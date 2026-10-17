"""Run the shell workflow with fake Docker transport and real SQLite backup code.

The shim maps container paths into a private temporary directory. It executes
the shell's embedded Python command against a real local CoreStore; it never
contacts Docker or reads a production database.
"""
from contextlib import closing
from pathlib import Path
import json
import os
import shutil
import sqlite3
import subprocess
import sys
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / "scripts/backup-core-production.sh"
sys.path.insert(0, str(ROOT / "server"))
import core_backup
from core_server import Store
from core_commerce import Config


DOCKER_SHIM = r'''#!/usr/bin/env python3
import contextlib, io, os, pathlib, shutil, sys
sys.path.insert(0, os.environ['FAKE_CORE_SERVER'])
import core_backup
args = sys.argv[1:]
mode = os.environ.get('FAKE_CORE_MODE', 'success')
remote = pathlib.Path(os.environ['FAKE_CORE_REMOTE'])

def mapped(path):
    value = pathlib.Path(path)
    assert value.parent == pathlib.Path('/var/lib/osgard-core')
    assert value.name.startswith('.osgard-core-backup-')
    return remote / value.name

if mode == 'docker-fails':
    sys.exit(1)
if 'exec' in args:
    command = args[args.index('core-api') + 1:]
    if command[:2] == ['python', '-c']:
        actual_backup = core_backup.backup
        def local_backup(source, destination, **kwargs):
            assert source == '/var/lib/osgard-core/core.sqlite3'
            return actual_backup(pathlib.Path(os.environ['FAKE_CORE_SOURCE']), mapped(destination), **kwargs)
        core_backup.backup = local_backup
        sys.argv = ['-c', *command[3:]]
        output = io.StringIO()
        with contextlib.redirect_stdout(output):
            exec(compile(command[2], '<container-backup-command>', 'exec'))
        if mode == 'invalid-sha':
            print('not a checksum')
        elif mode == 'wrong-sha':
            print('0' * 64)
        else:
            print(output.getvalue(), end='')
    elif command[0] == 'rm':
        for value in command[1:]:
            if value not in ('-f', '--'):
                mapped(value).unlink(missing_ok=True)
    else:
        sys.exit(2)
elif 'cp' in args:
    source = mapped(args[-2].removeprefix('core-api:'))
    pending = pathlib.Path(args[-1])
    shutil.copyfile(source, pending)
    if mode == 'corrupt-transfer':
        with pending.open('ab') as stream:
            stream.write(b'CORRUPTED IN TRANSIT')
    suffix = {'db-collision': '', 'manifest-collision': '.manifest.json',
              'checksum-collision': '.sha256', 'sidecar-collision': '-wal'}.get(mode)
    if suffix is not None:
        filename = source.name.removeprefix('.').replace('osgard-core-backup-', 'osgard-core-', 1)
        (pending.parent / (filename + suffix)).write_bytes(b'DO NOT OVERWRITE')
else:
    sys.exit(2)
'''


class BackupContractTests(unittest.TestCase):
    def setUp(self):
        for program in ('bash', 'timeout', 'sha256sum'):
            if shutil.which(program) is None:
                self.skipTest(program + ' unavailable')
        self.temp = tempfile.TemporaryDirectory(prefix='osgard-backup-shell-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        binary = self.base / 'bin'
        binary.mkdir()
        docker = binary / 'docker'
        docker.write_text(DOCKER_SHIM)
        docker.chmod(0o700)
        self.source = self.base / 'local-core.sqlite3'
        Store(self.source, commerce_config=Config())
        self.remote = self.base / 'fake-container-volume'
        self.remote.mkdir(mode=0o700)
        self.dest = self.base / 'backups'
        self.env = dict(os.environ, PATH=str(binary) + os.pathsep + os.environ.get('PATH', ''),
                        FAKE_CORE_SOURCE=str(self.source), FAKE_CORE_REMOTE=str(self.remote),
                        FAKE_CORE_SERVER=str(ROOT / 'server'), OSGARD_CORE_BACKUP_DIR=str(self.dest))

    def run_script(self, mode='success', **environment):
        result = subprocess.run(['bash', str(SCRIPT)], cwd=ROOT,
                                env=dict(self.env, FAKE_CORE_MODE=mode, **environment),
                                capture_output=True, text=True, timeout=25)
        self.assertEqual(list(self.remote.iterdir()), [], 'remote temporary snapshot leaked')
        self.assertEqual(list(self.dest.glob('.osgard-core-pending-*')), [], 'host pending file leaked')
        return result

    def assert_no_publication(self, result):
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertEqual(list(self.dest.glob('*.sqlite3')), [])
        self.assertEqual(list(self.dest.glob('*.sha256')), [])
        self.assertEqual(list(self.dest.glob('*.manifest.json')), [])

    def test_shell_syntax(self):
        result = subprocess.run(['bash', '-n', str(SCRIPT)], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_failed_docker_does_not_publish_partial_backup(self):
        self.assert_no_publication(self.run_script('docker-fails'))

    def test_real_snapshot_metadata_checksum_and_private_permissions(self):
        result = self.run_script()
        self.assertEqual(result.returncode, 0, result.stderr + result.stdout)
        snapshots = list(self.dest.glob('*.sqlite3'))
        self.assertEqual(len(snapshots), 1)
        snapshot = snapshots[0]
        manifest = Path(str(snapshot) + '.manifest.json')
        checksum = Path(str(snapshot) + '.sha256')
        metadata = json.loads(manifest.read_text())
        self.assertEqual(metadata['database'], {'filename': snapshot.name,
                         'bytes': snapshot.stat().st_size, 'sha256': core_backup.digest(snapshot)})
        self.assertEqual(metadata['snapshot_method'], 'sqlite-online-backup')
        self.assertEqual(metadata['sqlite']['foreign_key_check'], 'passed')
        self.assertEqual(self.dest.stat().st_mode & 0o777, 0o700)
        for path in (snapshot, manifest, checksum):
            self.assertEqual(path.stat().st_mode & 0o777, 0o600)
        verified = subprocess.run(['sha256sum', '-c', str(checksum)], capture_output=True, text=True)
        self.assertEqual(verified.returncode, 0, verified.stderr)
        restored = core_backup.restore_backup(snapshot, manifest, self.base / 'restored')
        self.assertEqual(restored['status'], 'restored_offline')

    def test_missing_source_is_not_created(self):
        self.source.unlink()
        result = self.run_script()
        self.assert_no_publication(result)
        self.assertIn('missing', result.stderr)
        self.assertFalse(self.source.exists())

    def test_corrupt_source_is_not_published(self):
        self.source.write_bytes(b'not a SQLite database')
        self.assert_no_publication(self.run_script())

    def test_unrelated_version_one_database_is_not_published(self):
        self.source.unlink()
        with closing(sqlite3.connect(self.source)) as database:
            database.executescript('CREATE TABLE unrelated(id INTEGER); PRAGMA user_version=1;')
        result = self.run_script()
        self.assert_no_publication(result)
        self.assertIn('Core schema', result.stderr)

    def test_orphaned_core_relationship_is_not_published(self):
        with closing(sqlite3.connect(self.source)) as database:
            database.execute("INSERT INTO sessions VALUES('orphan-token-hash', 'missing-user', 0)")
            database.commit()
        result = self.run_script()
        self.assert_no_publication(result)
        self.assertIn('foreign_key_check', result.stderr)

    def test_corrupt_transfer_fails_digest_binding(self):
        result = self.run_script('corrupt-transfer')
        self.assert_no_publication(result)
        self.assertIn('checksum', result.stderr)

    def test_invalid_container_checksum_is_refused(self):
        result = self.run_script('invalid-sha')
        self.assert_no_publication(result)
        self.assertIn('valid snapshot SHA-256', result.stderr)

    def test_wrong_container_checksum_is_refused(self):
        result = self.run_script('wrong-sha')
        self.assert_no_publication(result)
        self.assertIn('checksum', result.stderr)

    def test_existing_bundle_components_are_never_overwritten(self):
        for mode in ('db-collision', 'manifest-collision', 'checksum-collision'):
            with self.subTest(mode=mode):
                self.dest = self.base / mode
                self.env['OSGARD_CORE_BACKUP_DIR'] = str(self.dest)
                result = self.run_script(mode)
                self.assertNotEqual(result.returncode, 0)
                self.assertEqual([path.read_bytes() for path in self.dest.iterdir()], [b'DO NOT OVERWRITE'])

    def test_existing_destination_sidecar_is_preserved(self):
        result = self.run_script('sidecar-collision')
        self.assert_no_publication(result)
        self.assertIn('sidecar', result.stderr)
        self.assertEqual([path.read_bytes() for path in self.dest.iterdir()], [b'DO NOT OVERWRITE'])

    def test_symlink_backup_directory_is_refused(self):
        real = self.base / 'real'
        real.mkdir(mode=0o700)
        self.dest.symlink_to(real, target_is_directory=True)
        result = self.run_script()
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('symlink backup directory', result.stderr)
        self.assertEqual(list(real.iterdir()), [])

    def test_symlink_ancestor_is_refused(self):
        real = self.base / 'real'
        real.mkdir(mode=0o700)
        alias = self.base / 'alias'
        alias.symlink_to(real, target_is_directory=True)
        result = self.run_script(OSGARD_CORE_BACKUP_DIR=str(alias / 'backups'))
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('symlink', result.stderr)
        self.assertEqual(list(real.iterdir()), [])

    def test_shared_directory_is_refused_without_chmod(self):
        self.dest.mkdir()
        self.dest.chmod(0o755)
        result = self.run_script()
        self.assert_no_publication(result)
        self.assertIn('must already be private', result.stderr)
        self.assertEqual(self.dest.stat().st_mode & 0o777, 0o755)


if __name__ == '__main__':
    unittest.main()
