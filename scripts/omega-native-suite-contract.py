#!/usr/bin/env python3
"""Fail-closed audit of Godot CPU suites vs original real OpenGL capture.

The native CI must not run an asynchronous true-GL screenshot test in
--headless (dummy renderer). It must not claim the screenshot was tested
by merely skipping it: preserve the true XVFB/OpenGL jobs.
"""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
TESTS = ROOT / "godot/empire-omega/tests"
MAIN = ROOT / ".github/workflows/omega-godot-web.yml"
R44 = ROOT / ".github/workflows/omega-r44-real-streetlighting-qa.yml"
R57 = ROOT / ".github/workflows/omega-r57-headless-gpu-separation-qa.yml"
GPU_ONLY = (
    "horizon_capture.gd",
    "horizon_driving_capture.gd",
    "horizon_r4_showroom_capture.gd",
    "r44_actual_night_capture.gd",
)


def verify():
    workflow = MAIN.read_text(encoding="utf-8")
    image_workflow = R44.read_text(encoding="utf-8")
    gate_workflow = R57.read_text(encoding="utf-8")
    assert "python3 scripts/omega-native-suite-contract.py" in workflow
    assert 'for test_file in godot/empire-omega/tests/*.gd' in workflow
    assert "timeout --signal=TERM --kill-after=5s" in workflow
    assert "v59_r40_force_motor_calibration.gd) test_seconds=110" in workflow
    assert "v67_r46_physics_ab_trials.gd) test_seconds=60" in workflow
    assert "test_seconds=15" in workflow
    assert "v71_r52_real_joined_gameplay.gd" not in GPU_ONLY
    assert "v72_r55_forty_mission_event_save.gd" not in GPU_ONLY
    assert "xvfb-run" in image_workflow and "r44_actual_night_capture.gd" in image_workflow
    assert "xvfb-run" in gate_workflow and "r44_actual_night_capture.gd" in gate_workflow
    pattern = re.search(r'case "\$\{test_file##\*/\}" in\s+(.+?)\)\s+echo "OpenGL-only', workflow, re.S)
    assert pattern is not None, "Cannot find exact headless exclusion guard"
    for name in GPU_ONLY:
        assert (TESTS / name).is_file(), f"GPU evidence suite missing: {name}"
        assert name in pattern.group(1), f"headless would timeout on real GPU-only test: {name}"
    assert "frame_post_draw" in (TESTS / "r44_actual_night_capture.gd").read_text()
    assert "get_texture().get_image()" in (TESTS / "r44_actual_night_capture.gd").read_text()
    all_suites = sorted(p for p in TESTS.glob("*.gd") if p.is_file())
    assert len(all_suites) >= 65, "full original regression suite silently shortened"
    for name in GPU_ONLY:
        assert sum(p.name == name for p in all_suites) == 1
    print(
        f"PASS original {len(all_suites)-len(GPU_ONLY)} headless native tests;"
        f" {len(GPU_ONLY)} real-GPU-only screenshot suites excluded only from"
        " dummy headless renderer; true OpenGL still mandatory on dedicated CI"
    )


if __name__ == "__main__":
    verify()
