#!/usr/bin/env python3
"""Prepare an UNVERIFIED Android/iPhone field evidence draft from REAL Godot
benchmark and recording bytes. Never attests a physical device or grants GO.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path

from omega_r80_hardware_evidence import (
    BENCHMARK_SCHEMA, SHA40, MAX_BENCHMARK_BYTES, MAX_RECORDING_BYTES,
    EvidenceError, require, numeric, integer, original_file
)


def digest(path: Path) -> str:
    sha = hashlib.sha256()
    with path.open("rb") as f:
        while block := f.read(1024 * 1024):
            sha.update(block)
    return sha.hexdigest()


def make_draft(benchmark_path: Path, video_path: Path, source_commit: str,
               os_family: str, output_path: Path) -> dict:
    require(SHA40.fullmatch(source_commit) is not None,
            "40 lowercase hex source SHA from the uncached public release manifest required")
    require(os_family in ("android", "ios"), "device OS must be android or ios")
    base = output_path.parent.resolve()
    require(benchmark_path.parent.resolve() == base and video_path.parent.resolve() == base,
            "original Godot benchmark, video and draft must be in the same session directory")
    require(output_path.name not in (benchmark_path.name, video_path.name),
            "never overwrite original video or Godot benchmark")
    b_sha = digest(benchmark_path)
    original_file(base, benchmark_path.name, b_sha, ".json", 350, MAX_BENCHMARK_BYTES)
    benchmark = json.loads(benchmark_path.read_text(encoding="utf-8"))
    require(isinstance(benchmark, dict) and benchmark.get("schema") == BENCHMARK_SCHEMA
            and benchmark.get("status") == "complete"
            and benchmark.get("engine") == "Godot 4.4.1",
            "not a completed original Godot 4.4.1 R36 frame report")
    require(benchmark.get("platform_reported_by_engine") == "Web",
            "only actual Godot Web mobile benchmark is eligible")
    require(benchmark.get("physical_hardware_attested") is False
            and benchmark.get("device_model_verified") is False
            and benchmark.get("source_sha_verified") is False,
            "source/physical attestation cannot be invented by the game")
    for k in ("warmup_s", "capture_s", "p95_frame_ms", "p99_frame_ms"):
        numeric(benchmark, k)
    for k in ("frame_count", "viewport_width", "viewport_height"):
        integer(benchmark, k)
    v_sha = digest(video_path)
    video_kind = ".webm" if video_path.suffix.lower() == ".webm" else ".mp4"
    require(video_path.suffix.lower() in (".webm", ".mp4"),
            "original continuous session video must be WebM or MP4")
    original_file(base, video_path.name, v_sha, video_kind, 1025, MAX_RECORDING_BYTES)
    with video_path.open("rb") as f:
        header = f.read(16)
    require((video_kind == ".webm" and header[:4] == bytes.fromhex("1a45dfa3")) or
            (video_kind == ".mp4" and header[4:8] == b"ftyp"),
            "video does not have authentic WebM/MP4 container header")
    draft = {
        "schema": "empire-omega-r50-physical-v1",
        "source_commit": source_commit,
        "os_family": os_family,
        "physical_device": False,
        "model": "",
        "os_version": "",
        "browser": "",
        "operator": "",
        "capture_utc": "",
        "warmup_s": benchmark["warmup_s"],
        "capture_s": benchmark["capture_s"],
        "frame_count": benchmark["frame_count"],
        "p95_frame_ms": benchmark["p95_frame_ms"],
        "p99_frame_ms": benchmark["p99_frame_ms"],
        "viewport_width": benchmark["viewport_width"],
        "viewport_height": benchmark["viewport_height"],
        "benchmark_file": benchmark_path.name,
        "benchmark_sha256": b_sha,
        "recording_file": video_path.name,
        "recording_sha256": v_sha,
        "_draft_status": "UNVERIFIED_TEMPLATE_NOT_HARDWARE_EVIDENCE",
        "_instructions": "Independent tester must verify actual phone, source, video and complete blank metadata before changing physical_device to true. Even then it remains human-review-only."
    }
    require(not output_path.is_symlink(), "never replace a linked draft path")
    with output_path.open("x", encoding="utf-8") as f:
        json.dump(draft, f, indent=2, ensure_ascii=False)
        f.write("\n")
    return draft


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--benchmark", type=Path, required=True)
    parser.add_argument("--recording", type=Path, required=True)
    parser.add_argument("--source-commit", required=True)
    parser.add_argument("--os-family", choices=("android", "ios"), required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        data = make_draft(args.benchmark, args.recording,
                          args.source_commit, args.os_family, args.output)
    except (OSError, ValueError, TypeError, KeyError) as err:
        print(json.dumps({"status": "HOLD", "reason": str(err)}, ensure_ascii=False))
        return 1
    print(json.dumps({"status": "UNVERIFIED_TEMPLATE",
                      "source_commit": data["source_commit"],
                      "physical_device_certified": False,
                      "production_go": False}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
