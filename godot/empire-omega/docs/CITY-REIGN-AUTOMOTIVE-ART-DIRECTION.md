# CITY REIGN — AAA AUTOMOTIVE ART DIRECTION: V1

Status: Original real Godot 3D vehicle variants implemented for the playable R90 city; still not photoreal AAA.

## Intended visual character
The city's distinct districts should contain believable functional vehicles, not 12 identical soft-shaded proxy sedans. A dense, restrained, highly legible automotive language is more important than adding glossy glow. The color script is slate, graphite, patinated gold, petrol teal and satin silver with believable clear-coat reflections.

## Actual original source implementation
1. **City sedan**: retains exact pre-approved R126 828-vertex original chassis, 648-vertex original cabin and 576-vertex wheel. Existing retrocompatibility and physically proven collision unchanged.
2. **Municipal taxi**: physically sculpted roof identification sign and warm-banded side silhouette, all fused into original 2 MeshInstance3D draws. No neon billboard, no external logos or assets.
3. **Courier service**: three-dimensional raised freight/pod roof, paired rails, rear loading step and recessed tail trim, sharing original wheel meshes, collision and actual road AI.
4. **Executive**: panoramic dark roof center, satin roof perimeter, genuine front grille slats and metal side trim; same authoritative physical collision and traffic.
5. **Police/patrol**: untouched R126 original body and two verified blue/red sirens; not allowed to become taxi or lose road law AI.

Models assigned deterministically 3/3/3/3 to the existing original 12 traffic routes. Cached at most six new shared source ArrayMeshes (3 bodies + 3 cabins). Each vehicle still carries only original two visual car shells, 4 round wheels, 2 headlamps, 2 brake lights, and the same one 2.25 × 1.15 × 4.1-metre CharacterBody3D collider. No fresh traffic agents, crowd clones, physics, saves, new economic currency, environment props or separate material draws.

### Hardware level of detail
- **LOW**: the EXACT original R126 shared sedan body/cabin meshes, cached one each across whole vehicle population. Same basic wheel and original headlight surface. Real mobile FPS must still be measured.
- **STANDARD/CINEMATIC**: chosen family-specific 3D source art. These modes share original single-surface materials; switching never alters route, speed, collision, municipal income or mission state.
- No 2D reference images, UI-only cosmetics, imported unlicensed brand names, fake shadow meshes, per-frame SurfaceTool allocations or asset downloads.

### Verified engineering targets
- Original R126 mesh/physics regression `v99` stays exactly intact.
- New real original Godot `v114_city_reign_aaa_vehicle_fleet.gd` verifies separate cached 3D shapes, 12-agent main-scene distribution, player-city routes, wheel spin compatibility, police exception, original GPU draw nodes, 3 quality tiers and absence of changes to real city mission/treasury/wallet.
- Full original R90 WebGL Chromium, native Godot suite, artifact SHA provenance plus manual-only production gating must pass on exact head.
- **AAA aesthetic and commercialization HOLD**: still requires professional licensed GLB car model authoring, tire suspension/paint environment polish, dedicated turn-signal/soft-light kit, real pedestrian/traffic closeup acceptance, camera matching, physical desktop/phone frame testing, sound and independent art-director signoff.

No new deployment to `master`, production public R87 or SSH. This is an original graphical upgrade, not a completed worldwide blockbuster.
