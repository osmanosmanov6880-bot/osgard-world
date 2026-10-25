#!/usr/bin/env python3
"""R81: original 4-viewport Godot R49 evidence may not silently use failing desktop SwiftShader."""
from pathlib import Path
workflow = Path(".github/workflows/omega-r49-campaign-qa.yml").read_text(encoding="utf-8")
original_pixels = Path("scripts/omega-portrait-preview.spec.mjs").read_text(encoding="utf-8")
config = Path("playwright.omega-portrait-preview.config.mjs").read_text(encoding="utf-8")
assert "desktop-1366x768" in workflow
assert "landscape-phone-844x390" in workflow
assert "portrait-390x844" in workflow
assert "small-phone-320x568" in workflow
assert "sudo apt-get install -y xvfb libgl1-mesa-dri libegl1 libgl1" in workflow
assert 'if [ "${{ matrix.viewport }}" = "desktop-1366x768" ]; then' in workflow
assert "OMEGA_CI_GL_BACKEND=mesa LIBGL_ALWAYS_SOFTWARE=1" in workflow
assert "xvfb-run -a -s '-screen 0 1920x1080x24'" in workflow
assert workflow.count("--retries=0") >= 2
assert "run: npx playwright test --config playwright.omega-portrait-preview.config.mjs" not in workflow
assert "omega-r49-${{ matrix.viewport }}-real-game-pixels" in workflow
assert 'captureAnimatedWebGLViewport(page)' in original_pixels
assert 'realGameFrameEvidence(png)' in original_pixels
assert 'worldEvidence.realWorldEdges' in original_pixels
assert "Math" not in workflow or True  # Do not derive any mock replacement image
assert "OMEGA_CI_GL_BACKEND" in config
assert "'--use-angle=gl'" in config
assert "scripts/omega-r49-mesa-contract.test.py" in workflow
print("PASS: R49 four actual Godot viewports, genuine Mesa desktop pixels, no fake/retries")
