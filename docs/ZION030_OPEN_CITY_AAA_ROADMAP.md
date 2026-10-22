# ZION-030 — OPEN CITY / ROADMAP TO AN AAA-QUALITY GAME

**Product:** A third-person urban adventure about rebuilding climate-resilient Athens. It is an original title, not a GTA clone. The ambition is GTA-like freedom, exploration and living-world systems, not criminal violence.

## Product pillars

1. **Freedom:** walking, sprinting, driving a municipal EV, meaningful districts, navigation and seamless mode switching.
2. **Living city:** believable streets, day/night and weather, ambient pedestrians, moving cars, route planning, interactive landmarks.
3. **Progress:** original cooling mission remains valid; extra municipal contracts award credits and reputation, unlocking vehicle upgrades.
4. **Visual quality:** strong architectural art direction, readable scale, calibrated lighting and material response, grounded props, motion and sound, performance budgets.
5. **Distribution:** playable browser release first; Godot / Unreal only as a deliberate parallel native client with asset parity, build automation and performance evidence.

## Delivery waves and acceptance gates

| Wave | Feature | Shippable acceptance condition |
|---|---|---|
| v27 (baseline) | Free walking around original city | Third-person navigation and the three original hotspots work |
| **v28 (this release)** | **Expanded district, electric car, pedestrians and moving traffic, side contracts, persistent rewards, selectable lighting/rain, route-based minimap** | Source tests prove legacy-grid parity, hotspots and contracts are reachable, driving collisions and rewards; browser tests verify street mode and no uncaught errors |
| v29 | Character rig, locomotion blend trees, smarter vehicle and camera physics, pedestrians with safer crossing routes | Animation state transitions and collision/camera regressions tested at 30/60 FPS |
| v30 | Multi-district streaming, loading and checkpoints, interiors, mission state machine, richer dialogue | Save/load restoration validated under failure and refresh; stable frame pacing |
| v31 | Authored art pass with legally licensed high-quality 3D environments, PBR material library, detailed vehicles and NPCs | Art and perf review at desktop 1080p and mobile mid-range; accessibility review |
| v32 | Campaign chapter, reactive economy, soundscape, localization, polishing and player onboarding | 60-minute playtest, signed off without progression blockers |
| Native AAA track | Godot or UE native prototype with matching gameplay contract and environment benchmarks | **Only claim an engine release after a compiled, playable artifact and test log exist** |

## Concrete v28 controls

- **W/A/S/D** move or drive. **Shift** sprints on foot. **F** enters or leaves the city EV nearby.
- **E** interacts with hot zones or blue service beacons while on foot. **1/2/3** changes cooling tool.
- **T** cycles dusk/night/day; **P** toggles rain; **Q** switches high/eco quality.
- **Mobile:** touch joystick, drag the viewport to turn camera, on-screen car/interaction buttons.
- The original strategic map still handles the authoritative three-placement puzzle. The vehicle is a municipal service car, and side-contract progress saves locally only.

## Measurable quality standards (targets, not achieved AAA claims)

- Gameplay desktop target: responsive 60 FPS at 1080p on a defined reference machine; mobile target 30 FPS on mid-tier devices; adaptive render scale when FPS falls. Must benchmark actual hardware rather than declare success from static source.
- Street design: reachable missions, clear landmarks and turn-by-turn minimap guidance; no dead-end progression.
- Security and safety: no network secrets in the client, no privileges needed, user-safe storage parsing, no server persistence assumed.
- Visual bar: a cohesive cinematic art pass requires high-quality models/textures/animation; **procedural boxes are a playable prototype, not photorealistic AAA artwork**.
- Scope: Unreal Engine 5.8 should not be promised without verifying the engine version and actual native build environment; migration alone does not make graphics AAA.

## Known limitations of v28

- The new city is procedurally generated and deliberately lightweight, not a photorealistic scan of Athens.
- Pedestrians follow simple routes, traffic is ambient and does not use full traffic lights or advanced AI.
- Vehicle handling is arcade-style; physical impacts, damage and advanced tire models are out of scope.
- Atmospheric weather is visual and changes sim ambience; it does not alter the educational temperature model.
- Contracts and credits are stored on this browser only; they are not synchronized to accounts.