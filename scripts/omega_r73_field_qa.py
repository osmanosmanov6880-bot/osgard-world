#!/usr/bin/env python3
"""EMPIRE Omega R73: source-pinned, fail-closed 40-mission field evidence pack.

This tool can validate completeness, ordering, timestamps, image/video headers
and SHA-256 of submitted evidence. It CANNOT prove that a person played, that
pixels show the correct scene, that the video is decodable, or that the game is
AAA. A separate reviewer must inspect the original media and approve release.
"""
from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import math
import re
import struct
import sys
from pathlib import Path

SCHEMA = "empire-omega-r73-field-campaign-v1"
VERDICT_SCHEMA = "empire-omega-r73-field-verdict-v1"
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")
SAFE_FILE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
CHECKPOINTS = (6, 20, 40)
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class EvidenceError(ValueError):
    pass


def require(condition: bool, message: str) -> None:
    if not condition:
        raise EvidenceError(message)


def read_object(path: Path) -> dict:
    obj = json.loads(path.read_text(encoding="utf-8"))
    require(isinstance(obj, dict), f"JSON object required: {path.name}")
    return obj


def real_missions(script_path: Path) -> list[dict]:
    text = script_path.read_text(encoding="utf-8")
    marker = "const MISSIONS = "
    require(text.count(marker) == 1, "missing or duplicate authored mission registry")
    missions, _ = json.JSONDecoder().raw_decode(text.split(marker, 1)[1].lstrip())
    require(isinstance(missions, list) and len(missions) == 40,
            "expected exactly forty authored Godot missions")
    for index, item in enumerate(missions):
        require(isinstance(item, dict) and
                re.fullmatch(r"[a-z_]+", str(item.get("id", ""))) is not None and
                type(item.get("reward")) is int and item["reward"] > 0,
                f"invalid authored mission {index + 1}")
    return missions


def source_commit(manifest: dict) -> str:
    require(manifest.get("engine") == "Godot 4.4.1" and
            manifest.get("source_path") == "godot/empire-omega" and
            manifest.get("artifact_kind") == "native-Godot-HTML5-export",
            "expected the genuine EMPIRE Omega release manifest")
    sha = str(manifest.get("source_commit", ""))
    require(SHA40.fullmatch(sha) is not None, "missing exact game source commit")
    return sha


def make_template(manifest: dict, missions: list[dict]) -> dict:
    sha = source_commit(manifest)
    return {
        "schema": SCHEMA, "source_commit": sha,
        "tester": "", "captured_utc": "", "human_operated": False,
        "platform": "", "recording_file": "campaign.webm",
        "recording_sha256": "", "recording_duration_s": None,
        "missions": [
            {"stage": i + 1, "action": m["id"], "reward": m["reward"],
             "result": "pending", "start_s": None, "finish_s": None,
             "screen_file": f"mission-{i+1:02d}.png", "screen_sha256": ""}
            for i, m in enumerate(missions)
        ],
        "save_reload_checkpoints": [
            {"stage": stage, "stage_after_reload": None,
             "save_reload_verified": False,
             "screen_file": f"checkpoint-{stage:02d}.png", "screen_sha256": ""}
            for stage in CHECKPOINTS
        ],
        "notes": "Template only; no human playthrough or hardware is certified."
    }


def checked_media(root: Path, filename: object, digest: object, kind: str) -> None:
    require(isinstance(filename, str) and SAFE_FILE.fullmatch(filename) is not None
            and filename not in (".", ".."), f"unsafe {kind} filename")
    require(isinstance(digest, str) and SHA64.fullmatch(digest) is not None,
            f"missing {kind} SHA-256: {filename}")
    p = root / filename
    require(not p.is_symlink() and p.is_file() and p.resolve().parent == root.resolve(),
            f"missing or external {kind}: {filename}")
    require(p.stat().st_size >= (1024 if kind == "video" else 100),
            f"empty/truncated {kind}: {filename}")
    with p.open("rb") as stream:
        head = stream.read(32)
        if kind == "image":
            require(filename.lower().endswith(".png") and head.startswith(PNG_SIGNATURE)
                    and head[12:16] == b"IHDR", f"not a PNG: {filename}")
            width, height = struct.unpack(">II", head[16:24])
            require(width >= 160 and height >= 160 and width <= 8192 and height <= 8192,
                    f"implausible screenshot resolution: {filename}")
        else:
            require((filename.lower().endswith(".mp4") and head[4:8] == b"ftyp") or
                    (filename.lower().endswith(".webm") and head[:4] == b"\x1a\x45\xdf\xa3"),
                    f"not an MP4/WebM header: {filename}")
        stream.seek(0)
        sha = hashlib.sha256()
        while block := stream.read(1024 * 1024):
            sha.update(block)
    require(sha.hexdigest() == digest, f"SHA-256 mismatch for {filename}")


def positive_number(value: object, label: str) -> float:
    require(type(value) in (int, float) and math.isfinite(value) and value > 0,
            f"missing/invalid positive number {label}")
    return float(value)


def verify_campaign(submission: dict, manifest: dict, missions: list[dict],
                    evidence_dir: Path) -> dict:
    sha = source_commit(manifest)
    require(submission.get("schema") == SCHEMA, "wrong field evidence schema")
    require(submission.get("source_commit") == sha, "submitted campaign is for another game commit")
    require(submission.get("human_operated") is True, "unattested human field session")
    require(isinstance(submission.get("tester"), str) and
            len(submission["tester"].strip()) >= 3, "tester missing")
    require(submission.get("platform") in ("desktop", "android", "ios"),
            "actual tested platform missing")
    when = str(submission.get("captured_utc", ""))
    try:
        parsed = dt.datetime.fromisoformat(when.replace("Z", "+00:00"))
    except ValueError as exc:
        raise EvidenceError("invalid captured_utc") from exc
    require(parsed.tzinfo is not None and parsed.utcoffset() == dt.timedelta(0),
            "capture timestamp must be UTC and timezone-aware")
    duration = positive_number(submission.get("recording_duration_s"), "recording_duration_s")
    require(duration >= 60 and duration < 36000, "recording duration out of supported range")
    checked_media(evidence_dir, submission.get("recording_file"),
                  submission.get("recording_sha256"), "video")
    entries = submission.get("missions")
    require(isinstance(entries, list) and len(entries) == 40, "exactly forty ordered mission records required")
    used_images: set[str] = set()
    last_finish = 0.0
    for index, (entry, authored) in enumerate(zip(entries, missions)):
        require(isinstance(entry, dict), f"bad record at mission {index + 1}")
        label = f"mission {index + 1}"
        require(type(entry.get("stage")) is int and entry["stage"] == index + 1,
                f"wrong stage sequence at {label}")
        require(entry.get("action") == authored["id"] and
                type(entry.get("reward")) is int and entry["reward"] == authored["reward"],
                f"authored Godot action/reward mismatch at {label}")
        require(entry.get("result") == "passed", f"missing completed outcome for {label}")
        start = positive_number(entry.get("start_s"), label + " start")
        finish = positive_number(entry.get("finish_s"), label + " finish")
        require(start >= last_finish and finish > start + 0.5 and finish <= duration,
                f"overlapping or impossible recording timeline at {label}")
        last_finish = finish
        image = entry.get("screen_file")
        require(image not in used_images, f"reused screenshot filename at {label}")
        used_images.add(image)
        checked_media(evidence_dir, image, entry.get("screen_sha256"), "image")
    checkpoints = submission.get("save_reload_checkpoints")
    require(isinstance(checkpoints, list) and len(checkpoints) == len(CHECKPOINTS),
            "three mandatory save/reload checkpoints required")
    for entry, stage in zip(checkpoints, CHECKPOINTS):
        require(isinstance(entry, dict) and type(entry.get("stage")) is int and
                entry["stage"] == stage and entry.get("save_reload_verified") is True and
                type(entry.get("stage_after_reload")) is int and
                entry["stage_after_reload"] == stage,
                f"save/reload proof missing or regressed at stage {stage}")
        image = entry.get("screen_file")
        require(image not in used_images, f"duplicate checkpoint screenshot at stage {stage}")
        used_images.add(image)
        checked_media(evidence_dir, image, entry.get("screen_sha256"), "image")
    return {
        "schema": VERDICT_SCHEMA, "source_commit": sha,
        "status": "EVIDENCE_READY_FOR_INDEPENDENT_REVIEW",
        "mission_records_checked": 40, "distinct_screenshot_files_checked": 43,
        "save_reload_checkpoints_checked": list(CHECKPOINTS),
        "recording_digest_checked": True,
        "browser_or_hardware_run_independently_witnessed": False,
        "screenshots_semantically_verified": False,
        "video_playback_verified": False,
        "aaa_quality_attested": False,
        "production_go": False,
        "required_next_gate": "Independent reviewer inspects original continuous playthrough, screenshot contents, physical hardware tests, AAA art and signs off separately."
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    mode = parser.add_mutually_exclusive_group(required=True)
    mode.add_argument("--template", action="store_true")
    mode.add_argument("--verify", type=Path, metavar="SESSION_JSON")
    parser.add_argument("--manifest", type=Path, default=Path("public/games/omega-3d-preview/release.json"))
    parser.add_argument("--game", type=Path, default=Path("godot/empire-omega/scripts/mission_manager.gd"))
    parser.add_argument("--evidence-dir", type=Path, default=Path("."))
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        manifest = read_object(args.manifest)
        missions = real_missions(args.game)
        if args.template:
            report = make_template(manifest, missions)
        else:
            report = verify_campaign(read_object(args.verify), manifest, missions, args.evidence_dir)
    except (ValueError, OSError, TypeError, KeyError, OverflowError) as exc:
        report = {"schema": VERDICT_SCHEMA, "status": "HOLD",
                  "production_go": False, "reason": str(exc)}
    rendered = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 1 if report.get("status") == "HOLD" else 0


if __name__ == "__main__":
    sys.exit(main())
