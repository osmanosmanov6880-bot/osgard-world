#!/usr/bin/env python3
"""W49: fail-closed exact W47 -> W48 source scope, no deployment.

Original mission/core/scene and desktop browser tests stay unmodified; the
W53 mobile CDP touch test is explicitly excepted for real slow-frame gestures.
This is a Git/source integrity check. Real geometry and gameplay require
the separate Godot/Chromium suites; a PASS here never certifies runtime.
"""
import argparse
import json
import subprocess
from pathlib import Path

W47_PINNED_SHA = "14be69cdaa1fdffa4e209645eed0b1964581858a"
ALLOWED = {
    ".github/workflows/r135-w33-operator-debrief-native-qa.yml",
    ".github/workflows/osgard-w53-mobile-touch-acceptance.yml",
    ".github/workflows/osgard-w55-real-mobile-glyph-acceptance.yml",
    ".github/workflows/osgard-w56-local-physical-review.yml",
    ".github/workflows/osgard-w57-exact-head-physical-hold.yml",
    ".github/workflows/osgard-w58-telemetry-groups.yml",
    "tooling/osgard-w56/hardware_review_gate.py",
    "tooling/osgard-w56/test_hardware_review_gate.py",
    "tooling/osgard-w56/README.md",
    "w33-godot-native/scripts/OSGARDObsidianStage.gd",
    "w33-godot-native/scripts/OSGARDMain.gd",
    "w33-godot-native/tests/test_w48_ring_instancing.gd",
    "w33-godot-native/tests/test_w53_mobile_edge_swipe.gd",
    "w33-godot-native/tests/test_w55_readable_protocol_copy.gd",
    "w33-godot-native/ci/godot_software_performance.py",
    "w33-godot-native/ci/browser_webgl_smoke.py",
    "w33-godot-native/ci/mobile_touch_acceptance.py",
    "w33-godot-native/ci/w55_visual_typography_acceptance.py",
    "w33-godot-native/ci/browser_gameplay_acceptance.py",
    "w33-godot-native/ci/w49_source_contract.py",
    "w33-godot-native/ci/w51_paired_comparison.py",
    "w33-godot-native/ci/w52_release_gate.py",
    "w33-godot-native/ci/test_w49_w52_gate_regressions.py",
    "w33-godot-native/ci/W49_W52_RELEASE_README.md",
}
PRESERVE = (
    "w33-godot-native/Main.tscn",
    "w33-godot-native/project.godot",
    "w33-godot-native/export_presets.cfg",
    "w33-godot-native/scripts/OSGARDCore.gd",
    "w33-godot-native/scripts/OSGARDRig.gd",
    "w33-godot-native/tests/test_six_missions.gd",
    "w33-godot-native/tests/test_scene_integration.gd",
    "w33-godot-native/ci/visual_art_acceptance.py",
)
# The original W47 desktop gameplay driver is read-only except for one
# independently reviewed W54 wall-clock/actual-frame diagnostic adjustment.
# Its exact Git blob is pinned: an unreviewed weakening of the mission test
# cannot pass the source gate just because this QA path is allowlisted.
REVIEWED_GAMEPLAY_PATH = "w33-godot-native/ci/browser_gameplay_acceptance.py"
REVIEWED_GAMEPLAY_BLOB = "50e492dadc8a63d99e05677ed3cc07b4dbe16cad"
# W56 operates on untrusted self-reported real-device observations. Its fail-
# closed verifier, negative tests and CI workflow are reviewed at exact Git
# blob SHAs; changing any of these requires independent explicit acceptance.
REVIEWED_W56_CRITICAL_BLOBS = {
    "tooling/osgard-w56/hardware_review_gate.py": "31e0f525bbde6b78aa9efbf0794bc63e5b339a21",
    "tooling/osgard-w56/test_hardware_review_gate.py": "22d9fb347757db4c028329c574e6e6945d0c103b",
    ".github/workflows/osgard-w56-local-physical-review.yml": "8065ee1d6c773c87f273df65b23a921e56a46d85",
}
# W58: exact reviewed responsive telemetry source, native RU/EN regression and
# dedicated fail-closed workflow. Never silently weaken browser/native checks.
REVIEWED_W58_CRITICAL_BLOBS = {
    "w33-godot-native/scripts/OSGARDMain.gd": "a5537386acab0df1cc4f4d55af047199d15c9bf4",
    "w33-godot-native/tests/test_w55_readable_protocol_copy.gd": "28ba896de926990826d3a7161e3f394a60cc8c90",
    ".github/workflows/osgard-w58-telemetry-groups.yml": "e70a6ba328320fed66c2e22d578da62b06ee52b3",
}

W56_PATHS = {
    "tooling/osgard-w56/hardware_review_gate.py",
    "tooling/osgard-w56/test_hardware_review_gate.py",
    ".github/workflows/osgard-w56-local-physical-review.yml",
    "tooling/osgard-w56/README.md",
}
SHA_CHARS = frozenset("0123456789abcdef")


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def assert_sha(value, label):
    if len(value) != 40 or any(char not in SHA_CHARS for char in value):
        raise ValueError(label + " must be an exact full lowercase SHA")


def verify(base, head):
    assert_sha(base, "W47 baseline")
    assert_sha(head, "W48 head")
    if base != W47_PINNED_SHA:
        raise ValueError("W47 source baseline unexpectedly moved; require independent re-acceptance")
    if git("rev-parse", "HEAD") != head:
        raise ValueError("Git checkout does not match PR head SHA")
    git("cat-file", "-e", base + "^{commit}")
    if git("merge-base", base, head) != base:
        raise ValueError("W48 head is not a descendant of pinned W47")
    changed = sorted(set(filter(None, git("diff", "--name-only", "--no-renames", base, head).splitlines())))
    if not changed:
        raise ValueError("No source changes found: wrong PR head")
    excluded = sorted(set(changed) - ALLOWED)
    if excluded:
        raise ValueError("Unauthorized application/mission/production path changes: " + ", ".join(excluded))
    if not {"w33-godot-native/scripts/OSGARDObsidianStage.gd",
            "w33-godot-native/tests/test_w48_ring_instancing.gd"}.issubset(changed):
        raise ValueError("Missing actual W48 implementation or native acceptance test")
    if set(changed) & W56_PATHS:
        if not set(REVIEWED_W56_CRITICAL_BLOBS).issubset(changed):
            raise ValueError("Partial W56 evidence checker: reviewer, negative tests and fail-closed CI all mandatory")
        for path, approved_sha in REVIEWED_W56_CRITICAL_BLOBS.items():
            candidate_blob = git("rev-parse", head + ":" + path)
            if candidate_blob != approved_sha:
                raise ValueError("Unreviewed W56 fail-closed evidence gate change: " + path)
    reviewed_w58 = {}
    for path, approved_sha in REVIEWED_W58_CRITICAL_BLOBS.items():
        candidate_blob = git("rev-parse", head + ":" + path)
        if candidate_blob != approved_sha:
            raise ValueError("Unreviewed W58 UI/runtime QA evidence blob: " + path)
        reviewed_w58[path] = candidate_blob
    gameplay_blob = git("rev-parse", head + ":" + REVIEWED_GAMEPLAY_PATH)
    if gameplay_blob != REVIEWED_GAMEPLAY_BLOB:
        raise ValueError("Unreviewed six-mission browser QA driver change: exact vetted Git blob mismatch")
    subprocess.run(["git", "diff", "--check", base, head], check=True)
    preserved = {}
    for name in PRESERVE:
        before = git("rev-parse", base + ":" + name)
        after = git("rev-parse", head + ":" + name)
        if before != after:
            raise ValueError("Mission/scene/physics original source changed: " + name)
        preserved[name] = after
    return {
        "schema": "OSGARD_W49_EXACT_SOURCE_CONTRACT_V1",
        "status": "PASS",
        "baseline_w47_sha": base,
        "candidate_w48_sha": head,
        "scope_changed_paths": changed,
        "preserved_original_git_blob_shas": preserved,
        "reviewed_browser_gameplay_ci_blob_sha": gameplay_blob,
        "reviewed_w56_gate_blob_shas": REVIEWED_W56_CRITICAL_BLOBS if set(changed) & W56_PATHS else {},
        "reviewed_w58_telemetry_git_blobs": reviewed_w58,
        "production_source_unchanged": True,
        "native_geometry_qa_status": "NOT_RUN_BY_THIS_SCRIPT",
        "browser_gameplay_qa_status": "NOT_RUN_BY_THIS_SCRIPT",
        "hardware_certified": False,
        "production_deployed": False,
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", required=True)
    p.add_argument("--head", required=True)
    p.add_argument("--out", type=Path, required=True)
    opts = p.parse_args()
    opts.out.parent.mkdir(parents=True, exist_ok=True)
    try:
        result = verify(opts.base, opts.head)
    except (ValueError, subprocess.CalledProcessError) as error:
        result = {"schema": "OSGARD_W49_EXACT_SOURCE_CONTRACT_V1", "status": "FAIL",
                  "baseline_w47_sha": opts.base, "candidate_w48_sha": opts.head,
                  "reason": str(error), "production_deployed": False}
        opts.out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
        raise SystemExit("W49 SOURCE HOLD: " + str(error))
    opts.out.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print("W49 ORIGINAL W47-BOUND SOURCE INTEGRITY PASS; runtime verification separately required")


if __name__ == "__main__":
    main()
