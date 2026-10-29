# IRON PULSE WORLD / G4 — LOCAL DEVICE LAB + PHYSICAL-DEVICE RELEASE GATES

**Date:** 2026-10-29. **Source baseline:** verified G3.1 `dfedf825bee767a1fb66d16c5845db8d9def181a`; [exact-head G3.1 CI SUCCESS #40820592970](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40820592970). G4 is stacked on G3.1 and does not change any other project in the OSgard repository.

## What this is and is not

**Implemented in Godot, not an HTML mockup:** The local benchmark lab runs inside the actual Godot 4.4.1 first-person 3D game on Windows or WebGL. The operator explicitly starts it with **F9**, views it with **F8** or the 51px native mobile **LAB** button, and ends it with F9 or opening LAB. Opening LAB pauses the real game so its idle/menu frames are not mistaken for active gameplay. An explicit button exports a JSON report inside the game's `user://` filesystem and attempts a clipboard copy (permission-dependent).

**Not yet done:** No independent physical Windows/Android/iOS devices have been measured during this code-development pass. A headless Godot math test and SwiftShader Chromium emulation can verify implementation but CANNOT certify hardware FPS, battery use, touchscreen latency, mobile Safari support, controller mapping, thermal throttling, security, playability or production release.

## G4 / block A — honest frame timing

The player-initiated recording consumes real current-client `_process(delta)` values:
- P50/median, p95 and p99 main-loop frame times (ms), observed arithmetic mean and estimated FPS derived solely from that mean. This is a **main-loop delta proxy**, not a GPU profiling sensor or a per-device guarantee.
- >=50ms hitches and >=250ms active stalls are counted; false clean results cannot hide actual long active frames. Invalid negative/NaN/Infinity deltas and >2s background-tab interruptions are excluded **and separately counted**. Paused/intro frames do not enter the sample history.
- Sample buffer capped at 18,000 values. A single explicit session auto-stops at 600 active seconds. Downshift to ECO, resize, time interruption or truncated samples invalidate A/B comparability.
- Only a completed run with >=90 active seconds, >=1800 accepted frames, fixed quality and fixed viewport with no background interruption and no sample truncation can be flagged `comparable_local_run=true`. This means **internally comparable measurements**, not hardware attestation.
- No account, IP, GPU vendor, hardware UUID, device fingerprint, raw keystrokes, location or remote analytics is collected by the module. JSON export occurs only on an explicit player action. Web browser user:// and clipboard availability depend on host permissions.

## G4 / block B — genuine GUI + gameplay isolation

- `scripts/IPDeviceLab.gd` owns bounded samples, percentile math, finish/export and separate privacy flags. `scripts/Main.gd` adds real native controls and a bilingual, pause-aware report. F8 opens/closes LAB; F9 starts/stops. A real mobile LAB button occupies a separate 51px touch target.
- LAB does not call `IPCrisisEngine`, invent game successes, change story/health or save diagnostic metrics in the existing `IRON_PULSE_CAMPAIGN_V6` checkpoint; G1 help, G2 stations and G3 materials remain unchanged.
- Manual G profile and adaptive K profile continue to work. Any change during a recording is documented in `quality_changed` and the run becomes incomparable.
- The public portal section documents actual features and limitations in RU/EN with no invented performance figures or screenshots.

## G4 / block C — engineering gates

- `tests/test_g4_local_device_lab.gd`: deterministic **synthetic unit-test deltas** used ONLY to prove percentile math and limits, not sold as device measurements. The test asserts: opt-in, >50ms/250ms hitches, actual active seconds, clean/incomparable run logic, interruptions, capped memory, max ten minutes, zero remote uploads or fingerprint fields, native F8/F9/touch UI, real local JSON, no engine/save changes.
- Existing V1–V18/G1/G2/G3 and engine+scene regression checks remain mandatory.
- Real Playwright Chromium/SwiftShader WebGL checks: F9 captures *actual* running browser frames; F9 finishes, LAB opens as genuine native UI; ESC and mobile LAB touch restore the real game. Short simulated-browser sessions are explicitly marked NOT hardware-certified and NOT comparable.
- Windows/WebGL exports and their SHA-256 manifest, RU/EN portal 320/390px, original real gameplay and exact-head CI are required.

## Procedure for human hardware validation after coding (NOT EXECUTED)

A release engineer must record the exact source SHA, build SHA, device OS/browser/graphics profile (coarse hand-entered testing notes), temperature/power conditions and run logs. Do not add device identifiers to automated application logs. Use identical fixed viewport and fixed HERO or ECO profile; turn K/AUTO off. Warm up for 3 minutes, then collect one clean **90–300-second** local report for each of GRID, HEAT, AIR with actual navigation and interactions, and test mission restart/restore/3D camera in both quality modes. Independently perform a **30-minute soak session** while collecting successive <=10-minute reports for thermal/graphics trends, crash-free startup and state integrity. Any interruption, app backgrounding or quality change requires a fresh comparison run.

Minimum real test matrix, with two independent runs per row:
| Client | Required real hardware checks | Open questions |
|---|---|---|
| Windows 10/11, integrated GPU | HERO/ECO gameplay; sustained 30-minute soak; native file export | GPU frame pacing, input, thermals |
| Windows 10/11, discrete GPU | Full campaign, real gamepad, audio/3D lights | PC performance and controller mapping |
| Android/Chrome, midrange physical handset | True 51px LAB, GUIDE, NAV, USE; portrait/landscape; browser recovery | Touch occlusion, thermal throttle, stable WebGL |
| Android/Chrome, low-end physical handset | ECO and device memory constraints, reload recovery | Memory pressure and p95 in real hardware |
| iPhone/Safari (if browser build is supported) | Startup, touch, background/resume, input/clipboard | Safari/WebGL capability, storage/permissions |

Provisional **engineering targets for review, not claims**: desktop 60fps experience aims at p95 <=16.7ms where appropriate; ECO low-end aims p95 <=33.3ms at 30fps. Treat targets as hypotheses, not a claim of achievement or a universal device minimum. The live frame monitor cannot verify GPU frame times, so independent GPU/OS counters and human observations are necessary.

## G4 status and next gates

A future green CI establishes **software/test acceptance**, never physical-device acceptance. Release G5/G6 should add manual signoff, accessibility/rights/compliance, offline data/restore drills, consented user feedback and staging rollback; G7 requires 20 genuine players completing a three-act study, with observed outcomes, not simulated user counts. No unauthorized release, merge to `master` or deployment is implied.
