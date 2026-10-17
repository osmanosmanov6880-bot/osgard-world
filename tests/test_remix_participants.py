"""Addressed REMIX admission through real Core, HTTP, SQLite and process locks.

All services use temporary databases and ephemeral loopback ports. The original
two-player fixture deliberately accepts forged, duplicate and terminal inputs;
it is not evidence that the unavailable legacy implementation supports them.
The guard must enforce membership and sequences before forwarding. No external
network, browser, production account or legacy source is used by these tests.
"""

import copy
from concurrent.futures import ThreadPoolExecutor
from contextlib import contextmanager
from datetime import datetime, timedelta, timezone
import hashlib
import http.client
from http.server import ThreadingHTTPServer
import importlib.util
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
SPEC = importlib.util.spec_from_file_location("remix_participant_owned_fixture", ROOT / "scripts/remix-owned-contract-tests.py")
fixture = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = fixture
SPEC.loader.exec_module(fixture)
guard = fixture.guard
http_request, serve, stop = fixture.http_request, fixture.serve, fixture.stop

CREATE_KEY = "participant_create_0001"
INVITE_KEY = "participant_invite_0001"
ACCEPT_KEY = "participant_accept_0001"
REVOKE_KEY = "participant_revoke_0001"
INPUT = {"sequence": 1, "moveX": 1, "moveY": 0, "jump": False}


class TwoPlayerLegacy(fixture.MutableLegacy):
    """Original fixture, intentionally without ACL, phase or sequence checks."""

    def __init__(self):
        super().__init__()
        self.input_entered = None
        self.input_release = None


class TwoPlayerHandler(fixture.MutableHandler):
    def do_POST(self):
        path = urlsplit(self.path).path
        route = re.fullmatch(r"/v1/matches/([^/]+)/input", path)
        if route is None:
            return super().do_POST()
        payload = json.loads(self.rfile.read(int(self.headers.get("Content-Length", "0"))) or b"{}")
        legacy = self.server.legacy
        with legacy.lock:
            legacy.calls.append(("POST", self.path, payload, dict(self.headers)))
            state = legacy.states.get(route[1])
            if state is None:
                return self.answer(404, {"error": "missing"})
            legacy.input_count += 1
            state["replayFrames"] += 1
            row = next((item for item in state["scores"] if item["playerId"] == payload["playerId"]), None)
            if row is None:
                row = {"playerId": payload["playerId"], "score": 0}
                state["scores"].append(row)
            row["score"] += 0.25
            state["players"] = len(state["scores"])
            ack = {"playerId": payload["playerId"], "position": [row["score"], 0, 0], "velocityY": 0,
                   "onGround": True, "score": row["score"], "lastSequence": payload["sequence"]}
        if legacy.input_entered:
            legacy.input_entered.set()
        if legacy.input_release:
            legacy.input_release.wait(4)
        if legacy.drop_input:
            self.connection.shutdown(socket.SHUT_RDWR)
            self.connection.close()
            return
        return self.answer(legacy.input_status, legacy.ack_override or ack)


def participant_process(database, upstream, core, control, entered, release, pause="", enabled=True):
    """Independent lock descriptors, with optional crash points around commit."""
    server = None
    try:
        server = guard.create_server(database, upstream, port=0, timeout=2, budget=6,
                                     core_upstream=core, core_host="osgard.world", enable_owned_creation=False,
                                     enable_participant_admission=enabled)
        store = server.guard.store
        if pause == "in_transaction":
            original_connect = store.connect

            @contextmanager
            def paused_connect():
                with original_connect() as db:
                    def trace(statement):
                        # SQLite invokes the callback before this UPDATE. The
                        # participant INSERT has run, but neither effect nor
                        # ready marker has committed. Killing this process must
                        # roll the partial transaction back.
                        if statement.startswith("UPDATE owned_invitations SET status='accepted'"):
                            entered.set()
                            release.wait(10)
                    db.set_trace_callback(trace)
                    yield db
            store.connect = paused_connect
        elif pause == "after_commit":
            original_complete = store.complete_admission

            def paused_complete(*args, **kwargs):
                result = original_complete(*args, **kwargs)
                if args[2] == "accept":
                    entered.set()
                    release.wait(10)
                return result
            store.complete_admission = paused_complete
        thread = serve(server)
        control.send(server.server_address[1])
        if control.poll(30):
            control.recv()
        release.set()
        stop(server, thread)
        server = None
    finally:
        control.close()
        if server is not None:
            server.server_close()


class ParticipantTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.core_temp = tempfile.TemporaryDirectory(prefix="osgard-participant-core-")
        root = Path(cls.core_temp.name) / "web"
        root.mkdir()
        cls.core_database = Path(cls.core_temp.name) / "core.sqlite3"
        cls.core = fixture.core_server.create_server(root, cls.core_database, port=0,
                   public_origin="https://osgard.world", commerce_config=fixture.core_commerce.Config())
        cls.core.allowed_hosts = {"osgard.world"}
        cls.core_thread = serve(cls.core)
        cls.core_port = cls.core.server_address[1]
        cls.core_base = f"http://127.0.0.1:{cls.core_port}"
        cls.owner = cls.account("register", "participant_owner")
        cls.target = cls.account("register", "participant_target")
        cls.outsider = cls.account("register", "participant_outsider")

    @classmethod
    def core_request(cls, route, body=None, token=None):
        return http_request(cls.core_port, "/api/core/" + route, body, token, headers={"Host": "osgard.world"})

    @classmethod
    def account(cls, operation="login", username="participant_target"):
        status, value, *_ = cls.core_request("auth/" + operation, {"username": username, "password": fixture.PASSWORD})
        if status != 200:
            raise AssertionError(f"Synthetic Core {operation} failed with HTTP {status}")
        return value

    @classmethod
    def tearDownClass(cls):
        stop(cls.core, cls.core_thread)
        cls.core_temp.cleanup()

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="osgard-participant-guard-")
        self.database = Path(self.temporary.name) / "terminal.sqlite3"
        self.legacy = TwoPlayerLegacy()
        self.backend = ThreadingHTTPServer(("127.0.0.1", 0), TwoPlayerHandler)
        self.backend.daemon_threads = True
        self.backend.legacy = self.legacy
        self.backend_thread = serve(self.backend)
        self.backend_base = f"http://127.0.0.1:{self.backend.server_address[1]}"
        self.backend_live = True
        self.server = None
        self.processes = []
        self.start_guard()

    def start_guard(self, admission=True, creation=True, **kwargs):
        self.server = guard.create_server(self.database, self.backend_base, port=0, core_upstream=self.core_base,
                   core_host="osgard.world", enable_owned_creation=creation, enable_participant_admission=admission, **kwargs)
        self.thread = serve(self.server)
        self.port = self.server.server_address[1]

    def stop_guard(self):
        if self.server is not None:
            stop(self.server, self.thread)
            self.server = None

    def restart(self, **kwargs):
        self.stop_guard()
        self.start_guard(**kwargs)

    def start_process(self, pause="", enabled=True):
        context = multiprocessing.get_context("spawn")
        receiver, sender = context.Pipe()
        entered, release = context.Event(), context.Event()
        process = context.Process(target=participant_process, args=(str(self.database), self.backend_base,
                   self.core_base, sender, entered, release, pause, enabled))
        process.start()
        sender.close()
        self.processes.append((process, receiver, release))
        self.assertTrue(receiver.poll(6), "Independent participant guard did not start")
        return process, receiver.recv(), entered, release

    def tearDown(self):
        if self.legacy.input_release:
            self.legacy.input_release.set()
        for process, control, release in self.processes:
            if process.is_alive():
                # A deliberately killed process cannot acknowledge an Event
                # wakeup. Do not notify its abandoned condition waiters.
                release.set()
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

    def request(self, path, body=None, token=None, port=None, **kwargs):
        return http_request(port or self.port, path, body, token, **kwargs)

    def create(self, key=CREATE_KEY):
        reply = self.request("/v2/matches", fixture.CREATE, self.owner["token"], headers={"Idempotency-Key": key})
        self.assertEqual(reply[0], 201, reply[1])
        return reply[1]

    def invite(self, match, key=INVITE_KEY, recipient=None, token=None, **kwargs):
        return self.request(f"/v2/matches/{match['id']}/invitations",
                            {"recipientAccountId": recipient or self.target["user"]["id"]},
                            token or self.owner["token"], headers={"Idempotency-Key": key}, **kwargs)

    def invitation(self, match, **kwargs):
        reply = self.invite(match, **kwargs)
        self.assertEqual(reply[0], 201, reply[1])
        return reply[1]["invitation"]

    def operation(self, invitation, kind="accept", key=None, token=None, **kwargs):
        return self.request(f"/v2/invitations/{invitation['id']}/{kind}", {},
                            token or (self.target["token"] if kind == "accept" else self.owner["token"]),
                            headers={"Idempotency-Key": key or (ACCEPT_KEY if kind == "accept" else REVOKE_KEY)}, **kwargs)

    def joined(self):
        match = self.create()
        invitation = self.invitation(match)
        reply = self.operation(invitation)
        self.assertEqual(reply[0], 201, reply[1])
        return match, invitation, reply[1]["match"]

    def metadata(self, match, token=None):
        return self.request(f"/v2/matches/{match['id']}", token=token or self.owner["token"])

    def command(self, match, token=None, sequence=1, prefix="v2", **changes):
        return self.request(f"/{prefix}/matches/{match['id']}/input", dict(INPUT, sequence=sequence, **changes), token or self.owner["token"])

    def recovery(self, key=ACCEPT_KEY, token=None):
        return self.request("/v2/admission-attempts/" + key, token=token or self.target["token"])

    def test_default_foundation_is_additive_and_admission_does_not_start_implicitly(self):
        self.restart(admission=False)
        match = self.create()
        self.assertEqual(self.server.guard.store.schema_version(), 2)
        health = self.request("/health")[1]
        self.assertEqual((health["participantPolicyVersion"], health["participantAdmissionEnabled"], health["maxParticipants"]), (1, False, 2))
        self.assertEqual(self.invite(match)[0:2], (403, {"error": "participant_admission_disabled",
                         "message": "New participant admission is not enabled in this release."}))
        self.assertIsNone(self.server.guard.store.admission_attempt(self.owner["user"]["id"], INVITE_KEY))
        self.assertEqual(self.server.guard.store.schema_version(), 2)
        self.legacy.playing(match["id"])
        self.assertEqual(self.command(match)[0], 200)
        self.assertEqual(self.metadata(match)[1]["participantCount"], 1)

    def test_invitation_reference_is_not_a_capability_or_automatic_join(self):
        match = self.create()
        invitation = self.invitation(match)
        path = "/v2/invitations/" + invitation["id"]
        before = len(self.legacy.calls)
        self.assertEqual(self.request(path)[0], 401)
        self.assertEqual(self.request(path, token=self.outsider["token"])[0], 403)
        self.assertEqual(self.operation(invitation, token=self.outsider["token"])[0], 403)
        self.assertEqual(self.operation(invitation, token=self.owner["token"])[0], 403)
        self.assertEqual(self.operation(invitation, kind="revoke", token=self.target["token"])[0], 403)
        self.assertEqual(len(self.legacy.calls), before)
        owner_view = self.request(path, token=self.owner["token"])[1]
        target_view = self.request(path, token=self.target["token"])[1]
        self.assertEqual((owner_view["role"], target_view["role"]), ("owner", "recipient"))
        self.assertEqual((owner_view["admissionAllowed"], target_view["admissionAllowed"]), (False, True))
        self.assertEqual(target_view["engine"], {"phase": "COUNTDOWN", "remainingMs": 2500})
        self.assertEqual(target_view["status"], "pending")
        self.assertEqual(self.metadata(match, self.target["token"])[0], 403)
        self.assertEqual(self.legacy.states[match["id"]]["players"], 0)

    def test_two_verified_members_have_distinct_ids_sequence_one_and_relative_history(self):
        owner, invitation, participant = self.joined()
        self.assertEqual(participant["id"], owner["id"])
        self.assertNotEqual(participant["playerId"], owner["playerId"])
        self.assertNotIn(participant["playerId"], (self.owner["user"]["id"], self.target["user"]["id"]))
        self.assertEqual((participant["role"], participant["participantCount"], participant["maxParticipants"], participant["highestSubmittedSequence"]), ("participant", 2, 2, 0))
        self.assertEqual(self.metadata(owner)[1]["participantCount"], 2)
        self.assertEqual(self.legacy.states[owner["id"]]["players"], 0)
        self.legacy.playing(owner["id"])
        for user, match in ((self.owner, owner), (self.target, participant)):
            reply = self.command(match, user["token"])
            self.assertEqual((reply[0], reply[1]["playerId"], reply[1]["lastSequence"]), (200, match["playerId"], 1))
            history = self.request("/v2/matches", token=user["token"])[1]
            self.assertEqual(history["matches"], [self.metadata(match, user["token"])[1]])
            self.assertIsNone(history["nextCursor"])
        self.assertEqual(self.request("/v2/matches", token=self.outsider["token"])[1]["matches"], [])
        state = self.legacy.states[owner["id"]]
        self.assertEqual((state["players"], state["replayFrames"]), (2, 2))
        self.assertEqual({row["playerId"] for row in state["scores"]}, {owner["playerId"], participant["playerId"]})

    def test_every_alias_uses_membership_before_query_player_or_cache(self):
        owner, invitation, participant = self.joined()
        self.legacy.playing(owner["id"])
        before = len(self.legacy.calls)
        for prefix in ("v1", "v2"):
            for action, body in (("state", None), ("result", None), ("input", INPUT)):
                for suffix in ("", "/", "?playerId=attacker"):
                    path = f"/{prefix}/matches/{owner['id']}/{action}{suffix}"
                    with self.subTest(path=path):
                        self.assertEqual(self.request(path, body)[0], 401)
                        self.assertEqual(self.request(path, body, self.outsider["token"])[0], 403)
        self.assertEqual(len(self.legacy.calls), before)
        reply = self.request(f"/v1/matches/{owner['id']}/input?playerId={owner['playerId']}", INPUT, self.target["token"])
        self.assertEqual((reply[0], reply[1]["playerId"]), (200, participant["playerId"]))
        self.assertNotIn("?", self.legacy.posts("/input")[-1][1])

    def test_member_cannot_submit_as_other_member_even_through_v1(self):
        owner, invitation, participant = self.joined()
        self.legacy.playing(owner["id"])
        before = len(self.legacy.calls)
        for prefix in ("v1", "v2"):
            for user, forged in ((self.owner, participant["playerId"]), (self.target, owner["playerId"]), (self.target, "arbitrary")):
                reply = self.command(owner, user["token"], prefix=prefix, playerId=forged)
                self.assertEqual((reply[0], reply[1]["error"]), (403, "player_forbidden"))
        self.assertEqual(len(self.legacy.calls), before)
        self.assertEqual(self.metadata(owner, self.target["token"])[1]["highestSubmittedSequence"], 0)

    def test_completed_operations_recover_without_upstream_and_accept_returns_fresh_highwater(self):
        owner, invitation, participant = self.joined()
        self.legacy.playing(owner["id"])
        self.assertEqual(self.command(owner, self.target["token"], sequence=7)[0], 200)
        before = len(self.legacy.calls)
        repeated = self.operation(invitation)
        self.assertEqual((repeated[0], repeated[1]["match"]["highestSubmittedSequence"]), (201, 7))
        recovered = self.recovery()
        self.assertEqual((recovered[0], recovered[1]), (200, repeated[1]))
        repeated_invite = self.invite(owner)
        self.assertEqual((repeated_invite[0], repeated_invite[1]["invitation"]["id"]), (201, invitation["id"]))
        self.assertEqual(len(self.legacy.calls), before)
        stop(self.backend, self.backend_thread)
        self.backend_live = False
        self.assertEqual(self.recovery()[1], recovered[1])
        self.assertEqual(self.recovery(INVITE_KEY, self.owner["token"])[1]["status"], "ready")
        self.assertEqual(len(self.legacy.posts("/v1/matches")), 1)
        self.assertEqual(self.legacy.input_count, 1)

    def test_operation_keys_bind_actor_kind_and_exact_target(self):
        owner = self.create()
        invitation = self.invitation(owner)
        self.assertEqual(self.recovery(INVITE_KEY)[0], 404)
        conflict = self.invite(owner, recipient=self.outsider["user"]["id"])
        self.assertEqual((conflict[0], conflict[1]["error"]), (409, "operation_conflict"))
        conflict = self.operation(invitation, kind="revoke", key=INVITE_KEY)
        self.assertEqual((conflict[0], conflict[1]["error"]), (409, "operation_conflict"))
        accepted = self.operation(invitation, key=INVITE_KEY)
        self.assertEqual(accepted[0], 201)  # Same spelling is scoped to another Core actor.
        self.assertEqual(self.recovery(INVITE_KEY)[1]["operation"], "accept")

    def test_pending_conflict_is_durable_and_returns_existing_reference(self):
        owner = self.create()
        invitation = self.invitation(owner)
        key = "participant_invite_0002"
        reply = self.invite(owner, key=key)
        self.assertEqual((reply[0], reply[1]["status"], reply[1]["error"], reply[1]["invitationId"]),
                         (409, "rejected", "invitation_pending", invitation["id"]))
        self.assertEqual(self.recovery(key, self.owner["token"])[1], reply[1])
        self.assertEqual(self.invite(owner, key=key)[1], reply[1])

    def test_pending_revoke_is_owner_only_and_accepted_slot_cannot_be_reassigned(self):
        owner = self.create()
        invitation = self.invitation(owner)
        revoked = self.operation(invitation, kind="revoke")
        self.assertEqual((revoked[0], revoked[1]["invitation"]["status"]), (200, "revoked"))
        self.assertEqual(self.operation(invitation, kind="revoke")[1], revoked[1])
        rejected = self.operation(invitation)
        self.assertEqual((rejected[0], rejected[1]["error"]), (409, "invitation_revoked"))
        second = self.invitation(owner, key="participant_invite_0002")
        self.assertEqual(self.operation(second, key="participant_accept_0002")[0], 201)
        denied = self.operation(second, kind="revoke", key="participant_revoke_0002")
        self.assertEqual((denied[0], denied[1]["error"]), (409, "invitation_accepted"))
        full = self.invite(owner, key="participant_invite_0003", recipient=self.outsider["user"]["id"])
        self.assertEqual((full[0], full[1]["error"]), (409, "match_full"))
        self.assertEqual(self.metadata(owner, self.outsider["token"])[0], 403)

    def test_expired_reference_does_not_create_membership_or_extend_engine_clock(self):
        owner = self.create()
        invitation = self.invitation(owner)
        now = datetime.now(timezone.utc)
        with sqlite3.connect(self.database) as db:
            db.execute("UPDATE owned_invitations SET created_at=?,expires_at=? WHERE invitation_id=?",
                       ((now - timedelta(seconds=130)).isoformat(), (now - timedelta(seconds=10)).isoformat(), invitation["id"]))
        before = copy.deepcopy(self.legacy.states[owner["id"]])
        reply = self.operation(invitation)
        self.assertEqual((reply[0], reply[1]["error"]), (409, "invitation_expired"))
        self.assertEqual(self.legacy.states[owner["id"]], before)
        self.assertEqual(self.metadata(owner, self.target["token"])[0], 403)

    def test_fresh_admission_phase_and_positive_clock_are_required(self):
        cases = [("COUNTDOWN", 1, 201), ("PLAYING", 1, 201), ("RUNNING", 1, 201),
                 ("WAITING", 30000, 409), ("COUNTDOWN", 0, 409), ("PLAYING", 0, 409), ("RESULTS", 0, 409)]
        for index, (phase, remaining, expected) in enumerate(cases):
            with self.subTest(phase=phase, remaining=remaining):
                owner = self.create(key=f"participant_create_{index + 10:04d}")
                invitation = self.invitation(owner, key=f"participant_invite_{index + 10:04d}")
                self.legacy.states[owner["id"]].update(phase=phase, remainingMs=remaining)
                before = copy.deepcopy(self.legacy.states[owner["id"]])
                reply = self.operation(invitation, key=f"participant_accept_{index + 10:04d}")
                self.assertEqual(reply[0], expected, reply[1])
                self.assertEqual(self.legacy.states[owner["id"]], before)
                self.assertEqual(self.metadata(owner)[1]["participantCount"], 2 if expected == 201 else 1)

    def test_malformed_terminal_observation_permanently_blocks_later_admission(self):
        owner = self.create()
        invitation = self.invitation(owner)
        self.legacy.states[owner["id"]].update(phase="RESULTS", remainingMs=1)
        self.assertEqual(self.request("/v2/invitations/" + invitation["id"], token=self.target["token"])[0], 503)
        self.assertIsNotNone(self.server.guard.store.load(owner["id"]))
        self.legacy.playing(owner["id"])
        reply = self.operation(invitation)
        self.assertEqual((reply[0], reply[1]["error"]), (409, "match_closed"))
        self.assertEqual(self.command(owner)[0], 409)
        self.assertEqual(self.legacy.input_count, 0)

    def test_uncertain_participant_input_reserves_own_highwater_only_and_is_not_retried(self):
        owner, invitation, participant = self.joined()
        self.legacy.playing(owner["id"])
        self.legacy.drop_input = True
        self.assertEqual(self.command(owner, self.target["token"], sequence=4)[0], 503)
        self.assertEqual(self.legacy.input_count, 1)
        self.assertEqual(self.metadata(owner)[1]["highestSubmittedSequence"], 0)
        self.assertEqual(self.metadata(owner, self.target["token"])[1]["highestSubmittedSequence"], 4)
        self.legacy.drop_input = False
        self.restart(admission=False, creation=False)
        for sequence in (1, 4):
            reply = self.command(owner, self.target["token"], sequence=sequence)
            self.assertEqual((reply[0], reply[1]["error"]), (409, "stale_input_sequence"))
        self.assertEqual(self.legacy.input_count, 1)
        self.assertEqual(self.command(owner)[0], 200)
        self.assertEqual(self.command(owner, self.target["token"], sequence=6)[0], 200)
        self.assertEqual(self.legacy.input_count, 3)

    def test_two_player_frozen_bytes_survive_disabled_restart_and_engine_outage(self):
        owner, invitation, participant = self.joined()
        self.legacy.playing(owner["id"])
        self.assertEqual(self.command(owner)[0], 200)
        self.assertEqual(self.command(owner, self.target["token"])[0], 200)
        self.legacy.terminal(owner["id"])
        path = f"/v2/matches/{owner['id']}/result"
        frozen = self.request(path, token=self.owner["token"])
        self.assertEqual(frozen[0], 200)
        self.assertEqual(len(frozen[1]["scores"]), 2)
        self.assertEqual(self.request(path, token=self.target["token"])[2], frozen[2])
        # Restart while the upstream lies about its phase; durable membership
        # and terminal data, not upstream state, must determine these replies.
        self.legacy.playing(owner["id"])
        self.legacy.states[owner["id"]]["scores"][0]["score"] = 999
        self.restart(admission=False, creation=False)
        stop(self.backend, self.backend_thread)
        self.backend_live = False
        for prefix in ("v1", "v2"):
            route = f"/{prefix}/matches/{owner['id']}/result"
            self.assertEqual(self.request(route)[0], 401)
            self.assertEqual(self.request(route, token=self.outsider["token"])[0], 403)
            for actor in (self.owner, self.target):
                self.assertEqual(self.request(route, token=actor["token"])[2], frozen[2])
                self.assertEqual(self.command(owner, actor["token"], sequence=2, prefix=prefix)[0], 409)
        self.assertEqual(self.recovery()[1]["match"]["playerId"], participant["playerId"])
        self.assertEqual(self.server.guard.store.schema_version(), 3)

    def test_real_core_logout_expiry_and_revocation_apply_to_joined_frozen_reads(self):
        owner, invitation, participant = self.joined()
        self.legacy.terminal(owner["id"])
        path = f"/v1/matches/{owner['id']}/result"
        self.assertEqual(self.request(path, token=self.target["token"])[0], 200)
        for reason in ("logout", "expiry", "revoke"):
            with self.subTest(reason=reason):
                login = self.account()
                self.assertEqual(self.request(path, token=login["token"])[0], 200)
                if reason == "logout":
                    self.assertEqual(self.core_request("auth/logout", {}, login["token"])[0], 200)
                elif reason == "expiry":
                    with sqlite3.connect(self.core_database) as db:
                        db.execute("UPDATE sessions SET expires_at=? WHERE token_hash=?",
                                   (time.time() - 1, hashlib.sha256(login["token"].encode()).hexdigest()))
                else:
                    sessions = self.core_request("auth/security", token=login["token"])[1]["sessions"]
                    current = next(row["id"] for row in sessions if row["current"])
                    self.assertEqual(self.core_request("auth/sessions/revoke", {"sessionId": current}, self.target["token"])[0], 200)
                self.assertEqual(self.request(path, token=login["token"])[0], 401)
                self.assertEqual(self.recovery(token=login["token"])[0], 401)
                self.assertEqual(self.command(owner, login["token"])[0], 401)
        self.assertEqual(self.request(path, token=self.target["token"])[0], 200)

    def test_core_outage_never_downgrades_joined_member_or_recovery_to_guest(self):
        owner, invitation, participant = self.joined()
        self.legacy.terminal(owner["id"])
        self.assertEqual(self.request(f"/v2/matches/{owner['id']}/result", token=self.target["token"])[0], 200)
        self.server.guard.core.upstream = guard.Upstream("http://127.0.0.1:1", timeout=0.05, trusted_host="osgard.world")
        before = len(self.legacy.calls)
        for path in (f"/v1/matches/{owner['id']}/result", f"/v2/matches/{owner['id']}",
                     "/v2/invitations/" + invitation["id"], "/v2/admission-attempts/" + ACCEPT_KEY):
            reply = self.request(path, token=self.target["token"])
            self.assertEqual((reply[0], reply[1]["error"]), (503, "authentication_unavailable"))
        self.assertEqual(len(self.legacy.calls), before)

    def test_admission_sends_no_post_identity_or_credentials_to_legacy(self):
        owner = self.create()
        headers = {"Idempotency-Key": INVITE_KEY, "Cookie": "participant_fixture_cookie=private",
                   "X-User-Id": self.target["user"]["id"], "Authorization": "Bearer " + self.owner["token"]}
        reply = self.request(f"/v2/matches/{owner['id']}/invitations", {"recipientAccountId": self.target["user"]["id"]}, headers=headers)
        self.assertEqual(reply[0], 201)
        self.assertEqual(self.operation(reply[1]["invitation"])[0], 201)
        before_input = copy.deepcopy(self.legacy.calls)
        self.legacy.playing(owner["id"])
        self.assertEqual(self.command(owner, self.target["token"])[0], 200)
        self.assertEqual([call[1] for call in before_input if call[0] == "POST"], ["/v1/matches"])
        for method, route, body, outgoing in self.legacy.calls:
            self.assertFalse({name.lower() for name in outgoing} & {"authorization", "cookie", "x-user-id", "idempotency-key", "proxy-authorization"})
            for actor in (self.owner, self.target):
                self.assertNotIn(actor["user"]["id"], json.dumps((route, body, outgoing)))
                self.assertNotIn(actor["token"], json.dumps((route, body, outgoing)))
        for path in Path(self.temporary.name).glob("terminal.sqlite3*"):
            data = path.read_bytes()
            for actor in (self.owner, self.target):
                self.assertNotIn(actor["token"].encode(), data)
            self.assertNotIn(b"participant_fixture_cookie", data)

    def test_storage_failure_before_reservation_has_no_admission_or_legacy_write(self):
        owner = self.create()
        before = len(self.legacy.calls)
        with patch.object(self.server.guard.store, "reserve_admission", side_effect=sqlite3.OperationalError("fixture full")):
            self.assertEqual(self.invite(owner)[0], 503)
        self.assertEqual(len(self.legacy.calls), before)
        self.assertIsNone(self.server.guard.store.admission_attempt(self.owner["user"]["id"], INVITE_KEY))
        self.assertEqual(self.server.guard.store.schema_version(), 2)

    def test_atomic_ready_failure_rolls_back_membership_and_get_recovers_no_commit(self):
        owner = self.create()
        invitation = self.invitation(owner)
        with sqlite3.connect(self.database) as db:
            db.execute("""CREATE TRIGGER fixture_reject_ready BEFORE UPDATE ON owned_admission_attempts
                          WHEN NEW.operation='accept' AND NEW.status='ready'
                          BEGIN SELECT RAISE(ABORT,'fixture commit failure'); END""")
        self.assertEqual(self.operation(invitation)[0], 503)
        self.assertIsNone(self.server.guard.store.second_participant(self.server.guard.store.owner(owner["id"])))
        self.assertEqual(self.server.guard.store.invitation(invitation["id"])["status"], "pending")
        with sqlite3.connect(self.database) as db:
            db.execute("DROP TRIGGER fixture_reject_ready")
        recovery = self.recovery()
        self.assertEqual((recovery[0], recovery[1]["status"], recovery[1]["error"]), (200, "rejected", "admission_interrupted"))
        self.assertEqual(self.operation(invitation)[0], 409)
        self.assertEqual(self.metadata(owner, self.target["token"])[0], 403)
        self.assertEqual(self.operation(invitation, key="participant_accept_0002")[0], 201)

    def test_lost_accept_response_recovers_only_existing_committed_membership(self):
        owner = self.create()
        invitation = self.invitation(owner)
        with patch.object(self.server.guard, "_admission_reply", side_effect=guard.GuardError("fixture_lost_response", "No response.")):
            self.assertEqual(self.operation(invitation)[0], 503)
        recovered = self.recovery()
        self.assertEqual((recovered[0], recovered[1]["status"]), (200, "ready"))
        player = recovered[1]["match"]["playerId"]
        self.assertEqual(self.operation(invitation)[1]["match"]["playerId"], player)
        self.assertEqual(self.legacy.input_count, 0)
        self.assertEqual(len(self.legacy.posts("/v1/matches")), 1)

    def test_schema_two_foundation_adds_empty_tables_without_raising_then_never_downgrades_three(self):
        owner = self.create()
        self.stop_guard()
        with sqlite3.connect(self.database) as db:
            for table in ("owned_admission_attempts", "owned_participants", "owned_invitations"):
                db.execute(f'DROP TABLE "{table}"')
            self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 2)
        self.start_guard(admission=False)
        self.assertEqual(self.metadata(owner)[0], 200)
        self.assertEqual(self.server.guard.store.schema_version(), 2)
        self.restart(admission=True)
        self.invitation(owner)
        self.assertEqual(self.server.guard.store.schema_version(), 3)
        self.create(key="participant_create_0002")
        self.assertEqual(self.server.guard.store.schema_version(), 3)
        self.restart(admission=False, creation=False)
        self.assertEqual(self.server.guard.store.schema_version(), 3)

    def test_schema_three_startup_refuses_missing_admission_tables(self):
        owner, invitation, participant = self.joined()
        for table in ("owned_participants", "owned_invitations", "owned_admission_attempts"):
            with self.subTest(table=table):
                broken = Path(self.temporary.name) / (table + "-missing.sqlite3")
                with sqlite3.connect(self.database) as source, sqlite3.connect(broken) as destination:
                    source.backup(destination)
                    destination.execute(f'DROP TABLE "{table}"')
                with self.assertRaisesRegex(ValueError, "schema is incomplete"):
                    guard.Guard(broken, self.backend_base, core_upstream=self.core_base)
                with sqlite3.connect(broken) as db:
                    self.assertEqual(db.execute("PRAGMA user_version").fetchone()[0], 3)
                    self.assertIsNone(db.execute("SELECT 1 FROM sqlite_master WHERE name=?", (table,)).fetchone())

    def test_lost_member_row_cannot_reopen_slot_or_return_owner_frozen_result(self):
        owner, invitation, participant = self.joined()
        self.legacy.terminal(owner["id"])
        path = f"/v1/matches/{owner['id']}/result"
        self.assertEqual(self.request(path, token=self.owner["token"])[0], 200)
        with sqlite3.connect(self.database) as db:
            db.execute("DELETE FROM owned_participants WHERE match_id=?", (owner["id"],))
        for actor in (self.owner, self.target):
            self.assertEqual(self.request(path, token=actor["token"])[0], 503)
        self.assertEqual(self.invite(owner, key="participant_invite_0002")[0], 409)
        self.assertEqual(self.recovery()[0], 503)

    def test_unknown_player_in_terminal_roster_fails_closed_without_reopening_input(self):
        owner, invitation, participant = self.joined()
        self.legacy.states[owner["id"]].update(phase="RESULTS", remainingMs=0, players=1,
            replayFrames=1, scores=[{"playerId": "unbound_legacy_player", "score": 7}])
        path = f"/v2/matches/{owner['id']}/result"
        self.assertEqual(self.request(path, token=self.target["token"])[0], 503)
        self.assertEqual(self.server.guard.store.load(owner["id"]), {"state": None, "result": None})
        self.legacy.playing(owner["id"])
        self.assertEqual(self.command(owner)[0], 409)
        self.assertEqual(self.command(owner, self.target["token"])[0], 409)
        self.assertEqual(self.legacy.input_count, 0)

    def test_admission_route_spellings_methods_and_private_body_fields_never_forward(self):
        owner = self.create()
        invitation = self.invitation(owner)
        before = len(self.legacy.calls)
        base = "/v2/invitations/" + invitation["id"]
        for path in (base + "/accept/child", base.replace("/v2/", "/V2/"), base + "/%61ccept", base + "/../accept", base + "//accept"):
            self.assertIn(self.request(path, {}, self.target["token"], headers={"Idempotency-Key": ACCEPT_KEY})[0], (400, 404))
        for path, method in ((base + "/accept", "GET"), (base, "POST"), ("/v2/admission-attempts/" + ACCEPT_KEY, "POST")):
            self.assertEqual(self.request(path, {}, self.target["token"], method=method)[0], 405)
        self.assertEqual(self.request(base + "/accept?playerId=other", {}, self.target["token"])[0], 400)
        self.assertEqual(self.request(base + "/accept", {"playerId": "forged"}, self.target["token"], headers={"Idempotency-Key": ACCEPT_KEY})[0], 400)
        self.assertEqual(self.invite(owner, recipient="../bad")[0], 400)
        self.assertEqual(len(self.legacy.calls), before)

    def test_match_lease_timeout_does_not_reserve_an_admission(self):
        owner = self.create()
        self.restart(admission=True, budget=0.12)
        with self.server.guard.files.match(owner["id"], time.monotonic() + 1):
            started = time.monotonic()
            self.assertEqual(self.invite(owner)[0], 503)
            self.assertLess(time.monotonic() - started, 0.5)
        self.assertIsNone(self.server.guard.store.admission_attempt(self.owner["user"]["id"], INVITE_KEY))
        self.assertEqual(self.server.guard.store.schema_version(), 2)

    def test_two_processes_competing_accepts_fill_one_immutable_slot(self):
        owner = self.create()
        invitation = self.invitation(owner)
        _, other_port, _, _ = self.start_process()
        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(self.operation, invitation)
            second = pool.submit(self.operation, invitation, key="participant_accept_0002", port=other_port)
            replies = [first.result(6), second.result(6)]
        self.assertEqual(sorted(reply[0] for reply in replies), [201, 409])
        accepted = next(reply[1] for reply in replies if reply[0] == 201)
        self.assertEqual(self.metadata(owner, self.target["token"])[1]["playerId"], accepted["match"]["playerId"])
        with sqlite3.connect(self.database) as db:
            self.assertEqual(db.execute("SELECT COUNT(*) FROM owned_participants").fetchone()[0], 1)
        self.assertEqual(self.legacy.input_count, 0)
        self.legacy.playing(owner["id"])
        path = f"/v2/matches/{owner['id']}/input"
        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(self.command, owner)
            second = pool.submit(self.request, path, INPUT, self.target["token"], port=other_port)
            self.assertEqual((first.result(6)[0], second.result(6)[0]), (200, 200))
        with ThreadPoolExecutor(max_workers=2) as pool:
            first = pool.submit(self.command, owner, self.target["token"], sequence=2)
            second = pool.submit(self.request, path, dict(INPUT, sequence=2), self.target["token"], port=other_port)
            self.assertEqual(sorted([first.result(6)[0], second.result(6)[0]]), [200, 409])
        self.assertEqual(self.legacy.input_count, 3)
        self.assertEqual(self.metadata(owner)[1]["highestSubmittedSequence"], 1)
        self.assertEqual(self.metadata(owner, self.target["token"])[1]["highestSubmittedSequence"], 2)

    def test_other_process_cannot_forward_participant_input_before_binding_commit(self):
        owner = self.create()
        invitation = self.invitation(owner)
        self.legacy.playing(owner["id"])
        _, creator_port, entered, release = self.start_process(pause="in_transaction")
        with ThreadPoolExecutor(max_workers=2) as pool:
            acceptance = pool.submit(self.operation, invitation, port=creator_port)
            self.assertTrue(entered.wait(3), "Accept did not reach the uncommitted participant insert")
            with sqlite3.connect(self.database) as db:
                self.assertEqual(db.execute("SELECT COUNT(*) FROM owned_participants").fetchone()[0], 0)
            command = pool.submit(self.command, owner, self.target["token"])
            time.sleep(0.06)
            self.assertFalse(command.done())
            self.assertEqual(self.legacy.input_count, 0)
            release.set()
            accepted, submitted = acceptance.result(6), command.result(6)
        self.assertEqual((accepted[0], submitted[0]), (201, 200))
        self.assertEqual(accepted[1]["match"]["playerId"], submitted[1]["playerId"])
        self.assertEqual(self.legacy.input_count, 1)

    def test_process_death_inside_sqlite_transaction_does_not_leave_partial_membership(self):
        owner = self.create()
        invitation = self.invitation(owner)
        process, port, entered, release = self.start_process(pause="in_transaction")
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(self.operation, invitation, port=port)
            self.assertTrue(entered.wait(3))
            process.terminate()
            process.join(3)
            with self.assertRaises((http.client.HTTPException, OSError)):
                pending.result(6)
        recovered = self.recovery()
        self.assertEqual((recovered[0], recovered[1]["status"], recovered[1]["error"]), (200, "rejected", "admission_interrupted"))
        self.assertEqual(self.metadata(owner, self.target["token"])[0], 403)
        self.assertEqual(self.server.guard.store.invitation(invitation["id"])["status"], "pending")
        self.assertEqual(self.legacy.input_count, 0)
        self.assertEqual(self.server.guard.store.schema_version(), 3)

    def test_process_death_after_commit_recovers_ready_under_disabled_admission(self):
        owner = self.create()
        invitation = self.invitation(owner)
        process, port, entered, release = self.start_process(pause="after_commit")
        with ThreadPoolExecutor(max_workers=1) as pool:
            pending = pool.submit(self.operation, invitation, port=port)
            self.assertTrue(entered.wait(3))
            process.terminate()
            process.join(3)
            with self.assertRaises((http.client.HTTPException, OSError)):
                pending.result(6)
        self.restart(admission=False, creation=False)
        recovered = self.recovery()
        self.assertEqual((recovered[0], recovered[1]["status"]), (200, "ready"))
        self.assertEqual(recovered[1]["match"]["highestSubmittedSequence"], 0)
        self.assertEqual(self.operation(invitation)[1], recovered[1])
        self.legacy.playing(owner["id"])
        self.assertEqual(self.command(owner, self.target["token"])[0], 200)
        self.assertEqual(self.legacy.input_count, 1)

    def test_finalization_waits_for_in_progress_input_and_freezes_both_players(self):
        owner, invitation, participant = self.joined()
        self.legacy.playing(owner["id"])
        self.assertEqual(self.command(owner)[0], 200)
        self.legacy.input_entered, self.legacy.input_release = threading.Event(), threading.Event()
        _, other_port, _, _ = self.start_process(enabled=False)
        with ThreadPoolExecutor(max_workers=2) as pool:
            command = pool.submit(self.command, owner, self.target["token"])
            self.assertTrue(self.legacy.input_entered.wait(3))
            self.legacy.terminal(owner["id"])
            result = pool.submit(self.request, f"/v2/matches/{owner['id']}/result", token=self.owner["token"], port=other_port)
            time.sleep(0.06)
            self.assertFalse(result.done())
            self.legacy.input_release.set()
            self.assertEqual(command.result(6)[0], 200)
            frozen = result.result(6)
        self.assertEqual((frozen[0], len(frozen[1]["scores"])), (200, 2))
        self.assertEqual(self.command(owner, self.target["token"], sequence=2)[0], 409)
        self.assertEqual(self.legacy.input_count, 2)

    def test_engine_expiry_after_admission_read_is_not_an_atomic_expiry_or_clock_extension_claim(self):
        owner = self.create()
        invitation = self.invitation(owner)
        complete = self.server.guard.store.complete_admission

        def engine_expires(*args, **kwargs):
            self.legacy.terminal(owner["id"])
            return complete(*args, **kwargs)

        with patch.object(self.server.guard.store, "complete_admission", side_effect=engine_expires):
            reply = self.operation(invitation)
        self.assertEqual(reply[0], 201)  # Local membership committed after the last positive engine read.
        self.assertEqual(self.legacy.states[owner["id"]]["remainingMs"], 0)
        self.assertEqual(self.command(owner, self.target["token"])[0], 409)
        self.assertEqual(self.legacy.input_count, 0)

    def test_disabled_admission_keeps_pending_revoke_and_existing_acl_without_guest_downgrade(self):
        owner = self.create()
        invitation = self.invitation(owner)
        self.restart(admission=False, creation=False)
        self.assertEqual(self.operation(invitation)[0], 403)
        self.assertEqual(self.metadata(owner, self.target["token"])[0], 403)
        self.assertEqual(self.operation(invitation, kind="revoke")[0], 200)
        self.assertEqual(self.recovery(REVOKE_KEY, self.owner["token"])[1]["status"], "ready")
        self.assertEqual(self.request(f"/v1/matches/{fixture.GUEST_MATCH}/state")[0], 200)
        self.assertEqual(self.server.guard.store.schema_version(), 3)


if __name__ == "__main__":
    unittest.main(verbosity=2)
