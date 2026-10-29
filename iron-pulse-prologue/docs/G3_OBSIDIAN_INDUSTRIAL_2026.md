# IRON PULSE WORLD — G3 OBSIDIAN INDUSTRIAL VISUAL ENGINEERING

Release candidate specification • 29 October 2026 • stacked on verified G2 exact commit `31254ede2e90f53f3528b4f020418666e5b06664` • previous CI PASS [#40813465798](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40813465798).

## Product / visual definition

The world is the *fictional* A7 reactor rescue game, built with Godot 4.4.1, a Windows version and an actual browser-playable WebGL export. It is not a multiplayer SaaS or a working connection to infrastructure. The intended visual identity is **OBSIDIAN INDUSTRIAL / BLACK TITANIUM**: grounded large-scale architecture, understated metal, strong readable hierarchy, small amounts of scenario-derived hazard light, and authentic screenshots from the engine. No generated image is to be presented as game footage or as an implemented feature. "AAA" is an independent quality target, not a certification.

## Engineering block 01 — real 3D industrial material language

**New file:** `scripts/IPObsidianArchitecture.gd` (`class_name IPObsidianArchitecture`).

- Original Godot primitive **MeshInstance3D** architectural cassettes mount on the existing outer walls (left service/reactor and permitted right maintenance/evacuation sections), preserving the 22 m open plasma viewing bay on the right. No new physics bodies or colliders and no changes to the original six objective terminals, three rescue stations or two G2 field consoles.
- Distinct original metallic/roughness parameters: black titanium (metalness .83/roughness .34), matte obsidian (.30/.67), brushed steel (.88/.27), warm bronze (.71/.44). Every visual resource exists in the source and is inspected by native tests; no external textures or license-dependent geometry.
- Real **MultiMeshInstance3D** groups batch 130 machine fasteners and 66 traction features. The source-bound browser/native audit exposes actual instance count; this is not an FPS benchmark or a universal GPU draw-call guarantee.
- Three sector-critical signs mount physically in the scene at z = -13.8 / -35.0 / -51.2; actual **Label3D** text changes with RU/EN. Actual warning strips and three Godot lights remain in ECO graphics.

## Engineering block 02 — genuine hazard lighting and accessible quality

- Three real material instances react to `IPCrisisEngine` source `heat`, `oxygen` and scenario `blackout/thermal/breach`. Rising risk shifts color toward danger; no remote analytics, arbitrary score, fake FPS or physical equipment control.
- Reduced-motion setting holds stable light energy without throbbing. HERO shows advanced noninteractive industrial mesh detail. ECO removes only decorative meshes; three localized safety signs, luminous hazard strips and safety lights stay visible.
- `Main.gd` links this module into actual `_ready`, real `_process`, `G`/AUTO graphics profile, restored save quality and native `L` language toggle; source gameplay and original campaign checkpoint remain unchanged.
- The browser exposes **read-only** `g3_obsidian_architecture` audit fields populated directly by Godot, not a JavaScript mock and not a player-command surface.

## Engineering block 03 — international site is faithful to the shipped code

- RU/EN premium portal section documents only authentic Godot materials, two graphics modes and state-responsive safety lighting. Three CSS color swatches are visibly material concepts, **not screenshots**; the portal's real proof image continues to be generated from the compiled Godot browser run.
- 320px/390px touch versions and reduced-motion/reflow remain mandatory; service-worker shell cache version increments while full Godot game assets are still not silently auto-cached offline.

## Mandatory QA / measurable acceptance

1. `tests/test_g3_obsidian_architecture.gd` imports the **real Main.tscn** and validates scene nodes, ≥70 original HERO meshes, 9 critical meshes, 130+66 actual GPU instances, physically placed hazard signs, PBR material identities/roughness, RU/EN switch, source-derived heat/oxygen response, no fake engine modification, reduced-motion steadiness, HERO↔ECO and G2 + V6 save nonregression.
2. Old V1–V18, G1, G2 native regression suites must still pass with exact source HEAD.
3. Actual Chromium WebGL desktop and mobile tests read true Godot PBR architectural geometry positions and three physical safety lights; the tests verify ECO hides HERO while safety survives and verify restored HERO plus English signage. Existing original UI, camera, mission and previous browser tests must all remain mandatory.
4. Exact SHA-bound Windows/WebGL binaries, independent archive SHA manifest and actual Godot Chromium screenshot evidence, RU/EN portal and mobile overflow checks.

**Hard hold:** a CI PASS does **not** certify AAA visuals, production performance, photorealism, physical-device compatibility or intellectual-property rights. Independent art/audio review, real frame-time tests on actual GPUs and phones, complete human 3-act campaign trials, rights/brand/legal checks and publish/rollback approval remain mandatory G3–G9 work. No merge into `master` or production deployment is part of this draft.

## Remaining roadmap after code G3

- **G3 art acceptance:** lock visual screenshot angles and conduct independent review of 3D sightlines, material coherence, hazard legibility, environmental storytelling and original audio mix. Iterate on real gameplay screenshots; commission rights-cleared assets if necessary.
- **G4 physical compatibility:** run actual 30-minute Windows GPUs, Android mobile and iPhone/browser sessions for p50/p95 frame times, app visibility, temperature, controller and touch targets.
- **G5/G6 operational trust:** data corruption tests, release provenance, support/accessibility and professionally reviewed launch languages.
- **G7/G8:** 20 genuinely recruited playtesters with consent and observed full campaign, documented pricing/legal/distribution and reversible production staging; only then conditional release GO.
- **G9:** 90-day operational error and support plan based solely on real incidents and users.
