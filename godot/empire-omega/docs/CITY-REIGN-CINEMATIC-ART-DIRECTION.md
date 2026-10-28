# CITY REIGN — CINEMATIC METROPOLIS: AAA art-direction production contract

**Status**: ORIGINAL procedural 3D art candidate for R90 staging. NOT photoreal AAA, not commercially released, never a substitute for original licensed hero models.

## Visual north star
- **Architecture**: metropolitan graphite-metal / limestone / satin glass, legible ground-floor frontage, varied roof edges. Urban forms must remain physically legible from pedestrian and third-person chase-camera height, not merely from a top-down atlas.
- **Materials**: 3 shared original 128px triplanar plaster, ashlar limestone and brick families on all existing original buildings; metal cornices and glazed ground-level details use bounded StandardMaterial3D PBR. Normal maps **cinematic** only; low mode turns them off.
- **Night identity**: warm champagne utility light against cool slate masonry; no fake bloom/overexposure. Affects ONLY existing real geometry. Accent power goes to ZERO at actual city energy=0; daytime is not secretly night.
- **Street grammar**: 10m roads, existing door/window footprints, 34 pedestrians and 12 traffic agents are contractual. No backdrop image, URL/web photo, extra colliders or changed mission locations.
- **Four geographic signatures**: civic law arch (Forum), covered exchange canopy (Market), freight gantry (Depot), twin transformer sculpture (Power). Original solid one-mesh-per-site colored geometry, placed off actual roads and building collision; localized RU/EN/ZH Label3D, a single accent MultiMesh.
- **Government UI**: retain approved black/brass editorial R90 command center and its genuine SubViewport of the same active 3D city. Do not fake a rendered city screenshot inside the UI.
- **Graphic modes**: low hides A1 and A2 details + their emission, standard keeps simple roofline/entry and squares, cinematic adds facade mullions/roof plant/true masonry normals/night accent. Preserve mobile adaptive-quality governor.

## Exact engineering limits
| Asset system | Maximum | Verification |
|---|---:|---|
| Existing playable building lots | 128 | One new A1 `record` per original physical wall |
| GPU A1 MultiMesh draw batches | 4 | Roof, entrance, mullions, rooftop equipment |
| GPU A1 instances | 1024 | 4 roof + 1 entrance + 2 reveals + at most 1 rooftop plant per real building |
| A2 independent original sculpted landmarks | 4 | One ArrayMesh body + Label3D each, no CollisionShape3D |
| A2 shared accent MultiMesh instances | 12 | Three per plaza, zero real-time OmniLight shadows |
| Shared masonry material families | 3 | Reuse all albedo/normal/roughness 128px images (from existing original `FACADE_PACK`) |
| Extra cinematic visual physics bodies | 0 | Existing roads and original world bodies unchanged |
| Extra saves, missions, game credits | 0 | All art follows existing GameState data; no new authoritative systems |

## Source anatomy
- `scripts/city_reign_cinematic_facades.gd` — A1 architecture, four GPU instancing batches
- `scripts/city_reign_signature_squares.gd` — A2 four distinct physical city installations and real power-driven accent
- `scripts/world_builder.gd` — A3 shared original PBR wall materials and integration with original gameplay world/quality/weather
- `tests/v113_city_reign_cinematic_architecture.gd` — exact source native geometry, material budget, live world, mobile and visual-state assertions
- `.github/workflows/city-reign-cinematic-art-qa.yml` — exact SHA real Godot compiler/tests; manual-only production contract

## Remaining AAA art gates (NOT MET)
1. Commission/author 4–8 hero buildings and 12–20 physically believable cars with verified original or licensed GLB, proper LOD/colliders and materials.
2. Character direction: facial rig, pedestrian variety, detailed animation, at least one directed narrative scene; meaningful citizen acting, not just UI text.
3. Real lighting reference on 3 calibrated monitor/display profiles; independently compare original screenshot to approved user references and measure color/exposure.
4. Measure a **20s real frame benchmark** on target desktop GPU plus two real Android phones and iPhone Safari; define P50/P95 frame times. Automated Chromium screenshot is NOT a phone benchmark.
5. Independent three-player Episode 01 30-minute playtest and UX notes; no claim of 30-minute enjoyment absent evidence.
6. Human art director sign-off, commercial asset/license audit, accessibility, compatibility and separately approved production release/rollback.

**Production gate**: HOLD. `master`, live R87, SSH secrets and commercial game are NOT altered.
