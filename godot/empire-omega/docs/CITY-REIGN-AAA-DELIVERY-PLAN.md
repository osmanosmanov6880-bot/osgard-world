# CITY REIGN - AAA/Blockbuster delivery map (source-truth roadmap)

**Candidate branch** `feat/city-reign-brand-transition-20261027` -> **staging** R90 PR #500 only. Not production. **Last authored checkpoint** 27 Oct 2026. A finished game cannot be inferred from the count of commits, authored GDScript, automation PASS, or screenshots.

## Product north star
A player gains influence through street-level action, and their money/policies visibly improve or harm district life. The differentiator is **one shared authoritative simulation** serving travel, missions, economy, infrastructure and city feedback. Priority: a compelling, independently playtested **30-minute vertical slice** before scale.

## Gate A - operational safety and source of truth
- [x] Native Godot is authoritative, existing 40 sequential mission identities and version-4 saves are preserved.
- [x] UI/C2 code reads one state; citizen/project actions are not fabricated as rendered effects.
- [ ] Independent source SHA and private reference images must be pinned and externally reviewed.
- [ ] Production auto-release lock from R139 PR #573 must be separately merged/verified on master; R90 and this PR remain isolated.
- **EXIT:** exact-SHA native+WebGL provenance success, no production mutation, explicit human approvals.

## Gate B - playable narrative and first 30 minutes
- [x] Three introductory narrative acts + epilogue reflect current campaign index, risk and weakest district. *Text framing, not full scripted cutscenes.*
- [x] 40 original career tasks and chapter rewards remain tied to real action transactions.
- [ ] Re-author an exciting **continuous, optional 30-minute opening**: arrive, meet resident with voice, accept clear delivery, face district trade-off, see persistent street consequence, close a dramatic beat.
- [ ] Record >= 3 uninstructed 15-30 min human sessions; measure failed actions, time to task success, voluntary continuation and perceived agency.
- **EXIT:** three people play without developer directions, can accurately explain why outcomes changed.

## Gate C - systemic city decisions
- [x] Original 8 paid, resource-limited, multi-turn projects with saved progress and economic modifiers.
- [x] C1 construction sites grow from actual remaining turns, completed landmarks replace worksites, reset clears them.
- [x] C2 **read-only** same-turn counterfactual impact forecasts; cost/benefit based on production state, not fake stats.
- [x] C5 side-effect-free comparative previews for the four existing governance policies.
- [x] C5 city emergencies visible in the actual street from live saved crisis ID; cleared after resolution.
- [ ] Add two irreversible-but-fair district trade-offs with citizen feedback, public services and policy opposition, preserving predictable counterfactual forecasts.
- [ ] Test long saves, softlock recovery and crisis fairness across 30 simulated turns.
- **EXIT:** players can predict and observe at least three distinct short/long-term city effects without reading a spreadsheet.

## Gate D - recognizable visual urban world
- [x] C3 eight source-authored landmark identities that differ by functional facility; low-poly prototypes only.
- [ ] Commission/license high-quality original PBR hero architecture, vehicles, people, texture LODs, signage and terrain; track asset licenses and build provenance.
- [ ] Native art pass for all four districts: streetfronts, materials, reflections, atmosphere, filmed comparison against the **actual** two user-approved original references.
- [ ] Performance LOD/occlusion/streaming profiles; mobile must retain gameplay legibility, not fake AAA rendered imagery.
- **EXIT:** real reference-to-runtime sign-off; clean rights chain; four districts recognizable blind.

## Gate E - traffic, people and interaction
- [x] Existing driving/traffic/resident systems are executable with testable signals.
- [ ] Distinct NPC schedules and reactions, dialogue choices, cinematic encounters, better animations, robust car/camera physics and audio.
- [ ] Automated scenario suite for traffic/pedestrian non-blocking, service completion, regressions in all mission gates.
- **EXIT:** 20 minutes driving/walking with zero critical camera, physics or interaction deadlocks.

## Gate F - sound, cinematic direction and accessibility
- [x] Deterministic existing game audio and browser/mobile control support.
- [ ] Original licensed score, directional ambience, voice, dialogue and reaction SFX; real opening cinematic with player skip.
- [ ] Controller remaps, readable mobile touch targets, captions/contrast, reduced-motion options, accessible tutorials.
- **EXIT:** audio/visual/caption approval and verified keyboard + controller + portrait touch onboarding.

## Gate G - independent quality and device proof
- [x] Source-bound GitHub CI can run real Godot and Chromium/WebGL plus source provenance.
- [ ] 36 original physical trials: desktop / Android / iPhone x four common play scenarios x three independent runs.
- [ ] Collect actual GPU p50/p95/p99 frame time, heat, input latency, asset-load time, crash logs and memory. **Never invent FPS.**
- [ ] Check corrupted-save recovery, mobile WebGL browsers, background-tab behavior, 30-turn simulation parity.
- **EXIT:** individually reviewable authentic physical recordings, stable frame budgets defined per target device.

## Gate H - audience, business and shipping
- [ ] Verify **CITY REIGN** trademark/market collision, worldwide localization, commercial licenses, age rating and storefront rules.
- [ ] Build 60-90 second authentic captured trailer from genuine engine footage, Steam page and wishlist funnel.
- [ ] Closed demo with measurable real retention/interest, human qualitative feedback; paid release only when product and market gates justify it.
- [ ] Independent LIVE verified production rollback rehearsal, signed artifact hashes, explicit four-part GO and release owner.
- **EXIT:** audited go/no-go; source-locked release, rollback path, valid marketing claims, customers able to purchase/support.

## Current no-bluff status
ENGINEERING STAGING. Previous C1 exact-head GitHub native+Chromium/provenance checks passed. Subsequent C2/C3 must pass their own new exact-SHA runs; no manual source review, real GPU target-device proof or independent player validation yet. AAA art, commercial release and blockbuster performance remain **HOLD**. Only real evidence changes the status.

## Gate B1 - actual first-player promise loop (new Episode 01 candidate)
- [x] A true **optional civic priority selection**: CITY REIGN starts with existing enter-car, market delivery, first-business and city-turn missions, then prompts the player to compare **Open Budget (Forum)** vs **Safe Crossings (Residential)** as a first civic promise; neither choice rewrites the existing 40 career missions.
- [x] Both actions spend the exact established city treasury/materials/goods/action through `GameState.start_initiative`; neither can be claimed without paying, building, and advancing two real turns.
- [x] Original 3D proposal boards in each real district are present before investment, disappear when the real construction scaffold starts and stay gone after completion. Three-language street labels, no collision/traffic interference.
- [x] Journal and real interactive command center derive onboarding stage, real resource availability, construction remaining and fulfilled-project job effect **only from existing saved state**; no new save keys or fabricated side quests. Both investments remain available; the episode celebrates the first delivered promise.
- [x] Source-authoritative automated test `v110_city_reign_first_mandate.gd` with real clickable buttons, 3D geometry, finances, saved restore and alternate district; must actually PASS Godot 4.4.1 on exact candidate SHA.
- [ ] Independent human **30-minute game session**. This code creates a coherent path but no claim of player enjoyment or 30-minute playtime until measured.
- [ ] Story cinematics, dialogue choice that changes how residents respond, unique licensed assets and original voice acting are still not implemented.

- [x] E01 on-foot street interaction: near either board, the real F action opens the existing paid decision interface and preselects the correct district without spending money. The separate click on an investment button performs the sole resource transaction. `v111` verifies it in the full real city scene with 34 citizens and 12 traffic cars.

- [x] E01 resident reaction dialogue: when the player approaches and speaks to any actual resident, the native dialogue now references the district's real current investment state (not started / building / completed). Completed Open Budget and Safe Crossings change residents' lines in three languages without changing rewards, council scores or the existing 40 mission stages. Tests `v112` cover all 4 districts, 3 languages, both projects and actual dialogue popups.

## A1-A3 — Cinematic Metropolis original native art pass
- [x] Per-original-building roof cornices, entrance fascia, 3D facade corner reveals and limited physical rooftop plants, **4 actual GPU batches**.
- [x] Four distinct original solid 3D civic-square installations (Forum law portal, Market exchange, freight gantry, energy commons) at road-clear sites; 12 original GPU instanced wayfinding details.
- [x] Three existing source-generated masonry PBR materials now actually cover all original colliding building walls, sharing only three cached 128px texture families; normals follow the cinematic quality tier and drop off on low phones.
- [x] Real day/night power-controlled emission, independently visible RU/EN/ZH 3D site labels; original buildings, traffic, save schema unchanged.
- [ ] Exact SHA native `v113_city_reign_cinematic_architecture.gd` and all E01 tests to execute in Godot. **Pending until CI PASS**.
- [ ] True licensed/commissioned high-poly hero assets, target-device profiling and independent aesthetic art signoff.
- Full design contract: `docs/CITY-REIGN-CINEMATIC-ART-DIRECTION.md`.

## AAA A5 — Real-world traffic identity
- [x] The existing 12 original traffic agents now have a deterministic 3/3/3/3 visual distribution: sedan, taxi, courier and executive. Original 40 mission identifiers, driving routes and physical city colliders remain authoritative.
- [x] All three new classes have genuinely different original closed 3D body/cabin silhouettes, no screenshots. Extra body details are fused into the SAME original 2 per-car meshes; wheels, lamps and brakes unchanged. Patrol mesh remains original R126.
- [x] New real render-quality gate: LOW returns to the precise R126 mesh allocations, standard/cinematic use a tiny shared cache of at most 6 new model-specific meshes; no per-frame geometry allocations or vehicle/game-state mutations.
- [ ] New native exact-SHA `v114` must pass in original Godot and staged WebGL Chromium; NO engineering GO until confirmed.
- [ ] Commission and license high-poly hero vehicles and record actual real-hardware FPS; current shapes are original stylized 3D art, not AAA photoreal approval.
- Complete source and acceptance contract: `docs/CITY-REIGN-AUTOMOTIVE-ART-DIRECTION.md`.

## AAA A7 — source-real playable player car silhouettes
- [x] All four original owned vehicle models (compact, courier, executive, utility) have distinct real 3D closed profile shapes and corrected glass rest transforms, not just car color.
- [x] The original compact always keeps its exact original FlowBody and AerodynamicGreenhouse meshes and all existing wheel/brake/vehicle physics. Three other families share at most 6 new cached original Mesh resources.
- [x] Native garage action `VehicleController.apply_variant` now also updates existing exact body/canopy 3D; original vehicle catalog prices, speed, fuel and save schema unchanged.
- [ ] Original full-world `v115` and authentic v26/v21/v22/v113 Godot acceptance on exact branch head REQUIRED. No photoreal AAA acceptance.
- [ ] Final hero GLB meshes, true skinning and PBR consistency, hardware GPU benchmark and independent aesthetic/driver testing.
- Architecture and source-art contract: `docs/CITY-REIGN-HERO-GARAGE-AAA-DESIGN.md`.

## A9 — Premium interactive garage (real Godot UI)
- [x] Four source-bound original Godot PanelContainer vehicle cards, R90 charcoal/brass visual hierarchy, mobile 1-column / desktop 2-column, direct visible 46px actions and RU/EN/ZH.
- [x] Actual speed/acceleration/handling source multipliers and catalog costs/condition; no fake stats or economy change.
- [x] Same live `_do_vehicle` -> GameState.buy/select_vehicle callback; original missions, saves and finances remain authoritative.
- [ ] Exact-source original Godot `v116` plus v113/v115 and full Chrome/WebGL acceptance required before staging merge.
- [ ] Physical phone screenshot inspection, art review and measured accessibility/contrast.
- Full UI art contract: `docs/CITY-REIGN-AAA-GARAGE-UI.md`.

## AAA A11 — actually interactive native 3D automotive showroom
- [x] Actual source car art (original real HORIZON car with A7 body/greenhouse variants) shown within a single demand-rendered 3D Godot offscreen camera, no image generation or copyrighted car designs.
- [x] Desktop original stage with two unshadowed key/fill studio lights, satin basalt turntable, vehicle-color styling, interactive 15-degree rotation and genuinely inspectable unowned cars (preview does NOT buy).
- [x] Phone never allocates preview until explicit user inspection; LOW graphics forbids new GPU viewport; offscreen budget bounded to 620x282 desktop / 340x184 mobile and single `UPDATE_ONCE`.
- [ ] Exact native original Godot v117, existing economy/physics regressions, actual WebGL Chromium and human art test must pass. Source acceptance isn't photoreal AAA quality approval.
- Design and provenance: `docs/CITY-REIGN-AAA-REAL-3D-SHOWROOM.md`.

### A11 pixel reality gate
- [x] Add separately exported TEST-ONLY source-original Godot WebGL fixture and pinned real Chromium pixel assertions for body switch and 15° render rotation. Never change the production entrypoint in Git.
- [ ] Actual software GPU real screenshot artifacts, pixel deltas and browser error-free evidence must pass on exact PR head before human review. No fake AAA art claims.
