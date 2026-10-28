#!/usr/bin/env python3
"""V12 source manifest and release hold gate; does not certify hardware or AAA.
Requires real Godot/Windows/WebGL/Chromium CI separately in same workflow.
"""
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCES = [
    "scripts/Main.gd",
    "scripts/CrisisEngine.gd",
    "scripts/IPStoryDirector.gd",
    "scripts/IPCheckpointStore.gd",
    "scripts/IPCampaignFlow.gd",
    "scripts/IPCampaignEchoes.gd",
    "scripts/IPWayfinding.gd",
    "scripts/IPPerformanceAudit.gd",
    "scripts/IPReactorAtrium.gd",
    "scripts/IPContainmentFX.gd",
    "ci/browser_webgl_acceptance.py",
    "tests/test_v9_campaign_flow.gd",
    "tests/test_v9_campaign_scene.gd",
    "tests/test_v10_wayfinding.gd",
    "tests/test_v11_campaign_echoes.gd",
    "tests/test_v12_release_gate.gd",
    "docs/V9_TO_V12_IMPLEMENTATION_AND_RELEASE_HOLD_RU.md",
]
missing = [name for name in SOURCES if not (ROOT / name).is_file()]
assert not missing, "Missing mandatory V9-V12 implementation/evidence: " + repr(missing)
manifest = {}
for name in SOURCES:
    data = (ROOT / name).read_bytes()
    assert data, f"Empty source file: {name}"
    manifest[name] = {
        "sha256": hashlib.sha256(data).hexdigest(),
        "bytes": len(data),
    }
main = (ROOT / "scripts/Main.gd").read_text(encoding="utf-8")
story = (ROOT / "scripts/IPStoryDirector.gd").read_text(encoding="utf-8")
campaign = (ROOT / "scripts/IPCampaignFlow.gd").read_text(encoding="utf-8")
browser = (ROOT / "ci/browser_webgl_acceptance.py").read_text(encoding="utf-8")
document = (ROOT / "docs/V9_TO_V12_IMPLEMENTATION_AND_RELEASE_HOLD_RU.md").read_text(encoding="utf-8")
for marker in ("_start_campaign", "_end_action", "campaign.checkpoint()",
               "wayfinder.update_goal", "campaign_echoes.sync",
               "reactor_atrium.cycle_director_shot", "performance_audit.observe",
               'KEY_F3', "KEY_H", "KEY_P"):
    assert marker in main, f"Main did not integrate required feature: {marker}"
for marker in ("carry_crew", "carry_core", "on_campaign_carryover"):
    assert marker in story, "Incomplete real RU/EN campaign narrative " + marker
for marker in ("apply_to_next", "record_victory", "modifier_applied", "restore"):
    assert marker in campaign, "Incomplete campaign consequence/safety " + marker
for marker in ("v12_native_camera_shots", "v12_real_mobile_cam",
               'production_ready', "wayfinder", "campaign_echoes"):
    assert marker in browser, "Missing real WebGL proof coverage: " + marker
assert "PRODUCTION HOLD" in document and "V9" in document and "V12" in document, (
    "Release documentation must explicitly retain production hold and full scope")
# Explicitly do not turn this gate into production approval.
output = {
    "format": "IRON_PULSE_V12_SOURCE_INTEGRITY",
    "manifest_files": len(manifest),
    "files": manifest,
    "software_tests": "run separately by exact-head GitHub Actions",
    "gameplay_preview": True,
    "hardware_certified": False,
    "professional_aaa_art_certified": False,
    "production_ready": False,
    "release_hold": True,
    "outstanding": [
        "true Windows GPU acceptance",
        "physical Android/iOS testing",
        "real controller latency and input QA",
        "independent gameplay and accessibility review",
        "professional AAA character/assets/animation/audio",
        "trademark and content licensing",
        "staging rollback and human GO"
    ],
}
proof = ROOT / "build" / "proof"
proof.mkdir(parents=True, exist_ok=True)
(proof / "V12_SOURCE_REVIEW.json").write_text(
    json.dumps(output, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
print(f"IRON PULSE V12 SOURCE INTEGRITY PASS: {len(manifest)} exact files")
