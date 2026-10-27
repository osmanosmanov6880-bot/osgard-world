#!/usr/bin/env python3
"""W61 exact-source brand/UI scope gate. Never authorizes production.

Run in full git checkout. Compare W61 against approved W60 brand proposal,
NOT against an older green CI result. This verifies what changed, not hardware.
"""
import argparse
import json
import re
import subprocess
from pathlib import Path

BASE = "6186356cd1807007533f72aeee06ccaa2035d4e6"
ALLOWED = frozenset({
    "w33-godot-native/scripts/OSGARDMain.gd",
    "w33-godot-native/scripts/OSGARDText.gd",
    "w33-godot-native/tests/test_w41_typography.gd",
    "w33-godot-native/tests/test_w61_brand_and_phase_hud.gd",
    "tooling/last-frontier/w61_source_guard.py",
    "tooling/last-frontier/test_w61_source_guard.py",
    ".github/workflows/osgard-w61-identity-hud.yml",
    "docs/LAST_FRONTIER_W61_VERTICAL_SLICE.md",
})
MANDATORY = frozenset({
    "w33-godot-native/scripts/OSGARDMain.gd",
    "w33-godot-native/scripts/OSGARDText.gd",
    "w33-godot-native/tests/test_w41_typography.gd",
    "w33-godot-native/tests/test_w61_brand_and_phase_hud.gd",
})
PROTECTED = (
    "w33-godot-native/project.godot",
    "w33-godot-native/Main.tscn",
    "w33-godot-native/export_presets.cfg",
    "w33-godot-native/scripts/OSGARDCore.gd",
    "w33-godot-native/scripts/OSGARDRig.gd",
    "w33-godot-native/tests/test_six_missions.gd",
    "w33-godot-native/tests/test_scene_integration.gd",
    "w33-godot-native/ci/browser_gameplay_acceptance.py",
    "w33-godot-native/ci/w49_source_contract.py",
    "w33-godot-native/ci/w52_release_gate.py",
    ".github/workflows/r135-w33-operator-debrief-native-qa.yml",
)
MAIN_ALLOWED_METHODS = frozenset({
    "_make_cinematic_overlay", "_create_interface", "_layout_stage_for_screen",
    "_refresh", "_publish_web_accessibility", "_sync_camera_rail",
})


def git(*args):
    return subprocess.check_output(["git", *args], text=True).strip()


def validate_paths(changed):
    paths = set(changed)
    if paths - ALLOWED:
        raise ValueError("Unauthorized gameplay/production path: " + repr(sorted(paths - ALLOWED)))
    if not MANDATORY.issubset(paths):
        raise ValueError("Incomplete native brand implementation/test: " +
                         repr(sorted(MANDATORY - paths)))
    return sorted(paths)


def methods(body):
    """Return each method text, including its implementation, for comparison."""
    out = {}
    match = list(re.finditer(r"(?m)^func ([A-Za-z0-9_]+)\(", body))
    for i, m in enumerate(match):
        name = m.group(1)
        end = match[i + 1].start() if i + 1 < len(match) else len(body)
        out[name] = body[m.start():end].rstrip()
    return out


def validate_main_methods(before, after):
    old, new = methods(before), methods(after)
    if old.keys() != new.keys():
        raise ValueError("Gameplay entrypoints were added/removed during branding")
    changed = sorted(name for name in old if old[name] != new[name])
    unexpected = set(changed) - MAIN_ALLOWED_METHODS
    if unexpected:
        raise ValueError("Branding modified unrelated gameplay method: " + repr(sorted(unexpected)))
    if not {"_refresh", "_make_cinematic_overlay", "_layout_stage_for_screen"}.issubset(changed):
        raise ValueError("Missing integrated native UI changes")
    if "LastFrontierMissionPhaseStrip" not in after or "OSGARD simulated lab, " in after:
        raise ValueError("Missing native phase HUD or stale spoken brand")
    return changed


def validate_main_preamble(before, after):
    """Only a read-only phase-strip declaration may be added outside methods."""
    old = before.split("\nfunc ", 1)[0]
    new = after.split("\nfunc ", 1)[0]
    exact_insert = ("var stage_edition: Label\n"
                    "# W61: source-only cinematic mission phase indicators; no gameplay mutation.\n"
                    "var mission_segments: Array[ColorRect] = []")
    if old.count("var stage_edition: Label") != 1:
        raise ValueError("Original game declarations missing in baseline")
    if new != old.replace("var stage_edition: Label", exact_insert):
        raise ValueError("Unreviewed global state or engine dependency added")
    return True


def validate_localization(before, after):
    new = after
    # Remove only the precise W61 additions: existing strings, decisions and
    # simulation disclaimers must remain byte-for-byte unchanged.
    allowed = (
        '    "brand_desktop":"ПОСЛЕДНИЙ РУБЕЖ   /   ПРОТОКОЛ А7",\n',
        '    "brand_mobile":"ПОСЛЕДНИЙ РУБЕЖ",\n',
        '    "stage_facility":"ОБЪЕКТ A7  //  ДИАГНОСТИКА",\n',
        '    "stage_narrow":"A7  /  НАБЛЮДЕНИЕ",\n',
        '    "stage_classification":"A7 / ЗАКРЫТЫЙ ИССЛЕДОВАТЕЛЬСКИЙ ОБЪЕКТ",\n',
        '    "reactor_title_short":"РЕАКТОР A7",\n',
        '    "reactor_title_long":"РЕАКТОР A7   /   ПРОТОКОЛ",\n',
        '    "stage_idle":"A7 / ОЖИДАНИЕ",\n',
        '    "stage_active":"A7 / ДИАГНОСТИКА",\n',
        '    "stage_alert":"ТРЕВОГА / ПРОВЕРЬТЕ ПРОТОКОЛ",\n',
        '    "stage_complete":"ПРОТОКОЛ / ЗАВЕРШЁН",\n',
        '    "brand_desktop":"LAST FRONTIER   /   A7 PROTOCOL",\n',
        '    "brand_mobile":"LAST FRONTIER",\n',
        '    "stage_facility":"A7 FACILITY  //  LIVE DIAGNOSTICS",\n',
        '    "stage_narrow":"A7  /  OBSERVATION",\n',
        '    "stage_classification":"A7 / RESTRICTED RESEARCH FACILITY",\n',
        '    "reactor_title_short":"REACTOR A7",\n',
        '    "reactor_title_long":"REACTOR A7   /   A7 PROTOCOL",\n',
        '    "stage_idle":"A7 / SECURE STANDBY",\n',
        '    "stage_active":"A7 / LIVE DIAGNOSTICS",\n',
        '    "stage_alert":"ALERT / CHECK SAFETY",\n',
        '    "stage_complete":"PROTOCOL / COMPLETE",\n',
    )
    for entry in allowed:
        if new.count(entry) != 1:
            raise ValueError("Native RU/EN localized brand contract changed")
        new = new.replace(entry, "")
    if new != before:
        raise ValueError("An original gameplay instruction/disclaimer changed")
    return len(allowed)


def verify(head):
    if not re.fullmatch(r"[0-9a-f]{40}", head or ""):
        raise ValueError("Expected 40-character exact source HEAD")
    if git("rev-parse", "HEAD") != head:
        raise ValueError("Checkout not pinned to exact proposed W61 SHA")
    git("cat-file", "-e", BASE + "^{commit}")
    if git("merge-base", BASE, head) != BASE:
        raise ValueError("Proposed branch lacks exact W60 ancestor")
    changed = validate_paths(git("diff", "--name-only", "--no-renames", BASE, head).splitlines())
    subprocess.run(["git", "diff", "--check", BASE, head], check=True)
    blobs = {}
    for path in PROTECTED:
        original, current = git("rev-parse", BASE + ":" + path), git("rev-parse", head + ":" + path)
        if original != current:
            raise ValueError("Protected gameplay/CI/source blob was changed: " + path)
        blobs[path] = current
    before_main = git("show", BASE + ":w33-godot-native/scripts/OSGARDMain.gd")
    after_main = git("show", head + ":w33-godot-native/scripts/OSGARDMain.gd")
    validate_main_preamble(before_main, after_main)
    methods_changed = validate_main_methods(before_main, after_main)
    before_l10n = git("show", BASE + ":w33-godot-native/scripts/OSGARDText.gd")
    after_l10n = git("show", head + ":w33-godot-native/scripts/OSGARDText.gd")
    added = validate_localization(before_l10n, after_l10n)
    return {
        "schema": "LAST_FRONTIER_W61_SOURCE_BOUND_BRAND_V1",
        "status": "PASS", "source_sha": head, "parent_w60_sha": BASE,
        "scope_paths": changed, "protected_original_git_blobs": blobs,
        "native_ui_methods_changed": methods_changed, "localization_entries_added": added,
        "six_mission_logic_modified": False, "original_release_checks_modified": False,
        "old_w58_9of9_claims_transfer_to_new_sha": False,
        "hardware_certified": False, "commercial_title_cleared": False,
        "production_approved": False, "allow_master_merge": False,
        "production_deployed": False,
    }


def main():
    p = argparse.ArgumentParser()
    p.add_argument("--head", required=True)
    p.add_argument("--out", required=True, type=Path)
    a = p.parse_args()
    try:
        result = verify(a.head)
    except (ValueError, subprocess.CalledProcessError) as e:
        result = {"schema": "LAST_FRONTIER_W61_SOURCE_BOUND_BRAND_V1",
                  "status": "FAIL", "source_sha": a.head, "error": str(e),
                  "production_approved": False, "allow_master_merge": False,
                  "production_deployed": False}
    a.out.parent.mkdir(parents=True, exist_ok=True)
    a.out.write_text(json.dumps(result, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(result["status"] + " / " + ("isolated brand evidence" if result["status"] == "PASS" else result["error"]))
    if result["status"] != "PASS":
        raise SystemExit(2)


if __name__ == "__main__":
    main()
