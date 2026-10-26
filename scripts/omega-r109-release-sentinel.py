#!/usr/bin/env python3
"""EMPIRE Omega candidate provenance sentinel. No changes to live production.

This verifies the *actual checkout* and original pinned CC0 binary resources;
never fabricates a visual pass, a benchmark, a mission or an accepted release.
"""
import argparse
import hashlib
import json
import subprocess
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROJECT = ROOT / "godot" / "empire-omega"
PROVENANCE = PROJECT / "assets" / "r90" / "provenance.json"
SCRIPT_PATHS = [
    "scripts/hud.gd",
    "scripts/game_state.gd",
    "scripts/mission_manager.gd",
    "scripts/world_builder.gd",
    "scripts/horizon_roadscape.gd",
    "scripts/horizon_r90_premium_dashboard.gd",
    "scripts/horizon_r90_reference_style.gd",
    "scripts/horizon_r91_skyline_detail.gd",
    "scripts/horizon_r92_projective_districts.gd",
    "scripts/horizon_r93_real_civic_kpis.gd",
    "scripts/horizon_r95_city_massing.gd",
    "scripts/horizon_r98_architectural_fins.gd",
]
TESTS = [
    "v29_responsive_layout",
    "v54_r32_cinematic_cabinet_wet_grip",
    "v72_r55_forty_mission_event_save",
    "v74_r64_authoritative_mission_transactions",
    "v75_r68_policy_mission_real_change",
    "v76_r87_honest_mission_navigation",
    "v78_r90_reference_fidelity",
    "v79_r91_original_architecture",
    "v80_r92_real_district_projection",
    "v81_r93_live_civic_metrics",
    "v82_r95_city_massing",
    "v83_r97_cinematic_command_hierarchy",
    "v84_r98_facade_geometry",
    "v85_r99_command_visual_geometry",
    "v86_r102_real_asphalt_quality",
    "v87_r108_native_mountain_ridges",
    "v88_r106_embedded_cc0_road_activation",
    "v89_r111_stable_weather_pbr",
    "v90_r112_true_camera_inspection",
    "v91_r114_pbr_roofline_luxury",
]


def sha256(file: Path) -> str:
    digest = hashlib.sha256()
    with file.open("rb") as reader:
        for block in iter(lambda: reader.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def checked_source() -> dict:
    project_file = PROJECT / "project.godot"
    if not project_file.is_file():
        raise RuntimeError("Original Godot 4.x source project is missing")
    config = project_file.read_text(encoding="utf-8")
    for expected in ('renderer/rendering_method="gl_compatibility"',
                     'GameState="*res://scripts/game_state.gd"',
                     'run/main_scene="res://scenes/main.tscn"'):
        if expected not in config:
            raise RuntimeError("Wrong project or engine configuration: " + expected)
    required = [PROJECT / p for p in SCRIPT_PATHS]
    required.extend(PROJECT / "tests" / (t + ".gd") for t in TESTS)
    missing = [str(p.relative_to(ROOT)) for p in required if not p.is_file()]
    if missing:
        raise RuntimeError("MISSING REAL CODE; do not release: " + ", ".join(missing))
    return {str(p.relative_to(ROOT)): sha256(p) for p in required}


def checked_assets() -> dict:
    if not PROVENANCE.is_file():
        raise RuntimeError("Missing human-reviewed CC0 photo provenance lock")
    manifest = json.loads(PROVENANCE.read_text(encoding="utf-8"))
    if manifest.get("license") != "CC0" or manifest.get("asset") != "aerial_asphalt_01":
        raise RuntimeError("Unreviewed license or wrong photographic road asset")
    if manifest.get("source") != "https://polyhaven.com/a/aerial_asphalt_01":
        raise RuntimeError("Unapproved original material source")
    if set(manifest.get("files", {})) != {"albedo", "normal_gl", "roughness"}:
        raise RuntimeError("Incomplete authentic albedo/normal/roughness provenance")
    validated = {}
    for channel, data in manifest["files"].items():
        file = PROVENANCE.parent / data["file"]
        if not file.is_file() or file.is_symlink():
            raise RuntimeError("Missing original reviewed binary: " + str(file))
        if file.stat().st_size != data["bytes"] or sha256(file) != data["sha256"]:
            raise RuntimeError("Original photo SHA-256 / size mismatch: " + file.name)
        if (data.get("width"), data.get("height")) != (1024, 1024):
            raise RuntimeError("Incorrect CC0 1K source dimensions: " + file.name)
        validated[channel] = {"path": str(file.relative_to(ROOT)),
                              "bytes": file.stat().st_size,
                              "sha256": sha256(file)}
    # Also execute the strict reviewed JPEG marker / dimensional checks.
    subprocess.run([sys.executable, str(ROOT / "scripts" / "r90_cc0_texture_pack.py"),
                    "verify"], cwd=ROOT, check=True)
    return validated


def current_commit() -> str:
    return subprocess.check_output(["git", "rev-parse", "HEAD"],
                                   cwd=ROOT, text=True).strip()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="")
    args = parser.parse_args()
    source = checked_source()
    assets = checked_assets()
    manifest = {
        "product": "EMPIRE OMEGA",
        "engine": "Godot 4.4.1 GL Compatibility",
        "scope": "unpublished candidate verification; NOT a production deployment",
        "tested_checkout_commit": current_commit(),
        "authoritative_source_files_sha256": source,
        "asset_sha256": assets,
        "required_native_tests": TESTS,
        "live_3d_source": "original World3D and Godot SubViewport, not a generated image",
        "requires_independent_webgl_chromium": True,
        "requires_human_reference_comparison": True,
        "production_signoff_recorded": False,
    }
    if args.output:
        dest = ROOT / args.output
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(manifest, ensure_ascii=False,
                                   sort_keys=True, indent=2) + "\n", encoding="utf-8")
        print("Wrote exact-candidate provenance:", dest)
    print("PASS original source and 3 SHA-locked CC0 materials:",
          len(source), "files,", len(assets), "maps;", manifest["tested_checkout_commit"])


if __name__ == "__main__":
    try:
        main()
    except (OSError, RuntimeError, ValueError, subprocess.CalledProcessError) as exc:
        print("EMPIRE OMEGA RELEASE SENTINEL FAIL:", exc, file=sys.stderr)
        raise SystemExit(1)
