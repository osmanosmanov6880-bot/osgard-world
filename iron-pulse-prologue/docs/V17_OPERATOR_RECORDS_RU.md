# IRON PULSE WORLD V17 — OPERATOR RECORDS / PRIVACY FIRST

## 0. Source lineage

Base: verified V16 commit `9ee417b5e41963b86415da7b5f1833886ff8d26c`, GitHub Actions [40774690367](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40774690367), full CI SUCCESS. The new branch continues the existing Godot 4.4.1 game and integrated RU/EN WebGL portal; it does **not** replace gameplay or touch `master`.

## A — lasting product value, no fake player stats

`scripts/IPRunArchive.gd` records **only actually completed** `IPCrisisEngine` runs, using `IPAfterActionReview.review(engine,campaign)`. The saved record includes actual scenario, engine grade, outcome, elapsed time, heat/oxygen/crew/bulkhead charge, switches, rejected commands, repair and relay choices, actual ordered event keys and proven chapter victories. No timestamp per event is invented, because the original engine never captured that timing. No leaderboard, cloud account, social metrics, player-identifying metadata or API call.

The archive retains **the most recent 16 actual results**, not sixteen generated examples. It computes personal best by actual engine grade first and fastest elapsed time within that grade second. No personal best is displayed for a mission with zero wins. Local sequence numbers are scoped to this single copy of the game and never called global ranks.

## B — native UX, protected storage and real deletion

- Use **O** during the intro, when paused, or after a completed mission. A live unpaused crisis cannot be interrupted by the archive.
- Use the visible 52px button in the intro or mission end, or standard gamepad X before/after an operation.
- Dismiss with O, ESC or a visible 52px close control. The UI is a real native Godot Control/ScrollContainer, localized RU/EN and rendered inside the game, not an HTML image.
- In the archive, deleting all records requires **two deliberate presses**. It does NOT erase existing V6/V9 campaign progress or engine checkpoints.
- Native archive uses `IPCheckpointStore` atomic `user://` save and SHA-256 corruption detection. A corrupt or unsupported existing archive is **never silently overwritten**. The operator is told it is protected, and can explicitly clear it with two confirmations.
- SHA-256 is accidental corruption detection, **not a cryptographic authenticity proof**. Existing local files are not signed or secure against an owner with filesystem access.
- Save failures are disclosed on the game result screen. The active gameplay state is never modified by archiving, viewing, erasing or validating the personal history.

## C — exact-source QA and world launch path

The mandatory Godot regression `tests/test_v17_operator_records.gd` tests real wins/losses from the original engine, absence of fabricated prelaunch data, persistence after cold reload, strict type/range checks, invalid payload rejection, bounded last-16 retention, checksum corruption, path traversal, original campaign save isolation, native UI (O, ESC, language), two-click erase, and double-end protection. CI continues to run all previous V1–V16 native tests, exports WebGL and Windows x64 from the exact commit, produces source manifests and runs real Chromium emulated desktop/mobile interaction.

The RU/EN portal includes an explicit operator-records section. A visible 16 is labeled **maximum local storage capacity, not actual player count**. Native Chromium tests exercise keyboard O and 52px touchscreen open/close in the real Godot game and require empty records on a fresh session.

## D — release constraints

**SOFTWARE PREVIEW / PRODUCTION HOLD.** Passing CI is not a commercial international launch, native GPU certification, physical Android/iOS/Windows acceptance, controller hardware QA, user-retention research, art-direction acceptance or rights clearance. WebGL game binaries are not promised fully offline; the PWA only caches its small static shell. No unverified adoption metrics or fake screenshots.
