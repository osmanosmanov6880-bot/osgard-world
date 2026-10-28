#!/usr/bin/env python3
"""LAST FRONTIER W75 / source-bound release evidence gate.

This audits real *submitted* evidence. It does not run a playtest, sample a
physical GPU, validate a person's identity, clear a trademark or publish a
release. Generated fixtures and absent proof always result in HOLD.

Python >=3.10 standard library only. No network, external packages or actions.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
import re
import statistics
from pathlib import Path
from typing import Any

SCHEMA = "LAST_FRONTIER_W75_INDEPENDENT_RELEASE_EVIDENCE_V1"
REPORT_SCHEMA = "LAST_FRONTIER_W75_NO_FAKE_AAA_RELEASE_GATE_V1"
BASE_W74_SHA = "73ef81b54cb42831cafd9ac8fa69c5807cd8dc8d"
W74_CI_URL = (
    "https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40650956529"
)
MAX_MANIFEST_BYTES = 1024 * 1024
MAX_SINGLE_ARTIFACT_BYTES = 64 * 1024 * 1024
MIN_FIRST_TIME_SESSIONS = 12
MIN_COMPLETIONS = 9
DURATION_TARGET_SECONDS = (600, 900)
REQUIRED_DEVICE_CLASSES = ("desktop_windows", "android", "ios")
HEX_SHA = re.compile(r"^[0-9a-f]{64}$")
SOURCE_SHA = re.compile(r"^[0-9a-f]{40}$")


def blank_manifest() -> dict[str, Any]:
    return {
        "schema": SCHEMA,
        "source_sha": BASE_W74_SHA,
        "build": {
            "github_actions_url": W74_CI_URL,
            "native_godot_suites_passed": 11,
            "source_verification_file": "",
            "source_verification_sha256": "",
            "webgl_export_manifest_file": "",
            "webgl_export_manifest_sha256": "",
        },
        "first_time_playtests": [],
        "physical_device_tests": [],
        "art_direction": {
            "independent_reviewer_code": "",
            "approved_environment": False,
            "approved_animation": False,
            "approved_audio": False,
            "approved_narrative": False,
            "asset_rights_reviewed": False,
            "review_file": "",
            "review_sha256": "",
        },
        "legal": {
            "final_distinct_name": "",
            "trademark_clearance_reviewed": False,
            "assets_and_audio_license_cleared": False,
            "jurisdiction_reviewed": [],
            "review_file": "",
            "review_sha256": "",
        },
        "owner_release_consent": {
            "explicit_go": False,
            "signed_evidence_file": "",
            "signed_evidence_sha256": "",
        },
        "privacy": {
            "pseudonymous_participant_codes_only": True,
            "no_names_contacts_health_or_raw_voice_data": True,
            "collected_with_express_consent": False,
        },
        "notice": (
            "BLANK EVIDENCE: no participants, device benchmarks, artwork approvals "
            "or legal clearance have been performed by this script."
        ),
    }


def _string(value: Any) -> str:
    return value.strip() if isinstance(value, str) else ""


def _number(value: Any) -> float | None:
    if isinstance(value, bool) or not isinstance(value, (int, float)):
        return None
    n = float(value)
    return n if math.isfinite(n) else None


def _artifact(root: Path, name: Any, expected_hash: Any) -> bool:
    """Only hash bounded files below the user-selected local evidence folder.

    Never open a URL, accept absolute paths, follow symlinks or use an
    unchecked filename as a filesystem operation outside this folder.
    """
    path_string = _string(name)
    digest = _string(expected_hash).lower()
    if not path_string or not HEX_SHA.fullmatch(digest):
        return False
    rel = Path(path_string)
    if rel.is_absolute() or ".." in rel.parts or len(path_string) > 220:
        return False
    try:
        physical_root = root.resolve(strict=True)
        resolved = (physical_root / rel).resolve(strict=True)
        if not resolved.is_relative_to(physical_root):
            return False
        if not resolved.is_file() or resolved.is_symlink():
            return False
        size = resolved.stat().st_size
        if size <= 0 or size > MAX_SINGLE_ARTIFACT_BYTES:
            return False
        h = hashlib.sha256()
        with resolved.open("rb") as handle:
            for part in iter(lambda: handle.read(65536), b""):
                h.update(part)
        return h.hexdigest() == digest
    except (ValueError, OSError, RuntimeError):
        return False


def evaluate(manifest: dict[str, Any], root: Path,
             expected_sha: str = BASE_W74_SHA) -> dict[str, Any]:
    """Pure local audit. No field is filled by the program with fake results."""
    checks: dict[str, bool] = {}
    findings: list[str] = []
    stats: dict[str, Any] = {}
    checks["schema"] = manifest.get("schema") == SCHEMA
    checks["exact_source_sha"] = (
        _string(manifest.get("source_sha")) == expected_sha and
        bool(SOURCE_SHA.fullmatch(expected_sha))
    )
    build = manifest.get("build", {})
    if not isinstance(build, dict):
        build = {}
    checks["actual_accepted_ci_url"] = (
        _string(build.get("github_actions_url")) == W74_CI_URL and
        build.get("native_godot_suites_passed") == 11
    )
    checks["local_source_audit_file_hash"] = _artifact(
        root, build.get("source_verification_file"),
        build.get("source_verification_sha256"))
    checks["local_native_webgl_manifest_hash"] = _artifact(
        root, build.get("webgl_export_manifest_file"),
        build.get("webgl_export_manifest_sha256"))
    checks["build_evidence"] = (
        checks["actual_accepted_ci_url"] and
        checks["local_source_audit_file_hash"] and
        checks["local_native_webgl_manifest_hash"]
    )

    privacy = manifest.get("privacy", {})
    if not isinstance(privacy, dict):
        privacy = {}
    checks["privacy_protocol"] = all([
        privacy.get("pseudonymous_participant_codes_only") is True,
        privacy.get("no_names_contacts_health_or_raw_voice_data") is True,
        privacy.get("collected_with_express_consent") is True,
    ])

    sessions = manifest.get("first_time_playtests", [])
    if not isinstance(sessions, list) or len(sessions) > 100:
        sessions = []
        findings.append("Invalid/oversized playtest session list.")
    unique_ids: set[str] = set()
    unique_participants: set[str] = set()
    valid_sessions: list[dict[str, Any]] = []
    for record in sessions:
        if not isinstance(record, dict):
            continue
        sid = _string(record.get("session_id"))
        participant = _string(record.get("participant_code"))
        seconds = _number(record.get("duration_seconds"))
        count = _number(record.get("confusion_events"))
        declared_source = _string(record.get("source_sha"))
        if not sid or not participant or len(sid) > 80 or len(participant) > 80:
            continue
        if sid in unique_ids or participant in unique_participants:
            continue
        # No identifying contacts or obviously personally identifiable fields.
        if "@" in participant or "@" in sid or any(c.isspace() for c in participant):
            continue
        if record.get("synthetic") is not False:
            continue
        if record.get("first_time_player") is not True or (
                record.get("explicit_consent") is not True):
            continue
        if record.get("observed_by_real_human") is not True or not (
                _string(record.get("independent_observer_code"))):
            continue
        if seconds is None or seconds < 60 or seconds > 7200:
            continue
        if count is None or count < 0 or count > 100:
            continue
        if declared_source != expected_sha:
            continue
        if record.get("completed") not in (True, False):
            continue
        if not _artifact(root, record.get("local_evidence_file"),
                         record.get("local_evidence_sha256")):
            continue
        unique_ids.add(sid)
        unique_participants.add(participant)
        valid_sessions.append(record)

    completed = [s for s in valid_sessions if s["completed"] is True]
    durations = [float(s["duration_seconds"]) for s in valid_sessions]
    measured_median = statistics.median(durations) if durations else None
    average_confusion = statistics.mean(
        float(s["confusion_events"]) for s in valid_sessions
    ) if valid_sessions else None
    stats.update({
        "submitted_sessions": len(sessions),
        "evidence_checked_first_time_sessions": len(valid_sessions),
        "completed_unique_sessions": len(completed),
        "median_observed_duration_seconds": measured_median,
        "average_reported_confusion_events": average_confusion,
        "note": "Self/observer-attested external human evidence is not independently certifiable by code.",
    })
    checks["enough_unique_real_observed_sessions"] = (
        len(valid_sessions) >= MIN_FIRST_TIME_SESSIONS
    )
    checks["enough_actual_completions"] = len(completed) >= MIN_COMPLETIONS
    checks["median_duration_10_to_15_minutes"] = (
        measured_median is not None and
        DURATION_TARGET_SECONDS[0] <= measured_median <= DURATION_TARGET_SECONDS[1]
    )
    checks["observed_confusion_not_excessive"] = (
        average_confusion is not None and average_confusion <= 2.0
    )
    checks["human_playtests"] = all([
        checks["privacy_protocol"],
        checks["enough_unique_real_observed_sessions"],
        checks["enough_actual_completions"],
        checks["median_duration_10_to_15_minutes"],
        checks["observed_confusion_not_excessive"],
    ])

    devices = manifest.get("physical_device_tests", [])
    if not isinstance(devices, list) or len(devices) > 100:
        devices = []
        findings.append("Invalid/oversized physical device test list.")
    valid_devices: dict[str, list[dict[str, Any]]] = {}
    for record in devices:
        if not isinstance(record, dict) or record.get("synthetic") is not False:
            continue
        family = _string(record.get("device_class"))
        fps = _number(record.get("observed_fps_median"))
        p95 = _number(record.get("observed_p95_frame_ms"))
        samples = _number(record.get("native_render_samples"))
        if family not in REQUIRED_DEVICE_CLASSES:
            continue
        if record.get("physical_device_used") is not True or (
                record.get("human_observer_confirmed") is not True):
            continue
        if _string(record.get("source_sha")) != expected_sha:
            continue
        if not _string(record.get("device_model")) or not (
                _string(record.get("gpu_name"))):
            continue
        if fps is None or p95 is None or samples is None:
            continue
        if samples < 300 or samples > 10_000_000:
            continue
        if fps < 60.0 or p95 > 20.0 or p95 <= 0.0:
            # This is the *target*, not a fictitious actual benchmark.
            continue
        if not _artifact(root, record.get("local_evidence_file"),
                         record.get("local_evidence_sha256")):
            continue
        valid_devices.setdefault(family, []).append(record)
    for family in REQUIRED_DEVICE_CLASSES:
        checks[f"physical_{family}_60fps_target"] = bool(valid_devices.get(family))
    checks["real_hardware"] = all(
        checks[f"physical_{kind}_60fps_target"] for kind in REQUIRED_DEVICE_CLASSES
    )
    stats["evidence_checked_physical_device_classes"] = sorted(valid_devices)
    stats["physical_device_standards"] = "At least one actual Win/Android/iOS device at median >=60fps and p95 <=20ms each."

    art = manifest.get("art_direction", {})
    if not isinstance(art, dict):
        art = {}
    checks["independent_original_art_signoff"] = all([
        bool(_string(art.get("independent_reviewer_code"))),
        art.get("approved_environment") is True,
        art.get("approved_animation") is True,
        art.get("approved_audio") is True,
        art.get("approved_narrative") is True,
        art.get("asset_rights_reviewed") is True,
        _artifact(root, art.get("review_file"), art.get("review_sha256")),
    ])
    legal = manifest.get("legal", {})
    if not isinstance(legal, dict):
        legal = {}
    jurisdictions = legal.get("jurisdiction_reviewed", [])
    if not isinstance(jurisdictions, list):
        jurisdictions = []
    checks["original_name_and_licenses_cleared"] = all([
        bool(_string(legal.get("final_distinct_name"))),
        legal.get("trademark_clearance_reviewed") is True,
        legal.get("assets_and_audio_license_cleared") is True,
        bool(jurisdictions) and all(isinstance(x, str) and x for x in jurisdictions),
        _artifact(root, legal.get("review_file"), legal.get("review_sha256")),
    ])
    owner = manifest.get("owner_release_consent", {})
    if not isinstance(owner, dict):
        owner = {}
    checks["actual_explicit_owner_go_document"] = (
        owner.get("explicit_go") is True and
        _artifact(root, owner.get("signed_evidence_file"),
                  owner.get("signed_evidence_sha256"))
    )

    missing = [k for k, ok in checks.items() if not ok and k not in {
        "local_source_audit_file_hash", "local_native_webgl_manifest_hash",
        "actual_accepted_ci_url", "enough_unique_real_observed_sessions",
        "enough_actual_completions", "median_duration_10_to_15_minutes",
        "observed_confusion_not_excessive", "privacy_protocol",
        *(f"physical_{family}_60fps_target" for family in REQUIRED_DEVICE_CLASSES),
    }]
    if not checks["human_playtests"]:
        findings.append(
            "At least 12 unique, evidence-backed, explicitly consented and "
            "independently observed first-time sessions are required; no "
            "synthetic or duplicated participants are counted."
        )
    if not checks["real_hardware"]:
        findings.append(
            "No valid measured physical Windows, Android and iOS "
            "60fps/p95 frame evidence across all device classes."
        )
    if not checks["independent_original_art_signoff"]:
        findings.append("Original art/audio/narrative reviews and rights signoff missing.")
    if not checks["original_name_and_licenses_cleared"]:
        findings.append("Distinct commercial name, jurisdiction and licenses not cleared.")
    if not checks["actual_explicit_owner_go_document"]:
        findings.append("Explicit signed owner approval missing.")
    all_present = all(checks.values())
    return {
        "schema": REPORT_SCHEMA,
        "source_sha": expected_sha,
        "evidence_declared_sha": manifest.get("source_sha"),
        "machine_audit": "PASS" if checks["schema"] and checks["exact_source_sha"] else "FAIL",
        "evidence_completeness": "COMPLETE_FOR_MANUAL_REVIEW" if all_present else "INCOMPLETE",
        "next_state": "FINAL_MANUAL_REVIEW_REQUIRED" if all_present else "PRODUCTION_HOLD",
        "production_release_authorized_by_software": False,
        "master_branch_merge_authorized_by_software": False,
        "steam_or_public_domain_publish_authorized_by_software": False,
        "can_software_prove_human_identity_or_hardware_genuineness": False,
        "no_fake_human_test_results": True,
        "checks": checks,
        "missing_major_gates": missing,
        "statistics": stats,
        "findings": findings,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--template", type=Path, default=None,
                        help="Create empty evidence collection template with no fake data")
    parser.add_argument("--manifest", type=Path, default=None,
                        help="Existing observer-filled JSON evidence manifest")
    parser.add_argument("--evidence-root", type=Path, default=Path("."))
    parser.add_argument("--out", type=Path, default=None)
    parser.add_argument("--expected-sha", default=BASE_W74_SHA)
    args = parser.parse_args()
    if args.template is not None:
        args.template.parent.mkdir(parents=True, exist_ok=True)
        args.template.write_text(json.dumps(
            blank_manifest(), ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8")
        print("BLANK REAL HUMAN/DEVICE PLAYTEST TEMPLATE:", args.template)
    if args.manifest is None:
        return 0 if args.template is not None else 2
    if not SOURCE_SHA.fullmatch(args.expected_sha):
        parser.error("expected SHA must be an exact full 40-character Git commit SHA")
    if args.manifest.stat().st_size > MAX_MANIFEST_BYTES:
        parser.error("manifest too large")
    try:
        parsed = json.loads(args.manifest.read_text(encoding="utf-8"))
    except (OSError, ValueError) as exc:
        parser.error(f"invalid JSON manifest: {exc}")
    if not isinstance(parsed, dict):
        parser.error("manifest must be a JSON object")
    report = evaluate(parsed, args.evidence_root, args.expected_sha)
    pretty = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.out is not None:
        args.out.parent.mkdir(parents=True, exist_ok=True)
        args.out.write_text(pretty, encoding="utf-8")
    print(pretty)
    # Non-zero intentionally blocks automated release when evidence is absent.
    return 0 if report["next_state"] == "FINAL_MANUAL_REVIEW_REQUIRED" else 3


if __name__ == "__main__":
    raise SystemExit(main())
