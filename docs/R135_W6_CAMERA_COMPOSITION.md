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

## W6.1 correction after visual artifact review

- First W6 candidate completed full native+Chromium+Nginx CI but did not pass **visual** review. Evidence from `r135-w6-qa.zip`: the main optical unit was easier to spot but the machine occupied only the left portion of the portrait frame.
- Reproducible image heuristic (blue industrial surfaces, central 70% width, exclude HUD): first substantial equipment row **W5 0.4105 screen height; W6 first cut 0.4214**. This is not an improvement. It is an informal metric, not an image-quality score.
- W6.1 now aims portrait inspection **left and below** the moving head to place the highlighted target toward the upper-right scene region and expose more of the equipment. Optical camera FOV uses 57 degrees portrait, 53 landscape.
- Godot telemetry adds `machine_top_screen_y` projected from a fixed original-geometry reference rail at `Vector3(0, 3.78, 5.37)`. Mobile browser smoke rejects frames where this point falls below 37% of viewport height; the moving optical node must remain within the existing safe area.
- W6.1 is still candidate-only. Do not merge on numeric target-centering alone: review actual pixel screenshots and regression results before approval.

## W6.2 and W6.3 measured fixes (candidate, not released)

- W6.1 mobile failure, Actions `40084348324`: optical head projected to `x=0.7673` (QA allows maximum 0.75). Main rail projection `y=0.3616`.
- W6.2 at commit `8ea6047c072cec69694bba7537f3a6657daa2c92`, Actions `40108456405`: optical head moved to `x=0.6190`, `y=0.3646`; rail `y=0.3681`. The game and desktop WebGL passed, but portrait QA still required an obsolete FOV `>= 60` after the actual camera was set to 57 degrees. This was a **test specification error**, not a crash.
- W6.2 screenshot has no right-edge text cut-off, but large active label overlays the equipment and labels for unrelated faults add noise. Its first substantial blue-geometry row starts at `0.2952` of image height versus W5 `0.4105`, measured using the same fixed color/width heuristic; this is not an objective art quality score.
- W6.3 at commit `82cc6578468d859170c7e9d0d56f03e335a1374a` changes four files in a single atomic Git commit: move portrait framing slightly upward, reduce fault-label footprint, show only the active in-world fault label while preserving passive markers, expose `fault_label_visible_count`, and assert FOV `56-58` plus only one visible active label on desktop and touch QA.
- Await GitHub Actions `40108970977` and inspect real portrait screenshot before approving visual promotion. W5 production remains pinned and untouched.

## W6.3 passing gameplay + pixel evidence; W6.4 caption refinement

- Candidate run `40108970977` on source `82cc6578468d859170c7e9d0d56f03e335a1374a` completed **SUCCESS**: Godot 4.4.1, real desktop/mobile SwiftShader WebGL mission, Nginx gzip/WASM/PCK 206 and stored QA assets. The artifact is `12565549877` and has an independently inspected W6 manifest (version `r135-web-framing-w6-20261024`).
- Real 1082x2202 portrait image passed the fixed-color geometry gate: first substantial structure at 27.66% screen height, blue geometry coverage 29.05% of sampled game area. W5 reference started at 41.05%.
- Visual review still identified a **portrait-only occlusion**: the caption overlapped/partially disappeared behind the top beam. Desktop caption was readable. W6.4 raises the portrait caption to 1.34 local units while leaving desktop placement at 0.82, without changing mission logic or camera targeting.
- Candidate run `40109700192` validates this final caption adjustment. Do not merge or promote until the new screenshot has been inspected.
- New `scripts/r135-pixel-composition-qa.py` gives a repeatable screenshot gate; W5 fails and the improved W6.3 reference passes. Pillow-based pixel checks are an auxiliary composition metric only, never proof of AAA rendering or hardware FPS.

## W6.4 FINAL CANDIDATE — approved for code merge

- GitHub Actions run `40109700192` completed **success** on engine snapshot `947b4627080636543ae5e873b88b50e61f13beb4`: Godot 4.4.1 native, desktop and Pixel emulation real Chromium gameplay, Nginx WASM and HTTP-206 byte ranges.
- Immutable workflow artifact `12565818008` contains `OSGARD_R135_OPTIMIZED_WEB.zip`, `R135_OPTIMIZED_MANIFEST.json` and screenshots (retention 14 days).
- Independently computed manifest SHA-256: `0638f1ad5c0ab26d2d112e63bd1759923e5401a85ad4f2cedd450bbb7def2f61`; version `r135-web-framing-w6-20261024`.
- Visually inspected `w6-portrait-optical-active.png`: the active optical caption now appears **fully above** the metal rail; no right-edge clipping. The pixel-based gate passed (first blue-geometry structure at 26.25% height, sampled geometric coverage 28.82%). W5 begins at 41.05%.
- The pass is **software WebGL and mobile emulation**, not physical-device FPS/thermals and not AAA art certification.
- Code PR can merge safely with W5 production artifact pin unchanged. To publish W6, create a **separate promotion PR** that pins this verified artifact ID, source SHA and manifest digest; require candidate Nginx, local preflight and public SSH health checks with rollback. Do not use unverified latest artifacts.
