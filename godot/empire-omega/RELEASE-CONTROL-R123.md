# EMPIRE Ω R123 — REAL Street Citizens, engineering acceptance and release hold

**State:** new feature branch with original Godot 4.4.1 implementation. This document is the source/QA contract, **not** a claim that tests or user art sign-off have passed.

## Changes actually made

- The original `pedestrian_agent.gd` **retains** its id, routine, local/global position, route, 2.15m/s walk, predictive `horizon_pedestrian_yield.gd` stop/resume rules, four-second schedule refresh, walking velocity for nearby traffic, and visibility/culling.
- The original `CapsuleMesh` rendered per citizen is replaced by ONE `MeshInstance3D` with physically modeled, actual source `ArrayMesh` surfaces (feet/shoes, independent legs, torso/tapered coat, arms/hands, neck, low-poly physical head, hair/eyes and real material colors). One standard, non-emissive, rough PBR finish shares the vertex-colored material; not a sprite, billboard, photo, or AI-generated still image.
- Four clothing/skin palettes and four explicitly displaced leg/arm walking poses are cached **globally** in sixteen source meshes. A walking citizen switches existing shared mesh references by its actual route-driven time; no per-frame vertex allocation, no per-person mesh construction after warmup. On stop/yield, it restores the idle pose. A small conventional head/body sway remains in the one original visual node.
- No collision body or new physics geometry is created. Original traffic clearance radius, mission routes, economy, 34-citizen goal and saved game remain independent of this art. Dynamic shadows remain disabled on original low-cost pedestrians.

## Original strict Godot QA — mandatory

1. Exact original 4.4.1 source import, fatal on parser error. New `v97_r123_real_pedestrian_body_gait.gd` checks actual source triangle counts, face normals, five clothing/material colors, human-scale bounding box, genuine geometry change on animated steps, PBR material, caching **4 x 4**, one visual node for each of twelve real instantiated NPC agents, original NPC crossing behavior and mission/save invariants.
2. Original `v24_horizon_character_and_hall.gd` must prove the actual **player** remains the genuine independently animated human. `v63_r41_predictive_pedestrian_yield.gd` and `v68_r47_predictive_crosswalk_traffic.gd` must prove real live pedestrians still yield correctly to approaching/parallel cars and traffic detects future crosswalk hazards. The original R26/R44 192-tree camera frame, R114/R116/R119 skyline, R120 branches and true mission tests also remain in the full test suite.
3. The original exact-source GitHub gate `scripts/omega-r109-release-sentinel.py` must SHA-review both altered code files and all **30 original native suite files**. The original `.github/workflows/omega-r109-final-candidate-evidence.yml` checks out the immutable PR HEAD SHA, runs Godot, authentic HTML5/WASM/PCK export and **four real Chromium** desktop/390px mobile/F9 city focus/host-rAF scenarios; artifact source manifest and binary SHA must refer to that very SHA.
4. The R123 targeted workflow `.github/workflows/omega-r123-real-walking-citizens-qa.yml` independently recompiles the engine, executes R41/R47/new native pedestrian checks and exports/photographs real playable Godot city in Chromium.

**Fail closed:** Do not merge R123 until exact HEAD original native + 4/4 actual Chromium + original provenance SUCCESS and screenshots have been inspected. After merging into unpublished R90, repeat *all gates* on the merged R90 SHA. Never mistake synthetic PR preview or a previously successful unrelated source SHA for real combined-head evidence.

## Production safety and art honesty

Public `master` R87 `public/games/omega-3d-preview/release.json` source SHA and original `index.wasm`/`index.pck` rollback hashes must remain unchanged. Merge to `master` would trigger the actual Godot export and direct deployment pipeline. **No production release or SSH publishing** until the user-approved art reference itself is compared against actual Godot gameplay render, hardware-device frame rate independently measured, keyboard/touch usability verified and a safe rollback is recorded.

This feature improves silhouette and gait in the actual playing city; it is **procedural low-poly character art, not AAA-photoreal scanned actors**. Source-level game behavior proof does not constitute artistic approval.
