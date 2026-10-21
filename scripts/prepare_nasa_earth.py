#!/usr/bin/env python3
"""Build self-hosted OSGARD Earth texture tiers from credited NASA imagery.

Outputs are committed by a GitHub Actions workflow, never fetched from NASA by
site visitors. Inputs:
- NASA Earth Observatory Blue Marble Next Generation, July 2004 (global, 5400x2700).
- NASA Earth Observatory Black Marble 2016 nighttime, 0.1 degree (3600x1800).
- Natural Earth public-domain land polygon outlines already stored in repo.

This is a historical composite, not live Earth imagery.
"""
from __future__ import annotations

import hashlib
import io
import json
import os
import pathlib
import time
import urllib.request
from PIL import Image, ImageDraw, ImageFilter, ImageOps

ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "public" / "brand" / "earth"
COAST = ROOT / "public" / "brand" / "omega-earth-land.json"
SOURCES = {
    "surface": {
        "url": "https://assets.science.nasa.gov/content/dam/science/esd/eo/images/bmng/bmng-base/july/world.200407.3x5400x2700.jpg",
        "minimum": (5400, 2700),
        "credit": "NASA Earth Observatory / Blue Marble: Next Generation, July 2004",
    },
    "night": {
        "url": "https://assets.science.nasa.gov/content/dam/science/esd/eo/images/imagerecords/144000/144898/BlackMarble_2016_01deg.jpg",
        "minimum": (3600, 1800),
        "credit": "NASA Earth Observatory / Black Marble nighttime composites, 2016",
    },
}


def download(name: str, spec: dict) -> tuple[Image.Image, str]:
    request = urllib.request.Request(spec["url"], headers={
        "User-Agent": "OSGARD-Earth-Asset-Builder/1.0 (static asset preparation; attribution included)",
        "Accept": "image/jpeg,image/*;q=0.8",
    })
    last_error = None
    for attempt in range(3):
        try:
            with urllib.request.urlopen(request, timeout=75) as response:
                mime = response.headers.get("Content-Type", "").lower()
                if "image" not in mime and "octet-stream" not in mime:
                    raise RuntimeError(f"{name}: unexpected content type {mime!r}")
                raw = response.read(32 * 1024 * 1024 + 1)
            if len(raw) > 32 * 1024 * 1024:
                raise RuntimeError(f"{name}: download larger than 32 MB")
            image = Image.open(io.BytesIO(raw))
            image.load()
            image = image.convert("RGB")
            if image.width < spec["minimum"][0] or image.height < spec["minimum"][1]:
                raise RuntimeError(f"{name}: invalid resolution {image.size}")
            if image.width != image.height * 2:
                raise RuntimeError(f"{name}: expected global 2:1 equirectangular image")
            print(f"{name}: {image.size}, raw={len(raw):,}, sha256={hashlib.sha256(raw).hexdigest()}")
            return image, hashlib.sha256(raw).hexdigest()
        except Exception as e:
            last_error = e
            print(f"Attempt {attempt + 1} for {name} failed: {e}")
            if attempt < 2:
                time.sleep((attempt + 1) * 3)
    raise RuntimeError(f"{name}: trusted NASA download failed") from last_error


def webp(image: Image.Image, path: pathlib.Path, *, quality: int = 86):
    image.save(path, format="WEBP", quality=quality, method=6, exact=True)
    with Image.open(path) as check:
        if check.size != image.size:
            raise RuntimeError(f"{path.name}: encoded dimensions changed")
        check.verify()
    size = path.stat().st_size
    if size > 3 * 1024 * 1024:
        raise RuntimeError(f"{path.name}: above hard 3 MB budget ({size} bytes)")
    return {
        "file": path.name,
        "width": image.width,
        "height": image.height,
        "bytes": size,
        "sha256": hashlib.sha256(path.read_bytes()).hexdigest(),
    }


def create_roughness(width: int) -> Image.Image:
    """Sea roughness ~0.25; land roughness ~0.85, with land geometry from Natural Earth."""
    polygons = json.loads(COAST.read_text(encoding="utf-8"))["polygons"]
    height = width // 2
    image = Image.new("L", (width, height), 68)
    draw = ImageDraw.Draw(image)
    for polygon in polygons:
        for index, ring in enumerate(polygon):
            if len(ring) < 4:
                continue
            # Avoid filling the entire world for polygons crossing the +/-180 meridian.
            pieces = []
            current = [ring[0]]
            for point in ring[1:]:
                if abs(point[0] - current[-1][0]) > 180:
                    if len(current) >= 3:
                        pieces.append(current)
                    current = [point]
                else:
                    current.append(point)
            if len(current) >= 3:
                pieces.append(current)
            for segment in pieces:
                points = [((lon + 180) * width / 360, (90 - lat) * height / 180) for lon, lat in segment]
                if len(points) >= 3:
                    draw.polygon(points, fill=221 if index == 0 else 68)
    return image.filter(ImageFilter.GaussianBlur(width / 2048))


def create_city_lights(image: Image.Image, width: int) -> Image.Image:
    """Isolate bright settlement emissions from the 2016 NASA Black Marble composite."""
    reduced = image.resize((width, width // 2), Image.Resampling.LANCZOS)
    gray = ImageOps.grayscale(reduced)
    # Arctic land / unlit infrastructure should not become artificial city lights.
    threshold = gray.point(lambda x: min(255, max(0, round((x - 88) * 2.8))))
    return Image.merge("RGB", (threshold, threshold, threshold))


def build() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    surface, surface_sha = download("surface", SOURCES["surface"])
    night, night_sha = download("night", SOURCES["night"])
    results = []
    for width, quality in [(512, 79), (1024, 81), (2048, 85), (4096, 88)]:
        image = surface.resize((width, width // 2), Image.Resampling.LANCZOS)
        results.append(webp(image, OUT / f"blue-marble-{width}.webp", quality=quality))
    # Cities only need one medium-resolution light-map; the sun shader masks the day side.
    results.append(webp(create_city_lights(night, 2048), OUT / "black-marble-lights-2048.webp", quality=87))
    results.append(webp(create_roughness(2048), OUT / "earth-roughness-2048.webp", quality=91))
    total = sum(item["bytes"] for item in results)
    if total > 7 * 1024 * 1024:
        raise RuntimeError(f"Earth texture bundle too large: {total} bytes")
    manifest = {
        "version": 1,
        "mode": "self-hosted",
        "timeframe": "July 2004 surface / 2016 night lights",
        "not_live_data": True,
        "credit": "NASA Earth Observatory; Reto Stoeckli, Robert Simmon and NASA MODIS / VIIRS teams",
        "source": {key: {"url": value["url"], "sha256": (surface_sha if key == "surface" else night_sha)} for key, value in SOURCES.items()},
        "generated": results,
        "bundle_bytes": total,
    }
    (OUT / "manifest.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"textures": len(results), "total_bytes": total, "manifest": str(OUT / "manifest.json")}, indent=2))


if __name__ == "__main__":
    build()
