#!/usr/bin/env python3
"""R135 W12: fail-closed verification of *actual* Chromium 3-case screenshots.

Not OCR, not GPU/physical-phone attestation; visual review remains separate.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path

from PIL import Image


def require(condition: bool, reason: str) -> None:
    if not condition:
        raise ValueError("R135 W12 evidence rejected: " + reason)


def audit(screens: Path) -> dict:
    filenames = {}
    cases = []
    for device in ("desktop-1366", "mobile-390"):
        mobile = device == "mobile-390"
        evidence_path = screens / f"w12-{device}-three-case-evidence.json"
        require(evidence_path.is_file(), "missing 3-case JSON for " + device)
        report = json.loads(evidence_path.read_text(encoding="utf-8"))
        require(report.get("device") == device and report.get("new_cases") is not None,
                "wrong device or cases in " + device)
        require(report.get("software_browser_renderer", "").startswith("SwiftShader"),
                "not labelled as software Chromium WebGL")
        records = report["new_cases"]
        require(isinstance(records, list) and len(records) == 2, "must contain exactly two new cases")
        for n, (idx, fault, target) in enumerate(((1, "COOLING AIRFLOW", 3), (2, "SERVICE INTERLOCK", 1))):
            case = records[n]
            require(case.get("index") == idx and case.get("fault") == fault
                    and case.get("targetView") == target and case.get("cleared") == idx + 1
                    and case.get("result") == "PASS" and case.get("simulated_only") is True,
                    "case identity/completion missing for " + device + " " + fault)
            require(type(case.get("errors")) is int and case["errors"] >= 2,
                    "unsafe/wrong-view errors were not recorded")
            require(type(case.get("score")) in (int, float)
                    and math.isfinite(case["score"]) and 0 <= case["score"] <= 150,
                    "invalid score")
            projection = case.get("caption_projection")
            require(isinstance(projection, dict), "no actual 3D camera projection evidence")
            px, py = projection.get("normalized_x"), projection.get("normalized_y")
            css = projection.get("css_height_px")
            dpr = projection.get("device_pixel_ratio")
            native = projection.get("render_target_height_px")
            require(all(type(x) in (float, int) and math.isfinite(x)
                        for x in (px, py, css, dpr, native)),
                    "nonfinite 3D label geometry")
            require(.10 <= px <= .90 and .10 <= py <= .85 and css >= 12.0,
                    "3D label outside camera safe area or less than 12 CSS pixels")
            require(1.0 <= dpr <= 4.5 and abs(native / dpr - css) <= .15,
                    "render target pixels do not match actual device pixel ratio")
            image_path = screens / f"w12-{device}-fault-{idx + 1}-active.png"
            require(image_path.is_file() and image_path.stat().st_size >= 30_000,
                    "missing or suspiciously small original screenshot " + image_path.name)
            raw = image_path.read_bytes()
            digest = hashlib.sha256(raw).hexdigest()
            with Image.open(image_path) as opened:
                opened.verify()
            with Image.open(image_path) as opened:
                im = opened.convert("RGB")
            w, h = im.size
            require((360 <= w <= 500 and h >= 700 and h > w * 1.4) if mobile
                    else (w >= 1000 and h >= 600 and w > h * 1.3),
                    "screenshot is not the tested browser viewport")
            area = im.crop((0, round(h * .14), w, round(h * .72)))
            # Secondary nonblank scene proof: visible amber diagnostic glyphs
            # and equipment light. It does not read or understand the caption.
            amber = sum(1 for r, g, b in area.getdata()
                        if r >= 130 and g >= 80 and b < 150
                        and r > g * 1.08 and g > b * 1.25)
            require(amber >= (90 if mobile else 250),
                    "missing warm diagnostic/scene pixels outside HUD")
            filenames[image_path.name] = digest
            cases.append({
                "device": device, "fault": fault, "cleared_count": case["cleared"],
                "score": case["score"], "errors": case["errors"],
                "caption_css_height": css, "sha256": digest,
                "screenshot_pixels": [w, h], "amber_scene_pixels": amber,
            })
    require(len(set(filenames.values())) == 4,
            "different diagnostic cases reused the same image bytes")
    return {
        "status": "PASS", "source": "four original screenshots and two per-device reports",
        "cases": cases,
        "limitations": ("Color heuristic and camera geometry do not replace human visual "
                        "review, physical mobile hardware, OCR or real GPU performance."),
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--screens", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    options = parser.parse_args()
    report = audit(options.screens)
    options.output.parent.mkdir(parents=True, exist_ok=True)
    options.output.write_text(json.dumps(report, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print("R135 W12 full case evidence PASS: 4 authentic PNGs, 2 reports, measured caption size")
    for case in report["cases"]:
        print(case["device"], case["fault"], "css-label", case["caption_css_height"],
              "amber", case["amber_scene_pixels"], "SHA256", case["sha256"])


if __name__ == "__main__":
    main()
