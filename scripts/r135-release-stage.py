#!/usr/bin/env python3
"""Stage only checksum-verified OSGARD R135 Godot Web release files."""
from __future__ import annotations

import hashlib
import json
from pathlib import Path
import shutil
import sys
import tempfile
import zipfile


def reject(reason: str):
    raise SystemExit("R135 release rejected: " + reason)


def stage(archive: Path, manifest_path: Path, destination: Path):
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("version") != "r135-web-diagnostics-w4-20261024":
        reject("wrong release tag")
    if manifest.get("engine") != "Godot 4.4.1":
        reject("wrong Godot engine")
    files = manifest.get("files")
    required = {"index.html", "index.js", "index.wasm", "index.pck"}
    if not isinstance(files, dict) or not required.issubset(files):
        reject("required engine output absent")
    size = manifest.get("optimized_pck_bytes")
    if not isinstance(size, int) or not 10000000 < size < 100000000:
        reject("PCK outside safe size budget")
    if files["index.pck"]["size_bytes"] != size:
        reject("PCK size mismatch")
    wasm = files.get("index.wasm")
    packed_wasm = files.get("index.wasm.gz")
    if not isinstance(wasm, dict) or not isinstance(packed_wasm, dict):
        reject("WASM and precompressed WASM are both required")
    if packed_wasm.get("size_bytes", 0) <= 0 or packed_wasm.get("size_bytes", 0) >= wasm.get("size_bytes", 0) * 0.70:
        reject("WASM gzip savings below mandatory transfer budget")
    if manifest.get("native_tests") != "passed" or not manifest.get("original_glbs_preserved"):
        reject("required native source verification missing")

    destination = destination.resolve()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix=".r135-stage-", dir=destination.parent) as temp:
        temporary = Path(temp)
        with zipfile.ZipFile(archive) as z:
            names = z.namelist()
            if len(names) != len(set(names)) or set(names) != set(files) | {"release.json"}:
                reject("ZIP entries differ from release manifest")
            for info in z.infolist():
                if info.filename != Path(info.filename).name or info.is_dir() or info.flag_bits & 1:
                    reject("unsafe archive member")
                if info.file_size > 100000000:
                    reject("oversized archive member")
                digest = hashlib.sha256()
                length = 0
                output = temporary / info.filename
                with z.open(info) as src, output.open("wb") as dst:
                    for chunk in iter(lambda: src.read(1024 * 1024), b""):
                        dst.write(chunk)
                        digest.update(chunk)
                        length += len(chunk)
                if info.filename == "release.json":
                    if json.loads(output.read_text(encoding="utf-8")) != manifest:
                        reject("embedded manifest tampered with")
                elif (length != files[info.filename].get("size_bytes")
                      or digest.hexdigest() != files[info.filename].get("sha256")):
                    reject("SHA-256 mismatch: " + info.filename)
        html = (temporary / "index.html").read_text(encoding="utf-8")
        if "<canvas" not in html or "index.js" not in html:
            reject("not an actual Godot HTML5 export")
        if destination.exists():
            shutil.rmtree(destination)
        shutil.copytree(temporary, destination)
        # TemporaryDirectory is mode 0700. copytree copies its permissions
        # to the destination, making genuine game files invisible to Nginx's
        # unprivileged worker (try_files then reports a misleading HTTP 404).
        # Keep source files public-read-only, allow directory traversal.
        destination.chmod(0o755)
        for member in destination.rglob("*"):
            member.chmod(0o755 if member.is_dir() else 0o644)
        if (destination.stat().st_mode & 0o111) != 0o111:
            reject("R135 directory not publicly traversable")
    print(json.dumps({"status": "verified", "files": len(files) + 1,
                      "pck_bytes": size, "destination": str(destination)}))


if __name__ == "__main__":
    if len(sys.argv) != 4:
        reject("usage: r135-release-stage.py release.zip manifest.json target_dir")
    stage(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]))
