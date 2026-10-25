#!/usr/bin/env python3
"""OSA CINEMA: local objective A/V QC from actual bytes, never publication authorization.

Media stay on the editor's machine. ffmpeg decodes each soundtrack (EBU R128,
silence detector) and each video (black and freeze detector); all markers are
hints for a human review, not an automated verdict about artistic quality.
"""
import argparse
import concurrent.futures
import hashlib
import json
import re
import subprocess
from datetime import datetime, timezone
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
VIDEO_MANIFEST = ROOT / "docs/OSA_CINEMA_V16_WORKPRINT_MANIFEST.json"
AUDIO_MANIFEST = ROOT / "docs/OSA_CINEMA_V16_NARRATION_MANIFEST.json"
HEX = re.compile(r"^[a-f0-9]{64}$")


def parsed_float(text, expression):
    matched = re.search(expression, text, re.I | re.M)
    return round(float(matched.group(1)), 3) if matched else None


def parse_audio(log):
    summary = log.rsplit("Summary:", 1)[-1] if "Summary:" in log else ""
    return {
        "integratedLufs": parsed_float(summary, r"\bI:\s*(-?[\d.]+)\s+LUFS"),
        "loudnessRangeLu": parsed_float(summary, r"LRA:\s*(-?[\d.]+)\s+LU"),
        "truePeakDbtp": parsed_float(summary, r"Peak:\s*(-?[\d.]+)\s+dBFS"),
        "silences": [
            {"start": round(float(m.group(1)), 3), "duration": round(float(m.group(2)), 3)}
            for m in re.finditer(
                r"silence_start:\s*([\d.]+).*?silence_end:\s*[\d.]+\s*\|\s*silence_duration:\s*([\d.]+)",
                log, re.S,
            )
        ],
    }


def parse_video(log):
    return {
        "blackIntervals": [
            {"start": round(float(m.group(1)), 3), "duration": round(float(m.group(2)), 3)}
            for m in re.finditer(
                r"black_start:\s*([\d.]+)\s+black_end:\s*[\d.]+\s+black_duration:\s*([\d.]+)", log
            )
        ],
        "freezeIntervals": [
            {"start": round(float(m.group(1)), 3), "duration": round(float(m.group(2)), 3)}
            for m in re.finditer(
                r"freeze_start:\s*([\d.]+).*?freeze_duration:\s*([\d.]+)\s*\n.*?freeze_end:",
                log, re.S,
            )
        ],
    }


def run_ffmpeg(args, timeout=120):
    try:
        result = subprocess.run(
            ["ffmpeg", "-nostdin", "-hide_banner", "-nostats", "-threads", "2", *args],
            capture_output=True, text=True, timeout=timeout, check=False,
        )
        return result.returncode, result.stderr
    except (OSError, subprocess.TimeoutExpired) as exc:
        return 124, str(exc)


def sha256_file(path):
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""):
            digest.update(chunk)
    return digest.hexdigest()


def asset_specs():
    video = json.loads(VIDEO_MANIFEST.read_text("utf-8"))["assets"]
    audio = json.loads(AUDIO_MANIFEST.read_text("utf-8"))["assets"]
    if len(video) != 4 or len(audio) != 6:
        raise ValueError("Expected precisely four workprints and six narration sources")
    seen = set()
    for asset in video + audio:
        name = asset.get("file")
        if not isinstance(name, str) or name != Path(name).name or "/" in name or "\\" in name:
            raise ValueError("Untrusted media filename")
        if not HEX.fullmatch(asset.get("sha256", "")) or not isinstance(asset.get("sizeBytes"), int):
            raise ValueError("Missing source byte fingerprint")
        if asset["id"] in seen:
            raise ValueError("Duplicate media ID")
        seen.add(asset["id"])
    return [("video", x) for x in video] + [("narration", x) for x in audio]


def inspect_one(spec, video_root, narration_root):
    kind, asset = spec
    local = (video_root if kind == "video" else narration_root) / asset["file"]
    row = {
        "id": asset["id"], "file": asset["file"], "category": kind,
        "locale": asset["locale"], "sourceFingerprint": asset["sha256"],
        "integrityVerified": False, "scanSucceeded": False,
        "audio": None, "video": None, "reviewFlags": [],
        "publicationAuthorized": False,
    }
    try:
        if local.is_symlink() or not local.is_file():
            row["reviewFlags"].append("original_missing_or_unsafe_symlink")
            return row
        observed = local.stat().st_size
        sha = sha256_file(local)
        row["observedBytes"] = observed
        row["observedSha256"] = sha
        if observed != asset["sizeBytes"] or sha != asset["sha256"]:
            row["reviewFlags"].append("source_integrity_mismatch")
            return row
        row["integrityVerified"] = True
    except OSError as exc:
        row["reviewFlags"].append("source_io_error")
        row["error"] = str(exc)
        return row

    code, log = run_ffmpeg(
        ["-i", str(local), "-vn", "-af",
         "ebur128=peak=true,silencedetect=noise=-45dB:d=1", "-f", "null", "-"]
    )
    row["audio"] = parse_audio(log)
    if code != 0 or row["audio"]["integratedLufs"] is None:
        row["reviewFlags"].append("audio_scan_failed")
    else:
        if row["audio"]["truePeakDbtp"] is not None and row["audio"]["truePeakDbtp"] > -1.0:
            row["reviewFlags"].append("true_peak_above_minus_one_dbtp_manual_review")
        if row["audio"]["silences"]:
            row["reviewFlags"].append("silence_intervals_manual_review")

    if kind == "video":
        code_v, log_v = run_ffmpeg(
            ["-i", str(local), "-map", "0:v:0", "-an", "-vf",
             "scale=320:-2,blackdetect=d=0.3:pix_th=0.10,freezedetect=n=-50dB:d=1.5",
             "-f", "null", "-"]
        )
        row["video"] = parse_video(log_v)
        if code_v != 0:
            row["reviewFlags"].append("video_scan_failed")
        if row["video"]["blackIntervals"]:
            row["reviewFlags"].append("black_transitions_review_intent")
        if row["video"]["freezeIntervals"]:
            row["reviewFlags"].append("static_holds_review_intent")
        row["scanSucceeded"] = code == 0 and code_v == 0
    else:
        row["scanSucceeded"] = code == 0
    return row


def evaluate(video_root, narration_root, max_workers=2):
    specs = asset_specs()
    with concurrent.futures.ThreadPoolExecutor(max_workers=max_workers) as executor:
        rows = list(executor.map(lambda spec: inspect_one(spec, video_root, narration_root), specs))
    return {
        "schemaVersion": 1,
        "project": "OSA CINEMA",
        "createdAt": datetime.now(timezone.utc).isoformat(),
        "scope": "Offline objective measurements of private video/audio source bytes",
        "releaseAuthorization": False,
        "limitations": [
            "No speech-language recognition or listening-based script approval",
            "No legal clearance, final-edit approval or subtitle accuracy check",
            "Black and static events may be deliberate editing choices",
            "True peak and LUFS targets depend on publishing platform",
            "These results are not a license to publish media",
        ],
        "summary": {
            "mediaTotal": len(rows),
            "integrityVerified": sum(bool(x["integrityVerified"]) for x in rows),
            "scanSucceeded": sum(bool(x["scanSucceeded"]) for x in rows),
            "needsEditorialReview": sum(bool(x["reviewFlags"]) for x in rows),
            "publicationAuthorized": 0,
        },
        "assets": rows,
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--video-root", type=Path, required=True)
    parser.add_argument("--narration-root", type=Path, required=True)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--max-workers", type=int, default=2)
    parser.add_argument("--strict-integrity", action="store_true",
                        help="Nonzero exit if any declared source or decode is missing/broken; never auto-approve release")
    opts = parser.parse_args()
    if opts.max_workers < 1 or opts.max_workers > 4:
        parser.error("--max-workers must be between 1 and 4")
    report = evaluate(opts.video_root, opts.narration_root, opts.max_workers)
    print("OSA_CINEMA_V17_OBJECTIVE_QA " + json.dumps(report["summary"], ensure_ascii=False))
    if opts.report:
        opts.report.parent.mkdir(parents=True, exist_ok=True)
        opts.report.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if opts.strict_integrity and (
        report["summary"]["integrityVerified"] != report["summary"]["mediaTotal"]
        or report["summary"]["scanSucceeded"] != report["summary"]["mediaTotal"]
    ):
        raise SystemExit(2)


if __name__ == "__main__":
    main()
