# OSGARD R135 W6 — portrait optical framing and legible 3D diagnostics

## Evidence driving the change
W5 real Chromium screenshots (`w5-portrait-optical-active.png`, `w5-desktop-optical-active.png`, Actions run `40082233653`) show an optical inspection view with a large unused dark upper region and an orange target close to the right edge. Gameplay and touch input work; the presentation and clarity do not.

The prior camera multiplied orbit distance by `max(1, 1.35 / aspect)` for the optical view. At 1081 x 2202 (aspect ~0.49) it turned a 6.3-unit distance into ~17.3 units. It also tracked only 42% of carriage displacement.

## Implemented in W6 candidate
1. Portrait Camera3D uses `KEEP_WIDTH` and a 61-degree horizontal field-of-view target instead of multiplying zoom by a raw inverse aspect. Landscape continues to use `KEEP_HEIGHT` and the original 55-degree FOV.
2. Optical camera follows the **actual animated 3D head node** (full X, Y and Z), not an approximate fixed focus; portrait optical minimum distance 7.8 world units. The system still respects mouse-wheel and touch-pinch user zoom above the minimum.
3. Service-deck and cooling-side inspection presets aim at their physical diagnostic components.
4. Simulated fault discs are larger and 3D labels readable; labels report **INSPECT** or **CLEARED** in words instead of relying solely on amber/green. All fault sources remain synthetic.
5. Expose read-only browser telemetry: `camera_keep_width`, `camera_fov`, `camera_target_visible`, normalized `camera_target_screen_x/y`, `camera_effective_distance` and `optical_tracking`. No device telemetry or control API added.

## Acceptance contract
- Godot 4.4.1 native game script imports and existing W5 smoke stays green (all three faults, two quality models, training scenario and safety locks).
- Desktop Chromium visual QA: moving optical head projected inside normalized `x=0.25..0.75`, `y=0.22..0.78`; landscape retains `KEEP_HEIGHT`.
- Pixel 7 software touch/portrait QA: optical head projected inside normalized `x=0.25..0.75`, `y=0.24..0.73`; `KEEP_WIDTH` enabled; W5 real touch challenge still completes.
- Additional screenshots `w6-desktop-optical-active.png` and `w6-portrait-optical-active.png` retained for visual audit.
- `.github/workflows/r135-web-optimized.yml` produces independent W6 **candidate** manifests. W5 production ZIP staging, source pin and deployed asset version remain intact; no W6 release or site publication until validation.

## Performance and quality limits
Software Chromium with SwiftShader validates behavior and framing but not physical iOS/Android GPU FPS, energy use or thermals. This is a visual usability improvement toward production-quality game UX, not a claim of cinematic photorealistic AAA.
