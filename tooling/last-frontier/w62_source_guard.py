#!/usr/bin/env python3
"""W62: verify that release packaging does not change the W61 source game."""
import argparse
import json
import re
import subprocess
from pathlib import Path

BASE = "8da37a1f264c1b4387e5b93b67968a523dabe13d"
ALLOWED = {
    "tooling/last-frontier/release_package.py",
    "tooling/last-frontier/test_release_package.py",
    "tooling/last-frontier/w62_source_guard.py",
    "tooling/last-frontier/test_w62_source_guard.py",
    ".github/workflows/last-frontier-w62-review.yml",
    "docs/LAST_FRONTIER_W62_REVIEW.md",
}
MANDATORY = {
    "tooling/last-frontier/release_package.py",
    "tooling/last-frontier/test_release_package.py",
    ".github/workflows/last-frontier-w62-review.yml",
}
PROTECTED = (
    "w33-godot-native/project.godot",
    "w33-godot-native/Main.tscn",
    "w33-godot-native/export_presets.cfg",
    "w33-godot-native/scripts/OSGARDCore.gd",
    "w33-godot-native/scripts/OSGARDRig.gd",
    "w33-godot-native/scripts/OSGARDMain.gd",
    "w33-godot-native/scripts/OSGARDText.gd",
    "w33-godot-native/tests/test_six_missions.gd",
    "w33-godot-native/tests/test_w61_brand_and_phase_hud.gd",
    "tooling/last-frontier/w61_source_guard.py",
    ".github/workflows/osgard-w61-identity-hud.yml",
    "w33-godot-native/ci/w49_source_contract.py",
    "w33-godot-native/ci/w52_release_gate.py",
    ".github/workflows/r135-w33-operator-debrief-native-qa.yml",
)


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def verify_changes(changed):
    changed = set(changed)
    if changed - ALLOWED:
        raise ValueError("Unreviewed game/production file changed: " + repr(sorted(changed - ALLOWED)))
    if not MANDATORY.issubset(changed):
        raise ValueError("Incomplete W62 release source and negative-test scope")
    return sorted(changed)


def verify(head):
    if not re.fullmatch("[0-9a-f]{40}", head or ""):
        raise ValueError("W62 requires exact 40-character commit SHA")
    if git("rev-parse", "HEAD") != head:
        raise ValueError("Checked-out commit differs from requested source")
    git("cat-file", "-e", BASE + "^{commit}")
    if git("merge-base", BASE, head) != BASE:
        raise ValueError("Missing reviewed W61 source ancestor")
    changed = verify_changes(git("diff", "--name-only", "--no-renames", BASE, head).splitlines())
    subprocess.run(["git", "diff", "--check", BASE, head], check=True)
    blobs = {}
    for path in PROTECTED:
        old = git("rev-parse", BASE + ":" + path)
        new = git("rev-parse", head + ":" + path)
        if new != old:
            raise ValueError("Game, safety or original CI changed by W62: " + path)
        blobs[path] = new
    return {
        "schema": "LAST_FRONTIER_W62_NO_SOURCE_MUTATION_V1",
        "status": "PASS", "source_sha": head, "approved_w61_parent_sha": BASE,
        "changes": changed, "unchanged_git_blobs": blobs,
        "gameplay_modified": False, "old_ci_evidence_reused_as_new_head": False,
        "commercial_name_cleared": False, "physical_certified": False,
        "production_approved": False, "allow_master_merge": False,
        "production_published": False,
    }


def main():
    p=argparse.ArgumentParser()
    p.add_argument("--head",required=True)
    p.add_argument("--out",required=True,type=Path)
    a=p.parse_args()
    try:
        result=verify(a.head)
    except (ValueError,subprocess.CalledProcessError) as e:
        result={"schema":"LAST_FRONTIER_W62_NO_SOURCE_MUTATION_V1","status":"FAIL",
                "source_sha":a.head,"error":str(e),
                "allow_master_merge":False,"production_approved":False,
                "production_published":False}
    a.out.parent.mkdir(parents=True,exist_ok=True)
    a.out.write_text(json.dumps(result,indent=2)+"\n")
    print(result["status"]+"/PRODUCTION_HOLD")
    if result["status"]!="PASS":
        raise SystemExit(2)


if __name__=="__main__":
    main()
