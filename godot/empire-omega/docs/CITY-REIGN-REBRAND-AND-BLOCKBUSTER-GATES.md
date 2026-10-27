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
