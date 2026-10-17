#!/usr/bin/env python3
"""Recovery validation uses synthetic SQLite files only; no production data."""
from contextlib import closing
import importlib.util
import json
import os
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
        with closing(sqlite3.connect(self.backup)) as db:
            db.execute("CREATE TABLE records (id INTEGER PRIMARY KEY, label TEXT)")
            db.execute("INSERT INTO records (label) VALUES ('private synthetic value')")
            db.commit()

    def generic(self, path=None, checksum=None):
        return module.drill(path or self.backup, checksum, sqlite_only=True)

    def test_private_restore_is_read_only_and_reports_its_limits(self):
        before = self.backup.read_bytes()
        result = self.generic()
        self.assertEqual(result["status"], "passed")
        self.assertEqual(result["table_count"], 1)
        self.assertFalse(result["production_modified"])
        self.assertFalse(result["core_schema_checked"])
        self.assertFalse(result["application_restore_validated"])
        self.assertIsNone(result["rto_seconds"])
        self.assertIsNone(result["rpo_seconds"])
        self.assertNotIn("private synthetic value", json.dumps(result))
        self.assertEqual(self.backup.read_bytes(), before)

    def test_expected_hash_is_verified_and_wrong_hash_is_rejected(self):
        checksum = module.digest(self.backup)
        result = self.generic(checksum=checksum)
        self.assertEqual(result["sha256"], checksum)
        self.assertTrue(result["expected_sha256_verified"])
        with self.assertRaisesRegex(ValueError, "checksum"):
            self.generic(checksum="0" * 64)
        with self.assertRaisesRegex(ValueError, "64 hex"):
            self.generic(checksum="not-a-sha")

    def test_corrupt_empty_and_non_database_files_are_rejected(self):
        for value in (b"SQLite format 3" + b"\0" * 300, b"", b"not a database"):
            with self.subTest(value=len(value)):
                self.backup.write_bytes(value)
                with self.assertRaises((ValueError, sqlite3.DatabaseError)):
                    self.generic()

    def test_empty_schema_is_rejected(self):
        self.backup.unlink()
        with closing(sqlite3.connect(self.backup)) as db:
            db.execute("PRAGMA user_version = 1")
        with self.assertRaisesRegex(ValueError, "no SQLite tables"):
            self.generic()

    def test_file_and_parent_symlinks_are_rejected(self):
        link = self.base / "link.sqlite3"
        link.symlink_to(self.backup)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.generic(link)
        parent = self.base / "linked-directory"
        parent.symlink_to(self.base, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, "symlink"):
            self.generic(parent / self.backup.name)

    @unittest.skipUnless(hasattr(os, "mkfifo"), "POSIX named pipe regression")
    def test_named_pipe_is_rejected_without_blocking(self):
        pipe = self.base / "pipe.sqlite3"
        os.mkfifo(pipe)
        with self.assertRaisesRegex(ValueError, "regular file"):
            self.generic(pipe)

    def test_even_empty_sidecars_are_not_treated_as_a_standalone_snapshot(self):
        for suffix in ("-wal", "-shm", "-journal"):
            sidecar = self.backup.with_name(self.backup.name + suffix)
            with self.subTest(suffix=suffix):
                sidecar.touch()
                try:
                    with self.assertRaisesRegex(ValueError, "standalone snapshot"):
                        self.generic()
                finally:
                    sidecar.unlink()

    def test_integrity_check_alone_cannot_hide_broken_foreign_keys(self):
        with closing(sqlite3.connect(self.backup)) as db:
            db.execute("CREATE TABLE children (record_id INTEGER REFERENCES records(id))")
            db.execute("INSERT INTO children VALUES (999)")
            db.commit()
            self.assertEqual(db.execute("PRAGMA integrity_check").fetchone(), ("ok",))
        with self.assertRaisesRegex(ValueError, "foreign key integrity"):
            self.generic()

    def test_core_profile_rejects_generic_wrong_version_and_missing_columns(self):
        with self.assertRaisesRegex(ValueError, "Core schema version"):
            module.drill(self.backup)
        with closing(sqlite3.connect(self.backup)) as db:
            db.execute("PRAGMA user_version=1")
        with self.assertRaisesRegex(ValueError, "expected table"):
            module.drill(self.backup)
        with closing(sqlite3.connect(self.backup)) as db:
            for name in module.CORE_COLUMNS:
                db.execute(f'CREATE TABLE "{name}" (placeholder TEXT)')
        with self.assertRaisesRegex(ValueError, "expected columns"):
            module.drill(self.backup)

    def test_current_core_snapshot_is_accepted_without_environment_credentials(self):
        import sys
        sys.path.insert(0, str(ROOT / "server"))
        from core_server import Store
        from core_commerce import Config
        from core_backup import backup
        source = self.base / "synthetic-core.sqlite3"
        target = self.base / "consistent-core.sqlite3"
        store = Store(source, commerce_config=Config())
        with store.transaction() as db:
            db.execute("INSERT INTO users VALUES (?,?,?,?,?)",
                       ("synthetic-user", "synthetic-fixture", "00", "not-a-password-hash", "2026-01-01T00:00:00Z"))
        checksum = backup(source, target)
        before = target.read_bytes()
        result = module.drill(target, checksum)
        self.assertTrue(result["core_schema_checked"])
        self.assertTrue(result["foreign_keys_checked"])
        self.assertEqual(result["schema_version"], 1)
        self.assertGreaterEqual(result["table_count"], len(module.CORE_COLUMNS))
        self.assertEqual(target.read_bytes(), before)

    def test_core_profile_rejects_missing_runtime_refund_timestamp(self):
        import sys
        sys.path.insert(0, str(ROOT / "server"))
        from core_server import Store
        from core_commerce import Config
        source = self.base / "core-missing-refund-timestamp.sqlite3"
        store = Store(source, commerce_config=Config())
        with store.transaction() as db:
            db.execute("ALTER TABLE commerce_refund_ops DROP COLUMN started_at")
            self.assertEqual(db.execute("PRAGMA integrity_check").fetchone()[0], "ok")
            with self.assertRaisesRegex(sqlite3.OperationalError, "no such column: started_at"):
                db.execute("SELECT state,target_minor FROM commerce_refund_ops ORDER BY started_at DESC LIMIT 1")
        with self.assertRaisesRegex(ValueError, "expected columns"):
            module.drill(source)

    def test_active_wal_requires_backup_api_snapshot(self):
        with closing(sqlite3.connect(self.backup)) as source:
            source.execute("PRAGMA journal_mode=WAL")
            source.execute("INSERT INTO records(label) VALUES ('uncheckpointed synthetic row')")
            source.commit()
            with self.assertRaisesRegex(ValueError, "sidecar"):
                self.generic()
            snapshot = self.base / "consistent.sqlite3"
            with closing(sqlite3.connect(snapshot)) as destination:
                source.backup(destination)
            result = self.generic(snapshot)
            self.assertEqual(result["status"], "passed")


if __name__ == "__main__":
    unittest.main()
