#!/usr/bin/env python3
"""Fail-closed OSGARD R135 candidate evidence gate.

This validates the actual exported Godot Web binaries and a real portrait
screenshot without claiming physical-device hardware/thermal certification.
The CI build's own manifest is not a third-party signature; promotion must
later pin its independently reviewed SHA-256 digest.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import math
import struct
import zipfile
from pathlib import Path


def check(test: bool, message: str) -> None:
    if not test:
        raise ValueError("R135 W10 release rejected: " + message)


def hash_stream(stream) -> tuple[str, int]:
    digest = hashlib.sha256()
    size = 0
    for chunk in iter(lambda: stream.read(1024 * 1024), b""):
        size += len(chunk)
        digest.update(chunk)
    return digest.hexdigest(), size


def portrait_capture_proof(path: Path, screenshot: Path,
                           width: int, height: int) -> dict:
    """Cross-check authentic PNG bytes, CSS viewport and actual Godot render target.

    CDP screenshots may encode CSS pixels on high-DPR handsets (412x839),
    even while Godot renders 1081x2202 actual pixels. Do not upsample or
    silently drop the former 600x1000 viewport requirement: accept the smaller
    capture ONLY with verified high-resolution live canvas geometry.
    """
    check(path.is_file(), "live Chromium canvas provenance JSON missing")
    proof = json.loads(path.read_text(encoding="utf-8"))
    check(isinstance(proof, dict), "invalid screenshot provenance JSON")
    check(proof.get("screenshot_sha256") == hashlib.sha256(screenshot.read_bytes()).hexdigest(),
          "screenshot/provenance sha256 mismatch")
    # Source helper uses actual Page.screencastFrame compositor PNG (R53),
    # or authenticated CDP viewport, Godot canvas readback and Playwright.
    # All paths MUST still satisfy exact PNG checksum + physical CSS/DPR/canvas
    # geometry and visible simulated optical target; never allow generated art.
    check(proof.get("capture_method") in
          ("chromium-cdp", "chromium-cdp-screencast", "chromium-cdp-view",
           "chromium-canvas-readback", "playwright-viewport"),
          "not a trusted WebGL screenshot capture path")
    check(proof.get("scene_ready") is True and proof.get("view") == 2
          and proof.get("camera_target_visible") is True
          and proof.get("active_caption_depth_override") is True
          and proof.get("fault_label_visible_count") == 1
          and proof.get("loading_failures") == 0,
          "portrait capture was not the active readable Godot optical fault")

    def pair(field: str) -> tuple[float, float]:
        items = proof.get(field)
        check(isinstance(items, list) and len(items) == 2
              and all(type(v) in (int, float) and math.isfinite(v) and v > 0
                      for v in items), "invalid capture geometry: " + field)
        return float(items[0]), float(items[1])

    capture_w, capture_h = pair("screenshot_pixels")
    css_w, css_h = pair("css_viewport")
    canvas_w, canvas_h = pair("canvas_pixels")
    element_w, element_h = pair("canvas_css")
    dpr = proof.get("device_pixel_ratio")
    check(type(dpr) in (int, float) and math.isfinite(dpr) and 1.4 <= dpr <= 4.5,
          "high-DPR capture lacks valid device pixel ratio")
    check((capture_w, capture_h) == (width, height),
          "PNG header does not match reported screenshot geometry")
    check(width >= 360 and height >= 700 and height / width >= 1.4,
          "portrait screenshot dimensions not credible")
    check(canvas_w >= 600 and canvas_h >= 1000 and canvas_h / canvas_w >= 1.4,
          "real Godot WebGL render target too small")
    check(abs(element_w / css_w - 1.0) <= .06 and abs(element_h / css_h - 1.0) <= .06,
          "Godot canvas not filling CSS viewport")
    check(abs(canvas_w / (element_w * dpr) - 1.0) <= .08
          and abs(canvas_h / (element_h * dpr) - 1.0) <= .08,
          "claimed canvas resolution does not match devicePixelRatio")
    css_capture = abs(width / css_w - 1.0) <= .06 and abs(height / css_h - 1.0) <= .06
    pixel_capture = (abs(width / canvas_w - 1.0) <= .06
                     and abs(height / canvas_h - 1.0) <= .06)
    check(css_capture or pixel_capture,
          "screenshot does not match live CSS viewport OR native canvas pixels")
    return {
        "capture_method": proof["capture_method"],
        "capture_coordinates": "css" if css_capture else "render_target",
        "css_viewport": [css_w, css_h],
        "canvas_pixels": [canvas_w, canvas_h],
        "device_pixel_ratio": dpr,
        "sha256": proof["screenshot_sha256"],
    }


def validate(archive: Path, manifest_path: Path, portrait: Path,
             expected_version: str, expected_source: str,
             portrait_evidence: Path | None = None) -> dict:
    check(archive.is_file() and archive.stat().st_size > 10_000_000,
          "missing genuine archive")
    check(manifest_path.is_file(), "manifest missing")
    manifest_bytes = manifest_path.read_bytes()
    manifest = json.loads(manifest_bytes)
    manifest_hash = hashlib.sha256(manifest_bytes).hexdigest()
    check(manifest.get("version") == expected_version, "wrong build version")
    check(manifest.get("source_commit") == expected_source, "wrong source commit")
    check(manifest.get("engine") == "Godot 4.4.1", "engine not verified")
    check(manifest.get("native_tests") == "passed", "native smoke missing")
    check(manifest.get("webgl_browser_software_smoke") == "passed",
          "real browser gameplay smoke missing")
    check(manifest.get("original_glbs_preserved") is True,
          "HERO/ECO source assets not proven")
    files = manifest.get("files")
    required = {"index.html", "index.js", "index.wasm",
                "index.wasm.gz", "index.pck"}
    check(isinstance(files, dict) and required.issubset(files),
          "critical Godot binaries absent from manifest")
    check(10_000_000 < int(manifest.get("optimized_pck_bytes", 0)) < 100_000_000,
          "PCK exceeds validated budget")

    asset_hashes = {}
    with zipfile.ZipFile(archive) as bundle:
        names = bundle.namelist()
        check(len(names) == len(set(names)), "duplicate ZIP members")
        check(set(names) == set(files.keys()) | {"release.json"},
              "unaccounted ZIP members")
        check(bundle.read("release.json") == manifest_bytes,
              "embedded manifest differs from reviewed bytes")
        for member in bundle.infolist():
            check(member.filename == Path(member.filename).name
                  and not member.is_dir()
                  and not (member.flag_bits & 1),
                  "unsafe or encrypted ZIP member")
            check(member.file_size < 120_000_000, "oversized ZIP member")
            if member.filename == "release.json":
                continue
            ref = files[member.filename]
            with bundle.open(member) as source:
                digest, size = hash_stream(source)
            check(digest == ref.get("sha256"), "wrong asset sha256: " + member.filename)
            check(size == ref.get("size_bytes"), "wrong asset size: " + member.filename)
            asset_hashes[member.filename] = digest
        with bundle.open("index.wasm.gz") as wrapped:
            with gzip.GzipFile(fileobj=wrapped) as decoded:
                uncompressed_digest, uncompressed_size = hash_stream(decoded)
        check(uncompressed_digest == asset_hashes["index.wasm"],
              "compressed WASM is not the genuine engine file")
        check(uncompressed_size == files["index.wasm"]["size_bytes"],
              "wrong decompressed WASM length")

    raw_size = int(files["index.wasm"]["size_bytes"])
    gz_size = int(files["index.wasm.gz"]["size_bytes"])
    check(gz_size < raw_size * .70, "WASM compression below transfer budget")
    check(portrait.is_file(), "real portrait Chromium screenshot missing")
    with portrait.open("rb") as image:
        header = image.read(24)
    check(len(header) == 24 and header[:8] == b"\x89PNG\r\n\x1a\n"
          and header[12:16] == b"IHDR", "not a genuine PNG screenshot")
    width, height = struct.unpack(">II", header[16:24])
    if portrait_evidence is None:
        # W10 backward-compatible strict mode. No unverified DPR exception.
        check(width >= 600 and height >= 1000 and height / width >= 1.4,
              "portrait screenshot dimensions not credible")
        capture_provenance = None
    else:
        capture_provenance = portrait_capture_proof(portrait_evidence, portrait, width, height)
    check(archive.stat().st_size < 135_000_000,
          "candidate exceeds reviewed transfer budget")

    with archive.open("rb") as package:
        archive_hash, _ = hash_stream(package)
    return {
        "status": "PASS",
        "mode": "Godot 4.4.1 genuine browser archive / software GPU QA",
        "version": expected_version,
        "source_commit": expected_source,
        "manifest_sha256": manifest_hash,
        "archive_sha256": archive_hash,
        "archive_bytes": archive.stat().st_size,
        "verified_asset_count": len(asset_hashes),
        "pck_bytes": files["index.pck"]["size_bytes"],
        "wasm_gzip_bytes": gz_size,
        "portrait_pixels": [width, height],
        "portrait_capture_provenance": capture_provenance,
        "hardware_gpu_fps_certified": False,
        "real_phone_thermals_certified": False,
        "simulated_equipment_only": True,
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--archive", type=Path, required=True)
    p.add_argument("--manifest", type=Path, required=True)
    p.add_argument("--portrait", type=Path, required=True)
    p.add_argument("--portrait-evidence", type=Path,
                   help="live browser geometry proof for CDP CSS-pixel screenshots")
    p.add_argument("--expected-version", required=True)
    p.add_argument("--expected-source", required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    summary = validate(args.archive, args.manifest, args.portrait,
                       args.expected_version, args.expected_source,
                       args.portrait_evidence)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
