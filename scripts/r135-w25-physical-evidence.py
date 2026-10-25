#!/usr/bin/env python3
"""OSGARD R135 W25: fail-closed integrity gate for ORIGINAL physical mobile
field recordings and visible Godot frame timing JSON, on both phone families.

No software tool can certify that an operator used a real phone or the footage
shows the stated device. A machine pass means DOCUMENT INTEGRITY ONLY, never
hardware certification. Do not place users' identities in submissions.
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
import zlib
from pathlib import Path

SCHEMA = "osgard-r135-w25-browser-frames-v1"
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,120}$")
MATRIX = {("android", "portrait"), ("android", "landscape"),
          ("ios", "portrait"), ("ios", "landscape")}
MAX_REPORT_BYTES = 320_000
MAX_VIDEO_BYTES = 2_000_000_000


class EvidenceError(ValueError):
    pass


def require(valid: bool, explanation: str) -> None:
    if not valid:
        raise EvidenceError(explanation)


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for block in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(block)
    return h.hexdigest()


def checked_file(folder: Path, name: object, sha: object, kind: str,
                 minimum: int = 1024, maximum: int = MAX_VIDEO_BYTES) -> Path:
    require(isinstance(name, str) and bool(SAFE.fullmatch(name)) and
            name not in (".", "..") and name.lower().endswith(kind),
            "unsafe or missing original " + kind + " filename")
    require(isinstance(sha, str) and bool(SHA64.fullmatch(sha)),
            "invalid SHA-256 for " + kind)
    path = folder / name
    require(path.is_file() and not path.is_symlink() and
            path.resolve().parent == folder.resolve(), "missing/linked original evidence")
    require(minimum <= path.stat().st_size <= maximum, "original evidence invalid size")
    require(digest(path) == sha, "original evidence SHA-256 mismatch")
    return path


def verify_png(path: Path) -> tuple[int, int]:
    data = path.read_bytes()
    require(data.startswith(b"\x89PNG\r\n\x1a\n") and len(data) > 16000,
            "not a full original PNG screenshot")
    offset, width, height, pixels, closed = 8, 0, 0, False, False
    while offset + 12 <= len(data):
        size = struct.unpack_from(">I", data, offset)[0]
        end = offset + 8 + size
        require(size <= 25_000_000 and end + 4 <= len(data),
                "truncated/oversized screenshot chunk")
        marker = data[offset + 4:offset + 8]
        actual_crc = zlib.crc32(data[offset + 4:end]) & 0xFFFFFFFF
        expected_crc = struct.unpack_from(">I", data, end)[0]
        require(actual_crc == expected_crc, "original screenshot CRC mismatch")
        if marker == b"IHDR":
            require(size == 13, "invalid screenshot IHDR")
            width, height = struct.unpack_from(">II", data, offset + 8)
        elif marker == b"IDAT":
            pixels = True
        elif marker == b"IEND":
            closed = (size == 0 and end + 4 == len(data))
            break
        offset = end + 4
    require(closed and pixels and 300 <= width <= 4096 and 300 <= height <= 4096,
            "incomplete image or invalid dimensions")
    return width, height


def verify_video(path: Path) -> None:
    with path.open("rb") as f:
        head = f.read(16)
    require((path.suffix.lower() == ".webm" and
             head[:4] == bytes.fromhex("1a45dfa3")) or
            (path.suffix.lower() == ".mp4" and head[4:8] == b"ftyp"),
            "video does not have original MP4/WebM container header")


def quantile(samples: list[float], fraction: float) -> float:
    sorted_sample = sorted(samples)
    return sorted_sample[min(len(samples)-1, max(0, math.ceil(len(samples)*fraction)-1))]


def number(value: object, low: float, high: float, label: str) -> float:
    require(type(value) in (float, int) and math.isfinite(value) and
            low <= float(value) <= high, "invalid numeric " + label)
    return float(value)


def validate_capture(report: dict, expected_source: str) -> dict:
    require(isinstance(report, dict) and report.get("schema") == SCHEMA,
            "not an original OSGARD Godot R135 browser timing report")
    require(report.get("source_commit") == expected_source, "source SHA mismatch")
    require(report.get("engine") == "Godot 4.4.1" and
            report.get("scene_ready") is True and report.get("simulation_only") is True,
            "unverified Godot game source")
    require(report.get("status") == "UNVERIFIED_PHONE_MEASUREMENT_DRAFT" and
            report.get("physical_hardware_attested") is False and
            report.get("reviewer_confirmed") is False and
            report.get("visual_review_approved") is False and
            report.get("screen_recording_approved") is False,
            "browser software must NEVER self-certify physical equipment")
    require(report.get("uploads_sent") is False and
            report.get("user_agent_trusted") is False and
            report.get("no_synthetic_emulation_claim") is False,
            "browser must not secretly upload or claim authenticated phone ID")
    require(report.get("platform_claim") in {"android", "ios"},
            "unknown/desktop OS cannot count as Android or iOS phone")
    require(report.get("orientation") in {"portrait", "landscape"},
            "unknown device orientation")
    w, h = report.get("viewport_width"), report.get("viewport_height")
    require(type(w) is int and type(h) is int and
            300 <= w <= 4096 and 300 <= h <= 4096 and
            ((w < h) == (report["orientation"] == "portrait")),
            "invalid real phone viewport/orientation")
    require(report.get("quality") in (0, 2), "not actual ECO/HERO quality")
    require(report.get("loaded_model") in ("service_spine_eco.glb",
                                           "service_spine_hero.glb"),
            "original Godot equipment model missing")
    require(type(report.get("cleared_case_count")) is int and
            0 <= report["cleared_case_count"] <= 3,
            "invalid actual game diagnostic count")
    require(report.get("WebGL_context_lost") is False, "GPU context lost during benchmark")
    when = report.get("capture_utc")
    try:
        parsed = dt.datetime.fromisoformat(when.replace("Z", "+00:00"))
    except (TypeError, ValueError):
        parsed = None
    require(parsed is not None and parsed.tzinfo is not None and
            parsed.utcoffset() == dt.timedelta(0), "UTC session timestamp required")
    times = report.get("frames_ms")
    require(isinstance(times, list) and 240 <= len(times) <= 9000 and
            report.get("frame_count") == len(times),
            "missing original uninterrupted frame-time array")
    values = [number(v, 1.0, 1000.0, "frame_ms") for v in times]
    elapsed = number(report.get("capture_ms"), 20_000, 62_000, "capture_ms")
    require(abs(sum(values)-elapsed) <= 2500.0,
            "frame samples not consistent with 20-60 seconds of real rendering")
    percentiles = {}
    for field, fraction in (("p50_frame_ms", .50), ("p95_frame_ms", .95),
                            ("p99_frame_ms", .99)):
        recorded = number(report.get(field), 1.0, 1000, field)
        actual = quantile(values, fraction)
        require(abs(recorded-actual) <= .15,
                field + " differs from the individual original frames")
        percentiles[field] = actual
    return {"os": report["platform_claim"], "orientation": report["orientation"],
            "model": report["loaded_model"], "frame_count": len(values),
            "capture_ms": elapsed, **percentiles}


def review_bundle(folder: Path, expected_source: str) -> dict:
    require(bool(SHA40.fullmatch(expected_source)), "exact 40-character source SHA required")
    folder = folder.resolve()
    matrix, summaries = set(), []
    for platform, orientation in sorted(MATRIX):
        session = folder / (platform + "-" + orientation)
        require(session.is_dir() and not session.is_symlink(), "missing device session: " + session.name)
        manifest_path = session / "original-evidence.json"
        require(manifest_path.is_file() and
                200 <= manifest_path.stat().st_size <= 16_000,
                "session needs manifest with original file hashes")
        manifest = json.loads(manifest_path.read_text("utf-8"))
        require(manifest.get("schema") == "osgard-r135-w25-original-evidence-v1",
                "wrong original evidence manifest")
        if manifest.get("device_claim") != platform or manifest.get("orientation") != orientation:
            raise EvidenceError("session matrix device mismatch")
        benchmark = checked_file(session, manifest.get("timing_file"),
                                 manifest.get("timing_sha256"), ".json",
                                 1400, MAX_REPORT_BYTES)
        recording_ext = Path(str(manifest.get("video_file", ""))).suffix.lower()
        require(recording_ext in (".mp4", ".webm"), "continuous original video required")
        video = checked_file(session, manifest.get("video_file"),
                             manifest.get("video_sha256"), recording_ext, 1025)
        verify_video(video)
        screenshot = checked_file(session, manifest.get("screenshot_file"),
                                  manifest.get("screenshot_sha256"), ".png", 16001, 25_000_000)
        width, height = verify_png(screenshot)
        report = json.loads(benchmark.read_text("utf-8"))
        evidence = validate_capture(report, expected_source)
        require(evidence["os"] == platform and evidence["orientation"] == orientation,
                "benchmark session does not match original mobile evidence bundle")
        require((width < height) == (orientation == "portrait"),
                "original screenshot not captured in claimed orientation")
        summaries.append(evidence)
        matrix.add((platform, orientation))
    require(matrix == MATRIX, "physical families and both orientations required")
    return {
        "status": "ORIGINAL_BYTES_INTEGRITY_PASS_HUMAN_DEVICE_REVIEW_HOLD",
        "source_commit": expected_source,
        "verified_session_matrix": ["/".join(x) for x in sorted(matrix)],
        "original_software_frame_reports": summaries,
        "physical_device_authenticated": False,
        "human_visual_review_completed": False,
        "hardware_fps_certified": False,
        "iOS_Safari_and_Android_Chrome_certified": False,
        "production_W28_go": False,
        "note": "SHA/CRC/data consistency cannot prove footage is a real physical phone; independent human review remains mandatory."
    }


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument("--evidence", type=Path, required=True)
    p.add_argument("--source", required=True)
    a = p.parse_args()
    try:
        result = review_bundle(a.evidence, a.source)
    except (EvidenceError, OSError, KeyError, TypeError, json.JSONDecodeError) as error:
        print(json.dumps({"status": "HOLD", "reason": str(error),
                          "hardware_fps_certified": False}, ensure_ascii=False))
        return 1
    print(json.dumps(result, ensure_ascii=False, indent=2))
    return 0


if __name__ == "__main__":
    sys.exit(main())
