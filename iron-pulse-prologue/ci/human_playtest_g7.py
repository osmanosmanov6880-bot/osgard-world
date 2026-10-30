#!/usr/bin/env python3
"""G7: source-bound offline three-act human playtest evidence intake.

This audits *claimed* human testing, NOT identities or actual player presence.
No analytics, PII, transmission, recruitment or production deployment.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
import release_vault_g5 as vault

SCHEMA = "IRON_PULSE_G7_HUMAN_PLAYTEST_V1"
ACTS = ("GRID", "HEAT", "AIR")
HEX40 = re.compile(r"[a-f0-9]{40}\Z")
HEX64 = re.compile(r"[a-f0-9]{64}\Z")
PID = re.compile(r"P-[a-f0-9]{12}\Z")
BUGID = re.compile(r"BUG-[0-9]{3,5}\Z")
METRICS = ("controls", "clarity", "engagement", "accessibility")
SESSION_FIELDS = {"id", "consent_claimed", "withdrawn", "locale", "platform",
                  "acts", "ratings", "feedback_code"}
ACT_FIELDS = {"act", "completed", "duration_seconds", "restarts"}
BUG_FIELDS = {"id", "severity", "state", "reproduced", "regression_test"}
PACKET_FIELDS = {"schema", "source_sha", "bundle_sha256", "privacy",
                 "manual_claims_only", "production_approved",
                 "participants", "bugs", "independent_review_requested"}

class TrialError(ValueError):
    pass

def require(ok, message):
    if not ok:
        raise TrialError(message)

def unique(pairs):
    output = {}
    for k, value in pairs:
        require(k not in output, "duplicate JSON property")
        output[k] = value
    return output

def read_json(path, limit=200000):
    require(path.is_file() and not path.is_symlink(), "missing or symlinked evidence JSON")
    require(path.stat().st_size <= limit, "oversized private evidence JSON")
    try:
        data = json.loads(path.read_text(encoding="utf-8"), object_pairs_hook=unique,
                          parse_constant=lambda _: (_ for _ in ()).throw(TrialError("nonfinite JSON")))
    except (UnicodeError, json.JSONDecodeError) as error:
        raise TrialError("invalid evidence JSON") from error
    require(type(data) is dict, "JSON packet must be an object")
    return data

def keys(data, allowed):
    require(type(data) is dict and set(data).issubset(allowed),
            "unknown field: private identifiers are prohibited")

def bound_int(value, low, high):
    require(type(value) is int and low <= value <= high, "integer out of range")

def ensure_source(source, bundle):
    require(type(source) is str and HEX40.fullmatch(source), "pin 40-character source SHA")
    require(type(bundle) is str and HEX64.fullmatch(bundle), "pin external 64-character bundle SHA")

def audit_packet(packet, source, bundle):
    keys(packet, PACKET_FIELDS)
    require(packet.get("schema") == SCHEMA and packet.get("source_sha") == source
            and packet.get("bundle_sha256") == bundle and
            packet.get("privacy") == "anonymous_codes_only" and
            packet.get("manual_claims_only") is True and
            packet.get("production_approved") is False,
            "invalid source/privacy/production trust boundary")
    participants = packet.get("participants")
    bugs = packet.get("bugs")
    require(type(participants) is list and 20 <= len(participants) <= 200,
            "20-200 consenting claimed participants required")
    require(type(bugs) is list and len(bugs) <= 500, "invalid bug ledger")
    require(packet.get("independent_review_requested") is True,
            "independent review must be requested, not assumed complete")
    ids, completed, languages = set(), 0, {"ru":0, "en":0}
    seconds_sum = 0
    for entry in participants:
        keys(entry, SESSION_FIELDS)
        identifier = entry.get("id")
        require(type(identifier) is str and PID.fullmatch(identifier)
                and identifier not in ids, "duplicate/invalid anonymous participant ID")
        ids.add(identifier)
        require(entry.get("consent_claimed") is True and entry.get("withdrawn") is False,
                "participant lacks claimed informed consent or has withdrawn")
        locale = entry.get("locale")
        require(locale in ("ru", "en"), "unsupported participant locale")
        languages[locale] += 1
        require(entry.get("platform") in ("windows", "android", "ios"),
                "unsupported playtest platform")
        acts = entry.get("acts")
        require(type(acts) is list and len(acts) == 3, "all three acts must be reported")
        got_acts = set()
        whole = True
        for act in acts:
            keys(act, ACT_FIELDS)
            name = act.get("act")
            require(name in ACTS and name not in got_acts, "missing/duplicate act")
            got_acts.add(name)
            require(type(act.get("completed")) is bool, "invalid completion boolean")
            bound_int(act.get("duration_seconds"), 30, 21600)
            bound_int(act.get("restarts"), 0, 100)
            seconds_sum += act["duration_seconds"]
            whole = whole and act["completed"]
        ratings = entry.get("ratings")
        keys(ratings, set(METRICS))
        require(set(ratings) == set(METRICS), "four experience ratings required")
        for metric in METRICS:
            bound_int(ratings[metric], 1, 5)
        feedback = entry.get("feedback_code")
        require(type(feedback) is str and
                re.fullmatch(r"[a-z0-9_-]{1,48}", feedback),
                "feedback must be non-identifying controlled code")
        completed += int(whole)
    require(languages["ru"] >= 5 and languages["en"] >= 5,
            "minimum five claimed sessions for each launch language")
    require(completed >= 20 and completed / len(participants) >= .8,
            "at least 20 complete campaign participants and 80% completion required")
    bug_ids, blockers = set(), []
    for issue in bugs:
        keys(issue, BUG_FIELDS)
        identifier = issue.get("id")
        require(type(identifier) is str and BUGID.fullmatch(identifier)
                and identifier not in bug_ids, "duplicate/invalid bug ID")
        bug_ids.add(identifier)
        require(issue.get("severity") in ("P0", "P1", "P2", "P3"),
                "invalid bug severity")
        require(issue.get("state") in ("open", "fixed", "verified"),
                "invalid bug state")
        require(type(issue.get("reproduced")) is bool and
                type(issue.get("regression_test")) is bool,
                "bug reproduction and regression claims must be explicit")
        if issue["severity"] in ("P0", "P1") and issue["state"] != "verified":
            blockers.append(identifier)
        if issue["state"] == "verified" and not issue["regression_test"]:
            blockers.append(identifier)
    require(not blockers, "unresolved or untested critical blockers: " + ",".join(blockers[:10]))
    return {"submitted_participant_codes":len(participants),
            "claimed_completed_three_acts":completed,
            "claimed_completion_rate":round(completed / len(participants), 3),
            "locale_counts":languages,
            "submitted_bug_count":len(bugs),
            "submitted_play_seconds":seconds_sum}

def assess(archive, source, bundle, root):
    ensure_source(source, bundle)
    require(root.is_dir() and not root.is_symlink(), "private trial directory missing")
    release = vault.verify_archive(archive, source, bundle)
    require(release["verified"] is True and release["source_sha"] == source,
            "source-bound real Godot archive mismatch")
    report = {"schema":SCHEMA, "source_sha":source, "bundle_sha256":bundle,
              "status":"RELEASE_HOLD", "production_approved":False,
              "human_participants_independently_verified":False,
              "commercial_release_allowed":False, "telemetry_uploaded":False,
              "claims_only":True, "errors":[],
              "interpretation":"Offline submitted claims; no independent human identity attestation"}
    path = root / "trials.json"
    if not path.exists():
        report["errors"].append("No 20-person independent playtest packet")
        return report
    try:
        stats = audit_packet(read_json(path), source, bundle)
        report.update(stats)
        report["status"] = "READY_FOR_INDEPENDENT_REVIEW"
    except (TrialError, OSError, TypeError, KeyError) as error:
        report["errors"].append(str(error)[:250])
    return report

def init(archive, source, bundle, root):
    ensure_source(source, bundle)
    verified = vault.verify_archive(archive, source, bundle)
    require(verified.get("verified") is True, "unverified release archive")
    require(not root.is_symlink(), "symlinked private folder")
    root.mkdir(parents=True, exist_ok=True)
    path = root / "trials.json"
    require(not path.exists() and not path.is_symlink(), "will not overwrite playtest evidence")
    empty = {"schema":SCHEMA, "source_sha":source, "bundle_sha256":bundle,
             "privacy":"anonymous_codes_only", "manual_claims_only":True,
             "production_approved":False, "participants":[], "bugs":[],
             "independent_review_requested":False}
    with path.open("x", encoding="utf-8") as f:
        f.write(json.dumps(empty, sort_keys=True, indent=2)+"\n")
    return path

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--archive", type=Path, required=True)
    p.add_argument("--source-sha", required=True)
    p.add_argument("--bundle-sha256", required=True)
    p.add_argument("--evidence-dir", type=Path, required=True)
    p.add_argument("--output", type=Path)
    p.add_argument("--init", action="store_true")
    p.add_argument("--expect-hold", action="store_true")
    args = p.parse_args()
    try:
        if args.init:
            require(not args.expect_hold and not args.output, "init is not acceptance")
            print(init(args.archive, args.source_sha, args.bundle_sha256,
                       args.evidence_dir))
            return 0
        out = assess(args.archive, args.source_sha, args.bundle_sha256,
                     args.evidence_dir)
        payload = json.dumps(out, indent=2, sort_keys=True)+"\n"
        if args.output:
            require(not args.output.is_symlink(), "symlinked result file")
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(payload, encoding="utf-8")
        print(payload, end="")
        if args.expect_hold:
            return 0 if out["status"] == "RELEASE_HOLD" else 3
        return 0 if out["status"] == "READY_FOR_INDEPENDENT_REVIEW" else 2
    except (TrialError, vault.VaultError, OSError, TypeError) as error:
        print("G7 FAIL CLOSED:", error, file=sys.stderr)
        return 4

if __name__ == "__main__":
    sys.exit(main())
