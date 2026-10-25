#!/usr/bin/env python3
"""Recover exactly a reviewed R135 public WebGL package when the Actions artifact expires.

Fail-closed: never use the public server as a source of trust. The external
pin's manifest SHA and every asset SHA must match before any ZIP can be staged.
Use only after the identical W14 release was already activated once.
"""
from __future__ import annotations

import argparse
import gzip
import hashlib
import json
import shutil
import tempfile
import urllib.request
import zipfile
from pathlib import Path

PUBLIC_BASE = "https://osgard.world/games/r135-service/"


def require(value: bool, reason: str) -> None:
    if not value:
        raise ValueError("W14 verified live recovery denied: " + reason)


def retrieve(url: str, target: Path, limit: int, plain_wasm: bool = False) -> tuple[str, int]:
    req = urllib.request.Request(url, headers={
        "Accept-Encoding": "identity", "Cache-Control": "no-cache",
    })
    digest = hashlib.sha256()
    seen = 0
    with urllib.request.urlopen(req, timeout=90) as response:
        encoding = response.headers.get("Content-Encoding", "").lower()
        if encoding == "gzip" and plain_wasm:
            stream = gzip.GzipFile(fileobj=response)
        else:
            require(encoding in ("", "identity"), "unexpected content coding on " + url)
            stream = response
        with target.open("wb") as output:
            while True:
                chunk = stream.read(1024 * 1024)
                if not chunk:
                    break
                seen += len(chunk)
                require(seen <= limit, "remote response longer than reviewed manifest")
                digest.update(chunk)
                output.write(chunk)
    return digest.hexdigest(), seen


def recover(pin_path: Path, target: Path, base: str = PUBLIC_BASE) -> dict:
    pin = json.loads(pin_path.read_text(encoding="utf-8"))
    expected_hash = str(pin.get("manifest_sha256", ""))
    expected_source = str(pin.get("source_commit", ""))
    expected_version = str(pin.get("version", ""))
    require(len(expected_hash) == 64 and len(expected_source) == 40,
            "reviewed pin missing digest")
    require(expected_version == "r135-case-progress-w14-20261025",
            "not a reviewed W14 version")
    target.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="r135-w14-recover-") as staging:
        root = Path(staging)
        manifest_path = root / "release.json"
        digest, size = retrieve(base.rstrip("/") + "/release.json", manifest_path, 65536)
        require(digest == expected_hash, "live site has not published pinned W14")
        manifest = json.loads(manifest_path.read_bytes())
        require(manifest.get("version") == expected_version and
                manifest.get("source_commit") == expected_source,
                "live source/version mismatch")
        files = manifest.get("files")
        require(isinstance(files, dict), "invalid file hash manifest")
        require({"index.html", "index.js", "index.wasm", "index.wasm.gz", "index.pck"}.
                issubset(files), "missing required Godot components")
        require(len(files) <= 24, "unexpectedly many package entries")
        for name, attrs in sorted(files.items()):
            require(isinstance(name, str) and name == Path(name).name
                    and name not in (".", "..", "release.json")
                    and "\\" not in name and "/" not in name,
                    "unsafe archive member")
            require(isinstance(attrs, dict), "invalid asset hash metadata")
            expected_size = attrs.get("size_bytes")
            expected_file_hash = attrs.get("sha256")
            require(isinstance(expected_size, int) and 0 <= expected_size <= 110_000_000,
                    "asset size outside budget")
            require(isinstance(expected_file_hash, str) and len(expected_file_hash) == 64,
                    "asset SHA missing")
            actual_hash, actual_size = retrieve(
                base.rstrip("/") + "/" + name, root / name, expected_size,
                plain_wasm=(name == "index.wasm"))
            require(actual_size == expected_size and actual_hash == expected_file_hash,
                    "live asset digest mismatch: " + name)
        archive = target / "OSGARD_R135_OPTIMIZED_WEB.zip"
        with zipfile.ZipFile(archive, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as out:
            for file in sorted(root.iterdir()):
                out.write(file, file.name)
        shutil.copyfile(manifest_path, target / "R135_OPTIMIZED_MANIFEST.json")
    return {"status": "VERIFIED_LIVE_RECOVERY", "version": expected_version,
            "source_commit": expected_source, "manifest_sha256": expected_hash,
            "archive_bytes": archive.stat().st_size}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--pin", required=True, type=Path)
    parser.add_argument("--target", required=True, type=Path)
    parser.add_argument("--base-url", default=PUBLIC_BASE)
    args = parser.parse_args()
    result = recover(args.pin, args.target, args.base_url)
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
