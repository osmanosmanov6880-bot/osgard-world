"""Real loopback HTTP/SQLite tests against a deliberately mutable legacy fixture.

The fixture models the observed public protocol bug; these tests do not run the
unavailable game source or claim live deployment verification.
"""

import copy
from concurrent.futures import ThreadPoolExecutor
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
from pathlib import Path
import socket
import sqlite3
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))
import remix_guard as guard


MATCH = "match_existing.1"
PLAYER = "qa-guard-player"
INPUT = {"playerId": PLAYER, "sequence": 1, "moveX": 1, "moveY": 0, "jump": False}


class Legacy:
    def __init__(self):
        self.lock = threading.RLock()
        self.state = {"id": MATCH, "phase": "PLAYING", "players": 0, "remainingMs": 30000,
                      "replayFrames": 0, "scores": []}
        self.result_status = 200
        self.state_override = None
        self.result_override = None
        self.calls = []
        self.input_count = 0
        self.drop_post = False
        self.delay_close_post = False
        self.delay_state = 0
        self.drip_state_headers = False
        self.finish_on_result = False
        self.enter_post = None
        self.release_post = None

    def terminal(self, score=0.25, frames=3):
        with self.lock:
            self.state.update(phase="RESULTS", remainingMs=0, players=1,
                              replayFrames=frames, scores=[{"playerId": PLAYER, "score": score}])

    def result(self):
        return {"matchId": MATCH, "phase": "RESULTS", "replayFrames": self.state["replayFrames"],
                "scores": copy.deepcopy(self.state["scores"])}


class LegacyHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def answer(self, status, value, content_type="application/json"):
        body = value if isinstance(value, bytes) else (json.dumps(value).encode() if content_type == "application/json" else value.encode())
        self.send_response(status)
        self.send_header("Content-Type", content_type)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("X-Legacy-Fixture", "transparent")
        self.end_headers()
        try:
            self.wfile.write(body)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        legacy = self.server.legacy
        with legacy.lock:
            legacy.calls.append(("GET", self.path, None, dict(self.headers)))
        if self.path == "/health":
            return self.answer(200, {"status": "ok"})
        if self.path.endswith("/state"):
            if legacy.delay_state:
                time.sleep(legacy.delay_state)
            if legacy.drip_state_headers:
                try:
                    self.wfile.write(b"HTTP/1.0 200 OK\r\n")
                    for index in range(12):
                        self.wfile.write(f"X-Drip-{index}: pending\r\n".encode())
                        time.sleep(0.025)
                    self.wfile.write(b"Content-Length: 0\r\n\r\n")
                except (BrokenPipeError, ConnectionResetError):
                    pass
                return
            with legacy.lock:
                return self.answer(200, legacy.state_override if legacy.state_override is not None else legacy.state)
        if self.path.endswith("/result"):
            with legacy.lock:
                if legacy.finish_on_result:
                    legacy.terminal()
                if legacy.result_status != 200:
                    return self.answer(legacy.result_status, "result unavailable\n", "text/plain")
                if legacy.state["phase"] != "RESULTS":
                    return self.answer(409, "match has not reached results\n", "text/plain")
                return self.answer(200, legacy.result_override if legacy.result_override is not None else legacy.result())
        return self.answer(405, "method not allowed\n", "text/plain")

    def do_POST(self):
        legacy = self.server.legacy
        body = self.rfile.read(int(self.headers.get("Content-Length", "0")))
        value = json.loads(body) if body else {}
        with legacy.lock:
            legacy.calls.append(("POST", self.path, value, dict(self.headers)))
        if self.path.endswith("/input"):
            if legacy.enter_post:
                legacy.enter_post.set()
            if legacy.release_post:
                legacy.release_post.wait(3)
            with legacy.lock:
                # Deliberately reproduces the bug: input changes terminal results.
                legacy.input_count += 1
                legacy.state["players"] = 1
                legacy.state["replayFrames"] += 1
                legacy.state["scores"] = [{"playerId": value["playerId"], "score": legacy.state["replayFrames"] * 0.1}]
                reply = {"playerId": value["playerId"], "position": [legacy.input_count / 12, 0, 0],
                         "velocityY": 0, "onGround": True, "score": legacy.state["scores"][0]["score"],
                         "lastSequence": value["sequence"]}
                if legacy.drop_post:
                    self.connection.shutdown(socket.SHUT_RDWR)
                    self.connection.close()
                    return
                if legacy.delay_close_post:
                    try:
                        self.wfile.write(b"HTTP/1.0 200 OK\r\nContent-Type: application/json\r\nConnection: close\r\n\r\n")
                        self.wfile.write(json.dumps(reply).encode())
                        time.sleep(0.3)
                        self.wfile.write(b"\n")
                    except (BrokenPipeError, ConnectionResetError):
                        pass
                    return
                return self.answer(200, reply)
        if self.path == "/v1/challenges":
            return self.answer(201, dict(value, id="ch_fixture"))
        if self.path == "/v1/matches":
            return self.answer(201, dict(value, id=MATCH))
        return self.answer(404, "not found\n", "text/plain")


class GuardTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="osgard-remix-guard-tests-")
        self.database = Path(self.temporary.name) / "terminal.sqlite3"
        self.legacy = Legacy()
        self.backend = ThreadingHTTPServer(("127.0.0.1", 0), LegacyHandler)
        self.backend.daemon_threads = True
        self.backend.legacy = self.legacy
        self.backend_thread = threading.Thread(target=self.backend.serve_forever, daemon=True)
        self.backend_thread.start()
        self.backend_base = f"http://127.0.0.1:{self.backend.server_address[1]}"
        self.backend_live = True
        self.start_guard()

    def start_guard(self, **kwargs):
        self.server = guard.create_server(self.database, self.backend_base, port=0, **kwargs)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.port = self.server.server_address[1]

    def stop_guard(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(3)

    def stop_backend(self):
        if self.backend_live:
            self.backend.shutdown()
            self.backend.server_close()
            self.backend_thread.join(3)
            self.backend_live = False

    def tearDown(self):
        if self.legacy.release_post:
            self.legacy.release_post.set()
        self.stop_guard()
        self.stop_backend()
        self.temporary.cleanup()

    def request(self, path, body=None, headers=None, method=None):
        client = http.client.HTTPConnection("127.0.0.1", self.port, timeout=5)
        data = json.dumps(body).encode() if body is not None else None
        try:
            client.request(method or ("POST" if body is not None else "GET"), path, data,
                           {"Content-Type": "application/json", **(headers or {})})
            response = client.getresponse()
            raw = response.read()
            try:
                value = json.loads(raw)
            except ValueError:
                value = raw.decode()
            return response.status, value, dict(response.getheaders()), raw
        finally:
            client.close()

    def get(self, action="state"):
        return self.request(f"/v1/matches/{MATCH}/{action}")

    def input(self, sequence=1):
        return self.request(f"/v1/matches/{MATCH}/input", dict(INPUT, sequence=sequence))

    def test_health_requires_writable_store_and_legacy_health(self):
        status, value, _, _ = self.request("/health")
        self.assertEqual(status, 200)
        self.assertEqual((value["status"], value["schemaVersion"], value["frozenResults"]), ("ok", 1, True))
        self.assertFalse(value["replayVerification"] or value["playerAuthentication"] or value["activeMatchRecovery"])
        with patch.object(self.server.guard.store, "probe", side_effect=sqlite3.OperationalError("read only")):
            self.assertEqual(self.request("/health")[0], 503)

    def test_countdown_and_zero_clock_input_never_reach_mutable_backend(self):
        for phase, remaining in (("COUNTDOWN", 2500), ("WAITING", 0), ("PLAYING", 0)):
            self.legacy.state.update(phase=phase, remainingMs=remaining)
            status, value, _, _ = self.input()
            self.assertEqual((status, value["error"]), (409, "match_not_playing"))
        self.assertEqual(self.legacy.input_count, 0)
        self.assertFalse(any(method == "POST" for method, *_ in self.legacy.calls))

    def test_playing_input_is_preceded_by_matching_state_and_forwarded_once(self):
        status, value, _, _ = self.input()
        self.assertEqual((status, value["lastSequence"], self.legacy.input_count), (200, 1, 1))
        self.assertEqual([(method, path.rsplit("/", 1)[-1]) for method, path, *_ in self.legacy.calls],
                         [("GET", "state"), ("POST", "input")])

    def test_first_late_input_records_terminal_marker_and_never_forwards(self):
        self.legacy.terminal()
        status, value, _, _ = self.input()
        self.assertEqual((status, value["error"], self.legacy.input_count), (409, "match_finished", 0))
        self.assertIsNotNone(self.server.guard.store.load(MATCH))
        self.assertEqual(self.get("result")[0], 200)

    def test_first_read_of_preexisting_match_freezes_both_dtos(self):
        self.legacy.terminal()
        result = self.get("result")
        state = self.get("state")
        self.assertEqual((result[0], state[0]), (200, 200))
        request_count = len(self.legacy.calls)
        self.legacy.terminal(score=999, frames=99)
        self.assertEqual(self.get("result")[3], result[3])
        self.assertEqual(self.get("state")[3], state[3])
        self.assertEqual(len(self.legacy.calls), request_count)
        self.assertEqual(self.input()[0], 409)

    def test_frozen_snapshots_survive_guard_restart_and_upstream_outage(self):
        self.legacy.terminal()
        before_result, before_state = self.get("result"), self.get("state")
        self.stop_guard()
        self.stop_backend()
        self.start_guard(timeout=0.1)
        self.assertEqual(self.get("result")[3], before_result[3])
        self.assertEqual(self.get("state")[3], before_state[3])
        self.assertEqual(self.input()[0], 409)
        self.assertEqual(self.request("/health")[0], 503)

    def test_failed_result_fetch_retains_terminal_marker_and_never_exposes_scores(self):
        self.legacy.terminal()
        self.legacy.result_status = 503
        status, value, _, _ = self.get()
        self.assertEqual(status, 503)
        self.assertNotIn("scores", value)
        self.assertIsNone(self.server.guard.store.load(MATCH)["result"])
        self.stop_guard()
        self.start_guard()
        self.legacy.state.update(phase="PLAYING", remainingMs=30000)
        self.assertEqual(self.input()[0], 409)
        self.assertEqual(self.legacy.input_count, 0)
        self.legacy.terminal()
        self.legacy.result_status = 200
        self.assertEqual(self.get("result")[0], 200)

    def test_result_cannot_be_exposed_when_atomic_snapshot_commit_fails(self):
        self.legacy.terminal()
        with patch.object(self.server.guard.store, "finalize", side_effect=sqlite3.OperationalError("disk full")):
            status, value, _, _ = self.get("result")
            self.assertEqual((status, value["error"]), (503, "storage_unavailable"))
            self.assertNotIn("scores", value)
        self.assertIsNone(self.server.guard.store.load(MATCH)["result"])
        self.assertEqual(self.input()[0], 409)
        self.assertEqual(self.get("result")[0], 200)

    def test_disk_failure_before_input_fails_closed_without_upstream_request(self):
        with patch.object(self.server.guard.store, "probe", side_effect=sqlite3.OperationalError("disk full")):
            self.assertEqual(self.input()[0], 503)
        self.assertEqual(self.legacy.calls, [])
        self.assertEqual(self.legacy.input_count, 0)

    def test_terminal_marker_commit_failure_does_not_forward_late_input(self):
        self.legacy.terminal()
        with patch.object(self.server.guard.store, "mark_terminal", side_effect=sqlite3.OperationalError("disk full")):
            self.assertEqual(self.input()[0], 503)
            self.assertEqual(self.get()[0], 503)
        self.assertEqual(self.legacy.input_count, 0)

    def test_lost_post_response_is_not_retried(self):
        self.legacy.drop_post = True
        status, value, _, _ = self.input()
        self.assertEqual((status, value["error"]), (503, "upstream_write_uncertain"))
        self.assertEqual(self.legacy.input_count, 1)
        self.assertEqual(sum(method == "POST" for method, *_ in self.legacy.calls), 1)

    def test_wrong_state_id_never_unlocks_input(self):
        self.legacy.state_override = dict(self.legacy.state, id="another-match")
        self.assertEqual(self.input()[0], 503)
        self.assertEqual(self.legacy.input_count, 0)

    def test_malformed_terminal_observation_still_permanently_closes_inputs(self):
        self.legacy.terminal()
        self.legacy.state_override = dict(self.legacy.state, scores=[{"playerId": PLAYER, "score": float("nan")}])
        self.assertEqual(self.get()[0], 503)
        self.assertIsNotNone(self.server.guard.store.load(MATCH))
        self.legacy.state_override = None
        self.legacy.state.update(phase="PLAYING", remainingMs=30000)
        self.assertEqual(self.input()[0], 409)
        self.assertEqual(self.legacy.input_count, 0)

    def test_duplicate_nonidentity_json_fields_cannot_erase_terminal_marker(self):
        self.legacy.state_override = (f'{{"id":"{MATCH}","phase":"RESULTS",'
                                      '"scores":[],"scores":[],"remainingMs":0}').encode()
        self.assertEqual(self.get()[0], 503)
        self.assertEqual(self.server.guard.store.load(MATCH), {"state": None, "result": None})
        self.legacy.state_override = None
        self.assertEqual(self.input()[0], 409)
        self.assertEqual(self.legacy.input_count, 0)

    def test_wrong_result_id_nan_duplicates_and_mismatched_frame_count_fail_closed(self):
        self.legacy.terminal()
        valid = self.legacy.result()
        bad_results = [dict(valid, matchId="another-match"), dict(valid, replayFrames=999),
                       dict(valid, scores=[{"playerId": PLAYER, "score": float("nan")}]),
                       dict(valid, scores=valid["scores"] * 2)]
        for invalid in bad_results:
            self.legacy.result_override = invalid
            with self.subTest(result=invalid):
                status, value, _, _ = self.get("result")
                self.assertEqual(status, 503)
                self.assertNotIn("scores", value)
                self.assertIsNone(self.server.guard.store.load(MATCH)["result"])
        self.assertEqual(self.input()[0], 409)

    def test_concurrent_input_and_finalization_are_serialized_for_same_match(self):
        entered, release = threading.Event(), threading.Event()
        self.legacy.enter_post, self.legacy.release_post = entered, release
        with ThreadPoolExecutor(max_workers=2) as pool:
            input_reply = pool.submit(self.input)
            self.assertTrue(entered.wait(2))
            terminal_reply = pool.submit(self.get, "state")
            time.sleep(0.04)
            self.assertFalse(terminal_reply.done())
            self.legacy.terminal(score=0, frames=0)
            release.set()
            self.assertEqual(input_reply.result(timeout=3)[0], 200)
            frozen_state = terminal_reply.result(timeout=3)
        self.assertEqual((frozen_state[0], frozen_state[1]["replayFrames"]), (200, 1))
        self.assertEqual(self.get("result")[1]["replayFrames"], 1)
        self.assertEqual(self.input(sequence=2)[0], 409)
        self.assertEqual(self.legacy.input_count, 1)

    def test_result_phase_transition_between_reads_is_frozen_before_exposure(self):
        self.legacy.finish_on_result = True
        self.assertEqual(self.get("result")[0], 200)
        self.assertIsNotNone(self.server.guard.store.load(MATCH)["result"])
        self.assertEqual(self.input()[0], 409)

    def test_canonical_path_guard_cannot_be_bypassed_with_encodings_or_segments(self):
        for path in (f"/v1/matches/{MATCH}%2finput", f"/v1//matches/{MATCH}/input",
                     f"/v1/matches/{MATCH}/x/../input", f"/v1/matches/{MATCH}/%69nput",
                     f"http://elsewhere.invalid/v1/matches/{MATCH}/input", f"//elsewhere.invalid/input"):
            with self.subTest(path=path):
                self.assertEqual(self.request(path, INPUT)[0], 400)
        self.assertEqual(self.legacy.calls, [])

    def test_unsupported_match_methods_and_descendants_never_reach_legacy_router(self):
        for method in ("GET", "HEAD", "PUT", "PATCH", "DELETE", "OPTIONS"):
            with self.subTest(method=method):
                self.assertEqual(self.request(f"/v1/matches/{MATCH}/input", INPUT, method=method)[0], 405)
        for action in ("state", "result"):
            self.assertEqual(self.request(f"/v1/matches/{MATCH}/{action}", INPUT)[0], 405)
        for path in (f"/v1/matches/{MATCH}/input/extra", f"/V1/MATCHES/{MATCH}/input",
                     f"/v1/matches/{MATCH}/Input", f"/v1/matches/{MATCH};other/input"):
            with self.subTest(path=path):
                self.assertEqual(self.request(path, INPUT)[0], 404)
        self.assertEqual(self.legacy.calls, [])

    def test_other_routes_status_headers_and_bodies_remain_compatible_without_token_storage(self):
        payload = {"creatorId": PLAYER, "title": "Own fixture", "seed": 20261017, "visibility": "private"}
        status, value, headers, _ = self.request("/v1/challenges", payload, {"Authorization": "Bearer synthetic-secret-do-not-store"})
        self.assertEqual((status, value), (201, dict(payload, id="ch_fixture")))
        self.assertEqual(headers["X-Legacy-Fixture"], "transparent")
        self.assertEqual(self.legacy.calls[-1][3]["Authorization"], "Bearer synthetic-secret-do-not-store")
        self.assertEqual(self.request("/v1/challenges")[0:2], (405, "method not allowed\n"))
        self.assertEqual(self.request("/v1/matches", {"challengeId": "ch_fixture", "maxPlayers": 2})[0], 201)
        self.legacy.terminal()
        self.assertEqual(self.get("result")[0], 200)
        files = [self.database, self.database.with_name(self.database.name + "-wal")]
        self.assertFalse(any(b"synthetic-secret-do-not-store" in path.read_bytes() for path in files if path.exists()))

    def test_upstream_timeout_is_bounded_and_never_retries_or_forwards_input(self):
        self.stop_guard()
        self.start_guard(timeout=0.05, budget=0.15)
        self.legacy.delay_state = 0.3
        before = time.monotonic()
        status = self.input()[0]
        self.assertLess(time.monotonic() - before, 0.7)
        self.assertEqual(status, 503)
        self.assertEqual(self.legacy.input_count, 0)
        self.assertEqual(len(self.legacy.calls), 1)

    def test_slow_headers_and_zero_length_body_cannot_extend_absolute_upstream_budget(self):
        self.stop_guard()
        self.start_guard(timeout=0.08, budget=0.10)
        self.legacy.drip_state_headers = True
        before = time.monotonic()
        status = self.input()[0]
        elapsed = time.monotonic() - before
        self.assertEqual(status, 503)
        self.assertLess(elapsed, 0.22)
        self.assertEqual(self.legacy.input_count, 0)
        self.assertEqual(len(self.legacy.calls), 1)

    def test_watchdog_eof_without_content_length_is_not_a_successful_post(self):
        self.stop_guard()
        self.start_guard(timeout=0.08, budget=0.15)
        self.legacy.delay_close_post = True
        status, value, _, _ = self.input()
        self.assertEqual((status, value["error"]), (503, "upstream_write_uncertain"))
        self.assertEqual(self.legacy.input_count, 1)
        self.assertEqual(sum(method == "POST" for method, *_ in self.legacy.calls), 1)

    def test_corrupt_snapshot_is_not_replaced_with_new_upstream_result(self):
        self.legacy.terminal()
        self.assertEqual(self.get("result")[0], 200)
        with sqlite3.connect(self.database) as db:
            value = self.legacy.result()
            value["scores"][0]["score"] = 999
            db.execute("UPDATE terminal_matches SET result_json=? WHERE match_id=?", (json.dumps(value), MATCH))
        before = len(self.legacy.calls)
        self.assertEqual(self.get("result")[0], 503)
        self.assertEqual(self.input()[0], 503)
        self.assertEqual(len(self.legacy.calls), before)


if __name__ == "__main__":
    unittest.main()
