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


def validate(archive: Path, manifest_path: Path, portrait: Path,
             expected_version: str, expected_source: str) -> dict:
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
    check(len(header) == 24 and header[:8] == b"\\x89PNG\\r\\n\\x1a\\n"
          and header[12:16] == b"IHDR", "not a genuine PNG screenshot")
    width, height = struct.unpack(">II", header[16:24])
    check(width >= 600 and height >= 1000 and height / width >= 1.4,
          "portrait screenshot dimensions not credible")
    check(archive.stat().st_size < 135_000_000,
          "candidate exceeds reviewed transfer budget")

    archive_hash, _ = hash_stream(archive.open("rb"))
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
        "hardware_gpu_fps_certified": False,
        "real_phone_thermals_certified": False,
        "simulated_equipment_only": True,
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--archive", type=Path, required=True)
    p.add_argument("--manifest", type=Path, required=True)
    p.add_argument("--portrait", type=Path, required=True)
    p.add_argument("--expected-version", required=True)
    p.add_argument("--expected-source", required=True)
    p.add_argument("--output", type=Path, required=True)
    args = p.parse_args()
    summary = validate(args.archive, args.manifest, args.portrait,
                       args.expected_version, args.expected_source)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(summary, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
