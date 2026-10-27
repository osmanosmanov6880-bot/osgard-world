#!/usr/bin/env python3
"""EMPIRE Ω R135: PRIVATE capture intake for 36 REAL hardware trials.

This is an offline evidence collector, NOT an emulator, video creator, or
GPU-performance certification. Every real input is copied unchanged to a
private 0700 folder and SHA-256 pinned. Source-of-truth validation delegates
to the existing omega-r127-physical-device-gate.py; a structural PASS still
requires independently witnessed genuine devices, ART and GAMEPLAY reviews.
Never commit original player/device recordings to GitHub.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import runpy
import shutil
import stat
import sys

ROOT = Path(__file__).resolve().parent.parent
GATE = runpy.run_path(str(ROOT / "scripts/omega-r127-physical-device-gate.py"))
DEVICES = ("desktop", "android", "iphone")
SCENARIOS = ("drive_city", "live_cabinet", "night_rain", "save_reload")
ITERATIONS = (1, 2, 3)
SHA40 = re.compile(r"^[0-9a-f]{40}$")
KIT_SCHEMA = "omega-r135-private-physical-intake-v1"
PACKET_SCHEMA = "omega-r127-physical-run-packet-v1"
MAX_VIDEO = 2 * 1024 * 1024 * 1024
MIN_VIDEO = 128 * 1024


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError(message)


def private_root(root: Path, creating: bool) -> Path:
    require(root.is_absolute() and not root.is_symlink(),
            "Supply an absolute, non-symlink PRIVATE recording folder")
    actual = root.resolve()
    require(not actual.is_relative_to(ROOT.resolve()),
            "Real device videos and participant names MUST stay outside public Git checkout")
    require(root.parent.is_dir() and not root.parent.is_symlink(),
            "Private workspace parent must be a real directory")
    if creating:
        require(not root.exists(), "Never overwrite existing physical-device evidence")
    else:
        require(root.is_dir(), "Physical-device private intake workspace missing")
        if os.name == "posix":
            require((stat.S_IMODE(root.stat().st_mode) & 0o077) == 0,
                    "Physical evidence folder must be chmod 700")
    return root


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def atomic_json(path: Path, obj: dict, *, create: bool = False) -> None:
    value = json.dumps(obj, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
    temp = path.parent / ("." + path.name + ".r135-pending")
    if create:
        require(not path.exists() and not temp.exists(), "Evidence template already exists")
    require(not temp.exists() and not temp.is_symlink(), "Stale/unsafe intake tempfile")
    fd = os.open(temp, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            f.write(value)
        if create:
            os.link(temp, path)
        else:
            require(path.is_file() and not path.is_symlink(), "Unsafe packet update")
            os.replace(temp, path)
    finally:
        temp.unlink(missing_ok=True)


def capture_matrix() -> list[dict]:
    return [
        {"device_class": d, "scenario": s, "iteration": i,
         "required": True, "actual_video_collected": False,
         "actual_godot_r36_report_collected": False}
        for d in DEVICES for s in SCENARIOS for i in ITERATIONS
    ]


def init(root: Path, sha: str) -> dict:
    require(SHA40.fullmatch(sha) is not None, "Exact source commit 40-char SHA required")
    private_root(root, True)
    root.mkdir(mode=0o700)
    atomic_json(root / "capture_packet.json", {
        "schema": PACKET_SCHEMA,
        "original_source_sha": sha,
        "operator": "",
        "records": [],
    }, create=True)
    atomic_json(root / "REQUIRED_36_DEVICE_RUNS.json", {
        "schema": KIT_SCHEMA, "exact_original_source_sha": sha,
        "expected_original_video_records": 36,
        "recordings": capture_matrix(),
        "all_evidence_is_missing_until_independently_recorded": True,
        "production_authorized": False
    }, create=True)
    instructions = (
        "# EMPIRE Ω R135 — private REAL-device field evidence\n\n"
        "All tests MUST run the exact unpublished Godot R90 SHA " + sha + ".\n"
        "This folder must remain PRIVATE (no Git commit, email or public CI upload).\n\n"
        "36 separate runs = desktop / Android / physical iPhone x 4 original game\n"
        "scenarios (drive_city, live_cabinet, night_rain, save_reload) x 3 each.\n"
        "For each run capture a CONTINUOUS real screen video and the original\n"
        "Godot R36 completed engine-render-frame JSON (at least 19 seconds,\n"
        "100 frames). Observe the exact phone model, real GPU/browser version\n"
        "and both fingers on phones. Do not re-use videos or artificial FPS.\n\n"
        "Example local intake:\n"
        "python3 scripts/omega-r135-physical-fieldkit.py add --root /PRIVATE/PATH \\\n"
        "  --device android --scenario drive_city --iteration 1 \\\n"
        "  --model 'Actual device' --gpu 'Actual GPU renderer' \\\n"
        "  --browser 'Actual Chrome version' --operator 'Witness code' \\\n"
        "  --witnessed-live --two-finger-observed \\\n"
        "  --video /PRIVATE/REAL_ORIGINAL.mp4 \\\n"
        "  --frame-report /PRIVATE/REAL_GODOT_R36.json\n\n"
        "Then run audit --root /PRIVATE/PATH. The strict existing R127\n"
        "validator must show 36/36 actual packets and valid source-locked\n"
        "original video bytes, real Godot frame percentile targets and GPU.\n"
        "Even then independent physical operator and art approval are needed;\n"
        "machine status NEVER authorizes master/SSH/production.\n"
    )
    note = root / "PRIVATE_INSTRUCTIONS_RU.md"
    fd = os.open(note, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(instructions)
    return {"status": "PRIVATE_EMPTY_36_RUN_MATRIX_CREATED", "source_sha": sha,
            "real_videos_recorded": 0, "expected": 36, "production_authorized": False}


def load_packet(root: Path) -> dict:
    path = root / "capture_packet.json"
    require(path.is_file() and not path.is_symlink(), "Unsafe source-locked capture manifest")
    packet = json.loads(path.read_text("utf-8"))
    require(packet.get("schema") == PACKET_SCHEMA and
            SHA40.fullmatch(str(packet.get("original_source_sha", ""))) is not None,
            "Existing kit is not source-pinned to a REAL original commit")
    require(isinstance(packet.get("records"), list), "Malformed intake records")
    return packet


def validate_media(video: Path, report: Path) -> dict:
    for p in (video, report):
        require(p.is_file() and not p.is_symlink(), "Real original file missing/linked: "+str(p))
    require(MIN_VIDEO <= video.stat().st_size <= MAX_VIDEO,
            "Real video empty/truncated/oversized (requires original screen recording)")
    require(video.suffix.lower() in (".mp4", ".mov", ".webm"),
            "Physical video must be an untouched MP4/MOV/WebM")
    with video.open("rb") as inp:
        header = inp.read(16)
    require((video.suffix.lower() in (".mp4", ".mov") and header[4:8] == b"ftyp") or
            (video.suffix.lower() == ".webm" and header[:4] == bytes.fromhex("1a45dfa3")),
            "Input is not an actual video media container")
    require(40 <= report.stat().st_size <= 1024 * 1024,
            "Original Godot frame JSON is empty/oversized")
    data = json.loads(report.read_text("utf-8"))
    require(isinstance(data, dict) and
            data.get("schema") == "empire-omega-real-frames-r36-v1" and
            data.get("engine") == "Godot 4.4.1" and
            data.get("status") == "complete",
            "Requires ORIGINAL completed Godot R36 engine report, not browser RAF")
    require(str(data.get("metric_source", "")).startswith("Godot render-frame"),
            "Browser requestAnimationFrame is NOT original Godot frame timing")
    return data


def add(root: Path, args: argparse.Namespace) -> dict:
    private_root(root, False)
    packet = load_packet(root)
    sha = packet["original_source_sha"]
    key = (args.device, args.scenario, args.iteration)
    require(args.device in DEVICES and args.scenario in SCENARIOS and
            args.iteration in ITERATIONS, "Unknown physical trial ID")
    require(args.witnessed_live is True, "Operator must explicitly witness real device")
    require(args.device == "desktop" or args.two_finger_observed is True,
            "Real Android/iPhone needs actually observed simultaneous touch")
    require(all(isinstance(s, str) and len(s.strip()) >= 4 and len(s) <= 160
                for s in (args.model, args.gpu, args.browser, args.operator)),
            "Record the actual device, GPU, browser and accountable witness")
    require(not GATE["software_renderer"](args.gpu),
            "Software Mesa/SwiftShader renderer is NOT real physical GPU evidence")
    require(not any((p.get("device_class"),p.get("scenario"),p.get("iteration")) == key
                    for p in packet["records"]), "Refuse duplicate or overwritten recording")
    require(not packet["operator"] or packet["operator"] == args.operator,
            "Lead operator/source pin cannot silently change between sessions")
    validate_media(args.video, args.frame_report)
    name = "_".join(map(str,key))
    suffix = args.video.suffix.lower()
    vid_name = name + suffix
    report_name = name + "_R36.json"
    target_video = root / vid_name
    target_report = root / report_name
    require(not target_video.exists() and not target_report.exists(),
            "Never replace any real original recording or frame report")
    try:
        shutil.copy2(args.video, target_video, follow_symlinks=False)
        shutil.copy2(args.frame_report, target_report, follow_symlinks=False)
        if os.name == "posix":
            target_video.chmod(0o600)
            target_report.chmod(0o600)
        entry = {
            "device_class": args.device, "scenario": args.scenario,
            "iteration": args.iteration, "model": args.model,
            "browser": args.browser, "gpu_renderer": args.gpu,
            "operator_observed_device": True,
            "two_finger_controls_observed": args.two_finger_observed,
            "original_source_sha": sha,
            "video_file": vid_name, "video_sha256": sha256(target_video),
            "game_report": report_name,
        }
        problems = GATE["inspect_packet"](root, entry, sha)
        packet["operator"] = args.operator
        packet["records"].append(entry)
        atomic_json(root / "capture_packet.json", packet)
    except BaseException:
        # Never leave half-copied evidence that can count for another run.
        if not any((p.get("device_class"),p.get("scenario"),p.get("iteration")) == key
                   for p in load_packet(root)["records"]):
            target_video.unlink(missing_ok=True)
            target_report.unlink(missing_ok=True)
        raise
    return {
        "status": ("ORIGINAL_SOURCE_RECORD_CAPTURED" if not problems else
                   "ORIGINAL_RECORD_CAPTURED_WITH_PERFORMANCE_OR_SOURCE_BLOCKERS"),
        "device": args.device, "scenario": args.scenario,
        "iteration": args.iteration, "real_video_sha256": entry["video_sha256"],
        "issues": problems,
        "original_record_count": len(packet["records"]),
        "production_authorized": False,
    }


def audit(root: Path) -> dict:
    private_root(root, False)
    p = root / "capture_packet.json"
    packet = load_packet(root)
    report = GATE["evaluate"](p, packet["original_source_sha"])
    # This is a structural *source and frame threshold* check ONLY.
    report["independent_physical_witness_completed_by_tool"] = False
    report["production_authorized"] = False
    atomic_json(root / "AUDIT_36_REAL_DEVICE_RUNS.json", report,
                create=not (root / "AUDIT_36_REAL_DEVICE_RUNS.json").exists())
    return report


def self_test() -> None:
    rows = capture_matrix()
    assert len(rows) == 36 and len({
        (x["device_class"],x["scenario"],x["iteration"]) for x in rows
    }) == 36
    assert not GATE["MODEL_SHA"].fullmatch("fake-sha")
    assert GATE["software_renderer"]("Mesa llvmpipe")
    assert GATE["software_renderer"]("Google SwiftShader")
    assert not GATE["software_renderer"]("NVIDIA GeForce RTX 4070")
    assert all(not x["actual_video_collected"] for x in rows)
    assert len(DEVICES) == 3 and len(SCENARIOS) == 4 and len(ITERATIONS) == 3
    print("R135 PASS: private 36 unique slots / no fake GPU or videos, zero production GO")


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("action", choices=("init","add","audit","self-test"))
    p.add_argument("--root", type=Path)
    p.add_argument("--sha", help="Exact 40-char original unpublished R90 game source SHA")
    p.add_argument("--device", choices=DEVICES)
    p.add_argument("--scenario", choices=SCENARIOS)
    p.add_argument("--iteration", type=int, choices=ITERATIONS)
    p.add_argument("--video", type=Path)
    p.add_argument("--frame-report", type=Path)
    p.add_argument("--model")
    p.add_argument("--gpu")
    p.add_argument("--browser")
    p.add_argument("--operator")
    p.add_argument("--witnessed-live", action="store_true")
    p.add_argument("--two-finger-observed", action="store_true")
    args = p.parse_args()
    try:
        if args.action == "self-test":
            self_test()
            return 0
        require(args.root is not None, "Private --root path mandatory")
        if args.action == "init":
            result = init(args.root, args.sha or "")
        elif args.action == "add":
            require(args.video is not None and args.frame_report is not None,
                    "Actual ORIGINAL --video and Godot R36 --frame-report required")
            result = add(args.root,args)
        else:
            result = audit(args.root)
        print(json.dumps(result,ensure_ascii=False,indent=2))
        # A full 36 packet report must return failure if evidence remains HOLD.
        if args.action == "audit" and not result["structural_and_frame_thresholds_passed"]:
            return 1
        return 0
    except (ValueError,OSError,TypeError,KeyError,json.JSONDecodeError) as e:
        print(json.dumps({"status":"HOLD","production_authorized":False,
                          "error":str(e)},ensure_ascii=False),file=sys.stderr)
        return 2


if __name__ == "__main__":
    sys.exit(main())
