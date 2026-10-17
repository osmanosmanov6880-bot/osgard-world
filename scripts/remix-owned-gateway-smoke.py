#!/usr/bin/env python3
"""Exercise real Core authentication through isolated Docker/Nginx routing.

Only loopback CI is accepted. Credentials live in a mode-0600 temporary file
between container restarts; the shell fixture removes it and both data volumes.
No credential value is printed or included in a workflow artifact.
"""
import http.client
import json
import os
from pathlib import Path
import secrets
import sys
from urllib.parse import urlsplit


base, stage, state_path = sys.argv[1:]
parsed = urlsplit(base)
assert parsed.scheme == "http" and parsed.hostname == "127.0.0.1" and parsed.port, "Only an isolated loopback CI gateway is permitted."
assert not parsed.path.strip("/") and not parsed.query and not parsed.fragment and not parsed.username
state_file = Path(state_path)
checks = 0


def request(method, path, expected=200, body=None, token=None, key=None, origin="https://osgard.world"):
    global checks
    assert path.startswith("/api/") and "\r" not in path and "\n" not in path
    headers = {"Host": "osgard.world", "Accept": "application/json", "Origin": origin}
    if token:
        headers["Authorization"] = "Bearer " + token
    if key:
        headers["Idempotency-Key"] = key
    data = None
    if body is not None:
        headers["Content-Type"] = "application/json"
        data = json.dumps(body).encode()
    connection = http.client.HTTPConnection(parsed.hostname, parsed.port, timeout=12)
    try:
        connection.request(method, path, body=data, headers=headers)
        response = connection.getresponse()
        raw = response.read(1_048_577)
        # Do not print arbitrary response bodies, which may contain a new token.
        assert response.status == expected, (stage, method, path, response.status, expected)
        assert len(raw) <= 1_048_576
        assert "application/json" in response.getheader("Content-Type", "")
        assert "no-store" in response.getheader("Cache-Control", ""), (stage, path, "cache policy")
        checks += 1
        return raw
    finally:
        connection.close()


def obj(method, path, expected=200, body=None, token=None, key=None):
    return json.loads(request(method, path, expected, body, token, key))


def save(value):
    descriptor = os.open(state_file, os.O_WRONLY | os.O_CREAT | os.O_TRUNC | os.O_NOFOLLOW, 0o600)
    with os.fdopen(descriptor, "w") as output:
        json.dump(value, output)


if stage == "active":
    capabilities = obj("GET", "/api/remix/v2/capabilities")
    assert capabilities["authPolicyVersion"] == 1 and capabilities["creationEnabled"] is True
    assert capabilities["ownershipPolicy"] == "confirmed-durable-binding"
    assert obj("GET", "/api/remix/health")["schemaVersion"] == 1
    accounts = []
    for prefix in ("owner", "other"):
        accounts.append(obj("POST", "/api/core/auth/register", body={
            "username": "qa_remix_" + prefix + "_" + secrets.token_hex(6),
            "password": secrets.token_urlsafe(32),
        }))
    owner, other = accounts
    assert owner["user"]["id"] != other["user"]["id"]
    assert obj("GET", "/api/core/auth/me", token=owner["token"])["user"]["id"] == owner["user"]["id"]
    request("GET", "/api/core/auth/me", 403, token=owner["token"], origin="https://untrusted.invalid")
    challenge = obj("POST", "/api/remix/v1/challenges", 201, {
        "creatorId": "qa-owned-fixture", "title": "Isolated owned gateway fixture",
        "mode": "speed", "seed": 20261017, "visibility": "private",
    })
    creation = {"challengeId": challenge["id"], "maxPlayers": 2}
    operation = secrets.token_hex(16)
    match = obj("POST", "/api/remix/v2/matches", 201, creation, owner["token"], operation)
    assert match["accessMode"] == "core-owned" and match["highestSubmittedSequence"] == 0
    assert match["playerId"].startswith("corep_") and match["challengeId"] == challenge["id"]
    prefix = "/api/remix/v2/matches/" + match["id"]
    old_prefix = "/api/remix/v1/matches/" + match["id"]
    assert obj("POST", "/api/remix/v2/matches", 201, creation, owner["token"], operation) == match
    assert obj("GET", "/api/remix/v2/creation-attempts/" + operation, token=owner["token"])["match"] == match
    assert obj("GET", "/api/remix/v2/matches", token=owner["token"])["matches"] == [match]
    assert obj("GET", "/api/remix/v2/matches", token=other["token"])["matches"] == []
    for route in (prefix + "/state", old_prefix + "/state"):
        request("GET", route, 401)
        request("GET", route, 403, token=other["token"])
        assert obj("GET", route, token=owner["token"])["players"] == 0
    command = {"playerId": match["playerId"], "sequence": 1, "moveX": 1, "moveY": 0, "jump": False}
    result = obj("POST", prefix + "/input", body=command, token=owner["token"])
    assert result["playerId"] == match["playerId"] and result["lastSequence"] == 1
    request("POST", prefix + "/input", 409, command, owner["token"])
    request("POST", old_prefix + "/input", 401, dict(command, sequence=2))
    request("POST", old_prefix + "/input", 403, dict(command, sequence=2), other["token"])
    assert obj("GET", prefix, token=owner["token"])["highestSubmittedSequence"] == 1
    evidence = obj("GET", "/api/remix/__fixture/ownership-evidence")
    assert evidence == {"creates": 1, "inputs": 1, "credentialHeaders": 0}
    assert obj("GET", "/api/remix/health")["schemaVersion"] == 2
    save({"ownerToken": owner["token"], "otherToken": other["token"], "match": match, "operation": operation})
else:
    saved = json.loads(state_file.read_text())
    owner, other, match = saved["ownerToken"], saved["otherToken"], saved["match"]
    prefix = "/api/remix/v2/matches/" + match["id"]
    old_prefix = "/api/remix/v1/matches/" + match["id"]
    if stage in ("finalized", "restored", "legacy-offline"):
        state = request("GET", prefix + "/state", token=owner).decode()
        result = request("GET", prefix + "/result", token=owner).decode()
        value = json.loads(result)
        assert value["phase"] == "RESULTS" and value["replayFrames"] == 1
        assert value["scores"] == [{"playerId": match["playerId"], "score": 0.1}]
        if stage == "finalized":
            saved.update(state=state, result=result)
            save(saved)
        else:
            assert (state, result) == (saved["state"], saved["result"]), "Protected frozen bytes changed."
        for route in (prefix + "/result", old_prefix + "/result"):
            request("GET", route, 401)
            request("GET", route, 403, token=other)
            assert request("GET", route, token=owner).decode() == result
        assert obj("GET", prefix, token=owner)["highestSubmittedSequence"] == 1
        if stage == "restored":
            capabilities = obj("GET", "/api/remix/v2/capabilities")
            assert capabilities["creationEnabled"] is False and capabilities["authPolicyVersion"] == 1
            assert obj("GET", "/api/remix/health")["schemaVersion"] == 2
            request("POST", "/api/remix/v2/matches", 403, {"challengeId": match["challengeId"], "maxPlayers": 2}, owner, secrets.token_hex(16))
        if stage == "legacy-offline":
            request("GET", "/api/remix/health", 503)
    elif stage == "core-offline":
        # Legacy is running again. Only operations needing actual Core identity fail.
        assert obj("GET", "/api/remix/health")["status"] == "ok"
        for route in (prefix + "/state", prefix + "/result", old_prefix + "/result"):
            request("GET", route, 503, token=owner)
            request("GET", route, 401)
        challenge = obj("POST", "/api/remix/v1/challenges", 201, {
            "creatorId": "qa-anonymous-core-outage", "title": "Anonymous fixture remains usable",
            "mode": "speed", "seed": 20261017, "visibility": "private",
        })
        assert challenge["id"] == "ch_fixture"
    else:
        raise AssertionError("Unknown isolated ownership stage")

print(f"PASS REMIX owned gateway {stage}: {checks} real HTTP assertions; isolated Core/legacy data only")
