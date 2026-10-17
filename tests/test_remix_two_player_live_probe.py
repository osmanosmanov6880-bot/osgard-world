"""Offline contract and transport fixtures for the bounded guest QA probe.

No sockets, browser, Docker, Core credentials or production records are used.
HTTPConnection is replaced at the probe's explicit factory boundary. Two alarm
tests deliberately block that fake transport to verify the real POSIX deadline.
"""

import contextlib
import importlib.util
import io
import json
from pathlib import Path
import signal
import tempfile
import time
import unittest
from unittest.mock import patch


ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("remix_two_player_live_probe", ROOT / "scripts/remix-two-player-live-smoke.py")
probe_module = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(probe_module)
RELEASE = "75a3251ae5cc"
PRIVATE = "never-retain-proxy-user-password-or-reflected-body"
REAL_SLEEP = time.sleep


class Clock:
    def __init__(self):
        self.now = 10000.0

    def monotonic(self):
        return self.now

    def sleep(self, seconds):
        self.now += seconds


class Response:
    def __init__(self, status, value, *, html=False, cache=True, raw=None, mime=None):
        self.status = status
        self.headers = {"Content-Type": mime or ("text/html" if html else "application/json")}
        if cache:
            self.headers["Cache-Control"] = "no-store"
        self.raw = raw if raw is not None else value.encode() if html else json.dumps(value).encode()

    def getheader(self, key, default=None):
        return self.headers.get(key, default)

    def read(self, limit):
        return self.raw[:limit]


class Engine:
    def __init__(self, clock):
        self.clock = clock
        self.calls, self.connections = [], []
        self.created_at = None
        self.scores, self.sequences = {}, {}
        self.frames = self.root_reads = 0
        self.hook = None
        self.reject_second_player = False
        self.accept_duplicate = False
        self.mutate_late = False
        self.wrong_second_ack = False
        self.drop_input_response = False
        self.wrong_result = False
        self.changed_release = False
        self.private_extra = False
        self.plain_duplicates = False

    def phase(self):
        elapsed = self.clock.now - self.created_at
        return ("COUNTDOWN", int((2.5 - elapsed) * 1000)) if elapsed < 2.5 else ("PLAYING", int((33 - elapsed) * 1000)) if elapsed < 33 else ("RESULTS", 0)

    def state(self):
        phase, remaining = self.phase()
        return {"id": "match_guest.1", "phase": phase, "remainingMs": remaining, "players": len(self.scores),
                "replayFrames": self.frames, "scores": [{"playerId": player, "score": score} for player, score in self.scores.items()]}

    def response(self, call):
        method, path, body, headers = call
        if self.hook:
            value = self.hook(call)
            if value is not None:
                return value
        if path == "/":
            self.root_reads += 1
            release = "111111111111" if self.changed_release and self.root_reads > 1 else RELEASE
            return Response(200, f'<script src="/brand/osa-transition.js?v={release}"></script>', html=True)
        if path == "/api/remix/health":
            return Response(200, {"status": "ok", "service": "osgard-remix-guard", "frozenResults": True, "extra": PRIVATE})
        if path == "/api/remix/v1/challenges":
            return Response(201, {"id": "ch_guest_fixture", **body, "extra": PRIVATE})
        if path == "/api/remix/v1/matches":
            self.created_at = self.clock.now
            return Response(201, {"id": "match_guest.1", **body, "createdAt": "2026-10-17T12:00:00Z", "extra": PRIVATE})
        if path.endswith("/state"):
            return Response(200, dict(self.state(), **({"extra": PRIVATE} if self.private_extra else {})))
        if path.endswith("/result"):
            state = self.state()
            if state["phase"] != "RESULTS":
                return Response(409, {"error": "not_finished", "private": PRIVATE})
            scores = state["scores"][:1] if self.wrong_result else state["scores"]
            return Response(200, {"matchId": "match_guest.1", "phase": "RESULTS", "scores": scores,
                                  "replayFrames": self.frames, "extra": PRIVATE})
        if path.endswith("/input"):
            player, sequence = body["playerId"], body["sequence"]
            if self.phase()[0] != "PLAYING":
                if self.mutate_late:
                    self.frames += 1
                    self.scores[player] += 1
                return Response(409, {"error": "not_playing", "private": PRIVATE})
            if self.reject_second_player and self.sequences and player not in self.sequences:
                return Response(409, {"error": "global_sequence", "private": PRIVATE})
            if sequence <= self.sequences.get(player, 0) and not self.accept_duplicate:
                if self.plain_duplicates:
                    return Response(409, None, mime="text/plain; charset=utf-8", raw=b"stale input sequence\n")
                return Response(409, {"error": "duplicate", "private": PRIVATE})
            self.sequences[player] = sequence
            self.frames += 1
            self.scores[player] = self.scores.get(player, 0) + 0.25
            if self.drop_input_response:
                raise OSError(PRIVATE)
            ack_player = next(iter(self.sequences)) if self.wrong_second_ack and len(self.sequences) > 1 else player
            return Response(200, {"playerId": ack_player, "position": [0.25, 0, 0], "velocityY": 0,
                                  "onGround": True, "score": self.scores[player], "lastSequence": sequence, "extra": PRIVATE})
        raise AssertionError("Unexpected fixture route")

    def connection(self, host, port, *, timeout):
        self.connections.append((host, port, timeout))
        engine = self

        class Connection:
            def request(self, method, path, body=None, headers=None):
                self.call = (method, path, json.loads(body) if body else None, headers)
                engine.calls.append(self.call)

            def getresponse(self):
                return engine.response(self.call)

            def close(self):
                pass
        return Connection()


class TwoPlayerProbeTests(unittest.TestCase):
    def setUp(self):
        self.clock = Clock()
        self.engine = Engine(self.clock)
        self.monotonic = patch.object(probe_module.time, "monotonic", self.clock.monotonic)
        self.sleep = patch.object(probe_module.time, "sleep", self.clock.sleep)
        self.monotonic.start()
        self.sleep.start()
        self.addCleanup(self.sleep.stop)
        self.addCleanup(self.monotonic.stop)

    def probe(self, exercise=True, **kwargs):
        return probe_module.Probe(exercise, RELEASE, connection=self.engine.connection, **kwargs)

    def posts(self):
        return [call for call in self.engine.calls if call[0] == "POST"]

    def test_default_is_three_reads_with_no_accounts_challenges_or_match_writes(self):
        probe = self.probe(False)
        self.assertTrue(probe.run())
        self.assertEqual([(method, path) for method, path, *_ in self.engine.calls],
                         [("GET", "/"), ("GET", "/api/remix/health"), ("GET", "/")])
        self.assertEqual(probe.report["postAttempts"], {"challenge": 0, "match": 0, "input": 0})

    def test_full_guest_exercise_has_exact_eight_bounded_posts_and_two_sequence_one_players(self):
        probe = self.probe()
        self.assertTrue(probe.run(), probe.report)
        self.assertEqual(probe.report["status"], "PASS")
        self.assertEqual(len(probe.report["checks"]), 8)
        self.assertEqual(len(self.posts()), 8)
        self.assertEqual(probe.report["postAttempts"], {"challenge": 1, "match": 1, "input": 6})
        self.assertEqual(self.posts()[0][2]["visibility"], "private")
        self.assertIn("OSGARD QA", self.posts()[0][2]["title"])
        self.assertEqual(self.posts()[1][2], {"challengeId": "ch_guest_fixture", "maxPlayers": 2})
        self.assertEqual([call[2]["sequence"] for call in self.posts()[2:]], [1, 1, 1, 1, 2, 2])
        self.assertEqual(len({item["playerId"] for item in probe.report["acceptedInputs"]}), 2)
        self.assertEqual(probe.report["result"]["replayFrames"], 2)
        self.assertLess(len(probe.report["requests"]), 72)
        self.assertLess(probe.report["durationSeconds"], 90)
        self.assertTrue(all(entry["outcome"] == "received" for entry in probe.report["requests"]))
        self.assertTrue(all(host == "osgard.world" and port == 443 and 0 < timeout <= 10 for host, port, timeout in self.engine.connections))

    def test_second_player_global_sequence_bug_is_failure_not_retried_as_sequence_two(self):
        self.engine.reject_second_player = True
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 4)
        self.assertEqual([row[2]["sequence"] for row in self.posts()[2:]], [1, 1])
        self.assertEqual(probe.report["requests"][-1]["status"], 409)
        self.assertNotIn("resultSha256", probe.report)

    def test_accepting_duplicate_input_is_a_failure(self):
        self.engine.accept_duplicate = True
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 5)
        self.assertEqual(probe.report["requests"][-1]["expectedStatus"], 409)
        self.assertEqual(probe.report["requests"][-1]["status"], 200)

    def test_documented_plain_text_duplicate_409_completes_with_two_unchanged_frames(self):
        self.engine.plain_duplicates = True
        probe = self.probe()
        self.assertTrue(probe.run(), probe.report)
        self.assertEqual(len(self.posts()), 8)
        rejections = [entry for entry in probe.report["requests"] if entry.get("status") == 409]
        self.assertEqual([entry["contentType"] for entry in rejections], ["text/plain", "text/plain", "application/json", "application/json"])
        self.assertEqual([entry["bytes"] for entry in rejections[:2]], [21, 21])
        self.assertTrue(all(entry["noStore"] and entry["outcome"] == "received" for entry in rejections))
        self.assertEqual(probe.report["result"]["replayFrames"], 2)
        self.assertEqual(len(probe.report["result"]["scores"]), 2)
        self.assertEqual(self.engine.frames, 2)
        self.assertNotIn("stale input sequence", json.dumps(probe.report))

    def test_html_duplicate_409_is_rejected_without_retaining_its_body(self):
        def reject(call):
            if call[1].endswith("/input") and call[2]["sequence"] <= self.engine.sequences.get(call[2]["playerId"], 0):
                return Response(409, PRIVATE, html=True)
        self.engine.hook = reject
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 5)
        self.assertEqual(probe.report["requests"][-1]["status"], 409)
        self.assertEqual(probe.report["requests"][-1]["contentType"], "text/html")
        self.assertNotIn("resultSha256", probe.report)
        self.assertNotIn(PRIVATE, json.dumps(probe.report))

    def test_plain_text_409_still_requires_no_store_and_a_bounded_body(self):
        for cache, raw in ((False, b"stale input sequence\n"), (True, b"x" * (probe_module.MAX_BODY + 1))):
            with self.subTest(cache=cache, size=len(raw)):
                self.engine = Engine(self.clock)
                def reject(call):
                    if call[1].endswith("/input") and call[2]["sequence"] <= self.engine.sequences.get(call[2]["playerId"], 0):
                        return Response(409, None, mime="text/plain", raw=raw, cache=cache)
                self.engine.hook = reject
                probe = self.probe()
                self.assertFalse(probe.run())
                self.assertEqual(len(self.posts()), 5)
                self.assertEqual(probe.report["requests"][-1]["status"], 409)
                self.assertNotIn("resultSha256", probe.report)

    def test_plain_text_success_is_rejected_even_for_a_valid_accepted_input(self):
        def wrong_type(call):
            if call[1].endswith("/input"):
                return Response(200, None, mime="text/plain", raw=b"accepted\n")
        self.engine.hook = wrong_type
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 3)
        self.assertEqual(probe.report["requests"][-1]["status"], 200)
        self.assertEqual(probe.report["requests"][-1]["contentType"], "text/plain")
        self.assertNotIn("acceptedInputs", probe.report)

    def test_plain_text_duplicate_409_cannot_hide_an_extra_frame_or_reflect_private_text(self):
        def mutate(call):
            if call[1].endswith("/input") and call[2]["sequence"] <= self.engine.sequences.get(call[2]["playerId"], 0):
                self.engine.frames += 1
                return Response(409, None, mime="text/plain; reflected=" + PRIVATE, raw=PRIVATE.encode())
        self.engine.hook = mutate
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 6)
        self.assertEqual(self.engine.frames, 4)
        self.assertEqual(probe.report["stateObservations"][-1]["replayFrames"], 4)
        self.assertNotIn("resultSha256", probe.report)
        self.assertNotIn(PRIVATE, json.dumps(probe.report))

    def test_late_409_with_mutated_result_still_fails_immutability(self):
        self.engine.mutate_late = True
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 8)
        self.assertNotIn("resultSha256", probe.report)
        self.assertGreater(self.engine.frames, 2)

    def test_result_must_contain_both_players_and_exact_accepted_frame_count(self):
        self.engine.wrong_result = True
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 6)
        self.assertNotIn("resultSha256", probe.report)

    def test_second_ack_bound_to_first_player_is_not_success(self):
        self.engine.wrong_second_ack = True
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 4)
        self.assertEqual(len(probe.report["acceptedInputs"]), 1)

    def test_lost_post_response_is_journaled_uncertain_without_retry(self):
        self.engine.drop_input_response = True
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 3)
        self.assertEqual(self.engine.frames, 1)
        self.assertEqual(probe.report["requests"][-1]["outcome"], "uncertain")
        self.assertEqual(probe.report["requests"][-1]["input"]["sequence"], 1)
        self.assertNotIn(PRIVATE, json.dumps(probe.report))

    def test_lost_creation_consumes_budget_before_response_and_cannot_be_reissued(self):
        self.engine.hook = lambda call: (_ for _ in ()).throw(OSError(PRIVATE)) if call[1] == "/api/remix/v1/challenges" else None
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 1)
        with self.assertRaises(probe_module.ProbeFailure):
            probe.request("POST", "/api/remix/v1/challenges", probe.challenge_payload(), expected=201)
        self.assertEqual(len(self.posts()), 1)
        self.assertEqual(probe.report["requests"][-1]["outcome"], "uncertain")

    def test_reflected_unknown_fields_and_error_messages_never_enter_artifact(self):
        self.engine.private_extra = True
        probe = self.probe()
        self.assertTrue(probe.run())
        self.assertNotIn(PRIVATE, json.dumps(probe.report))
        for _, _, _, headers in self.engine.calls:
            self.assertFalse({key.lower() for key in headers} & {"authorization", "cookie", "proxy-authorization"})
        self.assertFalse(any("/core/" in row[1] or "/v2/" in row[1] for row in self.engine.calls))

    def test_wrong_initial_release_prevents_all_posts_and_later_change_prevents_pass(self):
        probe = probe_module.Probe(True, "ffffffffffff", connection=self.engine.connection)
        self.assertFalse(probe.run())
        self.assertEqual(len(self.engine.calls), 1)
        self.assertEqual(self.posts(), [])
        self.engine = Engine(self.clock)
        self.engine.changed_release = True
        probe = self.probe()
        self.assertFalse(probe.run())
        self.assertEqual(len(self.posts()), 8)

    def test_unpinned_exercise_is_rejected_before_transport(self):
        with self.assertRaises(probe_module.ProbeFailure):
            probe_module.Probe(True, "", connection=self.engine.connection)
        self.assertEqual(self.engine.calls, [])

    def test_fixed_allowlist_blocks_core_other_match_and_unbounded_commands(self):
        probe = self.probe()
        for method, path, body in (("POST", "/api/core/auth/register", {}), ("GET", "/api/remix/v2/matches", None),
                                   ("POST", "/api/remix/v1/matches/other/input", {}), ("GET", "/api/remix/health?target=elsewhere", None)):
            with self.subTest(path=path), self.assertRaises(probe_module.ProbeFailure):
                probe.request(method, path, body)
        self.assertEqual(self.engine.calls, [])
        self.assertEqual(probe.report["requests"], [])

    def test_proxy_configuration_is_checked_once_and_never_written_or_bypassed(self):
        proxy = object()
        with patch.object(probe_module.transport, "runtime_proxy", return_value=proxy) as setup, \
             patch.object(probe_module.transport, "connection_factory", return_value=self.engine.connection) as factory:
            probe = probe_module.Probe(False, RELEASE)
            self.assertTrue(probe.run())
            setup.assert_called_once_with()
            factory.assert_called_once_with(proxy)
        with patch.object(probe_module.transport, "runtime_proxy", side_effect=probe_module.transport.ProxyConfigurationError(PRIVATE)), \
             patch.object(probe_module.transport, "connection_factory") as factory:
            probe = probe_module.Probe(True, RELEASE)
            self.assertFalse(probe.run())
            factory.assert_not_called()
            self.assertEqual(probe.report["requests"], [])
            self.assertNotIn(PRIVATE, json.dumps(probe.report))

    def test_redirect_non_json_missing_no_store_duplicate_json_and_large_body_are_rejected(self):
        bad = [Response(302, {"location": PRIVATE}), Response(200, "not-json", html=True),
               Response(200, {"status": "ok"}, cache=False), Response(200, None, raw=b'{"status":"ok","status":"wrong"}'),
               Response(200, None, raw=b"x" * (probe_module.MAX_BODY + 1))]
        for response in bad:
            with self.subTest(status=response.status, size=len(response.raw)):
                self.engine = Engine(self.clock)
                self.engine.hook = lambda call: response if call[1] == "/api/remix/health" else None
                probe = self.probe()
                self.assertFalse(probe.run())
                self.assertEqual(len(self.engine.calls), 2)
                self.assertEqual(self.posts(), [])
                self.assertNotIn(PRIVATE, json.dumps(probe.report))

    def test_fake_clock_cannot_complete_a_request_after_its_deadline(self):
        def delay(call):
            self.clock.now += 11
            return Response(200, '<script src="/brand/osa-transition.js?v=' + RELEASE + '"></script>', html=True)
        self.engine.hook = delay
        probe = self.probe(False)
        self.assertFalse(probe.run())
        self.assertEqual(len(self.engine.calls), 1)
        self.assertEqual(probe.report["requests"][0]["outcome"], "failed")

    def test_total_deadline_and_request_count_prevent_further_dispatch(self):
        probe = self.probe(False)
        probe.deadline = self.clock.now
        with self.assertRaises(probe_module.ProbeFailure):
            probe.request("GET", "/")
        probe.deadline += 90
        probe.report["requests"] = [{}] * probe_module.MAX_REQUESTS
        with self.assertRaises(probe_module.ProbeFailure):
            probe.request("GET", "/")
        self.assertEqual(self.engine.calls, [])

    def test_report_is_exclusive_private_and_records_intent_before_dispatch(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / "evidence.json"
            probe = self.probe(output=output)
            def observe(call):
                persisted = json.loads(output.read_text())
                self.assertEqual(persisted["requests"][-1]["outcome"], "pending")
                return None
            self.engine.hook = observe
            self.assertTrue(probe.run())
            self.assertEqual(output.stat().st_mode & 0o777, 0o600)
            self.assertEqual(json.loads(output.read_text())["status"], "PASS")
            before = output.read_bytes()
            with self.assertRaises(FileExistsError):
                self.probe(output=output)
            self.assertEqual(output.read_bytes(), before)
            link = Path(directory) / "link.json"
            link.symlink_to(output)
            with self.assertRaises(FileExistsError):
                self.probe(output=link)
            self.assertNotIn(PRIVATE, output.read_text())

    def test_cli_preserves_explicit_flags_and_default_does_not_enable_writes(self):
        with patch.object(probe_module.transport, "runtime_proxy", return_value=None), \
             patch.object(probe_module.transport, "connection_factory", return_value=self.engine.connection), \
             contextlib.redirect_stdout(io.StringIO()) as output:
            self.assertEqual(probe_module.main([]), 0)
            self.assertEqual(json.loads(output.getvalue())["postAttempts"], {"challenge": 0, "match": 0, "input": 0})
        self.assertEqual(self.posts(), [])
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(probe_module.main(["--exercise-two-player"]), 2)
        self.assertEqual(self.posts(), [])


class RealAlarmTests(unittest.TestCase):
    def test_whole_request_alarm_interrupts_fake_constructor_and_cancels_its_timer(self):
        def blocked(host, port, *, timeout):
            REAL_SLEEP(0.3)
            raise AssertionError("Alarm did not interrupt construction")
        probe = probe_module.Probe(False, RELEASE, connection=blocked)
        probe.deadline = time.monotonic() + 0.04
        started = time.monotonic()
        self.assertFalse(probe.run())
        self.assertLess(time.monotonic() - started, 0.2)
        self.assertEqual(signal.getitimer(signal.ITIMER_REAL)[0], 0)
        self.assertEqual(probe.report["requests"][0]["outcome"], "failed")

    def test_alarm_on_uncertain_post_restores_prior_handler_and_live_timer(self):
        class Connection:
            def request(self, *args, **kwargs):
                pass
            def getresponse(self):
                REAL_SLEEP(0.3)
            def close(self):
                pass
        old_handler = signal.getsignal(signal.SIGALRM)
        old_timer = signal.getitimer(signal.ITIMER_REAL)
        own_handler = lambda signum, frame: None
        try:
            signal.signal(signal.SIGALRM, own_handler)
            signal.setitimer(signal.ITIMER_REAL, 0.8)
            probe = probe_module.Probe(True, RELEASE, connection=lambda *args, **kwargs: Connection())
            probe.deadline = time.monotonic() + 0.04
            with self.assertRaises(probe_module.ProbeFailure):
                probe.request("POST", "/api/remix/v1/challenges", probe.challenge_payload(), expected=201)
            self.assertEqual(probe.post_counts["challenge"], 1)
            self.assertEqual(probe.report["requests"][0]["outcome"], "uncertain")
            self.assertIs(signal.getsignal(signal.SIGALRM), own_handler)
            remaining, interval = signal.getitimer(signal.ITIMER_REAL)
            self.assertTrue(0.5 < remaining < 0.8)
            self.assertEqual(interval, 0)
        finally:
            signal.setitimer(signal.ITIMER_REAL, 0)
            signal.signal(signal.SIGALRM, old_handler)
            if old_timer[0]:
                signal.setitimer(signal.ITIMER_REAL, *old_timer)


if __name__ == "__main__":
    unittest.main(verbosity=2)
