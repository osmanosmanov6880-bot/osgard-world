# OSGARD R135 — release completion programme W7 → W10

Owner: OSGARD WORLD. Candidate started on 2026-10-24. All equipment, physics and faults are **simulated**. The project must never claim live connection to an industrial machine.

## Verified baseline

- W5 public browser release: 4-step training + 3 independent 5-step diagnostic faults, safety interlocks, native source assets HERO/ECO, local record and 8 touch controls. Proven by Godot 4.4.1, desktop+Pixel software WebGL and production byte-range smoke.
- W6.4 camera/UI: original photogrammetric-style GLB assets unchanged; mobile inspection caption not occluded, meaningful geometry begins at 26.25% screen height versus W5 41.05%. Candidate run `40109700192` passed Godot, real Chromium mobile emulation and Nginx.
- W6.4 delivery PR #315 merged. Production remains **unconfirmed** until a server workflow explicitly validates published `r135-web-framing-w6-20261024` with source SHA, checksum and HTTP 206. Do not infer publication from a cancelled or pending workflow.

## W7 — restrained premium 3D service studio (implemented in candidate code; CI pending)

Deliverables:
1. Material hierarchy: matte charcoal non-mirror floor, natural neutral background, warm white key, cool-neutral rim, desaturated copper wayfinding, low-emission accents.
2. Minimal industrial cyclorama, side pylons, structural truss and subtle perimeter; preserve all HERO/ECO source meshes.
3. **Geometry batching**: 18 floor grid segments drawn as two `MultiMeshInstance3D` batches rather than 18 independent scene mesh instances. Record expected stage batches/instances, not fabricated GPU draw-call totals.
4. ECO/HERO tier changes material emission and stage detail exposure alongside the existing model/reflection control.
5. Accessibility: `prefers-reduced-motion` disables decorative fault-marker pulsing only (never real mission and servo timing). Reduced-motion QA in simulated Pixel browser context.
6. Neutral high-contrast operator HUD without bright neon; same 8 tested buttons on desktop/mobile.

Acceptance: native Godot 4.4.1 passes, SwiftShader Chrome/Pix7 mission+diagnosis passes, 18 studio grid segments / 2 MultiMesh batches proven, 3 faults still complete, ECO/HERO source meshes unchanged. Screenshot inspected for no loss of legibility and no clipped portrait caption.

## W8 — visible smoothness, budget and accessibility (next milestone)

- Record stable `Engine.get_frames_per_second()` as **software-renderer telemetry only**. A single sample is not a performance benchmark.
- Test portrait resolutions (360×780, 390×844, 430×932), viewport resize, touch hitboxes, zoom boundaries and device-motion preferences.
- Profile startup allocations/PCK, 75th percentile time to first interaction under production-like traffic shaping, and JavaScript errors without adding remote telemetry.
- Define EC0 quality budget vs HERO and ensure visual-effects toggles do not alter mission scoring or physics.
- Physical Android/iOS device 1% lows, memory, thermals and battery: **not done** without actual devices; requires independent test evidence.

## W9 — complete playable service chapter

- Three different fault cases with clear visual clues, safe order, contextual helper prompts and score feedback, plus fourth optional variation that does not touch production machinery.
- Player progression: self-guided first-use tutorial → four-step maintenance → five-step inspection → performance review with errors, duration and explanations.
- State machine test: all 3 fault routes, wrong order, restart refusal until sealed, scoring persistence and no accidental skip. All cases must be reachable through the **existing** eight buttons and keyboard.
- Accessibility: UI states must communicate outcomes in text, not color only. Add a clear “simulation” label.

## W10 — release readiness and delivery

- Release from exact successful CI artifact (not `latest`), verify independent SHA-256 digest, content member hashes, Nginx MIME + WASM gzip and PCK HTTP 206. Preserve rollback to known-good W5/W6.
- Public deploy: actual byte-identical manifest, JS/WASM/PCK, responsive route, 8 touch buttons and catalog links; all adjacent OSGARD games retain their expected binary assets.
- Real hardware FPS + thermal and usability assessment is a non-negotiable quality gate for claims of mobile production excellence. Without this, publish as **software-tested browser game**, never as hardware-tested AAA.
- Run browser test on screenshots and a hands-on playthrough for composition. A high score is not proof of photorealistic graphics.

## Non-goals and integrity rules

- Never claim 8K cinematic/AAA photorealism because UI was recolored or a web page displays successfully.
- Never change the official live game while a new candidate has failing or missing tests.
- Never overwrite archived release binaries to disguise mismatched build provenance.
- Avoid independent release of W7 source via catalog before Godot+Chromium screenshot acceptance.
