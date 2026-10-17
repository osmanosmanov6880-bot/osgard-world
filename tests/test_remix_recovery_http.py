"""Real active-arena process/backup recovery and private report boundaries."""
from contextlib import closing, redirect_stderr, redirect_stdout
from pathlib import Path
from unittest.mock import patch
import importlib.util
import io
import json
import os
import sqlite3
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("remix_recovery_http", ROOT / "scripts/remix-recovery-drill.py")
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)


class RemixRecoveryHttpTests(unittest.TestCase):
    def setUp(self):
        temporary = tempfile.TemporaryDirectory(prefix="osgard-remix-recovery-test-")
        self.addCleanup(temporary.cleanup)
        self.base = Path(temporary.name)
        self.work, self.report = self.base / "exercise", self.base / "report.json"

    def command(self):
        return ["--work-dir", str(self.work), "--report", str(self.report)]

    def test_real_http_active_wal_sigkill_snapshot_restore_and_corruption_boundaries(self):
        marker = "TEST_SECRET_MUST_NOT_REACH_ARENA_CHILD_OR_REPORT"
        caller_environment = {
            "OSGARD_COMMERCE_ENABLED": "1", "OSGARD_STRIPE_LIVEMODE": "1",
            "OSGARD_STRIPE_SECRET_KEY": marker, "OSGARD_CORE_TOKEN": marker,
            "AWS_SECRET_ACCESS_KEY": marker, "HTTPS_PROXY": "https://" + marker,
            "PYTHONPATH": str(self.base / "untrusted-modules"),
        }
        actual_popen = subprocess.Popen
        with patch.dict(os.environ, caller_environment), \
                patch.object(recovery.core_recovery.subprocess, "Popen", wraps=actual_popen) as popen:
            report = recovery.run_drill(self.work)
        self.assertEqual(report["status"], "passed", report.get("failure"))
        self.assertEqual(popen.call_count, 4, "source, crashed source restart, snapshot restore and corrupt-copy processes")
        for call in popen.call_args_list:
            command, environment = call.args[0], call.kwargs["env"]
            self.assertIn("--remix", command)
            self.assertEqual(command[command.index("--host") + 1], "127.0.0.1")
            self.assertEqual(command[command.index("--port") + 1], "0")
            self.assertTrue(Path(command[command.index("--database") + 1]).is_relative_to(self.work))
            self.assertEqual(environment["OSGARD_COMMERCE_ENABLED"], "0")
            for name in caller_environment.keys() - {"OSGARD_COMMERCE_ENABLED"}:
                self.assertNotIn(name, environment)
            self.assertNotIn(marker, json.dumps(environment))
        self.assertEqual(report["processes"], {"started": 4, "forced_terminations": 1})
        self.assertEqual(report["http"]["requests"], report["http"]["verified_responses"])
        self.assertGreater(report["http"]["verified_responses"], 50)
        for name in ("production_backup_used", "production_modified", "production_restore_tested",
                     "production_rto_rpo_measured", "external_requests_performed", "payments_enabled",
                     "legacy_active_match_recovery_tested"):
            self.assertIs(report[name], False)
        self.assertIs(report["remix_enabled"], True)
        point = report["recovery_point"]
        self.assertEqual(point["snapshot_sequence"], 4)
        self.assertEqual(point["later_source_sequence"], 5)
        self.assertTrue(point["later_input_excluded"])
        self.assertTrue(report["continuation"]["same_result_as_source"])
        self.assertTrue(report["continuation"]["same_replay_as_source"])
        self.assertEqual(report["restored_sqlite"]["foreign_key_check"], "passed")
        self.assertEqual(report["post_http_sqlite"]["integrity_check"], "passed")
        self.assertIn("corrupt_active_copy_rejects_reads_fresh_input_and_cached_retry_without_writes", report["checks"])
        self.assertFalse((self.work / "rejected-active-copy.sqlite3").exists())
        raw = (self.work / "report.json").read_text()
        self.assertEqual(json.loads(raw), report)
        self.assertEqual((self.work / "report.json").stat().st_mode & 0o777, 0o600)
        for forbidden in (marker, str(self.work), "remix_drill_creator_", "remix_drill_challenger_",
                          "remix_drill_outsider_", "password_hash", "token_hash", ".sqlite3"):
            self.assertNotIn(forbidden, raw)
        # Inspect this test's own private snapshot to prove identifiers and
        # credential derivatives were not copied into the report by accident.
        with closing(sqlite3.connect((self.work / "snapshots/core.sqlite3").as_uri() + "?mode=ro&immutable=1", uri=True)) as db:
            for row in db.execute("SELECT id,username,salt,password_hash FROM users"):
                for value in row:
                    self.assertNotIn(value, raw)
            for (value,) in db.execute("SELECT token_hash FROM sessions"):
                self.assertNotIn(value, raw)

    def test_failure_report_names_phase_without_exception_secrets(self):
        marker = "PRIVATE_PATH_AND_SESSION_MUST_NOT_BE_PUBLISHED"
        with patch.object(recovery.LocalArena, "__enter__", side_effect=ValueError(marker)), \
                redirect_stdout(io.StringIO()) as stdout:
            code = recovery.main(self.command())
        self.assertEqual(code, 2)
        report = json.loads(self.report.read_text())
        self.assertEqual(report["status"], "failed")
        self.assertEqual(report["failure"], {"stage": "create-http-proof-and-active-prefix", "error_type": "ValueError"})
        self.assertEqual(report["checks"], [])
        self.assertEqual(report["http"], {"requests": 0, "verified_responses": 0, "loopback_only": True})
        self.assertNotIn(marker, self.report.read_text() + stdout.getvalue())
        self.assertEqual(json.loads(stdout.getvalue()), report)
        self.assertEqual(json.loads((self.work / "report.json").read_text()), report)
        self.assertFalse((self.work / "live/core.sqlite3").exists())

    def test_existing_work_is_preserved_and_never_opened_as_a_database(self):
        self.work.mkdir()
        sentinel = self.work / "core.sqlite3"
        sentinel.write_bytes(b"DO NOT OPEN OR REPLACE THIS DATABASE")
        with patch.object(recovery.LocalArena, "__enter__") as start, redirect_stdout(io.StringIO()):
            code = recovery.main(self.command())
        self.assertEqual(code, 2)
        start.assert_not_called()
        self.assertEqual(sentinel.read_bytes(), b"DO NOT OPEN OR REPLACE THIS DATABASE")
        self.assertEqual(list(self.work.iterdir()), [sentinel])
        report = json.loads(self.report.read_text())
        self.assertEqual(report["failure"]["stage"], "prepare-isolated-directory")

    def test_existing_report_or_symlink_parent_prevents_start(self):
        self.report.write_text("KEEP PREVIOUS REPORT")
        with patch.object(recovery.LocalArena, "__enter__") as start, redirect_stderr(io.StringIO()):
            self.assertEqual(recovery.main(self.command()), 2)
        start.assert_not_called()
        self.assertEqual(self.report.read_text(), "KEEP PREVIOUS REPORT")
        self.assertFalse(self.work.exists())
        real = self.base / "real"
        real.mkdir()
        alias = self.base / "alias"
        alias.symlink_to(real, target_is_directory=True)
        self.report = alias / "report.json"
        with patch.object(recovery.LocalArena, "__enter__") as start, redirect_stderr(io.StringIO()):
            self.assertEqual(recovery.main(self.command()), 2)
        start.assert_not_called()
        self.assertEqual(list(real.iterdir()), [])
        self.assertFalse(self.work.exists())


if __name__ == "__main__":
    unittest.main()
