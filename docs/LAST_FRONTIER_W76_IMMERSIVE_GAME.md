# LAST FRONTIER W76 — playable immersive mission, not a screenshot

Date: 28 Oct 2026. **Godot 4.4.1 draft software vertical slice.** Accepted ancestor: W74 `73ef81b54cb42831cafd9ac8fa69c5807cd8dc8d`, [three CI jobs PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40650956529).

## Delivered real engine development

1. **Play now / ENTER** starts the original W72 extended physical incident mission (only if it has not already started), enters the actual W70 physics first-person CharacterBody3D and opts into one large 3D viewport. This does not skip the valve/relay/sync puzzles, win automatically, or simulate a mission.
2. **Immersive mode / TAB**, reversible, expands the native Godot 3D viewport, hides four secondary dashboard groups, keeps the real game state in memory, and restores all original buttons when deactivated. Mobile 320/390px and desktop 768/1366px layouts keep the original stage and controls available. This avoids the earlier 30-button default visual overload without deleting any mission or breaking accessibility.
3. New `A7MissionWayfinder.gd`: fifteen actual Godot 3D meshes (13 original bridge-aligned floor markers, a torus goal and pylon), an in-world `Label3D` and a real practical light. The target follows the **actual** five-step mission: CORE before original first two decisions, RELAY after those decisions, CORE for the genuine final return. Distance is measured each frame from the original player CharacterBody3D world position; no fake travel-time estimates or teleports.
4. The real main native UI has a single mission objective line in RU/EN with physics distance and optional navigation, not a random story text. Source-accurate read-only state for browser QA; ECO and reduced-motion are honored.
5. The original Godot W63 six-cycle game math, original W70 physical collision engine, W72 source-gated valve/relay, W73 in-world ray and SHA-checked local save/replay, and W74 controller/3D servo feedback source files remain byte-for-byte unchanged.

## Actual acceptance

The new real Godot `tests/test_w76_immersive_level.gd` tests the original full scene, play-button real mission+physics route, true 3D guide, exact original gameplay state, physical valve alignment + E, two real A7 decisions, the actual mission's goal relocation, TAB restores original panels without discarding journals, compact mobile and desktop views, bilingual, ECO, reduced-motion, and reset. CI compiles all scripts and runs W73, W74 and W76 original native suites, and exports real Godot WASM/PCK bound to exact head SHA.

**Not certified:** Professional human art direction, original character animation, physical PC/mobile GPU FPS, 10-15min first-time player sessions, source-specific intellectual-property rights, legal naming, or retail deployment. Keep as unmerged DRAFT until exact-head CI passes; do not represent this procedural engine as GTA VI / Forza-level art.

**Product next steps:** professional production environment/character assets, cinematography/performance on physical devices and 12 independent playtests recorded with W75 evidence gate. W75 remains a separate source-identical release auditor, not a fake commercial GO.
