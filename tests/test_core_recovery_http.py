"""Real local Core HTTP recovery and truthful failure/report boundaries."""
from contextlib import redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch
import importlib.util
import io
import json
import os
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('core_recovery_http', ROOT / 'scripts/core-recovery-drill.py')
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)


class CoreRecoveryHttpTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix='osgard-core-http-test-')
        self.addCleanup(self.temp.cleanup)
        self.base = Path(self.temp.name)
        self.work = self.base / 'exercise'
        self.report = self.base / 'report.json'

    def command(self):
        return ['--work-dir', str(self.work), '--report', str(self.report)]

    def test_real_http_cycle_and_child_environment_isolation(self):
        marker = 'TEST_SECRET_MUST_NOT_REACH_CHILD_OR_REPORT'
        caller_config = {'OSGARD_COMMERCE_ENABLED': '1', 'OSGARD_STRIPE_LIVEMODE': '1',
                         'OSGARD_STRIPE_SECRET_KEY': marker, 'OSGARD_STRIPE_WEBHOOK_SECRET': marker,
                         'OSGARD_STRIPE_SECRET_KEY_FILE': str(self.base / 'do-not-open'),
                         'OSGARD_CORE_TOKEN': marker, 'AWS_SECRET_ACCESS_KEY': marker,
                         'PYTHONPATH': str(self.base / 'untrusted-module-path')}
        actual_popen = subprocess.Popen
        with patch.dict(os.environ, caller_config), patch.object(recovery.subprocess, 'Popen', wraps=actual_popen) as popen:
            report = recovery.run_drill(self.work)
        self.assertEqual(report['status'], 'passed', report.get('error'))
        self.assertEqual(popen.call_count, 2, 'the original and restored Core must be distinct processes')
        for call in popen.call_args_list:
            command, environment = call.args[0], call.kwargs['env']
            self.assertEqual(command[command.index('--host') + 1], '127.0.0.1')
            self.assertEqual(command[command.index('--port') + 1], '0')
            self.assertNotIn('--remix', command)
            self.assertTrue(Path(command[command.index('--database') + 1]).is_relative_to(self.work))
            self.assertEqual(environment['OSGARD_COMMERCE_ENABLED'], '0')
            for key in caller_config.keys() - {'OSGARD_COMMERCE_ENABLED'}:
                self.assertNotIn(key, environment)
            self.assertNotIn(marker, json.dumps(environment))
        for flag in ('production_backup_used', 'production_modified', 'production_restore_tested',
                     'production_rto_rpo_measured', 'external_requests_performed', 'payments_enabled', 'remix_enabled'):
            self.assertIs(report[flag], False)
        self.assertEqual(report['observed_records'], {'users': 3, 'projects': 1, 'members': 1,
                         'revisions_at_snapshot': 6, 'assets': 1, 'completed_jobs': 1, 'cost_entries': 1})
        self.assertEqual(report['recovery_point']['later_live_revision'], report['recovery_point']['snapshot_project_revision'] + 1)
        self.assertTrue(report['recovery_point']['later_change_excluded'])
        self.assertEqual(report['restored_sqlite']['foreign_key_check'], 'passed')
        self.assertEqual(report['post_http_sqlite']['integrity_check'], 'passed')
        self.assertEqual(len(report['checks']), 11)
        raw = (self.work / 'report.json').read_text()
        self.assertEqual(json.loads(raw), report)
        self.assertNotIn(marker, raw)
        for private_value in ('drill_owner_', 'drill_viewer_', 'drill_outsider_', 'token_hash', 'password_hash'):
            self.assertNotIn(private_value, raw)
        self.assertFalse((self.work / 'must-not-copy-active.sqlite3').exists())

    def test_runtime_failure_writes_both_reports_and_returns_nonzero(self):
        with patch.object(recovery.LocalCore, '__enter__', side_effect=ValueError('Controlled startup failure')):
            with redirect_stdout(io.StringIO()) as stdout:
                code = recovery.main(self.command())
        self.assertEqual(code, 2)
        report = json.loads(self.report.read_text())
        self.assertEqual(report['status'], 'failed')
        self.assertEqual(report['error'], 'Controlled startup failure')
        self.assertEqual(report['checks'], [])
        self.assertEqual(json.loads(stdout.getvalue()), report)
        self.assertEqual(json.loads((self.work / 'report.json').read_text()), report)
        self.assertEqual(self.report.stat().st_mode & 0o777, 0o600)
        self.assertFalse((self.work / 'live/core.sqlite3').exists())

    def test_preexisting_work_is_preserved_with_failed_external_report(self):
        self.work.mkdir()
        sentinel = self.work / 'core.sqlite3'
        sentinel.write_bytes(b'DO NOT REUSE THIS DIRECTORY')
        with patch.object(recovery.LocalCore, '__enter__') as start, redirect_stdout(io.StringIO()):
            code = recovery.main(self.command())
        self.assertEqual(code, 2)
        start.assert_not_called()
        self.assertEqual(sentinel.read_bytes(), b'DO NOT REUSE THIS DIRECTORY')
        self.assertEqual(list(self.work.iterdir()), [sentinel])
        report = json.loads(self.report.read_text())
        self.assertEqual(report['status'], 'failed')
        self.assertIn('already exists', report['error'])

    def test_preexisting_report_prevents_start_and_is_not_overwritten(self):
        self.report.write_bytes(b'KEEP PREVIOUS REPORT')
        with patch.object(recovery.LocalCore, '__enter__') as start, redirect_stderr(io.StringIO()):
            code = recovery.main(self.command())
        self.assertEqual(code, 2)
        start.assert_not_called()
        self.assertEqual(self.report.read_bytes(), b'KEEP PREVIOUS REPORT')
        self.assertFalse(self.work.exists())

    def test_symlink_report_parent_prevents_start(self):
        real = self.base / 'real'
        real.mkdir()
        alias = self.base / 'alias'
        alias.symlink_to(real, target_is_directory=True)
        self.report = alias / 'report.json'
        with patch.object(recovery.LocalCore, '__enter__') as start, redirect_stderr(io.StringIO()):
            code = recovery.main(self.command())
        self.assertEqual(code, 2)
        start.assert_not_called()
        self.assertEqual(list(real.iterdir()), [])
        self.assertFalse(self.work.exists())


if __name__ == '__main__':
    unittest.main()
