# CITY REIGN R167 — PRECISION SCULPT / ORIGINAL ENGINEERING

**Baseline:** publicly verified R166 `539c9fbe8dcb6fd853946841d56cac67f216924d`, SSH run 40839742690, 37 native Godot suite logs/3593 native assertions, real public WebGL2 PASS.
**Source:** original Godot 4.4.1 GL Compatibility, `godot/empire-omega`. Not a generated reference still or separate promotional mock.

## Large source-real improvements

1. **Longitudinal body/roof silhouette refinement** in `horizon_coupe_sculpt.gd`: source authored cross sections are reconstructed as 3x bounded cubic Hermite subdivisions, with explicit envelope clipping to original panel/roof sections; smooth native normals and generated PBR tangents. Both original MeshInstance3D draw surfaces remain one surface and true original four vehicle garage variants reuse their existing exact 6 cached meshes. No change in collision hull, car size, economy or mission state. A single sculpted body is capped below 3400 vertices per surface.
2. **Precision native PBR bodywork** in `city_reign_precision_bodywork.gd`: a single shared, vertex-colored real 3D surface with center cooling aperture, dark intake mouths, machined vertical ribs, front hood shoulder details and original rear diffuser finish. Native StandardMaterial3D clearcoat, physical directional light, no new shadow casting or per-frame mesh. Hidden on low graphics; standard/cinematic use only ONE extra detail draw. Original real 2 lamp nodes now use a shared cached 108-vertex triple-band sculpted emissive shape, same original light material & lights; no new point lights.
3. **Visual speed/brake aero response** in `horizon_vehicle_art.gd` and original `vehicle_controller.gd`: existing rear spoiler pivots by max 0.22 rad while braking at speed, preserving spring lean, original collisions and gameplay authority. Reduced-motion preference disables animation. Non-sports garage variants keep spoiler hidden.

## Measured acceptance gates
- v150 exact original physical bounded geometry, uniform mesh cache for compact/courier/executive/utility, Godot 4 smooth normals/tangents and memory envelope.
- v151 real vertex-color PBR, two shared one-surface triple-band headlamps, 40 graphics-tier swaps, same original R129 machined splitter, immutable meshes.
- v152 true original physical road, driver W/S, existing spoiler transform, release decay, reduced-motion, 120 animation updates, save/economy isolation.
- Older actual v103 glazing and v114 four car models and visual tests v26, all R166/R165/R164, original campaign and save recoveries, actual private original WebGL2 Chromium with E/V/W/S, source-only immutable SHA.
- SSH release only from exact SHA after 2/2 CI PASS; source archive, server SHA256, real LIVE desktop/mobile-size Chromium, rollback only CITY REIGN. Physical Android/iPhone frames-per-second NOT measured.
- GTA VI/Forza/The Matrix are art direction references, not claims that a browser game now has that full visual complexity.

## Forward production boundary
R168: author calibrated exterior light materials and 3D environment reflections without unsupported GL Compatibility post-processing.
R169: sound/animation/in-car ergonomics, license provenance and realistic device-performance profiling.
R170: cohesive 5-10 minute genuine playable driving + mission vertical slice.
