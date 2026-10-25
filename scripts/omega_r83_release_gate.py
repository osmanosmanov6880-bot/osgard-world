#!/usr/bin/env python3
"""EMPIRE Ω R83: final source-pinned field-evidence review queue.

Verifies original evidence through R50 (seven public digests + two genuine
Chromium tests), R73/R75 (forty human-reported mission attempts, PNG integrity,
original video, reload checkpoints), R80 (original device telemetry/video),
twenty separate consented human sessions, and original visual/licence review.

No automated result ever grants a production release or AAA-quality approval.
Even complete machine evidence needs independent human observation and signoff.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import importlib.util
import json
import math
import re
import sys
from pathlib import Path

import omega_r73_field_qa as r73
import omega_r80_hardware_evidence as r80

SCHEMA = "empire-omega-r83-final-evidence-v1"
SOURCE_RE = re.compile(r"^[0-9a-f]{40}$")
SHA_RE = re.compile(r"^[0-9a-f]{64}$")
ROOT = Path(__file__).resolve().parent
REQUIRED_CHECKS = (
    "source_bound_public_webgl",
    "forty_human_mission_evidence",
    "physical_android_original_telemetry",
    "physical_ios_original_telemetry",
    "twenty_consented_player_sessions",
    "original_art_frames_and_licences",
)
DISPLAY = {
    "source_bound_public_webgl": "Original seven public SHA-256 and zero-flaky desktop/touch Godot WebGL",
    "forty_human_mission_evidence": "Human-reported forty missions, original recording, forty-three distinct PNGs and save reloads",
    "physical_android_original_telemetry": "Independent physical Android R36 Godot frame JSON plus recording",
    "physical_ios_original_telemetry": "Independent physical iPhone R36 Godot frame JSON plus recording",
    "twenty_consented_player_sessions": "Twenty distinct consented human user sessions with evidence",
    "original_art_frames_and_licences": "Original game frames and source/licence inventory ready for independent art review",
}


class FieldError(ValueError):
    pass


def insist(value: bool, reason: str) -> None:
    if not value:
        raise FieldError(reason)


def load_object(path: Path) -> dict:
    insist(path.is_file() and not path.is_symlink() and path.stat().st_size <= 1024 * 1024,
           "missing, linked or oversized JSON: " + path.name)
    obj = json.loads(path.read_text(encoding="utf-8"))
    insist(isinstance(obj, dict), "JSON object required: " + path.name)
    return obj


def release_source(manifest: dict) -> str:
    source = manifest.get("source_commit")
    insist(isinstance(source, str) and SOURCE_RE.fullmatch(source) is not None,
           "invalid original published game source SHA")
    insist(manifest.get("engine") == "Godot 4.4.1" and
           manifest.get("source_path") == "godot/empire-omega" and
           manifest.get("artifact_kind") == "native-Godot-HTML5-export",
           "not an authentic EMPIRE Omega Godot release manifest")
    insist(isinstance(manifest.get("files"), dict) and
           len(manifest["files"]) == 7, "original seven game files missing")
    return source


def read_r50_module():
    path = ROOT / "omega-r50-release-gate.py"
    spec = importlib.util.spec_from_file_location("omega_r83_r50_contract", path)
    insist(spec is not None and spec.loader is not None, "R50 release verifier unavailable")
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module



# A real Playwright JSON reporter contains the genuine source test traces and
# attachments. R84 desktop+touch produced ~3.8 MiB, exceeding the 1-MiB cap
# intended for simple private field forms. Keep THAT 1-MiB cap unchanged;
# only the original Chromium reporter gets a bounded, separately validated cap.
MAX_ORIGINAL_PLAYWRIGHT_JSON_BYTES = 16 * 1024 * 1024


def load_original_browser_report(path: Path) -> dict:
    insist(path.is_file() and not path.is_symlink(),
           "missing or linked original Playwright JSON report")
    size = path.stat().st_size
    insist(100 <= size <= MAX_ORIGINAL_PLAYWRIGHT_JSON_BYTES,
           "empty or oversized original Playwright JSON report")
    report = json.loads(path.read_text(encoding="utf-8"))
    insist(isinstance(report, dict) and isinstance(report.get("stats"), dict)
           and isinstance(report.get("suites"), list),
           "original Playwright reporter requires stats and test suites")
    # These are ONLY framing requirements: R50.validate_browser below must
    # still verify all genuine desktop and touch results and reject flaky runs.
    return report


def source_bound_public_webgl(manifest: dict, assets: Path,
                              live_path: Path, browser_path: Path) -> None:
    r50 = read_r50_module()
    # Verify ALL original packaged bytes, not just a supplied JSON success flag.
    r50.validate_manifest(manifest, assets, strict_bytes=True)
    r50.validate_live(load_object(live_path), manifest)
    browser = load_original_browser_report(browser_path)
    project_names = r50.validate_browser(browser)
    insist(set(project_names) == {"desktop-chromium", "touch-phone-chromium"},
           "missing real desktop and touch projects")
    insist(browser.get("stats", {}).get("flaky", 0) == 0,
           "a recovered flaky browser attempt cannot certify stable release")


def source_bound_campaign(manifest: dict, game: Path, campaign: Path,
                          evidence_dir: Path) -> None:
    sessions = load_object(campaign)
    missions = r73.real_missions(game)
    verdict = r73.verify_campaign(sessions, manifest, missions, evidence_dir)
    insist(verdict.get("status") == "EVIDENCE_READY_FOR_INDEPENDENT_REVIEW" and
           verdict.get("production_go") is False,
           "original forty-mission evidence cannot be certified automatically")


def session_datetime(value: object) -> None:
    insist(isinstance(value, str), "session UTC timestamp missing")
    try:
        parsed = dt.datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError as exc:
        raise FieldError("session UTC timestamp invalid") from exc
    insist(parsed.tzinfo is not None and parsed.utcoffset() == dt.timedelta(0),
           "session capture must be UTC")


def human_sessions(report_path: Path, source: str) -> None:
    report = load_object(report_path)
    insist(report.get("schema") == "empire-omega-r83-20-sessions-v1" and
           report.get("source_commit") == source,
           "twenty human sessions refer to another game or schema")
    sessions = report.get("sessions")
    insist(isinstance(sessions, list) and len(sessions) == 20,
           "exactly twenty distinct real user sessions required")
    ids: set[str] = set()
    participant_codes: set[str] = set()
    recordings: set[str] = set()
    for index, item in enumerate(sessions, start=1):
        insist(isinstance(item, dict), "invalid session record " + str(index))
        sid = item.get("session_id")
        participant = item.get("participant_code")
        observer = item.get("observer")
        insist(all(isinstance(x, str) and 3 <= len(x.strip()) <= 128
                   for x in (sid, participant, observer)),
               "incomplete session, anonymized tester or observer")
        insist(sid not in ids and participant not in participant_codes,
               "duplicated session or player; need twenty independent people")
        ids.add(sid)
        participant_codes.add(participant)
        insist(item.get("recording_consent") is True and
               item.get("actually_played") is True,
               "unconsented or unplayed session does not qualify")
        session_datetime(item.get("captured_utc"))
        seconds = item.get("duration_s")
        insist(type(seconds) in (int, float) and math.isfinite(seconds) and
               60 <= seconds <= 14400,
               "missing or impossible play time")
        insist(item.get("outcome") in ("completed", "failed", "abandoned"),
               "missing honest session outcome")
        notes = item.get("feedback")
        insist(isinstance(notes, str) and len(notes.strip()) >= 10,
               "session requires actual qualitative feedback")
        name = item.get("recording_file")
        digest = item.get("recording_sha256")
        insist(isinstance(name, str) and name.lower().endswith((".mp4", ".webm")),
               "original MP4/WebM gameplay recording required")
        kind = ".mp4" if name.lower().endswith(".mp4") else ".webm"
        movie = r80.original_file(report_path.parent, name, digest, kind, 1025,
                                  r80.MAX_RECORDING_BYTES)
        with movie.open("rb") as file:
            signature = file.read(16)
        insist((kind == ".webm" and signature[:4] == bytes.fromhex("1a45dfa3")) or
               (kind == ".mp4" and signature[4:8] == b"ftyp"),
               "session video is not an original WebM/MP4 container")
        insist(digest not in recordings, "reused recording for distinct players")
        recordings.add(digest)


def art_and_licences(report_path: Path, source: str) -> None:
    report = load_object(report_path)
    insist(report.get("schema") == "empire-omega-r83-original-art-v1" and
           report.get("source_commit") == source,
           "original art reviewer/scene source mismatch")
    reviewer = report.get("reviewer")
    insist(isinstance(reviewer, str) and len(reviewer.strip()) >= 3,
           "independent art reviewer required")
    insist(report.get("real_godot_frames_reviewed") is True,
           "AI mockups or presentation slides cannot certify actual Godot art")
    licence_items = report.get("assets")
    insist(isinstance(licence_items, list) and len(licence_items) > 0,
           "original 3D asset provenance and licence inventory missing")
    names = set()
    for item in licence_items:
        insist(isinstance(item, dict) and
               all(isinstance(item.get(k), str) and len(item[k].strip()) >= 3
                   for k in ("asset_id", "origin", "licence", "review_notes")),
               "asset source, licence or review note missing")
        insist(item["asset_id"] not in names, "duplicated art asset in licence report")
        names.add(item["asset_id"])
    images = report.get("screenshots")
    insist(isinstance(images, list) and len(images) >= 4,
           "original game frame set for four viewports missing")
    sizes = set()
    digests = set()
    for item in images:
        insist(isinstance(item, dict), "invalid original game frame evidence")
        label = item.get("viewport")
        insist(label in ("1366x768", "390x844", "320x568", "844x390"),
               "unknown original game viewport")
        insist(label not in sizes, "duplicate original Godot viewport")
        sizes.add(label)
        file = item.get("file")
        digest = item.get("sha256")
        frame = r80.original_file(report_path.parent, file, digest, ".png", 100,
                                  64 * 1024 * 1024)
        r73.validate_decodable_png(frame)
        with frame.open("rb") as stream:
            header = stream.read(24)
        width = int.from_bytes(header[16:20], "big")
        height = int.from_bytes(header[20:24], "big")
        target_w, target_h = (int(x) for x in label.split("x"))
        if label == "1366x768":
            # Real CDP evidence may downsample original 1366 CSS pixels to
            # 960x540, but the picture must retain real scene proportions.
            insist(850 <= width <= target_w and 475 <= height <= target_h and
                   abs(width / height - target_w / target_h) < 0.025,
                   "desktop authentic CDP evidence dimensions do not match")
        else:
            insist(width == target_w and height == target_h,
                   "mobile original Godot viewport screenshot dimensions mismatch")
        insist(digest not in digests, "same visual frame falsely assigned multiple viewports")
        digests.add(digest)
    insist(sizes == {"1366x768", "390x844", "320x568", "844x390"},
           "all four original Godot viewport frames required")
    # These claims are still self-attested, NOT machine-verified AAA art quality.


def summarise(source: str, checks: dict[str, bool], problems: list[str]) -> dict:
    insist(SOURCE_RE.fullmatch(source) is not None, "invalid source SHA")
    insist(set(checks) == set(REQUIRED_CHECKS), "missing or extra final release evidence checks")
    incomplete = [name for name in REQUIRED_CHECKS if checks[name] is not True]
    return {
        "schema": SCHEMA,
        "source_commit": source,
        "status": "READY_FOR_INDEPENDENT_HUMAN_SIGNOFF" if not incomplete else "HOLD",
        "technical_web_ready": checks["source_bound_public_webgl"] is True,
        "machine_verified_components": [name for name in REQUIRED_CHECKS if checks[name] is True],
        "missing_evidence": [{"check": name, "requirement": DISPLAY[name]}
                             for name in incomplete],
        "rejected_evidence": problems,
        "independent_human_verification_complete": False,
        "aaa_quality_certified": False,
        "production_go": False,
        "note": "No machine or uploaded JSON may approve real phones, 40-mission gameplay authenticity, all asset licences, AAA visual quality, or final commercial release."
    }


def run(args) -> dict:
    manifest = load_object(args.manifest)
    source = release_source(manifest)
    checks = {name: False for name in REQUIRED_CHECKS}
    failures: list[str] = []

    def check(name: str, provided: bool, fn) -> None:
        if not provided:
            return
        try:
            fn()
            checks[name] = True
        except (OSError, ValueError, TypeError, KeyError, OverflowError) as exc:
            failures.append(name + ": " + str(exc))

    check(REQUIRED_CHECKS[0], bool(args.r50_live and args.r50_browser),
          lambda: source_bound_public_webgl(manifest, args.assets,
                                            args.r50_live, args.r50_browser))
    check(REQUIRED_CHECKS[1], bool(args.campaign and args.campaign_dir),
          lambda: source_bound_campaign(manifest, args.game,
                                        args.campaign, args.campaign_dir))
    check(REQUIRED_CHECKS[2], bool(args.android),
          lambda: insist(r80.validate_physical_run(args.android, source) == "android",
                         "not the original Android session"))
    check(REQUIRED_CHECKS[3], bool(args.ios),
          lambda: insist(r80.validate_physical_run(args.ios, source) == "ios",
                         "not the original iPhone session"))
    check(REQUIRED_CHECKS[4], bool(args.sessions),
          lambda: human_sessions(args.sessions, source))
    check(REQUIRED_CHECKS[5], bool(args.art),
          lambda: art_and_licences(args.art, source))
    return summarise(source, checks, failures)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, default=Path("public/games/omega-3d-preview/release.json"))
    parser.add_argument("--assets", type=Path, default=Path("public/games/omega-3d-preview"))
    parser.add_argument("--game", type=Path, default=Path("godot/empire-omega/scripts/mission_manager.gd"))
    parser.add_argument("--r50-live", type=Path)
    parser.add_argument("--r50-browser", type=Path)
    parser.add_argument("--campaign", type=Path)
    parser.add_argument("--campaign-dir", type=Path)
    parser.add_argument("--android", type=Path)
    parser.add_argument("--ios", type=Path)
    parser.add_argument("--sessions", type=Path)
    parser.add_argument("--art", type=Path)
    parser.add_argument("--output", type=Path)
    parser.add_argument("--require-all-field-evidence", action="store_true")
    args = parser.parse_args()
    try:
        verdict = run(args)
    except (OSError, ValueError, TypeError, KeyError, OverflowError) as exc:
        verdict = {
            "schema": SCHEMA, "status": "HOLD", "production_go": False,
            "rejected_evidence": [str(exc)], "missing_evidence": list(REQUIRED_CHECKS)
        }
    value = json.dumps(verdict, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(value, encoding="utf-8")
    else:
        print(value, end="")
    return 1 if args.require_all_field_evidence and verdict["status"] == "HOLD" else 0


if __name__ == "__main__":
    sys.exit(main())
