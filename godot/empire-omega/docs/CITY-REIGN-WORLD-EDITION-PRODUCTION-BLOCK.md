# CITY REIGN — WORLD EDITION / B41–B48 production ledger

**Date:** 28 October 2026  
**Repository:** `osmanosmanov6880-bot/osgard-world`  
**Candidate branch:** `feat/city-reign-aaa-world-quality-gate-20261028`  
**PR:** #627 (draft; no master/public deployment)  
**Source engine:** Godot 4.4.1, GL Compatibility, real playable source.

## The product — what "world-class" means here

CITY REIGN is a player-driven open city: drive, talk to citizens, invest public
treasury, build physical city projects, and see lasting effects on the world.
The artistic north star is **The Matrix Awakens × GTA VI × Forza Horizon 5**:
urban material and scale, living systems/narrative, and vehicle quality. These
are **quality benchmarks only**. Do not copy proprietary models, maps, brands
or copyrighted visual assets.

An AAA goal is **not** reached by increasing version numbers or adding boxes.
All release claims require a playable build with actual original 3D,
representative footage, stable frame times, source-locked acceptance, and
independent player testing. Screenshots alone never prove gameplay.

## B41 — authored street-level 3D architecture [SOURCE IMPLEMENTED]

**File:** `scripts/city_reign_street_architecture.gd`

- One authored street-frontage instance for each of the **existing original**
  generated buildings, at exactly the original road-facing door orientation.
- Four district palettes and original stone/PBR facade texture reuse.
- Physical 3D stone plinths, corner columns, entrance lintels and roofline
  spandrels, plus real metal brackets, joinery and door handles.
- Two planted box/soil systems per facade, each with native volumetric stems
  and multiple double-sided 3D leaf surfaces.
- Actual luminous metal shopfront bars, powered by the original
  `GameState.data.energy` and the existing city daylight clock.
- No arbitrary "new lots", new destination coordinates, fake shops, physics
  bodies, road collisions, mission payouts or player-account changes.
- Four shared source-native `ArrayMesh + MultiMesh` draw groups across at
  most 128 building facades; no per-shop scene node explosion.

**Important:** This is materially better procedurally authored street detail,
but it is NOT imported photogrammetry, premium scanned assets or GTA-quality
facade art yet. Licensed PBR asset production remains a separate art stage.

## B42 — real quality and power budgets [SOURCE IMPLEMENTED]

| Setting | Physical geometry | Lighting | Allocation policy |
| --- | --- | --- | --- |
| Low | Added street kit hidden | Off | Same source batches remain cached |
| Standard | PBR stone and metal visible | Powered dusk/night fixtures | Foliage hidden |
| Cinematic | Stone, metal, planted foliage | More vivid dusk/night fixtures | No extra dynamic omnidirectional lights |

- Changes happen on the existing `WorldBuilder.apply_visual_budget()` path.
- Dusk, electricity and weather route through real authoritative
  `WorldBuilder._apply_lighting()` and `update_daynight()`.
- Brownouts reduce material emission; an actual blackout makes the real
  3D facade fixtures dark (not a fictitious HUD indicator).
- Same original gameplay simulation and vehicle collision layout, with no
  changes to authority, saving or localization.

## B43 — source-native regression proof [SOURCE IMPLEMENTED]

**Test:** `tests/v123_city_reign_street_world_integrity.gd`

Validates in real Godot:
1. Four representative lots and their original facade orientation/position.
2. Genuine indexed/native 3D triangle surfaces with finite transforms.
3. Shared PBR color/normal/roughness and live vertex shading.
4. Four bounded instanced GPU groups, with no per-object collisions.
5. Low, Standard and Cinematic actual render visibility.
6. Daytime street lights disabled; night street lights enabled.
7. Full municipal power outage and low-power brownout.
8. Original full `WorldBuilder` creates a frontage for every original building.
9. Original R90 skyline remains three roots; R91 windows/crowns two batches.
10. Wet road and quality changes preserve bounded geometry.
11. The original authoritative save/economy/campaign dictionary is unchanged.

**CI:** `.github/workflows/city-reign-world-edition-native-qa.yml`.

Source SHA locked (no synthetic merge checking), strict Godot import, new
B41-B43 tests plus 11 native source tests covering original R90/R91 roof art,
first chapter, real citizen reactions, 12 paid lots, 40-event story/save,
and joined original gameplay. Raw console logs are uploaded as artifacts.
CI must finish GREEN on the exact proposed source SHA before merge.

**Not yet claimed:** no verified production build, physical-phone FPS, 30
minutes of independent human playtime, finished 8K art, or finished trailer.

## B44 — actual browser/WebGL and visual evidence [REQUIRED]

- Use existing source-pinned Chromium/WebGL first-chapter and R90/R114
  capture workflows on the exact same PR commit.
- Preserve PNG attachments from the **real game canvas**, not visual mockups.
- Compare fixed route start, market corner, nighttime, and post-construction
  frame captures at the same camera/graphics settings.
- Inspect sun/ambient, sidewalk materials, window depth, vehicular tire/road
  geometry, newly visible stone/metal storefronts and no UI occlusion.
- Fail release if WebGL shows black screen, lost context, error overlay,
  flicker, invisible new kit or broken first chapter.
- Pixel images do not establish game design quality or a consistent 60 FPS.

## B45 — next full-block 3D environment art [NOT FINISHED]

- Replace generic box-only hero buildings with individually modelled and
  licensed PBR architecture, varied gables, recessed entrances and
  believable window/door scale.
- Build coherent interiors where gameplay actually requires entry.
- Real material provenance manifest: source, creator, license, attribution,
  model scale, LOD levels, mesh/material cost and embedded dependencies.
- Treat original photographed/CC0 road textures as offline pinned assets;
  never hotlink production assets or add unreviewed commercial models.
- Fixed-angle before/after with identical world state, time and camera.

## B46 — next vehicle production [NOT FINISHED]

- High-quality vehicle exterior/interior with actual mesh LODs and
  car paint, glass, rubber, metal and tire surfaces.
- Physical driving and contact behavior validated on original game
  controllers (not a stylized video demonstration).
- Sound events for engine load, gear changes, grip, wet roads and
  collision, all clamped for listener safety.
- Real traffic, pedestrian crossing and camera occlusion regression.

## B47 — 30-minute first-episode release candidate [NOT FINISHED]

- A player starts on a visible street, takes a car, drives to the market,
  learns city requests, funds a civic building with actual saved money,
  waits for two real construction turns and witnesses a finished asset.
- Include authored dialog, optional citizen consequences, a clear route
  objective, sound, failure/recovery, save/reload and onboarding.
- Independent human testers should finish, understand the economic
  consequence and be able to find the next goal without developer help.
- Formalize art reviews against actual route captures at 6 camera angles.

## B48 — platform delivery, not just a running demo [NOT FINISHED]

- Source-controlled native Windows/desktop and Web exports, checksums and
  reproducible build receipts; asset licenses and legal approvals.
- Desktop performance tiers with accurate **measured** 1% low/p95 frame time,
  GPU memory/VRAM and CPU profiling at reproducible city viewpoints.
- Android and iOS physical hardware capture, touch/portrait safe areas and
  heat/battery budgets. No emulator = physical device proof substitution.
- Localized UI and speech/subtitles appropriate for supported languages;
  RU/EN/ZH scene labels and actual controls need complete player reviews.
- Crash recovery, save migrations, rollback/publish controls and
  staged opt-in distribution; master/public not mutated without gates.

## Verified quality bar and stopping rules

| Check | Required result |
| --- | --- |
| Engine import | Actual Godot 4.4.1, no parse errors |
| Native regression | All required suites exit 0 and print 0 failures |
| Runtime browser | No WebGL loss or browser errors, real render frames |
| 3D instancing | 4 new batches, <=128 original buildings |
| Source economy | Purchases/treasury/XP/mission state unchanged by visual-only code |
| LOD and electricity | Player graphics choices and saved city power drive physical world |
| Visual QA | Actual game screenshots at identical viewpoint, honest differences |
| Performance | Profiled target devices and p95/1% low, no invented numbers |
| Legal | Each commercial texture/model/audio file has verified origin and rights |
| Release | Human test, product acceptance and deliberate owner authorization |

### Exact native commands for independent verification

```bash
python3 godot/empire-omega/tools/generate_audio.py
python3 godot/empire-omega/tools/generate_patrol_audio.py
bash scripts/omega-strict-godot-import.sh godot/empire-omega
godot --headless --path godot/empire-omega --script res://tests/v123_city_reign_street_world_integrity.gd
godot --headless --path godot/empire-omega --script res://tests/v122_city_reign_cinematic_rooftop_lod.gd
```

**Marketing restriction:** describe only completed, source-proven milestones.
Do not call CITY REIGN a finished world-class AAA game until that claim has
independent, playable, artistic and hardware evidence. Do not merge a red PR.

---

## B49–B52 — native architectural city-body upgrade (candidate, awaiting exact-head CI)

The first browser screenshots showed excessive repetition: most visible original
`Building_###` bodies were plain rectangular boxes even when their storefront
and roof ornamentation used genuine 3D. To address the most obvious visual
bottleneck, B49 modifies the real source body's geometry *in place*.

**Source:** `scripts/city_reign_tower_body_lod.gd` plus
`scripts/world_builder.gd`. Only the original `VisualMesh.mesh` changes.

- **B49 — source-authored closed building solids:** actual eight-edge
  chamfered high-rise cores (not merely painting a box), real stone plinths
  and top courses with correct outward face normals.
- **B50 — four neighborhood art identities:** district-dependent chamfer
  widths and surface tinting plus restrained facade piers, inter-floor
  shadow lines and physical roof mechanical volumes. Original PBR texture
  families remain shared (no external or uncleared model download).
- **B51 — original resource-quality tiers:** original lightweight `BoxMesh`
  remains resident for LOW; sculpted STANDARD and CINEMATIC `ArrayMesh`
  alternatives swap *inside the same real building MeshInstance3D*, without
  changing any collision body or adding a render node per building.
- **B52 — true source/world verification:** native
  `tests/v124_city_reign_tower_silhouette_lod.gd` checks mathematical
  mesh bounds, finite normals, physical geometry outside the old cuboid,
  all existing original building colliders, original window/material
  bindings, all three LOD settings, wet-road/night changes and immutable
  monetary/campaign state. CI runs the new suite alongside the genuine
  prior mission/road/traffic tests.

**Budgets** (engineering limits, not GPU profiling):
up to 128 original towers; each STANDARD model ≤600 vertices,
each CINEMATIC model ≤2400 vertices; same one mesh renderer per
original colliding building. Low retains original 12-triangle BoxMesh.
The original 52m road grid, real driving collision and source-pinned
40-stage story are unaffected in code.

**Evidence gate:** The source and native regression suite must be
verified on the exact post-commit SHA. A green old head is not proof
of this new candidate. Real screenshots at the same viewpoint must
be inspected before visual benefit can be claimed. This improves
procedural architecture only; it still does **not** reach the geometry,
shading, crowds or photogrammetry quality of the AAA benchmarks.

## Art and product decision after native QA

Do not mistake source triangles for AAA photorealism. The visual
reviewer must still explicitly compare the actual upgraded Godot
frame against the earlier image in:
- overall silhouette diversity, street-level architectural depth,
  believable roofline and windows;
- no z-fighting, window obstruction, geometry pop, sidewalk overlap
  or vehicle collision regressions;
- 720p/1080p desktop and constrained-phone hardware;
- profiling and independent playtests (these remain open release gates).

The project is a **playable city-game candidate**, not a finished
world-class platform. Windows, Linux and WebGL candidate artifacts
may be downloaded from source-locked CI; no production deployment
has been authorized.
