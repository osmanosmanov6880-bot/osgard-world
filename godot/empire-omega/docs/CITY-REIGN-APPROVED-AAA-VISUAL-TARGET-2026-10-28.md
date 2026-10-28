# CITY REIGN — approved visual target and production gate

Approved 2026-10-28. This is a target, NOT a claim of achieved photorealism.

## Binding art direction
- **The Matrix Awakens**: believable urban scale, materials, street density and daylight.
- **GTA VI**: rich inhabited city, character and traffic animation, authored storytelling.
- **Forza Horizon 5**: vehicle surfacing, reflections, driving feel, tire/road contact.
- No prerendered substitutions: acceptance must use frames captured from the running Godot game.
- References are quality benchmarks, not permission to copy third-party proprietary assets.

## First source-code production increment
- New `city_reign_rooftop_geometry.gd`: deterministic rooftop mechanical housing meshes, batched into a bounded MultiMesh (at most 72).
- Wired into existing `horizon_r90_street_dressing.gd`; follows low/standard/cinematic quality tiers.
- Low turns this detail off; standard/cinematic keep real geometry visible.
- Cosmetic-only; no alterations to missions, driving, saved state or economy.

## Acceptance gates (not yet passed)
1. Run Godot headless import and parser check.
2. Run game under native renderer and WebGL renderer; compare equivalent camera positions with earlier capture.
3. Test low/standard/cinematic: rooftop objects off/on/on.
4. Verify no gameplay regression, stable save/load and bounded instance count.
5. Profile GPU/CPU/frame timing at fixed viewpoints on target devices.
6. Only then mark this increment as accepted.

## Next work packages
1. Reference camera, lighting and material calibration; test building silhouettes and street detail.
2. Licensed PBR architecture, sidewalks and road textures; correct scale/UV/LOD.
3. Production vehicle meshes, physically plausible handling and audio.
4. Pedestrians, traffic, animation, weather and dense world behavior.
5. Cohesive playable 30-minute chapter, device benchmarks and public demo gates.

## Current limitations
The scene is procedural low-poly geometry, not Matrix/GTA/Forza fidelity. No Godot runtime or platform benchmark was executed by this commit. No claim of visual parity or of a shipped AAA product.
