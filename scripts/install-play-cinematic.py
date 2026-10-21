#!/usr/bin/env python3
"""Install or roll back an allowlisted OSGARD frontend release; dry-run by default.

Standalone Python 3.9+ / POSIX installer. It never extracts a tar into the
document root, changes Nginx/backend configuration, or removes whole folders.
"""
from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import io
import json
import os
from pathlib import Path, PurePosixPath
import re
import signal
import stat
import sys
import tarfile
import tempfile
import uuid


SCHEMA = 1
KIND = "osgard-play-selective-release"
TRANSACTION_KIND = "osgard-play-selective-backup"
GLOBAL_KIND = "osgard-global-frontend-release"
GLOBAL_TRANSACTION_KIND = "osgard-global-frontend-backup"
MAX_FILES = 1024
MAX_FILE_BYTES = 16 * 1024 * 1024
MAX_TOTAL_BYTES = 256 * 1024 * 1024
MAX_MANIFEST_BYTES = 2 * 1024 * 1024
HASH_RE = re.compile(r"^[0-9a-f]{64}$")
SOURCE_RE = re.compile(r"^[0-9a-f]{40}(?:[0-9a-f]{24})?$")
ASSET_RE = re.compile(r"^assets/[A-Za-z0-9_][A-Za-z0-9_.-]*-[A-Za-z0-9_-]{8,}\.(?:js|css)$")
ART_RE = re.compile(r"^brand/play/[A-Za-z0-9][A-Za-z0-9_-]*\.webp$")
WORLD_RE = re.compile(r"^play/world/[a-z0-9][a-z0-9-]{0,63}/index\.html$")
HTML_PATHS = frozenset({"play/index.html", "games/index.html", "entertainment/index.html", "games/time/index.html"})
GAME_FIX_PATHS = frozenset({"games/vector-zero/index.html"})
FIXED_ASSET_PATHS = frozenset({"brand/play/ui-icons.svg"})
# Reviewed against scripts/build-brand-routes.mjs and redesignCatalog.ts. This
# is a fixed registry, never a **/index.html glob supplied by the archive. In
# particular, static Godot/Unity/Time Empire pages are not React route shells.
GLOBAL_HTML_PATHS = frozenset("""
academy/index.html
account/index.html
archive/index.html
aurum/index.html
brand/index.html
business/index.html
catalog/index.html
chronicle/index.html
club/index.html
community/index.html
core-events/index.html
create/index.html
data/index.html
deliveries/index.html
development/index.html
entertainment/index.html
games/index.html
games/time/index.html
index.html
intelligence/index.html
learning/assessment/index.html
learning/campus/index.html
learning/enrollment/index.html
learning/experiments/index.html
learning/index.html
learning/organizer/index.html
learning/portfolio/index.html
learning/pricing/index.html
learning/program/index.html
learning/project/index.html
learning/workspace/index.html
lectures/how-language-models-work/index.html
lectures/human-in-the-loop/index.html
lectures/index.html
lectures/intelligence-and-imitation/index.html
lectures/investigate-the-future/index.html
lectures/power-of-knowledge/index.html
lectures/privacy-before-prompting/index.html
lectures/signal-and-noise/index.html
lectures/verify-an-ai-answer/index.html
marcosa/index.html
masters/index.html
media/index.html
miniapp/index.html
mobility/index.html
next/index.html
osa-cinema/index.html
play/index.html
play/inherit/index.html
play/null-shift/index.html
play/partners/index.html
play/remix/index.html
play/swarm/index.html
play/world/afterimage-run/index.html
play/world/empire-orbit/index.html
play/world/inherit/index.html
play/world/null-shift/index.html
play/world/remix/index.html
play/world/swarm/index.html
play/world/time/index.html
play/world/vector-zero/index.html
play/world/zion-020/index.html
play/world/zion-021/index.html
play/world/zion-022/index.html
play/world/zion-023/index.html
play/world/zion-024/index.html
play/world/zion-025/index.html
play/world/zion-026/index.html
play/world/zion-027/index.html
play/world/zion-028/index.html
play/world/zion-029/index.html
play/world/zion-030/index.html
portal/index.html
profile/index.html
purchases/index.html
quality/index.html
stream/index.html
teams/index.html
timecoin/index.html
week/index.html
workspace/index.html
workspace/overview/index.html
worlds/index.html
""".split())
INTRO_ASSET_PATHS = frozenset({
    "brand/intro/energy-platform.webp", "brand/intro/energy-platform-1280.webp",
    "brand/intro/energy-platform-mobile.webp", "brand/intro/energy-platform-mobile-780.webp",
    "brand/intro/osgard-emblem.webp", "brand/intro/osgard-emblem-640.webp",
})
PATH_POLICY = [
    "assets/<name>-<hash>.js", "assets/<name>-<hash>.css",
    "brand/play/<name>.webp", "brand/play/ui-icons.svg", "play/index.html", "play/world/<id>/index.html",
    "games/index.html", "entertainment/index.html", "games/time/index.html", "games/vector-zero/index.html",
]
GLOBAL_PATH_POLICY = [
    "assets/<name>-<hash>.js", "assets/<name>-<hash>.css", "brand/play/<name>.webp",
    *sorted(FIXED_ASSET_PATHS | INTRO_ASSET_PATHS | GLOBAL_HTML_PATHS | GAME_FIX_PATHS),
]


class ReleaseError(Exception):
    """A release was rejected without relaxing its path or integrity policy."""


def utc_now() -> str:
    return dt.datetime.now(dt.timezone.utc).isoformat(timespec="seconds").replace("+00:00", "Z")


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def json_bytes(value: object) -> bytes:
    return (json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n").encode("utf-8")


def relative_parts(value: str) -> tuple[str, ...]:
    if not isinstance(value, str) or not value or len(value) > 240 or "\\" in value or "\x00" in value:
        raise ReleaseError("Invalid relative path")
    path = PurePosixPath(value)
    if path.is_absolute() or path.as_posix() != value or any(part in ("", ".", "..") for part in path.parts):
        raise ReleaseError("Non-canonical or traversing path: " + value)
    return path.parts


def allowed_path(value: str, global_frontend: bool = False) -> bool:
    relative_parts(value)
    if value in GAME_FIX_PATHS or value in FIXED_ASSET_PATHS or ASSET_RE.fullmatch(value) or ART_RE.fullmatch(value):
        return True
    if global_frontend:
        return value in GLOBAL_HTML_PATHS or value in INTRO_ASSET_PATHS
    return value in HTML_PATHS or bool(WORLD_RE.fullmatch(value))


def require_allowed(value: str, global_frontend: bool = False) -> str:
    if not allowed_path(value, global_frontend):
        raise ReleaseError("Path is outside the fixed " + ("global frontend" if global_frontend else "PLAY") + " allowlist: " + value)
    return value


def parse_json(data: bytes, label: str) -> dict:
    def unique_pairs(pairs):
        result = {}
        for key, value in pairs:
            if key in result:
                raise ReleaseError("Duplicate JSON key in " + label)
            result[key] = value
        return result
    try:
        value = json.loads(data.decode("utf-8"), object_pairs_hook=unique_pairs)
    except (UnicodeDecodeError, ValueError) as error:
        raise ReleaseError("Invalid JSON in " + label) from error
    if not isinstance(value, dict):
        raise ReleaseError(label + " must be a JSON object")
    return value


def validate_manifest(manifest: dict, global_frontend: bool = False) -> dict[str, dict]:
    expected_kind = GLOBAL_KIND if global_frontend else KIND
    if manifest.get("schema_version") != SCHEMA or manifest.get("kind") != expected_kind:
        raise ReleaseError("Release scope does not match this invocation; global packages require --global-frontend and PLAY packages require the default mode")
    source = manifest.get("source")
    if not isinstance(source, dict) or not SOURCE_RE.fullmatch(str(source.get("git_commit", ""))):
        raise ReleaseError("The manifest must identify its source commit")
    if type(source.get("working_tree_dirty")) is not bool:
        raise ReleaseError("The source working-tree state must be explicit")
    if manifest.get("path_allowlist") != (GLOBAL_PATH_POLICY if global_frontend else PATH_POLICY):
        raise ReleaseError("The manifest path policy does not match this installer")
    preconditions = manifest.get("expected_previous")
    if not isinstance(preconditions, dict) or set(preconditions) != GAME_FIX_PATHS:
        raise ReleaseError("The fixed VECTOR//ZERO bugfix must identify its previous file checksum")
    if any(not HASH_RE.fullmatch(str(value)) for value in preconditions.values()):
        raise ReleaseError("Invalid game bugfix precondition checksum")
    entries = manifest.get("files")
    if not isinstance(entries, list) or not 1 <= len(entries) <= MAX_FILES:
        raise ReleaseError("Invalid release file count")
    files: dict[str, dict] = {}
    total = 0
    for entry in entries:
        if not isinstance(entry, dict):
            raise ReleaseError("Invalid file manifest entry")
        path = require_allowed(entry.get("path"), global_frontend)
        if path in files:
            raise ReleaseError("Duplicate manifest path: " + path)
        size = entry.get("size")
        if type(size) is not int or not 0 < size <= MAX_FILE_BYTES or not HASH_RE.fullmatch(str(entry.get("sha256", ""))):
            raise ReleaseError("Invalid size or checksum: " + path)
        files[path] = {"path": path, "size": size, "sha256": entry["sha256"]}
        total += size
    if total > MAX_TOTAL_BYTES:
        raise ReleaseError("Release exceeds the total size limit")
    if global_frontend and not (GLOBAL_HTML_PATHS | INTRO_ASSET_PATHS).issubset(files):
        raise ReleaseError("A global release requires all 83 reviewed React shells and all six fixed intro images")
    if not HTML_PATHS.issubset(files) or not any(WORLD_RE.fullmatch(path) for path in files):
        raise ReleaseError("A complete PLAY catalogue, aliases and the Time React shell are required")
    if not GAME_FIX_PATHS.issubset(files):
        raise ReleaseError("The release is missing its fixed VECTOR//ZERO bugfix")
    if not FIXED_ASSET_PATHS.issubset(files):
        raise ReleaseError("The release is missing its fixed PLAY icon sprite")
    if not any(ASSET_RE.fullmatch(path) for path in files) or not any(ART_RE.fullmatch(path) for path in files):
        raise ReleaseError("The release must contain bundles and PLAY artwork")
    return files


def ensure_posix() -> None:
    if os.name != "posix" or not all(hasattr(os, name) for name in ("O_NOFOLLOW", "O_DIRECTORY")):
        raise ReleaseError("Installation requires POSIX Python with O_NOFOLLOW and directory file descriptors")


def absolute_directory(value: str, label: str) -> Path:
    path = Path(value)
    if not path.is_absolute() or ".." in path.parts or path == Path("/"):
        raise ReleaseError(label + " must be an absolute non-root path without '..'")
    return path


@contextlib.contextmanager
def open_absolute_directory(path: Path, create: bool = False):
    """Walk from / using O_NOFOLLOW; no symlink component can redirect writes."""
    ensure_posix()
    current = os.open("/", os.O_RDONLY | os.O_DIRECTORY)
    try:
        for part in path.parts[1:]:
            if part in ("", ".", ".."):
                raise ReleaseError("Invalid absolute directory component")
            try:
                child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=current)
            except FileNotFoundError:
                if not create:
                    raise
                os.mkdir(part, 0o700, dir_fd=current)
                os.fsync(current)
                child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=current)
            os.close(current)
            current = child
        yield current
    finally:
        os.close(current)


def check_directory_components(path: Path, allow_missing: bool = False) -> None:
    current = Path("/")
    for part in path.parts[1:]:
        current = current / part
        try:
            info = current.lstat()
        except FileNotFoundError:
            if allow_missing:
                return
            raise ReleaseError("Directory does not exist: " + str(current))
        if not stat.S_ISDIR(info.st_mode) or stat.S_ISLNK(info.st_mode):
            raise ReleaseError("Directory is a symlink or not a directory: " + str(current))


@contextlib.contextmanager
def parent_directory(root_fd: int, path: str, create: bool = False, mode: int = 0o755):
    parts = relative_parts(path)
    current = os.dup(root_fd)
    try:
        for part in parts[:-1]:
            try:
                child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=current)
            except FileNotFoundError:
                if not create:
                    raise
                os.mkdir(part, mode, dir_fd=current)
                os.fsync(current)
                child = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=current)
            os.close(current)
            current = child
        yield current, parts[-1]
    finally:
        os.close(current)


def read_file(root_fd: int, path: str, max_bytes: int = MAX_FILE_BYTES) -> tuple[bytes, dict] | None:
    try:
        with parent_directory(root_fd, path) as (parent, name):
            file_fd = os.open(name, os.O_RDONLY | os.O_NOFOLLOW, dir_fd=parent)
    except FileNotFoundError:
        return None
    except OSError as error:
        raise ReleaseError("Cannot safely read file or parent directory: " + path) from error
    try:
        before = os.fstat(file_fd)
        if not stat.S_ISREG(before.st_mode) or before.st_size > max_bytes:
            raise ReleaseError("Not a regular bounded file: " + path)
        chunks = []
        size = 0
        while True:
            chunk = os.read(file_fd, min(1024 * 1024, max_bytes + 1 - size))
            if not chunk:
                break
            chunks.append(chunk)
            size += len(chunk)
            if size > max_bytes:
                raise ReleaseError("File exceeds the size limit: " + path)
        after = os.fstat(file_fd)
        if (before.st_ino, before.st_size, before.st_mtime_ns) != (after.st_ino, after.st_size, after.st_mtime_ns):
            raise ReleaseError("File changed while being read: " + path)
        data = b"".join(chunks)
        return data, {"sha256": digest(data), "size": len(data), "mode": stat.S_IMODE(after.st_mode) & 0o777,
                      "uid": after.st_uid, "gid": after.st_gid, "mtime_ns": after.st_mtime_ns}
    finally:
        os.close(file_fd)


def current_snapshot(root_fd: int, path: str) -> dict | None:
    current = read_file(root_fd, path)
    return None if current is None else current[1]


def same_snapshot(left: dict | None, right: dict | None) -> bool:
    if left is None or right is None:
        return left is right
    return all(left.get(key) == right.get(key) for key in ("sha256", "size", "mode", "uid", "gid"))


def atomic_write(root_fd: int, path: str, data: bytes, metadata: dict | None = None, private: bool = False) -> None:
    """Replace one regular file in its own directory; never follow a symlink."""
    relative_parts(path)
    with parent_directory(root_fd, path, create=True, mode=0o700 if private else 0o755) as (parent, name):
        try:
            existing = os.stat(name, dir_fd=parent, follow_symlinks=False)
            if not stat.S_ISREG(existing.st_mode):
                raise ReleaseError("Refusing to replace a non-regular file: " + path)
        except FileNotFoundError:
            pass
        temporary = ".osgard-play-" + uuid.uuid4().hex + ".tmp"
        fd = os.open(temporary, os.O_WRONLY | os.O_CREAT | os.O_EXCL | os.O_NOFOLLOW, 0o600, dir_fd=parent)
        try:
            view = memoryview(data)
            while view:
                wrote = os.write(fd, view)
                if wrote <= 0:
                    raise ReleaseError("Short write: " + path)
                view = view[wrote:]
            if metadata is not None:
                info = os.fstat(fd)
                if (info.st_uid, info.st_gid) != (metadata["uid"], metadata["gid"]):
                    os.fchown(fd, metadata["uid"], metadata["gid"])
            os.fchmod(fd, metadata["mode"] if metadata is not None else (0o600 if private else 0o644))
            if metadata is not None and "mtime_ns" in metadata:
                os.utime(fd, ns=(metadata["mtime_ns"], metadata["mtime_ns"]))
            os.fsync(fd)
            os.close(fd)
            fd = -1
            os.replace(temporary, name, src_dir_fd=parent, dst_dir_fd=parent)
            os.fsync(parent)
        finally:
            if fd != -1:
                os.close(fd)
            try:
                os.unlink(temporary, dir_fd=parent)
            except FileNotFoundError:
                pass


def delete_regular_file(root_fd: int, path: str) -> None:
    with parent_directory(root_fd, path) as (parent, name):
        info = os.stat(name, dir_fd=parent, follow_symlinks=False)
        if not stat.S_ISREG(info.st_mode):
            raise ReleaseError("Refusing to remove a non-regular file: " + path)
        os.unlink(name, dir_fd=parent)
        os.fsync(parent)


def read_archive(path: Path, global_frontend: bool = False) -> tuple[dict, dict[str, bytes], str]:
    absolute = path.absolute()
    if ".." in absolute.parts:
        raise ReleaseError("Archive path must not contain '..'")
    check_directory_components(absolute.parent)
    with open_absolute_directory(absolute.parent) as archive_parent:
        archive_data = read_file(archive_parent, absolute.name, MAX_TOTAL_BYTES)
    if archive_data is None:
        raise ReleaseError("Archive does not exist")
    raw = archive_data[0]
    payload: dict[str, bytes] = {}
    manifest = None
    entries: dict[str, dict] = {}
    seen = set()
    try:
        with tarfile.open(fileobj=io.BytesIO(raw), mode="r|gz") as archive:
            for index, member in enumerate(archive):
                if index > MAX_FILES or member.name in seen:
                    raise ReleaseError("Duplicate or excessive archive entries")
                seen.add(member.name)
                relative_parts(member.name)
                if not member.isfile() or member.issym() or member.islnk() or member.sparse is not None or member.pax_headers:
                    raise ReleaseError("Only ordinary files are accepted in the archive")
                if index == 0:
                    if member.name != "manifest.json" or not 0 < member.size <= MAX_MANIFEST_BYTES:
                        raise ReleaseError("The first archive entry must be a bounded manifest.json")
                    stream = archive.extractfile(member)
                    if stream is None:
                        raise ReleaseError("Cannot read release manifest")
                    manifest = parse_json(stream.read(MAX_MANIFEST_BYTES + 1), "manifest.json")
                    entries = validate_manifest(manifest, global_frontend)
                    continue
                if not member.name.startswith("payload/"):
                    raise ReleaseError("Unexpected archive member: " + member.name)
                name = require_allowed(member.name[len("payload/"):], global_frontend)
                entry = entries.get(name)
                if entry is None or member.size != entry["size"] or member.size > MAX_FILE_BYTES:
                    raise ReleaseError("Unexpected file or size: " + name)
                stream = archive.extractfile(member)
                if stream is None:
                    raise ReleaseError("Cannot read payload: " + name)
                data = stream.read(MAX_FILE_BYTES + 1)
                if len(data) != entry["size"] or digest(data) != entry["sha256"]:
                    raise ReleaseError("Payload checksum mismatch: " + name)
                payload[name] = data
    except (tarfile.TarError, EOFError, OSError) as error:
        raise ReleaseError("Invalid or damaged gzip/tar archive") from error
    if manifest is None or set(payload) != set(entries):
        raise ReleaseError("Archive is incomplete")
    return manifest, payload, digest(raw)


@contextlib.contextmanager
def installation_lock(backup_fd: int, root: Path):
    import fcntl
    name = ".osgard-play-" + digest(str(root).encode())[:16] + ".lock"
    fd = os.open(name, os.O_WRONLY | os.O_CREAT | os.O_NOFOLLOW, 0o600, dir_fd=backup_fd)
    try:
        if not stat.S_ISREG(os.fstat(fd).st_mode):
            raise ReleaseError("Installation lock is not a regular file")
        try:
            fcntl.flock(fd, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError as error:
            raise ReleaseError("Another frontend installation or rollback holds this backup-store lock") from error
        yield
    finally:
        os.close(fd)


def validate_locations(root: Path, backup_dir: Path) -> None:
    if backup_dir == root or root in backup_dir.parents:
        raise ReleaseError("The backup directory must be outside the document root")
    check_directory_components(root)
    check_directory_components(backup_dir, allow_missing=True)


def plan_release(root_fd: int, entries: dict[str, dict], preconditions: dict[str, str]) -> tuple[list[dict], list[str]]:
    changed = []
    unchanged = []
    for path in sorted(entries, key=lambda item: (item.endswith(".html"), item)):
        entry = entries[path]
        before = current_snapshot(root_fd, path)
        if before is not None and before["sha256"] == entry["sha256"] and before["size"] == entry["size"]:
            unchanged.append(path)
            continue
        # Existing hashed bundles may still serve other OSGARD sections. Never
        # overwrite a different file at a supposedly immutable asset URL.
        if ASSET_RE.fullmatch(path) and before is not None:
            raise ReleaseError("Existing hashed asset has different bytes; refusing to overwrite it: " + path)
        # A separately published newer game must never be overwritten by the
        # one audited runtime fix included in this frontend release.
        if path in GAME_FIX_PATHS and (before is None or before["sha256"] != preconditions[path]):
            raise ReleaseError("VECTOR//ZERO differs from the audited base; leave the newer game untouched: " + path)
        after = {"sha256": entry["sha256"], "size": entry["size"],
                 "mode": before["mode"] if before else 0o644,
                 "uid": before["uid"] if before else os.geteuid(),
                 "gid": before["gid"] if before else os.getegid()}
        changed.append({"path": path, "before": before, "after": after})
    if sum(record["before"]["size"] for record in changed if record["before"] is not None) > MAX_TOTAL_BYTES:
        raise ReleaseError("Previous versions exceed the bounded backup size")
    return changed, unchanged


def store_transaction(backup_fd: int, transaction: dict) -> None:
    atomic_write(backup_fd, "transaction.json", json_bytes(transaction), private=True)


def validate_snapshot(value: object, nullable: bool = False) -> None:
    if value is None and nullable:
        return
    if not isinstance(value, dict) or not HASH_RE.fullmatch(str(value.get("sha256", ""))):
        raise ReleaseError("Invalid backup snapshot")
    for key in ("size", "mode", "uid", "gid"):
        if type(value.get(key)) is not int or value[key] < 0:
            raise ReleaseError("Invalid backup file metadata")
    if value["size"] > MAX_FILE_BYTES or value["mode"] > 0o777:
        raise ReleaseError("Backup file metadata is outside the allowed bounds")
    if "mtime_ns" in value and (type(value["mtime_ns"]) is not int or value["mtime_ns"] < 0):
        raise ReleaseError("Invalid backup modification time")


def load_transaction(backup_fd: int, root: Path, global_frontend: bool = False) -> dict:
    result = read_file(backup_fd, "transaction.json", MAX_MANIFEST_BYTES)
    if result is None:
        raise ReleaseError("No transaction.json in this backup")
    transaction = parse_json(result[0], "transaction.json")
    expected_kind = GLOBAL_TRANSACTION_KIND if global_frontend else TRANSACTION_KIND
    if transaction.get("kind") != expected_kind or transaction.get("schema_version") != SCHEMA or transaction.get("root") != str(root):
        raise ReleaseError("Backup belongs to a different document root, scope or installer version")
    release = read_file(backup_fd, "release-manifest.json", MAX_MANIFEST_BYTES)
    if release is None or digest(release[0]) != transaction.get("release_manifest_sha256"):
        raise ReleaseError("The backed-up release manifest checksum does not match")
    release_manifest = parse_json(release[0], "release-manifest.json")
    release_files = validate_manifest(release_manifest, global_frontend)
    if transaction.get("source") != release_manifest["source"] or not HASH_RE.fullmatch(str(transaction.get("archive_sha256", ""))):
        raise ReleaseError("Backup release identity mismatch")
    records = transaction.get("files")
    if not isinstance(records, list) or len(records) > MAX_FILES:
        raise ReleaseError("Invalid backup record count")
    names = set()
    total = 0
    for record in records:
        if not isinstance(record, dict):
            raise ReleaseError("Invalid backup record")
        path = require_allowed(record.get("path"), global_frontend)
        if path in names:
            raise ReleaseError("Duplicate backup path")
        names.add(path)
        validate_snapshot(record.get("before"), nullable=True)
        validate_snapshot(record.get("after"))
        expected = release_files.get(path)
        if expected is None or (record["after"]["sha256"], record["after"]["size"]) != (expected["sha256"], expected["size"]):
            raise ReleaseError("Backup attempts to restore a file outside its original release: " + path)
        total += record["after"]["size"]
    if total > MAX_TOTAL_BYTES:
        raise ReleaseError("Backup transaction is too large")
    applied = transaction.get("applied")
    inflight = transaction.get("inflight")
    if not isinstance(applied, list) or any(not isinstance(path, str) or path not in names for path in applied) or len(set(applied)) != len(applied):
        raise ReleaseError("Invalid applied-file journal")
    if inflight is not None and (not isinstance(inflight, str) or inflight not in names):
        raise ReleaseError("Invalid inflight-file journal")
    if transaction.get("status") not in {"prepared", "applying", "applied", "rollback_failed", "rolling_back", "rolled_back"}:
        raise ReleaseError("Invalid backup transaction state")
    if transaction["status"] == "applied" and (set(applied) != names or inflight is not None):
        raise ReleaseError("An applied release has an incomplete file journal")
    return transaction


@contextlib.contextmanager
def ignore_repeated_interrupts():
    """A second TERM/HUP/interrupt must not cut short the recovery writes."""
    previous = {}
    try:
        for name in ("SIGINT", "SIGTERM", "SIGHUP"):
            if hasattr(signal, name):
                signum = getattr(signal, name)
                previous[signum] = signal.getsignal(signum)
                signal.signal(signum, signal.SIG_IGN)
        yield
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


@contextlib.contextmanager
def interrupted_apply():
    previous = {}
    def interrupted(signum, _frame):
        raise ReleaseError("Installation interrupted by signal " + str(signum))
    try:
        for name in ("SIGINT", "SIGTERM", "SIGHUP"):
            if hasattr(signal, name):
                signum = getattr(signal, name)
                previous[signum] = signal.getsignal(signum)
                signal.signal(signum, interrupted)
        yield
    finally:
        for signum, handler in previous.items():
            signal.signal(signum, handler)


def rollback_plan(root_fd: int, backup_fd: int, transaction: dict) -> list[tuple[dict, bytes | None]]:
    records = {record["path"]: record for record in transaction["files"]}
    paths = list(transaction["applied"])
    if transaction.get("inflight") and transaction["inflight"] not in paths:
        paths.append(transaction["inflight"])
    plan = []
    conflicts = []
    for path in reversed(paths):
        record = records[path]
        before, after = record["before"], record["after"]
        old_data = None
        if before is not None:
            backup = read_file(backup_fd, "before/" + path)
            if backup is None or backup[1]["sha256"] != before["sha256"] or backup[1]["size"] != before["size"]:
                raise ReleaseError("Backup checksum mismatch: " + path)
            old_data = backup[0]
        current = current_snapshot(root_fd, path)
        if same_snapshot(current, before):
            continue  # Already restored, including a newly-created file removed earlier.
        if not same_snapshot(current, after):
            conflicts.append(path)
            continue
        plan.append((record, old_data))
    if conflicts:
        raise ReleaseError("Rollback conflict: files changed after this release: " + ", ".join(conflicts))
    return plan


def perform_rollback(root_fd: int, backup_fd: int, transaction: dict) -> list[str]:
    plan = rollback_plan(root_fd, backup_fd, transaction)  # Check all conflicts before writing anything.
    transaction["status"] = "rolling_back"
    store_transaction(backup_fd, transaction)
    restored = []
    try:
        for record, old_data in plan:
            path = record["path"]
            current = current_snapshot(root_fd, path)
            if same_snapshot(current, record["before"]):
                continue
            if not same_snapshot(current, record["after"]):
                raise ReleaseError("Rollback conflict while restoring: " + path)
            if old_data is None:
                delete_regular_file(root_fd, path)
            else:
                atomic_write(root_fd, path, old_data, record["before"])
            if not same_snapshot(current_snapshot(root_fd, path), record["before"]):
                raise ReleaseError("Rollback verification failed: " + path)
            restored.append(path)
            transaction["restored"] = sorted(set(transaction.get("restored", [])) | set(restored))
            store_transaction(backup_fd, transaction)
        transaction["status"] = "rolled_back"
        transaction["rolled_back_at"] = utc_now()
        store_transaction(backup_fd, transaction)
        return restored
    except Exception:
        transaction["status"] = "rollback_failed"
        store_transaction(backup_fd, transaction)
        raise


def install_release(root: Path, archive_path: Path, backup_dir: Path, apply: bool = False, global_frontend: bool = False) -> dict:
    validate_locations(root, backup_dir)
    manifest, payload, archive_sha = read_archive(archive_path, global_frontend)
    entries = validate_manifest(manifest, global_frontend)
    with open_absolute_directory(root) as root_fd:
        changes, unchanged = plan_release(root_fd, entries, manifest["expected_previous"])
        report = {"operation": "install", "mode": "apply" if apply else "dry-run", "status": "ready",
                  "root": str(root), "release_kind": manifest["kind"], "source": manifest["source"], "archive_sha256": archive_sha,
                  "replace": [item["path"] for item in changes if item["before"] is not None],
                  "create": [item["path"] for item in changes if item["before"] is None], "unchanged": unchanged}
        if not apply or not changes:
            if apply:
                report["status"] = "unchanged"
            return report
        with open_absolute_directory(backup_dir, create=True) as store_fd, installation_lock(store_fd, root):
            changes, unchanged = plan_release(root_fd, entries, manifest["expected_previous"])
            if not changes:
                report.update(status="unchanged", replace=[], create=[], unchanged=unchanged)
                return report
            backup_name = ("frontend-" if global_frontend else "play-") + dt.datetime.now(dt.timezone.utc).strftime("%Y%m%dT%H%M%SZ") + "-" + manifest["source"]["git_commit"][:12] + "-" + uuid.uuid4().hex[:8]
            os.mkdir(backup_name, 0o700, dir_fd=store_fd)
            os.fsync(store_fd)
            backup_fd = os.open(backup_name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=store_fd)
            backup_path = backup_dir / backup_name
            try:
                for record in changes:
                    if record["before"] is None:
                        continue
                    current = read_file(root_fd, record["path"])
                    if current is None or not same_snapshot(current[1], record["before"]):
                        raise ReleaseError("File changed before its backup was captured: " + record["path"])
                    atomic_write(backup_fd, "before/" + record["path"], current[0], private=True)
                    saved = read_file(backup_fd, "before/" + record["path"])
                    if saved is None or saved[1]["sha256"] != record["before"]["sha256"]:
                        raise ReleaseError("Backup verification failed: " + record["path"])
                serialized_manifest = json_bytes(manifest)
                transaction = {"kind": GLOBAL_TRANSACTION_KIND if global_frontend else TRANSACTION_KIND, "schema_version": SCHEMA, "root": str(root),
                               "created_at": utc_now(), "archive_sha256": archive_sha, "source": manifest["source"],
                               "release_manifest_sha256": digest(serialized_manifest),
                               "status": "prepared", "files": changes, "newly_created": [item["path"] for item in changes if item["before"] is None],
                               "applied": [], "inflight": None, "restored": []}
                atomic_write(backup_fd, "release-manifest.json", serialized_manifest, private=True)
                store_transaction(backup_fd, transaction)
                try:
                    transaction["status"] = "applying"
                    store_transaction(backup_fd, transaction)
                    for record in changes:
                        path = record["path"]
                        if not same_snapshot(current_snapshot(root_fd, path), record["before"]):
                            raise ReleaseError("File changed during installation: " + path)
                        transaction["inflight"] = path
                        store_transaction(backup_fd, transaction)
                        atomic_write(root_fd, path, payload[path], record["before"] or record["after"])
                        actual = current_snapshot(root_fd, path)
                        if not same_snapshot(actual, record["after"]):
                            raise ReleaseError("Installed checksum or metadata mismatch: " + path)
                        record["after"] = actual
                        transaction["applied"].append(path)
                        transaction["inflight"] = None
                        store_transaction(backup_fd, transaction)
                    for path, entry in entries.items():
                        current = current_snapshot(root_fd, path)
                        if current is None or (current["sha256"], current["size"]) != (entry["sha256"], entry["size"]):
                            raise ReleaseError("Post-installation checksum mismatch: " + path)
                    transaction["status"] = "applied"
                    transaction["applied_at"] = utc_now()
                    store_transaction(backup_fd, transaction)
                except BaseException as error:
                    try:
                        with ignore_repeated_interrupts():
                            perform_rollback(root_fd, backup_fd, transaction)
                    except BaseException as rollback_error:
                        raise ReleaseError("Installation failed and rollback needs review. Backup: " + str(backup_path) + "; " + str(rollback_error)) from error
                    raise ReleaseError("Installation failed; its file changes were rolled back. Backup: " + str(backup_path) + "; " + str(error)) from error
                report.update(status="applied", backup=str(backup_path), backup_name=backup_name,
                              replace=[item["path"] for item in changes if item["before"] is not None],
                              create=[item["path"] for item in changes if item["before"] is None], unchanged=unchanged)
                return report
            finally:
                os.close(backup_fd)


def rollback_release(root: Path, backup_dir: Path, backup_name: str, apply: bool = False, global_frontend: bool = False) -> dict:
    prefix = "frontend" if global_frontend else "play"
    if not re.fullmatch(prefix + r"-[0-9]{8}T[0-9]{6}Z-[0-9a-f]{12}-[0-9a-f]{8}", backup_name):
        raise ReleaseError("--rollback must name one generated backup for the selected scope; global backups require --global-frontend")
    validate_locations(root, backup_dir)
    with open_absolute_directory(root) as root_fd, open_absolute_directory(backup_dir) as store_fd:
        backup_fd = os.open(backup_name, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW, dir_fd=store_fd)
        try:
            transaction = load_transaction(backup_fd, root, global_frontend)
            plan = rollback_plan(root_fd, backup_fd, transaction)
            report = {"operation": "rollback", "mode": "apply" if apply else "dry-run", "status": "ready",
                      "root": str(root), "backup": str(backup_dir / backup_name), "restore_or_remove": [record["path"] for record, _ in plan]}
            if not apply:
                return report
            with installation_lock(store_fd, root):
                transaction = load_transaction(backup_fd, root, global_frontend)
                report["restored"] = perform_rollback(root_fd, backup_fd, transaction)
                report["status"] = "rolled_back"
                return report
        finally:
            os.close(backup_fd)


def self_test() -> dict:
    """Temp-only integration tests; never use a real web root or network."""
    checks = []
    with tempfile.TemporaryDirectory(prefix="osgard-play-release-test-") as temporary:
        base = Path(temporary)
        root = base / "html"
        root.mkdir()
        store = base / "backups"
        protected = {"index.html": b"ORIGINAL WORLD HOME", "nginx.conf": b"DO NOT CHANGE NGINX",
                     "games/null-shift-godot/index.wasm": b"GODOT LIVE SENTINEL",
                     "games/null-shift-godot/index.pck": b"GODOT LIVE SCENE",
                     "games/remix/player/Build/REMIX-live.wasm.gz": b"UNITY LIVE SENTINEL",
                     "games/vector-zero/save-state.dat": b"UNRELATED VECTOR DATA",
                     "games/time/runtime-new.js": b"UNRELATED NEW TIME RESOURCE",
                     "games/time-empire/index.html": b"STANDALONE EMPIRE MUST REMAIN",
                     "brand/play/another-sprite.svg": b"UNRELATED SVG RESOURCE",
                     "server/private.db": b"PROTECTED DATABASE"}
        original = {"play/index.html": b"old play", "play/world/vector-zero/index.html": b"old detail",
                    "games/index.html": b"old games alias", "entertainment/index.html": b"old entertainment alias",
                    "games/time/index.html": b'<script type="module" src="/assets/index-OLD12345.js"></script>',
                    "brand/play/ui-icons.svg": b'<svg xmlns="http://www.w3.org/2000/svg"><symbol id="old"/></svg>',
                    "games/vector-zero/index.html": b"old audited vector game"}
        for path, data in {**protected, **original}.items():
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        payload = {"assets/PlayHome-A1b2C3d4.js": b"export const play = true;", "brand/play/vector-zero.webp": b"RIFFTESTWEBP",
                   "play/index.html": b"new play", "play/world/vector-zero/index.html": b"new detail",
                   "games/index.html": b"new games alias", "entertainment/index.html": b"new entertainment alias",
                   "games/time/index.html": b'<script type="module" src="/assets/PlayHome-A1b2C3d4.js"></script>',
                   "brand/play/ui-icons.svg": b'<svg xmlns="http://www.w3.org/2000/svg"><symbol id="orbit"/></svg>',
                   "games/vector-zero/index.html": b"verified vector game bugfix"}
        manifest = {"kind": KIND, "schema_version": SCHEMA, "created_at": utc_now(), "path_allowlist": PATH_POLICY,
                    "source": {"git_commit": "a" * 40, "working_tree_dirty": False},
                    "expected_previous": {path: digest(original[path]) for path in GAME_FIX_PATHS},
                    "files": [{"path": path, "size": len(data), "sha256": digest(data)} for path, data in payload.items()]}

        def archive_to(path, data_payload=None, extra=None, file_manifest=None):
            with tarfile.open(path, "w:gz", format=tarfile.USTAR_FORMAT) as archive:
                raw = json_bytes(manifest if file_manifest is None else file_manifest)
                member = tarfile.TarInfo("manifest.json"); member.size = len(raw)
                archive.addfile(member, io.BytesIO(raw))
                for name, data in (payload if data_payload is None else data_payload).items():
                    member = tarfile.TarInfo("payload/" + name); member.size = len(data)
                    archive.addfile(member, io.BytesIO(data))
                if extra:
                    archive.addfile(*extra)

        def must_reject(action, label):
            try:
                action()
            except (ReleaseError, OSError):
                checks.append(label)
            else:
                raise AssertionError("Expected rejection: " + label)

        def assert_protected():
            for name, data in protected.items():
                assert (root / name).read_bytes() == data, "Protected path changed: " + name

        archive = base / "release.tar.gz"
        archive_to(archive)
        plan = install_release(root, archive, store)
        assert plan["mode"] == "dry-run" and not store.exists()
        assert all((root / name).read_bytes() == data for name, data in original.items())
        checks.append("dry-run leaves document root and backup store unchanged")
        applied = install_release(root, archive, store, apply=True)
        assert all((root / name).read_bytes() == data for name, data in payload.items())
        assert_protected()
        checks.append("apply preserves Godot, Unity, root index, Nginx and backend sentinels")
        assert (root / "games/time/index.html").read_bytes() == payload["games/time/index.html"]
        assert (root / "brand/play/ui-icons.svg").read_bytes() == payload["brand/play/ui-icons.svg"]
        checks.append("Time React shell and exact icon sprite update without touching neighboring runtime or SVG files")
        backup_name = applied["backup_name"]
        rollback_release(root, store, backup_name)
        assert (root / "play/index.html").read_bytes() == payload["play/index.html"]
        rollback_release(root, store, backup_name, apply=True)
        assert all((root / name).read_bytes() == data for name, data in original.items())
        assert not (root / "assets/PlayHome-A1b2C3d4.js").exists()
        assert not (root / "brand/play/vector-zero.webp").exists()
        assert_protected()
        rollback_release(root, store, backup_name, apply=True)
        checks.append("rollback restores only replaced files, removes only new files and is idempotent")

        bad = base / "bad-checksum.tar.gz"
        archive_to(bad, {**payload, "play/index.html": b"bad play"})
        must_reject(lambda: install_release(root, bad, store, apply=True), "corrupt checksum rejected before install")
        traversal = tarfile.TarInfo("payload/../escape.txt"); traversal.size = 4
        bad = base / "traversal.tar.gz"; archive_to(bad, extra=(traversal, io.BytesIO(b"evil")))
        must_reject(lambda: install_release(root, bad, store, apply=True), "archive traversal rejected")
        link = tarfile.TarInfo("payload/brand/play/evil.webp"); link.type = tarfile.SYMTYPE; link.linkname = "../../index.html"
        bad = base / "symlink.tar.gz"; archive_to(bad, extra=(link,))
        must_reject(lambda: install_release(root, bad, store, apply=True), "archive symlink rejected")
        art_dir = root / "brand/play"
        saved_art = base / "saved-art"
        art_dir.rename(saved_art)
        outside = base / "outside"; outside.mkdir()
        art_dir.symlink_to(outside, target_is_directory=True)
        must_reject(lambda: install_release(root, archive, store, apply=True), "document-root parent symlink rejected")
        art_dir.unlink()
        saved_art.rename(art_dir)
        collision = root / "assets/PlayHome-A1b2C3d4.js"
        collision.write_bytes(b"a different shared asset")
        must_reject(lambda: install_release(root, archive, store, apply=True), "existing hashed asset collision rejected")
        collision.unlink()

        fresh_game = root / "games/vector-zero/index.html"
        fresh_game.write_bytes(b"A NEWER SEPARATELY PUBLISHED GAME")
        must_reject(lambda: install_release(root, archive, store, apply=True), "newer VECTOR//ZERO runtime is protected by its expected previous checksum")
        assert fresh_game.read_bytes() == b"A NEWER SEPARATELY PUBLISHED GAME"
        assert not collision.exists()
        fresh_game.write_bytes(original["games/vector-zero/index.html"])
        must_reject(lambda: require_allowed("games/vector-zero/another-file.js"), "fixed game exception does not allow sibling runtime files")
        must_reject(lambda: require_allowed("games/time/runtime-new.js"), "Time shell exception does not allow other runtime files")
        must_reject(lambda: require_allowed("brand/play/another-sprite.svg"), "fixed sprite exception does not allow arbitrary SVG files")

        applied = install_release(root, archive, store, apply=True)
        (root / "play/index.html").write_bytes(b"USER CHANGED THIS AFTER RELEASE")
        must_reject(lambda: rollback_release(root, store, applied["backup_name"], apply=True), "rollback conflict leaves subsequent user changes intact")
        assert (root / "play/index.html").read_bytes() == b"USER CHANGED THIS AFTER RELEASE"
        assert (root / "assets/PlayHome-A1b2C3d4.js").exists()
        (root / "play/index.html").write_bytes(payload["play/index.html"])
        rollback_release(root, store, applied["backup_name"], apply=True)
        assert_protected()

        real_write = globals()["atomic_write"]
        def injected_write(fd, path, data, metadata=None, private=False):
            if path == "play/index.html" and data == payload[path]:
                raise OSError("Injected installation failure")
            return real_write(fd, path, data, metadata, private)
        globals()["atomic_write"] = injected_write
        try:
            must_reject(lambda: install_release(root, archive, store, apply=True), "mid-installation error triggers selective automatic rollback")
        finally:
            globals()["atomic_write"] = real_write
        assert all((root / name).read_bytes() == data for name, data in original.items())
        assert not (root / "assets/PlayHome-A1b2C3d4.js").exists()
        assert_protected()

        # The explicit global release is a different contract. Exercise it on
        # the same root with live standalone pages and private files present.
        global_protected = {name: data for name, data in protected.items() if name != "index.html"}
        global_protected.update({
            "games/null-shift-godot/index.html": b"LIVE GODOT ENTRY MUST REMAIN",
            "games/remix/player/index.html": b"LIVE UNITY ENTRY MUST REMAIN",
            "account/current-session.json": b"PRIVATE AUTH SENTINEL",
            "api/auth/session.json": b"SERVER SESSION SENTINEL",
            "brand/intro/unrelated.webp": b"UNRELATED INTRO RESOURCE",
        })
        for path, data in {**global_protected, "account/index.html": b"old account React shell"}.items():
            target = root / path
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(data)
        baseline = {path.relative_to(root).as_posix(): path.read_bytes() for path in root.rglob("*") if path.is_file()}
        global_payload = {**payload,
                          **{path: ("new React shell: " + path).encode() for path in GLOBAL_HTML_PATHS},
                          **{path: ("RIFF WEBP intro: " + path).encode() for path in INTRO_ASSET_PATHS}}
        global_manifest = {**manifest, "kind": GLOBAL_KIND, "path_allowlist": GLOBAL_PATH_POLICY,
                           "files": [{"path": path, "size": len(data), "sha256": digest(data)} for path, data in global_payload.items()]}
        global_archive = base / "global-release.tar.gz"
        archive_to(global_archive, global_payload, file_manifest=global_manifest)

        def assert_global_restored():
            actual = {path.relative_to(root).as_posix(): path.read_bytes() for path in root.rglob("*") if path.is_file()}
            assert actual == baseline, "Global rollback changed files outside the release or left newly-created files"

        def assert_global_protected():
            assert all((root / path).read_bytes() == data for path, data in global_protected.items())

        must_reject(lambda: install_release(root, global_archive, store, apply=True), "global archive cannot broaden default PLAY scope without an explicit flag")
        must_reject(lambda: install_release(root, archive, store, apply=True, global_frontend=True), "PLAY archive cannot masquerade as a complete global release")
        assert_global_restored()
        for forbidden in ("index.html", "brand/intro/osgard-emblem.webp"):
            must_reject(lambda path=forbidden: require_allowed(path), "default PLAY allowlist still excludes " + forbidden)
        for forbidden in ("games/null-shift-godot/index.html", "games/remix/player/index.html", "games/time-empire/index.html",
                          "play/world/unreviewed-game/index.html", "brand/intro/unrelated.webp", "account/current-session.json"):
            must_reject(lambda path=forbidden: require_allowed(path, True), "global fixed registry rejects " + forbidden)
        incomplete_shell = {**global_manifest, "files": [entry for entry in global_manifest["files"] if entry["path"] != "account/index.html"]}
        must_reject(lambda: validate_manifest(incomplete_shell, True), "global manifest cannot omit a reviewed account shell")
        incomplete_intro = {**global_manifest, "files": [entry for entry in global_manifest["files"] if entry["path"] != "brand/intro/osgard-emblem.webp"]}
        must_reject(lambda: validate_manifest(incomplete_intro, True), "global manifest requires all six exact intro assets")

        global_store = base / "global-backups"
        global_plan = install_release(root, global_archive, global_store, global_frontend=True)
        assert global_plan["mode"] == "dry-run" and not global_store.exists()
        assert global_plan["release_kind"] == GLOBAL_KIND and "index.html" in global_plan["replace"]
        assert_global_restored()
        checks.append("global dry-run previews root and all generated shells without creating a backup")
        installed_global = install_release(root, global_archive, global_store, apply=True, global_frontend=True)
        assert len(GLOBAL_HTML_PATHS) == 83 and len(INTRO_ASSET_PATHS) == 6
        assert all((root / name).read_bytes() == data for name, data in global_payload.items())
        assert_global_protected()
        checks.append("global apply updates exactly 83 React shells and six intro assets while preserving standalone games and auth data")
        global_backup = installed_global["backup_name"]
        must_reject(lambda: rollback_release(root, global_store, global_backup, apply=True), "global rollback also requires the explicit global scope")
        (root / "index.html").write_bytes(b"NEW ROOT CHANGED AFTER GLOBAL RELEASE")
        must_reject(lambda: rollback_release(root, global_store, global_backup, apply=True, global_frontend=True), "global rollback conflict protects subsequent root changes before restoring any file")
        assert (root / "index.html").read_bytes() == b"NEW ROOT CHANGED AFTER GLOBAL RELEASE"
        assert (root / "account/index.html").read_bytes() == global_payload["account/index.html"]
        (root / "index.html").write_bytes(global_payload["index.html"])
        rollback_release(root, global_store, global_backup, apply=True, global_frontend=True)
        rollback_release(root, global_store, global_backup, apply=True, global_frontend=True)
        assert_global_restored()
        checks.append("global rollback restores prior shells and removes only release-created files; retry is safe")

        bad_global = base / "bad-global-checksum.tar.gz"
        archive_to(bad_global, {**global_payload, "index.html": b"DAMAGED GLOBAL ROOT"}, file_manifest=global_manifest)
        must_reject(lambda: install_release(root, bad_global, global_store, apply=True, global_frontend=True), "global root checksum corruption is rejected before writes")
        def injected_global_write(fd, path, data, metadata=None, private=False):
            if path == "intelligence/index.html" and data == global_payload[path]:
                raise OSError("Injected failure after replacing the global root")
            return real_write(fd, path, data, metadata, private)
        globals()["atomic_write"] = injected_global_write
        try:
            must_reject(lambda: install_release(root, global_archive, global_store, apply=True, global_frontend=True), "global mid-installation failure rolls back root, shells and assets selectively")
        finally:
            globals()["atomic_write"] = real_write
        assert_global_restored()
    return {"status": "PASS", "tests": len(checks), "checks": checks}


def main(argv=None) -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--root", help="Existing absolute document-root directory")
    parser.add_argument("--archive", type=Path, help="Verified selective release .tar.gz")
    parser.add_argument("--backup-dir", help="Absolute backup store outside the document root")
    parser.add_argument("--rollback", metavar="BACKUP_NAME", help="Restore one generated backup directory by name")
    parser.add_argument("--apply", action="store_true", help="Actually change release files; otherwise only inspect")
    parser.add_argument("--global-frontend", action="store_true", help="Explicitly select all 83 reviewed React shells and six fixed intro images; required for global install and rollback")
    parser.add_argument("--self-test", action="store_true", help="Run integration checks in a new temporary fixture")
    args = parser.parse_args(argv)
    try:
        ensure_posix()
        if args.self_test:
            if args.root or args.archive or args.backup_dir or args.rollback or args.apply or args.global_frontend:
                raise ReleaseError("--self-test cannot be combined with installation arguments")
            report = self_test()
        else:
            if not args.root or not args.backup_dir or bool(args.archive) == bool(args.rollback):
                parser.error("Supply --root, --backup-dir and exactly one of --archive or --rollback")
            root = absolute_directory(args.root, "--root")
            backups = absolute_directory(args.backup_dir, "--backup-dir")
            with interrupted_apply() if args.apply else contextlib.nullcontext():
                report = rollback_release(root, backups, args.rollback, args.apply, args.global_frontend) if args.rollback else install_release(root, args.archive, backups, args.apply, args.global_frontend)
        print(json.dumps(report, ensure_ascii=False, indent=2))
        return 0
    except (ReleaseError, OSError, ValueError) as error:
        print(json.dumps({"status": "REJECTED", "error": str(error)}, ensure_ascii=False), file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
