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
