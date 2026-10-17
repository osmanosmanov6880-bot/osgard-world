"""Joint INHERIT lineage and Core REMIX match-journal recovery boundary.

Every backup is an independent SQLite copy made from this test's disposable Core
database. No production DB is accessed; corruption is injected into private
copies only and rejected verification must never modify an input file.
"""
from contextlib import closing
import hashlib
import importlib.util
from pathlib import Path
import sqlite3
import sys
import tempfile
import unittest
import uuid

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))

import core_inherit
from core_backup import backup
from core_commerce import Config
from core_server import Store

spec = importlib.util.spec_from_file_location(
    "remix_inherit_joint_backup_verifier", ROOT / "scripts/verify-core-backup.py")
verifier = importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class CoreRemixBackupSemanticsTests(unittest.TestCase):
    def setUp(self):
        self.scratch = tempfile.TemporaryDirectory(prefix="osgard-joint-backup-")
        self.addCleanup(self.scratch.cleanup)
        self.root = Path(self.scratch.name)
        self.database = self.root / "core.sqlite3"
        self.store = Store(self.database,
                           commerce_config=Config(enabled=False), enable_remix=True)
        self.actor = uuid.uuid4().hex
        with self.store.transaction() as db:
            db.execute("INSERT INTO users VALUES(?,?,?,?,?)",
                       (self.actor, "joint-backup-" + self.actor[:10], "00",
                        "no-password-fixture", "2026-01-01T00:00:00Z"))
        self.world = self.store.mutate(core_inherit.PREFIX + "worlds", self.actor,
            dict(title="Private backup world", template=core_inherit.TEMPLATE,
                 source="template", objects=[]), uuid.uuid4().hex)["world"]
        self.challenge = self.store.remix.mutate("challenges", self.actor,
            dict(title="Owned backup arena", seed=42), uuid.uuid4().hex)
        self.match = self.store.remix.mutate("matches", self.actor,
            dict(challengeId=self.challenge["id"]), uuid.uuid4().hex)
        self.accepted = self.store.remix.mutate(
            "matches/" + self.match["id"] + "/input", self.actor,
            dict(sequence=1, moveX=-1, moveY=0, jump=False), uuid.uuid4().hex)
        self.assertEqual(self.accepted["sequence"], 1)

    def snapshot(self):
        path = self.root / (uuid.uuid4().hex + ".sqlite3")
        checksum = backup(self.database, path)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), checksum)
        with closing(sqlite3.connect(path)) as db:
            self.assertEqual(db.execute("PRAGMA journal_mode=DELETE").fetchone()[0].lower(),
                             "delete")
        return path

    def test_valid_combined_wal_snapshot_verifies_both_games(self):
        path = self.snapshot()
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        result = verifier.drill(path, sha)
        self.assertEqual(result["status"], "passed")
        self.assertTrue(result["expected_sha256_verified"])
        self.assertTrue(result["inherit_lineage_checked"])
        self.assertEqual(result["inherit_worlds_checked"], 1)
        self.assertTrue(result["remix_journal_checked"])
        self.assertEqual(result["remix_challenges_checked"], 1)
        self.assertEqual(result["remix_matches_checked"], 1)
        self.assertFalse(result["production_modified"])
        self.assertFalse(result["application_restore_validated"])
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), sha)

    def test_corrupted_active_state_checkpoint_and_ack_are_rejected(self):
        for table, col, where in (
            ("remix_matches", "state_json", "id"),
            ("remix_inputs", "checkpoint_json", "match_id"),
            ("remix_inputs", "response_json", "match_id"),
        ):
            with self.subTest(table=table, column=col):
                path = self.snapshot()
                with closing(sqlite3.connect(path)) as db:
                    db.execute(f"UPDATE {table} SET {col}='{{}}' WHERE {where}=?",
                               (self.match["id"],))
                    db.commit()
                    self.assertEqual(db.execute("PRAGMA integrity_check").fetchone(),
                                     ("ok",))
                sha = hashlib.sha256(path.read_bytes()).hexdigest()
                with self.assertRaisesRegex(ValueError, "REMIX match journal"):
                    verifier.drill(path)
                self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), sha)

    def test_invalid_challenge_geometry_is_rejected_even_without_completed_run(self):
        path = self.snapshot()
        with closing(sqlite3.connect(path)) as db:
            db.execute("UPDATE remix_challenges SET arena_json='{}' WHERE id=?",
                       (self.challenge["id"],))
            db.commit()
        sha = hashlib.sha256(path.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, "REMIX challenge or replay"):
            verifier.drill(path)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), sha)

    def test_inherit_semantic_integrity_still_rejects_corrupt_tips(self):
        path = self.snapshot()
        with closing(sqlite3.connect(path)) as db:
            db.execute("UPDATE inherit_worlds SET baseline='invalid JSON fixture' WHERE id=?",
                       (self.world["id"],))
            db.commit()
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, "INHERIT world lineage"):
            verifier.drill(path)
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)

    def test_partial_remix_schema_fails_closed(self):
        path = self.snapshot()
        with closing(sqlite3.connect(path)) as db:
            db.execute("DROP TABLE remix_operations")
            db.commit()
        with self.assertRaisesRegex(ValueError, "Core backup is missing an expected table"):
            verifier.drill(path)

    def test_generic_sqlite_inspection_does_not_claim_game_semantics(self):
        path = self.snapshot()
        with closing(sqlite3.connect(path)) as db:
            db.execute("UPDATE remix_inputs SET checkpoint_json='{}'")
            db.commit()
        generic = verifier.drill(path, sqlite_only=True)
        self.assertEqual(generic["status"], "passed")
        self.assertFalse(generic["core_schema_checked"])
        self.assertFalse(generic["inherit_lineage_checked"])
        self.assertFalse(generic["remix_journal_checked"])
        with self.assertRaisesRegex(ValueError, "REMIX match journal"):
            verifier.drill(path)

    def test_pre_remix_core_backup_remains_compatible(self):
        database = self.root / "legacy.sqlite3"
        Store(database, commerce_config=Config(enabled=False))
        path = self.root / "legacy-backup.sqlite3"
        backup(database, path)
        report = verifier.drill(path)
        self.assertTrue(report["core_schema_checked"])
        self.assertFalse(report["remix_journal_checked"])
        self.assertEqual(report["remix_matches_checked"], 0)
        self.assertTrue(report["inherit_lineage_checked"])


if __name__ == "__main__":
    unittest.main()
