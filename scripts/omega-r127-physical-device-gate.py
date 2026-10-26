#!/usr/bin/env python3
"""EMPIRE OMEGA R127: evaluate operator-collected *physical* device run packets.

This does NOT turn Mesa CI into real PC/Android GPU evidence. It only rejects
missing/mismatched per-device reports and recordings. A final human visual,
thermal, source SHA, and playability sign-off always remains mandatory.
No network, no telemetry upload, no production actions.
"""
import argparse
import hashlib
import json
import math
import re
import sys
from pathlib import Path

SCENARIOS = ("drive_city", "live_cabinet", "night_rain", "save_reload")
DEVICE_CLASSES = ("desktop", "android")
REPETITIONS = (1, 2, 3)
REPORT_SCHEMA = "empire-omega-real-frames-r36-v1"
MODEL_SHA = re.compile(r"^[a-f0-9]{40}$")
FILE_SHA = re.compile(r"^[a-f0-9]{64}$")
SOFTWARE_GPU = ("llvmpipe", "softpipe", "swiftshader", "software rasterizer",
                "mesa offscreen", "virtual gpu", "software renderer")


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            sha.update(chunk)
    return sha.hexdigest()


def safe_file(root: Path, name: str) -> Path:
    value = (root / str(name)).resolve()
    if not value.is_relative_to(root.resolve()) or not value.is_file():
        raise ValueError("Missing/outside-scope file: " + name)
    return value


def software_renderer(name: str) -> bool:
    lowered = name.strip().lower()
    return not lowered or any(flag in lowered for flag in SOFTWARE_GPU)


def finite_positive(value: object) -> bool:
    return isinstance(value, (int, float)) and not isinstance(value, bool) and (
        math.isfinite(value) and value > 0
    )


def inspect_packet(folder: Path, packet: dict, source_sha: str) -> list[str]:
    errors: list[str] = []
    model = packet.get("model", "")
    browser = packet.get("browser", "")
    gpu = packet.get("gpu_renderer", "")
    if not isinstance(model, str) or len(model.strip()) < 4:
        errors.append("missing actual named physical device model")
    if not isinstance(browser, str) or len(browser.strip()) < 3:
        errors.append("missing actual browser version")
    if not isinstance(gpu, str) or software_renderer(gpu):
        errors.append("Mesa/software/unknown GPU is not physical target evidence")
    if packet.get("operator_observed_device") is not True:
        errors.append("named operator has not attested seeing actual device")
    if packet.get("original_source_sha") != source_sha:
        errors.append("per-run source SHA does not match candidate commit")
    try:
        video = safe_file(folder, packet.get("video_file", ""))
        stated = packet.get("video_sha256", "")
        if not isinstance(stated, str) or not FILE_SHA.fullmatch(stated) or digest(video) != stated:
            errors.append("screen recording bytes do not match stated SHA-256")
    except (OSError, ValueError) as exc:
        errors.append(str(exc))
    try:
        captured = json.loads(safe_file(folder, packet.get("game_report", "")).read_text("utf-8"))
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        errors.append("missing/unreadable actual Godot _process report: " + str(exc))
        return errors
    if captured.get("schema") != REPORT_SCHEMA or captured.get("status") != "complete":
        errors.append("requires a completed original Godot R36 JSON report")
    if captured.get("engine") != "Godot 4.4.1" or (
        not str(captured.get("metric_source", "")).startswith("Godot render-frame")
    ):
        errors.append("host rAF or synthetic numbers are NOT Godot on-device render evidence")
    if captured.get("physical_hardware_attested") is not False:
        errors.append("raw engine report must not falsely assert independently certified hardware")
    if captured.get("source_sha_verified") is not False:
        errors.append("raw engine report must not forge source verification")
    frames = captured.get("frame_count", 0)
    duration = captured.get("capture_s", 0)
    p50 = captured.get("p50_frame_ms", 0)
    p95 = captured.get("p95_frame_ms", 0)
    p99 = captured.get("p99_frame_ms", 0)
    if not isinstance(frames, int) or frames < 100 or (
        not finite_positive(duration) or duration < 19.0
    ):
        errors.append("too few actual Godot render frames or insufficient captured seconds")
    if not all(finite_positive(v) for v in (p50, p95, p99)) or not p50 <= p95 <= p99:
        errors.append("invalid real-frame percentile order or nonfinite samples")
    target = 16.7 if packet.get("device_class") == "desktop" else 33.3
    if finite_positive(p95) and p95 > target:
        errors.append("p95 %.2f ms exceeds device target %.1f ms" % (p95, target))
    if packet.get("device_class") == "android" and captured.get("graphics_quality") != "low":
        errors.append("Android benchmark must test an explicit LOW graphics preset")
    if packet.get("device_class") == "android" and packet.get("two_finger_controls_observed") is not True:
        errors.append("physical two-finger touch interaction lacks operator verification")
    return errors


def evaluate(path: Path, expected_sha: str) -> dict:
    if not MODEL_SHA.fullmatch(expected_sha):
        raise ValueError("Expected exact 40-character source SHA required")
    source = json.loads(path.read_text(encoding="utf-8"))
    if source.get("schema") != "omega-r127-physical-run-packet-v1":
        raise ValueError("Wrong real-device packet schema")
    if source.get("original_source_sha") != expected_sha:
        raise ValueError("Cannot accept recordings from another version or synthetic PR merge")
    if not isinstance(source.get("operator"), str) or not source["operator"].strip():
        raise ValueError("Missing named, accountable hardware witness")
    records = source.get("records", [])
    if not isinstance(records, list):
        raise ValueError("Expected a list of original source device measurements")
    examined = {}
    for packet in records:
        if not isinstance(packet, dict):
            raise ValueError("Malformed hardware record")
        key = (packet.get("device_class"), packet.get("scenario"), packet.get("iteration"))
        if key in examined:
            raise ValueError("Duplicate device/scenario/iteration cannot count as 3 trials")
        examined[key] = inspect_packet(path.parent, packet, expected_sha)
    blockers = []
    for device in DEVICE_CLASSES:
        for scenario in SCENARIOS:
            for iteration in REPETITIONS:
                key = (device, scenario, iteration)
                if key not in examined:
                    blockers.append("%s / %s / run %d: MISSING" % key)
                else:
                    for problem in examined[key]:
                        blockers.append("%s / %s / run %d: %s" % (*key, problem))
    return {
        "schema": "omega-r127-physical-evidence-check-v1",
        "source_sha": expected_sha,
        "original_evidence_packets": len(examined),
        "expected_packets": len(DEVICE_CLASSES)*len(SCENARIOS)*len(REPETITIONS),
        "structural_and_frame_thresholds_passed": not blockers,
        "blockers": blockers,
        "mesa_chromium_is_hardware_evidence": False,
        "independent_real_device_review_required": True,
        "art_reference_human_approval_recorded": False,
        "full_15_20_min_human_playthrough_recorded": False,
        "production_authorized": False
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--packet", type=Path)
    parser.add_argument("--expected-sha")
    parser.add_argument("--output", type=Path)
    parser.add_argument("--self-test", action="store_true")
    args = parser.parse_args()
    if args.self_test:
        assert software_renderer("Mesa llvmpipe")
        assert software_renderer("Google SwiftShader")
        assert not software_renderer("NVIDIA GeForce RTX 4070")
        assert finite_positive(16.7) and not finite_positive(float("nan"))
        assert not finite_positive(True)
        assert not MODEL_SHA.fullmatch("bad-hash")
        print("R127 physical-device evidence syntax/safety self-test PASS; NO hardware tested")
        return 0
    if args.packet is None or args.expected_sha is None:
        parser.error("Provide --packet and --expected-sha; never auto-attest CI samples")
    try:
        result = evaluate(args.packet.resolve(), args.expected_sha)
    except (OSError, ValueError, json.JSONDecodeError) as exc:
        print("R127 PHYSICAL GATE ERROR:", exc, file=sys.stderr)
        return 2
    body = json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True)+"\n"
    if args.output:
        args.output.write_text(body, encoding="utf-8")
    print(body)
    return 0 if result["structural_and_frame_thresholds_passed"] else 1


if __name__ == "__main__":
    sys.exit(main())
