#!/usr/bin/env python3
"""Check the real REMIX HTTP contract; writes require an explicit --exercise.

Default: one read-only GET /health. With --exercise: create one private QA
challenge and match, exercise only that match, and require immutable results.
No POST is retried, no existing match is enumerated, and no replay endpoint is
invented. A passing run is not evidence of persistence across service restarts.
"""

from __future__ import annotations

import argparse
import datetime as dt
from http.client import HTTPException
import json
import math
import os
from pathlib import Path
import re
import sys
import tempfile
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener
import uuid


class ContractFailure(Exception):
    """The endpoint failed or did not satisfy the checked contract."""


def require(condition, message):
    if not condition:
        raise ContractFailure(message)


def integer(value, label, minimum=0):
    require(type(value) is int and value >= minimum, f"{label} must be an integer >= {minimum}")
    return value


def finite_number(value, label):
    valid = type(value) in (int, float)
    try:
        valid = valid and math.isfinite(value)
    except OverflowError:
        valid = False
    require(valid, f"{label} must be finite numeric data")
    return value


def identifier(value, label):
    require(isinstance(value, str) and re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9_.-]{0,127}", value),
            f"{label} must be a bounded server identifier")
    return value


def validate_base(value):
    try:
        parts = urlsplit(value)
        parts.port
    except ValueError as error:
        raise ContractFailure("--base must be a valid absolute HTTP(S) URL") from error
    require(parts.scheme in ("https", "http") and parts.hostname, "--base must be an absolute HTTP(S) URL")
    require(parts.username is None and parts.password is None and not parts.query and not parts.fragment,
            "--base cannot contain credentials, a query, or a fragment")
    return value.rstrip("/")


def reject_json_constant(value):
    raise ValueError(f"Non-finite JSON constant: {value}")


def json_object(response, expected_status=200):
    require(response["status"] == expected_status,
            f"{response['method']} {response['path']}: expected HTTP {expected_status}, got {response['status']}")
    require(response["contentType"].split(";", 1)[0].strip().lower() == "application/json",
            f"{response['path']}: expected application/json")
    require(isinstance(response["body"], dict), f"{response['path']}: expected a JSON object")
    return response["body"]


def validate_scores(value):
    require(isinstance(value, list), "scores must be an array")
    seen = set()
    for score in value:
        require(isinstance(score, dict), "Each score must be an object")
        player_id = identifier(score.get("playerId"), "score.playerId")
        require(player_id not in seen, "scores cannot contain duplicate player IDs")
        seen.add(player_id)
        finite_number(score.get("score"), "score.score")
    return value


def validate_state(response, match_id):
    value = json_object(response)
    require(value.get("id") == match_id, "State belongs to a different match")
    require(value.get("phase") in ("COUNTDOWN", "PLAYING", "RESULTS"), "Unknown match phase")
    integer(value.get("players"), "players")
    integer(value.get("remainingMs"), "remainingMs")
    integer(value.get("replayFrames"), "replayFrames")
    validate_scores(value.get("scores"))
    require(len(value["scores"]) == value["players"], "players does not match the score roster")
    if value["phase"] == "RESULTS":
        require(value["remainingMs"] == 0, "A completed match must have zero remainingMs")
    return value


def validate_input(response, player_id, sequence):
    value = json_object(response)
    require(value.get("playerId") == player_id, "Input acknowledgement belongs to a different player")
    require(type(value.get("lastSequence")) is int and value["lastSequence"] == sequence,
            "Input acknowledgement has the wrong lastSequence")
    require(isinstance(value.get("position"), list) and len(value["position"]) == 3,
            "position must contain three world coordinates")
    for coordinate in value["position"]:
        finite_number(coordinate, "position coordinate")
    finite_number(value.get("velocityY"), "velocityY")
    finite_number(value.get("score"), "score")
    require(type(value.get("onGround")) is bool, "onGround must be a boolean")
    return value


def validate_result(response, match_id):
    value = json_object(response)
    require(value.get("matchId") == match_id, "Result belongs to a different match")
    require(value.get("phase") == "RESULTS", "Result must be terminal")
    integer(value.get("replayFrames"), "result.replayFrames")
    validate_scores(value.get("scores"))
    return value


def result_signature(value):
    """Compare the actual result fields, independent of roster ordering."""
    return (value["matchId"], value["phase"], value["replayFrames"],
            tuple(sorted((row["playerId"], row["score"]) for row in value["scores"])))


def require_immutable(before, after):
    require(result_signature(before) == result_signature(after),
            "Terminal result changed after a late input: scores/replayFrames must be frozen")


class NoRedirects(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        return None


class Run:
    def __init__(self, base, exercise, output, deadline_seconds):
        self.base = validate_base(base)
        self.output = Path(output).absolute() if output else None
        if self.output:
            require(not self.output.exists() and not self.output.is_symlink(), "Refusing to overwrite the report")
            require(self.output.parent.is_dir(), "The report's parent directory must already exist")
        self.deadline = time.monotonic() + deadline_seconds
        self.client = build_opener(NoRedirects())
        self.report = {
            "schemaVersion": 1,
            "base": self.base,
            "mode": "own-private-match" if exercise else "health-read-only",
            "startedAt": dt.datetime.now(dt.timezone.utc).isoformat(),
            "status": "running",
            "checks": [],
            "requests": [],
            "limits": ["No restart persistence check", "No Unity gameplay or anti-cheat validation",
                       "No replay download API was assumed", "No POST retry or existing-user-data modification"],
        }
        self.save()

    def save(self):
        if not self.output:
            return
        # Replace our report atomically so every completed request survives a
        # later timeout. The report contains only this run's synthetic IDs.
        fd, temporary = tempfile.mkstemp(prefix=".remix-contract-", dir=self.output.parent)
        try:
            with os.fdopen(fd, "w", encoding="utf-8") as stream:
                json.dump(self.report, stream, ensure_ascii=False, indent=2, allow_nan=False)
                stream.write("\n")
            os.replace(temporary, self.output)
        finally:
            if os.path.exists(temporary):
                os.unlink(temporary)

    def check(self, name, condition, detail):
        self.report["checks"].append({"name": name, "status": "passed" if condition else "failed", "detail": detail})
        self.save()

    def request(self, path, payload=None):
        remaining = self.deadline - time.monotonic()
        require(remaining > 0, "The bounded check deadline expired")
        method = "POST" if payload is not None else "GET"
        entry = {"at": dt.datetime.now(dt.timezone.utc).isoformat(), "path": path,
                 "method": method, "request": payload}
        self.report["requests"].append(entry)
        # Record POST intent before the network call. A lost response cannot
        # safely be treated as a rejected creation/input.
        entry["outcome"] = "pending"
        self.save()
        request = Request(self.base + path,
                          data=json.dumps(payload, allow_nan=False).encode() if payload is not None else None,
                          headers={"Content-Type": "application/json", "User-Agent": "OSGARD-REMIX-contract/1"},
                          method=method)
        try:
            try:
                response = self.client.open(request, timeout=min(12, remaining))
            except HTTPError as error:
                response = error
            with response:
                entry["status"] = response.status
                entry["contentType"] = response.headers.get("Content-Type", "")
                raw = response.read(1_048_577)
            require(len(raw) <= 1_048_576, "Service response exceeded the 1 MiB limit")
            raw_text = raw.decode("utf-8", errors="replace")
            try:
                entry["body"] = json.loads(raw_text, parse_constant=reject_json_constant)
            except ValueError:
                entry["body"] = raw_text
            entry["outcome"] = "received"
        except (URLError, TimeoutError, OSError, HTTPException, ContractFailure, KeyboardInterrupt) as error:
            entry["outcome"] = "uncertain" if method == "POST" else "failed"
            entry["error"] = str(error)
            self.save()
            suffix = "; the POST was not retried and may have succeeded" if method == "POST" else ""
            raise ContractFailure(f"{method} {path} did not complete{suffix}: {error}") from error
        self.save()
        return entry

    def health(self):
        value = json_object(self.request("/health"))
        require(value.get("status") == "ok", "Health did not report status=ok")
        self.check("health", True, "GET /health returned JSON status=ok")

    def exercise(self):
        player_id = "qa-remix-" + uuid.uuid4().hex[:16]
        today = dt.datetime.now(dt.timezone.utc).date()
        self.report["playerId"] = player_id
        challenge_request = {"creatorId": player_id, "title": f"OSGARD QA {today} / contract",
                             "mode": "speed", "seed": int(today.strftime("%Y%m%d")), "visibility": "private"}
        challenge = json_object(self.request("/v1/challenges", challenge_request), 201)
        challenge_id = identifier(challenge.get("id"), "challenge.id")
        self.report["challengeId"] = challenge_id
        self.save()
        for key in ("creatorId", "title", "mode", "seed", "visibility"):
            require(type(challenge.get(key)) is type(challenge_request[key]) and challenge[key] == challenge_request[key],
                    f"Challenge did not preserve {key}; stopping before match creation")
        match = json_object(self.request("/v1/matches", {"challengeId": challenge_id, "maxPlayers": 2}), 201)
        match_id = identifier(match.get("id"), "match.id")
        self.report["matchId"] = match_id
        self.save()
        require(match.get("challengeId") == challenge_id, "Created match refers to a different challenge")
        require(type(match.get("maxPlayers")) is int and match["maxPlayers"] == 2, "Match changed maxPlayers")
        self.check("own-private-match", True, "Created one private QA challenge and its own two-player-capacity match")
        prefix = "/v1/matches/" + quote(match_id, safe="")

        def state():
            return validate_state(self.request(prefix + "/state"), match_id)

        def send(sequence):
            return self.request(prefix + "/input", {"playerId": player_id, "sequence": sequence,
                                                     "moveX": 1, "moveY": 0, "jump": False})

        current = state()
        require(current["players"] == 0 and current["replayFrames"] == 0 and current["scores"] == [],
                "A newly created match already contains player input; stopping the isolated exercise")
        if current["phase"] == "COUNTDOWN" and current["remainingMs"] >= 1200:
            before = time.monotonic()
            early = send(1)
            received_before_deadline = (time.monotonic() - before) * 1000 < current["remainingMs"] - 100
            current = state()
            # A request that crossed into PLAYING cannot establish a countdown
            # violation. Mark that observation inconclusive instead of blaming
            # the service or claiming the phase gate was verified.
            conclusive = early["status"] == 409 or received_before_deadline
            if conclusive:
                self.check("countdown-rejects-input", early["status"] == 409,
                           f"Countdown input returned HTTP {early['status']}; required HTTP 409")
                self.check("countdown-input-has-no-effects", current["players"] == 0 and current["replayFrames"] == 0,
                           "Rejected countdown input must not register a player or add replay frames")
            else:
                self.check("countdown-rejects-input", False,
                           "Inconclusive: the input response crossed the countdown boundary")
        else:
            self.check("countdown-rejects-input", False,
                       "Inconclusive: no sufficiently early countdown state was observed")

        while current["phase"] == "COUNTDOWN":
            time.sleep(min(0.5, max(0, self.deadline - time.monotonic())))
            current = state()
        require(current["phase"] == "PLAYING", "Match ended before input sequence checks could run")
        premature = self.request(prefix + "/result")
        self.check("result-unavailable-before-end", premature["status"] == 409,
                   f"GET result during PLAYING returned HTTP {premature['status']}; required HTTP 409")

        validate_input(send(2), player_id, 2)
        before_stale = state()
        stale = send(2)
        after_stale = state()
        self.check("duplicate-sequence-rejected", stale["status"] == 409,
                   f"Duplicate sequence returned HTTP {stale['status']}; required HTTP 409")
        self.check("duplicate-sequence-has-no-effects",
                   before_stale["scores"] == after_stale["scores"] and before_stale["replayFrames"] == after_stale["replayFrames"],
                   "A duplicate input must not change the score or replay frame count")
        validate_input(send(4), player_id, 4)
        stale = send(3)
        self.check("sequence-gap-accepted-and-old-input-rejected", stale["status"] == 409,
                   "Sequence 4 was acknowledged; older sequence 3 must return HTTP 409")

        current = state()
        while current["phase"] != "RESULTS":
            require(current["phase"] == "PLAYING", "Match regressed from PLAYING")
            time.sleep(min(1.0, max(0, self.deadline - time.monotonic())))
            current = state()
        result_before = validate_result(self.request(prefix + "/result"), match_id)
        require(any(score["playerId"] == player_id for score in result_before["scores"]),
                "Terminal result omitted the only admitted QA player")
        self.check("terminal-result", True, "Own match reached RESULTS with finite server score and replay frame count")
        late = send(5)
        self.check("results-reject-input", late["status"] == 409,
                   f"Late input returned HTTP {late['status']}; required HTTP 409")
        result_after = validate_result(self.request(prefix + "/result"), match_id)
        self.check("terminal-result-immutable", result_signature(result_before) == result_signature(result_after),
                   "Scores and replay frames must remain unchanged after a late input")

    def finish(self, error=None):
        if error:
            self.report["error"] = str(error)
        failed = [check for check in self.report["checks"] if check["status"] == "failed"]
        self.report["status"] = "failed" if error or failed else "passed"
        self.report["completedAt"] = dt.datetime.now(dt.timezone.utc).isoformat()
        self.save()
        return self.report


def parse_args(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base", default="https://osgard.world/api/remix",
                        help="REMIX base URL, without a trailing /health or /v1 path")
    parser.add_argument("--exercise", action="store_true",
                        help="Explicitly create one private QA challenge/match and test only that match")
    parser.add_argument("--output", help="New JSON report path; refuses an existing file")
    parser.add_argument("--deadline", type=float, default=90,
                        help="Total deadline in seconds, including requests (10–180; default 90)")
    args = parser.parse_args(argv)
    if not 10 <= args.deadline <= 180:
        parser.error("--deadline must be between 10 and 180 seconds")
    return args


def main(argv=None):
    args = parse_args(argv)
    run = None
    try:
        run = Run(args.base, args.exercise, args.output, args.deadline)
        run.health()
        if args.exercise:
            run.exercise()
        report = run.finish()
    except (ContractFailure, OSError, KeyboardInterrupt) as error:
        if run:
            report = run.finish(error or "Interrupted")
        else:
            print(f"REMIX contract check failed before any request: {error}", file=sys.stderr)
            return 1
    print(json.dumps({"status": report["status"], "mode": report["mode"],
                      "requests": len(report["requests"]), "checks": report["checks"],
                      "error": report.get("error"), "report": str(run.output) if run.output else None},
                     ensure_ascii=False, indent=2))
    return 0 if report["status"] == "passed" else 1


if __name__ == "__main__":
    raise SystemExit(main())
