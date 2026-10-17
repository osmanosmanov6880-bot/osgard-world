"""Execute the activation driver's real recovery functions with Docker stubs.

No production activation body, Docker daemon, network request, or real container
is used. Every Docker call records its intent and returns a controlled outcome.
Parent tests use harmless child shells, system sleep/flock, and temporary files
to verify actual signals, reaping and lock ownership across a lost caller.
"""

from contextlib import contextmanager
from pathlib import Path
import json
import os
import re
import shlex
import signal
import subprocess
import tempfile
import time
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
                  if re.fullmatch(r"\s*trap 'activation_failure [^']+' (?:ERR|TERM INT|HUP)", line))
if len(TRAPS.splitlines()) != 3:
    raise AssertionError("Expected the actual error and signal recovery traps")

PARENT_FUNCTIONS = "\n".join(shell_function(name) for name in
                            ("acquire_activation_lock", "stop_activation_worker", "monitor_activation_worker"))
PARENT_TRAPS = "\n".join(line.strip() for line in ACTIVATION.splitlines()
                         if re.fullmatch(r"trap 'stop_activation_worker [0-9]+' (?:TERM|INT|HUP)", line))
if len(PARENT_TRAPS.splitlines()) != 3:
    raise AssertionError("Expected the actual parent signal forwarding traps")


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


def wait_for_file(path, timeout=4):
    deadline = time.monotonic() + timeout
    while not path.exists() and time.monotonic() < deadline:
        time.sleep(0.01)
    if not path.exists():
        raise AssertionError(f"Temporary worker did not reach {path.name}")


@contextmanager
def parent_fixture(*, committed=False, attempts=600, outcome=None):
    """Run actual parent/worker traps with only a logging Docker shell function."""
    with tempfile.TemporaryDirectory(prefix="osgard-activation-parent-") as directory:
        root = Path(directory)
        files = {name: root / name for name in ("state", "log", "calls", "ready", "rollback", "lock")}
        files["calls"].write_text("")
        values = {
            "state_file": str(files["state"]), "log_file": str(files["log"]),
            "call_log": str(files["calls"]), "ready_file": str(files["ready"]),
            "rollback_file": str(files["rollback"]), "OSGARD_ACTIVATION_LOCK": str(files["lock"]),
            "activation_worker_started": "0", "pid": "", "rollback_done": "0",
            "activation_committed": "1" if committed else "0",
            "remix_guard_started": "1", "remix_guard_replaced": "1",
            "remix_guard_previous": "guard-previous", "core_started": "1",
            "core_replaced": "1", "core_previous": "core-previous",
            "frontend_replaced": "1", "container_name": "frontend-fixture",
        }
        assignments = "\n".join(f"{name}={shlex.quote(value)}" for name, value in values.items())
        docker_stub = r'''
docker() {
  printf '%s\t%s\t%s\n' "${1:-}" "${2:-}" "${3:-}" >> "$call_log"
  if [[ "${1:-}" == "rm" && "${2:-}" == "-f" && "${3:-}" == "osgard-remix-guard" ]]; then
    printf 'started\n' >> "$rollback_file"
    sleep 0.30
  fi
  return 0
}
'''
        worker = "while :; do sleep 0.05; done"
        if outcome is not None:
            status, code = outcome
            worker = f"printf '%s\\n' {shlex.quote(status)} > \"$state_file\"\nexit {code}"
        script = ("set -euo pipefail\n" + assignments + "\n" + docker_stub + FUNCTIONS + "\n" +
                  PARENT_FUNCTIONS + "\nacquire_activation_lock\n" + PARENT_TRAPS + "\n(\n" +
                  TRAPS + "\nprintf '%s\\n' \"$BASHPID\" > \"$ready_file\"\n" + worker +
                  '\n) >"$log_file" 2>&1 &\npid=$!\nactivation_worker_started=1\n' +
                  f"monitor_activation_worker {attempts}\n")
        process = subprocess.Popen(
            ["/bin/bash", "--noprofile", "--norc"], stdin=subprocess.PIPE,
            stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            cwd=directory, env={"PATH": "/usr/bin:/bin"}, start_new_session=True,
        )
        process.stdin.write(script)
        process.stdin.close()
        process.stdin = None
        try:
            wait_for_file(files["ready"])
            yield process, files, int(files["ready"].read_text())
        finally:
            # Only this test's newly created session is ever signalled.
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            process.communicate(timeout=3)


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

    def test_parent_term_int_hup_wait_for_rollback_despite_repeated_signals(self):
        for sig, expected in ((signal.SIGTERM, 143), (signal.SIGINT, 130), (signal.SIGHUP, 129)):
            with self.subTest(signal=sig), parent_fixture() as (process, files, worker_pid):
                os.kill(process.pid, sig)
                wait_for_file(files["rollback"])
                os.kill(process.pid, signal.SIGTERM)
                os.kill(worker_pid, signal.SIGHUP)
                self.assertIsNone(process.poll(), "Parent returned before rollback completed")
                process.communicate(timeout=4)
                self.assertEqual(process.returncode, expected)
                self.assertEqual(files["state"].read_text(), "failed\n")
                self.assertEqual(files["rollback"].read_text(), "started\n")
                with self.assertRaises(ProcessLookupError):
                    os.kill(worker_pid, 0)

    def test_session_hup_reaches_both_shells_and_cannot_interrupt_rollback_twice(self):
        with parent_fixture() as (process, files, worker_pid):
            os.killpg(process.pid, signal.SIGHUP)
            wait_for_file(files["rollback"])
            os.killpg(process.pid, signal.SIGHUP)
            self.assertIsNone(process.poll())
            process.communicate(timeout=4)
            self.assertEqual(process.returncode, 129)
            self.assertEqual(files["state"].read_text(), "failed\n")
            self.assertEqual(files["rollback"].read_text(), "started\n")
            with self.assertRaises(ProcessLookupError):
                os.kill(worker_pid, 0)

    def test_parent_timeout_waits_for_rollback_and_returns_timeout_status(self):
        with parent_fixture(attempts=1) as (process, files, worker_pid):
            wait_for_file(files["rollback"])
            os.kill(process.pid, signal.SIGTERM)
            os.kill(worker_pid, signal.SIGHUP)
            self.assertIsNone(process.poll())
            process.communicate(timeout=4)
            self.assertEqual(process.returncode, 124)
            self.assertEqual(files["state"].read_text(), "failed\n")
            with self.assertRaises(ProcessLookupError):
                os.kill(worker_pid, 0)

    def test_parent_cancellation_after_commit_retains_success_and_running_services(self):
        with parent_fixture(committed=True) as (process, files, worker_pid):
            os.kill(process.pid, signal.SIGTERM)
            process.communicate(timeout=4)
            self.assertEqual(process.returncode, 0)
            self.assertEqual(files["state"].read_text(), "success\n")
            self.assertEqual(files["calls"].read_text(), "")
            with self.assertRaises(ProcessLookupError):
                os.kill(worker_pid, 0)

    def test_normal_completion_reaps_worker_and_preserves_failure_status(self):
        for outcome in (("success", 0), ("failed", 7)):
            with self.subTest(outcome=outcome), parent_fixture(outcome=outcome) as (process, files, worker_pid):
                process.communicate(timeout=4)
                self.assertEqual(process.returncode, outcome[1])
                self.assertEqual(files["state"].read_text(), outcome[0] + "\n")
                with self.assertRaises(ProcessLookupError):
                    os.kill(worker_pid, 0)

    def test_inherited_host_lock_excludes_second_activation_after_caller_is_killed(self):
        with parent_fixture() as (process, files, worker_pid):
            contender = ("set -euo pipefail\nOSGARD_ACTIVATION_LOCK=" + shlex.quote(str(files["lock"])) +
                         "\n" + shell_function("acquire_activation_lock") + "\nacquire_activation_lock\n")

            def acquire():
                return subprocess.run(["/bin/bash", "--noprofile", "--norc"], input=contender,
                                      text=True, capture_output=True, env={"PATH": "/usr/bin:/bin"}, timeout=2)

            os.kill(process.pid, signal.SIGKILL)
            process.wait(timeout=2)
            self.assertEqual(acquire().returncode, 1, "Orphan worker must retain the host lock")
            os.kill(worker_pid, signal.SIGTERM)
            wait_for_file(files["rollback"])
            self.assertEqual(acquire().returncode, 1, "Rollback must retain the same host lock")
            wait_for_file(files["state"])
            deadline = time.monotonic() + 2
            result = acquire()
            while result.returncode and time.monotonic() < deadline:
                time.sleep(0.01)
                result = acquire()
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(files["state"].read_text(), "failed\n")

    def test_missing_host_flock_fails_before_opening_lock_or_starting_worker(self):
        with tempfile.TemporaryDirectory(prefix="osgard-missing-flock-") as directory:
            lock = Path(directory) / "lock"
            script = ("set -euo pipefail\nOSGARD_ACTIVATION_LOCK=" + shlex.quote(str(lock)) +
                      "\n" + shell_function("acquire_activation_lock") + "\nacquire_activation_lock\n")
            completed = subprocess.run(["/bin/bash", "--noprofile", "--norc"], input=script,
                                       text=True, capture_output=True, env={"PATH": "/nonexistent"}, timeout=2)
            self.assertEqual(completed.returncode, 1)
            self.assertFalse(lock.exists())


class OwnedRolloutTests(unittest.TestCase):
    NETWORK_ID = "a" * 64
    SECOND_NETWORK_ID = "b" * 64

    def container_metadata(self, **changes):
        return {"network": "fixture-network", "ports": {"8080/tcp": None}, "configuredPorts": {},
                "publishAllPorts": False, "running": True,
                "networks": {"fixture-network": {"NetworkID": self.NETWORK_ID}}, **changes}

    def network_metadata(self, **changes):
        return {"id": self.NETWORK_ID, "name": "fixture-network", "driver": "bridge", "scope": "local",
                "internal": False, "ingress": False, "configOnly": False, "options": {}, **changes}

    def run_gate(self, flag="1", probe_status=0, metadata=None, inspect_status=0,
                 networks=None, network_status=0, version="28.5.1", version_status=0):
        if metadata is None:
            metadata = self.container_metadata()
        if networks is None:
            networks = {self.NETWORK_ID: self.network_metadata()}
        with tempfile.TemporaryDirectory(prefix="osgard-owned-rollout-") as directory:
            calls = Path(directory) / "calls"
            calls.write_text("")
            values = {"remix_owned_creation": flag, "fixture_probe_status": str(probe_status),
                      "fixture_inspect_status": str(inspect_status), "fixture_metadata": json.dumps(metadata),
                      "fixture_networks": json.dumps(networks), "fixture_network_status": str(network_status),
                      "fixture_version": version, "fixture_version_status": str(version_status),
                      "fixture_calls": str(calls)}
            assignments = "\n".join(f"{key}={shlex.quote(value)}" for key, value in values.items())
            script = "set -euo pipefail\n" + assignments + r'''
docker() {
  printf '%s\n' "$1" >> "$fixture_calls"
  case "$1" in
    exec) return "$fixture_probe_status" ;;
    inspect) printf '%s\n' "$fixture_metadata"; return "$fixture_inspect_status" ;;
    version) printf '%s\n' "$fixture_version"; return "$fixture_version_status" ;;
    network)
      [[ "${2:-}" == "inspect" ]] || return 99
      [[ "$fixture_network_status" == "0" ]] || return "$fixture_network_status"
      python3 -c 'import json,sys; print(json.dumps(json.loads(sys.argv[1]).get(sys.argv[2])))' "$fixture_networks" "${@: -1}"
      ;;
    *) return 99 ;;
  esac
}
''' + shell_function("verify_remix_owned_rollout") + "\nverify_remix_owned_rollout\n"
            result = subprocess.run(["/bin/bash", "--noprofile", "--norc"], input=script,
                                    text=True, capture_output=True, timeout=4,
                                    env={"PATH": os.environ.get("PATH", "/usr/bin:/bin")})
            return result, calls.read_text().splitlines()

    def test_disabled_foundation_needs_no_prior_auth_build(self):
        result, calls = self.run_gate(flag="0", probe_status=1, metadata={"unrecognized": True},
                                      version="unrecognized", network_status=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_invalid_creation_setting_fails_before_docker(self):
        for flag in ("", "true", "2", "1; echo invalid"):
            with self.subTest(flag=flag):
                result, calls = self.run_gate(flag=flag)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(calls, [])

    def test_unverified_old_guard_cannot_be_the_enabled_release_rollback(self):
        result, calls = self.run_gate(probe_status=1)
        self.assertEqual(result.returncode, 1)
        self.assertEqual(calls, ["exec"])
        self.assertIn("Deploy the disabled foundation first", result.stderr)

    def test_all_published_legacy_ports_including_loopback_are_rejected(self):
        for address in ("0.0.0.0", "::", "198.51.100.12", "", "127.0.0.1", "::1"):
            with self.subTest(address=address):
                result, calls = self.run_gate(metadata=self.container_metadata(ports={
                    "8080/tcp": [{"HostIp": address, "HostPort": "8080"}]}))
                self.assertEqual(result.returncode, 1)
                self.assertEqual(calls, ["exec", "inspect"])

    def test_unpublished_legacy_ports_on_verified_nat_bridge_are_accepted(self):
        for ports in ({"8080/tcp": None}, {}, None):
            with self.subTest(ports=ports):
                result, calls = self.run_gate(metadata=self.container_metadata(ports=ports, configuredPorts=ports))
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(calls, ["exec", "inspect", "version", "network"])

    def test_configured_or_automatic_port_publication_cannot_hide_behind_runtime_ports(self):
        for changes in ({"publishAllPorts": True}, {"configuredPorts": {"8080/tcp": [
                {"HostIp": "127.0.0.1", "HostPort": "8080"}]}}, {"ports": "unrecognized"}, {"running": False}):
            with self.subTest(changes=changes):
                result, calls = self.run_gate(metadata=self.container_metadata(**changes))
                self.assertEqual(result.returncode, 1)
                self.assertEqual(calls, ["exec", "inspect"])

    def test_actual_attached_driver_and_scope_are_checked_instead_of_network_name(self):
        for changes in ({"driver": "macvlan"}, {"driver": "ipvlan"}, {"driver": "overlay"},
                        {"driver": "unknown"}, {"scope": "swarm"}, {"scope": ""},
                        {"ingress": True}, {"configOnly": True}, {"internal": "unknown"}):
            with self.subTest(changes=changes):
                result, calls = self.run_gate(networks={self.NETWORK_ID: self.network_metadata(**changes)})
                self.assertEqual(result.returncode, 1)
                self.assertEqual(calls, ["exec", "inspect", "version", "network"])

    def test_each_attached_network_is_inspected_and_a_second_unsafe_driver_blocks_enable(self):
        attached = {"fixture-network": {"NetworkID": self.NETWORK_ID},
                    "second-network": {"NetworkID": self.SECOND_NETWORK_ID}}
        for driver, expected in (("bridge", 0), ("macvlan", 1)):
            with self.subTest(second_driver=driver):
                networks = {self.NETWORK_ID: self.network_metadata(), self.SECOND_NETWORK_ID: self.network_metadata(
                    id=self.SECOND_NETWORK_ID, name="second-network", driver=driver)}
                result, calls = self.run_gate(metadata=self.container_metadata(networks=attached), networks=networks)
                self.assertEqual(result.returncode, expected, result.stderr)
                self.assertEqual(calls, ["exec", "inspect", "version", "network", "network"])

    def test_routed_unprotected_and_unknown_gateway_modes_are_rejected_for_both_families(self):
        for family in ("ipv4", "ipv6"):
            for mode in ("routed", "nat-unprotected", "isolated", "unknown", ""):
                with self.subTest(family=family, mode=mode):
                    options = {"com.docker.network.bridge.gateway_mode_" + family: mode}
                    result, _ = self.run_gate(networks={self.NETWORK_ID: self.network_metadata(options=options)})
                    self.assertEqual(result.returncode, 1)
        options = {"com.docker.network.bridge.gateway_mode_ipv4": "nat",
                   "com.docker.network.bridge.gateway_mode_ipv6": "nat"}
        result, _ = self.run_gate(networks={self.NETWORK_ID: self.network_metadata(options=options)})
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_trusted_interfaces_and_nonstandard_bridge_options_are_rejected(self):
        invalid = [{"com.docker.network.bridge.trusted_host_interfaces": value} for value in ("", "eth0", "vxlan.1:eth3")]
        invalid += [{"com.docker.network.bridge.default_bridge": "true"},
                    {"com.docker.network.bridge.enable_ip_masquerade": "false"},
                    {"com.docker.network.bridge.gateway_mode_ipv4": None}]
        for options in invalid:
            with self.subTest(options=options):
                result, _ = self.run_gate(networks={self.NETWORK_ID: self.network_metadata(options=options)})
                self.assertEqual(result.returncode, 1)

    def test_network_identity_missing_or_mismatched_metadata_fails_closed(self):
        for changes in ({"id": self.SECOND_NETWORK_ID}, {"name": "wrong-network"}):
            result, _ = self.run_gate(networks={self.NETWORK_ID: self.network_metadata(**changes)})
            self.assertEqual(result.returncode, 1)
        for attached in ({}, {"bridge": {"NetworkID": self.NETWORK_ID}},
                         {"fixture-network": {"NetworkID": "malformed"}},
                         {"fixture-network": {"NetworkID": self.NETWORK_ID}, "duplicate": {"NetworkID": self.NETWORK_ID}}):
            result, _ = self.run_gate(metadata=self.container_metadata(networks=attached))
            self.assertEqual(result.returncode, 1)
        result, _ = self.run_gate(networks={})
        self.assertEqual(result.returncode, 1)
        result, _ = self.run_gate(network_status=1)
        self.assertEqual(result.returncode, 1)

    def test_unsupported_or_unavailable_engine_version_cannot_claim_unpublished_port_protection(self):
        for version in ("27.5.1", "20.10.27", "28.0.0-rc.1", "unrecognized", ""):
            with self.subTest(version=version):
                result, calls = self.run_gate(version=version)
                self.assertEqual(result.returncode, 1)
                self.assertEqual(calls, ["exec", "inspect", "version"])
        result, _ = self.run_gate(version_status=1)
        self.assertEqual(result.returncode, 1)

    def test_shared_host_network_or_unavailable_metadata_fails_closed(self):
        for network in ("host", "container:other-fixture", "bridge", "default", "not-actually-attached"):
            result, _ = self.run_gate(metadata=self.container_metadata(network=network))
            self.assertEqual(result.returncode, 1)
        result, _ = self.run_gate(metadata={"unrecognized": True})
        self.assertEqual(result.returncode, 1)
        result, _ = self.run_gate(inspect_status=1)
        self.assertEqual(result.returncode, 1)

    def test_rollout_gate_precedes_any_service_replacement(self):
        call = ACTIVATION.index("\n  verify_remix_owned_rollout\n")
        self.assertLess(call, ACTIVATION.index("docker stop osgard-core-api"))
        self.assertLess(call, ACTIVATION.index("docker stop osgard-remix-guard"))


class ParticipantRolloutTests(unittest.TestCase):
    def run_gate(self, admission='0', creation='1', probe_status=0):
        with tempfile.TemporaryDirectory(prefix='osgard-participant-rollout-') as directory:
            calls = Path(directory) / 'calls'
            calls.write_text('')
            values = dict(remix_participant_admission=admission, remix_owned_creation=creation,
                          fixture_probe_status=str(probe_status), fixture_calls=str(calls))
            assignments = '\n'.join(f'{key}={shlex.quote(value)}' for key, value in values.items())
            script = ('set -euo pipefail\n' + assignments + r'''
docker() {
  printf '%s\n' "$1" >> "$fixture_calls"
  [[ "$1" == "exec" && "$2" == "osgard-remix-guard" ]] || return 99
  return "$fixture_probe_status"
}
''' + shell_function('verify_remix_participant_rollout') + '\nverify_remix_participant_rollout\n')
            result = subprocess.run(['/bin/bash', '--noprofile', '--norc'], input=script,
                                    text=True, capture_output=True, timeout=3, env={'PATH': '/nonexistent'})
            return result, calls.read_text().splitlines()

    def test_published_admission_default_preserves_explicit_disable_override(self):
        assignments = re.findall(r'^remix_participant_admission=.*$', ACTIVATION, re.M)
        self.assertEqual(len(assignments), 1)
        for value, expected in ((None, '1'), ('0', '0'), ('1', '1'), ('', '1')):
            with self.subTest(environment=value):
                env = {'PATH': '/nonexistent'}
                if value is not None:
                    env['OSGARD_REMIX_PARTICIPANT_ADMISSION'] = value
                result = subprocess.run(
                    ['/bin/bash', '--noprofile', '--norc'],
                    input='set -euo pipefail\n' + assignments[0] + '\nprintf "%s" "$remix_participant_admission"\n',
                    text=True, capture_output=True, timeout=3, env=env)
                self.assertEqual(result.returncode, 0, result.stderr)
                self.assertEqual(result.stdout, expected)

    def test_disabled_participant_foundation_allows_current_owner_only_rollback(self):
        result, calls = self.run_gate(admission='0', probe_status=1)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(calls, [])

    def test_enabling_requires_verified_participant_rollback(self):
        for probe_status in (0, 1):
            result, calls = self.run_gate(admission='1', probe_status=probe_status)
            self.assertEqual(result.returncode, probe_status)
            self.assertEqual(calls, ['exec'])
            if probe_status:
                self.assertIn('Deploy the disabled participant foundation first', result.stderr)

    def test_invalid_admission_or_unprotected_creation_stops_before_docker(self):
        for admission, creation in (('', '1'), ('true', '1'), ('2', '1'), ('1', '0')):
            result, calls = self.run_gate(admission, creation)
            self.assertEqual(result.returncode, 1)
            self.assertEqual(calls, [])

    def test_participant_gate_runs_before_replacing_either_service(self):
        gate = ACTIVATION.index('\n  verify_remix_participant_rollout\n')
        self.assertLess(gate, ACTIVATION.index('docker stop osgard-core-api'))
        self.assertLess(gate, ACTIVATION.index('docker stop osgard-remix-guard'))


if __name__ == "__main__":
    unittest.main()
