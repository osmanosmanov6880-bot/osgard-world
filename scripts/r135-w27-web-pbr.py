#!/usr/bin/env python3
"""W27: Web-only faithful downsample of original OSGARD PBR, NEVER external art.

Native Godot keeps the untouched original 1024px PBR maps. WebGL packages
only 12 source-derived 512px PNGs to preserve the <100 MB original PCK budget.
The maps are still true albedo/normal/ORM from the original artist-authored
textures, not placeholders. This script performs no network access or upload.
"""
from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
from PIL import Image

FAMILIES = ("epoxy_floor", "service_paint", "galvanized_steel", "warm_copper")
CHANNELS = ("albedo", "normal", "orm")
SIZE = (512, 512)
MAX_PACKAGED_BYTES = 7_000_000


def generate(project: Path) -> dict:
    originals = project / "textures" / "r135"
    derived = project / "textures" / "r135_web"
    assert originals.is_dir(), "Original 36 source PBR maps are missing"
    assert len(tuple(originals.glob("*.png"))) == 36, "Source texture family changed"
    derived.mkdir(parents=True, exist_ok=True)
    manifest = []
    total_bytes = 0
    for family in FAMILIES:
        for channel in CHANNELS:
            name = f"{family}_{channel}.png"
            src = originals / name
            dst = derived / name
            assert src.is_file(), f"Real source texture is missing: {name}"
            before = hashlib.sha256(src.read_bytes()).hexdigest()
            with Image.open(src) as input_image:
                input_image.verify()
            with Image.open(src) as input_image:
                assert input_image.width >= 1024 and input_image.height >= 1024, (
                    f"{name} is not an original full-resolution source texture")
                image = input_image.convert("RGB").resize(SIZE, Image.Resampling.LANCZOS)
                image.save(dst, format="PNG", optimize=True, compress_level=9)
            with Image.open(dst) as web_image:
                web_image.verify()
            with Image.open(dst) as web_image:
                assert web_image.size == SIZE and web_image.mode == "RGB"
            assert hashlib.sha256(src.read_bytes()).hexdigest() == before, (
                f"Source PNG must be byte-identical after web derivation: {name}")
            length = dst.stat().st_size
            assert length > 1024, f"Empty Web PBR map: {name}"
            total_bytes += length
            manifest.append({
                "filename": name,
                "original_sha256": before,
                "web_sha256": hashlib.sha256(dst.read_bytes()).hexdigest(),
                "source_size": src.stat().st_size,
                "web_size": length,
                "dimensions": list(SIZE)
            })
    assert len(manifest) == 12
    assert len({r["web_sha256"] for r in manifest}) == 12, "Duplicate generated material art"
    assert total_bytes < MAX_PACKAGED_BYTES, (
        f"W27 12 faithful Web source maps exceed mobile transfer budget: {total_bytes}")
    return {
        "schema": "OSGARD_R135_W27_WEB_PBR_V1",
        "derived_original_maps": len(manifest),
        "web_source_bytes": total_bytes,
        "max_web_source_bytes": MAX_PACKAGED_BYTES,
        "originals_unmodified": True,
        "physical_phone_gpu_certified": False,
        "maps": manifest,
    }


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--project", type=Path,
        default=Path("godot/osgard-r135-standalone"))
    args = parser.parse_args()
    report = generate(args.project)
    print(json.dumps(report, ensure_ascii=False))
    print("W27 REAL WEB PBR DERIVATION PASS: 12 original-source maps, 512px, no file replaced")


if __name__ == "__main__":
    main()
