#!/usr/bin/env python3
"""Regression tests for production-independent Core SQLite recovery validation."""
import importlib.util
import sqlite3
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("verify_core_backup", ROOT / "scripts/verify-core-backup.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class RecoveryDrillTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.backup = self.base / "backup.sqlite3"
        with sqlite3.connect(self.backup) as db:
            db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY, label TEXT)")
            db.execute("INSERT INTO records (label) VALUES ('private test fixture')")

    def test_valid_private_restore(self):
        content = self.backup.read_bytes()
        result = module.drill(self.backup)
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["table_count"], 1)
        self.assertFalse(result["production_modified"])
        self.assertEqual(self.backup.read_bytes(), content)

    def test_expected_sha(self):
        result = module.drill(self.backup, module.digest(self.backup))
        self.assertEqual(result["sha256"], module.digest(self.backup))

    def test_wrong_sha_rejected(self):
        with self.assertRaisesRegex(ValueError, "checksum"):
            module.drill(self.backup, "0" * 64)

    def test_invalid_sha_rejected(self):
        with self.assertRaisesRegex(ValueError, "64 hex"):
            module.drill(self.backup, "not-a-sha")

    def test_corrupt_file_rejected(self):
        self.backup.write_bytes(b"SQLite format 3" + b"\0" * 300)
        with self.assertRaises((ValueError, sqlite3.DatabaseError)):
            module.drill(self.backup)

    def test_empty_file_rejected(self):
        self.backup.write_bytes(b"")
        with self.assertRaisesRegex(ValueError, "empty"):
            module.drill(self.backup)

    def test_symlink_rejected(self):
        link = self.base / "link.sqlite3"
        link.symlink_to(self.backup)
        with self.assertRaisesRegex(ValueError, "symlink"):
            module.drill(link)

    def test_non_database_file_rejected(self):
        self.backup.write_bytes(b"secret-not-a-database")
        with self.assertRaises(sqlite3.DatabaseError):
            module.drill(self.backup)

    def test_database_without_tables_rejected(self):
        self.backup.unlink()
        with sqlite3.connect(self.backup) as db:
            db.execute("PRAGMA user_version = 1")
        with self.assertRaisesRegex(ValueError, "no SQLite tables"):
            module.drill(self.backup)

if __name__ == "__main__":
    unittest.main()
