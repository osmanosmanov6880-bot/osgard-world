#!/usr/bin/env python3
"""Fail closed on W14 release evidence: raw source, archive and three-fault QA.

The reviewed SHA-256 pin is independent of the downloaded CI archive, and
software-rendered browser evidence is never represented as physical device FPS.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path


def require(condition: bool, message: str) -> None:
    if not condition:
        raise ValueError("OSGARD R135 W14 promotion rejected: " + message)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for piece in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(piece)
    return digest.hexdigest()


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--pin", type=Path, required=True)
    p.add_argument("--artifact", type=Path, required=True)
    args = p.parse_args()
    pin = json.loads(args.pin.read_text(encoding="utf-8"))
    home = args.artifact
    release = home / "r135-optimized-release"
    screens = home / "r135-screens"
    manifest_path = release / "R135_OPTIMIZED_MANIFEST.json"
    archive_path = release / "OSGARD_R135_OPTIMIZED_WEB.zip"
    require(pin.get("version") == "r135-case-progress-w14-20261025",
            "not the permitted W14 version")
    require(re.fullmatch(r"[0-9a-f]{40}", str(pin.get("source_commit", ""))) is not None,
            "invalid source SHA")
    require(re.fullmatch(r"[0-9a-f]{64}", str(pin.get("manifest_sha256", ""))) is not None,
            "invalid manifest SHA")
    require(pin.get("artifact_run_id") == 40175524463 and
            pin.get("artifact_id") == 12592898463,
            "unreviewed Actions artifact")
    require(pin.get("reviewed_portrait") is True and
            pin.get("reviewed_desktop") is True and
            pin.get("browser_three_fault_cases") is True and
            pin.get("physical_phone_fps_verified") is False,
            "unsupported physical-device claim or missing review")
    require(manifest_path.is_file() and archive_path.is_file(), "missing actual WebGL package")
    require(sha256(manifest_path) == pin["manifest_sha256"], "manifest digest mismatch")
    require(sha256(archive_path) == pin["archive_sha256"], "archive digest mismatch")
    m = json.loads(manifest_path.read_bytes())
    require(m.get("version") == pin["version"] and
            m.get("source_commit") == pin["source_commit"] and
            m.get("engine") == "Godot 4.4.1", "game source/version invalid")
    evidence = json.loads((home / "r135-w10-release-evidence.json").read_bytes())
    require(evidence.get("status") == "PASS" and
            evidence.get("manifest_sha256") == pin["manifest_sha256"] and
            evidence.get("archive_sha256") == pin["archive_sha256"] and
            evidence.get("source_commit") == pin["source_commit"] and
            evidence.get("hardware_gpu_fps_certified") is False,
            "source WebGL evidence failed or claims unmeasured physical GPU")
    metrics = {}
    for device, frame_name in [
        ("desktop-1366", "w12-desktop-1366"),
        ("mobile-390", "w12-mobile-390"),
    ]:
        report_path = screens / (frame_name + "-three-case-evidence.json")
        require(report_path.is_file(), "missing authentic browser report: " + device)
        report = json.loads(report_path.read_bytes())
        require(report.get("device") == device, "browser report device mismatch")
        require("not physical phone GPU" in report.get("software_browser_renderer", ""),
                "false physical-device performance attribution")
        cases = report.get("new_cases")
        require(isinstance(cases, list) and len(cases) == 2, "need both later faults")
        expect = [(1, "COOLING AIRFLOW", 3), (2, "SERVICE INTERLOCK", 1)]
        for i, (index, fault, view) in enumerate(expect):
            item = cases[i]
            require(item.get("index") == index and
                    item.get("fault") == fault and
                    item.get("targetView") == view and
                    item.get("cleared") == 2 + i and
                    item.get("result") == "PASS" and
                    item.get("simulated_only") is True,
                    "incorrect W12 fault matrix: " + device)
            image = screens / f"{frame_name}-fault-{index+1}-active.png"
            require(image.is_file() and image.stat().st_size > 20_000,
                    "missing real screenshot: " + image.name)
        metrics[device] = {
            "later_faults": [x["fault"] for x in cases],
            "final_case_count": cases[-1]["cleared"],
            "final_score": cases[-1]["score"],
        }
    print(json.dumps({
        "status": "W14_RELEASE_EVIDENCE_PASS",
        "version": pin["version"], "source_commit": pin["source_commit"],
        "manifest_sha256": pin["manifest_sha256"],
        "archive_sha256": pin["archive_sha256"],
        "desktop_and_emulated_touch": metrics,
        "physical_mobile_fps_tested": False,
    }, indent=2))


if __name__ == "__main__":
    main()
