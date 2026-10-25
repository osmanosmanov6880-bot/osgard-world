#!/usr/bin/env python3
"""Independent W21 SOFTWARE acceptance. Never treats screenshots as physical-phone QA.

A run being green is necessary but insufficient: the immutable GitHub run,
reviewed artifact, genuine browser frames and every WebGL byte must match.
"""
from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
from pathlib import Path

_W18 = Path(__file__).with_name("r135-w18-promotion-qa.py")
_spec = importlib.util.spec_from_file_location("r135_w18_verified_png", _W18)
assert _spec and _spec.loader
previous = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(previous)

VERSION = "r135-explainable-training-w21-candidate-20261025"
FRAMES = previous.REQUIRED_FRAMES + (
    "w19-desktop-1366-russian-luxury-welcome.png",
    "w19-mobile-390-russian-luxury-welcome.png",
    "w20-desktop-1366-player-settings.png",
    "w20-mobile-390-player-settings.png",
    "w21-desktop-1366-explainable-course.png",
    "w21-mobile-390-explainable-course.png",
)
SHA40 = re.compile(r"^[0-9a-f]{40}$")
SHA64 = re.compile(r"^[0-9a-f]{64}$")


def require(ok: bool, message: str) -> None:
    if not ok:
        raise ValueError("R135 W21 rejected: " + message)


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def verify_pin(pin: dict) -> None:
    require(isinstance(pin, dict), "reviewed pin must be an object")
    require(pin.get("version") == VERSION, "wrong candidate version")
    require(bool(SHA40.fullmatch(str(pin.get("source_commit", "")))), "invalid source SHA")
    for key in ("manifest_sha256", "archive_sha256"):
        require(bool(SHA64.fullmatch(str(pin.get(key, "")))), "invalid " + key)
    for key in ("artifact_id", "artifact_run_id", "native_run_id"):
        require(type(pin.get(key)) is int and pin[key] > 0, "invalid " + key)
    require(pin.get("artifact_name") == "osgard-r135-optimized-web-qa", "unexpected artifact")
    for key in (
        "reviewed_luxury_desktop", "reviewed_luxury_mobile",
        "reviewed_settings_desktop", "reviewed_settings_mobile",
        "reviewed_settings_persistence",
        "reviewed_coach_desktop", "reviewed_coach_mobile",
        "reviewed_real_causal_errors", "reviewed_no_overlap",
        "reviewed_ru_en", "browser_three_fault_cases",
    ):
        require(pin.get(key) is True, "independent human/CI review missing: " + key)
    require(pin.get("physical_phone_fps_verified") is False,
            "SwiftShader WebGL does not certify real-phone performance")
    require(pin.get("photorealistic_aaa_certified") is False,
            "W21 causal lessons do not certify AAA photorealism")
    frames = pin.get("screenshots_sha256")
    require(isinstance(frames, dict) and set(frames) == set(FRAMES),
            "all 17 exact original PNGs are required")
    hashes = list(frames.values())
    require(all(isinstance(v, str) and SHA64.fullmatch(v) for v in hashes),
            "invalid original frame checksum")
    require(len(hashes) == len(set(hashes)), "duplicated original screenshot checksum")


def review(pin: dict, root: Path) -> dict:
    verify_pin(pin)
    r = root / "r135-optimized-release"
    s = root / "r135-screens"
    archive = r / "OSGARD_R135_OPTIMIZED_WEB.zip"
    manifest_path = r / "R135_OPTIMIZED_MANIFEST.json"
    require(archive.is_file() and manifest_path.is_file(), "genuine archive missing")
    require(digest(archive) == pin["archive_sha256"], "ZIP checksum changed")
    require(digest(manifest_path) == pin["manifest_sha256"], "manifest checksum changed")
    manifest = json.loads(manifest_path.read_bytes())
    require(manifest.get("version") == VERSION and
            manifest.get("source_commit") == pin["source_commit"] and
            manifest.get("engine") == "Godot 4.4.1", "not reviewed Godot source")
    require(manifest.get("webgl_browser_software_smoke") == "passed" and
            manifest.get("native_tests") == "passed" and
            manifest.get("original_glbs_preserved") is True,
            "native/browser/GLB contract missing")
    count = previous.verify_archive(archive, manifest)
    readiness_path = root / "r135-w10-release-evidence.json"
    require(readiness_path.is_file(), "missing source-matched W10 evidence")
    readiness = json.loads(readiness_path.read_bytes())
    require(readiness.get("status") == "PASS" and
            readiness.get("source_commit") == pin["source_commit"] and
            readiness.get("manifest_sha256") == pin["manifest_sha256"] and
            readiness.get("archive_sha256") == pin["archive_sha256"] and
            readiness.get("hardware_gpu_fps_certified") is False,
            "unverified or misattributed W10 evidence")
    photos = {name: previous.verify_png(s / name, pin["screenshots_sha256"][name])
              for name in FRAMES}
    desk = photos["w19-desktop-1366-russian-luxury-welcome.png"]
    mobile = photos["w19-mobile-390-russian-luxury-welcome.png"]
    require(desk["width"] > desk["height"] and mobile["height"] > mobile["width"],
            "luxury onboarding device orientation evidence invalid")
    settings_desktop = photos["w20-desktop-1366-player-settings.png"]
    settings_mobile = photos["w20-mobile-390-player-settings.png"]
    require(settings_desktop["width"] > settings_desktop["height"] and
            settings_mobile["height"] > settings_mobile["width"],
            "true desktop/mobile W20 settings images must have distinct orientation")
    explained_desktop = photos["w21-desktop-1366-explainable-course.png"]
    explained_mobile = photos["w21-mobile-390-explainable-course.png"]
    require(explained_desktop["width"] > explained_desktop["height"] and
            explained_mobile["height"] > explained_mobile["width"],
            "genuine W21 cause-and-effect course originals must retain device orientation")

    matrix = {}
    for device in ("desktop-1366", "mobile-390"):
        path = s / ("w12-" + device + "-three-case-evidence.json")
        require(path.is_file(), "missing actual three-fault report: " + device)
        report = json.loads(path.read_bytes())
        require(report.get("device") == device and
                "not physical phone GPU" in str(report.get("software_browser_renderer", "")),
                "fake device provenance")
        cases = report.get("new_cases")
        require(isinstance(cases, list) and len(cases) == 2,
                "two additional real cases required")
        for i, (name, view) in enumerate(
            (("COOLING AIRFLOW", 3), ("SERVICE INTERLOCK", 1))
        ):
            case = cases[i]
            require(case.get("index") == i + 1 and
                    case.get("fault") == name and
                    case.get("targetView") == view and
                    case.get("cleared") == i + 2 and
                    case.get("result") == "PASS" and
                    case.get("simulated_only") is True,
                    "incorrect real diagnostic: " + name + ", " + device)
        matrix[device] = {"genuine_cases": 3, "score_final": cases[-1].get("score")}

    return {
        "status": "W21_SOFTWARE_ACCEPTED_HARDWARE_HOLD",
        "source_commit": pin["source_commit"],
        "manifest_sha256": pin["manifest_sha256"],
        "archive_sha256": pin["archive_sha256"],
        "actual_godot_web_files": count,
        "original_png_frames": len(photos),
        "actual_godot_chromium_diagnostics": matrix,
        "physical_android_iphone_certified": False,
        "aaa_photorealism_certified": False,
    }


def main() -> None:
    p = argparse.ArgumentParser()
    p.add_argument("--pin", type=Path, required=True)
    p.add_argument("--artifact", type=Path, required=True)
    args = p.parse_args()
    print(json.dumps(review(json.loads(args.pin.read_text("utf-8")), args.artifact),
                     indent=2, ensure_ascii=False))


if __name__ == "__main__":
    main()
