#!/usr/bin/env python3
"""W66 original visual frame metrics, *not* a human AAA art review.

Measures pixels actually produced by Godot 4.4.1+Chromium, not mockups.
Creates a comparable source-pinned report for subsequent art iteration.
"""
import argparse
import hashlib
import json
import re
from pathlib import Path
from PIL import Image, ImageChops, ImageStat


def require(x, msg):
    if not x:
        raise AssertionError(msg)


def measure(path, clip=None):
    data = path.read_bytes()
    with Image.open(path) as picture:
        require(picture.format == "PNG", "Not an authentic PNG")
        picture = picture.convert("RGB")
        w, h = picture.size
        if clip is None:
            crop = (int(w*0.14), int(h*0.25), int(w*0.86), int(h*0.79))
        else:
            crop = clip
        crop = tuple(map(int, crop))
        require(crop[2] <= w and crop[3] <= h and crop[0] >= 0,
                "Image crop does not match actual Chromium dimensions")
        pixels = picture.crop(crop)
        stat = ImageStat.Stat(pixels)
        return {
            "name": path.name,
            "sha256": hashlib.sha256(data).hexdigest(),
            "width": w, "height": h,
            "sample_rectangle": crop,
            "average_rgb": [round(x, 3) for x in stat.mean],
            "channel_deviation": [round(x, 3) for x in stat.stddev],
        }


def main(folder, exact, output):
    require(re.fullmatch(r"[0-9a-f]{40}", exact or "") is not None, "Exact SHA required")
    first = folder/"1366x900-before.png"
    changed = folder/"1366x900-reactive.png"
    mobile = folder/"390x844-mobile.png"
    for item in (first, changed, mobile):
        require(item.is_file(), "Missing original Chromium screenshot: "+str(item))
    records = [measure(first), measure(changed), measure(mobile,
        (int(390*.10), int(844*.20), int(390*.90), int(844*.61)))]
    require(records[0]["width"] == 1366 and records[0]["height"] == 900,
            "Desktop screenshot not genuine")
    require(records[2]["width"] == 390 and records[2]["height"] == 844,
            "Mobile screenshot not genuine")
    require(max(records[0]["channel_deviation"]) > 8.0,
            "Native 3D region looks blank")
    with Image.open(first) as a, Image.open(changed) as b:
        d = ImageChops.difference(a.convert("RGB"), b.convert("RGB")).convert("L")
        count = sum(d.histogram()[12:])
        require(count >= 150, "Rendered real game did not react to original decision")
    report = {
        "schema": "LAST_FRONTIER_W66_3D_ORIGINAL_PIXEL_QUALITY_REPORT_V1",
        "status": "PASS", "source_sha": exact,
        "real_software_renderer": "Godot 4.4.1 Chromium SwiftShader",
        "original_browser_frames": records,
        "changed_pixels_above_threshold": count,
        "photographic_or_ai_generated_concept_art": False,
        "human_art_approval": False,
        "AAA_claim": False, "physical_GPU_certification": False,
        "published": False,
    }
    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print("LAST FRONTIER W66 ORIGINAL 3D PIXEL EVIDENCE PASS", exact,
          "red_mean", records[0]["average_rgb"][0],
          "changed_pixels", count, "ART HUMAN REVIEW HOLD")


if __name__ == "__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--screens",type=Path,required=True)
    parser.add_argument("--sha",required=True)
    parser.add_argument("--out",type=Path,required=True)
    a=parser.parse_args()
    main(a.screens,a.sha,a.out)
