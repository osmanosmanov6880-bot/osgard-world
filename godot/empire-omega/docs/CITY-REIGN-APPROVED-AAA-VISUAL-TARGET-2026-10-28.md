# CITY REIGN — approved visual target and production gate

Approved 2026-10-28. This is a production target, **NOT** a claim of achieved photorealism.

## Binding art direction

- **The Matrix Awakens:** credible urban scale, dense architecture and physical daylight.
- **GTA VI:** inhabited open-world behavior, character and traffic animation, story.
- **Forza Horizon 5:** production vehicle materials, reflections, driving feel and tire/road contact.
- Only real running Godot geometry and licensed/provenance-safe assets are eligible for acceptance.
- Cinematic screenshots and illustrations cannot substitute for a live playable game.
- References are benchmarks, not permission to copy third-party proprietary content.

## Implementation: true shared-mesh rooftop LOD (PR #627)

The first prototype inserted an extra Node3D into R90, violating existing native tests
that require three R90 root children and two R91 GPU children. That implementation
has been **replaced**, not carried forward.

1. `scripts/city_reign_rooftop_geometry.gd` now extends RefCounted and generates
   source-authored, physically shaded vertices directly into an existing R91 roof mesh.
2. `scripts/horizon_r90_street_dressing.gd` preserves the **original three roots**.
3. `scripts/horizon_r91_skyline_detail.gd` retains exactly the original 72 tower
   instances and original two R91 MultiMesh batches. The rooftop crown MultiMesh
   switches between two real ArrayMesh LODs:
   - **Low:** original rooftop crown batch hidden.
   - **Standard:** original four modelled 3D roof masses (144 vertices / 48 triangles per crown).
   - **Cinematic:** 20 real 3D volumes (720 vertices / 240 triangles per crown).
4. The added shapes are raised perimeter parapets, two mechanical equipment
   housings with four front louvers, tilted panel equipment with metal supports,
   and roof service ducts. Every face has its own physical normal and PBR tint.
5. Both LODs use one GPU draw batch, no additional scene nodes or colliders,
   no RNG calls and no changes to missions, saving, economics or traffic authority.
6. The cinematic roof triangle ceiling is **72 × 240 = 17,280 triangles**
   for the shared crown geometry; this is a geometry budget, **not** measured FPS.
   The standard roof budget is **72 × 48 = 3,456 triangles**.
7. `tests/v122_city_reign_cinematic_rooftop_lod.gd` checks actual vertices,
   normals, per-vertex colors, LOD transitions, legacy scene hierarchy, instance
   counts, unchanged state and material settings.
8. `.github/workflows/city-reign-aaa-rooftop-source-qa.yml` executes actual
   Godot 4.4.1 strict import plus legacy R90/R91/R114/R116 and new native tests.

## Acceptance gates and evidence honesty

- **Source changes:** delivered to isolated draft PR #627.
- **Native Godot import and five regression suites:** GitHub Actions required;
  check exact PR run results before marking this gate passed.
- **Real Chromium/WebGL city comparison:** existing R114 browser QA required.
- **Visual pixel delta:** must use matching in-engine before/after cameras.
- **GPU performance:** no measured desktop or mobile FPS result yet.
- **Gameplay/saves:** native regressions prove only what their assertions actually test.
- **Production release:** forbidden until explicit visual, gameplay, hardware,
  license and human-playtesting gates pass.

## Next production blocks

1. Upgrade **street-level** architecture and materials at the actual first-gameplay
   intersection, with licensed PBR, real road markings, windows, props, LOD.
2. Physically credible daylight/night/rain material response and predictable exposure.
3. Real vehicle mesh/model pipeline, paint, glass, tires, suspension and driving sound.
4. Traffic, pedestrians, richer reactions, density and authored cinematics.
5. Playable 30-minute story slice, repeatable WebGL captures, device profiling
   and independent playtests.

## Limits

No assertion of Matrix/GTA/Forza visual parity, 8K realtime gameplay, or shipped
AAA production. This milestone improves actual procedural rooftop geometry while
keeping strict render budgets and scene compatibility. Asset quality, street density,
lighting, cars, animation, performance and independent end-to-end acceptance remain
far below the approved target.
