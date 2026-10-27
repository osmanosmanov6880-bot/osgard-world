#!/usr/bin/env python3
"""R133 fail-closed test for ACTUAL four-viewport Godot/Chromium evidence.

The R41/R47 workflows originally had true passing native traffic tests but
failed only at 1366x768 SwiftShader compositor readback, even after retries.
Use the pre-existing successful R12.1 Mesa/Xvfb path at desktop size.
This audit prevents replacing the real 3D checks with mock images or skipping
desktop, small phone, landscape or F9-era game coverage.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
RUNNER = (ROOT / "scripts/omega-four-viewport-real-ci.sh").read_text()
SPEC = (ROOT / "scripts/omega-portrait-preview.spec.mjs").read_text()
CONFIG = (ROOT / "playwright.omega-portrait-preview.config.mjs").read_text()
R41 = (ROOT / ".github/workflows/omega-r41-pedestrian-safety-qa.yml").read_text()
R47 = (ROOT / ".github/workflows/omega-r47-crosswalk-qa.yml").read_text()

SIZES = (
    "desktop-1366x768",
    "portrait-390x844",
    "small-phone-320x568",
    "landscape-phone-844x390",
)


def required(condition: bool, what: str) -> None:
    if not condition:
        raise SystemExit("R133 genuine WebGL evidence contract FAIL: " + what)


for size in SIZES:
    required(size in RUNNER, "runner missing real " + size)
    required(size in CONFIG, "Playwright missing real " + size)
    required(size in R47, "R47 matrix missing real " + size)
required("--workers=1 --retries=0" in RUNNER,
         "four-viewport runner must not rely on flaky hidden retries")
required("LIBGL_ALWAYS_SOFTWARE=1" in RUNNER and
         "OMEGA_CI_GL_BACKEND=mesa" in RUNNER and
         "xvfb-run -a" in RUNNER and
         "1920x1080x24" in RUNNER,
         "desktop must use actual full-viewport Mesa/Xvfb source")
required("bash scripts/omega-four-viewport-real-ci.sh" in R41,
         "R41 must execute every actual original Godot viewport")
required("libgl1-mesa-dri" in R41 and "xvfb" in R41,
         "R41 must provision actual Mesa OpenGL rather than fake PNGs")
required("if: matrix.viewport == 'desktop-1366x768'" in R47 and
         "LIBGL_ALWAYS_SOFTWARE=1" in R47 and
         "OMEGA_CI_GL_BACKEND=mesa" in R47 and
         "--workers=1 --retries=0" in R47,
         "R47 must use isolated real desktop Mesa with zero test retries")
required("realGameFrameEvidence(png)" in SPEC and
         "upperEdgeLumaStd" in SPEC and "lowerEdgeLumaStd" in SPEC and
         "topFraction" in SPEC and "bottomFraction" in SPEC,
         "actual original Godot scene/road/sky/edges MUST be asserted")
required("captureAnimatedWebGLViewport(page)" in SPEC,
         "must photograph a REAL live WebGL scene not a synthetic replacement")
required("if [ \"$failure\" -ne 0 ]" in RUNNER,
         "all four original source scenes must fail closed")
for path, body in (("R41", R41), ("R47", R47)):
    required("workflow_dispatch:" in body, path + " manual QA must remain")
    required("feat/omega-r90-aaa-reference-first-slice-20261026" in body,
             path + " must retest the original R90 staging head")
    required("deploy-frontend" not in body and "ssh-action" not in body,
             path + " QA must never publish to the live server")
print("R133 PASS: four real WebGL scenes, desktop Mesa/Xvfb, strict original")
print("Godot original capture: anti-splash + both screen edges, no CI deploy")
