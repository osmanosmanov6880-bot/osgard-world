#!/usr/bin/env python3
"""Validate a consistent SQLite backup in a private temporary restore directory."""
import argparse
from contextlib import closing
import hashlib
import json
import os
import sqlite3
import stat
import sys
import tempfile
import time
from pathlib import Path

SIDE_CARS = ("-wal", "-shm", "-journal")
# Compatibility checks for the persisted Core v1 state and durable operation ledgers.
CORE_COLUMNS = {
    "users": {"id", "username", "salt", "password_hash", "created_at"},
    "sessions": {"token_hash", "user_id", "expires_at"},
    "projects": {"id", "owner_id", "version", "data", "created_at", "updated_at"},
    "members": {"project_id", "user_id", "role"},
    "revisions": {"project_id", "version", "data", "actor_id"},
    "events": {"id", "project_id", "actor_id", "kind", "detail"},
    "operations": {"user_id", "key", "request_hash", "response", "created_at"},
    "templates": {"id", "owner_id", "source_project", "source_version", "data"},
    "jobs": {"id", "project_id", "source_version", "status", "attempts", "result"},
    "assets": {"id", "project_id", "source_version", "content", "sha256"},
    "commerce_orders": {"id", "project_id", "buyer_id", "state", "paid_minor", "refunded_minor"},
    "commerce_checkout_ops": {"id", "order_id", "provider_key", "params", "state", "started_at",
                              "lease_until", "session_id", "checkout_url", "last_error"},
    "commerce_refund_ops": {"id", "order_id", "provider_key", "params", "state", "target_minor",
                            "started_at", "lease_until", "refund_id", "last_error"},
    "commerce_webhook_events": {"id", "body_sha256", "event_type", "order_id", "processed_at"},
    "commerce_entitlements": {"order_id", "buyer_id", "active"},
    "commerce_requests": {"user_id", "key", "request_hash", "response"},
}

# Additive game tables are optional in pre-INHERIT backups. Once any is present,
# all ACL, lineage and recovery tables plus immutable-history guards are required.
INHERIT_COLUMNS = {
    "inherit_meta": {"version"},
    "inherit_worlds": {"id", "creator_id", "custodian_id", "revision", "generation", "custody_start",
                       "baseline", "objects", "baseline_hash", "snapshot_hash", "pending_handoff"},
    "inherit_members": {"world_id", "user_id", "joined_at"},
    "inherit_generations": {"world_id", "number", "author_id", "delta", "objects", "parent_hash", "snapshot_hash"},
    "inherit_handoffs": {"id", "world_id", "from_id", "to_id", "status", "expected_revision", "expires_at"},
    "inherit_notifications": {"id", "user_id", "world_id", "invitation_id", "generation", "actor_id", "kind", "read_at"},
    "inherit_operations": {"user_id", "key", "world_id", "invitation_id", "response", "created_at"},
}


def digest(path):
    hasher = hashlib.sha256()
    with Path(path).open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()


def identity(info):
    return (info.st_dev, info.st_ino, info.st_size, info.st_mtime_ns, info.st_ctime_ns)


def no_sidecars(directory_fd, name):
    for suffix in SIDE_CARS:
        try:
            os.stat(name + suffix, dir_fd=directory_fd, follow_symlinks=False)
        except FileNotFoundError:
            continue
        raise ValueError("backup has a WAL/SHM/journal sidecar; create a consistent standalone snapshot")


def copy_snapshot(source, target):
    """Open each path component without following symlinks; hash exactly the copied bytes."""
    if not hasattr(os, "O_NOFOLLOW") or not hasattr(os, "O_DIRECTORY"):
        raise ValueError("safe snapshot verification requires a POSIX filesystem")
    path = Path(source).absolute()
    directory_fd = os.open(path.anchor, os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:-1]:
            try:
                child_fd = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW,
                                   dir_fd=directory_fd)
            except OSError as error:
                raise ValueError("backup path must use real directories, not symlinks") from error
            os.close(directory_fd)
            directory_fd = child_fd
        no_sidecars(directory_fd, path.name)
        try:
            fd = os.open(path.name, os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK,
                         dir_fd=directory_fd)
        except OSError as error:
            raise ValueError("backup must be a readable regular file, not a symlink") from error
        with os.fdopen(fd, "rb") as original:
            before = os.fstat(original.fileno())
            if not stat.S_ISREG(before.st_mode):
                raise ValueError("backup must be a regular file, not a pipe or device")
            if before.st_size == 0:
                raise ValueError("empty backup file")
            hasher = hashlib.sha256()
            copied = 0
            out_fd = os.open(target, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
            with os.fdopen(out_fd, "wb") as restored:
                for block in iter(lambda: original.read(1024 * 1024), b""):
                    copied += len(block)
                    if copied > before.st_size:
                        raise ValueError("backup changed while copying")
                    hasher.update(block)
                    restored.write(block)
                restored.flush()
                os.fsync(restored.fileno())
            after = os.fstat(original.fileno())
            current_path = os.stat(path.name, dir_fd=directory_fd, follow_symlinks=False)
            if copied != before.st_size or identity(before) != identity(after) or identity(before) != identity(current_path):
                raise ValueError("backup changed while testing")
            no_sidecars(directory_fd, path.name)
            return hasher.hexdigest(), copied
    finally:
        os.close(directory_fd)


def check_sqlite(path, sqlite_only=False):
    # SQLite only ever opens the private copied file, never the supplied source.
    uri = path.as_uri() + "?mode=ro&immutable=1"
    with closing(sqlite3.connect(uri, uri=True, timeout=3)) as db:
        db.row_factory = sqlite3.Row
        db.execute("PRAGMA trusted_schema=OFF")
        db.execute("PRAGMA query_only=ON")
        if db.execute("PRAGMA integrity_check").fetchone()[0] != "ok":
            # Do not leak table names, row identifiers or database values into shared logs.
            raise ValueError("SQLite integrity_check failed")
        if db.execute("PRAGMA foreign_key_check").fetchone() is not None:
            raise ValueError("SQLite foreign key integrity check failed")
        tables = {name for (name,) in db.execute(
            "SELECT name FROM sqlite_schema WHERE type='table' AND name NOT LIKE 'sqlite_%'")}
        if not tables:
            raise ValueError("no SQLite tables found")
        version = db.execute("PRAGMA user_version").fetchone()[0]
        if not sqlite_only:
            if version != 1:
                raise ValueError("unsupported Core schema version")
            expected_columns = dict(CORE_COLUMNS)
            if tables & INHERIT_COLUMNS.keys():
                expected_columns.update(INHERIT_COLUMNS)
            for table, required in expected_columns.items():
                if table not in tables:
                    raise ValueError("Core backup is missing an expected table")
                columns = {column[1] for column in db.execute(f'PRAGMA table_info("{table}")')}
                if not required.issubset(columns):
                    raise ValueError("Core backup is missing expected columns")
            if tables & INHERIT_COLUMNS.keys():
                if [row[0] for row in db.execute('SELECT version FROM inherit_meta')] != [1]:
                    raise ValueError("unsupported INHERIT schema version")
                triggers = {row[0] for row in db.execute("SELECT name FROM sqlite_schema WHERE type='trigger'")}
                if not {"inherit_generation_no_update", "inherit_generation_no_delete"} <= triggers:
                    raise ValueError("Core backup is missing INHERIT history guards")
        # Validate application invariants on the private, immutable backup copy.
        # PRAGMA integrity_check verifies SQLite pages, not the semantic lineage
        # encoded in otherwise syntactically valid rows.
        lineage_checked = not sqlite_only and bool(tables & INHERIT_COLUMNS.keys())
        worlds_verified = 0
        generations_verified = 0
        if lineage_checked:
            server_dir = str(Path(__file__).resolve().parents[1] / "server")
            if server_dir not in sys.path:
                sys.path.insert(0, server_dir)
            import core_inherit
            try:
                # Stream bounded histories one world at a time. All names,
                # coordinates and owner identifiers remain on the private copy.
                for world in db.execute("SELECT * FROM inherit_worlds ORDER BY id"):
                    core_inherit.verify_lineage(db, world)
                    worlds_verified += 1
                    generations_verified += world["generation"] - 1
            except Exception:
                # Fail closed without leaking content or world IDs to CI logs.
                raise ValueError("INHERIT application lineage integrity check failed") from None
        return {"table_count": len(tables), "user_version": version,
                "inherit_lineage_checked": lineage_checked,
                "inherit_worlds_verified": worlds_verified,
                "inherit_generations_verified": generations_verified}


def drill(source, expected_sha256=None, sqlite_only=False):
    if expected_sha256 is not None:
        expected_sha256 = expected_sha256.lower().strip()
        if len(expected_sha256) != 64 or any(c not in "0123456789abcdef" for c in expected_sha256):
            raise ValueError("expected sha256 must be 64 hex characters")
    started = time.perf_counter()
    with tempfile.TemporaryDirectory(prefix="osgard-restore-drill-") as working:
        target = Path(working) / "restored.sqlite3"
        source_digest, size = copy_snapshot(source, target)
        if digest(target) != source_digest:
            raise ValueError("copy checksum mismatch")
        if expected_sha256 is not None and source_digest != expected_sha256:
            raise ValueError("checksum does not match expected SHA-256")
        schema = check_sqlite(target, sqlite_only)
        return {
            "status": "passed",
            "sha256": source_digest,
            "expected_sha256_verified": expected_sha256 is not None,
            "bytes": size,
            "table_count": schema["table_count"],
            "schema_version": schema["user_version"],
            "core_schema_checked": not sqlite_only,
            "foreign_keys_checked": True,
            "inherit_lineage_checked": schema["inherit_lineage_checked"],
            "inherit_worlds_verified": schema["inherit_worlds_verified"],
            "inherit_generations_verified": schema["inherit_generations_verified"],
            "restored_to": "ephemeral_private_directory",
            "production_modified": False,
            "verification_seconds": round(time.perf_counter() - started, 6),
            "application_restore_validated": False,
            "rto_seconds": None,
            "rpo_seconds": None,
        }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", type=Path, help="an already consistent standalone backup snapshot")
    parser.add_argument("--sha256", help="trusted expected 64-character SHA-256 digest")
    parser.add_argument("--sqlite-only", action="store_true",
                        help="diagnose generic SQLite without asserting Core schema compatibility")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        report = drill(args.backup, args.sha256, args.sqlite_only)
    except (ValueError, OSError, sqlite3.Error) as error:
        print("RECOVERY DRILL FAILED: " + str(error), file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("RECOVERY DRILL PASSED: SQLite integrity and foreign keys OK;",
              "Core schema checked:", report["core_schema_checked"],
              "sha256:", report["sha256"], "; private ephemeral restore only")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
