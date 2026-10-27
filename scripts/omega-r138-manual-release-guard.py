#!/usr/bin/env python3
"""EMPIRE Omega R138: HARD manual release consent before native master/SSH.

No automatic build, push, workflow_run or actual production access is performed
here. Original repository admin must independently set the exact source SHA and
the FOUR completed human approval flags as GitHub Actions vars, then explicitly
dispatch one individual master workflow with the SAME original source SHA.
All missing or mismatched inputs are a hard failure. The self-test exercises
simulated positive and negative cases, NEVER signs off an actual game.
"""
from __future__ import annotations

import argparse
import json
import re
import sys

SHA = re.compile(r"^[0-9a-f]{40}$")
TICKET = re.compile(r"^[A-Z][A-Z0-9-]{7,79}$")
SCHEMA = "empire-omega-r138-four-human-go-signed-exact-source-v1"
FLAGS = ("art", "gameplay", "physical", "rollback")


def verify(values: dict) -> dict:
    problems = []
    role = str(values.get("role", ""))
    candidate = str(values.get("observed_sha", ""))
    requested = str(values.get("requested_sha", ""))
    admin = str(values.get("approved_sha", ""))
    ticket = str(values.get("ticket", ""))
    if role not in ("build", "deploy"):
        problems.append("unknown operation; only native build or direct SSH deploy")
    if str(values.get("event", "")) != "workflow_dispatch":
        problems.append("automatic push/workflow_run MUST NOT activate original Omega")
    if str(values.get("ref", "")) != "refs/heads/master":
        problems.append("only an explicit master dispatcher can request a release")
    for label, val in (("source", candidate), ("request", requested), ("admin", admin)):
        if not SHA.fullmatch(val):
            problems.append("invalid 40-character " + label + " SHA")
    if candidate != requested or candidate != admin:
        problems.append("original exact candidate/dispatch/admin source SHA mismatch")
    if str(values.get("enabled", "")) != "true":
        problems.append("missing independent OMEGA_RELEASE_ENABLED repository-admin GO")
    if str(values.get("confirm", "")) != "I_AUTHORIZE_OMEGA_PRODUCTION":
        problems.append("explicit typed production acknowledgment missing")
    if not TICKET.fullmatch(ticket):
        problems.append("independently recorded release ticket is missing/invalid")
    if ticket != str(values.get("admin_ticket", "")):
        problems.append("dispatch ticket differs from separately configured admin ticket")
    for flag in FLAGS:
        if str(values.get(flag, "")) != "APPROVED":
            problems.append("independent " + flag + " review is NOT APPROVED")
    return {
        "schema": SCHEMA,
        "operation": role,
        "source_sha": candidate if SHA.fullmatch(candidate) else None,
        "explicit_manual_dispatch": values.get("event") == "workflow_dispatch",
        "review_flags_count": sum(str(values.get(s, "")) == "APPROVED" for s in FLAGS),
        "production_authorized": not bool(problems),
        "errors": problems,
        "not_a_verification_of_real_user_art_or_real_gpu_evidence": True,
        "operator_must_have_independently_collected_original_four_reviews": True,
    }


def fixture() -> dict:
    sha = "a" * 40  # SIMULATED self-test, never real Git source proof.
    return {
        "role": "build",
        "event": "workflow_dispatch",
        "ref": "refs/heads/master",
        "observed_sha": sha,
        "requested_sha": sha,
        "approved_sha": sha,
        "enabled": "true",
        "confirm": "I_AUTHORIZE_OMEGA_PRODUCTION",
        "ticket": "OMEGA-REVIEW-138",
        "admin_ticket": "OMEGA-REVIEW-138",
        "art": "APPROVED",
        "gameplay": "APPROVED",
        "physical": "APPROVED",
        "rollback": "APPROVED",
    }


def self_test() -> None:
    valid = fixture()
    # Positive unit fixture verifies the guard implementation, NOT real GO.
    assert verify(valid)["production_authorized"]
    count = 0
    for name, wrong in (
        ("role", "delete"),
        ("event", "push"),
        ("event", "workflow_run"),
        ("ref", "refs/pull/500/merge"),
        ("ref", "refs/heads/feat/omega-r90"),
        ("observed_sha", "b"*40),
        ("requested_sha", "b"*40),
        ("approved_sha", "b"*40),
        ("observed_sha", "NOT_REAL_GIT_SHA"),
        ("enabled", ""),
        ("enabled", "TRUE"),
        ("confirm", ""),
        ("confirm", "yes"),
        ("ticket", ""),
        ("ticket", "bad ticket with spaces"),
        ("admin_ticket", "OMEGA-OTHER-REVIEW"),
        ("art", ""),
        ("gameplay", ""),
        ("physical", ""),
        ("rollback", ""),
        ("art", "PASS"),
    ):
        data = dict(valid)
        data[name] = wrong
        result = verify(data)
        assert not result["production_authorized"] and result["errors"], (name,wrong)
        count += 1
    for role in ("build", "deploy"):
        data = dict(valid)
        data["role"] = role
        assert verify(data)["production_authorized"]
    # CI and unconfigured repository defaults should ALWAYS block production.
    no_admin = dict(valid)
    for flag in ("enabled", "approved_sha", "admin_ticket", *FLAGS):
        no_admin[flag] = ""
    result = verify(no_admin)
    assert not result["production_authorized"] and len(result["errors"]) >= 6
    print(f"R138 PASS: {count} exact-head automatic/missing-review tamper tests; "
          "no actual user/art/physical authorization asserted")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--role", choices=("build","deploy"))
    parser.add_argument("--event", default="")
    parser.add_argument("--ref", default="")
    parser.add_argument("--observed-sha", default="")
    parser.add_argument("--requested-sha", default="")
    parser.add_argument("--approved-sha", default="")
    parser.add_argument("--enabled", default="")
    parser.add_argument("--confirm", default="")
    parser.add_argument("--ticket", default="")
    parser.add_argument("--admin-ticket", default="")
    for flag in FLAGS:
        parser.add_argument("--" + flag, default="")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return 0
    result = verify(vars(args))
    print(json.dumps(result, indent=2, sort_keys=True))
    return 0 if result["production_authorized"] else 1


if __name__ == "__main__":
    sys.exit(main())
