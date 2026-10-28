# LAST FRONTIER — W71 / THE LAST SHIFT: TRUE SPATIAL MISSION

28 October 2026. **Actual playable Godot 4.4.1 source, not image concepts or a static demo.** Base exact accepted W70.1 `0fea3572b6ce75d3aab144ff678eb181b1713aac` ([3/3 CI PASS](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40628540819)). Draft W71 candidate — production approval withheld until its own exact SHA passes all gates.

## A functional change, not extra decoration

W70.1 has actual CharacterBody3D collision, moving first-person camera and an illuminated bridge between reactor and relay. The player could walk and investigate, but those actions didn't add a connected playable objective. W71 implements a **five-objective playable story** that explicitly combines the real two physical rooms with the existing deterministic six-cycle A7 simulator. Nothing fakes the model's win/lose outcome.

## Five authenticated objectives

| Stage | Player must do | Authority / real effect |
|---|---|---|
| 01 — Access reactor | Press `T` to opt into mission, `P` to enter physical operator, walk to reactor console, press `E` | Real `CharacterBody3D` distance from reactor console is checked again by mission authority; remote/spoofed `E` rejected |
| 02 — Stabilize primary | Make two **actual** game decisions (`1…5`) and survive first shift | Only `A7CascadeCore.choose()` can accept decisions. Metrics change as before; incident and first-cycle integrity recorded |
| 03 — Relay inspection | Physically navigate W70.1 walkway to separate second sector, approach relay console and press `E` | Mission checks real distance to second console before advancing. No teleport or direct unlock by switching camera |
| 04 — Hold the cascade | Survive remaining five original shifts, including their consequences | Requires actual core-game `status == won`; failure/unstable produces genuine failure state |
| 05 — Return to the core | Physically come back to the reactor and press `E` | Mission completes only after a verified six-cycle **original** win and final genuine distance check |

The **five spatial stage transitions** are different from the **six original incidents**. The end is not automatically awarded after pressing E, and the whole sequence has to be completed in one session. It may take more or less than 10–15 minutes; **no human duration has been measured** and we do not claim otherwise.

### New real 3D visuals and narrative UI

- Original `A7SpatialMission.gd`: two separate world-space objective pillars (`CylinderMesh`), two genuine `TorusMesh` marker rings, two `Label3D` labels, and `OmniLight3D` target illumination. Markers change based on actual ordered objectives, not a random VFX timer.
- Extra HUD: accessible RU/EN phase title, instructions, 5-step progression, operation start button; `T` works from the actual Godot game, `E` remains a true physical proximity interaction.
- The five-stage chain tracks real accepted engine choices, real spatial inspections, current safety/energy/pressure consequences, whether the player has won or failed, and **true monotonic session time**, not an invented completion-time score.
- Lower-performance ECO and reduced motion adapt real in-world marker visibility/lighting; compact phones hide nonessential 3D world labels while keeping accessible HUD text.
- The original W63 action buttons, all narrative, incident math, sounds, W69 optics/cinema and W70 actual character physics are unchanged at their source blob level.

## Real engineering acceptance

1. Exact descendant of accepted W70.1 SHA `0fea3572...`. Check 27 protected unmodified original game/3D/physics/audio/test/export Git blobs. Only seven W71 paths allowed.
2. Original Godot 4.4.1 headless import without GDScript parser errors.
3. Eight independent native Godot suites W63/W64/W65/W67/W68/W69/W70/W71. W71 independently verifies physical CORE/RELAY proximity, prevents out-of-order and spoofed interactions, proves 12 actual decisions and complete six-cycle winning route, requires final 3D return, proves genuine losing route and proper restart, RU/EN mobile and ECO.
4. Actual Godot `index.wasm` WebGL + original W70 Chromium regression. New W71 browser uses **real keyboard input** `T/P/S/E/1/4/L`; verifies that distant E fails, actual physical walking advances character, close E unlocks first target, two true decisions unlock relay; captures **7 new original 3D PNGs**, desktop and 390px mobile.
5. Previous W70 driver contributes 7 more original frames. All 14 images carry source-bound SHA-256 in GitHub artifacts and must be manually reviewed. No HTML screenshot painting, no fake forced core state in the browser test.
6. The exact latest PR commit must have 3 successful CI jobs. Earlier W70.1 success is **not** proof of W71 success.

## Still missing for an AAA/world-class commercial game

W71 is a meaningful interactive mission slice but is **not an artist-approved or player-timed complete 10–15 minute vertical slice**. The two sectors still use procedural engineering meshes and synthetic audio. It needs richer actual authored art, more varied interactions than inspecting a console and choosing two buttons, first-time player testing, narrative/voice performances, device GPU FPS/1% low/thermal optimization, gamepad, collision tuning, and proof of legal brand use.

**Proposed W72 production block:** three distinct station-specific physical puzzle mechanics (not only nearby E), tutorialization with world arrows and ambient narrative, reactive machine animations, actual saving/resume of both core and spatial state, real art/sound review, 12 first-time-player studies with measured session length. **W73:** full graphics pipeline, external independent QA and legal commercial gate.

## Safe delivery boundary

W71 is an isolated **DRAFT PR / PRODUCTION HOLD**. Do not merge master, publish to the live domain, Steam, mobile stores or claim AAA without real-device certification and independent approval. No physical machine control and no external network are used by this fictional prototype.
