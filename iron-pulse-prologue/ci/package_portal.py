#!/usr/bin/env python3
"""Reproducibly assemble the offline IRON PULSE international preview portal.

Copy the exact Godot WebGL export under /play, zip the Windows EXE with its
matching PCK, add unmodified real Chromium screenshot proof, and write a
source-bound SHA-256 manifest. Never fetch or publish external resources.
"""
from __future__ import annotations
import argparse
import hashlib
import json
from pathlib import Path
from shutil import copy2, copytree, rmtree
from zipfile import ZipFile, ZIP_DEFLATED

FILES = ("index.html","index.js","index.wasm","index.pck")

def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as reader:
        for block in iter(lambda: reader.read(1024*1024), b""):
            digest.update(block)
    return digest.hexdigest()

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--project",type=Path,required=True)
    parser.add_argument("--source-sha",required=True)
    arguments = parser.parse_args()
    if len(arguments.source_sha) != 40 or not all(x in "0123456789abcdef" for x in arguments.source_sha):
        parser.error("Need exact lowercase 40-byte source SHA")
    base = arguments.project.resolve(strict=True)
    build = base / "build"
    web = build / "web"
    win = build / "windows"
    screenshot = build / "browser-evidence" / "cinematic-reactor-desktop.png"
    root = build / "portal"
    for item in [*(web / name for name in FILES),win / "IRON_PULSE_BLACKOUT.exe",
                 win / "IRON_PULSE_BLACKOUT.pck",screenshot]:
        if not item.is_file() or item.stat().st_size == 0:
            raise ValueError(f"Exact-source build/evidence missing: {item}")
    if root.exists():
        rmtree(root)
    copytree(base / "portal",root)
    copytree(web,root / "play")
    (root / "downloads").mkdir()
    with ZipFile(root/"downloads"/"IRON_PULSE_WINDOWS.zip","w",compression=ZIP_DEFLATED,compresslevel=6) as zipout:
        for name in ("IRON_PULSE_BLACKOUT.exe","IRON_PULSE_BLACKOUT.pck"):
            zipout.write(win / name,arcname=name)
    (root / "evidence").mkdir()
    copy2(screenshot,root / "evidence" / screenshot.name)
    metadata = {
        "source_sha":arguments.source_sha,
        "status":"software_preview",
        "production_hold":True,
        "platforms":["WebGL","Windows x64"],
        "local_data_only":True,
        "third_party_tracking":False
    }
    (root / "build.json").write_text(json.dumps(metadata,indent=2)+"\n",encoding="utf-8")
    tracked = [
        "index.html","styles.css","app.js","build.json","serve_preview.py",
        "play/index.html","play/index.js","play/index.wasm","play/index.pck",
        "downloads/IRON_PULSE_WINDOWS.zip","evidence/cinematic-reactor-desktop.png"
    ]
    lines = [f"{sha256(root/name)}  {name}" for name in tracked]
    (root / "SHA256SUMS.txt").write_text("\n".join(lines)+"\n",encoding="utf-8")
    for line in lines:
        check,relative = line.split("  ",1)
        assert sha256(root/relative) == check,relative
    print("IRON PULSE V9 EXACT-SOURCE PORTAL PACKAGE PASS")
    print(f"Tracked files: {len(tracked)}; source SHA: {arguments.source_sha}")
    print(f"Artifact root: {root}")

if __name__ == "__main__":
    main()
