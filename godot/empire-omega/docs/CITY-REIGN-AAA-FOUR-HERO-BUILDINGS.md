# CITY REIGN A23–A25 — ORIGINAL hero architecture; actual civic decisions change buildings

## Engineering/visual intent
The original four key city landmarks were all near-bare 25×16m or 25×24m blocks with generic spires. Their authoritative physical building colliders and original city coordinates are **not changed**. A23 adds a separate original PBR-shaded source-native architectural silhouette to EACH building (not 2D concept art, remote model downloads, vendor imagery or new buildings).

### Four bespoke real Godot meshes
1. **Sovereign Hall, Forum, (-130, -130):** eight real stone colonnade piers, sandstone bases and brass capitals, nested public-entry glazing, crown-lintel relief and physically continuous roof edge.
2. **Market Exchange, Housing, (130, -130):** two projecting glass and brass canopy decks, seven vertical market mullions, inset original glass bays and an elevated trading roofline.
3. **Meridian Freight, Lower City, (-130, 130):** a real steel truss/gantry silhouette, five recessed freight windows, metal bracing and a rooftop loading gantry.
4. **Aether Grid, Aqueduct, (130, 130):** nine original heat-exchanger facade fins, metallic power rails, a real inset glass vertical core and two offset rooftop transformer crowns.

Each full facade is ONE bounded `ArrayMesh` with custom vertex colors, per-site physically based metal/roughness and zero extra physics bodies. Each building has ONE extra handmade physical roof-upgrade `ArrayMesh`, initially invisible. Exactly **8 maximum original additional drawable nodes** across the complete city. No new particle/animated camera/OmniLight3D or shadow pass. All source meshes are under 4,000 vertices each, and original roadbed/quest/house/physics coordinates remain unchanged.

## Actual authority, no synthetic economy
`CityReignPhysicalHeroBuildings.sync_state(state)` ONLY reads existing `GameState.BUILDINGS`, its 12 already purchased `state["buildings"]` levels, and `civic_initiatives.gd` eight actual `state["projects_done"]` records. A four-facade district improvement appears physically ONLY if a player purchased an actual building or completed a genuine paid civic initiative in the same district. Current stage has NO new save format, finance state, rewards, missions or currencies.

At actual 22:00, ONLY physically earned upper-front material bars emit source-colored soft light, modulated by the **same real saved energy** used by other city infrastructure. During midday the material is unlit, energy=0 fully removes glow. `GameState.build("council")` remains the ONLY authoritative money transaction. Source real `WorldBuilder.update_development()` updates the geometry from the already paid record.

## Real graphics budgets
- LOW: all eight optional 3D draw nodes hidden; original four physical landmarks/colliders fully playable.
- STANDARD: four physical hero city facades visible; source-earned crowns visible.
- CINEMATIC: same eight source draw nodes and higher pre-existing environment grading, without hidden new shadow/framerate budget.
- Every facade has exactly one `MeshInstance3D` plus one crown, no collision shape.
- No sprites, conceptual screenshots or imported branded architectural reference.

## Automated proof and honest remaining gaps
`tests/v120_city_reign_aaa_hero_architecture.gd` tests all 4 generated source-solid shapes, one authored 3D mesh per hero, 180-vertex earned upgrade, site coordinates and unique silhouettes, power outages, LOD, source-earned civic projects, reversible reset, original collision shapes and **real paid GameState.build council** in the ACTUAL fully playable city with 12 traffic vehicles / 34 pedestrians. It verifies the art cannot create credits or advance missions.

Separate exact-SHA Godot import, real WebGL Chromium and human visual review are still required before staging integration. This is an original low-to-medium-poly cinematic art pass, NOT licensed AAA photorealism. Real-world buyer-approved textured hero architecture, high-resolution PBR/UVs, true animations, actual measured desktop+phone performance, 30-minute independent playtests and visual-art direction approval are NOT done.

**Release:** unpublished R90 ONLY. No master, public R87, live SSH or paid store publish.

## A26 actual original street-captured WebGL pixel proof
Test-only `city_reign_real_hero_building_pixel_fixture.gd/.tscn` instantiates the **original full `WorldBuilder`**, with original 25m City Hall physical 3D landmark and actual source-authored hero facade. Camera sits on the original south street, not in a recreated art studio. Chromium exports the same Godot WASM and tests raw RGB pixels before and AFTER the REAL original `GameState.build("council")` budget-paid construction action. It then toggles LOW graphics and requires the original source-drawn architectural detail actually disappear. No fake SVG/HTML screenshot, unearned reward or production entrypoint change.

Live commercial acceptance is still gated on independent art review, production assets and physical target-device frame measurements.
