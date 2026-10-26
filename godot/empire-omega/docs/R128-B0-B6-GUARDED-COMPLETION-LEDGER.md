# EMPIRE Ω — R128 executable acceptance and completion ledger

**Repository scope:** ONLY `osmanosmanov6880-bot/osgard-world`, actual Godot 4.4.1 EMPIRE Ω project. No new concept images. This record distinguishes successful code tests from physical/human/artistic proof. **PRODUCTION HOLD.**

## Immutable source state observed 2026-10-26

- Unpublished R90 via [draft PR #500](https://github.com/osmanosmanov6880-bot/osgard-world/pull/500): merged R127 source `64d2c6618211a0ea81c655e90c8cbaaec0198e8d`. [R127 integration #553](https://github.com/osmanosmanov6880-bot/osgard-world/pull/553) MERGED into R90 **NOT master**.
- R90 merged-source [R109 exact Godot/native, Chromium and provenance run #40364442882](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40364442882): native, real Chromium and source provenance 3/3 SUCCESS on that merged SHA. Any R128 HEAD or further R90 merge REQUIRES its own independent full check.
- Public original R87 `source_commit=43ae041e8df52418ca74c02405de9c196b59bd37` in `master/public/games/omega-3d-preview/release.json` remains untouched. `master` may advance for other repository components independently; **master SHA, R90 HEAD, native source_commit and SSH frontend SHA are not interchangeable**.
- R87 original seven files including `index.pck` SHA-256 `c34d9b717b024bcec43239032d259229181568284186482ecfcd0f28e580fd4e` and `index.wasm` SHA-256 `e4a43dbae28662b2a68f6136857a94db6695430901515800b9883f6327cb7116` remain pinned in a read-only B6 utility.

## B0–B6 implementation / acceptance (do not collapse distinct scopes)

| Block | Implemented | Independent signoff / blocker |
|---|---|---|
| B0 source and build | R90 original Godot WebGL, exact source SHA, 37 original Godot suites + 4 Chromium and CC0 provenance. Previous merged R127 source fully passed | **DONE on R127 SHA**; R128 current HEAD initially unverified |
| B1 traffic city | 12 closed 3D native AI cars + pedestrians, real road interaction and original 3D physics | **ENGINEERING DONE on R127 SHA**, exterior/AAA art still HOLD |
| B2 original urban world | 24 source-modeled, physically shaded native roadside structures in real WorldBuilder; original R119 window hierarchy preserved; [native 899/899 proof #40353014737](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40353014737) | **SOURCE DONE / ART HOLD**. Real Chromium imagery shows repetitive facades, stylized vegetation, weaker street detail vs both approved references |
| B3 functional premium HUD | R128 real `hud.gd` preserves scrolling city council after authoritative economic refresh and minimum 46px real phone/keyboard tabs. New `v102_r128_accessible_cabinet_refresh.gd` checks 320×568, 390×844, 844×390 and 1366×768 plus original live 3D atlas | **CODE STAGED / CI PENDING**. Physical contrast, English/Chinese readability, original-reference visual comparison remain HUMAN HOLD |
| B4 player journey/save | Original [R127 native engine 21/21](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40353014756) drives physical Godot vehicle for 75 frames, E entry, authentic car position and GameState disk save/reload, with 12 traffic agents and 34 NPC | **ENGINE TEST DONE / HUMAN HOLD**: 3 unfamiliar players independently complete 15–20min, 40 missions actually navigated and save/reload verified; source suite is not human evidence |
| B5 physical performance | Expanded original `omega-r127-physical-device-gate.py`: **36 independent source-matched recording packets** (desktop + Android + physical iPhone × 4 scenarios × 3 repeats), video SHA, real Godot p50/p95/p99, no Mesa/SwiftShader/software GPU; explicit hardware model and observed two-touch. CI `--self-test` tests gate code only | **NO HARDWARE CLAIM. PERFORMANCE HOLD**. Real desktop GPU, Android device, iPhone runs with video, actual measured 95th and 99th percentiles missing |
| B6 source-preserving rollback | R128 read-only `omega-r128-r87-immutability.py` pins original exact R87 `source_commit` and seven SHA-256 claims; optionally verifies **actual** independently obtained seven files and WASM/PCK magic; independent workflow reads `master` R87 manifest only | **BASELINE GUARD CODE STAGED / PRODUCTION HOLD**. No genuine rollback rehearsal, signed art approval, physical FPS, full manual mission coverage or new production permission |

### B2/B3 original art review protocol — no generated stills

Use the **two already approved original user reference images**, unchanged. Preserve their original SHA hashes as the human review sources. Acquire **actual** rendered Godot at the same reference camera angle, day/night, 1440×900 desktop, 1920×1080 desktop, 390×844 mobile. For each of: architecture, street-level objects, car shape/shader, real NPC/trees, sunlight, shadow length, wet-road reflections, city aperture, dashboard contrast, number legibility, motion/video interactions:
1. Record a side-by-side discrepancy and directly link the original source file/PR change that corrected it. A nice screenshot is not a real UI click test.
2. Verify original assets' actual license/attribution (CC0 or explicit commercial license) and include source URL, original download hash, allowed redistributions and a human reviewer name.
3. Record **APPROVED or BLOCKED explicitly by human reviewer**. Do not mark AAA DONE from shader settings or synthetic reference imagery.

### B4 manual gameplay and persistence protocol

Three **real people** who did not implement the game should, independently, play 15–20 minutes from new game through walking, E entering vehicle, real traffic/crossings, city cabinet via Tab, one real action/transaction, mission objective, F5 save, browser/application reload, F9 load, continuing 3D driving. Attach raw screen recordings (SHA-256), participant-independent issue list and mission-state diffs with no duplicate rewards. Independently inspect each of 40 missions/chapters with gameplay evidence; **forty successful CI event assertions are not forty manual completions**. No completion claim absent independent actual play evidence.

### B5 reproducible physical-device packet acquisition

Use `scripts/omega-r127-physical-device-gate.py --packet <local/private.json> --expected-sha <exact_R90_candidate_40hex> --output <local/report.json>`. Record **36** unique complete runs from 3 original physical platforms. Each run must have one separately SHA-verified physical screen recording, operator-observed device model, GPU name/browser, original Godot R36 complete report and original source SHA.

Provisional acceptance targets: desktop p95≤16.7ms, p99≤33.3ms; Android/iPhone LOW p95≤33.3ms, p99≤50ms, actual two-finger operation. Measured thermal throttling, VRAM and cold-start load times go into the review narrative. **This script can validate evidence structure, not independently prove that video/operator/GPU are genuine; a separate real-person device witness is necessary.**

### B6 guarded manual rollback release plan — not permission

1. Store the exact current **master SHA** and R87 public `release.json` file contents before any candidate promotion; never use master SHA in place of game source SHA.
2. Download seven **actual** original public R87 binary bytes over HTTPS, recompute SHA for each, verify PCK/WASM magic. Manifest-only checks are not 7/7 live-byte proof.
3. Preserve original **Web binary and frontend/SSH SHA separately**; confirm the protected SSH action really changed active files (`deployed=true`), not green skipped/noop, and that no master push triggers accidental production.
4. Run an independent rollback in isolated staging with exact original seven binary bytes, record HTTP/Chromium E/W/A/two-touch results. This has **NOT happened**.
5. Only after B2 human art, B3 UX, B4 three human playthroughs and 40 mission acceptance, B5 physical desktop + Android + iPhone measurements, B6 isolated rollback can a separately authorized production change be considered. **PR #500 must remain DRAFT; do not merge into master or trigger SSH/VPS.**

## R128 CI contract

The original R109 workflow increases to **38 native Godot suites** while retaining all previous checks, **20 exact-source engine scripts**, the same three CC0 maps, all four original Chromium WebGL tests, and the three original executable/pixel/source artifacts on the exact R128 HEAD. The independent R128 native workflow verifies authored real HUD layout, R127 authentic drive/save, *read-only master R87 unchanged file-claim baseline*, plus device gate false-claim self-test. Both have **NO production steps**.

**Current stage:** R128 engineering candidate. Never label AAA DONE or RELEASE GO without missing independent human/hardware/rollback proofs.
