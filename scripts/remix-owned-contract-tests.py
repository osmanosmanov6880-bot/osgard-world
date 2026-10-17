#!/usr/bin/env python3
"""Local Core/HTTP/SQLite/process tests for the opt-in owned REMIX contract.

Only ephemeral loopback services and temporary databases are used. The legacy
fixture intentionally accepts unauthorized, duplicate and late inputs so the
guard, rather than the fixture, has to reject them. No production API is called.
An unknown orphan before durable binding is empty and unlinked, not protected;
these tests do not claim engine recovery, replay verification, or atomic expiry.
"""

import copy
from concurrent.futures import ThreadPoolExecutor
import hashlib
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import multiprocessing
from pathlib import Path
import re
import socket
import sqlite3
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "server"))
import core_commerce
import core_server
import remix_guard as guard


PASSWORD = "only-loopback-fixture-password-2026"
CREATE = {"challengeId": "ch_public_fixture", "maxPlayers": 2}
KEY = "fixture_operation_0001"
GUEST_MATCH = "legacy_empty.1"
INPUT = {"sequence": 1, "moveX": 1, "moveY": 0, "jump": False}


def http_request(port, path, body=None, token=None, method=None, headers=None):
    client = http.client.HTTPConnection("127.0.0.1", port, timeout=6)
    outgoing = {"Content-Type": "application/json", **(headers or {})}
    if token is not None:
        outgoing["Authorization"] = "Bearer " + token
    raw = json.dumps(body).encode() if body is not None else None
    try:
        client.request(method or ("POST" if body is not None else "GET"), path, raw, outgoing)
        reply = client.getresponse()
        data = reply.read()
        try:
            value = json.loads(data)
        except ValueError:
            value = data.decode()
        return reply.status, value, data, dict(reply.getheaders())
    finally:
        client.close()


def serve(server):
    thread = threading.Thread(target=lambda: server.serve_forever(poll_interval=0.01), daemon=True)
    thread.start()
    return thread


def stop(server, thread):
    server.shutdown()
    server.server_close()
    thread.join(3)


class MutableLegacy:
    def __init__(self):
        self.lock = threading.RLock()
        self.states = {GUEST_MATCH: self.empty(GUEST_MATCH, "PLAYING")}
        self.calls = []
        self.created = []
        self.drop_create = False
        self.drop_input = False
        self.input_status = 200
        self.ack_override = None
        self.create_status = 201
        self.create_id = None
        self.create_state = None
        self.create_metadata = None
        self.create_entered = None
        self.create_release = None
        self.input_count = 0

    @staticmethod
    def empty(identifier, phase="COUNTDOWN"):
        return {"id": identifier, "phase": phase, "players": 0, "remainingMs": 2500 if phase == "COUNTDOWN" else 30000,
                "replayFrames": 0, "scores": []}

    def playing(self, identifier):
        with self.lock:
            self.states[identifier].update(phase="PLAYING", remainingMs=30000)

    def terminal(self, identifier, player=None):
        with self.lock:
            state = self.states[identifier]
            state.update(phase="RESULTS", remainingMs=0)
            if player:
                state.update(players=1, replayFrames=2, scores=[{"playerId": player, "score": 0.25}])

    def posts(self, suffix):
        with self.lock:
            return [row for row in self.calls if row[0] == "POST" and row[1].endswith(suffix)]


class MutableHandler(BaseHTTPRequestHandler):
    def log_message(self, *args):
        pass

    def answer(self, status, value):
        raw = json.dumps(value).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        try:
            self.wfile.write(raw)
        except (BrokenPipeError, ConnectionResetError):
            pass

    def do_GET(self):
        legacy = self.server.legacy
        with legacy.lock:
            legacy.calls.append(("GET", self.path, None, dict(self.headers)))
            path = urlsplit(self.path).path
            if path == "/health":
                return self.answer(200, {"status": "ok"})
            route = re.fullmatch(r"/v1/matches/([^/]+)/(state|result)", path)
            if route:
                state = legacy.states.get(route[1])
                if state is None:
                    return self.answer(404, {"error": "missing"})
                if route[2] == "state":
                    return self.answer(200, state)
                if state["phase"] != "RESULTS":
                    return self.answer(409, {"error": "not finished"})
                return self.answer(200, {"matchId": route[1], "phase": "RESULTS", "replayFrames": state["replayFrames"],
                                         "scores": state["scores"]})
            return self.answer(200, {"path": self.path})

    def do_POST(self):
        legacy = self.server.legacy
        payload = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))) or b"{}")
        path = urlsplit(self.path).path
        with legacy.lock:
            legacy.calls.append(("POST", self.path, payload, dict(self.headers)))
        if path == "/v1/matches":
            with legacy.lock:
                if legacy.create_status != 201:
                    return self.answer(legacy.create_status, {"error": "fixture creation failure"})
                identifier = legacy.create_id or payload.get("id") or f"match_new.{len(legacy.created) + 1}"
                legacy.created.append(identifier)
                state = legacy.create_state or MutableLegacy.empty(identifier)
                legacy.states[identifier] = copy.deepcopy(state)
                match = legacy.create_metadata or dict(payload, id=identifier, createdAt="2026-10-17T12:00:00Z")
            if legacy.create_entered:
                legacy.create_entered.set()
            if legacy.create_release:
                legacy.create_release.wait(4)
            if legacy.drop_create:
                self.connection.shutdown(socket.SHUT_RDWR)
                self.connection.close()
                return
            return self.answer(201, match)
        route = re.fullmatch(r"/v1/matches/([^/]+)/input", path)
        if route:
            with legacy.lock:
                state = legacy.states.get(route[1])
                if state is None:
                    return self.answer(404, {"error": "missing"})
                # No auth/phase/sequence protection here: the guard must do it.
                legacy.input_count += 1
                state["players"] = 1
                state["replayFrames"] += 1
                state["scores"] = [{"playerId": payload["playerId"], "score": state["replayFrames"] * 0.1}]
                ack = {"playerId": payload["playerId"], "position": [0.25, 0, 0], "velocityY": 0,
                       "onGround": True, "score": state["scores"][0]["score"], "lastSequence": payload["sequence"]}
            if legacy.drop_input:
                self.connection.shutdown(socket.SHUT_RDWR)
                self.connection.close()
                return
            return self.answer(legacy.input_status, legacy.ack_override or ack)
        return self.answer(201, dict(payload, id="ch_public_fixture"))


def guard_process(database, upstream, core, enabled, control):
    """Spawned process has its own Python locks, proving flock is essential."""
    server = None
    try:
        server = guard.create_server(database, upstream, port=0, core_upstream=core, core_host="osgard.world",
                                     enable_owned_creation=enabled, timeout=2, budget=6)
        thread = serve(server)
        control.send(server.server_address[1])
        if control.poll(20):
            control.recv()
        stop(server, thread)
        server = None
    finally:
        control.close()
        if server is not None:
            server.server_close()


class OwnedContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_temp = tempfile.TemporaryDirectory(prefix="osgard-owned-core-")
        root = Path(cls.core_temp.name) / "web"
        root.mkdir()
        cls.core_database = Path(cls.core_temp.name) / "core.sqlite3"
        cls.core = core_server.create_server(root, cls.core_database, port=0, public_origin="https://osgard.world",
                                            commerce_config=core_commerce.Config())
        # Only the configured trusted Host works; the caller's Host cannot be
        # reused and an ordinary loopback Host would fail the real Core check.
        cls.core.allowed_hosts = {"osgard.world"}
        cls.core_thread = serve(cls.core)
        cls.core_port = cls.core.server_address[1]
        cls.core_base = f"http://127.0.0.1:{cls.core_port}"
        cls.alpha = cls.core_auth("register", "owned_alpha")
        cls.beta = cls.core_auth("register", "owned_beta")

    @classmethod
    def core_request(cls, route, body=None, token=None):
        return http_request(cls.core_port, "/api/core/" + route, body, token, headers={"Host": "osgard.world"})

    @classmethod
    def core_auth(cls, operation, username="owned_alpha"):
        status, value, *_ = cls.core_request("auth/" + operation, {"username": username, "password": PASSWORD})
        if status != 200:
            raise AssertionError(f"Synthetic Core {operation} failed with HTTP {status}")
        return value

    @classmethod
    def tearDownClass(cls):
        stop(cls.core, cls.core_thread)
        cls.core_temp.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="osgard-owned-guard-")
        self.database = Path(self.temporary.name) / "terminal.sqlite3"
        self.legacy = MutableLegacy()
        self.backend = ThreadingHTTPServer(("127.0.0.1", 0), MutableHandler)
        self.backend.daemon_threads = True
        self.backend.legacy = self.legacy
        self.backend_thread = serve(self.backend)
        self.backend_base = f"http://127.0.0.1:{self.backend.server_address[1]}"
        self.backend_live = True
        self.server = None
        self.processes = []
        self.start_guard()

    def start_guard(self, enabled=True, **kwargs):
        self.server = guard.create_server(self.database, self.backend_base, port=0, core_upstream=self.core_base,
                                         core_host="osgard.world", enable_owned_creation=enabled, **kwargs)
        self.thread = serve(self.server)
        self.port = self.server.server_address[1]

    def stop_guard(self):
        if self.server is not None:
            stop(self.server, self.thread)
            self.server = None

    def restart(self, enabled=False, **kwargs):
        self.stop_guard()
        self.start_guard(enabled, **kwargs)

    def tearDown(self):
        if self.legacy.create_release:
            self.legacy.create_release.set()
        for process, control in self.processes:
            if process.is_alive():
                try:
                    control.send("stop")
                except (BrokenPipeError, EOFError, OSError):
                    pass
            process.join(4)
            if process.is_alive():
                process.terminate()
                process.join(3)
            control.close()
        self.stop_guard()
        if self.backend_live:
            stop(self.backend, self.backend_thread)
        self.temporary.cleanup()

    def request(self, path, body=None, token=None, **kwargs):
        return http_request(self.port, path, body, token, **kwargs)

    def create(self, key=KEY, token=None, body=None, port=None):
        return http_request(port or self.port, "/v2/matches", CREATE if body is None else body,
                            token or self.alpha["token"], headers={"Idempotency-Key": key})

    def create_ok(self, **kwargs):
        status, value, *_ = self.create(**kwargs)
        self.assertEqual(status, 201, value)
        return value

    def input(self, match, sequence=1, token=None, **changes):
        return self.request(f"/v2/matches/{match['id']}/input", dict(INPUT, sequence=sequence, **changes),
                            token or self.alpha["token"])

    def get(self, match, action="", token=None):
        return self.request(f"/v2/matches/{match['id']}" + ("/" + action if action else ""), token=token or self.alpha["token"])

    def start_process(self, enabled=True):
        context = multiprocessing.get_context("spawn")
        receiver, sender = context.Pipe()
        process = context.Process(target=guard_process, args=(str(self.database), self.backend_base, self.core_base,
                                                            enabled, sender))
        process.start()
        sender.close()
        self.processes.append((process, receiver))
        self.assertTrue(receiver.poll(6), "The isolated guard process did not start")
        port = receiver.recv()
        return process, port

    def test_default_disabled_foundation_keeps_schema_one_and_guest_play(self):
        self.restart(enabled=False)
        capability = self.request("/v2/capabilities")[1]
        self.assertEqual(capability, {"authPolicyVersion": 1, "creationEnabled": False, "provider": "core",
                                      "ownershipPolicy": "confirmed-durable-binding", "legacyMatches": "anonymous",
                                      "activeMatchRecovery": False, "replayVerification": False,
                                      "participantPolicyVersion": 1, "participantAdmissionEnabled": False,
                                      "maxParticipants": 2})
        self.assertEqual(self.create()[0:2], (403, {"error": "owned_creation_disabled",
                                                  "message": "Account-owned creation is not enabled in this release."}))
        self.assertEqual(self.server.guard.store.schema_version(), 1)
        self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/input", dict(INPUT, playerId="guest"))[0], 200)
        self.assertEqual(self.legacy.posts("/v1/matches"), [])
        self.assertEqual(self.request("/health")[1]["authPolicyVersion"], 1)

    def test_real_core_identity_and_trusted_host_bind_server_player(self):
        match = self.create_ok()
        self.assertEqual(set(match), {"id", "challengeId", "maxPlayers", "createdAt", "playerId", "highestSubmittedSequence", "accessMode",
                                     "role", "participantCount", "maxParticipants"})
        self.assertEqual((match["accessMode"], match["highestSubmittedSequence"]), ("core-owned", 0))
        self.assertNotEqual(match["playerId"], self.alpha["user"]["id"])
        row = self.server.guard.store.owner(match["id"])
        self.assertEqual(row["owner_id"], self.alpha["user"]["id"])
        self.assertEqual(self.server.guard.store.schema_version(), 2)
        self.assertEqual(self.get(match)[1], match)
        self.assertEqual(self.legacy.posts("/v1/matches")[0][2], CREATE)

    def test_every_legacy_alias_requires_owner_before_player_or_cache_lookup(self):
        match = self.create_ok()
        self.legacy.playing(match["id"])
        before = len(self.legacy.calls)
        for prefix in ("/v1", "/v2"):
            for action, body in (("state", None), ("result", None), ("input", dict(INPUT)),
                                 ("input", dict(INPUT, playerId="attacker")),
                                 ("input", dict(INPUT, playerId=match["playerId"]))):
                for suffix in ("", "/", "?playerId=attacker"):
                    with self.subTest(prefix=prefix, action=action, suffix=suffix):
                        path = f"{prefix}/matches/{match['id']}/{action}{suffix}"
                        self.assertEqual(self.request(path, body)[0], 401)
                        self.assertEqual(self.request(path, body, self.beta["token"])[0], 403)
        self.assertEqual(len(self.legacy.calls), before)
        self.assertEqual(self.legacy.input_count, 0)

    def test_encoded_case_methods_and_base_aliases_never_forward(self):
        match = self.create_ok()
        before = len(self.legacy.calls)
        for path in (f"/v1/matches/{match['id']}/%69nput", f"/v1//matches/{match['id']}/input",
                     f"/v1/matches/{match['id']}/x/../input", f"/V1/MATCHES/{match['id']}/input",
                     f"/v1/matches/{match['id']}/Input", f"/v1/matches/{match['id']}",
                     f"/v2/matches/{match['id']}/input/extra"):
            self.assertIn(self.request(path, INPUT)[0], (400, 404))
        for method in ("GET", "HEAD", "PUT", "PATCH", "DELETE", "OPTIONS"):
            self.assertEqual(self.request(f"/v1/matches/{match['id']}/input", INPUT, method=method)[0], 405)
        self.assertEqual(len(self.legacy.calls), before)

    def test_anonymous_create_cannot_submit_owned_id_or_private_fields(self):
        match = self.create_ok()
        before = len(self.legacy.posts("/v1/matches"))
        for extra in ({"id": match["id"]}, {"playerId": "attacker"}, {"ownerId": self.beta["user"]["id"]}):
            self.assertEqual(self.request("/v1/matches", dict(CREATE, **extra))[0], 400)
        self.assertEqual(len(self.legacy.posts("/v1/matches")), before)
        self.assertEqual(self.request("/v1/matches")[0], 405)

    def test_explicit_v2_never_adopts_preexisting_anonymous_match(self):
        self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/state")[0], 200)
        self.assertEqual(self.request(f"/v2/matches/{GUEST_MATCH}", token=self.alpha["token"])[0], 404)
        self.assertEqual(self.request(f"/v2/matches/{GUEST_MATCH}/state", token=self.alpha["token"])[0], 404)
        self.assertEqual(self.request("/v2/matches", token=self.alpha["token"])[1]["matches"], [])

    def test_same_operation_reuses_binding_never_repeats_upstream_post(self):
        match = self.create_ok()
        self.assertEqual(self.create()[1], match)
        self.assertEqual(len(self.legacy.posts("/v1/matches")), 1)
        self.assertEqual(self.request(f"/v2/creation-attempts/{KEY}", token=self.alpha["token"])[1],
                         {"status": "ready", "match": match})
        self.assertEqual(self.create(body=dict(CREATE, challengeId="different"))[0:2],
                         (409, {"error": "operation_conflict", "message": "This operation key belongs to a different creation request."}))
        self.assertEqual(len(self.legacy.posts("/v1/matches")), 1)

    def test_operations_and_history_are_account_scoped(self):
        alpha = self.create_ok()
        self.assertEqual(self.request(f"/v2/creation-attempts/{KEY}", token=self.beta["token"])[0], 404)
        beta = self.create_ok(token=self.beta["token"])
        for user, own in ((self.alpha, alpha), (self.beta, beta)):
            status, value, *_ = self.request("/v2/matches", token=user["token"])
            self.assertEqual((status, value), (200, {"matches": [own], "nextCursor": None}))
        self.assertEqual(self.request("/v2/matches")[0], 401)
        self.assertEqual(self.request("/v2/matches?after=bad%2Fid", token=self.alpha["token"])[0], 400)
        self.assertEqual(self.request("/v2/matches?after=a&after=b", token=self.alpha["token"])[0], 400)

    def test_owned_history_pages_are_bounded_and_cursor_does_not_repeat_rows(self):
        expected = [self.create_ok(key=f"history_operation_{index:04d}")["id"] for index in range(51)]
        first = self.request("/v2/matches", token=self.alpha["token"])[1]
        self.assertEqual(len(first["matches"]), 50)
        self.assertEqual(first["nextCursor"], first["matches"][-1]["id"])
        second = self.request("/v2/matches?after=" + first["nextCursor"], token=self.alpha["token"])[1]
        self.assertEqual(len(second["matches"]), 1)
        self.assertIsNone(second["nextCursor"])
        self.assertEqual([row["id"] for row in first["matches"] + second["matches"]], sorted(expected))

    def test_owned_creation_rejects_private_or_unrecognized_fields_before_dispatch(self):
        for extra in ({"ownerId": self.alpha["user"]["id"]}, {"playerId": "private_player"},
                      {"id": GUEST_MATCH}, {"maxPlayers": 1}, {"challengeId": "bad/id"}):
            self.assertEqual(self.create(body=dict(CREATE, **extra))[0], 400)
        self.assertEqual(self.legacy.posts("/v1/matches"), [])
        self.assertEqual(self.server.guard.store.schema_version(), 1)

    def test_lost_creation_response_is_uncertain_and_never_adopted_or_retried(self):
        self.legacy.drop_create = True
        status, value, *_ = self.create()
        self.assertEqual((status, value["error"]), (503, "creation_uncertain"))
        identifier = self.legacy.created[0]
        self.assertIsNone(self.server.guard.store.owner(identifier))
        self.assertEqual(self.legacy.states[identifier]["players"], 0)
        self.assertEqual(self.request(f"/v2/creation-attempts/{KEY}", token=self.alpha["token"])[1]["status"], "uncertain")
        self.legacy.drop_create = False
        self.assertEqual(self.create()[0], 409)
        self.assertEqual(len(self.legacy.posts("/v1/matches")), 1)
        self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/state")[0], 200)
        self.assertEqual(self.request(f"/v1/matches/{identifier}/state")[0], 200)
        self.assertEqual(self.request(f"/v2/matches/{identifier}", token=self.alpha["token"])[0], 404)
        self.assertNotEqual(self.create_ok(key="fixture_operation_0002")["id"], identifier)

    def test_invalid_creation_response_or_nonempty_state_cannot_be_bound(self):
        invalid = [dict(MutableLegacy.empty("match_new.1"), players=1, scores=[{"playerId": "guest", "score": 0}]),
                   dict(MutableLegacy.empty("match_new.2"), replayFrames=1),
                   dict(MutableLegacy.empty("wrong_match"))]
        for index, state in enumerate(invalid):
            self.legacy.create_state = state
            status, value, *_ = self.create(key=f"invalid_operation_{index:04d}")
            self.assertEqual((status, value["error"]), (503, "creation_uncertain"))
        self.assertEqual(self.request("/v2/matches", token=self.alpha["token"])[1]["matches"], [])
        self.legacy.create_state = None
        self.legacy.create_metadata = {"id": "match_new.4", "challengeId": "wrong_challenge", "maxPlayers": 2,
                                       "createdAt": "2026-10-17T12:00:00Z"}
        self.assertEqual(self.create(key="invalid_operation_0004")[1]["error"], "creation_uncertain")
        self.assertIsNone(self.server.guard.store.owner("match_new.4"))

    def test_known_empty_anonymous_match_cannot_be_claimed_by_create_response(self):
        self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/state")[0], 200)
        self.legacy.create_id = GUEST_MATCH
        self.assertEqual(self.create()[0], 503)
        self.assertIsNone(self.server.guard.store.owner(GUEST_MATCH))

    def test_rejected_creation_is_recorded_without_retry(self):
        self.legacy.create_status = 404
        self.assertEqual(self.create()[0], 409)
        self.assertEqual(self.request(f"/v2/creation-attempts/{KEY}", token=self.alpha["token"])[1]["status"], "rejected")
        self.legacy.create_status = 201
        self.assertEqual(self.create()[0], 409)
        self.assertEqual(len(self.legacy.posts("/v1/matches")), 1)

    def test_countdown_and_finished_inputs_cannot_consume_sequence_or_mutate(self):
        match = self.create_ok()
        self.assertEqual(self.input(match)[0:2], (409, {"error": "match_not_playing",
                                                      "message": "The service has not confirmed an active playing phase."}))
        self.assertEqual(self.get(match)[1]["highestSubmittedSequence"], 0)
        self.assertEqual(self.get(match, "result")[1]["error"], "match_not_finished")
        self.legacy.terminal(match["id"])
        self.assertEqual(self.input(match)[1]["error"], "match_finished")
        self.assertEqual(self.legacy.input_count, 0)

    def test_bound_player_and_submitted_sequence_allow_gaps_not_reuse(self):
        match = self.create_ok()
        self.legacy.playing(match["id"])
        self.assertEqual(self.input(match, playerId="attacker")[0], 403)
        status, ack, *_ = self.input(match, sequence=3)
        self.assertEqual((status, ack["playerId"], ack["lastSequence"]), (200, match["playerId"], 3))
        for sequence in (1, 3):
            self.assertEqual(self.input(match, sequence)[1]["error"], "stale_input_sequence")
        self.assertEqual(self.get(match)[1]["highestSubmittedSequence"], 3)
        self.assertEqual(self.legacy.input_count, 1)
        forwarded = self.legacy.posts("/input")[0]
        self.assertEqual(forwarded[2]["playerId"], match["playerId"])

    def test_uncertain_input_retains_highwater_across_disabled_restart(self):
        match = self.create_ok()
        self.legacy.playing(match["id"])
        self.legacy.drop_input = True
        self.assertEqual(self.input(match, 7)[1]["error"], "upstream_write_uncertain")
        self.assertEqual(self.legacy.input_count, 1)
        self.restart(enabled=False)
        self.legacy.drop_input = False
        self.assertEqual(self.get(match)[1]["highestSubmittedSequence"], 7)
        self.assertEqual(self.input(match, 7)[0], 409)
        self.assertEqual(self.legacy.input_count, 1)
        self.assertEqual(self.input(match, 8)[0], 200)

    def test_upstream_input_rejection_still_retains_submitted_sequence(self):
        match = self.create_ok()
        self.legacy.playing(match["id"])
        self.legacy.input_status = 503
        self.assertEqual(self.input(match, 2)[1]["error"], "input_unconfirmed")
        self.assertEqual(self.get(match)[1]["highestSubmittedSequence"], 2)
        self.assertEqual(self.input(match, 2)[0], 409)
        self.assertEqual(self.legacy.input_count, 1)

    def test_mismatched_input_ack_is_not_accepted_or_retried(self):
        match = self.create_ok()
        self.legacy.playing(match["id"])
        self.legacy.ack_override = {"playerId": "another_player", "position": [0, 0, 0], "velocityY": 0,
                                    "onGround": True, "score": 1, "lastSequence": 1}
        self.assertEqual(self.input(match)[1]["error"], "upstream_contract")
        self.assertEqual(self.get(match)[1]["highestSubmittedSequence"], 1)
        self.assertEqual(self.input(match)[0], 409)
        self.assertEqual(self.legacy.input_count, 1)

    def test_invalid_input_and_duplicate_security_headers_fail_before_forward(self):
        match = self.create_ok()
        self.legacy.playing(match["id"])
        for changes in ({"sequence": True}, {"sequence": 0}, {"moveX": float("nan")}, {"moveY": 2},
                        {"jump": 1}, {"extra": "untrusted"}):
            self.assertEqual(self.request(f"/v2/matches/{match['id']}/input", dict(INPUT, **changes), self.alpha["token"])[0], 400)
        client = http.client.HTTPConnection("127.0.0.1", self.port, timeout=3)
        try:
            client.putrequest("GET", f"/v1/matches/{match['id']}/state")
            client.putheader("Authorization", "Bearer " + self.alpha["token"])
            client.putheader("authorization", "Bearer " + self.beta["token"])
            client.endheaders()
            self.assertEqual(client.getresponse().status, 400)
        finally:
            client.close()
        self.assertEqual(self.legacy.input_count, 0)

    def test_database_failure_before_reservation_or_input_prevents_write(self):
        with patch.object(self.server.guard.store, "reserve_creation", side_effect=sqlite3.OperationalError("disk full")):
            self.assertEqual(self.create()[0], 503)
        self.assertEqual(self.legacy.posts("/v1/matches"), [])
        self.assertEqual(self.server.guard.store.schema_version(), 1)
        match = self.create_ok()
        self.legacy.playing(match["id"])
        with patch.object(self.server.guard.store, "submit_sequence", side_effect=sqlite3.OperationalError("disk full")):
            self.assertEqual(self.input(match)[0], 503)
        self.assertEqual(self.legacy.input_count, 0)

    def test_failed_ownership_lookup_cannot_fall_through_to_anonymous_forward(self):
        match = self.create_ok()
        before = len(self.legacy.calls)
        with patch.object(self.server.guard.store, "owner", side_effect=sqlite3.OperationalError("unreadable ACL")):
            self.assertEqual(self.request(f"/v1/matches/{match['id']}/input", dict(INPUT, playerId="attacker"))[0], 503)
            self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/state")[0], 503)
        self.assertEqual(len(self.legacy.calls), before)

    def test_binding_failure_never_returns_owned_record(self):
        with patch.object(self.server.guard.store, "bind_creation", side_effect=sqlite3.OperationalError("disk full")):
            self.assertEqual(self.create()[1]["error"], "creation_uncertain")
        self.assertEqual(self.request("/v2/matches", token=self.alpha["token"])[1]["matches"], [])
        self.assertEqual(self.request(f"/v2/creation-attempts/{KEY}", token=self.alpha["token"])[1]["status"], "uncertain")
        self.assertEqual(self.create()[0], 409)
        self.assertEqual(len(self.legacy.posts("/v1/matches")), 1)

    def test_frozen_owned_result_keeps_auth_after_restart_and_engine_outage(self):
        match = self.create_ok()
        self.legacy.terminal(match["id"], match["playerId"])
        before = self.get(match, "result")
        self.assertEqual(before[0], 200)
        self.restart(enabled=False)
        stop(self.backend, self.backend_thread)
        self.backend_live = False
        self.assertEqual(self.get(match, "result")[2], before[2])
        self.assertEqual(self.request(f"/v1/matches/{match['id']}/result")[0], 401)
        self.assertEqual(self.get(match, "result", self.beta["token"])[0], 403)
        self.assertEqual(self.input(match)[0], 409)
        self.assertEqual(self.server.guard.store.schema_version(), 2)
        self.assertEqual(self.create(key="fixture_operation_0002")[1]["error"], "owned_creation_disabled")

    def test_logout_revalidates_real_core_session_on_each_request(self):
        login = self.core_auth("login")
        match = self.create_ok(token=login["token"])
        self.assertEqual(self.get(match, token=login["token"])[0], 200)
        self.assertEqual(self.core_request("auth/logout", {}, login["token"])[0], 200)
        self.assertEqual(self.get(match, token=login["token"])[0], 401)
        self.assertEqual(self.get(match)[0], 200)

    def test_expired_real_core_session_cannot_read_or_submit(self):
        login = self.core_auth("login")
        match = self.create_ok()
        self.legacy.playing(match["id"])
        self.assertEqual(self.get(match, token=login["token"])[0], 200)
        with sqlite3.connect(self.core_database) as db:
            db.execute("UPDATE sessions SET expires_at=? WHERE token_hash=?", (time.time() - 1, hashlib.sha256(login["token"].encode()).hexdigest()))
        self.assertEqual(self.get(match, token=login["token"])[0], 401)
        self.assertEqual(self.input(match, token=login["token"])[0], 401)
        self.assertEqual(self.legacy.input_count, 0)

    def test_revoked_real_core_session_cannot_read_even_frozen_cache(self):
        login = self.core_auth("login")
        match = self.create_ok()
        self.legacy.terminal(match["id"], match["playerId"])
        self.assertEqual(self.get(match, "result", login["token"])[0], 200)
        security = self.core_request("auth/security", token=login["token"])[1]
        current = next(row["id"] for row in security["sessions"] if row["current"])
        self.assertEqual(self.core_request("auth/sessions/revoke", {"sessionId": current}, self.alpha["token"])[0], 200)
        self.assertEqual(self.get(match, "result", login["token"])[0], 401)
        self.assertEqual(self.get(match, "result")[0], 200)

    def test_core_outage_cannot_become_guest_or_bypass_frozen_acl(self):
        match = self.create_ok()
        self.legacy.terminal(match["id"], match["playerId"])
        self.assertEqual(self.get(match, "result")[0], 200)
        self.server.guard.core.upstream = guard.Upstream("http://127.0.0.1:1", timeout=0.05, trusted_host="osgard.world")
        before = len(self.legacy.calls)
        for prefix in ("v1", "v2"):
            reply = self.request(f"/{prefix}/matches/{match['id']}/result", token=self.alpha["token"])
            self.assertEqual((reply[0], reply[1]["error"]), (503, "authentication_unavailable"))
        self.assertEqual(len(self.legacy.calls), before)
        self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/state")[0], 200)

    def test_tokens_cookies_and_claimed_identity_never_reach_legacy_or_disk(self):
        headers = {"Cookie": "private_cookie=fixture_do_not_forward", "X-User-Id": self.alpha["user"]["id"],
                   "Authorization": "Bearer " + self.alpha["token"]}
        self.request("/v1/challenges", {"title": "public fixture"}, headers=headers)
        match = self.create_ok()
        self.legacy.playing(match["id"])
        self.assertEqual(self.request(f"/v1/matches/{match['id']}/input", INPUT, headers=headers)[0], 200)
        for _, _, payload, forwarded in self.legacy.calls:
            lowered = {key.lower() for key in forwarded}
            self.assertFalse(lowered & {"authorization", "cookie", "proxy-authorization", "x-user-id"})
            self.assertNotIn(self.alpha["token"], json.dumps(payload))
        # Neither Core user ID nor assigned player ID occurs in create/state
        # requests before the durable owner binding. Only later input uses it.
        create_request = self.legacy.posts("/v1/matches")[0]
        self.assertEqual(create_request[2], CREATE)
        self.assertNotIn(self.alpha["user"]["id"], json.dumps(create_request))
        self.assertNotIn(match["playerId"], json.dumps(create_request))
        for path in Path(self.temporary.name).glob("terminal.sqlite3*"):
            raw = path.read_bytes()
            self.assertNotIn(self.alpha["token"].encode(), raw)
            self.assertNotIn(b"fixture_do_not_forward", raw)

    def test_schema_one_snapshot_survives_foundation_and_no_downgrade_after_reservation(self):
        self.legacy.terminal(GUEST_MATCH, "guest")
        frozen = self.request(f"/v1/matches/{GUEST_MATCH}/result")
        self.assertEqual(self.server.guard.store.schema_version(), 1)
        self.restart(enabled=False)
        self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/result")[2], frozen[2])
        self.restart(enabled=True)
        self.create_ok()
        self.restart(enabled=False)
        self.assertEqual(self.server.guard.store.schema_version(), 2)
        self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/result")[2], frozen[2])
        self.assertEqual(self.request("/health")[1]["schemaVersion"], 2)

    def test_unknown_schema_and_unsafe_shared_lock_file_fail_closed(self):
        bad = Path(self.temporary.name) / "unsupported.sqlite3"
        with sqlite3.connect(bad) as db:
            db.execute("PRAGMA user_version=99")
        with self.assertRaises(ValueError):
            guard.SnapshotStore(bad)
        lockfile = Path(self.temporary.name) / "remix-admission.lock"
        lockfile.unlink(missing_ok=True)
        lockfile.symlink_to(Path(self.temporary.name) / "elsewhere")
        self.assertEqual(self.create()[0], 503)
        self.assertEqual(self.legacy.posts("/v1/matches"), [])

    def test_restart_refuses_missing_protected_schema_instead_of_recreating_anonymous_catalog(self):
        match = self.create_ok()
        self.legacy.terminal(match["id"], match["playerId"])
        self.assertEqual(self.get(match, "result")[0], 200)
        route = f"/v1/matches/{match['id']}/result"
        self.assertEqual(self.request(route)[0], 401)
        for name in ("owned_matches", "owned_creation_attempts", "anonymous_matches", "terminal_matches", "guard_health"):
            with self.subTest(missing=name):
                broken = Path(self.temporary.name) / (name + "-missing.sqlite3")
                with sqlite3.connect(self.database) as source, sqlite3.connect(broken) as destination:
                    source.backup(destination)
                    destination.execute(f'DROP TABLE "{name}"')
                with self.assertRaisesRegex(ValueError, "schema is incomplete"):
                    guard.Guard(broken, self.backend_base, core_upstream=self.core_base)
                with sqlite3.connect(broken) as db:
                    self.assertIsNone(db.execute("SELECT 1 FROM sqlite_master WHERE name=?", (name,)).fetchone())
                    self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 2)
        with sqlite3.connect(self.database) as db:
            db.execute("DROP TABLE owned_matches")
        self.assertEqual(self.request(route)[0], 503)
        with self.assertRaisesRegex(ValueError, "schema is incomplete"):
            guard.Guard(self.database, self.backend_base, core_upstream=self.core_base)

    def test_shared_lock_and_database_contention_respect_request_deadline(self):
        self.restart(enabled=True, budget=0.1)
        with self.server.guard.files.admission(True, time.monotonic() + 1):
            before = time.monotonic()
            self.assertEqual(self.request(f"/v1/matches/{GUEST_MATCH}/state")[0], 503)
            self.assertLess(time.monotonic() - before, 0.4)
        with sqlite3.connect(self.database) as db:
            db.execute("BEGIN IMMEDIATE")
            before = time.monotonic()
            self.assertEqual(self.create()[0], 503)
            self.assertLess(time.monotonic() - before, 0.4)
        self.assertEqual(self.legacy.posts("/v1/matches"), [])

    def test_two_processes_close_creation_binding_race_and_serialize_sequence(self):
        self.stop_guard()
        _, creator_port = self.start_process(enabled=True)
        _, observer_port = self.start_process(enabled=False)
        self.legacy.create_entered = threading.Event()
        self.legacy.create_release = threading.Event()
        with ThreadPoolExecutor(max_workers=2) as pool:
            creation = pool.submit(self.create, port=creator_port)
            self.assertTrue(self.legacy.create_entered.wait(3))
            identifier = self.legacy.created[-1]
            attack = pool.submit(http_request, observer_port, f"/v1/matches/{identifier}/input", dict(INPUT, playerId="attacker"))
            time.sleep(0.1)
            self.assertFalse(attack.done(), "Another process classified the unbound ID without the admission lease")
            self.assertEqual(self.legacy.input_count, 0)
            self.legacy.create_release.set()
            status, match, *_ = creation.result(timeout=4)
            self.assertEqual(status, 201)
            self.assertEqual(attack.result(timeout=4)[0], 401)
        self.legacy.playing(identifier)
        with ThreadPoolExecutor(max_workers=2) as pool:
            replies = list(pool.map(lambda port: http_request(port, f"/v1/matches/{identifier}/input", INPUT, self.alpha["token"]),
                                    (creator_port, observer_port)))
        self.assertEqual(sorted(reply[0] for reply in replies), [200, 409])
        self.assertEqual(self.legacy.input_count, 1)
        value = http_request(observer_port, f"/v2/matches/{identifier}", token=self.alpha["token"])[1]
        self.assertEqual((value["playerId"], value["highestSubmittedSequence"]), (match["playerId"], 1))

    def test_process_death_before_binding_leaves_only_unlinked_uncertain_orphan(self):
        self.stop_guard()
        creator, creator_port = self.start_process(enabled=True)
        _, survivor_port = self.start_process(enabled=True)
        self.legacy.create_entered = threading.Event()
        self.legacy.create_release = threading.Event()
        with ThreadPoolExecutor(max_workers=1) as pool:
            creation = pool.submit(self.create, port=creator_port)
            self.assertTrue(self.legacy.create_entered.wait(3))
            identifier = self.legacy.created[-1]
            creator.terminate()
            creator.join(3)
            self.assertFalse(creator.is_alive())
            self.legacy.create_release.set()
            with self.assertRaises((OSError, http.client.HTTPException)):
                creation.result(timeout=3)
        self.assertEqual(self.legacy.states[identifier]["players"], 0)
        self.assertEqual(self.legacy.states[identifier]["replayFrames"], 0)
        attempt = http_request(survivor_port, f"/v2/creation-attempts/{KEY}", token=self.alpha["token"])
        self.assertEqual((attempt[0], attempt[1]["status"]), (200, "uncertain"))
        with sqlite3.connect(self.database) as db:
            self.assertEqual(db.execute("SELECT status FROM owned_creation_attempts WHERE operation_key=?", (KEY,)).fetchone()[0], "uncertain")
        self.assertEqual(self.create(port=survivor_port)[0], 409)
        self.assertEqual(len(self.legacy.posts("/v1/matches")), 1)
        self.assertEqual(http_request(survivor_port, f"/v1/matches/{identifier}/state")[0], 200)
        self.assertEqual(http_request(survivor_port, f"/v1/matches/{GUEST_MATCH}/state")[0], 200)
        self.assertEqual(http_request(survivor_port, f"/v2/matches/{identifier}", token=self.alpha["token"])[0], 404)
        self.assertEqual(self.create(key="fixture_operation_0002", port=survivor_port)[0], 201)


if __name__ == "__main__":
    unittest.main(verbosity=2)
