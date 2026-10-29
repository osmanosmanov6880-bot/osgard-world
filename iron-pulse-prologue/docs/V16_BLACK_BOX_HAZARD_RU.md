# IRON PULSE WORLD V16 — THREAT INTELLIGENCE / BLACK BOX

## Source and baseline

This is a REAL Godot 4.4.1 change on top of V15 exact head `ffa2edb6daeff9fe051678496619fd142e1df64e`, independently verified by GitHub Actions run **#40769873030 (success)**. Existing V1–V15 gameplay, three emergencies, three-act campaign, original 3D reactor, player controls, V6/V9 saves, bilingual portal and preflight diagnostics remain the source of truth. The integration stays outside `master` pending final release GO.

## Product block A: real threat intelligence, not a cosmetic gauge

`scripts/IPThreatRadar.gd` reads the live `IPCrisisEngine` state. The compact native cockpit shows STABLE / WATCH / CRITICAL / COMPLETE / FAILED plus a localized specific cause. Source-backed thresholds cover temperature, oxygen, crew, time, disconnected COOLANT/LIFE bus, the actual remaining thermal pulse countdown, and the genuine AIR rapid-patch microleak. The report is **read-only** and uses no fabricated mission score or analytics. The Godot HUD surfaces a visible, bilingual industrial status strip using the existing black-titanium/cyan/amber/red palette.

## Product block B: the honest A7 black box after a genuine result

`scripts/IPAfterActionReview.gd` is intentionally unavailable during a live or unstarted mission. After a real engine WIN/LOSS, it renders actual grade (UNRATED on failure), remaining heat/oxygen/crew/door, elapsed time, power switches, rejected actions, repair strategy, activated relays, and the last 12 actually recorded engine events **in order only**. Source does not store per-event timestamps, so the UI refuses to invent them. Outcome classification and lesson are derived from the real cause of failure or completed run. A real campaign record contributes its confirmed chapter count; no cloud leaderboard or fake global adoption numbers.

The operator can open the genuine native Godot evidence panel via **B**, gamepad **B/Y after completion**, or a visible 52px result-screen button. Exit with **ESC** or the on-screen 52px close control. A vertically scrollable result/history and fully bilingual headings keep long campaigns usable on narrow displays. The original end screen remains mounted behind the black box and the full simulation is never modified by opening/closing evidence.

## Product block C: actual 320/390px + desktop/browser and exact-head CI

- Native test: `tests/test_v16_black_box_hazard.gd`, covering real engine GRID victory, HEAT/AIR physical failure paths, countdown and microleak, accurate event history, player inputs, controls, bilingual report, in-game panels and checkpoint compatibility.
- `.github/workflows/iron-pulse-blackout-slice.yml` blocks release if any real engine, historical V1–V15 or V16 check fails.
- `ci/browser_webgl_acceptance.py` checks the **actual Godot WebGL** threat monitor on real player launch and explicitly requires no premature report or fake result. The existing V15 real mouse/touch planning forecast test remains intact.
- Portal controls now disclose the **B** post-mission black-box key and why there are no mock records; locale and PWA shell cache version updated. No automatic downloading of giant WebGL binaries into the PWA shell.
- Windows and WebGL output, source SHA manifest, genuine real Chromium screenshots and source-bound bundle are produced by CI only after validation.

## Release readiness

**SOFTWARE PREVIEW / PRODUCTION HOLD.** CI proves the code path in emulated Chromium and native headless Godot; it does not prove a good commercial game or physical iOS, Android, Windows GPU and gamepad performance. An independent real-device matrix, game studies, rights audit, legal/commercial QA, secure staging and reversible publishing decision are still required. No users, FPS results or global service usage are invented.
