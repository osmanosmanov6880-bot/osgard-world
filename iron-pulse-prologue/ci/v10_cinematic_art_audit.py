#!/usr/bin/env python3
"""V10: objective image-region acceptance of REAL exported Godot Chromium art.

This is NOT a substitute for human art direction and does not generate, touch up,
composite, or modify screenshots. It audits raw pixels of the same camera shot.
Baseline constants are from verified V9 source e435387f, image 1366x768,
with 12,858 saturated cyan pixels in the 200x310 central roof ROI and a
270-pixel-long vertical cyan column obscuring the center of the reactor.
"""
import argparse
import json
from pathlib import Path

from PIL import Image

OLD_V9_CENTER_ROOF_CYAN_PIXELS = 12858
OLD_V9_TALLEST_NEON_COLUMN = 270


def examine(path: Path):
    img = Image.open(path).convert("RGB")
    width, height = img.size
    if (width, height) != (1366, 768):
        raise AssertionError(f"Real A7 screenshot dimensions changed: {width}x{height}")
    col_counts = []
    total = 0
    for x in range(650, 850):
        cyan = 0
        for y in range(0, 310):
            r, g, b = img.getpixel((x, y))
            if r < 100 and g > 180 and b > 175:
                cyan += 1
        col_counts.append(cyan)
        total += cyan
    peak = max(col_counts)
    lit = 0
    sample = 0
    for y in range(270, 455):
        for x in range(560, 810):
            sample += 1
            if max(img.getpixel((x, y))) > 65:
                lit += 1
    valid_ratio = lit / max(1, sample)
    result = {
        "source": "REAL Godot 4.4.1 Chromium A7 security camera screenshot",
        "roi": [650, 0, 200, 310],
        "baseline_v9_neon_pixels": OLD_V9_CENTER_ROOF_CYAN_PIXELS,
        "current_v10_neon_pixels": total,
        "baseline_v9_max_cyan_column_pixels": OLD_V9_TALLEST_NEON_COLUMN,
        "current_v10_max_cyan_column_pixels": peak,
        "core_readable_fraction": round(valid_ratio, 4),
        "better_than_v9_by_pixels": total < OLD_V9_CENTER_ROOF_CYAN_PIXELS,
        "human_art_approval": False,
        "physical_hardware_certified": False,
    }
    return result


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--evidence", required=True, type=Path)
    ns = p.parse_args()
    target = ns.evidence / "cinematic-reactor-desktop.png"
    if not target.exists():
        raise FileNotFoundError(f"NO real cinematic Godot screenshot: {target}")
    result = examine(target)
    result["status"] = "PASS" if (
        result["current_v10_neon_pixels"] <= 10029
        and result["current_v10_max_cyan_column_pixels"] <= 210
        and result["core_readable_fraction"] >= 0.35
    ) else "FAIL"
    out = ns.evidence / "v10-cinematic-art-audit.json"
    out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(json.dumps(result, indent=2))
    if result["status"] != "PASS":
        raise AssertionError("V10 genuine reactor frame still has overwhelming cyan light bar or blacked-out core")


if __name__ == "__main__":
    main()
