#!/usr/bin/env python3
"""Bounded compatibility check of two guest players in the published REMIX engine.

Default is three read-only requests. --exercise-two-player, with an explicit
12-character release pin, creates one private QA challenge and one guest match.
Only that new match is used: two accepted sequence-1 inputs, two deliberate
duplicate checks and two late-input checks. Maximum eight POST attempts, 72 total
requests and 90 seconds; no automatic POST retry, enumeration or existing match
input. No Core account or session is created. The isolated QA records remain.

This proves neither v2 participant ACL nor Unity, replay verification, simulator
restart recovery or atomic legacy expiry. It uses the existing reviewed runtime
HTTP CONNECT helper and original HTTPSConnection TLS validation; no redirect,
proxy fallback, custom origin or credential forwarding to the origin is added.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import re
import secrets
import sys
import tempfile
import time


def sibling(name, filename):
    spec = importlib.util.spec_from_file_location(name, Path(__file__).resolve().with_name(filename))
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


# Reuse the already tested deadline, fixed-origin proxy adapter and observed
# v1 DTO validators. None of these modules performs a request when imported.
transport = sibling("_remix_two_player_transport", "with-remix-runtime-proxy.py")
timing = sibling("_remix_two_player_timing", "remix-owned-live-smoke.py")
contract = sibling("_remix_two_player_contract", "remix-service-contract-smoke.py")
ProbeFailure, require, request_timeout = timing.ProbeFailure, timing.require, timing.request_timeout
ORIGIN = "https://osgard.world"
PREFIX = "/api/remix"
MAX_REQUESTS = 72
MAX_SECONDS = 90
MAX_BODY = 1_048_576


def unique_object(pairs):
    value = dict(pairs)
    require(len(value) == len(pairs), "A JSON object contains duplicate fields")
    return value


def canonical_result(value):
    return {"matchId": value["matchId"], "phase": value["phase"], "replayFrames": value["replayFrames"],
            "scores": sorted(({"playerId": row["playerId"], "score": row["score"]} for row in value["scores"]),
                             key=lambda row: row["playerId"])}


class Probe:
    def __init__(self, exercise, expected_release, connection=None, output=None):
        require(not expected_release or re.fullmatch(r"[a-f0-9]{12}", expected_release), "Expected release must be a 12-character commit marker")
        require(not exercise or bool(expected_release), "Two-player writes require an explicit expected release")
        self.exercise_enabled = bool(exercise)
        self.expected_release = expected_release
        self.connection = connection
        self.started = time.monotonic()
        self.deadline = self.started + MAX_SECONDS
        self.match_id = self.challenge_id = ""
        self.players = []
        self.post_counts = {"challenge": 0, "match": 0, "input": 0}
        self.output = Path(output) if output else None
        self.report = {"schemaVersion": 1, "origin": ORIGIN, "status": "running",
            "mode": "guest-two-player-engine-compatibility" if exercise else "read-only",
            "startedAt": dt.datetime.now(dt.timezone.utc).isoformat(), "requests": [], "checks": [],
            "limits": ["Guest v1 engine compatibility only; no v2 membership or ACL proof",
                       "No Core accounts, credentials or sessions", "No Unity or verified replay",
                       "No active-engine recovery, restart test or atomic legacy expiry claim",
                       "No automatic POST retry, match enumeration or existing-user-data modification",
                       "One private QA challenge and one guest match remain if created"]}
        if self.output:
            require(self.output.parent.is_dir(), "The report parent directory must exist")
            # Exclusive creation also rejects symlinks and a concurrently
            # created report. Later atomic replacements belong to this run.
            fd = os.open(self.output, os.O_CREAT | os.O_EXCL | os.O_WRONLY | os.O_NOFOLLOW, 0o600)
            os.close(fd)
        self.save()

    def save(self):
        if not self.output:
            return
        fd, temporary = tempfile.mkstemp(prefix=".remix-two-player-", dir=self.output.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as stream:
                json.dump(self.report, stream, ensure_ascii=False, indent=2, allow_nan=False)
                stream.write("\n")
            os.replace(temporary, self.output)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def check(self, label, condition=True):
        require(condition, label)
        self.report["checks"].append(label)
        self.save()

    def permitted(self, method, path, body):
        require(method in ("GET", "POST"), "Unsupported probe method")
        require(isinstance(path, str) and len(path) <= 512 and not any(char in path for char in "?%\\\r\n"), "Invalid probe path")
        if method == "GET":
            require(body is None and (path in ("/", PREFIX + "/health") or bool(self.match_id)
                    and path in (PREFIX + f"/v1/matches/{self.match_id}/state", PREFIX + f"/v1/matches/{self.match_id}/result")),
                    "The probe may read only its fixed health, release and own match routes")
            return
        require(self.exercise_enabled, "POST requires explicit two-player exercise")
        if path == PREFIX + "/v1/challenges":
            kind = "challenge"
            require(body == self.challenge_payload(), "The challenge must be the private synthetic QA challenge")
        elif path == PREFIX + "/v1/matches":
            kind = "match"
            require(bool(self.challenge_id) and body == {"challengeId": self.challenge_id, "maxPlayers": 2},
                    "Only the newly confirmed QA challenge can create the match")
        else:
            kind = "input"
            require(bool(self.match_id) and path == PREFIX + f"/v1/matches/{self.match_id}/input"
                    and isinstance(body, dict) and set(body) == {"playerId", "sequence", "moveX", "moveY", "jump"}
                    and body["playerId"] in self.players and type(body["sequence"]) is int and body["sequence"] in (1, 2)
                    and type(body["moveX"]) is int and body["moveX"] in (-1, 1)
                    and body["moveY"] == 0 and body["jump"] is False,
                    "Only bounded synthetic commands for this run's two players may be sent")
        require(self.post_counts[kind] < (6 if kind == "input" else 1), "This POST budget is already consumed; it will not be retried")
        self.post_counts[kind] += 1

    def request(self, method, path, body=None, expected=200):
        require(len(self.report["requests"]) < MAX_REQUESTS, "The request count budget is exhausted")
        started = time.monotonic()
        require(started < self.deadline, "The probe time budget is exhausted")
        self.permitted(method, path, body)
        timeout = min(10, self.deadline - started)
        deadline = started + timeout
        entry = {"method": method, "path": path, "expectedStatus": expected, "outcome": "pending"}
        if method == "POST" and path.endswith("/input"):
            entry["input"] = {"playerId": body["playerId"], "sequence": body["sequence"]}
        self.report["requests"].append(entry)
        self.save()  # Intent exists before opening a socket, especially for POST.
        headers = {"Accept": "application/json", "Origin": ORIGIN, "Cache-Control": "no-cache",
                   "User-Agent": "OSGARD-two-player-engine-verification/1"}
        payload = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            payload = json.dumps(body, allow_nan=False).encode()
        try:
            with request_timeout(deadline - time.monotonic()):
                require(self.connection is not None, "QA transport is not configured")
                connection = self.connection("osgard.world", 443, timeout=timeout)
                try:
                    require(time.monotonic() < deadline, "The request deadline expired before dispatch")
                    connection.request(method, path, body=payload, headers=headers)
                    response = connection.getresponse()
                    entry["status"] = response.status
                    mime = response.getheader("Content-Type", "").split(";", 1)[0].strip().lower()
                    # Retain only a small media-type enum, never arbitrary
                    # header parameters or a reflected error response body.
                    entry["contentType"] = mime if mime in ("text/html", "text/plain", "application/json") else "unsupported" if mime else "missing"
                    no_store = "no-store" in {part.strip().lower() for part in response.getheader("Cache-Control", "").split(",")}
                    entry["noStore"] = no_store
                    raw = response.read(MAX_BODY + 1)
                    entry["bytes"] = len(raw)
                    require(response.status == expected, f"Unexpected HTTP status for {method} {path}: {response.status}")
                    require(len(raw) <= MAX_BODY, "The response exceeded the body budget")
                    if path == "/":
                        require(mime == "text/html", "The release marker response is not HTML")
                        markers = set(re.findall(rb"/brand/osa-transition\.js\?v=([a-f0-9]{12})", raw))
                        require(len(markers) == 1, "The release marker is missing or ambiguous")
                        value = markers.pop().decode()
                        require(not self.expected_release or value == self.expected_release, "The public release differs from the expected release")
                    else:
                        require(no_store, "The API response lacks no-store")
                        if expected == 409 and method == "POST" and path.endswith("/input") and mime == "text/plain":
                            # The observed legacy duplicate-sequence contract
                            # is 409 text/plain. The guard forwards that reply.
                            # Status, cache policy and size are still checked;
                            # its text is neither interpreted nor retained.
                            value = None
                        else:
                            require(mime == "application/json", "The API response is not JSON")
                            value = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Nonfinite JSON")), object_pairs_hook=unique_object)
                            require(isinstance(value, dict), "The API response is not an object")
                finally:
                    connection.close()
            require(time.monotonic() < min(deadline, self.deadline), "The whole-request or probe deadline expired")
            entry["outcome"] = "received"
            self.save()
            return {"status": response.status, "method": method, "path": path,
                    "contentType": mime, "body": value}
        except BaseException as error:
            entry["outcome"] = "uncertain" if method == "POST" else "failed"
            entry["errorType"] = type(error).__name__
            self.save()
            raise

    @staticmethod
    def challenge_payload():
        today = dt.datetime.now(dt.timezone.utc).date()
        return {"creatorId": "qa-remix-two-player", "title": f"OSGARD QA {today} / two-player engine",
                "mode": "speed", "seed": int(today.strftime("%Y%m%d")), "visibility": "private"}

    def state(self):
        state = contract.validate_state(self.request("GET", PREFIX + f"/v1/matches/{self.match_id}/state"), self.match_id)
        self.report.setdefault("stateObservations", []).append({key: state[key] for key in ("phase", "remainingMs", "players", "replayFrames")})
        return state

    def wait_state(self, state, phase):
        while state["phase"] != phase:
            require(state["phase"] in ("COUNTDOWN", "PLAYING"), "The own match left the expected lifecycle")
            require(time.monotonic() + 12 < self.deadline, "The match did not reach its phase within the bounded probe")
            time.sleep(1.25)
            state = self.state()
        return state

    def exercise(self):
        challenge = self.request("POST", PREFIX + "/v1/challenges", self.challenge_payload(), expected=201)["body"]
        self.challenge_id = contract.identifier(challenge.get("id"), "QA challenge ID")
        self.report["challengeId"] = self.challenge_id
        created = self.request("POST", PREFIX + "/v1/matches", {"challengeId": self.challenge_id, "maxPlayers": 2}, expected=201)["body"]
        self.match_id = contract.identifier(created.get("id"), "QA match ID")
        require(created.get("challengeId") == self.challenge_id and type(created.get("maxPlayers")) is int and created["maxPlayers"] == 2,
                "The match creation response is not bound to the fresh QA challenge and capacity")
        self.players = ["qa_two_" + secrets.token_hex(12), "qa_two_" + secrets.token_hex(12)]
        require(self.players[0] != self.players[1], "The synthetic player IDs must differ")
        self.report["match"] = {"id": self.match_id, "challengeId": self.challenge_id, "playerIds": self.players, "accessMode": "legacy-guest"}
        state = self.state()
        self.check("One fresh private QA challenge and empty guest match", state["players"] == 0 and state["replayFrames"] == 0 and state["scores"] == [])
        state = self.wait_state(state, "PLAYING")
        require(state["remainingMs"] > 0 and state["players"] == 0 and state["replayFrames"] == 0, "The new match did not become an empty playable run")
        commands = [{"playerId": player, "sequence": 1, "moveX": 1 if index == 0 else -1, "moveY": 0, "jump": False}
                    for index, player in enumerate(self.players)]
        route = PREFIX + f"/v1/matches/{self.match_id}/input"
        for command in commands:
            ack = contract.validate_input(self.request("POST", route, command), command["playerId"], 1)
            self.report.setdefault("acceptedInputs", []).append({key: ack[key] for key in ("playerId", "lastSequence", "score")})
        self.check("Both distinct guest players accepted their own sequence 1")
        # These are two deliberate negative assertions, never retries used to
        # recover an unknown write or obtain a successful acknowledgement.
        for command in commands:
            self.request("POST", route, command, expected=409)
        state = self.state()
        self.check("Duplicate sequence 1 is rejected independently for both players",
                   state["players"] == 2 and state["replayFrames"] == 2
                   and {row["playerId"] for row in state["scores"]} == set(self.players))
        terminal = self.wait_state(state, "RESULTS")
        result_route = PREFIX + f"/v1/matches/{self.match_id}/result"
        result = contract.validate_result(self.request("GET", result_route), self.match_id)
        self.check("Terminal result includes exactly the two players and two accepted frames",
                   terminal["players"] == 2 and terminal["replayFrames"] == 2 and result["replayFrames"] == 2
                   and len(result["scores"]) == 2 and {row["playerId"] for row in result["scores"]} == set(self.players)
                   and sorted((row["playerId"], row["score"]) for row in terminal["scores"]) ==
                       sorted((row["playerId"], row["score"]) for row in result["scores"]))
        for command in commands:
            self.request("POST", route, dict(command, sequence=2), expected=409)
        after = contract.validate_result(self.request("GET", result_route), self.match_id)
        contract.require_immutable(result, after)
        self.check("Late sequence 2 from both players is rejected and the terminal result is unchanged")
        retained = canonical_result(result)
        self.report["result"] = retained
        self.report["resultSha256"] = hashlib.sha256(json.dumps(retained, sort_keys=True, separators=(",", ":"), allow_nan=False).encode()).hexdigest()
        self.report["digestMeaning"] = "Canonical terminal snapshot only; not verified replay"

    def run(self):
        try:
            if self.connection is None:
                # Same reviewed transport used by the earlier owned QA. Only
                # in-memory proxy settings are read; they never enter evidence.
                self.connection = transport.connection_factory(transport.runtime_proxy())
            before = self.request("GET", "/")["body"]
            self.report["release"] = before
            self.check("Initial public release marker is recorded")
            health = self.request("GET", PREFIX + "/health")["body"]
            self.check("Public REMIX guard and legacy health are ready", health.get("status") == "ok"
                       and health.get("service") == "osgard-remix-guard" and health.get("frozenResults") is True)
            if self.exercise_enabled:
                self.exercise()
            self.check("Public release marker remained unchanged", self.request("GET", "/")["body"] == before)
            self.report["status"] = "PASS"
        except (Exception, KeyboardInterrupt) as error:
            self.report["status"] = "FAIL"
            self.report["failureType"] = type(error).__name__
            # Arbitrary exception strings can contain a proxy URL or reflected
            # server data. Even failure evidence uses only a fixed description.
            self.report["failure"] = "The bounded two-player check did not complete all required assertions. No automatic POST retry was performed."
        finally:
            self.report["finishedAt"] = dt.datetime.now(dt.timezone.utc).isoformat()
            self.report["durationSeconds"] = round(time.monotonic() - self.started, 3)
            self.report["postAttempts"] = dict(self.post_counts)
            self.save()
        return self.report["status"] == "PASS"


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exercise-two-player", action="store_true")
    parser.add_argument("--expected-release", default="")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args(argv)
    try:
        probe = Probe(args.exercise_two_player, args.expected_release, output=args.output)
    except Exception as error:
        print(json.dumps({"status": "FAIL", "phase": "configuration", "errorType": type(error).__name__, "requests": 0}))
        return 2
    passed = probe.run()
    print(json.dumps({"status": probe.report["status"], "requests": len(probe.report["requests"]),
                      "checks": len(probe.report["checks"]), "postAttempts": probe.post_counts,
                      "scope": "guest-v1-engine-compatibility-only"}))
    return 0 if passed else 1


if __name__ == "__main__":
    sys.exit(main())
