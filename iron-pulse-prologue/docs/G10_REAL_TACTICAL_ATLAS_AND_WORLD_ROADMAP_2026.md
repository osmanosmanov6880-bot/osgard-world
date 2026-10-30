# IRON PULSE WORLD G10 — TRUE TACTICAL ATLAS / REAL GAME UX

Date: 2026-10-30. Parent: [G7–G9 PR #698](https://github.com/osmanosmanov6880-bot/osgard-world/pull/698), exact-head 302b7852291386c8a7ab8ed0983913c56950e2cc, [full CI #41027430195 success](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41027430195).

## Purpose

Move beyond release paperwork into **actual playable Godot UX** without inventing a SaaS back-end, multiplayer users, GPU performance or art certification. G10 is a **real native in-game tactical atlas** drawing an original top-down sector schematic from existing physical 3D terminal/relay/field-station coordinates. It reads current IPCrisisEngine metrics, and the objective target is obtained from the same source-resolved IPWayfinding.goal_id as the existing 3D wayfinder. No HTML stand-in, random numbers or injected victories.

## Block A — Native Godot tactical map

- scripts/IPTacticalAtlas.gd: independently rendered, dark-obsidian 2D native Control._draw with three schematic sectors, corridor frame, real physical terminal markers, real relay and optional field stations. All markers originate from real in-memory scene data configured by Main; unknown/duplicate identifiers cannot create invented targets. Bounded to 40 markers.
- Real player position (world X/Z), exact current objective, sector, heat, oxygen, crew condition, door capacitor and timer are read from source state. The map reports straight-line distance; never claims A*, navmesh, traversable wall path, hardware GPS or real facility guidance. Bright player position and objective are visually distinct, with safety urgency on critical fictional crisis readings.
- Status remains **local only**: no account IDs, IP, telemetry, phone identifiers, user uploads, external requests or changes to story/checkpoint. The map contains a machine-readable readout for native regression and optional read-only browser QA (not a JS control API).

## Block B — Real interface and platform controls

- scripts/Main.gd: F2 opens a centered, responsive native map overlay. Main simulation is paused safely for reading, without player movement, mission time use or source state mutation. ESC/F2 or the native CLOSE button returns to gameplay; gamepad D-pad LEFT/B has equivalent access. Existing pause, gamepad, keyboard, checkpoint, G4 lab, H wayfinding, T forecast, F1 guide and other features remain intact.
- A genuine 51px MAP / F2 mobile touch button fits the middle column without overlapping the pre-existing LAB and SHOT controls. The map dynamically scales at 320/390px and English/Russian can switch inside the paused map.
- Native visual art direction is **Obsidian Precision**: restrained blue-black background, cool-cyan objective emphasis, amber relays, neutral field stations, red danger, clear typographic hierarchy. No AI-rendered screenshot substitute.
- The portal's G10 content is sourced from what actually exists in the game, with RU/EN translation, clear non-navigation disclaimer and adaptive CSS instead of a mock dashboard.

## Block C — Genuine hardware-independent software QA

- tests/test_g10_tactical_atlas.gd: actual Main.tscn import, scene-aware physical marker inventory, live crisis snapshot/distance, nonmutation, safe pause, language switch, keyboard/gamepad, mobile controls/close, pause compatibility and original checkpoint.
- ci/browser_webgl_acceptance.py: actual exported Godot/WebGL browser canvas gets real F2/ESC, touch MAP/button input and a raw Chromium screenshot for desktop/touch emulator. Read-only state is checked for real station source, valid objective, localized text, source scenario preservation, zero uploads. Screenshots have original scene pixels (not AI generation).
- ci/world_portal_acceptance.py: RU/EN G10 preview, 320/390px responsiveness, and explicit no-fake-route wording are tested alongside original campaign links.
- Existing V1–V18/G1–G9 regressions, real Godot Windows x64 + WebGL export, G5 source-bound reproducible packaging, G6 hardware HOLD, G7 human HOLD, G8 legal HOLD and G9 offline-operations HOLD stay mandatory.

## Explicit quality and commercial boundaries

G10 is an **authored in-engine user-experience improvement**, not a claim of independent AAA quality. Browser mobile emulation is not real iOS Safari or Android GPU testing. Schematic coordinates may not represent walkable paths; the existing 3D marker and real movement remain the navigation authority. The project has no authorized production release, signed Windows binary, real 20-person study or independent full art/audio/license/security approval.

Full QA acceptance must be exact-head in GitHub Actions before marking this candidate green. Keep G10 draft and do not merge to master or deploy websites automatically.

## Larger execution plan through a genuinely operated international game

**G10 — Player situational awareness:** complete real tactical atlas, responsive controls, physical input and visual QA, avoid fabricated map routing.

**G11 — Visual/lighting polish:** independently review real gameplay captures per scene. Correct physical PBR composition, lookdev, fog/contrast, animation clarity, shader complexity and legibility directly inside Godot. Compare desktop/mobile images from the same camera without changing source proof.

**G12 — Accessibility and device controls:** settings for font scale, color-vision-safe hazard encoding, gamepad remap, pause/menu focus and screen reader strategy; test real Windows integrated/discrete, Android low/mid and iPhone/Safari and 30m thermal soak. Do not assume emulators certify phones.

**G13 — Gameplay depth & three-act review:** playtests with 20 consenting people, then adjust rescue choices, difficulty onboarding, feedback and replay variation using results, keeping V6/V9 saves compatible and P0/P1 regressions closed.

**G14 — Legitimate global distribution:** rights audit for artwork/music/font/voice/trademark, binary signing, private reviewer GO, real CDN/host staging, signed provenance, explicit canary switch, real-host rollback/restore, RU/EN support; not automated by G10.

**G15 — Operated global service:** consented analytics and crash observability only after privacy/security approval, support/incident response, 30/60/90-day measurements; evaluate further languages and storefronts based on actual observed demand and unit economics, not invented revenue.

Each stage blocks final commercial GO until independently witnessed. **Global reach is a strategic goal, not a CI status.**
