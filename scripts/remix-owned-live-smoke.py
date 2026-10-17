#!/usr/bin/env python3
"""Bounded verification of the published Core-owned REMIX path.

Default is read-only. --exercise-owned creates two clearly named QA accounts and
one QA challenge/match; only that match is exercised. Credentials stay in memory.
Known sessions receive at most one logout attempt, including in finally; an
uncertain authentication or logout prevents a successful cleanup report. No POST
is retried, and evidence contains no authentication bodies or credentials.
QA accounts and the owned match remain as isolated test records on the server.
This Linux main-thread CLI uses a 100-second probe deadline and allows up to five
additional seconds for each pending known-session logout.
"""
from __future__ import annotations

import argparse
from contextlib import contextmanager
import datetime as dt
import hashlib
import http.client
import json
import math
from pathlib import Path
import re
import secrets
import signal
import sys
import threading
import time


class ProbeFailure(Exception):
    pass


def require(value, message):
    if not value:
        raise ProbeFailure(message)


def valid_id(value):
    return isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", value)


@contextmanager
def request_timeout(seconds):
    """Interrupt the entire synchronous operation, including DNS, TLS and reads."""
    require(hasattr(signal, "setitimer") and hasattr(signal, "SIGALRM")
            and threading.current_thread() is threading.main_thread(),
            "The live probe requires POSIX interval timers in the main thread")
    require(seconds > 0, "The request time budget is exhausted")

    def expired(signum, frame):
        raise ProbeFailure("The request exceeded its whole-request time budget")

    previous_handler = signal.getsignal(signal.SIGALRM)
    previous_timer = signal.getitimer(signal.ITIMER_REAL)
    started = time.monotonic()
    try:
        signal.signal(signal.SIGALRM, expired)
        signal.setitimer(signal.ITIMER_REAL, min(seconds, previous_timer[0]) if previous_timer[0] else seconds)
        yield
    finally:
        signal.setitimer(signal.ITIMER_REAL, 0)
        signal.signal(signal.SIGALRM, previous_handler)
        if previous_timer[0]:
            # Restore a caller's timer without granting it the time spent here.
            remaining = max(0.000001, previous_timer[0] - (time.monotonic() - started))
            signal.setitimer(signal.ITIMER_REAL, remaining, previous_timer[1])


class Probe:
    def __init__(self, exercise, expected_release):
        self.started = time.monotonic()
        self.deadline = self.started + 100
        self.tokens = []
        self.closed_tokens = set()
        self.logout_attempted = set()
        self.expected_release = expected_release
        self.report = {
            "schemaVersion": 1, "origin": "https://osgard.world", "status": "running",
            "mode": "two-qa-accounts-one-owned-match" if exercise else "read-only",
            "startedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
            "requests": [], "checks": [],
            "authOutcomeUncertain": False,
            "limits": ["No Unity gameplay or replay validation", "No restart or active-engine recovery check",
                       "No POST retry or access to existing users' data",
                       "A lost authentication response may leave an unknown session that cannot be logged out",
                       "Two QA accounts and their one match remain; no credentials are retained in evidence"],
        }

    def request(self, method, path, *, expected=200, body=None, token=None, key=None, cleanup=False):
        require(path.startswith("/") and "\r" not in path and "\n" not in path, "Invalid probe path")
        require(len(self.report["requests"]) < (96 if cleanup else 88), "The probe request budget is exhausted")
        started = time.monotonic()
        remaining = self.deadline - started
        require(cleanup or remaining > 0, "The probe time budget is exhausted")
        timeout = 5 if cleanup else min(12, remaining)
        deadline = started + timeout
        if token:
            require(path in ("/api/core/auth/me", "/api/core/auth/logout") or path.startswith(("/api/remix/v2/", "/api/remix/v1/matches/")), "Credential destination rejected")
        headers = {"Accept": "application/json", "Origin": "https://osgard.world", "Cache-Control": "no-cache", "User-Agent": "OSGARD-owned-release-verification/1"}
        if token:
            headers["Authorization"] = "Bearer " + token
        if key:
            headers["Idempotency-Key"] = key
        data = None
        if body is not None:
            headers["Content-Type"] = "application/json"
            data = json.dumps(body, allow_nan=False).encode()
        # Journal the attempt before any dispatch, never its credentials or body.
        # A lost POST response must remain visible as an uncertain write.
        entry = {"method": method, "path": path, "outcome": "pending"}
        self.report["requests"].append(entry)
        if method == "POST" and path in ("/api/core/auth/register", "/api/core/auth/login"):
            # Only account() can clear this, after retaining a validated token.
            self.report["authOutcomeUncertain"] = True
        try:
            with request_timeout(deadline - time.monotonic()):
                connection = http.client.HTTPSConnection("osgard.world", timeout=timeout)
                try:
                    require(time.monotonic() < deadline, "The request time budget is exhausted")
                    connection.request(method, path, body=data, headers=headers)
                    response = connection.getresponse()
                    entry["status"] = response.status
                    raw = response.read(1_048_577)
                    entry["bytes"] = len(raw)
                    accepted = (expected,) if isinstance(expected, int) else expected
                    require(response.status in accepted, f"{method} {path}: unexpected HTTP {response.status}")
                    require(len(raw) <= 1_048_576, "The response exceeded the body budget")
                    if path == "/":
                        require("text/html" in response.getheader("Content-Type", ""), "The release marker is not HTML")
                        markers = set(re.findall(rb"/brand/osa-transition\.js\?v=([a-f0-9]{12})", raw))
                        require(len(markers) == 1, "The public release marker is missing or ambiguous")
                        value = markers.pop().decode()
                        require(not self.expected_release or value == self.expected_release, "The public release differs from the expected commit")
                    else:
                        require("application/json" in response.getheader("Content-Type", ""), f"{path}: response is not JSON")
                        require("no-store" in response.getheader("Cache-Control", ""), f"{path}: no-store is missing")
                        value = json.loads(raw, parse_constant=lambda _: (_ for _ in ()).throw(ValueError("Nonfinite JSON")))
                        require(isinstance(value, dict), f"{path}: response is not an object")
                finally:
                    connection.close()
            # The monotonic check also covers fake-clock tests and work that
            # completes just as the alarm is cancelled. Cleanup has its own cap.
            require(time.monotonic() < deadline, "The request time budget is exhausted")
            require(cleanup or time.monotonic() < self.deadline, "The probe time budget is exhausted")
            entry["outcome"] = "received"
            return value
        except BaseException as error:
            entry["outcome"] = "uncertain" if method == "POST" else "failed"
            entry["errorType"] = type(error).__name__
            raise

    def check(self, label, condition=True):
        require(condition, label)
        self.report["checks"].append(label)

    def logout(self, token):
        if token in self.logout_attempted:
            return
        self.logout_attempted.add(token)
        self.request("POST", "/api/core/auth/logout", expected=(200, 401), token=token, body={}, cleanup=True)
        self.closed_tokens.add(token)

    def account(self, suffix):
        credentials = {"username": "qa_owned_" + suffix + "_" + secrets.token_hex(8), "password": secrets.token_urlsafe(32)}
        registered = self.request("POST", "/api/core/auth/register", body=credentials)
        token = registered.get("token")
        require(isinstance(token, str) and re.fullmatch(r"[A-Za-z0-9_-]{40,100}", token), "Core registration returned no valid session")
        self.tokens.append(token)
        self.report["authOutcomeUncertain"] = False
        self.logout(token)
        logged = self.request("POST", "/api/core/auth/login", body=credentials)
        token = logged.get("token")
        require(isinstance(token, str) and re.fullmatch(r"[A-Za-z0-9_-]{40,100}", token), "Core login returned no valid session")
        self.tokens.append(token)
        self.report["authOutcomeUncertain"] = False
        user = logged.get("user", {}).get("id")
        require(valid_id(user), "Core login returned no valid account")
        require(self.request("GET", "/api/core/auth/me", token=token).get("user", {}).get("id") == user, "Core session identity mismatch")
        return token, user

    def exercise(self):
        owner, owner_id = self.account("owner")
        other, other_id = self.account("other")
        self.check("Two independently registered and logged-in QA accounts", owner_id != other_id)
        challenge = self.request("POST", "/api/remix/v1/challenges", expected=201, body={
            "creatorId": "qa-owned-release", "title": "Owned release verification", "mode": "speed",
            "seed": int(dt.datetime.now(dt.timezone.utc).strftime("%Y%m%d")), "visibility": "private",
        })
        require(valid_id(challenge.get("id")), "The QA challenge ID is invalid")
        key = secrets.token_hex(16)
        match = self.request("POST", "/api/remix/v2/matches", expected=201, token=owner, key=key,
                             body={"challengeId": challenge["id"], "maxPlayers": 2})
        require(valid_id(match.get("id")) and valid_id(match.get("playerId")), "The owned match/player IDs are invalid")
        self.check("One durably bound Core-owned match with a server-assigned player", match.get("accessMode") == "core-owned" and match.get("highestSubmittedSequence") == 0 and match.get("challengeId") == challenge["id"])
        # Only the public DTO of our own test match is retained.
        self.report["match"] = {field: match[field] for field in ("id", "challengeId", "playerId", "accessMode")}
        prefix = "/api/remix/v2/matches/" + match["id"]
        legacy = "/api/remix/v1/matches/" + match["id"]
        attempt = self.request("GET", "/api/remix/v2/creation-attempts/" + key, token=owner)
        self.check("Creation attempt resolves by GET without repeating POST", attempt.get("status") == "ready" and attempt.get("match", {}).get("id") == match["id"])
        for token, present in ((owner, True), (other, False)):
            rows = self.request("GET", "/api/remix/v2/matches", token=token).get("matches")
            require(isinstance(rows, list) and len(rows) <= 50, "Owned history is not bounded")
            self.check("Owner history includes QA match" if present else "Other account history excludes QA match", any(row.get("id") == match["id"] for row in rows) is present)
        for route in (prefix + "/state", legacy + "/state"):
            self.request("GET", route, expected=401)
            self.request("GET", route, expected=403, token=other)
        self.check("Missing sessions and another account cannot read either match alias")
        state = self.request("GET", prefix + "/state", token=owner)
        while state.get("phase") == "COUNTDOWN":
            require(time.monotonic() < self.deadline - 20, "Countdown exceeded the probe budget")
            time.sleep(1.5)
            state = self.request("GET", prefix + "/state", token=owner)
        require(state.get("phase") == "PLAYING" and state.get("players") == 0, "The fresh match did not become an empty playable run")
        command = {"sequence": 1, "moveX": 1, "moveY": 0, "jump": False}
        self.request("POST", legacy + "/input", expected=401, body=command)
        self.request("POST", legacy + "/input", expected=403, body=command, token=other)
        accepted = self.request("POST", prefix + "/input", body=command, token=owner)
        self.check("Only owner input is accepted for the server-assigned player", accepted.get("playerId") == match["playerId"] and accepted.get("lastSequence") == 1)
        self.request("POST", prefix + "/input", expected=409, body=command, token=owner)
        self.check("Consumed input sequence is durable and duplicate input is rejected", self.request("GET", prefix, token=owner).get("highestSubmittedSequence") == 1)
        state = self.request("GET", prefix + "/state", token=owner)
        while state.get("phase") in ("COUNTDOWN", "PLAYING"):
            require(time.monotonic() < self.deadline - 10, "Match completion exceeded the probe budget")
            time.sleep(1.5)
            state = self.request("GET", prefix + "/state", token=owner)
        require(state.get("phase") == "RESULTS", "The match did not reach results")
        result = self.request("GET", prefix + "/result", token=owner)
        require(result.get("matchId") == match["id"] and result.get("phase") == "RESULTS" and result.get("replayFrames") == 1, "The result is not the one-command QA result")
        require(isinstance(result.get("scores"), list) and len(result["scores"]) == 1 and result["scores"][0].get("playerId") == match["playerId"], "The result roster differs from the owned player")
        for route in (prefix + "/result", legacy + "/result"):
            self.request("GET", route, expected=401)
            self.request("GET", route, expected=403, token=other)
            require(self.request("GET", route, token=owner) == result, "Result aliases disagree")
        self.check("Completed results remain protected through both aliases")
        self.request("POST", legacy + "/input", expected=409, body=dict(command, sequence=2), token=owner)
        self.check("A late owner input cannot change the completed result", self.request("GET", prefix + "/result", token=owner) == result)
        score = result["scores"][0].get("score")
        require(type(score) in (float, int) and math.isfinite(score), "The QA score is invalid")
        retained = {"matchId": match["id"], "phase": "RESULTS", "replayFrames": 1, "scores": [{"playerId": match["playerId"], "score": score}]}
        self.report["result"] = retained
        self.report["resultSha256"] = hashlib.sha256(json.dumps(retained, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
        self.logout(owner)
        self.request("GET", prefix + "/result", expected=401, token=owner)
        self.check("Logout revokes access to the frozen result immediately")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--exercise-owned", action="store_true")
    parser.add_argument("--expected-release", default="")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    require(not args.expected_release or re.fullmatch(r"[a-f0-9]{12}", args.expected_release), "Expected release must be a 12-character commit marker")
    if args.output:
        require(not args.output.exists() and not args.output.is_symlink() and args.output.parent.is_dir(), "Refusing to overwrite probe evidence")
    probe = Probe(args.exercise_owned, args.expected_release)
    try:
        before = probe.request("GET", "/")
        capabilities = probe.request("GET", "/api/remix/v2/capabilities")
        probe.report["release"] = before
        probe.report["capabilities"] = {field: capabilities.get(field) for field in ("authPolicyVersion", "provider", "ownershipPolicy", "creationEnabled", "legacyMatches", "activeMatchRecovery", "replayVerification")}
        probe.check("Published ownership policy is Core confirmed-durable-binding", capabilities.get("authPolicyVersion") == 1 and capabilities.get("provider") == "core" and capabilities.get("ownershipPolicy") == "confirmed-durable-binding")
        if args.exercise_owned:
            require(capabilities.get("creationEnabled") is True, "Owned creation is not enabled; no QA account was created")
            probe.exercise()
        probe.check("The public release remained unchanged during verification", probe.request("GET", "/") == before)
        probe.report["status"] = "PASS"
    except Exception as error:
        probe.report["status"] = "FAIL"
        probe.report["failure"] = str(error) if isinstance(error, ProbeFailure) else "Transport or parsing failure: " + type(error).__name__
    finally:
        for token in probe.tokens:
            try:
                probe.logout(token)
            except Exception:
                pass  # Never repeat a logout whose first response was uncertain.
        failures = len(set(probe.tokens) - probe.closed_tokens)
        probe.report["allQaSessionsLoggedOut"] = failures == 0 and not probe.report["authOutcomeUncertain"]
        if not probe.report["allQaSessionsLoggedOut"]:
            probe.report["status"] = "FAIL"
        if failures:
            probe.report["cleanupFailureCount"] = failures
        probe.report["finishedAt"] = dt.datetime.now(dt.timezone.utc).isoformat()
        probe.report["durationSeconds"] = round(time.monotonic() - probe.started, 3)
        # Evidence consists solely of deliberate public fields above, never locals.
        evidence = json.dumps(probe.report, ensure_ascii=False, indent=2) + "\n"
        require(not any(token in evidence for token in probe.tokens), "Credential detected in evidence")
        if args.output:
            with args.output.open("x") as output:
                output.write(evidence)
        print(json.dumps({"status": probe.report["status"], "requests": len(probe.report["requests"]), "checks": len(probe.report["checks"]), "allQaSessionsLoggedOut": probe.report["allQaSessionsLoggedOut"], "authOutcomeUncertain": probe.report["authOutcomeUncertain"]}))
    return 0 if probe.report["status"] == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
