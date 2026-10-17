#!/usr/bin/env python3
"""Assert an isolated Docker/Nginx REMIX boundary, never the public service."""
import json
from pathlib import Path
import sys
from urllib.error import HTTPError
from urllib.parse import urlsplit
from urllib.request import Request, urlopen


base, stage, snapshot_path = sys.argv[1:]
assert urlsplit(base).hostname == "127.0.0.1", "This fixture check only runs against a loopback CI port."
match_id = "match_existing.1"
player_id = "qa-guard-player"
input_body = {"playerId": player_id, "sequence": 1, "moveX": 1, "moveY": 0, "jump": False}
checks = 0


def request(method, path, expected, body=None):
    global checks
    data = None if body is None else json.dumps(body).encode()
    req = Request(base + path, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        response = urlopen(req, timeout=12)
    except HTTPError as error:
        response = error
    with response:
        raw = response.read()
        assert response.status == expected, (stage, method, path, response.status, raw[:500])
        assert "no-store" in response.headers.get("Cache-Control", ""), "API responses must not be cached."
    checks += 1
    return raw


def obj(method, path, expected=200, body=None):
    return json.loads(request(method, path, expected, body))


if stage == "countdown":
    health = obj("GET", "/health")
    assert health["service"] == "osgard-remix-guard" and health["frozenResults"] is True
    echo = obj("GET", "/__fixture/echo?probe=a%2Bb&mode=test")
    assert echo["path"] == "/__fixture/echo?probe=a%2Bb&mode=test", echo
    challenge = obj("POST", "/v1/challenges", 201, {"creatorId": player_id, "title": "CI fixture", "mode": "speed", "seed": 17, "visibility": "private"})
    match = obj("POST", "/v1/matches", 201, {"challengeId": challenge["id"], "maxPlayers": 2})
    assert match["id"] == match_id
    state = obj("GET", f"/v1/matches/{match_id}/state")
    assert state["phase"] == "COUNTDOWN" and state["replayFrames"] == 0
    request("POST", f"/v1/matches/{match_id}/input", 409, input_body)
    after = obj("GET", f"/v1/matches/{match_id}/state")
    assert after["replayFrames"] == 0 and after["players"] == 0
    request("GET", f"/v1/matches/{match_id}/result", 409)
elif stage == "playing":
    accepted = obj("POST", f"/v1/matches/{match_id}/input", 200, input_body)
    assert accepted["playerId"] == player_id and accepted["lastSequence"] == 1
    state = obj("GET", f"/v1/matches/{match_id}/state")
    assert state["phase"] == "PLAYING" and state["replayFrames"] == 1
elif stage in ("finalized", "restored", "offline"):
    state = request("GET", f"/v1/matches/{match_id}/state", 200).decode()
    result = request("GET", f"/v1/matches/{match_id}/result", 200).decode()
    parsed = json.loads(result)
    assert parsed["phase"] == "RESULTS" and parsed["matchId"] == match_id
    assert parsed["replayFrames"] == 3 and parsed["scores"] == [{"playerId": player_id, "score": 0.25}]
    snapshot = {"state": state, "result": result}
    if stage == "finalized":
        with Path(snapshot_path).open("x") as output:
            json.dump(snapshot, output)
    else:
        assert snapshot == json.loads(Path(snapshot_path).read_text()), "A persisted terminal response changed."
    request("POST", f"/v1/matches/{match_id}/input", 409, dict(input_body, sequence=2))
    assert request("GET", f"/v1/matches/{match_id}/result", 200).decode() == result
    if stage == "offline":
        request("GET", "/health", 503)
        request("GET", "/v1/matches/unknown.2/state", 503)
        request("POST", "/v1/challenges", 503, {"creatorId": player_id, "title": "CI outage fixture"})
else:
    raise AssertionError("Unknown CI stage")

print(f"PASS REMIX gateway {stage}: {checks} HTTP assertions; fixture-only evidence")
