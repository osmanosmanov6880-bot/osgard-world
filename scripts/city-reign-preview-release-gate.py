#!/usr/bin/env python3
"""Fail closed before SSH: only the already-verified exact source may be a PREVIEW.

This new /games/city-reign-preview/ route never overwrites the R87 Omega game,
portal, Docker application, customer data or master game source. Do not rebrand
this CI check as human AAA art, physical FPS or production Omega R138 approval.
"""
from __future__ import annotations
import argparse
import json
import os
import re
import urllib.error
import urllib.request
REPO = "osmanosmanov6880-bot/osgard-world"
PR = 627
HEX = re.compile(r"[0-9a-f]{40}\Z")
REQUIRED = {
    "native-paid-civic-source", "world-native-integration",
    "real-paid-first-promise-chromium",
    "private-source-original-desktop-candidates",
    "private-original-playable-webgl",
    "actual-game-pixels (desktop-1366x768)",
    "actual-game-pixels (portrait-390x844)",
    "exact-native-godot-source", "exact-webgl-chromium"
}
BAD = {"failure", "timed_out", "cancelled", "action_required", "startup_failure"}

def validate(source: str, pr: dict, checks: dict) -> dict:
    if not HEX.fullmatch(source):
        raise ValueError("Source is not an immutable full commit SHA")
    if pr.get("number") != PR or pr.get("state") != "open":
        raise ValueError("The reviewed candidate PR is not available")
    if pr.get("head", {}).get("ref") != "feat/city-reign-aaa-world-quality-gate-20261028":
        raise ValueError("Unexpected candidate branch")
    if pr.get("head", {}).get("sha") != source:
        raise ValueError("Superseded candidate SHA: do not deploy")
    if pr.get("base", {}).get("ref") != "feat/omega-r90-aaa-reference-first-slice-20261026":
        raise ValueError("Unexpected original candidate base")
    count = checks.get("total_count", 0)
    if not isinstance(count, int) or count > 100:
        raise ValueError("Invalid source CI check count")
    runs = checks.get("check_runs")
    if not isinstance(runs, list) or count != len(runs):
        raise ValueError("Partial GitHub source CI result")
    if any(run.get("status") != "completed" for run in runs):
        raise ValueError("Native/browser checks are not finished")
    failed = [x.get("name", "") for x in runs if x.get("conclusion") in BAD]
    if failed:
        raise ValueError("Source CI failed: " + ", ".join(failed))
    successes = {str(x.get("name")) for x in runs if x.get("conclusion") == "success"}
    missing = REQUIRED - successes
    if missing:
        raise ValueError("Missing original game/native/WebGL proof: " + ", ".join(sorted(missing)))
    if len(successes) < 25:
        raise ValueError("Too few green original source jobs")
    return {"status": "PASS", "preview_only": True, "source_commit": source,
            "passing_checks": len(successes), "required_green_checks": sorted(REQUIRED),
            "failed_checks": 0, "replaces_public_omega_r87": False}

def request_json(url: str, token: str) -> dict:
    req = urllib.request.Request(url, headers={
        "Accept": "application/vnd.github+json",
        "Authorization": "Bearer " + token,
        "X-GitHub-Api-Version": "2022-11-28",
        "User-Agent": "city-reign-public-preview-exact-sha-gate"
    })
    with urllib.request.urlopen(req, timeout=25) as response:
        if response.status != 200:
            raise ValueError("GitHub read did not return 200")
        return json.loads(response.read(1_000_000))

def self_test() -> None:
    source = "a" * 40
    pr = {"number": PR, "state": "open",
          "head": {"ref": "feat/city-reign-aaa-world-quality-gate-20261028", "sha": source},
          "base": {"ref": "feat/omega-r90-aaa-reference-first-slice-20261026"}}
    runs = [{"name": name, "status": "completed", "conclusion": "success"}
            for name in sorted(REQUIRED)] + [
            {"name": "additional-" + str(i), "status": "completed", "conclusion": "success"}
            for i in range(22)]
    checks = {"total_count": len(runs), "check_runs": runs}
    assert validate(source, pr, checks)["passing_checks"] == 31
    def deny(candidate_pr, candidate_checks, candidate_source=source):
        try:
            validate(candidate_source, candidate_pr, candidate_checks)
        except ValueError:
            return
        raise AssertionError("Unsafe public preview approved")
    deny(pr, checks, "incorrect")
    deny({**pr, "head": {**pr["head"], "sha": "b"*40}}, checks)
    deny({**pr, "state": "closed"}, checks)
    deny({**pr, "base": {"ref": "master"}}, checks)
    deny(pr, {**checks, "total_count": 30})
    deny(pr, {"total_count": 0, "check_runs": []})
    for name in REQUIRED:
        invalid = json.loads(json.dumps(checks))
        next(row for row in invalid["check_runs"] if row["name"] == name)["conclusion"] = "failure"
        deny(pr, invalid)
    invalid = json.loads(json.dumps(checks))
    invalid["check_runs"][0]["status"] = "in_progress"
    deny(pr, invalid)
    print("PASS: source SHA, original PR, 9 exact checks, anti-supersession release tests")

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--source-sha", default="")
    parser.add_argument("--report", default="")
    args = parser.parse_args()
    try:
        if args.self_test:
            self_test()
            return 0
        if os.environ.get("GITHUB_REPOSITORY") != REPO:
            raise ValueError("Wrong authorized repository")
        token = os.environ.get("GH_TOKEN", "")
        if not token:
            raise ValueError("Missing read-only GitHub token")
        pr = request_json(f"https://api.github.com/repos/{REPO}/pulls/{PR}", token)
        checks = request_json(
            f"https://api.github.com/repos/{REPO}/commits/{args.source_sha}/check-runs?per_page=100",
            token)
        result = validate(args.source_sha, pr, checks)
        if args.report:
            from pathlib import Path
            Path(args.report).write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        print(json.dumps(result, indent=2))
        return 0
    except (ValueError, OSError, urllib.error.URLError, json.JSONDecodeError) as exc:
        print("CITY REIGN PREVIEW RELEASE REFUSED: " + str(exc))
        return 3

if __name__ == "__main__":
    raise SystemExit(main())
