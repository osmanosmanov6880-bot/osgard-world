"""Execute only the activation script's recovery functions with local Docker stubs.

No activation worker, Docker daemon, network request, or real container is used.
The shell has no executable search path; every Docker call records its intent
and returns a controlled outcome. Only temporary test files can be written.
"""

from pathlib import Path
import re
import shlex
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[1]
ACTIVATION = (ROOT / "scripts" / "activate-frontend-remote.sh").read_text()


def shell_function(name):
    """Extract one complete function at its actual indentation, never the worker."""
    starts = list(re.finditer(r"^(?P<indent> *)" + re.escape(name) + r"\(\) \{\n", ACTIVATION, re.M))
    if len(starts) != 1:
        raise AssertionError(f"Expected one {name} function in the actual activation script")
    start = starts[0]
    end = re.search(r"^" + re.escape(start["indent"]) + r"\}\n", ACTIVATION[start.end():], re.M)
    if end is None:
        raise AssertionError(f"Cannot find the end of {name}")
    return ACTIVATION[start.start():start.end() + end.end()]


FUNCTIONS = shell_function("rollback") + "\n" + shell_function("activation_failure")
TRAPS = "\n".join(line.strip() for line in ACTIVATION.splitlines()
                  if re.fullmatch(r"\s*trap 'activation_failure [^']+' (?:ERR|TERM INT)", line))
if len(TRAPS.splitlines()) != 2:
    raise AssertionError("Expected the actual error and signal recovery traps")


def recovery_fixture(body, **overrides):
    values = {
        "rollback_done": "0", "activation_committed": "0",
        "remix_guard_started": "1", "remix_guard_replaced": "1",
        "remix_guard_previous": "guard-previous",
        "core_started": "1", "core_replaced": "1", "core_previous": "core-previous",
        "frontend_replaced": "1", "container_name": "frontend-fixture",
        "fixture_fail_action": "", "fixture_fail_name": "",
    }
    values.update(overrides)
    with tempfile.TemporaryDirectory(prefix="osgard-activation-test-") as directory:
        call_log = Path(directory) / "calls.txt"
        state_file = Path(directory) / "state.txt"
        call_log.write_text("")
        values.update(call_log=str(call_log), state_file=str(state_file))
        assignments = "\n".join(f"{name}={shlex.quote(value)}" for name, value in values.items())
        script = "set -euo pipefail\n" + assignments + r'''
docker() {
  printf '%s\t%s\t%s\n' "${1:-}" "${2:-}" "${3:-}" >> "$call_log"
  if [[ "${1:-}" == "$fixture_fail_action" && "${2:-}" == "$fixture_fail_name" ]]; then
    return 42
  fi
  return 0
}
''' + FUNCTIONS + "\n" + body + "\n"
        completed = subprocess.run(
            ["/bin/bash", "--noprofile", "--norc"], input=script, text=True,
            capture_output=True, cwd=directory, env={"PATH": "/nonexistent"}, timeout=5,
            check=False,
        )
        calls = [tuple(line.split("\t")) for line in call_log.read_text().splitlines()]
        state = state_file.read_text() if state_file.exists() else None
    return completed, calls, state


class ActivationRecoveryTests(unittest.TestCase):
    def test_failed_guard_rename_still_restores_core_and_frontend(self):
        completed, calls, _ = recovery_fixture(
            "rollback", fixture_fail_action="rename", fixture_fail_name="guard-previous")
        self.assertEqual(completed.returncode, 1, completed.stderr)
        self.assertIn(("rename", "guard-previous", "osgard-remix-guard"), calls)
        self.assertNotIn(("start", "osgard-remix-guard", ""), calls)
        self.assertIn(("rename", "core-previous", "osgard-core-api"), calls)
        self.assertIn(("start", "osgard-core-api", ""), calls)
        self.assertEqual(calls[-1], ("exec", "frontend-fixture", "sh"))
        self.assertIn("continuing the other rollback steps", completed.stderr)

    def test_failed_core_restore_still_attempts_frontend(self):
        for action, name in (("rename", "core-previous"), ("start", "osgard-core-api")):
            with self.subTest(action=action):
                completed, calls, _ = recovery_fixture(
                    "rollback", fixture_fail_action=action, fixture_fail_name=name)
                self.assertEqual(completed.returncode, 1, completed.stderr)
                self.assertIn(("start", "osgard-remix-guard", ""), calls)
                self.assertEqual(calls[-1], ("exec", "frontend-fixture", "sh"))
                self.assertIn("continuing the frontend rollback", completed.stderr)

    def test_committed_cleanup_interruption_retains_running_services(self):
        # Model cleanup after previous containers have been removed. Execute the
        # script's real traps, including a TERM delivered only to this test shell.
        for trigger in ('kill -TERM "$$"', "false"):
            with self.subTest(trigger=trigger):
                completed, calls, state = recovery_fixture(
                    TRAPS + "\n" + trigger,
                    activation_committed="1", core_replaced="0", remix_guard_replaced="0")
                self.assertEqual(completed.returncode, 0, completed.stderr)
                self.assertEqual(calls, [], "A committed release must not be removed or rolled back")
                self.assertEqual(state, "success\n")
                self.assertIn("verified release remains active", completed.stderr)

    def test_before_frontend_swap_recovery_never_restores_stale_html(self):
        completed, calls, state = recovery_fixture(
            TRAPS + "\nfalse", frontend_replaced="0")
        self.assertEqual(completed.returncode, 1, completed.stderr)
        self.assertEqual(state, "failed\n")
        self.assertIn(("start", "osgard-remix-guard", ""), calls)
        self.assertIn(("start", "osgard-core-api", ""), calls)
        self.assertFalse(any(call[0] == "exec" for call in calls), calls)

    def test_successful_rollback_does_not_remove_restored_services_twice(self):
        completed, calls, _ = recovery_fixture("rollback\nrollback")
        self.assertEqual(completed.returncode, 0, completed.stderr)
        self.assertEqual(calls.count(("rm", "-f", "osgard-remix-guard")), 1)
        self.assertEqual(calls.count(("rm", "-f", "osgard-core-api")), 1)
        self.assertEqual(calls.count(("exec", "frontend-fixture", "sh")), 1)

    def test_commit_point_precedes_irreversible_previous_container_cleanup(self):
        verified = ACTIVATION.index("echo 'Public release checks passed.'")
        commit = ACTIVATION.index("\n  activation_committed=1\n")
        self.assertLess(verified, commit)
        for name in ("core_previous", "remix_guard_previous"):
            cleanup = ACTIVATION.index(f'docker rm "${name}"')
            self.assertLess(commit, cleanup, "Commit the verified release before removing its rollback container")


if __name__ == "__main__":
    unittest.main()
