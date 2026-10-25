#!/usr/bin/env python3
"""R79 contract: do not mark a fake or downsampled fixture as four real Godot viewports."""
from pathlib import Path

ROOT = Path(".")
RUNNER = ROOT / "scripts/omega-four-viewport-real-ci.sh"
WORKFLOWS = [
    ".github/workflows/omega-r27-streetfront-qa.yml",
    ".github/workflows/omega-r28-civic-qa.yml",
    ".github/workflows/omega-r28-road-paint-qa.yml",
    ".github/workflows/omega-r29-wet-city-qa.yml",
    ".github/workflows/omega-r36-real-frame-qa.yml",
]

script = RUNNER.read_text(encoding="utf-8")
assert "set -euo pipefail" in script
assert "OMEGA_CI_GL_BACKEND=mesa LIBGL_ALWAYS_SOFTWARE=1" in script
assert "xvfb-run -a" in script
assert "--retries=0" in script
assert "playwright.omega-portrait-preview.config.mjs" in script
assert "omega-original-four-viewport-evidence" in script
assert "if [ \"$failure\" -ne 0 ]" in script
for view in ("portrait-390x844", "small-phone-320x568",
             "landscape-phone-844x390", "desktop-1366x768"):
    assert view in script, f"missing native Godot viewport {view}"

for workflow in WORKFLOWS:
    data = (ROOT / workflow).read_text(encoding="utf-8")
    assert "bash scripts/omega-four-viewport-real-ci.sh" in data, workflow
    assert "xvfb libgl1-mesa-dri libegl1 libgl1" in data, workflow
    assert "omega-original-four-viewport-evidence/" in data, workflow
    assert "'scripts/omega-four-viewport-real-ci.sh'" in data, workflow
    assert "run: npx playwright test --config playwright.omega-portrait-preview.config.mjs" not in data, workflow

print("PASS: 5 real four-viewport Godot CI workflows enforce Mesa, zero retries and original PNG evidence")
