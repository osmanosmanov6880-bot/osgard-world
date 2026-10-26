#!/usr/bin/env python3
"""W56 independent physical QA report review — ALWAYS release HOLD.

Never converts untrusted manually supplied JSON into real hardware proof.
Pinned source SHA must be the release candidate's exact head, not an older
green CI's commit. Independent human review and final merged-SHA checks
remain external gates. No network access or data collection.
"""
import argparse
import json
import math
from pathlib import Path

WINDOWS_CHECKS = (
    "game_window_visible", "ru_en_text_readable", "all_six_missions_playable",
    "hero_eco_cameras", "no_major_frame_stutter", "no_unexpected_crashes",
)
PHONE_CHECKS = (
    "app_starts", "real_screen_touches_work", "ru_en_text_readable",
    "hero_eco_cameras", "no_unexpected_crashes",
)
VALID_MANUAL = {"PASS_MANUAL", "FAIL_MANUAL", "NOT_TESTED"}
HEX = set("0123456789abcdef")


def valid_sha(value):
    return isinstance(value, str) and len(value) == 40 and all(c in HEX for c in value)


def positive(value):
    return type(value) in (int, float) and math.isfinite(value) and value > 0


def source_match(report, key, sha, label):
    if report.get(key) != sha:
        raise ValueError(label + " report uses a stale or mismatched source SHA")


def checked_manual(checks, keys):
    if not isinstance(checks, dict):
        raise ValueError("No real-device manual check answers")
    for key in keys:
        if checks.get(key) not in VALID_MANUAL:
            raise ValueError("Missing/invalid manual device result: " + key)
    return all(checks[x] == "PASS_MANUAL" for x in keys)


def windows_review(report, sha):
    if report.get("schema") != "OSGARD_W56_LOCAL_WINDOWS_GPU_PREFLIGHT_V1":
        raise ValueError("Wrong Windows report schema")
    source_match(report, "build_source_sha", sha, "Windows")
    if report.get("app_sha256_valid") is not True or report.get("process_started") is not True:
        raise ValueError("Windows EXE/PCK SHA-256 or actual process startup not confirmed")
    if report.get("hardware_60fps_certified") is not False:
        raise ValueError("Windows preflight must not self-certify 60 FPS")
    gpu = report.get("video_cards")
    if not isinstance(gpu, list) or not gpu:
        raise ValueError("Windows GPU/driver observations absent")
    return {"reported": True, "manual_checklist_complete":
            checked_manual(report.get("manual_checks"), WINDOWS_CHECKS)}


def webgl_review(report, sha):
    if report.get("schema") != "OSGARD_W56_LOCAL_WEBGL_PHYSICAL_GPU_QA_V1":
        raise ValueError("Wrong WebGL telemetry schema")
    source_match(report, "source_commit", sha, "WebGL")
    if report.get("session_kind") != "real_engine_dom_read_only":
        raise ValueError("No actual Godot engine telemetry source")
    if report.get("hardware_fps_certified") is not False or report.get("physical_device_signoff") is not False:
        raise ValueError("Self-asserted hardware certification is forbidden")
    modes = report.get("modes")
    if not isinstance(modes, dict):
        raise ValueError("No HERO/ECO samples")
    enough = True
    for mode in ("hero", "eco"):
        data = modes.get(mode)
        if not isinstance(data, dict):
            enough = False
            continue
        if not (type(data.get("sample_count")) is int and data["sample_count"] >= 10
                and positive(data.get("observed_seconds")) and data["observed_seconds"] >= 20
                and positive(data.get("frames_advanced")) and data["frames_advanced"] > 10
                and positive(data.get("median_engine_fps"))
                and positive(data.get("median_total_draw_calls"))):
            enough = False
    if report.get("all_modes_sufficient") is True and not enough:
        raise ValueError("Insufficient samples despite claimed full HERO/ECO evidence")
    return {"reported": True, "sufficient_hero_and_eco": enough,
            "browser_says_gpu_not_software":
            enough and report.get("renderer_status") == "GPU_REPORTED_NOT_CERTIFIED"}


def phone_review(report, sha, system):
    if report.get("schema") != "OSGARD_W56_LOCAL_PHONE_MANUAL_REVIEW_V1":
        raise ValueError(system + " report wrong schema")
    if report.get("platform") != system:
        raise ValueError(system + " platform mismatch")
    source_match(report, "source_commit", sha, system)
    return {"reported": True, "manual_checklist_complete":
            checked_manual(report.get("manual_checks"), PHONE_CHECKS)}


def review(expected_sha, windows=None, webgl=None, android=None, ios=None):
    if not valid_sha(expected_sha):
        raise ValueError("Require an exact full lowercase 40-character source SHA")
    present = {}
    if windows is not None:
        present["windows"] = windows_review(windows, expected_sha)
    if webgl is not None:
        present["webgl"] = webgl_review(webgl, expected_sha)
    if android is not None:
        present["android"] = phone_review(android, expected_sha, "android")
    if ios is not None:
        present["ios"] = phone_review(ios, expected_sha, "ios")
    missing = [k for k in ("windows", "webgl", "android", "ios") if k not in present]
    return {
        "schema": "OSGARD_W56_FAIL_CLOSED_PHYSICAL_REVIEW_V1",
        "source_sha": expected_sha, "status": "HOLD",
        "decision": "MISSING_DEVICE_REPORTS" if missing else "HUMAN_HARDWARE_REVIEW_REQUIRED",
        "reports": present, "missing": missing,
        "independent_physical_device_certified": False,
        "cinematic_signoff": False, "production_approved": False,
        "allow_master_merge": False, "published_to_production": False,
        "limitations": "Self-reported JSON cannot certify hardware or replace manual review.",
    }


def read(path):
    if path is None:
        return None
    value = json.loads(path.read_text(encoding="utf-8-sig"))
    if not isinstance(value, dict):
        raise ValueError("Report must be a JSON object")
    return value


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--expected-sha", required=True)
    for name in ("windows", "webgl", "android", "ios"):
        p.add_argument("--" + name, type=Path)
    p.add_argument("--output", required=True, type=Path)
    a = p.parse_args()
    try:
        result = review(a.expected_sha, read(a.windows), read(a.webgl),
                        read(a.android), read(a.ios))
    except (ValueError, KeyError, OSError, json.JSONDecodeError) as exc:
        result = {
            "schema": "OSGARD_W56_FAIL_CLOSED_PHYSICAL_REVIEW_V1",
            "source_sha": a.expected_sha, "status": "FAIL",
            "decision": "INVALID_DEVICE_EVIDENCE", "error": str(exc),
            "allow_master_merge": False, "published_to_production": False,
        }
    a.output.parent.mkdir(parents=True, exist_ok=True)
    a.output.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(result["status"] + ": " + result["decision"])
    if result["status"] == "FAIL":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
