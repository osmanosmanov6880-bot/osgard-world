#!/usr/bin/env python3
"""Independent W18 evidence gate. No software screenshot is a phone GPU test."""
from __future__ import annotations
import argparse
import hashlib
import json
import re
import struct
import zipfile
from pathlib import Path

VERSION = "r135-premium-learning-w18-candidate-20261025"
REQUIRED_FRAMES = (
    "desktop-1366.png", "w6-portrait-optical-active.png",
    "w17-desktop-ru-operator.png", "w17-mobile-ru-operator.png",
    "w8-hud-360x780.png", "w8-hud-430x932.png", "w8-hud-932x430.png",
    "w12-desktop-1366-fault-2-active.png", "w12-desktop-1366-fault-3-active.png",
    "w12-mobile-390-fault-2-active.png", "w12-mobile-390-fault-3-active.png"
)
SHA40 = re.compile(r"^[a-f0-9]{40}$")
SHA64 = re.compile(r"^[a-f0-9]{64}$")

def require(ok: bool, why: str) -> None:
    if not ok:
        raise ValueError("R135 W18 evidence rejected: " + why)

def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def file_digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1048576), b""):
            h.update(chunk)
    return h.hexdigest()

def verify_pin(pin: dict) -> None:
    require(isinstance(pin, dict), "pin must be an object")
    require(pin.get("version") == VERSION, "wrong or mutable version")
    require(bool(SHA40.fullmatch(str(pin.get("source_commit", "")))), "invalid source SHA")
    for key in ("manifest_sha256", "archive_sha256"):
        require(bool(SHA64.fullmatch(str(pin.get(key, "")))), "invalid " + key)
    require(type(pin.get("artifact_run_id")) is int and pin["artifact_run_id"] > 0,
            "missing exact successful Actions run")
    require(type(pin.get("artifact_id")) is int and pin["artifact_id"] > 0,
            "missing exact reviewed Actions artifact")
    require(pin.get("artifact_name") == "osgard-r135-optimized-web-qa",
            "unexpected artifact name")
    for key in ("reviewed_portrait", "reviewed_desktop", "reviewed_ru_en",
                "browser_three_fault_cases"):
        require(pin.get(key) is True, "missing required reviewer attestation: " + key)
    require(pin.get("physical_phone_fps_verified") is False,
            "software-rendered W18 cannot claim physical GPU certification")
    frames = pin.get("screenshots_sha256")
    require(isinstance(frames, dict) and set(frames) == set(REQUIRED_FRAMES),
            "all 11 original screenshot hashes must be independently pinned")
    hashes = list(frames.values())
    require(all(isinstance(v, str) and SHA64.fullmatch(v) for v in hashes),
            "invalid screenshot SHA-256")
    require(len(hashes) == len(set(hashes)), "duplicate screenshot hash")

def verify_png(path: Path, expected: str) -> dict:
    require(path.is_file() and path.stat().st_size > 20000, "absent/tiny original PNG " + path.name)
    with path.open("rb") as f:
        header = f.read(24)
    require(header[:8] == b"\x89PNG\r\n\x1a\n" and header[12:16] == b"IHDR",
            "invalid PNG file signature " + path.name)
    width, height = struct.unpack(">II", header[16:24])
    require(width >= 300 and height >= 300 and width <= 8000 and height <= 8000,
            "invalid original screenshot dimensions " + path.name)
    require(file_digest(path) == expected, "original image hash does not match review " + path.name)
    return {"width": width, "height": height, "sha256": expected}

def verify_archive(path: Path, manifest: dict) -> int:
    files = manifest.get("files")
    require(isinstance(files, dict), "missing binary file map")
    require({"index.html", "index.js", "index.wasm", "index.wasm.gz", "index.pck"}.issubset(files),
            "not an actual Godot WebGL bundle")
    count = 0
    with zipfile.ZipFile(path) as bundle:
        members = bundle.infolist()
        names = [m.filename for m in members]
        require(len(names) == len(set(names)) and set(names) == set(files) | {"release.json"},
                "binary file map and ZIP members disagree")
        for info in members:
            require(not info.is_dir() and info.filename == Path(info.filename).name,
                    "unsafe ZIP path")
            require(not (info.flag_bits & 1) and 0 <= info.file_size <= 100000000,
                    "encrypted or oversized ZIP member")
            with bundle.open(info) as source:
                h = hashlib.sha256()
                total = 0
                for chunk in iter(lambda: source.read(1048576), b""):
                    total += len(chunk)
                    h.update(chunk)
            if info.filename == "release.json":
                require(json.loads(bundle.read(info)) == manifest, "embedded manifest changed")
            else:
                detail = files[info.filename]
                require(total == detail.get("size_bytes") and h.hexdigest() == detail.get("sha256"),
                        "wrong binary SHA: " + info.filename)
            count += 1
    return count

def review(pin: dict, root: Path) -> dict:
    verify_pin(pin)
    release = root / "r135-optimized-release"
    screens = root / "r135-screens"
    archive = release / "OSGARD_R135_OPTIMIZED_WEB.zip"
    manifest_path = release / "R135_OPTIMIZED_MANIFEST.json"
    require(archive.is_file() and manifest_path.is_file(), "candidate files missing")
    require(file_digest(archive) == pin["archive_sha256"], "candidate archive SHA mismatch")
    require(file_digest(manifest_path) == pin["manifest_sha256"], "candidate manifest SHA mismatch")
    manifest = json.loads(manifest_path.read_bytes())
    require(manifest.get("version") == pin["version"] and
            manifest.get("source_commit") == pin["source_commit"] and
            manifest.get("engine") == "Godot 4.4.1", "wrong actual Godot source/version")
    require(manifest.get("webgl_browser_software_smoke") == "passed" and
            manifest.get("native_tests") == "passed" and
            manifest.get("original_glbs_preserved") is True,
            "actual native/WebGL/GLB verification missing")
    zip_members = verify_archive(archive, manifest)
    evidence_file = root / "r135-w10-release-evidence.json"
    require(evidence_file.is_file(), "missing source-matched readiness evidence")
    evidence = json.loads(evidence_file.read_bytes())
    require(evidence.get("status") == "PASS" and
            evidence.get("source_commit") == pin["source_commit"] and
            evidence.get("manifest_sha256") == pin["manifest_sha256"] and
            evidence.get("archive_sha256") == pin["archive_sha256"] and
            evidence.get("hardware_gpu_fps_certified") is False,
            "ready report invalid or falsely attributes hardware GPU")
    frames = {name: verify_png(screens / name, pin["screenshots_sha256"][name])
              for name in REQUIRED_FRAMES}
    require(frames["w8-hud-932x430.png"]["width"] > frames["w8-hud-932x430.png"]["height"],
            "no authentic landscape frame")
    require(frames["w8-hud-360x780.png"]["height"] > frames["w8-hud-360x780.png"]["width"],
            "no authentic portrait frame")
    matrix = {}
    for device in ("desktop-1366", "mobile-390"):
        path = screens / ("w12-" + device + "-three-case-evidence.json")
        require(path.is_file(), "missing three-case report " + device)
        data = json.loads(path.read_bytes())
        require(data.get("device") == device and
                "not physical phone GPU" in str(data.get("software_browser_renderer", "")),
                "false hardware attribution or swapped browser evidence")
        cases = data.get("new_cases")
        require(isinstance(cases, list) and len(cases) == 2, "missing real faults")
        for i, (fault, view) in enumerate((("COOLING AIRFLOW", 3), ("SERVICE INTERLOCK", 1))):
            case = cases[i]
            require(case.get("index") == i + 1 and case.get("fault") == fault and
                    case.get("targetView") == view and case.get("cleared") == i + 2 and
                    case.get("result") == "PASS" and case.get("simulated_only") is True,
                    "incorrect original gameplay for " + device)
        matrix[device] = {"cleared": 3, "score_last": cases[-1].get("score")}
    return {"status": "W18_SOFTWARE_EVIDENCE_PASS_HARDWARE_UNCERTIFIED",
            "version": pin["version"], "source_commit": pin["source_commit"],
            "archive_sha256": pin["archive_sha256"], "manifest_sha256": pin["manifest_sha256"],
            "zip_members": zip_members, "reviewed_original_frames": len(frames),
            "browser_gameplay": matrix, "physical_android_iphone_certified": False}

def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--pin", type=Path, required=True)
    p.add_argument("--artifact", type=Path, required=True)
    args = p.parse_args()
    result = review(json.loads(args.pin.read_text(encoding="utf8")), args.artifact)
    print(json.dumps(result, indent=2, ensure_ascii=False))

if __name__ == "__main__":
    main()
