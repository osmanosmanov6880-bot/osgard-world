# CITY REIGN WORLD — ENGINEERING ROADMAP TO v1.0
**Baseline recorded 2026-10-29:** R169 released on `https://osgard.world/games/city-reign/`, exact 40-character SHA `8ea20f1b7699a9595800298a5acae6190d4871d2`; verified independently by public Chromium WebGL2 desktop + mobile-sized viewport and by SHA-256 of HTML/JS/WASM/PCK. The isolated temporary SSH cleanup originally failed (connection reset), then succeeded by guarded repair run 40876237523. R170 source `471daad1262b21cf77f1a2631340c9c182e02390` PASSED independent PR+push native and Chromium runs 40877148133 / 40877140193. R170 is a **draft, not public**.

## Definition of complete
A genuinely playable, publishable, original open-city game with a coherent core loop, onboarding, a tested first episode, all 40 progression missions, real saved state, safe vehicle feel, traffic/citizens/economy, original sourced assets, accessible RU/EN/ZH UI, measured mobile/desktop performance, and reproducible multi-stage verified release. **Do not claim visual equality to GTA VI, Forza Horizon 5 or The Matrix Awakens** without comparable hardware benchmarks, authored city scale and external player reviews.

The releases below are **dependency-ordered engineering work packages** and may span multiple GitHub PRs. Shipping gates are based on behaviour and QA, never on version numbers.

### BLOCK A — PLAYABLE CORE AND FIRST-TIME USER EXPERIENCE · R171–R174
- **R171 Context Coach:** source-driven current-action guidance for E/F/B/Tab/N and real cargo mileage, near-vehicle prompts, low fuel/damage, conflicting tasks, stalled saves, no phantom rewards; reuse existing journal only. Unit/native/browser tests and RU/EN/ZH.
- **R172 10-minute actual playthrough:** scripted real Godot input sequence through original player/car world, live car-to-market travel, business purchase and government; measure blockers, rescue/continue path. Do NOT substitute direct `MissionManager.register_action` calls for acceptance.
- **R173 chapter objective UI:** one usable minimal HUD objective, explicit status, distance, route, retry and menu affordances; 320/390/768/1366px actual layouts, keyboard/touch/controller access and no obstruction of physical road.
- **R174 input & comfort tuning:** car feel A/B with real braking, turning, traction and audio, latency measurement, gamepad bindings, accessibility, save/resume in mid-trip.
- **Gate A:** ≥10 external first-time testers, ≥80% finish first loop without developer help; all six actions validated through original gameplay input, not manually advanced mission flags; no dead end from load/cargo retry. Record actual median/p90 time; 5–10 minutes is a **target**, not currently measured.

### BLOCK B — PHYSICAL CAR, TRAFFIC AND CITY EMERGENCE · R175–R180
- **R175–R176:** tyre/suspension/brake and force feedback, car damage/collisions, traction in storms, lane & turn indicators, physically consistent cockpit, optional driving assist without altering game mission authority.
- **R177–R178:** deterministic traffic/lane planning, intersections, crosswalk priorities, police pursuit, legitimate pathfinding around closed roads, pedestrians with avoidance and bounded jobs, agent LOD from original 12 cars/34 citizens to measured safe density.
- **R179–R180:** collision reliability tests, scenario replay, bounded NPC/vehicle/physics budgets, safe returns when cars clip or get stranded, no teleport-generated mileage/contract credit.
- **Gate B:** no reproducible progression blocker in original route set; stable physics determinism within test tolerance; performance and damage/road rules measured on actual desktop and phone.

### BLOCK C — AUTHORED CITY AND AAA-QUALITY VISUAL ART · R181–R186
- **R181–R182:** establish original authored districts: business/market, civic square, residential, industrial/logistics; street atlas, measured traversable routes, proper sidewalks, props, façade topology, LOD and collisions.
- **R183–R184:** source PBR pipeline (consistent real material response, normal/roughness/metallic), time-of-day/weather/light optics, visible glass/water/shadows, appropriate colour grading for web GL Compatibility, no image mock-ups as a substitute.
- **R185–R186:** occlusion and distance culling, lazy district streaming, asset provenance and licences, texture/channel budgets, repeatable screenshot/frame comparisons. Blender-authored/licensed meshes audited for size and draw calls.
- **Gate C:** testable playable neighbourhoods with distinct visual identity and measurable mesh/material quality, stable WebGL2 view and collision for any place players can reach; device performance vs visual fidelity tradeoff documented.

### BLOCK D — FULL CAMPAIGN, ECONOMY AND LIVING SOCIETY · R187–R192
- **R187–R188:** make all 40 authored career actions discoverable, repeatably playable, localised and correctly awarded; 3 chapters tied to actual game world; optional community projects don't block required progression.
- **R189–R190:** economy ledger, stock, business cashflow, investment, infrastructure construction, contract wear and truthful world outcomes from GameState; prevent duplicate payouts, negative inventory and infinite reward exploits.
- **R191–R192:** citizens/relationships/police/public services and 8 civic initiatives with response to player actions; bounded simulation time, persistent physical landmarks, robust completion/failed state transitions.
- **Gate D:** 40/40 missions complete through legitimate gameplay; save/reload/rollback after every critical transaction; no ghost rewards and no save schema regression.

### BLOCK E — ENGINE, SECURITY, RECOVERY AND PLATFORM DELIVERY · R193–R197
- **R193:** save file atomic durability + corruption/backup recovery, migration, export/import, browser storage quotas, origin/privacy constraints, reproducible seed replay.
- **R194:** resource budgets and streaming: shader compilation stalls, texture memory, WebGL2 context loss/resume, browser tab suspended/resume, audio unlocked by user gesture, missing asset fallback.
- **R195:** accessibility and locales: RU/EN/ZH complete content, screen size scaling, remappable controls, reduced motion, contrast, touch targets ≥44/46px, controller usability, zero essential audio-only cues.
- **R196–R197:** security/private telemetry (opt-in only), production monitoring with no player secrets, signed/source-locked artifacts, isolated SSH activation, verified public source SHA and automatic rollback; release channels, restore drill and no leakage to other OSgard routes.
- **Gate E:** no critical/severe security or save-loss bugs, tested rollback, reproducible exact-commit binary and public/live acceptance before promotion.

### BLOCK F — EXTERNAL BETA, WORLD LAUNCH AND LIVE OPERATIONS · v0.9 → v1.0
- Closed beta cohorts, fresh profiles and migration tests, external defect tracking, narrative engagement, accessibility review, mobile device lab (actual hardware, not browser viewport alone), gameplay analytics only with informed opt-in.
- Benchmark targets, to **measure and adjust**: desktop 1080p 60 FPS on stated reference PC; mid-range physical Android playable at ≥30 FPS, p95 frametime ≤33 ms in a measured route; crash-free sessions ≥99.5%, zero data-loss bugs, >=80% complete first playable chapter without external help. Targets are NOT claimed achieved.
- Release `v1.0.0`: pinned source SHA, changelog and licences, independent 40-mission playthrough and saved-game recovery, translated website/store, support path, release rollback runbook and maintenance ownership.
- **Gate F:** external user acceptance, legal/licensing review of each third-party art/audio asset, support readiness and credible real benchmarks. Only then label it a worldwide commercial release.

### BLOCK G — POST-LAUNCH EXPANSION (CONDITIONAL, NOT v1.0 GATE)
- More authored districts and story arcs, DLC, mod tools, accessibility improvements, real player feedback loop and scheduled versioned releases.
- Optional online/co-op architecture **only after** core offline game is valuable and a separate security/cost/business evaluation supports it. Multiplayer and massive-map fidelity are not free patches; do not promise them for v1.0.

## Acceptance policy for EVERY block
1. Start from known passing immutable source and read original API/schema. Commit real code (Godot/Python/GitHub tests), not a concept image.
2. New tests check real scene/physics/UI paths; preserve previous full regressions, original 40 missions, corrupted save restore and original PCM. No hidden bypass of failing tests.
3. Run two independent push/PR CI flows, then real original Godot HTML/JS/WASM/PCK in Chromium with WebGL2 source SHA, direct E/V/W/S/Tab input, desktop + mobile-sized views.
4. Fail closed on differences; no SSH to published `/games/city-reign/` until verified build, product signoff and isolated atomic release. Keep R169 rollback source and do not overwrite any other route.
5. Track the user-facing impact with actual tester evidence and measured hardware performance; distinguish source completion, CI pass, browser proof and public deployment.
6. Document exactly what remains unmeasured or missing. Rollbacks/failed production cleanup require a documented and source-verified maintenance response.

**Immediate critical path:** Finish R171 coach → build real interactive first-loop acceptance R172 → conduct human first-session tests → improve real car/traffic → author distinctive district art → harden campaign/save → run hardware benchmark/beta → carefully release v1.0.
