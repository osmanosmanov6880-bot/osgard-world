# CITY REIGN — Brand transition / World-class release gate

**Working international title:** CITY REIGN. **RU subtitle:** «Власть над городом». Proposed tagline: «Не просто живи в городе. Измени его правила».

## Scope of this first real code change
- Godot `project.godot` application window name and description are now CITY REIGN.
- Preserve `godot/empire-omega` project path, `res://` asset paths, `GameState`, mission IDs, `MissionManager`, 40 missions, save format, 34 citizens, physics, input mappings, and original WebGL export and source-locked QA. These are compatibility identifiers, **not user-facing branding**.
- Do not rename public R87 URLs, production master, 7 pinned WASM/PCK binary hashes, or release.json. PR #500 stays DRAFT. The public game is still the prior release.
- HUD, pause menu, strategy cabinet and native 3D operations dashboard now use CITY REIGN user-facing text for RU/EN/ZH in this *unpublished candidate*. Legacy OSGARD v3 import identification, game-save paths and internal identifiers remain unchanged. Browser-export name still requires authentic exported HTML/WASM/PCK inspection and screenshot review. Icons, trailer, gallery, marketing and release branding remain pending.
- Commercial trademark/domain/Steam collision search not completed. The working title is not a registered trademark.

## Actual gap to a world-class blockbuster
| Block | Evidence required | Release status |
| --- | --- | --- |
| Gameplay | 3 independent real 15-20-minute playthroughs; record mission friction, 40 actual mission cases and retention hypothesis | HOLD |
| Visual | Original two user-approved reference files, original independent SHA pins, actual Godot screenshots and human approval; real authored hero assets | HOLD |
| World & characters | Distinctive district identity, meaningful NPC interactions, traffic/physics regression | PARTIAL |
| Hardware | 36 real physical sessions on desktop, Android, iPhone; p95/p99 frame times, thermals, input and crashes | HOLD |
| Product | Story hook, 30-minute vertical slice, audio, accessibility, onboarding, saves and player return loop | PARTIAL |
| Market | Independent playtest demand, Steam wishlist funnel, pricing/competitor verification, marketing trailer | HOLD |
| Release | True live public R87 7/7 HTTPS SHA verified R136; isolated candidate→rollback R137 currently under test; immutable source manifest and production approval | HOLD |

**Do not claim AAA photorealism, 60 FPS, market traction, a production deploy or a released rebrand without real evidence.** Engineering PASS != market/world-class success.

## C1 — concrete original gameplay code (candidate; not a native PASS claim)

- Each started civic initiative now creates a small collision-free procedural worksite at its original project location. Its central structure grows on each authoritative city turn and its sign displays localized progress. Completed projects replace the scaffold with the pre-existing city landmark; reset/load removes obsolete worksites. Only GameState/civic_initiatives changes money, resources, jobs, trust and turn state.
- R90 world integration now passes BOTH `projects_done` and `projects_active` into the 3D renderer after start, turn, load and reset. Existing one-argument landmark calls remain compatible.
- `tests/v106_city_reign_world_consequences.gd` is an actual Godot SceneTree regression suite covering 3-language branding, staged construction, turn progress, real completion effects, reset and unchanged legacy save identifiers. No synthetic screenshot may substitute for running it on Godot 4.4.1.
- Honest acceptance: candidate changes require exact-head native Godot parsing/tests and authentic Chromium WebGL smoke, controlled reference screenshots on real source, plus future physical device and independent human trials. No merge to master, public R87 replacement or production SSH deploy from this candidate.

## C2 - grounded player decisions and a coherent first-story framing
- Native cabinet now projects each available/in-progress initiative's *completed* effects using a clone of the current authoritative state with the **same turn, weather and economic model**. Values shown: estimated jobs, budget/turn change, project district score and trust. They explicitly say "forecast at current conditions"; changes over future turns can differ.
- Pure `city_reign_impact.gd` never writes to the original state or creates new currencies/save keys. It includes the real trust reward capped at 100, plus source-defined completed-project modifiers. Main game rules still belong exclusively to `GameState`.
- The existing 40 authored missions remain intact. `city_reign_story.gd` adds three native narrative acts and a free-play epilogue to the real journal and cabinet. It reports the authoritative stability, treasury and weakest district, including an active-crisis marker. Reading the journal never mints rewards.
- Native regression `tests/v107_city_reign_impact_story.gd` checks exact economic deltas, immutable state and RU/EN/ZH live labels. All claims are pending a successful exact-head engine/Chromium run.

## C3 - eight DISTINCT visible capital projects (native candidate)
- Previously eight completed investments all produced the same generic glowing obelisk and sphere. These have been replaced with real source-authored, function-specific **collision-free 3D** silhouettes: public budget archive, hospital with medical signage, safe crossing stripes/signals, trees and fountain park, filtered factory, dock with freight crane, water-treatment tanks and power substation.
- The existing project IDs, positions, prices, real economy, construction progress and persistence stay intact. Visible geometry is deterministic, under eight permanently spawned sites, and only created from `GameState.projects_done`. No external copyrighted assets, fake mission events or simulated screenshot backdrops.
- `tests/v108_city_reign_unique_landmarks.gd` verifies each of eight source-specific landmarks exists and no collision geometry is introduced, labels in three languages are consistent, reset and load remove visual state correctly. Geometry remains *stylized* and is not sold as 8K photorealism. Full AAA requires authored assets, licensed materials, animation, physical GPUs and human art-direction review.

## C5 - pre-decision policy comparison + real public emergency response
- The original four-course `GameState.set_course` transaction and its campaign mission still control policy. `city_reign_impact.gd` now presents same-turn, side-effect-free differences for the three alternative courses: projected next-turn budget, energy, trust and stability. RU/EN/ZH and explicit forecast condition wording; no dummy economy values.
- The five actual `GameState.incident` identifiers now drive an original non-colliding 3D emergency beacon at a related city location. Crisis/turn/save/load/language updates recreate or remove it; resolving the incident removes the scene. No duplicate crisis currency, mission shortcut or physics obstacle.
- Source-truth Godot suite `v109_city_reign_policies_crises.gd` compares each forecast to the existing authoritative economy, checks save immutability, all five visible emergencies and bilingual signs. **All tests are pending exact-head CI, not claimed PASS.**

## Episode 01 - First Promise: playable user choice (staging candidate)
- Stage is derived from the real existing 40-mission index (early driving/delivery -> first business -> local governance), then the authoritative current project IDs `open_records` or `safe_crossings`. No parallel chapter save, new achievements, or XP bypass.
- Each city commitment invokes the **same original** `hud._do_initiative` callback and `GameState.start_initiative` transaction; money, materials and action points are charged once. After the original second city turn, the authentic site becomes an existing unique final landmark, and in-game briefing shows live project effects. Both choices remain possible later.
- Two real, non-colliding authored 3D district proposal boards are visible before construction. The UI localizes RU/EN/ZH and shows real source costs. Loading/reset restores the same state with no fake markers.
- Contract test `scripts/omega-direct-publish.contract.test.mjs` modernized from pre-R138 auto-SSH assertions to strict **manual-only** production, exact SHA, independent ticket and all four approval controls, without changing an actual deployment workflow. R90 inherited one failing obsolete contract; the new test verifies the stronger present-day release gate.
- No claim of actual 30-minute player retention or photoreal AAA; mandatory real native `v110`, WebGL smoke, new exact merged SHA plus independent physical playtesting remain gates.

- [E01 addendum] Original in-world proposal boards are now genuine walk-up F interactions: they open the live governance UI, select the physical district, and perform NO silent cost/XP transaction. Only explicit investment buttons can spend. Full-world SceneTree regression `v111_city_reign_street_interaction.gd` tests real scene/player/3D signs/street accessibility, two sites, unchanged original 34 pedestrians and 12 traffic cars.

- [E01 citizens] Real residents' native `J` dialogue now varies with actual saved construction/completion of Open Budget or Safe Crossings; other districts mention actual low district quality or general concerns, and live crises add concern. `city_reign_resident_reactions.gd` is pure narrative commentary (no automated trust/stat change); `v112_city_reign_resident_reactions.gd` verifies displayed real popups, 4 districts, 3 languages, states and save immutability.

## A1-A3 — REAL 3D cinematic metropolis (source candidate)
- Deterministic 4-batch per-original-building architectural 3D cornice/header/vertical facade detail, no new building/physics lot; 4 sculpted location-specific installation meshes and 12 instanced wayfinding accents.
- Existing original shared 128px plaster/ashlar/brick PBR triplanar materials now applied to original physical building bodies (not simply imported unused). High-tier normals only; GL Compatibility mobile budget remains bounded.
- Real electricity + hour drives night accent emission; reset, routes, money, camera and original 40 missions are not touched. Three localized plaza label languages.
- New native `v113` and workflow `city-reign-cinematic-art-qa.yml`: pending exact SHA engine verification; **no photoreal AAA claim and no production GO**.
