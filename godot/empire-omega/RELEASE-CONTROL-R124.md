# EMPIRE Ω R124 — original foreground reflective window integration

**Status:** unpublished real Godot 4.4.1 PR candidate based on fully merged R123 `7534265174775204b5c8a3ca879cfb19903dd6d7`. This document is QA policy and source provenance, not a claim that R124 passed.

## Prior-work reconciliation

The original older [PR #540](https://github.com/osmanosmanov6880-bot/osgard-world/pull/540) implemented valid daytime near-camera PBR glass and a mobile/night shader fallback, but was authored against R90 at `ed224d1` before R119 real glazing, R120 woody canopy and R123 walking NPCs. Its PR was later **unmergeable**. The draft [PR #541](https://github.com/osmanosmanov6880-bot/osgard-world/pull/541) tried to reintegrate R119/R120 from the same older source and also became stale.

**This R124 branch safely ports the minimal original #540 rendering rules** into the actually current `godot/empire-omega/scripts/world_builder.gd`. It does **not** replace any other code files from the older branch or delete existing source. The foreground city uses its original multi-thousand one-batch `InstancedFacadeWindows` and independent `InstancedMetalWindowFrames`. Standard/cinematic daytime uses true Godot PBR shading with a bounded rough/specular surface; night preserves the preexisting power-dependent warm/cool windows; mobile LOW uses an unshaded GPU-efficient fallback, **without new material or draw batch**.

The actual city `facade_windows`, `window_points`, `facade_frames`, weather, traffic, game state, original R119 architectural windows, R120 trees and R123 pedestrians are unchanged apart from the material settings. The new `_apply_window_shading(hour)` runs BEFORE old window-color early return and is also called when quality tiers change; no cached electricity state can prevent correct GPU shading change.

## Acceptance (hard fail closed)

1. Original Godot 4.4.1 strict compiler+world import; `v98_r124_foreground_window_day_night.gd` tests actual live world with >1,000 original authored facade windows, unchanged original `MultiMesh` positions and shared graphics. Day/LOW/cinematic/night/blackout/recovered-day modes assert native material shading mode changes and 0 saved-game changes. Old original `v95_r119_real_glazing_readable_atlas.gd`, `v96_r120_sculpted_arbor_physical_wood.gd`, `v97_r123_real_pedestrian_body_gait.gd` remain strict regressions.
2. Full `scripts/omega-r109-release-sentinel.py` requires **31 real original Godot source suites**, 17 source-file SHA-256 locks and 3 pinned original Poly Haven CC0 maps. Enforce exact original immutable PR HEAD, never synthetic merge artifact, while building WebGL.
3. True `index.html` + `index.pck` + `index.wasm` Godot export; **four actual Chromium tests** (desktop drive+Tab, 390×844 touch, 3 screenshots proving F9 native city focus and restore, honest host rAF telemetry). Release CI uploads original executable archive, image evidence and exact binary/source SHA + provenance manifest with **no SSH deployment**.
4. Targeted `.github/workflows/omega-r124-foreground-reflective-streets-qa.yml` independently executes original daytime/night source regression and tests rendered Chromium pixels.
5. **After PR merge into R90, rerun all same checks on the actual merged branch SHA** and preserve rollback evidence. No early claim of approval from old #540, or from a standalone native test.

**Production safety**: Public R87 stays at source `43ae041e8df52418ca74c02405de9c196b59bd37`. Master PR #500 remains draft because merging it triggers actual WebGL+VPS deployment. Independent comparison of **actual** Godot pixels to user's two approved visual references and real target-hardware graphics smoothness have not been completed. A procedural graphical upgrade does not meet AAA photoreal certification.
