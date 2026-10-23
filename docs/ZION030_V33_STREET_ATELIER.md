# ZION-030 v33 — Street Atelier: close-up playable-city art

Status: implemented in source on feature branch and subject to GitHub CI + SSH deployment gates. This is authored procedural Three.js geometry, **not** an Unreal or scanned AAA environment.

## What changed in the running game

1. **68 existing center-city facades** get real extruded arch frames with inset cutouts, recessed glass doors, volumetric stone steps, pilasters, cornices, metal-framed windows, pane details and bronze fixtures. Original occupancy/collision remains unchanged.
2. **Eight premium shopfronts** chosen near the central plaza (two per quadrant): lathed stone columns, canopy fronts, planter details, and a single-texture atlas with readable Russian labels such as «ГОРОДСКОЙ САД» and «АТЕЛЬЕ СВЕТА». No network fonts or image resources are fetched. The atlas is omitted in LITE, preserving low-end memory.
3. **EV body made from an indexed BufferGeometry:** longitudinal aerodynamic cross-sections, precomputed normals, native body color and glass/trim details. Four instanced wheel rims per car rotate from actual vehicle translation, without changing speed, steering, battery or collision rules.
4. **Utility clothing** attaches to the existing animated playable avatar (rather than floating world objects).
5. **ULTRA / MOBILE / LITE:** heavy balcony infill, facade carvings and high-cost material atlas appear only in the appropriate tiers. Geometry is shared and batched via InstancedMesh (21 world-geometry batches in the current ULTRA procedural test).

## Verified and remaining

- Unit smoke v33: 68 archways, hundreds of real window details, valid transforms, indexed car geometry with normals, real wheel-animation matrix changes, all three LOD tiers, 8 atlas signs on hardware tiers, climate/quality switches, source-order contract.
- Browser v33: entry/exit and original game preserved; recorded screenshot in rainy/night street scene; mobile and desktop, quality switching.
- All prior v26–v32 gameplay and v31/v32 detailed art tests remain enabled.
- The SSH verifier is syntax checked during QA and requires byte-identical delivery of **13** v33 public game assets after activation.
- No production deployment, no FPS claims and no independent Unreal build may be announced before their actual evidence exists.

## Next design gates (not yet claimed)

- LOD profiling on at least one real mobile GPU and one desktop GPU, including frame-time 95th percentile;
- more non-repeating materials, human-authored PBR texture atlases and sculpted hero props;
- skeleton/ragdoll-ready character animations, true NPC navigation and fully accessible walkable interiors;
- accessible HUD density mode so detailed streets are not hidden by mission panels.

## Optional cinematic HUD
- The in-game header now exposes a **КИНО / HUD** switch, also mapped to **H** on desktop.
- Focus mode removes secondary contract, career and help panels but retains target progress, mini-map, mission/journal access, weather controls and mobile movement/action buttons.
- It is opt-in and user-preference persistent; existing default gameplay and prior tests are unchanged.
- The browser acceptance verifies that focus mode actually reduces overlays and screenshot evidence is taken after transient weather notifications disappear.
