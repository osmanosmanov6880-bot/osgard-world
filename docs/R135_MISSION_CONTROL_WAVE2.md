# OSGARD R135 — Mission Control W2

## What actually changed in the Godot scene

OSGARD R135 is still a standalone engineering **simulation**. Its original HERO and ECO GLB models, PBR materials and R136 isolation remain unchanged. This wave adds an actual game loop on top of that source:

1. Press **START MISSION** (or **M**) to initialize a repeatable maintenance simulation.
2. **OPEN HATCH** (**F**). Objective becomes 2/4.
3. **PLAY / PAUSE** (**Space**) to pause the simulated drive. Objective becomes 3/4.
4. **OPEN HATCH** again to close it. Objective becomes 4/4.
5. **PLAY / PAUSE** again to resume. Mission completes with elapsed time. Replaying resets the task and loop.

Skipping a required step changes the selected simulated mechanism but does **not** advance the objective. This is a finite playable inspection exercise, **not a physically validated machinery controller**.

## Camera and device UX

- Mouse drag / one finger: orbit around current focus.
- Wheel / two fingers: zoom in and out within bounded distance.
- **NEXT VIEW** / **V** cycles OVERVIEW → SERVICE DECK → OPTICAL HEAD → SIDE INSPECTION.
- **RESET VIEW** / **R** returns to overview.
- **ECO / HERO** / **Q** changes *actual source GLB meshes* at runtime.
- Six large in-engine buttons form a responsive 3×2 desktop / 2×3 portrait layout.
- Status HUD reports quality, motion, viewpoint, objective progress and simulated time.

## Acceptance gates (mandatory)

- Godot 4.4.1 native import and `tests/smoke.gd` prove real imported ECO/HERO scene, wrong-order mission rejection, four-step completion, paused/active actuator state, camera preset reset and UI presence.
- `scripts/r135-web-smoke.mjs` must run in Chromium SwiftShader WebGL2 on desktop and mobile emulation, wait for the *actual Godot controller*, execute mission through desktop keys or **mobile touchscreen buttons**, prove HERO/ECO runtime mesh switching, and save screenshots.
- Only after all checks pass is the Web ZIP published as `r135-web-mission-20261024`.
- Production `scripts/r135-release-stage.py` must checksum-verify all ZIP files, then `deploy-frontend.yml` stages the runtime in `/games/r135-service/`.
- `scripts/r135-production-smoke.mjs` checks final HTML, manifest version, PCK bytes, WASM MIME and HTTP 206 partial-range delivery.

## Limitations

This wave is a playable prototype with original imported models, **not** a finished AAA title. Desktop/mobile QA uses software WebGL in Chromium, **not** actual GPU/phone FPS data. The complete historical R134 baseline is still unavailable, and this standalone R135 does not replace R136. Source is merged only after CI. Public site availability requires the main server workflow to finish and its live HTTP assertions to pass.
