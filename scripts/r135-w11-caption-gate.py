#!/usr/bin/env python3
"""Validate actual R135 WebGL optical-caption pixels outside the Godot HUD.

Fixed RGB heuristic for composition only. NOT real-phone performance, OCR,
photorealism or a substitute for a human review of original screenshots.
"""
import argparse
import json
from pathlib import Path
from PIL import Image


def check(image_path: Path, portrait: bool) -> dict:
    with Image.open(image_path) as raw:
        rgb = raw.convert("RGB")
    w, h = rgb.size
    if portrait:
        if not (w >= 360 and h >= 700 and h / w >= 1.4):
            raise ValueError("Portrait PNG geometry invalid")
        roi = (.37, .20, .83, .30)
        threshold = 60
    else:
        if not (w >= 900 and h >= 540 and w / h > 1.3):
            raise ValueError("Desktop PNG geometry invalid")
        roi = (.44, .26, .83, .38)
        threshold = 160
    x0, y0, x1, y1 = roi
    region = rgb.crop((int(w*x0), int(h*y0), int(w*x1), int(h*y1)))
    pixels = region.load()
    warm = 0
    for y in range(region.height):
        for x in range(region.width):
            r, g, b = pixels[x, y]
            if r > 150 and g > 100 and b < 145 and r > g*1.08 and g > b*1.3:
                warm += 1
    return {
        "image": image_path.name, "size": [w, h], "roi": roi,
        "warm_caption_pixels": warm,
        "minimum_caption_pixels": threshold,
        "passes": warm >= threshold,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--portrait", type=Path, required=True)
    parser.add_argument("--desktop", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    options = parser.parse_args()
    captures = [check(options.portrait, True), check(options.desktop, False)]
    report = {
        "status": "PASS" if all(c["passes"] for c in captures) else "FAIL",
        "checks": captures,
        "limitations": "RGB caption location only; no reading accuracy, hardware FPS or AAA certification",
    }
    options.output.parent.mkdir(parents=True, exist_ok=True)
    options.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))
    if report["status"] != "PASS":
        raise SystemExit("R135 optical fault caption not visible outside HUD")


if __name__ == "__main__":
    main()
