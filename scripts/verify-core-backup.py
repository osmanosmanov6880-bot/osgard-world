#!/usr/bin/env python3
"""Inspect a Core snapshot on a private copy; optionally bind its backup metadata.

This inspection does not start the application. Use core-recovery-drill.py for
the complete local HTTP backup/restore exercise.
"""
import argparse
import json
import sqlite3
import sys
import tempfile
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "server"))
from core_backup import (CORE_COLUMNS, checked_path, checked_sha, check_sqlite, copy_snapshot,
                         digest, read_metadata, regular_reader,
                         validate_binding)

def validate_source(path):
    with regular_reader(path, standalone=True):
        pass

def drill(source, expected_sha256=None, sqlite_only=False, *, metadata_path=None, require_core=None):
    """Inspect Core by default; explicit generic inspection never claims a Core restore.

    ``require_core=False`` remains a supported API spelling of ``sqlite_only=True``.
    A manifest always requires the Core profile; contradictory explicit modes fail.
    """
    started = time.perf_counter()
    if sqlite_only and (require_core is True or metadata_path is not None):
        raise ValueError("--sqlite-only cannot be combined with --require-core or --manifest.")
    require_core = not sqlite_only if require_core is None else require_core
    source = checked_path(source)
    validate_source(source)
    expected = checked_sha(expected_sha256) if expected_sha256 is not None else None
    metadata = None
    metadata_sha = None
    if metadata_path is not None:
        metadata, metadata_sha = read_metadata(metadata_path)
        if expected is not None and expected != metadata["database"]["sha256"]:
            raise ValueError("Trusted SHA-256 does not match backup metadata.")
        expected = metadata["database"]["sha256"]
        require_core = True
    with tempfile.TemporaryDirectory(prefix="osgard-restore-drill-") as working:
        target = Path(working) / "restored.sqlite3"
        copied = copy_snapshot(source, target, expected)
        schema = check_sqlite(target, require_core=require_core)
        if metadata is not None:
            validate_binding(source, copied, schema, metadata)
        return {"status": "passed", **copied,
                "expected_sha256_verified": expected_sha256 is not None,
                "table_count": len(schema["tables"]), "schema_version": schema["user_version"],
                "foreign_key_check": "passed", "integrity_check": "passed",
                "core_schema_checked": bool(require_core), "foreign_keys_checked": True,
                "validation_scope": "core_schema_and_sqlite" if require_core else "sqlite_only",
                "metadata_bound": metadata is not None, "manifest_sha256": metadata_sha,
                "service_started": False, "application_restore_tested": False,
                "application_restore_validated": False,
                "verification_seconds": round(time.perf_counter() - started, 6),
                "rto_seconds": None, "rpo_seconds": None,
                "restored_to": "ephemeral_private_directory", "production_modified": False}

def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", type=Path, help="a consistent, stopped or SQLite-backup-API snapshot")
    parser.add_argument("--sha256", help="expected 64-character SHA-256 digest")
    parser.add_argument("--manifest", type=Path, help="bound Core backup manifest; requires the Core schema")
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--require-core", action="store_true", default=None,
                      help="explicitly require the default Core v1 schema profile")
    mode.add_argument("--sqlite-only", action="store_true",
                      help="diagnose generic SQLite without asserting Core schema compatibility")
    parser.add_argument("--json", action="store_true")
    args = parser.parse_args(argv)
    try:
        report = drill(args.backup, args.sha256, args.sqlite_only,
                       metadata_path=args.manifest, require_core=args.require_core)
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
