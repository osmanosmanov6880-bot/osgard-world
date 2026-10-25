#!/usr/bin/env python3
"""R135 W11: fail a WebGL release if real machine pixels are nearly black.

Samples consistent non-HUD regions in actual Chromium screenshots. Does NOT
measure aesthetics, photorealism, physical-device FPS, or reading accuracy.
"""
from __future__ import annotations

import argparse
import json
from pathlib import Path
from PIL import Image


def band(image: Path, roi: tuple[float, float, float, float]) -> dict:
    with Image.open(image) as raw:
        rgb = raw.convert("RGB")
    width, height = rgb.size
    left, top, right, bottom = roi
    cropped = rgb.crop((int(width*left), int(height*top),
                        int(width*right), int(height*bottom)))
    hist = cropped.convert("L").histogram()
    count = sum(hist)
    cumulative = 0
    median = 0
    for v, n in enumerate(hist):
        cumulative += n
        if cumulative >= count // 2:
            median = v
            break
    dark_fraction = sum(hist[:40]) / count
    return {
        "image": image.name,
        "screen": [width, height],
        "roi_normalized": list(roi),
        "median_luma_255": median,
        "dark_fraction_below_40": round(dark_fraction, 4),
    }


def main() -> None:
    args = argparse.ArgumentParser()
    args.add_argument("--portrait", type=Path, required=True)
    args.add_argument("--desktop", type=Path, required=True)
    args.add_argument("--output", type=Path, required=True)
    opt = args.parse_args()
    portrait = band(opt.portrait, (.20, .32, .82, .66))
    desktop = band(opt.desktop, (.20, .32, .82, .66))
    portrait["passes"] = portrait["median_luma_255"] >= 28 and portrait["dark_fraction_below_40"] <= .82
    desktop["passes"] = desktop["median_luma_255"] >= 30 and desktop["dark_fraction_below_40"] <= .58
    data = {
        "status": "PASS" if portrait["passes"] and desktop["passes"] else "FAIL",
        "check": "actual WebGL screenshot readability / fixed non-HUD ROI",
        "source": "SwiftShader Chromium, not real physical GPU",
        "checks": [portrait, desktop],
        "w10_baseline": {
            "portrait_median_luma_255": 10,
            "portrait_dark_fraction_below_40": 1.0,
            "desktop_median_luma_255": 26,
            "desktop_dark_fraction_below_40": .581,
        },
        "limitations": "Luma does not prove readable copy, art quality or AAA-grade rendering",
    }
    opt.output.parent.mkdir(parents=True, exist_ok=True)
    opt.output.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(data, indent=2))
    if data["status"] != "PASS":
        raise SystemExit("W11 actual WebGL render is still too dark")


if __name__ == "__main__":
    main()
