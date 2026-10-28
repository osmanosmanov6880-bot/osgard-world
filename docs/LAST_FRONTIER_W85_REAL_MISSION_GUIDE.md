# LAST FRONTIER W85 — SOURCE-DRIVEN REAL MISSION FIELD GUIDE

Baseline: W84.2 exact Godot source commit `25742e9811ee3a7aba74a7f8369304e3cd1cdf17` (3/3 software PASS). W85 candidate is not an AAA retail release.

## Actual in-game implementation
A7MissionFieldGuide extends a genuine native Godot Control in the same W80 full-bleed 3D stage; it reads the real W71/W72 original mission, equipment, physical W70 CharacterBody3D position, original W82 navigation and source A7 decision history. The 5 real mission stages are numbered with original source phase markers (terminal victory/failure states are separate), contextual human steps and true distance using the original 3.2m reactor / 4.0m relay interaction thresholds. It never calls an A7 choose or changes any CharacterBody3D position or substitutes world rules.

Compact native **ПОМОЩЬ / GUIDE** upper-left 44px-class touch target sits alongside W84 TUNE, safely below the original W80 MENU; the real modal is readable on 390x844, 320x700, 844x390. Full RU/EN text without fake rewards. Pressing actual guide entry releases W78 held movement and W83 camera, suspends future capture, and hides original physical W78 + equipment/decisions W79 until closed. W84 settings and W85 guide are mutually exclusive real source modals; the original UI/physics resumes without being replaced. Desktop hides touch-only guide.

### Actual mission guide
- Phase 0: walk to original core and solve genuine physical valve detents, then E inspection.
- Phase 1: make two actual original incident decisions, with heat/pressure/energy context.
- Phase 2: reach original relay and configure A/B/C, then E.
- Phase 3: original A7 six crisis cycles, live choice counts (no automated best move).
- Phase 4: physically return to source core, correctly connect all three SYNC parts and E.
- Phase 5 / 6: original verified victory / failure; guide cannot fake either.

## Test policy
- 14 native test suites: all previous W63–W84 protected tests plus W85 test based on full authentic original W79 five-stage mobile workflow (12 real A7 decisions, exact original field operations, SHA-checked checkpoint). W85 adds live phase/proximity human help, safe W70 W/A/S/D input release, W84 modal interlock, RU/EN, 320/844 geometry, and zero guide-generated game decisions.
- Original Godot WebGL Chromium: actual native real GUIDE entry/close clicks + original source distance and first phase, no source history mutation, no W78/W79 commands behind modal, 390/320/844 responsive, RU/EN and MENU. It captures 6 actual original game frames.
- Previous W84 (6 frames), W83 (6), W81 (7), W82 (5) all regress on same original W85 compiled WebGL; **30 original source SHA-checked browser frames**.
- Exact Git source integrity protects all original original mission, field equipment, operator physics, W78–W84 controls, checkpoint, scripts, test runners and engine scene except new W85 module and A7CascadeScreen.gd source integration.

**HOLD**: W85 is solely a guide/onboarding stage. A real human 5-phase full walking playthrough on an actual phone, mobile GPU measurements, premium authored AAA art, content scope and IP clearance remain unmet. See [LAST_FRONTIER_TO_WORLD_RELEASE_PLAN.md](LAST_FRONTIER_TO_WORLD_RELEASE_PLAN.md).

## W85.1 — strict 320px Chromium failure diagnostics + Unicode fallback
The first W85 Chromium [run 40789591833](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40789591833) completed **14 native Godot suites including 83 new W85 checks**, real Godot WASM/PCK export and screenshot capture at 390. It then failed a **strict** browser layout assertion after opening the guide on 320×700 (without identifying whether the problem was actual visibility or an out-of-screen child rect). W85.1 adds auditable source `w85_source_guide_open`, all actual Godot control rectangles, inside/outside bounds and a native Chromium screenshot under a separate diagnostic evidence folder on failure, while reducing the wasted timeout from 100 to 45 seconds. It DOES NOT remove or weaken the 320px requirement. Native progress strip now renders source-colored ASCII digits instead of ornamental Unicode circles, which appeared as missing-font boxes in the genuine 390px screenshot; this improves actual game readability, not generated art.
