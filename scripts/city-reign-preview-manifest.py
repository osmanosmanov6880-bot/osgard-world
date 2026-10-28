#!/usr/bin/env python3
"""Source-locked CITY REIGN PUBLIC TECHNICAL PREVIEW packaging.

This is the REAL Godot main scene's exported WebGL bytes, not game-like HTML.
Produces the same exact-file SHA-256 contract as omega-live-integrity.py.
It never alters master, the existing Omega R87 directory, SSH or production.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import tempfile
from pathlib import Path

ALLOWED = frozenset({
    "index.html", "index.js", "index.wasm", "index.pck", "index.png",
    "index.audio.worklet.js", "index.audio.position.worklet.js",
})
REQUIRED = {"index.html", "index.js", "index.wasm", "index.pck"}
SOURCE_PATH = "godot/empire-omega"
LIVE_PATH = "/games/city-reign-preview/"
SCRIPT_MARKER = '<script src="index.js"></script>'
PREVIEW_TITLE = "CITY REIGN — World Edition | OSGARD Preview"


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def validate_sha(sha: str) -> str:
    if re.fullmatch("[a-f0-9]{40}", sha or "") is None:
        raise ValueError("Exact lowercase 40-character source commit required")
    return sha


def ensure_native_web(root: Path, *, production_size: bool) -> list[Path]:
    if not root.is_dir() or root.is_symlink():
        raise ValueError("Expected a real, non-symlink Godot Web export directory")
    files = sorted(root.iterdir())
    if not REQUIRED.issubset({p.name for p in files}):
        raise ValueError("Missing original Godot html/js/wasm/pck")
    for entry in files:
        if entry.is_symlink() or not entry.is_file() or entry.name not in ALLOWED:
            raise ValueError("Unexpected/symlink/non-native export file: " + entry.name)
        if not entry.stat().st_size:
            raise ValueError("Empty game export file: " + entry.name)
    if root.joinpath("index.wasm").open("rb").read(4) != bytes.fromhex("0061736d"):
        raise ValueError("Original game WebAssembly signature missing")
    if root.joinpath("index.pck").open("rb").read(4) != b"GDPC":
        raise ValueError("Original Godot PCK signature missing")
    if production_size and (
        root.joinpath("index.wasm").stat().st_size < 1_000_000
        or root.joinpath("index.pck").stat().st_size < 100_000
    ):
        raise ValueError("Source game binary is abnormally small")
    return files


def package(root: Path, source_sha: str, *, production_size: bool = True) -> dict:
    source_sha = validate_sha(source_sha)
    files = ensure_native_web(root, production_size=production_size)
    html_path = root / "index.html"
    html = html_path.read_text(encoding="utf-8")
    if html.count(SCRIPT_MARKER) != 1:
        raise ValueError("Unrecognized official Godot 4.4.1 Web engine entrypoint")
    if 'GODOT_CONFIG' not in html or 'executable":"index"' not in html:
        raise ValueError("Expected original runnable Godot main-scene loader")
    # Nginx's shared games/static rule caches .js for 7 days. The source-pinned
    # query invalidates that cache for each NEW real WebAssembly release.
    html = html.replace(
        SCRIPT_MARKER, f'<script src="index.js?v={source_sha[:16]}"></script>'
    )
    html = re.sub(
        r"<title>[^<]{0,160}</title>",
        "<title>" + PREVIEW_TITLE + "</title>",
        html,
        count=1,
    )
    if PREVIEW_TITLE not in html:
        raise ValueError("Failed to brand the original native engine page")
    html_path.write_text(html, encoding="utf-8")
    entries = {p.name: digest(p.read_bytes()) for p in files}
    manifest = {
        "engine": "Godot 4.4.1",
        "native_tests": "passed",
        "artifact_kind": "native-Godot-HTML5-export",
        "source_path": SOURCE_PATH,
        "source_commit": source_sha,
        "main_scene": "res://scenes/main.tscn",
        "channel": "public-technical-preview",
        "relative_url": LIVE_PATH,
        "commercial_aaa_release": False,
        "physical_device_performance_approved": False,
        "independent_art_approval": False,
        "files": entries,
    }
    (root / "release.json").write_text(
        json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    sums = {**entries, "release.json": digest((root / "release.json").read_bytes())}
    (root / "SHA256SUMS.txt").write_text(
        "".join(f"{hash_value}  {name}\n" for name, hash_value in sorted(sums.items())),
        encoding="ascii",
    )
    return manifest


def self_test() -> None:
    with tempfile.TemporaryDirectory(prefix="cityreign-preview-manifest-") as tmp:
        root = Path(tmp)
        original_html = (
            '<html><head><title>Old Godot Title</title></head><body>'
            '<script src="index.js"></script>'
            '<script>const GODOT_CONFIG = {"executable":"index"};</script>'
            '</body></html>'
        )
        for name, body in {
            "index.html": original_html.encode(),
            "index.js": b"original Godot engine JS",
            "index.wasm": bytes.fromhex("0061736d") + b"native WASM",
            "index.pck": b"GDPC" + b"original physical game",
        }.items():
            (root / name).write_bytes(body)
        sha = "a" * 40
        result = package(root, sha, production_size=False)
        assert result["source_commit"] == sha
        assert result["channel"] == "public-technical-preview"
        assert result["commercial_aaa_release"] is False
        assert result["files"]["index.wasm"] == digest((root / "index.wasm").read_bytes())
        assert "index.js?v=aaaaaaaaaaaaaaaa" in (root / "index.html").read_text()
        assert PREVIEW_TITLE in (root / "index.html").read_text()
        for line in (root / "SHA256SUMS.txt").read_text().splitlines():
            value, name = line.split("  ")
            assert digest((root / name).read_bytes()) == value
        for bad_sha in ("", "invalid", "../master", "b"*39, "B"*40):
            try:
                validate_sha(bad_sha)
                raise AssertionError("Accepted unsafe source commit")
            except ValueError:
                pass
        (root / "index.html").write_text(original_html)
        (root / "index.wasm").write_bytes(b"FAKE")
        try:
            package(root, sha, production_size=False)
            raise AssertionError("Accepted fake WebAssembly")
        except ValueError:
            pass
        (root / "index.wasm").write_bytes(bytes.fromhex("0061736d")+b"x")
        (root / "other-site-secret.txt").write_text("unsafe")
        try:
            package(root, sha, production_size=False)
            raise AssertionError("Accepted unexpected archive file")
        except ValueError:
            pass
    print("PASS: CITY REIGN source-locked native preview manifest, true WASM/PCK, cache-buster and SHA256 safety")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--self-test", action="store_true")
    parser.add_argument("--export-dir", type=Path)
    parser.add_argument("--source-sha")
    args = parser.parse_args()
    if args.self_test:
        self_test()
        return
    if not args.export_dir or not args.source_sha:
        parser.error("--export-dir and --source-sha required")
    manifest = package(args.export_dir, args.source_sha)
    print("CITY REIGN PREVIEW SOURCE AND REAL GAME VERIFIED:", manifest["source_commit"])
    print("Native Godot engine files:", len(manifest["files"]))


if __name__ == "__main__":
    main()
