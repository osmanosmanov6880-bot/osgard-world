# CITY REIGN — WORLD PRODUCTION ROADMAP
Date: 2026-10-29
Engine: existing Godot 4.4.1 GL Compatibility / WebGL2
Canonical published baseline: R163, c2daff6b501be16fd292f9dc06989e4e02736dd0
Canonical game URL: https://osgard.world/games/city-reign/
This is an engineering plan and acceptance contract, not evidence of completed features.

## Product charter
Build a coherent standalone third-person / driving / city governance open-world game with original licensed 3D art, meaningful missions, persistent player progression, credible urban systems and three fully supported languages (RU, EN, ZH). GTA VI / The Matrix Awakens / Forza Horizon 5 are visual and interaction REFERENCE TARGETS only. Their studio-scale scope, proprietary assets, fidelity and budgets cannot be assumed or reproduced by automatic version-number increments.

## Rules applying to EVERY delivery
- Never replace an actual Godot game with an image, landing page or screenshot mock.
- Update only the original game source beneath godot/empire-omega and compatible workflows.
- Maintain 40 existing campaign missions, economy, saved city, player/car position and law system unless a versioned migration and regression prove preservation.
- All graphics must be rendered in the engine (original or properly licensed source meshes, material resources, effects).
- Prefer reused/cached Mesh resources, GL Compatibility shaders, bounded draw calls, CPU/GPU profiling and distance-aware LOD. Never fake measured FPS or real hardware success.
- Strict Git SHA and server file digest verification, true Chromium WebGL2 and gameplay input tests, isolated SSH rollback, source-locked artifacts and documentation per release.
- Internationalization, keyboard/gamepad/phone, reduced-motion, captions and colorblind readability required for every user-facing feature.

## Stage A · R164-R170 · Vehicle, interaction, premium visual vertical slice
A1 R164: true driver-seat camera with physically modelled dashboard/wheel/speed needle, restore windshield in other cameras. Preserve R160 Street/Classic/Panorama. Native four-mode, scene and 3-draw allocation tests.
A2: vehicle handling telemetry against repeatable acceleration, braking, tyre slip and four-contact simulation; actual Godot 4.4.1 test course and confidence labels (arcade physics, not claimed VehicleBody3D realism).
A3: original sculpted car body variants with premium PBR materials, separated headlamp/tail signatures, interior material pass and authored sound with legal asset provenance. Model LOD and shadows budget on LOW.
A4: driver feedback: indicators, hazards, adaptive sound, road spray and stable night visibility. HUD and cockpit agree with actual GameState and vehicle telemetry.
A5: one polished urban vertical slice with repeatable 5–10 minute player journey, no artificial screenshots, real Chromium screenshot diff and 30-minute exploratory playtest.
EXIT A: vehicle entry/exit, collision, camera cycling, audio, weather, 3 platforms' controls, save/load all pass; clear distinction between exterior and interior views.

## Stage B · R171-R180 · The believable living city
B1: minimum three recognizable neighborhoods with distinct authored road widths, landmarks, block massing, foliage, walkable pavements, nighttime signage and interior/public spaces. Use original meshes and streaming.
B2: traffic planner respects genuine closures, red lights, pedestrian priority, vehicle following, city governance decisions, lane identity, and signal phase. Measure stalled loops, deadlocks and pedestrian near misses in a 30-minute run.
B3: pedestrians gain visible task-driven routines: walking, crossing, waiting, commuting and reacting to actual nearby traffic; preserve original 34 citizens and no unsafe teleport hacks.
B4: real interactive day/night, rain, wet surface braking/visibility and municipal response systems, all source-verified.
B5: LOD, multi-mesh source reuse, streaming/chunk lifecycle and profiling before increasing crowd/population; no promise of GTA-scale NPC counts.
EXIT B: continuous 30-minute traversal on real desktop WebGL with no hard lock, broken routes, fatal errors or uncontrolled frame-time spikes; at least three visually distinct navigable areas.

## Stage C · R181-R188 · Completed gameplay and content
C1: preserve all existing 40 missions and progression. Identify 10 flagship missions for actual authored scene scripting, acceptance checks, car/on-foot objectives and meaningful fail/retry.
C2: upgrade economy and city policies into meaningful, testable tradeoffs with visible outcomes; no cosmetic clicker counters masquerading as gameplay.
C3: law/police, vehicle damage and traffic offenses have understandable causes, predictable consequences, recovery and fair feedback.
C4: interactive property/services as authored tasks; maintain player wallet and inventory authority in GameState only.
C5: one polished first-hour playthrough, clear onboarding, accessibility, strong save integrity, fully translated HUD, titles and scene cues.
EXIT C: a new player can finish the tutorial and 60 minutes of coherent play without instructions from the developer; replay/restart/save/load and original 40 missions pass automated coverage.

## Stage D · R189-R194 · Performance and accessibility hardening
D1: capture real GPU/CPU/frame-pacing/memory and input latency on physical Android, physical iPhone (eligible browser), and mid-range desktop; do not count viewport emulation as device validation.
D2: establish reproducible scene stress tests (dense intersection, driving speed, interior, rain/night). Record median and p95 frame duration, spikes, peak memory, shader errors and build byte size.
D3: target desktop 1080p 60 FPS and a qualifying mid-range Android at stable 30 FPS p95 <= 33.3 ms where hardware allows; these are TARGETS, not observed facts. Define documented device list and graceful lower-quality tier.
D4: improve input latency, memory lifetime, adaptive settings, reduced motion, UI contrast, keyboard/gamepad/touch target size, localization fallback and network/CDN packaging.
D5: native save migration tests and long-soak runs; no render regression and no lost player files across deployment.
EXIT D: performance results published for at least three real devices, zero unhandled WebGL crashes on supported device set, no reproducible hard freeze in 60 minute soak.

## Stage E · R195-R200 · International release and game 1.0
E1: RC content freeze, feature gating and launch build signed by exact source commit, deterministic asset list and test evidence.
E2: RU, EN, ZH end-to-end translation QA, help, accessibility and input legends on desktop/mobile.
E3: onboarding usability testing, player feedback, telemetry minimization/privacy, crash recovery and community support pipeline.
E4: full regression matrix: 40 campaign missions, city economic integrity, road policies, vehicle physics, interior/exterior cameras, real Chromium WebGL and physical supported devices.
E5: GitHub release notes, legal/asset attribution, player documentation, rollback drill, isolated SSH atomic deployment and independently repeated public WebGL acceptance.
EXIT E: 1.0 launched at canonical URL with completed first-hour game, published supported-device measurements, no open critical/blocking bugs, recovery of previous release proven.

## Explicit release gate
1. Dedicated feature branch and PR for each milestone; no direct default-branch overwrites.
2. Strict Godot 4.4.1 import and all native scenario tests with zero unexpected errors.
3. Export actual .html/.js/.wasm/.pck/.png artefacts, archive source SHA and SHA256SUMS.
4. Real Chromium renders original 3D world and accepts genuine input on desktop and phone-shaped viewport.
5. For significant performance changes: real-device testing BEFORE release approval.
6. Fast-forward release ref using expected_sha guard only from a passing immutable commit.
7. Atomic SSH upload to only /games/city-reign, server SHA check, public WebGL2 with actual input and frame evidence, rollback on any failed gate.
8. Save evidence + checks in GitHub Actions, record the exact publicly shipped commit and release notes.

## Feature ownership and resourcing reality
Engine systems and infrastructure can be iterated in code. World-class photorealism, professional vehicle sculpting, character animation, voice, sound mastering, visual direction, narrative and device QA require original licensed assets and dedicated human production time. Do NOT claim those resources or AAA parity until proven. A small finished, highly polished game takes priority over a giant unfinishable map.

## Tracking / status
R163: verified and published with original Godot build, SSH and independent public Chromium PASS.
R164: published at canonical site (767a64fe, SSH run 40789722171, original 3D cockpit and public Chromium PASS).
R165: verified and publicly published at canonical site (8b32c055, SSH run 40820474382, 3428 native checks, real public Chromium PASS). R166: original road contact craft under private native + Chromium QA, NOT shipped until exact SHA SSH and independent live browser PASS. R167-R200 planned only.
