#!/usr/bin/env python3
"""Build local, verifiable Earth textures from the NASA SVS 4096px hemispheres.
NASA/Goddard SVS 2915 Blue Marble / 2916 Earth at Night; retain credits.
Image outputs are derived, static visualization assets, not live satellite images.
The script is idempotent and fails closed on missing/non-image data.
"""
from __future__ import annotations

import hashlib
import json
import os
from pathlib import Path
from urllib.request import Request, urlopen

from PIL import Image, ImageEnhance, ImageOps

ROOT = Path(__file__).resolve().parent.parent
DEST = ROOT / "public" / "brand"
CACHE = ROOT / ".omega-nasa-cache"
ROOT_URL = "https://svs.gsfc.nasa.gov/vis/a000000/a002900"
INPUTS = {
    "day-west": (f"{ROOT_URL}/a002915/bluemarble-west-4096.png", (4096, 4096)),
    "day-east": (f"{ROOT_URL}/a002915/bluemarble-east-4096.png", (4096, 4096)),
    "night-west": (f"{ROOT_URL}/a002916/west-4096.png", (4096, 4096)),
    "night-east": (f"{ROOT_URL}/a002916/east-4096.png", (4096, 4096)),
}
MAX_SOURCE_BYTES = 25_000_000


def digest(blob: bytes) -> str:
    return hashlib.sha256(blob).hexdigest()


def acquire(name: str, url: str, dimensions: tuple[int, int]) -> tuple[Image.Image, dict]:
    CACHE.mkdir(parents=True, exist_ok=True)
    filename = CACHE / f"{name}.png"
    if not filename.exists():
        with urlopen(Request(url, headers={"User-Agent": "OSGARD-NASA-public-visualization/1.0"}), timeout=75) as response:
            size = response.headers.get("Content-Length")
            if size and int(size) > MAX_SOURCE_BYTES:
                raise RuntimeError(f"{name}: oversized source")
            blob = response.read(MAX_SOURCE_BYTES + 1)
        if len(blob) > MAX_SOURCE_BYTES or not blob.startswith(b"\x89PNG\r\n\x1a\n"):
            raise RuntimeError(f"{name}: unexpected source format or size")
        filename.write_bytes(blob)
    blob = filename.read_bytes()
    if len(blob) > MAX_SOURCE_BYTES:
        raise RuntimeError("Cache source exceeded size budget")
    with Image.open(filename) as img:
        img.load()
        if img.size != dimensions:
            raise ValueError(f"{name}: expected {dimensions}, got {img.size}")
        image = img.convert("RGB")
    return image, {"source": url, "source_bytes": len(blob), "sha256": digest(blob)}


def prepare(day: bool, west: Image.Image, east: Image.Image) -> Image.Image:
    # NASA 4096 hemispheres: western longitudes -180..0, eastern 0..180.
    # Compose the global equirectangular map and reduce to 4096x2048.
    world = Image.new("RGB", (8192, 4096))
    world.paste(west, (0, 0))
    world.paste(east, (4096, 0))
    world = world.resize((4096, 2048), Image.Resampling.LANCZOS)
    if day:
        world = ImageEnhance.Color(world).enhance(1.08)
        world = ImageEnhance.Contrast(world).enhance(1.06)
    else:
        # Remove the purple-toned unlit background, retaining real NASA light patterns.
        world = ImageOps.autocontrast(world, cutoff=1, preserve_tone=True)
        world = ImageEnhance.Contrast(world).enhance(1.28)
    return world


def write_image(image: Image.Image, filename: str, width: int, quality: int) -> dict:
    target = DEST / filename
    target.parent.mkdir(parents=True, exist_ok=True)
    new_size = (width, width // 2)
    resized = image if image.size == new_size else image.resize(new_size, Image.Resampling.LANCZOS)
    resized.save(target, "WEBP", quality=quality, method=6)
    with Image.open(target) as proof:
        proof.verify()
    blob = target.read_bytes()
    if len(blob) > 5_000_000:
        raise RuntimeError(f"{filename}: exceeds 5 MB delivery limit")
    return {"path": "/" + str(target.relative_to(ROOT / "public")), "size": new_size, "bytes": len(blob), "sha256": digest(blob)}


def main() -> None:
    images = {}
    proofs = {}
    for name, (url, dimensions) in INPUTS.items():
        images[name], proofs[name] = acquire(name, url, dimensions)
    daytime = prepare(True, images["day-west"], images["day-east"])
    night = prepare(False, images["night-west"], images["night-east"])
    assets = {
        "day_4k": write_image(daytime, "omega-nasa-day-4k.webp", 4096, 83),
        "day_2k": write_image(daytime, "omega-nasa-day-2k.webp", 2048, 80),
        "day_1k": write_image(daytime, "omega-nasa-day-1k.webp", 1024, 78),
        "night_4k": write_image(night, "omega-nasa-night-4k.webp", 4096, 83),
        "night_2k": write_image(night, "omega-nasa-night-2k.webp", 2048, 80),
        "night_1k": write_image(night, "omega-nasa-night-1k.webp", 1024, 78),
    }
    meta = {
        "edition": "nasa-blue-marble-svs-2004-derived",
        "notes": "Historical composite and artistic contrast enhancement; not realtime",
        "projection": "equirectangular",
        "source_credit": "NASA/Goddard Space Flight Center Scientific Visualization Studio",
        "day_credit": "Blue Marble data courtesy Reto Stockli (NASA/GSFC) and NASA's Earth Observatory",
        "night_credit": "Data Marc Imhoff NASA/GSFC and Christopher Elvidge NOAA/NGDC; image Craig Mayhew and Robert Simmon NASA/GSFC",
        "sources": proofs,
        "assets": assets,
    }
    (DEST / "omega-nasa-manifest.json").write_text(
        json.dumps(meta, ensure_ascii=False, separators=(",", ":"), sort_keys=True) + "\n",
        encoding="utf-8",
    )
    print(json.dumps({"ok": True, "assets": assets}, ensure_ascii=False, indent=2))


if __name__ == "__main__":
    main()
