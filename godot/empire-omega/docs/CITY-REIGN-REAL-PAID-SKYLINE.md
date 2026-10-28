# CITY REIGN — B27–B31 physically purchased skyline
Date: 28 October 2026. Target: the REAL original Godot gameplay city, not a concept image.

## Why this block exists
Prior art passes gave four existing city service landmarks original physical skins, but all twelve separately purchased player civic buildings were still uniformly coloured rectangular blocks regardless of what they represented. This pass introduces **12 unique source-authored physical tower sculptures**, each with **four actual purchased levels** and true windows, facade metal, roofline and distinctive infrastructure equipment. No additional plots or phantom purchases.

## Source files
- `scripts/city_reign_investment_skyline.gd` — source-authored Godot ArrayMesh, one real MeshInstance3D per original building, exactly 12 fixed existing project plots from WorldBuilder._project_position; 4 shared original district PBR materials with source vertex colour and physically modelled bronze/steel/glass.
- `scripts/world_builder.gd` — actual playable city integration, real saved 12 building levels synced only after authorised GameState.build(), no save or economic rules modified. LOW hides OPTIONAL geometry but keeps original purchased colliders/visual base, STANDARD/CINEMATIC show source real detail.
- `tests/v121_city_reign_twelve_paid_skyline.gd` — original Godot 4.4.1 tests all 48 real geometric stages, 12 physical lots, true full-city player purchase and cost integrity, 12 cars/34 citizens, zero new colliders, cache identity, mobile LOD and stage reset.
- `tests/city_reign_real_paid_skyline_pixel_fixture.gd` — exported original FULL WorldBuilder (not a static illustration). Press key 2 calls **real treasury-funded** `GameState.build("council")`; keys 3/4 physically disable/re-enable high quality source meshes. Chromium saves genuine scene RGB pixels and checks changes. Original project.godot main scene is untouched in Git.

## Original visual identity by municipal function
| Authoritative purchased property | Visual source-real signature |
|---|---|
| council | basalt limestone colonnade, bronze architrave, public glass entrance |
| clinic | raised emerald medical cross, paired roof rails, real glazing |
| academy | twin roof-side carved turrets, deep bronze education frieze |
| homes | street-facing physical balconies on each newly paid floor |
| gardens | three planted roof planters, balcony garden spillway |
| school | paired education masts and school signage beam |
| market | real projecting brass trading canopy, four retail mullions |
| factory | two 12-segment genuinely cylindrical industrial exhaust stacks |
| depot | original metal loading gantry and physically recessed freight openings |
| plant | two cylindrical turbine generator covers and conductive rails |
| purifier | three physical water treatment tubes with emerald header |
| reservoir | paired physical round reservoir housings and water pipes |

## Original state truth
The ONLY authorized money/upgrade source is `GameState.data["buildings"][id]`, funded by the EXISTING `GameState.build(id)` transaction. Geometry levels 1..4 are physical 14m / 22m / 30m / 38m tower forms, never visual-only artificial level numbers. Level0 renders nothing new. Unbuilt lots remain empty. Resetting a real save removes art. No new economy function, property asset, save schema, NPC route, input map or collider.

## Strict geometry and GPU budget
- At most 12 actual optional facade draw nodes across all active city districts, plus original existing physical collision buildings.
- 4 shared source PBR materials, no commercial stock textures.
- Up to 48 cached deterministic physical mesh variants **lazily**, not created every UI opening. Each bounded under 7,000 native vertices; all geometry stays inside original plot (+ small outward facade cladding margin).
- New art casts no dynamic shadows, owns no collision, lights or animation loop.
- Existing mobile LOW hides all optional 12 3D facades without hiding actual original paid buildings. STANDARD/CINEMATIC reuse the same cached mesh assets; no physics or save delta.
- No claim of AAA licensed/photo-real realism: original source-authored stylized metal/plaster is still a production prototype.

## Genuine acceptance requirements
Source exact-SHA native v108/v113/v119/v120/v121 all PASS; original full-city Chromium and first-party source-paid pixel test must PASS. Independent art-direction review, professional licensed PBR UV/normal maps, high-quality player character, gameplay first 30 minutes, real measured smartphone/desktop FPS and localization still remain HOLD. Release only after full staging and human review, never directly master/R87/SSH.
