#!/usr/bin/env python3
"""Acquire REAL CC0 scanned PBR maps from Poly Haven for R6 native desktop.
No image generation or synthetic substitute is passed off as photogrammetry.
Fails closed if API/file hashes/maps change. Uses only 2K JPEG/PNG variants.
Source: https://polyhaven.com/license ; API https://api.polyhaven.com
"""
from __future__ import annotations
import argparse, hashlib, json, re, sys, urllib.parse, urllib.request
from pathlib import Path
from PIL import Image

ASSETS = {
    "asphalt_05": {"purpose": "road asphalt", "map_keys": ["diffuse", "nor_gl", "rough"]},
    "concrete_floor_02": {"purpose": "sidewalk slabs and kerbstones", "map_keys": ["diffuse", "nor_gl", "rough"]},
    "painted_plaster_wall": {"purpose": "civic plaster / exterior facade", "map_keys": ["diffuse", "nor_gl", "rough"]},
}
DOWNLOAD_HOSTS = {"dl.polyhaven.org", "cdn.polyhaven.com"}

def get_json(url):
    req = urllib.request.Request(url, headers={"User-Agent": "OSGARD-Horizon-CC0Importer/1.0", "Accept": "application/json"})
    with urllib.request.urlopen(req, timeout=35) as response:
        return json.load(response)

def file_variant(record, resolution: str):
    if not isinstance(record, dict):
        raise ValueError("Expected Poly Haven map/format object")
    sizes = {str(k).lower(): v for k, v in record.items()}
    options = sizes.get(resolution.lower())
    if not isinstance(options, dict):
        raise ValueError(f"Requested {resolution} unavailable; sizes={list(sizes)}")
    # Prefer JPEG where it exists to avoid excessively large lossless files.
    for ext in ("jpg", "png"):
        candidate = next((v for k,v in options.items() if str(k).lower() == ext), None)
        if isinstance(candidate, dict) and candidate.get("url") and candidate.get("md5"):
            return ext, candidate
    raise ValueError("No 2K JPG/PNG variant with API MD5: " + str(list(options)))

def find_map(files, map_key):
    for key, value in files.items():
        if str(key).lower() == map_key:
            return value
    raise ValueError("Missing PBR map: " + map_key + "; available=" + str(list(files)))

def download(url, path: Path, md5, expected_size):
    parsed = urllib.parse.urlparse(url)
    if parsed.scheme != "https" or parsed.hostname not in DOWNLOAD_HOSTS:
        raise ValueError("Unexpected asset CDN URL: " + url)
    path.parent.mkdir(parents=True, exist_ok=True)
    result = hashlib.md5()
    sha = hashlib.sha256()
    size = 0
    req = urllib.request.Request(url, headers={"User-Agent": "OSGARD-Horizon-CC0Importer/1.0"})
    with urllib.request.urlopen(req, timeout=90) as stream, path.open("wb") as target:
        for data in iter(lambda: stream.read(1024 * 1024), b""):
            size += len(data)
            if size > 40 * 1024 * 1024:
                raise ValueError("Single 2K texture exceeds safety size limit")
            result.update(data)
            sha.update(data)
            target.write(data)
    if result.hexdigest().lower() != str(md5).lower():
        path.unlink(missing_ok=True)
        raise ValueError("Photogrammetry asset MD5 mismatch: " + path.name)
    if expected_size and size != int(expected_size):
        path.unlink(missing_ok=True)
        raise ValueError("Poly Haven download file size mismatch: " + path.name)
    with Image.open(path) as image:
        image.verify()
    with Image.open(path) as image:
        width, height = image.size
    if width < 1024 or height < 1024 or width > 4096 or height > 4096:
        raise ValueError(f"Not valid PBR image dimensions: {width} x {height}")
    return {"sha256": sha.hexdigest(), "md5": result.hexdigest(), "bytes": size, "width": width, "height": height}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path("godot/empire-omega/assets/r6/polyhaven"))
    parser.add_argument("--resolution", choices=("1k", "2k"), default="2k")
    args = parser.parse_args()
    output = args.output
    output.mkdir(parents=True, exist_ok=True)
    provenance = {"engine": "OSGARD Horizon R6", "license": "CC0",
        "license_url": "https://polyhaven.com/license",
        "API": "https://api.polyhaven.com",
        "downloaded_by": "deterministic authenticated Poly Haven official API map metadata",
        "resolution": args.resolution, "assets": {}}
    for slug, cfg in ASSETS.items():
        meta = get_json("https://api.polyhaven.com/info/" + slug)
        if int(meta.get("type", -1)) != 1:
            raise ValueError("Wrong asset type for " + slug)
        api_files = get_json("https://api.polyhaven.com/files/" + slug)
        assets = {}
        for key in cfg["map_keys"]:
            ext, data = file_variant(find_map(api_files, key), args.resolution)
            dst = output / slug / (key + "." + ext)
            entry = download(str(data["url"]), dst, data["md5"], data.get("size"))
            entry.update({"path": dst.relative_to(output).as_posix(), "source_url": data["url"], "type": key})
            assets[key] = entry
            print("CC0 MAP", slug, key, entry["width"], entry["height"], entry["sha256"][:16], flush=True)
        provenance["assets"][slug] = {"page": "https://polyhaven.com/a/" + slug,
            "author": meta.get("authors", {}), "purpose": cfg["purpose"], "maps": assets,
            "source_files_hash": meta.get("files_hash", "")}
    with (output / "MANIFEST_CC0.json").open("w", encoding="utf8") as stream:
        json.dump(provenance, stream, indent=2, ensure_ascii=False)
    print("R6 REAL_PHOTOGRAMMETRIC_MAPS:", sum(len(v["maps"]) for v in provenance["assets"].values()), "PASS", flush=True)

if __name__ == "__main__":
    main()
