#!/usr/bin/env python3
"""IRON PULSE G6: fail-closed offline physical-device evidence intake.

Validates *operator-submitted* G4 JSON reports and exact G5 release archive.
Neither JSON nor SHA-256 can attest to real hardware, user identity, or honesty.
The maximum outcome is READY_FOR_INDEPENDENT_REVIEW. Never production GO.
"""
from __future__ import annotations
import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path
import release_vault_g5 as vault

SCHEMA = "IRON_PULSE_DEVICE_EVIDENCE_G6"
G4 = "IRON_PULSE_DEVICE_LAB_G4"
ACTS = ("GRID", "HEAT", "AIR")
CLASSES = {
    "windows_integrated": ("windows", "native", "eco", 33.3),
    "windows_discrete": ("windows", "native", "hero", 16.7),
    "android_midrange": ("android", "chrome", "eco", 33.3),
    "android_entry": ("android", "chrome", "eco", 33.3),
    "iphone_safari": ("ios", "safari", "eco", 33.3),
}
# All flags are explicitly completed by a human; none are trusted attestations.
MANUAL_FLAGS = (
    "physical_device_claimed", "launch_pass", "controls_pass", "audio_pass",
    "checkpoint_recovery_pass", "three_acts_navigated", "soak_crash_free",
    "touch_or_gamepad_pass", "thermal_notes_taken", "independent_review_requested",
)
REPORT_KEYS = set("""schema format status source main_thread_proxy_not_gpu_profiler
frames_captured stored_frame_samples sample_truncated active_seconds median_ms
p95_ms p99_ms average_ms estimated_fps hitches_over_50ms stalls_over_250ms
paused_frames_excluded background_interruption_count invalid_deltas_excluded
quality_start quality_end quality_changed viewport_start viewport_end viewport_changed
locale_start auto_stopped_at_10min comparable_local_run hardware_physically_verified
independent_hardware_certification telemetry_uploaded account_ids_collected
device_fingerprint_collected privacy interpretation next_gate""".split())
HEX40 = re.compile(r"[0-9a-f]{40}\Z")
HEX64 = re.compile(r"[0-9a-f]{64}\Z")
PATH = re.compile(r"reports/[a-z0-9][a-z0-9_-]{0,100}\.json\Z")

class GateError(ValueError):
    pass

def check(ok, message):
    if not ok:
        raise GateError(message)

def unique(pairs):
    value = {}
    for k, v in pairs:
        check(k not in value, "duplicate JSON key")
        value[k] = v
    return value

def read_json(path, max_size):
    check(path.is_file() and not path.is_symlink(), "missing or symlinked JSON file")
    check(path.stat().st_size <= max_size, "oversize JSON")
    try:
        data = json.loads(path.read_text("utf-8"), object_pairs_hook=unique,
            parse_constant=lambda _: (_ for _ in ()).throw(GateError("nonfinite JSON")))
    except (UnicodeError, json.JSONDecodeError) as ex:
        raise GateError("invalid JSON") from ex
    check(type(data) is dict, "JSON root must be an object")
    return data

def fields(data, allowed):
    check(type(data) is dict, "expected JSON object")
    check(not set(data).difference(allowed), "unknown field; private identifiers forbidden")

def number(data, key, low=0):
    n = data.get(key)
    check(type(n) in (int, float) and math.isfinite(n) and n >= low,
          "invalid numeric field: " + key)
    return float(n)

def g4_validate(data, quality, p95_target):
    fields(data, REPORT_KEYS)
    check(data.get("schema") == G4 and data.get("format") == G4
        and data.get("status") == "complete"
        and data.get("source") == "actual_current_client_main_loop_delta"
        and data.get("main_thread_proxy_not_gpu_profiler") is True,
        "not an original completed G4 main-loop report")
    check(data.get("comparable_local_run") is True
        and data.get("sample_truncated") is False
        and data.get("quality_changed") is False
        and data.get("viewport_changed") is False
        and data.get("background_interruption_count") == 0,
        "G4 capture interrupted or incomparable")
    for flag in ("hardware_physically_verified", "independent_hardware_certification",
                 "telemetry_uploaded", "account_ids_collected", "device_fingerprint_collected"):
        check(data.get(flag) is False, "forged certification or privacy flag: " + flag)
    check(data.get("quality_start") == quality and data.get("quality_end") == quality,
          "wrong graphics profile")
    check(data.get("locale_start") in ("ru", "en"), "invalid locale")
    for key in ("viewport_start", "viewport_end"):
        size = data.get(key)
        check(type(size) is list and len(size) == 2
              and all(type(n) is int and 280 <= n <= 12000 for n in size),
              "invalid viewport")
    check(data["viewport_start"] == data["viewport_end"], "viewport changed")
    n = data.get("frames_captured")
    check(type(n) is int and 1800 <= n <= 18000
          and data.get("stored_frame_samples") == n,
          "G4 frame count inconsistent or ring buffer truncated")
    seconds = number(data, "active_seconds", 90)
    check(seconds <= 600.01, "G4 capture exceeds 10 minutes")
    avg = number(data, "average_ms", .01)
    p50, p95, p99 = (number(data, key, .01) for key in
                      ("median_ms", "p95_ms", "p99_ms"))
    fps = number(data, "estimated_fps", .01)
    check(p50 <= p95 <= p99 <= 2000 and p95 <= p95_target,
          "provisional main-loop p95 target failed")
    check(abs(1000.0 / avg - fps) <= .16, "FPS does not match mean")
    check(abs(seconds - n * avg / 1000) <= max(1.3, seconds * .04),
          "frame-time and duration inconsistent")
    for key in ("hitches_over_50ms", "stalls_over_250ms",
                "paused_frames_excluded", "invalid_deltas_excluded"):
        x = data.get(key)
        check(type(x) is int and 0 <= x <= 18000000, "invalid G4 counter: " + key)
    check(data["stalls_over_250ms"] <= data["hitches_over_50ms"] <= n,
          "inconsistent stall/hitch counts")
    return seconds

def check_report(root, record, seen_paths, seen_hashes, quality, target):
    fields(record, {"path", "sha256"})
    name, pinned = record.get("path"), record.get("sha256")
    check(type(name) is str and PATH.fullmatch(name), "unsafe report path")
    check(name not in seen_paths, "report reused for another independent session")
    seen_paths.add(name)
    check(type(pinned) is str and HEX64.fullmatch(pinned), "invalid report hash")
    check((root / "reports").is_dir() and not (root / "reports").is_symlink(),
          "missing or symlinked report directory")
    path = root / name
    data = read_json(path, 16384)
    actual = hashlib.sha256(path.read_bytes()).hexdigest()
    check(actual == pinned, "report SHA-256 mismatch")
    check(actual not in seen_hashes, "identical report reused")
    seen_hashes.add(actual)
    return g4_validate(data, quality, target)

def evaluate(archive, source_sha, bundle_sha, root):
    check(type(source_sha) is str and HEX40.fullmatch(source_sha)
          and type(bundle_sha) is str and HEX64.fullmatch(bundle_sha),
          "full trusted Git and release archive SHA-256 required")
    check(root.is_dir() and not root.is_symlink(), "evidence directory not found/symlinked")
    real_bundle = vault.verify_archive(archive, source_sha, bundle_sha)
    check(real_bundle.get("source_sha") == source_sha
          and real_bundle.get("verified") is True,
          "G5 archive not fully verified")
    result = {
        "schema": SCHEMA, "source_sha": source_sha, "bundle_sha256": bundle_sha,
        "status": "RELEASE_HOLD", "production_approved": False,
        "commercial_release_allowed": False, "deployment_performed": False,
        "physical_hardware_independently_verified": False,
        "claim_authentication_performed": False, "claims_only": True,
        "evaluated_device_classes": [], "validated_g4_reports": 0, "errors": [],
        "interpretation": "Manual claims only; no independent hardware attestation",
    }
    evidence = root / "evidence.json"
    if not evidence.exists():
        result["errors"] = ["No physical device evidence; CI is not a hardware test"]
        return result
    try:
        packet = read_json(evidence, 150000)
        fields(packet, {"schema", "source_sha", "bundle_sha256",
                        "privacy", "manual_claims_only", "production_approved", "devices"})
        check(packet.get("schema") == SCHEMA
              and packet.get("source_sha") == source_sha
              and packet.get("bundle_sha256") == bundle_sha
              and packet.get("privacy") == "coarse_classes_only"
              and packet.get("manual_claims_only") is True
              and packet.get("production_approved") is False,
              "source mismatch, forged approval or unsafe privacy")
        devices = packet.get("devices")
        check(type(devices) is dict and set(devices) == set(CLASSES),
              "five Windows/Android/iPhone classes required")
        paths, hashes = set(), set()
        for name, (os_name, runtime, quality, target) in CLASSES.items():
            device = devices[name]
            fields(device, {"platform", "runtime", "quality", "checks", "runs", "soak"})
            check(device.get("platform") == os_name
                  and device.get("runtime") == runtime
                  and device.get("quality") == quality, "wrong device class/profile")
            flags = device.get("checks")
            check(type(flags) is dict and set(flags) == set(MANUAL_FLAGS)
                  and all(flags[k] is True for k in MANUAL_FLAGS),
                  "manual control/soak/recovery checks incomplete")
            runs = device.get("runs")
            check(type(runs) is list and len(runs) == 6,
                  "two independent runs for each of three acts required")
            cases = set()
            for run in runs:
                fields(run, {"act", "iteration", "report"})
                case = (run.get("act"), run.get("iteration"))
                check(case[0] in ACTS and type(case[1]) is int and case[1] in (1, 2)
                      and case not in cases, "duplicate or missing act/iteration")
                cases.add(case)
                check_report(root, run.get("report"), paths, hashes, quality, target)
                result["validated_g4_reports"] += 1
            check(len(cases) == 6, "incomplete act matrix")
            soak = device.get("soak")
            check(type(soak) is list and 4 <= len(soak) <= 16,
                  "bounded 30-minute soak segments required")
            active = 0.0
            for segment in soak:
                active += check_report(root, segment, paths, hashes, quality, target)
                result["validated_g4_reports"] += 1
            check(active >= 1800, "less than 30 active soak minutes")
            result["evaluated_device_classes"].append(name)
    except (GateError, vault.VaultError, OSError, KeyError, TypeError) as ex:
        result["errors"].append(str(ex)[:200])
        return result
    result["status"] = "READY_FOR_INDEPENDENT_REVIEW"
    result["interpretation"] = ("Complete operator-claimed evidence, not independently "
                                "authenticated; commercialization remains prohibited")
    return result

def initialize(archive, source_sha, bundle_sha, root):
    check(type(source_sha) is str and HEX40.fullmatch(source_sha)
          and type(bundle_sha) is str and HEX64.fullmatch(bundle_sha),
          "trusted source and bundle SHA-256 required")
    checked = vault.verify_archive(archive, source_sha, bundle_sha)
    check(checked.get("source_sha") == source_sha and checked.get("verified") is True,
          "unverified release")
    check(not root.is_symlink(), "symlinked evidence directory")
    root.mkdir(parents=True, exist_ok=True)
    report_dir = root / "reports"
    check(not report_dir.is_symlink(), "symlinked report directory")
    report_dir.mkdir(exist_ok=True)
    data = {"schema": SCHEMA, "source_sha": source_sha,
            "bundle_sha256": bundle_sha, "privacy": "coarse_classes_only",
            "manual_claims_only": True, "production_approved": False, "devices": {}}
    for name, (os_name, runtime, quality, _) in CLASSES.items():
        data["devices"][name] = {
            "platform": os_name, "runtime": runtime, "quality": quality,
            "checks": {k: False for k in MANUAL_FLAGS},
            "runs": [{"act": a, "iteration": n, "report": {"path": "", "sha256": ""}}
                     for a in ACTS for n in (1, 2)],
            "soak": [],
        }
    output = root / "evidence.json"
    check(not output.exists() and not output.is_symlink(),
          "refusing to overwrite submitted evidence")
    with output.open("x", encoding="utf-8") as out:
        out.write(json.dumps(data, indent=2, sort_keys=True) + "\n")
    return output

def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--archive", required=True, type=Path)
    p.add_argument("--source-sha", required=True)
    p.add_argument("--bundle-sha256", required=True)
    p.add_argument("--evidence-dir", required=True, type=Path)
    p.add_argument("--output", type=Path)
    p.add_argument("--init", action="store_true")
    p.add_argument("--expect-hold", action="store_true")
    a = p.parse_args()
    try:
        if a.init:
            check(not a.output and not a.expect_hold, "--init cannot approve")
            print("G6 blank operator packet:", initialize(a.archive,
                  a.source_sha, a.bundle_sha256, a.evidence_dir))
            return 0
        outcome = evaluate(a.archive, a.source_sha, a.bundle_sha256, a.evidence_dir)
        payload = json.dumps(outcome, indent=2, sort_keys=True) + "\n"
        if a.output:
            check(not a.output.is_symlink(), "symlinked output")
            a.output.parent.mkdir(parents=True, exist_ok=True)
            a.output.write_text(payload, "utf-8")
        print(payload, end="")
        if a.expect_hold:
            return 0 if outcome["status"] == "RELEASE_HOLD" else 3
        return 0 if outcome["status"] == "READY_FOR_INDEPENDENT_REVIEW" else 2
    except (GateError, vault.VaultError, OSError, ValueError) as ex:
        print("G6 FAIL CLOSED:", ex, file=sys.stderr)
        return 4

if __name__ == "__main__":
    sys.exit(main())
