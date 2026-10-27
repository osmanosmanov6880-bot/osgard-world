# SABLEFAULT — INCIDENT 01 (experimental vertical slice)

**Status:** original playable browser prototype, **not** an AAA release, not an approved store title, and not deployed to osgard.world.

SABLEFAULT is a **provisional internal codename** only. A public name search identified a pre-existing video game and trademark uses of **REACTOR ZERO**, so that earlier proposed title is deliberately **not** used as an approved commercial brand. A full international trademark, store and domain clearance remains required even for SABLEFAULT.

## Quick start

This is an entirely new, **standalone** WebGL2/JavaScript game under `public/games/sablefault-preview/`. It does **not** replace or rename the established `w33-godot-native` / W58 Godot game. No Godot runtime, external library, CDN, account or network API is required to run this preview.

1. Extract `index.html`, `styles.css` and `game.js` into one folder.
2. Start a standard local static HTTP server, for example `python3 -m http.server 8769` **inside that folder**.
3. Open `http://localhost:8769` in a WebGL2-capable desktop browser. The preview also supports a CPU perspective fallback if WebGL2 is unavailable.
4. Select **Начать эпизод / Begin incident**. Follow the first directive to the central command station.

Controls: **WASD** move, **Shift** move faster, mouse look (click the canvas to capture, Esc to release), **E** use nearest terminal, **L** switch RU/EN, **H** show help. On mobile, use the bottom D-pad, drag inside the look area and tap the action button.

## Actual gameplay loop

- **Phase 1 / Command.** Walk to the station marked `C-01`, acknowledge a four-minute emergency.
- **Phase 2 / Systems.** Operate two independent coolant arrays, a pressure relief valve and one limited backup energy cell. Running pumps lowers core heat but raises pressure and drains electricity. Venting drops pressure but consumes oxygen. These four quantities **evolve every frame**; a resource exceeding a critical bound ends the incident. The player must keep heat below 53 and pressure below 62 with power above 12 for **seven consecutive seconds**.
- **Phase 3 / Choice.** The `R-19` grid relay offers two **mutually exclusive decisions**: prioritize the trapped crew or preserve the archive. The decision affects oxygen/power and changes the final narrative.
- **Phase 4 / Exit.** Return to `E-01` airlock. Unlock is conditional on the preceding steps. Finish with a score, consequences, and replay. Timeout and several critical resource states lead to honest failure rather than fake success.

**Original visual direction:** monumental neo-brutalist facility, black titanium, cold cyan containment light, emergency red, procedural annular core, volumetric-looking haze and diegetic station controls. Original synthesized interaction audio only; **no third-party copyrighted assets**.

## Privacy and safety

- Fictional educational crisis scenario; **not industrial-control or emergency training software**.
- No analytics, account integration, external requests or local persistence.
- Local WebGL2 draws only procedurally generated geometry. CPU fallback uses the same authored 3D geometry and a depth-sorted 2.5D view; it is not proof of dedicated-GPU performance.
- `window.SABLEFAULT_INSPECT()` returns **read-only** game diagnostics to help QA; no setter or cheat API exists. Production and real hardware certification are always false.
- No changes to OSGARD master, production domain, VPS, DNS, CI release selectors, payment systems or older W58 snapshots.

## Verified locally on 27 October 2026

- **Node JavaScript syntax check: PASS.**
- **Chromium native control path: PASS** — real key movement to a nearby station, E opens the terminal, an authentic visible button starts the phase. Another end-to-end test reached both pumps, vent, grid decision, evacuation victory, a scored mission report, restart and RU/EN switch.
- **390×844 UI check: PASS** — actual CDP device metrics, original mobile screenshot and visible mobile action button.
- **Visual rendering:** the environment policy of the local Chromium explicitly disables WebGL. Screenshots and gameplay were verified with the independent CPU-perspective fallback. **WebGL2 / true GPU rendering is not yet certified and must pass a separate actual GPU/browser smoke before release.**
- The local test invokes genuine keyboard and visible buttons and **reads** game state through the read-only inspector; it never directly injects success or resets a resource.

## Acceptance before expanding toward a commercial game

1. Real WebGL2 shader compile, desktop, mobile and memory regressions on a separate runner; capture native screenshots, console errors, frame metrics.
2. Playtest the full systems loop **with 10+ human players**, separately measure comprehension of failure, completion %, replay, time to first action, discovery of both endings and device compatibility; improve balance from observations.
3. Decide whether the reactor loop is compelling enough to justify porting the episode into **Godot 4.4.1** and combining it with the existing W58 six-mission simulation. Do not assume a WebGL prototype is already a native Godot title.
4. Replace all primitive assets only when the mechanic is validated, then add cinematic character/story, atmospheric audio, authored scenes and animation.
5. Independent IP review and commercial title clearance, accessibility, save/load/privacy, full hardware QA, platform requirements, marketing/store assets and publisher budgets before claiming production-ready or AAA quality.

**Current decision: EXPERIMENTAL PREVIEW, NO PRODUCTION GO.**
