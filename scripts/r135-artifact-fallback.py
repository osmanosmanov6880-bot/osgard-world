#!/usr/bin/env python3
"""Restore a byte-for-byte verified R135 W5 runtime from its existing public host.
Used only when the pinned GitHub Actions artifact has expired. Never trust
unverified server files: the manifest digest was recorded independently at build.
"""
from __future__ import annotations

import gzip
import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import urllib.request
import zipfile

BASE = "https://osgard.world/games/r135-service/"
MANIFEST_SHA256 = "b3e6b721cce1f4e764117cea59e190aaf74b669a26399284b9625bc30cde3219"
SOURCE_SHA = "cd6132fa5d34cbb701957b124a6aa2aac9210434"
VERSION = "r135-web-visual-diagnostics-w5-20261024"


def source_stream(filename: str):
    request = urllib.request.Request(
        BASE + filename,
        headers={"Cache-Control": "no-cache", "Accept-Encoding": "identity"},
    )
    return urllib.request.urlopen(request, timeout=90)


def restore(target: Path) -> None:
    target.mkdir(parents=True, exist_ok=True)
    with source_stream("release.json") as response:
        manifest_bytes = response.read()
    if hashlib.sha256(manifest_bytes).hexdigest() != MANIFEST_SHA256:
        raise ValueError("Public server manifest differs from verified W5 build")
    manifest = json.loads(manifest_bytes)
    if manifest.get("version") != VERSION or manifest.get("source_commit") != SOURCE_SHA:
        raise ValueError("Public server is not the pinned W5 build")
    files = manifest.get("files")
    if not isinstance(files, dict) or not {"index.html", "index.js", "index.wasm", "index.pck"}.issubset(files):
        raise ValueError("W5 asset manifest is incomplete")
    with tempfile.TemporaryDirectory(prefix="r135-recover-") as work:
        root = Path(work)
        (root / "release.json").write_bytes(manifest_bytes)
        for name, detail in sorted(files.items()):
            if not name or "/" in name or "\\" in name or name in {".", ".."}:
                raise ValueError("Unsafe asset path")
            expected_size = detail.get("size_bytes")
            expected_sha = detail.get("sha256")
            if not isinstance(expected_size, int) or not isinstance(expected_sha, str):
                raise ValueError("Invalid manifest hash or length")
            destination = root / name
            digest = hashlib.sha256()
            total = 0
            with source_stream(name) as response:
                encoding = (response.headers.get("Content-Encoding") or "").lower()
                if encoding == "gzip" and name == "index.wasm":
                    stream = gzip.GzipFile(fileobj=response)
                elif encoding:
                    raise ValueError(f"Unexpected content encoding on {name}: {encoding}")
                else:
                    stream = response
                with destination.open("wb") as out:
                    while True:
                        chunk = stream.read(1024 * 1024)
                        if not chunk:
                            break
                        total += len(chunk)
                        if total > expected_size:
                            raise ValueError(f"Overlong response for {name}")
                        digest.update(chunk)
                        out.write(chunk)
            if total != expected_size or digest.hexdigest() != expected_sha:
                raise ValueError(f"Asset hash mismatch for {name}")
        archive = target / "OSGARD_R135_OPTIMIZED_WEB.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as z:
            for file in sorted(root.iterdir()):
                z.write(file, file.name)
        shutil.copyfile(root / "release.json", target / "R135_OPTIMIZED_MANIFEST.json")
    print(json.dumps({"status": "verified_live_recovery", "manifest_sha256": MANIFEST_SHA256,
                      "archive_bytes": archive.stat().st_size, "source_commit": SOURCE_SHA}))


if __name__ == "__main__":
    if len(sys.argv) != 2:
        raise SystemExit("usage: r135-artifact-fallback.py /dir/for/w5/release")
    restore(Path(sys.argv[1]))
