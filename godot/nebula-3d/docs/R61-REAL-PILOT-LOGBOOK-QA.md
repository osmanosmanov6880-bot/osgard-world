# NEBULA R61 — earned per-captain flight logbook

**State:** source branch only. This feature is NOT deployed to public R60 until native Godot and real Chromium CI succeed.

R54 already implements game-credit captain training with independent ranks and actual defense/thrust/mission-credit bonuses. R61 does **not** duplicate those purchases. It adds *earned* per-captain real flight history.

## Four real engineering blocks

1. **Deterministic ledger:** `pilot_logbook_r61.gd` validates only Ada/Kai/Leya; records launches, verified mission/contract successes, failed flights, cumulative flight_distance in metres, real unlocked seconds and best/last sortie. Zero game-credit or XP minting.
2. **Game event wiring:** one record begins after actual unlocked garage departure; it closes exactly once on genuine mission/contract completion, failed sortie or R60 physical crash. Gameplay physics produces the distance; no developer-facing button can fabricate a pilot qualification.
3. **Persistent, corruption-safe progression:** optional `pilot_logbook_r61` is stored in existing `user://nebula_3d_save.json` version 1. Missing legacy keys load clean; invalid, infinite, negative and injected values are sanitized. Qualification requires both real success count and cumulative distance.
4. **Russian crew dashboard:** the existing premium minimal garage PИЛОТЫ tab now shows individual certified flying history and distance under the existing R54 academy.
5. **Native regression:** scripted tests verify an actual departure, 1875 metres and 85 seconds, failure counted exactly once, zero CR/XP grants, separate captain state, safe legacy save/reload, spoofed metrics rejection, earned Kai flight qualification.

## R61 acceptance contract

- Godot 4.7.2 native editor parse and runtime smoke must show `NEBULA_R61_REAL_PILOT_FLIGHT_LOGBOOK_SAVE_NO_MINT_SUCCESS` plus prior R60 success.
- Existing WebAssembly Chromium flight and 390×844 mobile touch regressions stay required.
- Until PR acceptance and 4-blob SSH release + public HTTPS exact-byte parity, production remains R60.
- Physical Android/iPhone QA: **NOT_PERFORMED**. No hosted SwiftShader capture is mislabeled as hardware quality evidence.

## Native/Chromium R61 test findings and R60 recovery correction

Latest native R61 parse, real game runtime smoke and WebAssembly export passed after the Kai history baseline correction. The WebAssembly Chromium PC flight also passed, but mobile Chromium CI exposed a real **test/game state handshake race** during device rotation: the physical R60 crash locks the ship during a 1.6-second rendered wreck hold (as intended), whereas the earlier R31 test immediately demanded an R43 garage retry button that cannot exist yet. The same snapshot showed Godot 320×480 touch geometry but stale CSS 844×390 from the prior orientation.

The enhanced R61 branch now exposes only gameplay state flags (`garage_open`, `crash_hold_active`, remaining hold milliseconds, real retry-button visibility) via QA telemetry, waits for the *real* crash-to-garage transition, then dispatches an actual CDP finger tap to the visible Godot retry button. It also requires matching Godot/CSS portrait geometry before pressing GAS. It **does not** force a successful sortie, call game internals from JS, disable collision physics, mint credits, or waive real mobile browser gates. Failure to emerge from the crash hold or to expose a real garage button remains a hard test failure.

Public R60 is unchanged. Hosted SwiftShader is software renderer only, physical phone GPU QA **NOT_PERFORMED**.

## R61 auto-repair repeated flight fix

After the R60 real physical crash, free-flight mode repairs the ship without returning it to the garage. R61 must **start a new flight record only after real hull recovery and controls unlock**, otherwise the first crash is recorded and all later crashes silently disappear from the pilot logbook. The new `_r61_begin_sortie()` call is restricted to the free-flight repair branch after the exact 220 CR fee and never invokes a mission success handler. Existing XP/CR economy and R43/R57 garage retry remain unchanged.

An additional Godot native regression now destroys the actual craft **twice**, waits for real 1.6-second debris holds, verifies two failures are recorded exactly once, two separate 220 CR repair fees, **zero XP mint**, and the next free-flight logbook is armed. No synthetic wallet or record increment.
