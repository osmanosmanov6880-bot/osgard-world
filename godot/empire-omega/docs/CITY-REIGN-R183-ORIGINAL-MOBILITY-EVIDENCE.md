# CITY REIGN R183 — SOURCE-TRUTH 20-SECOND STREET LIFE OBSERVATORY

Parent: R182 original crosswalk guard and 384 physical road zebra slats \`3f510c885774bb798b094917d3d1a1f75493ab80\`; native Godot 4.4.1 full original regression PASS. R182 independent Chromium WebGL2 checks are release-gated separately.

## Why this real global-scale feature exists
The original Godot game already allows the player to press REAL 20S FRAME TEST and explicitly EXPORT JSON, with honest p50/p95/p99 frame times and draw calls from actual \`_process(delta)\`. There was no evidence describing **what real city gameplay was doing** while the frame numbers were measured. This prevents reproducible QA of mobile traffic vs idle scenes. R183 adds a complementary **real-time, strictly opt-in 2Hz report of source entities** to the exact same LAB session and export, without another busy UI overlay or background privacy telemetry.

## Source implementation
- \`city_reign_mobility_evidence.gd\` samples only original 12 \`TrafficAgent\` Node3Ds, 34 \`PedestrianAgent\` single original meshes and \`TrafficSignalGrid.elapsed\`. No new cars, no render meshes, no collisions, no cameras and no new physics. Metrics are aggregate actual stopped cars (the original speed threshold), real R182 crosswalk-yield occupancy, R180 live WALK/WAIT and walking velocity, original stop/wait durations, and genuine red/green/amber timing samples from R178. Payload records population min/max, 2Hz sample count and actual local active-simulation capture seconds. No individual positions, citizen IDs, device IDs, player names, raw routes, trajectories, cookies, screen captures or network calls.
- Bound to **existing opt-in benchmark** only: the user must explicitly press the existing 20S test to call \`begin\`. Sampling skips paused/modal gameplay, excludes non-finite deltas, stops after 20s and 40 samples, refuses a completed result for an invalid population, aborts when the browser is backgrounded, and stores NOTHING to the source game save. Only the EXISTING explicit EXPORT JSON button attaches \`"original_live_street_life"\` to the original FPS report; no second control, no new popover, no unrelated UI complexity.
- **No false hardware claims.** New \`hardware_attested:false\` even if original observed real frames are valid. A unit-test with synthetic frames demonstrates aggregation mathematics only and must NEVER be called an actual phone FPS measurement. The existing R36 frame benchmark still owns its separate render frame results.

## Engineering native tests
- \`v198\` deterministic aggregate mathematics for 12/34 original sample structures, 40 source samples / 20s, signal phase provenance, privacy, reset/background/pause/invalid guards.
- \`v199\` full native Godot \`main.tscn\`, exactly 12 physical NPC traffic cars, 34 real residents, real original source states and unchanged wallet/mission. Synthetic times check math, **NOT device FPS**.
- \`v200\` original opt-in 20S LAB start, UI/export, no raw identities or fake hardware attestations, correct combined JSON evidence shape.
- Full inherited R182–R169 natively compiled 40-mission Godot 4.4.1 suite, real exported WebGL2 and independent Chromium exact source SHA with authentic game input/camera QA.

**R183 is draft until exact immutable SHA passes 2/2 independent CI.** Production SSH game untouched. Device FPS on physical phones and actual human 5–10 minute playtests remain unverified.
