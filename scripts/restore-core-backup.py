#!/usr/bin/env python3
"""Restore a metadata-bound Core backup offline into an explicitly new directory.

No server is started, no production configuration is changed, and the source
snapshot remains read-only. Custom live volume roots can be denied explicitly.
"""
import argparse
import json
from pathlib import Path
import sqlite3
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "server"))
from core_backup import restore_backup


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("backup", type=Path)
    parser.add_argument("--manifest", required=True, type=Path)
    parser.add_argument("--target-dir", required=True, type=Path, help="new private directory; its parent must already exist")
    parser.add_argument("--sha256", help="independently recorded backup SHA-256")
    parser.add_argument("--protected-root", action="append", default=[], type=Path, help="additional live/published root that must never receive this restore")
    args = parser.parse_args(argv)
    try:
        report = restore_backup(args.backup, args.manifest, args.target_dir,
                                expected_sha256=args.sha256, protected_roots=args.protected_root)
    except (ValueError, OSError, sqlite3.Error) as error:
        print("CORE RESTORE FAILED: " + str(error), file=sys.stderr)
        return 2
    print(json.dumps(report, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
