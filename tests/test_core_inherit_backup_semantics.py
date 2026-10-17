"""Backup acceptance must reject logically corrupt INHERIT data in valid SQLite files.

These tests modify disposable offline backup copies only. They never open or
modify production data, and the verifier must never repair a suspect snapshot.
"""
import hashlib
import json
import sqlite3
import unittest
import uuid

from test_core_inherit import InheritFixture, verifier, backup


class InheritBackupSemanticTests(InheritFixture, unittest.TestCase):
    def snapshot(self):
        dest = self.base / (uuid.uuid4().hex + '.sqlite3')
        checksum = backup(self.store.path, dest)
        self.assertEqual(hashlib.sha256(dest.read_bytes()).hexdigest(), checksum)
        return dest

    def mutate_copy(self, path, sql, args=()):
        with sqlite3.connect(path) as db:
            db.execute(sql, args)

    def assert_rejected(self, path):
        before = hashlib.sha256(path.read_bytes()).hexdigest()
        with self.assertRaisesRegex(ValueError, 'INHERIT world lineage or snapshot'):
            verifier.drill(path)
        # A failed read-only drill must leave its input byte-for-byte untouched.
        self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), before)

    def test_empty_inherit_schema_has_an_explicit_zero_world_attestation(self):
        copy = self.snapshot()
        report = verifier.drill(copy)
        self.assertTrue(report['inherit_lineage_checked'])
        self.assertEqual(report['inherit_worlds_checked'], 0)
        self.assertEqual(report['inherit_generations_checked'], 0)
        self.assertFalse(report['production_modified'])
        self.assertFalse(report['application_restore_validated'])

    def test_two_generation_backup_and_handoff_are_valid(self):
        start = self.create('local-copy', [dict(type='stone', x=9, y=12)])
        one = self.append(start)['world']
        invitation = self.offer(one)['invitation']
        after_handoff = self.accept(invitation)['world']
        self.append(after_handoff, 'next', x=67)
        copy = self.snapshot()
        checksum = hashlib.sha256(copy.read_bytes()).hexdigest()
        report = verifier.drill(copy, checksum)
        self.assertEqual(report['sha256'], checksum)
        self.assertTrue(report['expected_sha256_verified'])
        self.assertEqual(report['inherit_worlds_checked'], 1)
        self.assertEqual(report['inherit_generations_checked'], 2)
        self.assertTrue(report['inherit_lineage_checked'])
        self.assertEqual(hashlib.sha256(copy.read_bytes()).hexdigest(), checksum)

    def test_bad_baseline_hash_in_standalone_backup_is_detected(self):
        world = self.create('local-copy', [dict(type='stone', x=11, y=22)])
        copy = self.snapshot()
        self.mutate_copy(copy, "UPDATE inherit_worlds SET baseline='[]' WHERE id=?", (world['id'],))
        # SQLite itself sees no corruption; only application checks can reject it.
        with sqlite3.connect(copy) as db:
            self.assertEqual(db.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
        self.assert_rejected(copy)

    def test_invalid_baseline_json_is_detected(self):
        world = self.create()
        copy = self.snapshot()
        self.mutate_copy(copy, "UPDATE inherit_worlds SET baseline='no json' WHERE id=?", (world['id'],))
        self.assert_rejected(copy)

    def test_valid_json_with_wrong_world_tip_is_detected(self):
        world = self.append(self.create())['world']
        copy = self.snapshot()
        self.mutate_copy(copy, "UPDATE inherit_worlds SET objects='[]' WHERE id=?", (world['id'],))
        self.assert_rejected(copy)

    def test_corrupted_tip_hash_is_detected(self):
        world = self.append(self.create())['world']
        copy = self.snapshot()
        self.mutate_copy(copy, "UPDATE inherit_worlds SET snapshot_hash=? WHERE id=?",
                         ('0' * 64, world['id']))
        self.assert_rejected(copy)

    def test_wrong_generation_number_is_detected(self):
        world = self.append(self.create())['world']
        copy = self.snapshot()
        self.mutate_copy(copy, "UPDATE inherit_worlds SET generation=99 WHERE id=?", (world['id'],))
        self.assert_rejected(copy)

    def test_history_tamper_is_detected_even_if_trigger_is_restored(self):
        world = self.append(self.create())['world']
        copy = self.snapshot()
        with sqlite3.connect(copy) as db:
            trigger = db.execute(
                "SELECT sql FROM sqlite_master WHERE type='trigger' AND "
                "name='inherit_generation_no_update'").fetchone()[0]
            db.execute('DROP TRIGGER inherit_generation_no_update')
            db.execute("UPDATE inherit_generations SET delta=? WHERE world_id=?",
                       (json.dumps([dict(type='path', x=55, y=55)]), world['id']))
            db.execute(trigger)
        with sqlite3.connect(copy) as db:
            self.assertIsNotNone(db.execute("SELECT 1 FROM sqlite_master WHERE type='trigger' AND name='inherit_generation_no_update'").fetchone())
            self.assertEqual(db.execute('PRAGMA integrity_check').fetchone()[0], 'ok')
        self.assert_rejected(copy)

    def test_corrupt_one_of_two_worlds_blocks_the_entire_drill(self):
        first = self.append(self.create())['world']
        second = self.append(self.create())['world']
        copy = self.snapshot()
        self.mutate_copy(copy, "UPDATE inherit_worlds SET objects='[]' WHERE id=?", (second['id'],))
        with sqlite3.connect(copy) as db:
            self.assertEqual(db.execute('PRAGMA foreign_key_check').fetchall(), [])
        self.assert_rejected(copy)

    def test_sqlite_only_explicitly_skips_application_semantics(self):
        world = self.append(self.create())['world']
        copy = self.snapshot()
        self.mutate_copy(copy, "UPDATE inherit_worlds SET objects='[]' WHERE id=?", (world['id'],))
        diagnostic = verifier.drill(copy, sqlite_only=True)
        self.assertFalse(diagnostic['core_schema_checked'])
        self.assertFalse(diagnostic['inherit_lineage_checked'])
        self.assertEqual(diagnostic['inherit_worlds_checked'], 0)
        self.assert_rejected(copy)


if __name__ == '__main__':
    unittest.main(verbosity=2)
