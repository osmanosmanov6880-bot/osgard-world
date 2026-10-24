#!/usr/bin/env python3
"""Fixed-RGB composition gate on a real Godot portrait WebGL screenshot.

Tests geometry distribution only. This is not a photorealism or hardware-FPS test.
"""
from __future__ import annotations

import json
import sys
from pathlib import Path
from PIL import Image


def metrics(image_path: Path) -> dict:
    image = Image.open(image_path).convert("RGB")
    width, height = image.size
    if height < 700 or width < 600 or height / max(width, 1) < 1.4:
        raise ValueError("Need a real portrait Godot WebGL screenshot")
    left, right = int(width * .15), int(width * .85)
    first, last = int(height * .19), int(height * .75)
    pixels = image.load()
    nonempty_start = None
    total_blue = 0
    for y in range(first, last):
        row_blue = 0
        for x in range(left, right):
            r, g, b = pixels[x, y]
            if b > 55 and b > 1.2 * r and g > 1.05 * r and r < 140:
                row_blue += 1
        total_blue += row_blue
        if nonempty_start is None and row_blue > (right - left) * .13:
            nonempty_start = y
    fraction = nonempty_start / height if nonempty_start is not None else None
    coverage = total_blue / ((right - left) * (last - first))
    # The active 3D fault caption must appear above the upper beam,
    # in a defined portrait safe band, not behind the machine or HUD.
    caption_pixels = 0
    for y in range(int(height * .20), int(height * .24)):
        for x in range(int(width * .28), int(width * .78)):
            r, g, b = pixels[x, y]
            if r > 150 and 35 < g < 175 and b < 105 and r > g * 1.45:
                caption_pixels += 1
    passes = (fraction is not None and .19 < fraction <= .36 and
              coverage >= .16 and caption_pixels >= 280)
    return {
        "image": image_path.name,
        "width": width,
        "height": height,
        "first_structure_fraction": round(fraction, 4) if fraction is not None else None,
        "blue_geometry_coverage": round(coverage, 4),
        "fault_caption_orange_pixels": caption_pixels,
        "requirements": {
            "first_structure_fraction_max": .36,
            "blue_geometry_coverage_min": .16,
            "fault_caption_orange_pixels_min": 280
        },
        "status": "PASS" if passes else "FAIL",
        "caution": "Fixed RGB heuristic detects industrial scene occupancy, not visual art quality or FPS"
    }


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: python scripts/r135-pixel-composition-qa.py screenshot.png")
    result = metrics(Path(sys.argv[1]))
    print(json.dumps(result, indent=2, ensure_ascii=False))
    if result["status"] != "PASS":
        raise SystemExit("R135 portrait optical scene fails geometry occupancy gate")
