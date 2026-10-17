#!/usr/bin/env python3
"""Read-only SQLite backup recovery drill. Never opens the production database."""
import argparse
import hashlib
import json
import os
import shutil
import sqlite3
import stat
import sys
import tempfile
from pathlib import Path

def digest(path):
    hasher = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            hasher.update(block)
    return hasher.hexdigest()

def validate_source(path):
    if path.is_symlink() or not path.is_file():
        raise ValueError("backup must be a regular file, not a symlink")
    if path.stat().st_size == 0:
        raise ValueError("empty backup file")
    if not os.access(path, os.R_OK):
        raise ValueError("backup is not readable")

def check_sqlite(path):
    # The temporary restored file is the only file opened by SQLite.
    uri = path.as_uri() + "?mode=ro&immutable=1"
    with sqlite3.connect(uri, uri=True, timeout=3) as db:
        result = db.execute("PRAGMA integrity_check").fetchone()
        if result != ("ok",):
            raise ValueError("SQLite integrity_check failed: " + repr(result))
        tables = [name for (name,) in db.execute(
            "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name")]
        if not tables:
            raise ValueError("no SQLite tables found")
        version = db.execute("PRAGMA user_version").fetchone()[0]
        return {"tables": tables, "user_version": version}

def drill(source, expected_sha256=None):
    source = Path(source).absolute()
    validate_source(source)
    if expected_sha256 is not None:
        expected_sha256 = expected_sha256.lower().strip()
        if len(expected_sha256) != 64 or any(c not in "0123456789abcdef" for c in expected_sha256):
            raise ValueError("expected sha256 must be 64 hex characters")
    before = source.stat()
    # The entire procedure is isolated under a private ephemeral directory.
    with tempfile.TemporaryDirectory(prefix="osgard-restore-drill-") as working:
        target = Path(working) / "restored.sqlite3"
        with source.open("rb") as original, target.open("xb") as restored:
            shutil.copyfileobj(original, restored, 1024 * 1024)
        os.chmod(target, stat.S_IRUSR | stat.S_IWUSR)
        source_digest = digest(source)
        if digest(target) != source_digest:
            raise ValueError("copy checksum mismatch")
        if expected_sha256 is not None and source_digest != expected_sha256:
            raise ValueError("checksum does not match expected SHA-256")
        schema = check_sqlite(target)
        after = source.stat()
        if (before.st_size, before.st_mtime_ns, before.st_ino) != (after.st_size, after.st_mtime_ns, after.st_ino):
            raise ValueError("backup changed while testing")
        # No row values or sensitive data are included in this report.
        return {"status": "passed", "sha256": source_digest, "bytes": before.st_size,
                "table_count": len(schema["tables"]), "schema_version": schema["user_version"],
                "restored_to": "ephemeral_private_directory", "production_modified": False}

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", type=Path, help="a consistent, stopped or SQLite-backup-API snapshot")
    parser.add_argument("--sha256", help="expected 64-character SHA-256 digest")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        report = drill(args.backup, args.sha256)
    except (ValueError, OSError, sqlite3.Error) as error:
        print("RECOVERY DRILL FAILED: " + str(error), file=sys.stderr)
        return 2
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2))
    else:
        print("RECOVERY DRILL PASSED: SQLite integrity OK, tables=", report["table_count"],
              "sha256=", report["sha256"], "private ephemeral restore only")
    return 0

if __name__ == "__main__":
    raise SystemExit(main())
