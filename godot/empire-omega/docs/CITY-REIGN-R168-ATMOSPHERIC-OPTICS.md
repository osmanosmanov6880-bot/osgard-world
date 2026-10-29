# CITY REIGN R168 — ATMOSPHERIC OPTICS / ORIGINAL ENGINEERING

Baseline: **R167** original published Godot 4.4.1 commit `3c0d152521605ccd7bbba82f33a170a1ddc1c36b`.
Game source: `godot/empire-omega`. No screenshot compositing, advertisement images, new 3D car assets, fake SSR or silent production overwrite.

## Three source-engineering blocks

1. **Clock-aware solar orientation.** The original single directional sun now follows a bounded day arc in x AND yaw, with midday above the road and twilight at the horizon. ProceduralSkyMaterial horizon tint responds to actual hour/weather, preserving the existing R44 nightly sun/ambient exposure and sunrise. Existing GL Compatibility sky irradiance supplies PBR response. LOW adds no new fog, shadows, radiance probes or sky draws.
2. **Wet material reflectance on original real asphalt and puddles.** Existing native PBR asphalt/concrete now enable a restrained clearcoat only under genuine rain/storm and when graphics allow it. The actual existing 72-instanced puddles change shared albedo response with sky time and weather, not an image of a reflection. Both revert on dry weather/LOW and never change wheel wet-grip logic, collisions, textures or save state.
3. **Optically coherent player-car lamps.** Original R167 twin shared 108-vertex 3-band LED meshes now change material emission according to actual in-game hour and graphics tier. Exactly the same two R56 spotlights remain the bounded road-light sources. Mobile LOW removes both actual dynamic spotlights without hiding the original visible light meshes; no added draw calls, allocations or GPU lights.

## Acceptance / publishing gates

- v153 true source solar dawn/noon/dusk/night orientation and existing R44 light authority.
- v154 real PBR wet asphalt, idempotent source materials, one existing pooled 72-puddle batch, clear/LOW reset.
- v155 actual player CharacterBody3D car, R167 mesh identity, two headlights and 80 day/night swaps without GPU resource growth.
- Inherit R167 v150–v152, R166 v146–v149, R165 v143–v145, original R44 weather/night, 40-mission save/regression and real game WebGL2 Chromium E/V/W/S checks.
- Exact Godot import, native runs, Chromium source SHA, isolated SSH integrity and public browser are mandatory BEFORE labeling this revision published.
- NO claim of physically measured mobile FPS, true ray-traced reflections or AAA automotive equivalence.

R169 follows: original authored sound and animation / UX controls with license provenance and physical device profiling. R170 follows: cohesive repeatable 5–10 minute gameplay journey.
