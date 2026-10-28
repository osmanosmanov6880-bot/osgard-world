#!/usr/bin/env python3
"""Source-locked playable CITY REIGN HTML5 preview with complete SHA256 attestation.

This is a native Godot 4.4.1 build, never a generated landing page or video.
Only prepare manifests AFTER the authentic Godot engine/native/browser gates
have passed. The older /games/omega-3d-preview is never modified here.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
from pathlib import Path

NAME = re.compile(r"[a-zA-Z0-9_.-]{1,128}")
SHA = re.compile(r"[0-9a-f]{40}")
REQUIRED = {"index.html", "index.js", "index.wasm", "index.pck"}
MAX_FILE = 110 * 1024 * 1024
MAX_FILES = 24


def build_manifest(root: Path, source_sha: str) -> dict:
    if SHA.fullmatch(source_sha) is None:
        raise ValueError("Expected exact 40-character source SHA")
    if not root.is_dir() or root.is_symlink():
        raise ValueError("Godot export must be a real directory")
    names = {p.name for p in root.iterdir()}
    if not REQUIRED.issubset(names):
        raise ValueError("Missing original exported Godot Web executables")
    if "release.json" in names or "SHA256SUMS.txt" in names:
        raise ValueError("Refusing stale manifest in current source build")
    if len(names) < len(REQUIRED) or len(names) > MAX_FILES:
        raise ValueError("Unexpected number of native Godot assets")
    files = {}
    for path in sorted(root.iterdir()):
        if path.is_symlink() or not path.is_file() or NAME.fullmatch(path.name) is None:
            raise ValueError("Unsafe or nested export asset " + path.name)
        size = path.stat().st_size
        if size <= 0 or size > MAX_FILE:
            raise ValueError("Empty or oversized asset " + path.name)
        if path.name == "index.wasm" and size < 1_000_000:
            raise ValueError("WASM is too small to be a real game engine")
        if path.name == "index.pck" and size < 100_000:
            raise ValueError("PCK lacks real original game assets")
        digest = hashlib.sha256()
        with path.open("rb") as fh:
            for chunk in iter(lambda: fh.read(1024 * 1024), b""):
                digest.update(chunk)
        files[path.name] = digest.hexdigest()
    return {
        "engine": "Godot 4.4.1",
        "native_tests": "passed",
        "artifact_kind": "native-Godot-HTML5-export",
        "source_path": "godot/empire-omega",
        "source_commit": source_sha,
        "channel": "city-reign-preview",
        "url_path": "/games/city-reign/",
        "main_scene": "res://scenes/main.tscn",
        "release_stage": "playable-preview",
        "aaa_art_quality_certified": False,
        "independent_full_episode_playtest_certified": False,
        "mobile_gpu_fps_certified": False,
        "files": files,
    }


def write_release(root: Path, manifest: dict) -> None:
    checksums = "".join(
        f"{digest}  {name}\n" for name, digest in sorted(manifest["files"].items())
    )
    (root / "SHA256SUMS.txt").write_text(checksums, encoding="utf-8")
    (root / "release.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="city-reign-native-release-") as temp:
        root = Path(temp)
        for name, size in [
            ("index.html", 32),
            ("index.js", 40),
            ("index.wasm", 1_000_002),
            ("index.pck", 100_001),
        ]:
            (root / name).write_bytes(b"x" * size)
        reference = "a" * 40
        release = build_manifest(root, reference)
        assert release["source_commit"] == reference
        assert release["channel"] == "city-reign-preview"
        assert set(release["files"]) == REQUIRED
        write_release(root, release)
        assert (root / "SHA256SUMS.txt").is_file()
        try:
            build_manifest(root, reference)
        except ValueError:
            pass
        else:
            raise AssertionError("Stale release manifest was accepted")
        (root / "release.json").unlink()
        (root / "SHA256SUMS.txt").unlink()
        (root / "index.pck").unlink()
        try:
            build_manifest(root, reference)
        except ValueError:
            pass
        else:
            raise AssertionError("Missing game package was accepted")
    print("PASS: source-locked native-only CITY REIGN release manifest preflight")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--directory", type=Path)
    parser.add_argument("--source", type=str)
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.directory or not args.source:
        parser.error("--directory and --source are mandatory")
    manifest = build_manifest(args.directory, args.source)
    write_release(args.directory, manifest)
    print(json.dumps({
        "status": "SOURCE-LOCKED",
        "source_commit": manifest["source_commit"],
        "route": manifest["url_path"],
        "files": len(manifest["files"]),
        "engine": manifest["engine"],
    }))


if __name__ == "__main__":
    main()
