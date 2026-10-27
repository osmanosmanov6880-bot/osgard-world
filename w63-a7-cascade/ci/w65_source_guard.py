#!/usr/bin/env python3
"""W65 exact-base review: add narrative/audio only, protect original game rules."""
import argparse
import json
import re
import subprocess
from pathlib import Path

ALLOWED = {
    "w63-a7-cascade/scripts/A7CascadeScreen.gd",
    "w63-a7-cascade/scripts/A7IncidentDirector.gd",
    "w63-a7-cascade/scripts/A7ProceduralAudio.gd",
    "w63-a7-cascade/tests/test_w65_story_audio.gd",
    "w63-a7-cascade/ci/w65_browser_story_audio.py",
    "w63-a7-cascade/ci/w65_source_guard.py",
    ".github/workflows/last-frontier-w65-causal-story.yml",
    "docs/LAST_FRONTIER_W65_CAUSAL_STORY_AUDIO.md",
}
REQUIRED = set(ALLOWED)

PROTECTED = [
    "w63-a7-cascade/scripts/A7CascadeCore.gd",
    "w63-a7-cascade/tests/test_a7_cascade.gd",
    "w63-a7-cascade/scripts/A7CinematicStage.gd",
    "w63-a7-cascade/tests/test_w64_real_3d_stage.gd",
    "w63-a7-cascade/ci/w64_browser_acceptance.py",
    "w63-a7-cascade/Main.tscn",
    "w63-a7-cascade/project.godot",
    "w63-a7-cascade/export_presets.cfg",
    "w33-godot-native/scripts/OSGARDCore.gd",
    "w33-godot-native/scripts/OSGARDMain.gd",
    "w33-godot-native/scripts/OSGARDRig.gd",
    "tooling/last-frontier/release_package.py",
    "tooling/last-frontier/w62_source_guard.py",
    ".github/workflows/last-frontier-w64-real-3d.yml",
]

def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()

def check_paths(paths):
    paths = set(paths)
    extra = paths - ALLOWED
    missing = REQUIRED - paths
    if extra or missing:
        raise ValueError("W65 unreviewed or missing scope: " + repr({
            "unexpected": sorted(extra), "missing": sorted(missing),
        }))
    return sorted(paths)

def audit(base, head):
    if not re.fullmatch("[0-9a-f]{40}", base or ""):
        raise ValueError("Base must be an exact Git commit SHA")
    if not re.fullmatch("[0-9a-f]{40}", head or ""):
        raise ValueError("Head must be an exact Git commit SHA")
    if git("rev-parse", "HEAD") != head:
        raise ValueError("CI checkout is not the stated head")
    git("cat-file", "-e", base + "^{commit}")
    if git("merge-base", base, head) != base:
        raise ValueError("W65 has not incorporated exact reviewed W64 base")
    git("diff", "--check", base, head)
    changed = check_paths(git("diff", "--name-only", "--no-renames", base, head).splitlines())
    pinned = {}
    for path in PROTECTED:
        old = git("rev-parse", base + ":" + path)
        new = git("rev-parse", head + ":" + path)
        if old != new:
            raise ValueError("Protected gameplay/3D/CI mutated: " + path)
        pinned[path] = new
    core = Path("w63-a7-cascade/scripts/A7CascadeCore.gd").read_text()
    story = Path("w63-a7-cascade/scripts/A7IncidentDirector.gd").read_text()
    audio = Path("w63-a7-cascade/scripts/A7ProceduralAudio.gd").read_text()
    screen = Path("w63-a7-cascade/scripts/A7CascadeScreen.gd").read_text()
    if "class_name A7CascadeCore" not in core or "class_name A7IncidentDirector" not in story:
        raise ValueError("Original source classes missing")
    if any(token in story for token in ("OS.execute(", "HTTPClient", "JavaScriptBridge")):
        raise ValueError("Narrative is not offline-only")
    if "AudioStreamGenerator" not in audio or any(
        token in audio for token in ("HTTPClient", "AudioStreamMP3", "AudioStreamOggVorbis")
    ):
        raise ValueError("Sound module must synthesize original offline short tones")
    if "model.choose(action)" not in screen or "_update_forecast" not in screen:
        raise ValueError("Playable action/forecast integration missing")
    return {
        "schema": "LAST_FRONTIER_W65_EXACT_SOURCE_CAUSAL_STORY_V1",
        "status": "PASS", "base_sha": base, "head_sha": head,
        "changes": changed, "protected_original_blobs": pinned,
        "original_game_rules_changed": False,
        "original_3d_geometry_changed": False,
        "real_phone_certified": False, "commercial_name_cleared": False,
        "production_approved": False, "allow_master_merge": False,
        "deployed": False,
    }

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--base", required=True)
    p.add_argument("--head", required=True)
    p.add_argument("--out", required=True, type=Path)
    args = p.parse_args()
    try:
        record = audit(args.base, args.head)
    except (ValueError, subprocess.CalledProcessError) as ex:
        record = {
            "schema": "LAST_FRONTIER_W65_EXACT_SOURCE_CAUSAL_STORY_V1",
            "status": "FAIL", "head_sha": args.head,
            "error": str(ex), "production_approved": False,
            "allow_master_merge": False, "deployed": False,
        }
    args.out.parent.mkdir(parents=True, exist_ok=True)
    args.out.write_text(json.dumps(record, ensure_ascii=False, indent=2) + "\n")
    print("W65 EXACT SOURCE " + record["status"] + " / PRODUCTION HOLD")
    if record["status"] != "PASS":
        raise SystemExit(2)

if __name__ == "__main__":
    main()
