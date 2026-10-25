#!/usr/bin/env python3
"""EMPIRE Omega R80: fail-closed linkage of a claimed physical phone report to
the game's ORIGINAL R36 measured-frames JSON and recorded mobile session.

Machine verification only checks source/payload integrity and internally
consistent metrics. It cannot prove this actually ran on a physical phone,
the recorded pixels depict the correct app, or any AAA-quality result.
"""
from __future__ import annotations

import datetime as dt
import hashlib
import json
import math
import re
from pathlib import Path

SCHEMA = "empire-omega-r50-physical-v1"
BENCHMARK_SCHEMA = "empire-omega-real-frames-r36-v1"
SHA40 = re.compile(r"^[a-f0-9]{40}$")
SHA64 = re.compile(r"^[a-f0-9]{64}$")
SAFE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9_.-]{0,127}$")
MAX_BENCHMARK_BYTES = 256_000
MAX_RECORDING_BYTES = 2_000_000_000


class EvidenceError(ValueError):
    pass


def require(ok: bool, message: str) -> None:
    if not ok:
        raise EvidenceError(message)


def numeric(data: dict, key: str, *, minimum=0.0, maximum=100000.0,
            zero_allowed=False) -> float:
    value = data.get(key)
    require(type(value) in (float, int) and math.isfinite(value),
            f"invalid numeric {key}")
    v = float(value)
    require((v >= minimum if zero_allowed else v > minimum) and v <= maximum,
            f"out-of-range {key}")
    return v


def integer(data: dict, key: str, *, minimum=0, maximum=999999) -> int:
    value = data.get(key)
    require(type(value) is int and minimum <= value <= maximum,
            f"invalid integer {key}")
    return value


def original_file(root: Path, name: object, digest: object, suffix: str,
                  minimum_bytes: int, maximum_bytes: int) -> Path:
    require(isinstance(name, str) and SAFE.fullmatch(name) is not None
            and name not in (".", "..") and name.lower().endswith(suffix),
            f"unsafe {suffix} evidence filename")
    require(isinstance(digest, str) and SHA64.fullmatch(digest) is not None,
            f"missing {suffix} evidence SHA-256")
    file = root / name
    require(not file.is_symlink() and file.is_file() and
            file.resolve().parent == root.resolve(),
            f"missing, linked or external evidence file: {name}")
    size = file.stat().st_size
    require(minimum_bytes <= size <= maximum_bytes,
            f"empty or oversized evidence file: {name}")
    sha = hashlib.sha256()
    with file.open("rb") as stream:
        while block := stream.read(1024 * 1024):
            sha.update(block)
    require(sha.hexdigest() == digest, f"evidence SHA-256 mismatch: {name}")
    return file


def check_close(a: float, b: float, label: str, tolerance: float = 0.05) -> None:
    require(abs(a - b) <= tolerance, f"mismatched original Godot benchmark {label}")


def validate_physical_run(report_path: str | Path, expected_source: str) -> str:
    require(isinstance(expected_source, str) and SHA40.fullmatch(expected_source) is not None,
            "invalid expected Godot release source SHA")
    report_path = Path(report_path)
    require(report_path.is_file() and report_path.stat().st_size < MAX_BENCHMARK_BYTES,
            "missing/oversized physical phone report")
    report = json.loads(report_path.read_text(encoding="utf-8"))
    require(isinstance(report, dict) and report.get("schema") == SCHEMA,
            "unknown physical device report schema")
    require(report.get("source_commit") == expected_source,
            "physical phone report does not match public Godot source SHA")
    os_family = report.get("os_family")
    require(os_family in ("ios", "android"),
            "a physical Android or iOS device must be identified")
    require(report.get("physical_device") is True,
            "simulator or browser emulation is not a physical phone")
    for field in ("model", "os_version", "browser", "operator"):
        require(isinstance(report.get(field), str) and
                3 <= len(report[field].strip()) <= 200,
                f"missing or invalid physical phone field {field}")
    when = report.get("capture_utc")
    try:
        parsed = dt.datetime.fromisoformat(when.replace("Z", "+00:00")) if isinstance(when, str) else None
    except ValueError:
        parsed = None
    require(parsed is not None and parsed.tzinfo is not None and
            parsed.utcoffset() == dt.timedelta(0),
            "physical phone recording requires genuine timezone-aware UTC timestamp")
    warmup = numeric(report, "warmup_s", minimum=1.99, maximum=10.0)
    capture = numeric(report, "capture_s", minimum=19.99, maximum=60.0)
    count = integer(report, "frame_count", minimum=100, maximum=6000)
    p95 = numeric(report, "p95_frame_ms", maximum=1000.0)
    p99 = numeric(report, "p99_frame_ms", maximum=1000.0)
    require(p99 >= p95, "p99 cannot beat p95")
    # Respect the actual viewport of the device, rather than reporting
    # arbitrary p95 and p99 independent of screen geometry.
    width = integer(report, "viewport_width", minimum=260, maximum=4096)
    height = integer(report, "viewport_height", minimum=320, maximum=4096)
    metrics_path = original_file(report_path.parent,
                                 report.get("benchmark_file"),
                                 report.get("benchmark_sha256"),
                                 ".json", 350, MAX_BENCHMARK_BYTES)
    benchmark = json.loads(metrics_path.read_text(encoding="utf-8"))
    require(isinstance(benchmark, dict) and
            benchmark.get("schema") == BENCHMARK_SCHEMA and
            benchmark.get("status") == "complete" and
            benchmark.get("engine") == "Godot 4.4.1",
            "source-linked ORIGINAL Godot R36 benchmark report missing")
    require(benchmark.get("metric_source") ==
            "Godot render-frame _process(delta), actual in-game Performance renderer counters",
            "real render-frame metric source missing")
    require(benchmark.get("platform_reported_by_engine") == "Web",
            "physical mobile run requires authentic Godot Web benchmark")
    # Original in-game benchmark explicitly cannot attest physical hardware
    # or the source commit. Those claims require independent human review.
    require(benchmark.get("physical_hardware_attested") is False and
            benchmark.get("device_model_verified") is False and
            benchmark.get("source_sha_verified") is False,
            "forged engine benchmark hardware/source attestation")
    require(benchmark.get("graphics_quality") in ("low", "standard", "cinematic"),
            "missing tested graphics preset")
    require(benchmark.get("viewport_width") == width and
            benchmark.get("viewport_height") == height,
            "original Godot viewport differs from device report")
    require(integer(benchmark, "frame_count", minimum=100, maximum=6000) == count,
            "original Godot frame count differs")
    check_close(numeric(benchmark, "warmup_s", maximum=10), warmup, "warmup")
    check_close(numeric(benchmark, "capture_s", maximum=60), capture, "capture")
    p50_source = numeric(benchmark, "p50_frame_ms", maximum=1000)
    p95_source = numeric(benchmark, "p95_frame_ms", maximum=1000)
    p99_source = numeric(benchmark, "p99_frame_ms", maximum=1000)
    check_close(p95_source, p95, "p95")
    check_close(p99_source, p99, "p99")
    require(p50_source <= p95_source <= p99_source,
            "impossible Godot percentile ordering")
    worst = numeric(benchmark, "r48_max_render_frame_ms", maximum=1000)
    require(worst >= p99_source, "Godot worst frame shorter than p99")
    over30 = integer(benchmark, "r48_over_30fps_frame_budget", maximum=6000)
    over60 = integer(benchmark, "r48_over_60fps_frame_budget", maximum=6000)
    require(0 <= over30 <= over60 <= count, "impossible original slow-frame counts")
    check_close(numeric(benchmark, "r48_stutter_frame_percent_30fps",
                        zero_allowed=True, maximum=100),
                100.0 * over30 / count, "stutter frame percentage", 0.06)
    check_close(numeric(benchmark, "mean_observed_fps", maximum=600),
                count / capture, "observed FPS", 0.06)
    check_close(numeric(benchmark, "r48_p95_fps_equivalent", maximum=1000),
                1000.0 / p95_source, "p95 FPS", 0.09)
    p95_draw = numeric(benchmark, "p95_draw_calls",
                       zero_allowed=True, maximum=2_000_000)
    peak_draw = integer(benchmark, "maximum_draw_calls", maximum=2_000_000)
    require(peak_draw >= p95_draw, "impossible original renderer draw count")
    integer(benchmark, "dropped_invalid_or_capacity", maximum=6000)
    filename = report.get("recording_file")
    require(isinstance(filename, str) and
            (filename.lower().endswith(".webm") or filename.lower().endswith(".mp4")),
            "missing original device video format")
    video = original_file(report_path.parent, filename, report.get("recording_sha256"),
                          ".webm" if filename.lower().endswith(".webm") else ".mp4",
                          1025, MAX_RECORDING_BYTES)
    with video.open("rb") as file:
        prefix = file.read(16)
    require((filename.lower().endswith(".webm") and prefix[:4] == bytes.fromhex("1a45dfa3")) or
            (filename.lower().endswith(".mp4") and prefix[4:8] == b"ftyp"),
            "device recording must have original WebM/MP4 container header")
    # NEVER return actual hardware verification or a Production GO certificate:
    # field claims can be fabricated even with hashes and coherent metrics.
    return os_family


def main() -> int:
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--report", type=Path, required=True,
                        help="Original filled physical-phone session JSON")
    parser.add_argument("--source-commit", required=True,
                        help="40-hex SHA copied from independent published release.json")
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()
    try:
        kind = validate_physical_run(args.report, args.source_commit)
        result = {
            "schema": "empire-omega-r80-hardware-evidence-verdict-v1",
            "status": "EVIDENCE_READY_FOR_INDEPENDENT_HARDWARE_REVIEW",
            "reported_phone_os": kind, "source_commit": args.source_commit,
            "device_physically_witnessed": False,
            "gameplay_and_recording_semantically_verified": False,
            "production_go": False,
            "required_next_gate": "An independent person must inspect the original device, app and video and sign off. No automatic AAA certification."
        }
    except (OSError, ValueError, TypeError, KeyError, OverflowError) as exc:
        result = {
            "schema": "empire-omega-r80-hardware-evidence-verdict-v1",
            "status": "HOLD", "production_go": False, "reason": str(exc)
        }
    rendered = json.dumps(result, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered, encoding="utf-8")
    else:
        print(rendered, end="")
    return 0 if result["status"] == "EVIDENCE_READY_FOR_INDEPENDENT_HARDWARE_REVIEW" else 1


if __name__ == "__main__":
    raise SystemExit(main())
