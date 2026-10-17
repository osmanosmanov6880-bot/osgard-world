#!/usr/bin/env python3
"""Consistent Core snapshots and bound offline restores into new directories.

The backup(source, destination) -> sha256 API remains available to Core callers.
CLI backups also publish a private manifest/checksum pair. Restore never starts
a service, replaces a file, or reuses the default production database directory.
"""
from contextlib import closing, contextmanager
from datetime import datetime, timezone
from pathlib import Path
import argparse
import hashlib
import json
import os
import re
import sqlite3
import stat
import sys
import tempfile
import time

FORMAT = "osgard-core-backup/v1"
MAX_BYTES = 1024 * 1024 * 1024
MAX_METADATA_BYTES = 64 * 1024
SQLITE_TIMEOUT = 30
CORE_COLUMNS = {
    "users": {"id", "username", "salt", "password_hash", "created_at"},
    "sessions": {"token_hash", "user_id", "expires_at"},
    "projects": {"id", "owner_id", "version", "data", "created_at", "updated_at"},
    "members": {"project_id", "user_id", "role"},
    "revisions": {"project_id", "version", "data", "actor_id", "created_at"},
    "events": {"id", "project_id", "actor_id", "kind", "detail", "created_at"},
    "operations": {"user_id", "key", "request_hash", "response", "created_at"},
    "templates": {"id", "owner_id", "title", "source_project", "source_version", "data", "created_at"},
    "jobs": {"id", "project_id", "actor_id", "source_version", "status", "attempts", "result", "created_at", "updated_at"},
    "assets": {"id", "project_id", "source_version", "content", "sha256", "created_at"},
}
CORE_FOREIGN_KEYS = {
    "sessions": {("user_id", "users", "id")}, "projects": {("owner_id", "users", "id")},
    "members": {("project_id", "projects", "id"), ("user_id", "users", "id")},
    "revisions": {("project_id", "projects", "id")}, "events": {("project_id", "projects", "id")},
    "operations": {("user_id", "users", "id")}, "templates": {("owner_id", "users", "id")},
    "jobs": {("project_id", "projects", "id")}, "assets": {("project_id", "projects", "id")},
}


def utc_now():
    return datetime.now(timezone.utc).isoformat()


def checked_path(value, *, missing=False):
    """Reject traversal and symlinks in every existing path component."""
    raw = os.fspath(value)
    if not isinstance(raw, str) or not raw or "\\" in raw or any(ord(c) < 32 for c in raw):
        raise ValueError("Use a filesystem path without control characters or backslashes.")
    if ".." in Path(raw).parts:
        raise ValueError("Parent traversal is not allowed in backup/restore paths.")
    path = Path(os.path.abspath(raw))
    current = Path(path.anchor)
    for part in path.parts[1:]:
        current /= part
        try:
            info = current.lstat()
        except FileNotFoundError:
            if missing:
                continue
            raise ValueError("Source or parent directory is missing.") from None
        if stat.S_ISLNK(info.st_mode):
            raise ValueError("symlink backup/restore paths are not allowed.")
        if current != path and not stat.S_ISDIR(info.st_mode):
            raise ValueError("A backup/restore parent is not a directory.")
    return path


def prepare_directory(value):
    path = checked_path(value, missing=True)
    reject_public_destination(path)
    path.mkdir(mode=0o700, parents=True, exist_ok=True)
    checked_path(path)
    if not path.is_dir():
        raise ValueError("Backup directory is not a directory.")
    return path


def reject_public_destination(path):
    project = Path(__file__).resolve().parents[1]
    if any(path.is_relative_to(project / name) for name in ("public", "dist", "PAGES")):
        raise ValueError("Database destination is a public-serving directory.")


def require_new(path):
    checked_path(path, missing=True)
    if os.path.lexists(path):
        raise ValueError("Destination already exists; choose a new path.")


def private_fd(path):
    return os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0), 0o600)


def identity(info):
    return info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns


def unlink_owned(path, owner):
    try:
        info = path.lstat()
        if (info.st_dev, info.st_ino) == owner:
            path.unlink()
            return True
    except FileNotFoundError:
        pass


@contextmanager
def regular_reader(value, *, max_bytes=MAX_BYTES, stable=True):
    path = checked_path(value)
    fd = os.open(path, os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0) | getattr(os, "O_NONBLOCK", 0))
    with os.fdopen(fd, "rb") as stream:
        before = os.fstat(stream.fileno())
        if not stat.S_ISREG(before.st_mode):
            raise ValueError("Backup must be a regular file, not a symlink or device.")
        if not 0 < before.st_size <= max_bytes:
            raise ValueError("empty backup file or configured file size limit exceeded.")
        yield path, stream, before
        after = os.fstat(stream.fileno())
        current = path.stat()
        if (before.st_dev, before.st_ino) != (current.st_dev, current.st_ino) or (stable and (identity(before) != identity(after) or identity(after) != identity(current))):
            raise ValueError("Backup changed while testing or copying.")


def digest(path):
    with regular_reader(path) as (_, stream, _):
        hasher = hashlib.sha256()
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def checked_sha(value):
    if not isinstance(value, str) or not re.fullmatch(r"[0-9a-fA-F]{64}", value):
        raise ValueError("Expected sha256 must be 64 hex characters.")
    return value.lower()


def reject_sidecars(path):
    for suffix in ("-wal", "-shm", "-journal"):
        if os.path.lexists(str(path) + suffix):
            raise ValueError("Offline backup has a WAL/SHM/journal sidecar; create an online SQLite backup first.")


def check_sqlite(path, *, require_core=False, timeout=SQLITE_TIMEOUT):
    """Inspect only a private immutable snapshot, with a bounded SQL time budget."""
    path = checked_path(path)
    deadline = time.monotonic() + timeout
    with closing(sqlite3.connect(path.as_uri() + "?mode=ro&immutable=1", uri=True, timeout=3)) as db:
        db.set_progress_handler(lambda: int(time.monotonic() > deadline), 1000)
        db.execute("PRAGMA trusted_schema=OFF")
        try:
            if db.execute("PRAGMA integrity_check").fetchall() != [("ok",)]:
                raise ValueError("SQLite integrity_check failed.")
            if db.execute("PRAGMA foreign_key_check").fetchone() is not None:
                raise ValueError("SQLite foreign_key_check failed; orphaned relationships exist.")
            tables = [row[0] for row in db.execute("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
            if not tables:
                raise ValueError("no SQLite tables found")
            if len(tables) > 2000:
                raise ValueError("SQLite schema table budget exceeded.")
            version = db.execute("PRAGMA user_version").fetchone()[0]
            if require_core:
                if version != 1 or not CORE_COLUMNS.keys() <= set(tables):
                    raise ValueError("Unsupported or unrelated Core schema.")
                for table, required in CORE_COLUMNS.items():
                    columns = {row[1] for row in db.execute(f'PRAGMA table_info("{table}")')}
                    if not required <= columns:
                        raise ValueError("Core schema is missing required columns.")
                    foreign = {(row[3], row[2], row[4]) for row in db.execute(f'PRAGMA foreign_key_list("{table}")')}
                    if not CORE_FOREIGN_KEYS.get(table, set()) <= foreign:
                        raise ValueError("Core schema is missing required foreign keys.")
            schema = db.execute("SELECT type,name,tbl_name,sql FROM sqlite_master WHERE name NOT LIKE 'sqlite_%' ORDER BY type,name").fetchall()
        except sqlite3.OperationalError as error:
            if time.monotonic() > deadline:
                raise ValueError("SQLite validation time budget exceeded.") from error
            raise
    return {"tables": tables, "user_version": version, "table_count": len(tables),
            "schema_sha256": hashlib.sha256(json.dumps(schema, ensure_ascii=False, separators=(",", ":")).encode()).hexdigest(),
            "integrity_check": "passed", "foreign_key_check": "passed"}


def copy_snapshot(source, destination, expected_sha256=None):
    """Copy a stopped snapshot through one pinned reader; never copy active WAL."""
    expected = checked_sha(expected_sha256) if expected_sha256 is not None else None
    source = checked_path(source)
    destination = checked_path(destination, missing=True)
    reject_public_destination(destination)
    reject_sidecars(source)
    require_new(destination)
    reject_sidecars(destination)
    owner = None
    try:
        with regular_reader(source) as (_, original, before):
            fd = private_fd(destination)
            info = os.fstat(fd)
            owner = (info.st_dev, info.st_ino)
            checksum = hashlib.sha256()
            length = 0
            with os.fdopen(fd, "wb") as restored:
                for block in iter(lambda: original.read(1024 * 1024), b""):
                    length += len(block)
                    if length > MAX_BYTES:
                        raise ValueError("Backup size limit exceeded during copy.")
                    checksum.update(block)
                    restored.write(block)
                restored.flush()
                os.fsync(restored.fileno())
            if length != before.st_size:
                raise ValueError("Backup changed while copying.")
        reject_sidecars(source)
        sha = checksum.hexdigest()
        if expected is not None and sha != expected:
            raise ValueError("Backup checksum does not match expected SHA-256.")
        if digest(destination) != sha:
            raise ValueError("Copy checksum mismatch.")
        return {"sha256": sha, "bytes": length}
    except BaseException:
        if owner is not None:
            unlink_owned(destination, owner)
        raise


def backup(source, destination, *, timeout=SQLITE_TIMEOUT):
    """Create a new standalone Core snapshot with SQLite's online backup API."""
    source = checked_path(source)
    destination = checked_path(destination, missing=True)
    require_new(destination)
    reject_sidecars(destination)
    prepare_directory(destination.parent)
    # Live writes may change the source. Its inode/path must remain the same.
    owner = None
    try:
        with regular_reader(source, stable=False) as (_, original, source_info):
            fd = private_fd(destination)
            info = os.fstat(fd)
            owner = (info.st_dev, info.st_ino)
            os.close(fd)
            deadline = time.monotonic() + timeout

            def progress(status, remaining, total):
                if time.monotonic() > deadline:
                    raise ValueError("Online backup time budget exceeded.")
                if total * page_size > MAX_BYTES:
                    raise ValueError("Online backup size limit exceeded while copying.")

            with closing(sqlite3.connect(source.as_uri() + "?mode=ro", uri=True, timeout=3)) as src, closing(sqlite3.connect(destination)) as dst:
                page_size = src.execute("PRAGMA page_size").fetchone()[0]
                if src.execute("PRAGMA page_count").fetchone()[0] * page_size > MAX_BYTES:
                    raise ValueError("Logical database size limit exceeded before online backup.")
                src.backup(dst, pages=256, progress=progress, sleep=0.05)
                if dst.execute("PRAGMA journal_mode=DELETE").fetchone()[0] != "delete":
                    raise ValueError("Could not create a standalone SQLite snapshot.")
            if (source.stat().st_dev, source.stat().st_ino) != (source_info.st_dev, source_info.st_ino):
                raise ValueError("Source database pathname changed during backup.")
            reject_sidecars(destination)
            check_sqlite(destination, require_core=True, timeout=timeout)
            with destination.open("rb") as stream:
                os.fsync(stream.fileno())
            checksum = digest(destination)
        return checksum
    except BaseException:
        if owner is not None and unlink_owned(destination, owner):
            for suffix in ("-wal", "-shm", "-journal"):
                Path(str(destination) + suffix).unlink(missing_ok=True)
        raise


def write_private(path, data):
    fd = private_fd(path)
    info = os.fstat(fd)
    owner = (info.st_dev, info.st_ino)
    try:
        with os.fdopen(fd, "wb") as stream:
            stream.write(data)
            stream.flush()
            os.fsync(stream.fileno())
        return owner
    except BaseException:
        unlink_owned(path, owner)
        raise


def json_bytes(value):
    return (json.dumps(value, ensure_ascii=False, sort_keys=True, indent=2, allow_nan=False) + "\n").encode()


def publish_snapshot(source, destination, expected_sha256, *, method="verified-offline-snapshot"):
    """Validate and publish DB + manifest + checksum without replacing artifacts."""
    if method not in ("sqlite-online-backup", "verified-offline-snapshot"):
        raise ValueError("Unknown snapshot method.")
    destination = checked_path(destination, missing=True)
    prepare_directory(destination.parent)
    metadata_path = Path(str(destination) + ".manifest.json")
    checksum_path = Path(str(destination) + ".sha256")
    for path in (destination, metadata_path, checksum_path):
        require_new(path)
    owned = []
    try:
        copied = copy_snapshot(source, destination, expected_sha256)
        info = destination.stat()
        owned.append((destination, (info.st_dev, info.st_ino)))
        schema = check_sqlite(destination, require_core=True)
        schema.pop("tables")
        metadata = {"format": FORMAT, "schema_version": 1, "recorded_at": utc_now(), "snapshot_method": method,
                    "database": {"filename": destination.name, **copied}, "sqlite": schema}
        # The manifest is the last publication marker; older artifacts must exist.
        owned.append((checksum_path, write_private(checksum_path, f'{copied["sha256"]}  {destination}\n'.encode())))
        owned.append((metadata_path, write_private(metadata_path, json_bytes(metadata))))
        return {"status": "backup_verified", **copied, "schema_version": schema["user_version"],
                "manifest": str(metadata_path), "manifest_sha256": digest(metadata_path),
                "snapshot_method": method, "production_restore_performed": False}
    except BaseException:
        for path, owner in reversed(owned):
            unlink_owned(path, owner)
        raise


def create_backup_bundle(source, destination):
    destination = checked_path(destination, missing=True)
    for suffix in ("", ".sha256", ".manifest.json"):
        require_new(Path(str(destination) + suffix))
    prepare_directory(destination.parent)
    with tempfile.TemporaryDirectory(prefix=".osgard-core-snapshot-", dir=destination.parent) as folder:
        snapshot = Path(folder) / "snapshot.sqlite3"
        checksum = backup(source, snapshot)
        return publish_snapshot(snapshot, destination, checksum, method="sqlite-online-backup")


def read_metadata(value, *, include_raw=False):
    def unique(pairs):
        result = {}
        for key, item in pairs:
            if key in result:
                raise ValueError("Duplicate backup metadata key.")
            result[key] = item
        return result

    with regular_reader(value, max_bytes=MAX_METADATA_BYTES) as (_, stream, _):
        raw = stream.read(MAX_METADATA_BYTES + 1)
    try:
        value = json.loads(raw, object_pairs_hook=unique)
    except (UnicodeError, json.JSONDecodeError) as error:
        raise ValueError("Malformed backup metadata JSON.") from error
    if not isinstance(value, dict) or value.get("format") != FORMAT or type(value.get("schema_version")) is not int or value["schema_version"] != 1:
        raise ValueError("Unsupported backup metadata format/version.")
    database, schema = value.get("database"), value.get("sqlite")
    if not isinstance(database, dict) or not isinstance(schema, dict):
        raise ValueError("Backup metadata is missing database/SQLite binding.")
    filename = database.get("filename")
    if not isinstance(filename, str) or not filename or filename in (".", "..") or any(c in filename for c in "/\\") or any(ord(c) < 32 for c in filename):
        raise ValueError("Backup metadata filename must be a single safe basename.")
    database["sha256"] = checked_sha(database.get("sha256"))
    if type(database.get("bytes")) is not int or not 0 < database["bytes"] <= MAX_BYTES:
        raise ValueError("Backup metadata byte count is invalid.")
    if type(schema.get("user_version")) is not int or schema["user_version"] != 1:
        raise ValueError("Unsupported Core schema in backup metadata.")
    if type(schema.get("table_count")) is not int or not 1 <= schema["table_count"] <= 2000:
        raise ValueError("Invalid metadata table count.")
    schema["schema_sha256"] = checked_sha(schema.get("schema_sha256"))
    if schema.get("integrity_check") != "passed" or schema.get("foreign_key_check") != "passed":
        raise ValueError("Metadata does not record successful SQLite/FK checks.")
    if value.get("snapshot_method") not in ("sqlite-online-backup", "verified-offline-snapshot"):
        raise ValueError("Unsupported metadata snapshot method.")
    try:
        stamp = datetime.fromisoformat(value["recorded_at"])
        if stamp.tzinfo is None or stamp.utcoffset().total_seconds() != 0:
            raise ValueError()
    except (KeyError, TypeError, ValueError):
        raise ValueError("Backup metadata requires a UTC recorded_at timestamp.") from None
    result = value, hashlib.sha256(raw).hexdigest()
    return (*result, raw) if include_raw else result


def validate_binding(source, copied, schema, metadata):
    if metadata["database"] != {"filename": Path(source).name, **copied}:
        raise ValueError("Backup file/size/checksum does not match its metadata.")
    actual = {key: schema[key] for key in metadata["sqlite"] if key in schema}
    if metadata["sqlite"] != actual:
        raise ValueError("Restored SQLite schema does not match its metadata.")


def new_restore_directory(value, *, protected_roots=()):
    target = checked_path(value, missing=True)
    project = Path(__file__).resolve().parents[1]
    protected = (Path("/var/lib/osgard-core"), Path.home() / ".osgard-core",
                 project / "public", project / "dist", project / "PAGES", *map(Path, protected_roots))
    if any(target.is_relative_to(path.absolute()) for path in protected):
        raise ValueError("Restore target is a production or public-serving directory.")
    require_new(target)
    parent = checked_path(target.parent)
    if not parent.is_dir():
        raise ValueError("Restore parent directory must already exist.")
    target.mkdir(mode=0o700)
    return target


def restore_backup(source, metadata_path, target_dir, *, expected_sha256=None,
                   database_name="core.sqlite3", protected_roots=()):
    """Restore a bound snapshot offline. Do not start or configure a server."""
    if database_name in ("", ".", "..") or Path(database_name).name != database_name or "\\" in database_name:
        raise ValueError("Restore database name must be a single basename.")
    source = checked_path(source)
    metadata, metadata_sha, metadata_raw = read_metadata(metadata_path, include_raw=True)
    expected = metadata["database"]["sha256"]
    if expected_sha256 is not None and checked_sha(expected_sha256) != expected:
        raise ValueError("Trusted SHA-256 does not match backup metadata.")
    target = new_restore_directory(target_dir, protected_roots=protected_roots)
    target_info = target.stat()
    owned = []
    try:
        database = target / database_name
        copied = copy_snapshot(source, database, expected)
        info = database.stat()
        owned.append((database, (info.st_dev, info.st_ino)))
        schema = check_sqlite(database, require_core=True)
        validate_binding(source, copied, schema, metadata)
        report = {"schema_version": 1, "status": "restored_offline", "database": database_name,
                  "sha256": copied["sha256"], "bytes": copied["bytes"], "manifest_sha256": metadata_sha,
                  "sqlite": {key: value for key, value in schema.items() if key != "tables"},
                  "restored_at": utc_now(), "service_started": False, "production_modified": False,
                  "metadata_authenticated": False, "trusted_checksum_supplied": expected_sha256 is not None}
        for name, data in (("backup-manifest.json", metadata_raw), ("restore-report.json", json_bytes(report))):
            path = target / name
            owned.append((path, write_private(path, data)))
        return report
    except BaseException:
        for path, owner in reversed(owned):
            unlink_owned(path, owner)
        try:
            info = target.lstat()
            if (info.st_dev, info.st_ino) == (target_info.st_dev, target_info.st_ino):
                target.rmdir()
        except OSError:
            pass
        raise


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("mode", choices=("backup", "restore", "publish"))
    parser.add_argument("source", type=Path)
    parser.add_argument("destination", type=Path)
    parser.add_argument("--manifest", type=Path)
    parser.add_argument("--sha256")
    parser.add_argument("--method", choices=("sqlite-online-backup", "verified-offline-snapshot"), default="verified-offline-snapshot")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        if args.mode == "backup":
            result = create_backup_bundle(args.source, args.destination)
        elif args.mode == "publish":
            if args.sha256 is None:
                raise ValueError("Publishing a transferred snapshot requires --sha256 from its source.")
            result = publish_snapshot(args.source, args.destination, args.sha256, method=args.method)
        else:
            result = restore_backup(args.source, args.manifest or Path(str(args.source) + ".manifest.json"),
                                    args.destination.parent, expected_sha256=args.sha256, database_name=args.destination.name)
    except (ValueError, OSError, sqlite3.Error) as error:
        print("CORE BACKUP/RESTORE FAILED: " + str(error), file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        print("Core database copy validated. SHA-256:", result["sha256"])
        print("Status:", result["status"])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
