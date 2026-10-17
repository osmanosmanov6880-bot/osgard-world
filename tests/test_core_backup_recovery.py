#!/usr/bin/env python3
"""Regression tests for production-independent Core SQLite recovery validation."""
import importlib.util
from contextlib import closing
import hashlib
import json
import os
import sqlite3
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("verify_core_backup", ROOT / "scripts/verify-core-backup.py")
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)
import core_backup
from core_server import Store
from core_commerce import Config

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

    def test_orphan_foreign_key_is_rejected(self):
        with closing(sqlite3.connect(self.backup)) as db:
            db.executescript("CREATE TABLE parents(id PRIMARY KEY); CREATE TABLE children(parent_id REFERENCES parents(id)); INSERT INTO children VALUES(99);")
        with self.assertRaisesRegex(ValueError, "foreign_key_check"):
            module.drill(self.backup)

    def test_legacy_generic_inspection_does_not_claim_core_restore(self):
        result = module.drill(self.backup)
        self.assertEqual(result['validation_scope'], 'sqlite_only')
        self.assertFalse(result['metadata_bound'])
        self.assertFalse(result['application_restore_tested'])
        with self.assertRaisesRegex(ValueError, 'Core schema'):
            module.drill(self.backup, require_core=True)


class CoreSnapshotRestoreTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='osgard-core-recovery-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.source = self.base / 'source.sqlite3'
        self.snapshot = self.base / 'snapshot.sqlite3'
        self.manifest = Path(str(self.snapshot) + '.manifest.json')
        Store(self.source, commerce_config=Config())

    def sql(self, script):
        with closing(sqlite3.connect(self.source)) as db:
            db.executescript(script)

    def bundle(self):
        return core_backup.create_backup_bundle(self.source, self.snapshot)

    def restore(self, target=None, **kwargs):
        return core_backup.restore_backup(self.snapshot, self.manifest, target or self.base / 'restored', **kwargs)

    def test_online_backup_includes_committed_wal_data(self):
        with closing(sqlite3.connect(self.source)) as writer:
            writer.execute('PRAGMA journal_mode=WAL')
            writer.execute('PRAGMA wal_checkpoint(TRUNCATE)')
            writer.execute("INSERT INTO users VALUES('local-user','fixture','salt','hash','2026-01-01')")
            writer.commit()
            self.assertTrue(Path(str(self.source) + '-wal').exists())
            with closing(sqlite3.connect(self.source.as_uri() + '?immutable=1', uri=True)) as raw:
                self.assertEqual(raw.execute('SELECT COUNT(*) FROM users').fetchone()[0], 0)
            with self.assertRaisesRegex(ValueError, 'sidecar'):
                module.drill(self.source)
            checksum = core_backup.backup(self.source, self.snapshot)
            with closing(sqlite3.connect(self.snapshot)) as restored:
                self.assertEqual(restored.execute('SELECT COUNT(*) FROM users').fetchone()[0], 1)
            self.assertEqual(checksum, core_backup.digest(self.snapshot))
        self.assertFalse(Path(str(self.snapshot) + '-wal').exists())

    def test_missing_source_is_not_created(self):
        absent = self.base / 'absent.sqlite3'
        with self.assertRaisesRegex(ValueError, 'missing'):
            core_backup.backup(absent, self.snapshot)
        self.assertFalse(absent.exists())
        self.assertFalse(self.snapshot.exists())

    def test_wal_logical_size_limit_is_enforced_before_copy(self):
        with closing(sqlite3.connect(self.source)) as writer:
            writer.execute('PRAGMA journal_mode=WAL')
            writer.execute('PRAGMA wal_checkpoint(TRUNCATE)')
            limit = self.source.stat().st_size + 4096
            writer.execute('INSERT INTO users VALUES(?,?,?,?,?)', ('local-user', 'fixture', 'salt', 'x' * (1024 * 1024), '2026-01-01'))
            writer.commit()
            self.assertLess(self.source.stat().st_size, limit)
            self.assertGreater(Path(str(self.source) + '-wal').stat().st_size, limit)
            with patch.object(core_backup, 'MAX_BYTES', limit):
                with self.assertRaisesRegex(ValueError, 'size limit exceeded before online backup'):
                    core_backup.backup(self.source, self.snapshot)
            self.assertEqual(writer.execute('SELECT COUNT(*) FROM users').fetchone()[0], 1)
        self.assertFalse(self.snapshot.exists())

    def test_late_source_path_change_cleans_owned_snapshot(self):
        original_digest = core_backup.digest
        def replace_source(path):
            result = original_digest(path)
            if path == self.snapshot:
                self.source.rename(self.base / 'original.sqlite3')
                self.source.write_bytes(b'COMPETING SOURCE')
            return result
        with patch.object(core_backup, 'digest', side_effect=replace_source):
            with self.assertRaisesRegex(ValueError, 'changed while'):
                core_backup.backup(self.source, self.snapshot)
        self.assertFalse(self.snapshot.exists())
        self.assertEqual(self.source.read_bytes(), b'COMPETING SOURCE')

    def test_unrelated_schema_with_version_one_is_rejected(self):
        other = self.base / 'unrelated.sqlite3'
        with closing(sqlite3.connect(other)) as db:
            db.executescript('CREATE TABLE unrelated(id INTEGER); PRAGMA user_version=1;')
        with self.assertRaisesRegex(ValueError, 'Core schema'):
            core_backup.backup(other, self.snapshot)
        self.assertFalse(self.snapshot.exists())

    def test_newer_core_schema_is_rejected(self):
        self.sql('PRAGMA user_version=2;')
        with self.assertRaisesRegex(ValueError, 'Core schema'):
            self.bundle()
        self.assertFalse(self.snapshot.exists())
        self.assertFalse(self.manifest.exists())

    def test_missing_core_column_is_rejected(self):
        self.sql('ALTER TABLE projects RENAME COLUMN owner_id TO renamed_owner;')
        with self.assertRaisesRegex(ValueError, 'required columns'):
            core_backup.backup(self.source, self.snapshot)

    def test_missing_core_foreign_key_is_rejected(self):
        self.sql('DROP TABLE sessions; CREATE TABLE sessions(token_hash TEXT PRIMARY KEY,user_id TEXT NOT NULL,expires_at REAL NOT NULL);')
        with self.assertRaisesRegex(ValueError, 'required foreign keys'):
            core_backup.backup(self.source, self.snapshot)

    def test_orphaned_core_relation_is_rejected(self):
        self.sql("PRAGMA foreign_keys=OFF; INSERT INTO sessions VALUES('orphan-token-hash','missing-user',0);")
        with self.assertRaisesRegex(ValueError, 'foreign_key_check'):
            core_backup.backup(self.source, self.snapshot)
        self.assertFalse(self.snapshot.exists())

    def test_source_symlink_is_rejected(self):
        alias = self.base / 'alias.sqlite3'
        alias.symlink_to(self.source)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            core_backup.backup(alias, self.snapshot)

    def test_dangling_destination_symlink_is_not_followed(self):
        elsewhere = self.base / 'elsewhere.sqlite3'
        self.snapshot.symlink_to(elsewhere)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            core_backup.backup(self.source, self.snapshot)
        self.assertFalse(elsewhere.exists())
        self.assertTrue(self.snapshot.is_symlink())

    def test_symlink_in_parent_is_rejected(self):
        real = self.base / 'real'
        real.mkdir()
        alias = self.base / 'alias'
        alias.symlink_to(real, target_is_directory=True)
        with self.assertRaisesRegex(ValueError, 'symlink'):
            core_backup.backup(self.source, alias / 'snapshot.sqlite3')
        self.assertEqual(list(real.iterdir()), [])

    def test_backup_never_overwrites_existing_file(self):
        self.snapshot.write_bytes(b'KEEP ORIGINAL')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            core_backup.backup(self.source, self.snapshot)
        self.assertEqual(self.snapshot.read_bytes(), b'KEEP ORIGINAL')

    def test_preexisting_destination_sidecar_is_preserved(self):
        sidecar = Path(str(self.snapshot) + '-wal')
        sidecar.write_bytes(b'KEEP SIDECAR')
        with self.assertRaisesRegex(ValueError, 'sidecar'):
            core_backup.backup(self.source, self.snapshot)
        self.assertEqual(sidecar.read_bytes(), b'KEEP SIDECAR')
        self.assertFalse(self.snapshot.exists())

    def test_time_budget_aborts_and_cleans_partial_snapshot(self):
        with self.assertRaisesRegex(ValueError, 'time budget'):
            core_backup.backup(self.source, self.snapshot, timeout=0)
        self.assertFalse(self.snapshot.exists())

    def test_bundle_is_bound_private_and_restores_exact_bytes(self):
        result = self.bundle()
        content = self.snapshot.read_bytes()
        report = self.restore(expected_sha256=result['sha256'])
        self.assertEqual(report['status'], 'restored_offline')
        self.assertFalse(report['service_started'])
        self.assertFalse(report['production_modified'])
        self.assertFalse(report['metadata_authenticated'])
        self.assertEqual((self.base / 'restored/core.sqlite3').read_bytes(), content)
        self.assertEqual(self.snapshot.read_bytes(), content)
        for path in [self.snapshot, self.manifest, Path(str(self.snapshot) + '.sha256'), self.base / 'restored/core.sqlite3', self.base / 'restored/restore-report.json']:
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        self.assertEqual((self.base / 'restored').stat().st_mode & 0o777, 0o700)
        inspected = module.drill(self.snapshot, metadata_path=self.manifest)
        self.assertTrue(inspected['metadata_bound'])
        self.assertEqual(inspected['validation_scope'], 'core_schema_and_sqlite')

    def test_changed_database_fails_before_restore_is_published(self):
        self.bundle()
        with self.snapshot.open('ab') as stream:
            stream.write(b'changed')
        with self.assertRaisesRegex(ValueError, 'checksum'):
            self.restore()
        self.assertFalse((self.base / 'restored').exists())

    def test_original_manifest_bytes_are_preserved_and_bound(self):
        self.bundle()
        self.manifest.write_text(json.dumps(json.loads(self.manifest.read_text()), indent=1) + '\n\n')
        raw = self.manifest.read_bytes()
        report = self.restore()
        self.assertEqual((self.base / 'restored/backup-manifest.json').read_bytes(), raw)
        self.assertEqual(report['manifest_sha256'], hashlib.sha256(raw).hexdigest())

    def test_wrong_trusted_digest_is_rejected(self):
        self.bundle()
        with self.assertRaisesRegex(ValueError, 'Trusted SHA'):
            self.restore(expected_sha256='0' * 64)
        self.assertFalse((self.base / 'restored').exists())

    def test_metadata_scalar_types_and_paths_are_strict(self):
        self.bundle()
        original = json.loads(self.manifest.read_text())
        changes = [('schema_version', True), ('recorded_at', 'not-a-time'), ('recorded_at', '2026-01-01T00:00:00'),
                   ('database.bytes', True), ('database.bytes', 1.0), ('database.bytes', 0),
                   ('database.sha256', 'bad'), ('database.filename', '../source.sqlite3'),
                   ('sqlite.user_version', True), ('sqlite.table_count', True), ('sqlite.schema_sha256', 'bad')]
        for field, value in changes:
            with self.subTest(field=field, value=value):
                metadata = json.loads(json.dumps(original))
                parent, _, key = field.rpartition('.')
                (metadata[parent] if parent else metadata)[key or field] = value
                self.manifest.write_text(json.dumps(metadata))
                with self.assertRaises(ValueError):
                    self.restore()
                self.assertFalse((self.base / 'restored').exists())

    def test_metadata_schema_and_file_mismatch_are_rejected(self):
        self.bundle()
        original = json.loads(self.manifest.read_text())
        for section, key, value in [('sqlite', 'schema_sha256', '0' * 64), ('sqlite', 'table_count', 999),
                                    ('database', 'filename', 'different.sqlite3'), ('database', 'bytes', 1)]:
            with self.subTest(key=key):
                changed = json.loads(json.dumps(original))
                changed[section][key] = value
                self.manifest.write_text(json.dumps(changed))
                with self.assertRaisesRegex(ValueError, 'metadata'):
                    self.restore()
                self.assertFalse((self.base / 'restored').exists())

    def test_duplicate_and_oversized_metadata_are_rejected(self):
        self.bundle()
        raw = self.manifest.read_text()
        self.manifest.write_text(raw.replace('"schema_version": 1', '"schema_version": 1, "schema_version": 1'))
        with self.assertRaisesRegex(ValueError, 'Duplicate'):
            self.restore()
        self.manifest.write_bytes(b' ' * (core_backup.MAX_METADATA_BYTES + 1))
        with self.assertRaisesRegex(ValueError, 'size limit'):
            self.restore()

    def test_existing_restore_directory_is_never_reused(self):
        self.bundle()
        target = self.base / 'restored'
        target.mkdir()
        with self.assertRaisesRegex(ValueError, 'already exists'):
            self.restore(target)
        sentinel = target / 'core.sqlite3'
        sentinel.write_bytes(b'KEEP LIVE DATA')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            self.restore(target)
        self.assertEqual(sentinel.read_bytes(), b'KEEP LIVE DATA')
        self.assertEqual(list(target.iterdir()), [sentinel])

    def test_production_public_and_custom_live_roots_are_rejected(self):
        self.bundle()
        custom = self.base / 'configured-production'
        custom.mkdir()
        for path in [Path('/var/lib/osgard-core/drill-must-not-exist'), Path.home() / '.osgard-core/drill-must-not-exist',
                     ROOT / 'public/drill-must-not-exist', ROOT / 'dist/drill-must-not-exist', custom / 'restored']:
            with self.subTest(path=path):
                with self.assertRaisesRegex(ValueError, 'production or public'):
                    self.restore(path, protected_roots=[custom])
                self.assertFalse(path.exists())

    def test_traversal_and_restore_symlink_are_rejected(self):
        self.bundle()
        with self.assertRaisesRegex(ValueError, 'traversal'):
            self.restore(self.base / 'not-created' / '..' / 'restored')
        alias = self.base / 'restored'
        alias.symlink_to(self.base / 'absent')
        with self.assertRaisesRegex(ValueError, 'symlink'):
            self.restore(alias)
        self.assertFalse((self.base / 'absent').exists())

    def test_transfer_hash_mismatch_publishes_no_artifact(self):
        core_backup.backup(self.source, self.snapshot)
        target = self.base / 'published.sqlite3'
        with self.assertRaisesRegex(ValueError, 'checksum'):
            core_backup.publish_snapshot(self.snapshot, target, '0' * 64)
        self.assertEqual(list(self.base.glob('published*')), [])

    def test_publisher_preserves_preexisting_destination_sidecar(self):
        core_backup.backup(self.source, self.snapshot)
        target = self.base / 'published.sqlite3'
        sidecar = Path(str(target) + '-wal')
        sidecar.write_bytes(b'KEEP SIDECAR')
        with self.assertRaisesRegex(ValueError, 'sidecar'):
            core_backup.publish_snapshot(self.snapshot, target, core_backup.digest(self.snapshot))
        self.assertEqual(sidecar.read_bytes(), b'KEEP SIDECAR')
        self.assertFalse(target.exists())
        self.assertFalse(Path(str(target) + '.manifest.json').exists())

    def test_backups_cannot_be_written_into_public_trees(self):
        for directory in ('public', 'dist', 'PAGES'):
            with self.subTest(directory=directory):
                target = ROOT / directory / 'backup-must-not-exist.sqlite3'
                with self.assertRaisesRegex(ValueError, 'public-serving'):
                    core_backup.create_backup_bundle(self.source, target)
                self.assertFalse(target.exists())

    def test_manifest_collision_never_clobbers_competing_metadata(self):
        self.manifest.write_bytes(b'KEEP METADATA')
        with self.assertRaisesRegex(ValueError, 'already exists'):
            self.bundle()
        self.assertEqual(self.manifest.read_bytes(), b'KEEP METADATA')
        self.assertFalse(self.snapshot.exists())

    def test_failed_metadata_publication_cleans_only_owned_files(self):
        original = core_backup.write_private
        def collision(path, data):
            if path == self.manifest:
                path.write_bytes(b'COMPETING WRITER')
            return original(path, data)
        with patch.object(core_backup, 'write_private', side_effect=collision):
            with self.assertRaises(FileExistsError):
                self.bundle()
        self.assertEqual(self.manifest.read_bytes(), b'COMPETING WRITER')
        self.assertFalse(self.snapshot.exists())
        self.assertFalse(Path(str(self.snapshot) + '.sha256').exists())

if __name__ == "__main__":
    unittest.main()
