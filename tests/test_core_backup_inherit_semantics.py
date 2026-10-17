"""Offline semantic INHERIT verification of a consistent Core backup.

Only isolated synthetic SQLite fixtures are used. Never read production data.
"""
import importlib.util
from pathlib import Path
import sqlite3
import sys
import unittest

from test_core_inherit import InheritFixture

ROOT=Path(__file__).resolve().parents[1]
sys.path.insert(0,str(ROOT/"server"))
from core_backup import backup

spec=importlib.util.spec_from_file_location("backup_semantics",ROOT/"scripts/verify-core-backup.py")
verifier=importlib.util.module_from_spec(spec)
spec.loader.exec_module(verifier)


class InheritBackupSemanticTests(InheritFixture,unittest.TestCase):
    def verified_backup(self):
        path=self.base/"restore-readonly.sqlite3"
        checksum=backup(self.store.path,path)
        raw=path.read_bytes()
        result=verifier.drill(path,checksum)
        self.assertEqual(path.read_bytes(),raw)
        return path,result

    def test_empty_lineage_is_checked_not_silently_skipped(self):
        _,report=self.verified_backup()
        self.assertTrue(report["inherit_lineage_checked"])
        self.assertEqual(report["inherit_worlds_verified"],0)
        self.assertEqual(report["inherit_generations_verified"],0)

    def test_immutable_chain_in_backup_passes_with_bounded_counts(self):
        first=self.create("local-copy",[dict(type="stone",x=12,y=30)])
        second=self.append(first)["world"]
        third=self.append(second,x=51)["world"]
        _,report=self.verified_backup()
        self.assertEqual(report["inherit_worlds_verified"],1)
        self.assertEqual(report["inherit_generations_verified"],2)
        self.assertTrue(report["core_schema_checked"])
        self.assertTrue(report["foreign_keys_checked"])

    def test_tip_corruption_fails_despite_sqlite_page_integrity(self):
        world=self.append(self.create())["world"]
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_worlds SET objects='[]' WHERE id=?",(world["id"],))
            self.assertEqual(db.execute("PRAGMA integrity_check").fetchone()[0],"ok")
        target=self.base/"corrupt-tip.sqlite3"
        backup(self.store.path,target)
        with self.assertRaisesRegex(ValueError,"lineage integrity check failed"):
            verifier.drill(target)

    def test_changed_baseline_and_history_fail_without_leaking_objects(self):
        first=self.create("local-copy",[dict(type="stone",x=2,y=8)])
        self.append(first)
        with self.store.transaction() as db:
            db.execute("UPDATE inherit_worlds SET baseline='[]' WHERE id=?",(first["id"],))
        target=self.base/"bad-baseline.sqlite3"
        backup(self.store.path,target)
        with self.assertRaises(ValueError) as failure:
            verifier.drill(target)
        self.assertNotIn(first["id"],str(failure.exception))
        self.assertNotIn("stone",str(failure.exception))

    def test_generic_sqlite_only_does_not_claim_lineage_audit(self):
        path=self.base/"unrelated.sqlite3"
        with sqlite3.connect(path) as db:
            db.execute("CREATE TABLE other (id INTEGER)")
        report=verifier.drill(path,sqlite_only=True)
        self.assertFalse(report["core_schema_checked"])
        self.assertFalse(report["inherit_lineage_checked"])
        self.assertEqual(report["inherit_worlds_verified"],0)


if __name__=="__main__":
    unittest.main()
