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


def stage(archive: Path, manifest_path: Path, destination: Path,
          release_pin: Path | None = None):
    # Preserve the historical W6 no-pin fallback, but every promoted W11/W14
    # public deployment must supply a reviewed immutable release pin file.
    pin = {
        "manifest_sha256": "0638f1ad5c0ab26d2d112e63bd1759923e5401a85ad4f2cedd450bbb7def2f61",
        "version": "r135-web-framing-w6-20261024",
        "source_commit": "947b4627080636543ae5e873b88b50e61f13beb4",
    }
    if release_pin is not None:
        if not release_pin.is_file():
            reject("reviewed release pin file not found")
        pin = json.loads(release_pin.read_text(encoding="utf-8"))
        for key in ("manifest_sha256", "version", "source_commit"):
            if not isinstance(pin.get(key), str) or not pin[key]:
                reject("missing reviewed pin value: " + key)
        if len(pin["manifest_sha256"]) != 64 or len(pin["source_commit"]) != 40:
            reject("invalid reviewed release pin SHA lengths")
        permitted = {"r135-web-legibility-w11-20261024", "r135-case-progress-w14-20261025",
                     "r135-premium-learning-w18-candidate-20261025",
                     "r135-luxury-academy-w19-candidate-20261025",
                     "r135-player-settings-w20-candidate-20261025"}
        if pin.get("version") not in permitted:
            reject("release pin version not in independently tested allowlist")
        if not all(c in "0123456789abcdef" for c in pin["manifest_sha256"] + pin["source_commit"]):
            reject("release pin must contain lowercase hexadecimal SHA digests")
        if pin["version"] == "r135-premium-learning-w18-candidate-20261025":
            for proof in ("reviewed_portrait", "reviewed_desktop", "reviewed_ru_en",
                          "browser_three_fault_cases"):
                if pin.get(proof) is not True:
                    reject("unreviewed W18 safety/gameplay evidence: " + proof)
            if pin.get("physical_phone_fps_verified") is not False:
                reject("W18 Software candidate must not claim physical phone GPU certification")
            original_frames = pin.get("screenshots_sha256")
            if not isinstance(original_frames, dict) or len(original_frames) != 11:
                reject("W18 promotion requires original independently pinned screenshot hashes")
        if pin["version"] == "r135-luxury-academy-w19-candidate-20261025":
            for proof in ("reviewed_luxury_desktop", "reviewed_luxury_mobile",
                          "reviewed_no_overlap", "reviewed_ru_en", "browser_three_fault_cases"):
                if pin.get(proof) is not True:
                    reject("W19 independent evidence not accepted: " + proof)
            if pin.get("physical_phone_fps_verified") is not False:
                reject("W19 software browser cannot claim physical phone GPU FPS")
            if pin.get("photorealistic_aaa_certified") is not False:
                reject("W19 art direction is not certified AAA photorealism")
            frames = pin.get("screenshots_sha256")
            if not isinstance(frames, dict) or len(frames) != 13:
                reject("W19 promotion requires all 13 original PNG image hashes")
        if pin["version"] == "r135-player-settings-w20-candidate-20261025":
            for proof in ("reviewed_luxury_desktop", "reviewed_luxury_mobile",
                          "reviewed_settings_desktop", "reviewed_settings_mobile",
                          "reviewed_settings_persistence", "reviewed_no_overlap",
                          "reviewed_ru_en", "browser_three_fault_cases"):
                if pin.get(proof) is not True:
                    reject("W20 original user settings and real-game proof missing: " + proof)
            if pin.get("physical_phone_fps_verified") is not False:
                reject("W20 Chromium is not physical phone GPU verification")
            if pin.get("photorealistic_aaa_certified") is not False:
                reject("W20 settings cannot certify cinema AAA photorealism")
            if not isinstance(pin.get("native_run_id"), int) or pin["native_run_id"] <= 0:
                reject("W20 requires exact native Godot workflow run")
            frames = pin.get("screenshots_sha256")
            if not isinstance(frames, dict) or len(frames) != 15:
                reject("W20 requires all 15 original PNG review hashes")
    expected_sha256 = pin["manifest_sha256"]
    if hashlib.sha256(manifest_path.read_bytes()).hexdigest() != expected_sha256:
        reject("release manifest digest differs from independently reviewed build")
    manifest = json.loads(manifest_path.read_text(encoding="utf-8"))
    if manifest.get("version") != pin["version"]:
        reject("wrong pinned release version")
    if manifest.get("source_commit") != pin["source_commit"]:
        reject("release source commit is not the reviewed candidate")
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
    if manifest.get("webgl_browser_software_smoke") != "passed":
        reject("W6 WebGL gameplay evidence missing")

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
    if len(sys.argv) not in (4, 5):
        reject("usage: r135-release-stage.py release.zip manifest.json target_dir [reviewed_pin.json]")
    stage(Path(sys.argv[1]), Path(sys.argv[2]), Path(sys.argv[3]),
          Path(sys.argv[4]) if len(sys.argv) == 5 else None)
