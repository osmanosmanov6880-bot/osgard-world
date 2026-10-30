# IRON PULSE WORLD G12 — REAL CONTROL COMFORT / MOTOR ACCESSIBILITY

Date: 2026-10-30. Parent: [G11 draft PR #702](https://github.com/osmanosmanov6880-bot/osgard-world/pull/702); G11 is a source-backed technical candidate. G12 is stacked on exact G11 source 040878cb9f7713099a3122608c7311c4a757998b. It does not modify master/live domains and cannot approve production.

## What was implemented inside the actual Godot game

**Original IPControlComfort.gd** contains three explicit mutually exclusive physical keyboard presets:

- STANDARD: original WASD movement, sprint while Shift is held. Default keeps existing players and save files compatible.
- ARROWS: movement with directional arrow keys and hold Shift. Real keyboard input, not an automated movement path.
- ARROWS / SHIFT TOGGLE: same arrow movement, but pressing Shift turns sprint on or off. Pausing, finishing, restarting or switching presets clears the toggle.

Physical touch movement and standard mapped gamepad axis are preserved in all presets. Real CharacterBody3D still executes the same acceleration, collision, gravity and move_and_slide physics as before. No change to IPCrisisEngine, resource costs, missions, V6/V9 checkpoints, source PBR art, G10 map or G11 vision settings.

**Native controls**: F7 cycles the keyboard preset in the actual game. The 52px pause-menu button displays the current RU/EN input mode. Mapped gamepad X changes keyboard preset while paused (gameplay X remains quick action). A new 51px mobile PAUSE control sits between existing mobile buttons, with no collision at 320/390px. Actual PAUSE temporarily hides touch controls so they cannot obstruct native menu buttons, and native RESUME restores them.

**Private settings**: only a three-value enum and schema marker is stored in a separate user://iron_pulse_control_comfort_g12.cfg file. The temporary sprint latch is never stored or restored. Invalid config fields cannot cause automation, unlock missions or move the character. No accounts, emails, IP/device IDs, remote calls, analytics or user tracking.

## Mandatory software acceptance

- tests/test_g12_control_comfort.gd: checks pure profile axis selection, diagonal magnitude clamp, safe invalid storage, toggle sprint, local persistence, F7, real Main.tscn input dispatch, original character movement from synthesized Godot ArrowUp events, safe mobile PAUSE/RESUME and non-mutated choice/fault count.
- ci/browser_webgl_acceptance.py: drives **actual exported Godot WebGL keyboard** with F7, ArrowUp, Shift (not patched engine functions), tests physically moved CharacterBody3D under desktop Chromium and clicks actual 51px mobile PAUSE and native RESUME. Checks all actions and outcomes remain source-generated, no automatic mission wins, no external telemetry.
- ci/world_portal_acceptance.py: honest RU/EN control descriptions at desktop/390px/320px and unchanged exact Godot campaign CTA.
- Existing V1–V18, G1–G11, Windows/WebGL export, original game, in-browser asset screenshot capture, G5 Release Vault, and fail-closed G6–G9 proof gates remain compulsory.

### Manual operator QA on real hardware

1. Test real Windows x64 with both keyboard presets and simultaneously connected standard controller. Verify arrows are not trapped by a focused menu after real fullscreen/play.
2. Confirm WASD remains exclusively active under STANDARD and arrows under ARROWS, but touch/analog input continues in every profile. Confirm collisions and physics movement are unchanged.
3. Toggle Shift once, check increased actual speed; press again to stop sprint. Pause/finish/restart and verify no sprint remains latched.
4. On physical Android Chrome and iPhone Safari, tap new PAUSE, verify no button overlays menu controls; tap RESUME and verify original touch navigation returns without a broken pointer lock.
5. Verify mapped gamepad START pause/continue, X config while paused and existing gameplay X; no unexpected action when settings are modified.
6. Verify F7 and actual native pause menu are accessible under HERO/ECO, RU/EN, reduced motion, G11 high-contrast, and at 320/390/768/1366/1920px. Inspect real source screenshots and any repeated keyboard events.
7. Test privacy and cold restart of settings with no latched sprint. Test malformed file and storage errors and ensure normal classic default.
8. Independently verify player motor-accessibility needs; this is an implemented preset, not universal input remapping or WCAG certification.

## Full remaining release program

**G13 — Better playable systems and independent quality**: test actual three-act mission balances, improve real 3D lighting, original audio and decision consequences, and conduct a 20-person independently witnessed player study. Fix P0/P1 before commercial consideration.

**G14 — Production engineering and rights**: obtain written IP/music/fonts/asset review, Windows binary signing, trusted delivery with exact source hash, independent vulnerability/privacy/legal assessment, real cloud/CDN staging and rollback/restore rehearsal. A responsible operator authorizes GO separately; CI cannot authorize it.

**G15 — International operation and growth**: real RU/EN support, opted-in aggregate diagnostics, incident and recovery drills, 30/60/90-day measurements, then expansions based on actual regional/legal demand rather than invented users or revenue.

**Gate:** G12 is software engineering only. Real Windows/Android/iPhone compatibility, accessibility signoff, legal authorization and worldwide commercial reach are not established by CI. Keep DRAFT and RELEASE HOLD.
