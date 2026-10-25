# OSGARD R135 — approved premium/luxury onboarding implementation (W19 candidate)

> This changes genuine Godot gameplay code, not a static render. The concept-art reference is **a target**, not evidence of achieved AAA photorealism.

## Player experience

- **Default language: Russian.** Native and Web start in RU; English is available through the actual switch or `?lang=en`. Existing mission/diagnostic data and local W14 case save schema are unchanged.
- **Original procedural OSGARD vector mark** in the top HUD. No external generated images, logos or commercial fonts are embedded.
- **A non-blocking glass-themed interface** with high contrast dark titanium, restrained brushed-copper/orange focus, cyan hints, soft depth and strong text hierarchy. The main eight real operator buttons still work, with larger desktop console width and responsive phone layout.
- **An actual 6-chapter playable curriculum:** ① Russian greeting → ② inspection viewpoints → ③ stop drive, safely open/close hatch and reseal → ④ optical fault and genuine target scan → ⑤ repeat cooling/interlock faults → ⑥ independently saved training result. Active tutorial CTA invokes original simulation actions; no fictional WASD movement/remote industrial commands.
- `R135PremiumOnboarding.gd` saves only `user://r135_luxury_tutorial_v1.cfg`. It never modifies `user://r135_challenge_record.cfg` (W14 safety/score/legacy migration).
- Users can collapse/open onboarding and keep using the existing scene, keyboard, mouse and touch controls. Relevant keys are V, M, C, E, F, Space, Q, R and L.
- **Luxury industrial architecture** via 5 *additional* instanced decorative batches (41 pieces): rear pilasters, overhead rib structure, side supports, copper wayfinding inlays and soft cyan service LED strips. Original ECO/HERO GLBs and 36 texture images are unchanged. New depth/light settings differ in ECO/HERO without expensive additional shadow casters.

## Safety and honest limitations

This is *only a simulation*. Real equipment requires trained staff, lockout/isolation and verified zero energy. Hazardous action order is still rejected by the W13 real simulation director.

The new environment is an optimized visual uplift, **not AAA photorealism/8K certification**. WebGL Compatibility rendering, software Chromium smoke and independent original screenshots are not proof of real Android/iPhone GPU thermals or physical performance. Do not replace currently published W18/W14 game binaries with the W19 candidate until distinct exact-source manifest/artifact, native and browser acceptance, independent visual review and protected production gate have all passed.

## Acceptance criteria

1. Godot 4.4.1 imports original ECO/HERO models and runs `tests/smoke.gd` with new six-stage interactions, correct local save, no regression of safety interlocks or 3 genuine faults.
2. WebGL browser QA confirms first screen is actually Russian; main CTA advances the real lesson, changing camera and collapsing guide, with original unmodified desktop and Pixel-emulated screenshots.
3. Layout tests on desktop 1366×768 and mobile 360×780, 390×844, 430×932, 932×430, with good touch target sizes, 8 working original buttons, zero view-overlap, and built-in reduced-motion availability.
4. Stage `render_budget` reports original 2 grid batches/18 strips, original 3 W15 detail batches/47 instances, new luxury 5 batches/41 instances, 8 original unbatched stage meshes, no additional shadow casters.
5. All 3 fault cases must complete in Chromium desktop and software Pixel, never reporting actual device hardware FPS.

## Release isolation

Feature branch `feat/r135-approved-aaa-luxury-russian-onboarding-20261025` builds the unique WebGL label `r135-luxury-academy-w19-candidate-20261025`. Existing independent W18 source pin, W18 GitHub Release, W14 rollback and protected production selector are **not changed by this PR**. A future W19 production release needs its own immutable review pin, original screenshots/hashes and successful protected deployment.
