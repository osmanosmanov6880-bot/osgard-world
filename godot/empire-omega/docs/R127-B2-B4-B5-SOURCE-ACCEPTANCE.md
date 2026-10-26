# EMPIRE Ω — R127 B2/B4/B5: actual 3D art, playable save loop, performance gate

**Scope:** unpublished `feat/omega-r90-aaa-reference-first-slice-20261026` only. **No master merge, no R87 replacement, no VPS SSH.** This is engineering evidence, not a statement that the user-approved AURORA CITY reference images are matched.

## The review baseline (original genuine Godot pixels)

The starting R126 merged source `e15bcb5ad9958f800d064a5ab23b939b8af899d1` passed original exact-head staging CI [#40321821843](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40321821843) (native + 4 WebGL + provenance) and independent scene CI [#40321821931](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40321821931) (Godot native + Chromium). Original R126 screenshots: [real frame artifact #12647929918](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40320319735/artifacts/12647929918).

The actual inspected 960×540 desktop and 390×844 phone captures show a drivable road, live car and traffic, 3D pedestrian, architectural towers, and operable cabinet/F9 3D city atlas. **They also reveal clear mismatch with the two original AAA references:** heavily repetitive procedural street-scale assets, low-detail round trees, minimal curbstone furniture and small typography. R127 fixes one specific real-world source gap; it does not erase the remaining deficits.

## B2: actual volumetric street furniture in the living city

- New native `horizon_r127_street_shelters.gd`: 24 original 3D roof/column/glass/bench/transit-sign models, with bounded actual Godot vertex positions, per-face normals, vertex PBR colors, one cached `ArrayMesh` + one `MultiMesh`, fully lit by existing world lights. No downloaded stock assets, still images, new point lights or runtime material allocation.
- Actual R90 `horizon_r90_street_dressing.gd` instantiates the batch beneath the already-present native facade art grouping. **The original three R90 root nodes, two R91 facade/roof batches, 72 R90 towers, 144 roadside bollards, 12 real physical traffic agents, 34 pedestrians remain intact.** Nothing added to `CollisionObject3D`, navigation, physics world, source saves or economy.
- Every shelter is on the pedestrian side of a 10 m road, with a documented deterministic CPU transform. `LOW` excludes it, `STANDARD` and `CINEMATIC` render it. The new native Godot suite `v100_r127_original_street_art.gd` checks topology, normals, real world scale, shadow budget, street offset, PBR and zero state writes. Original older suites R90/R91/R116/R126 are **not weakened**.
- **Limit:** cosmetic non-colliding street furniture and procedural geometry are not licensed photogrammetry or final photoreal AAA. Further street intersection, skyline and architecture authoring remains B2 ART HOLD.

## B4: joined executable gameplay, not disconnected mock tests

- `v101_r127_live_drive_save_reload.gd` instantiates the actual shipped `res://scenes/main.tscn` only after the game's real autoloads exist.
- Uses in-game enter-vehicle interaction, **75 actual Godot physics frames of W input**, real speed and position, actual 12 AI vehicles / 34 NPC, original mission progression, Tab governance with the same live 3D city.
- Calls `main.gd::_save()` to write a real versioned disk snapshot with vehicle position, economy and campaign; mutates live economy+vehicle pose; calls `main.gd::_load()`; verifies actual primary-disk restore, car coordinates, mission and wallet, then restores the original caller's in-memory state. Uses PID-scoped disposable paths under `user://`; never edits a player's real save.
- Native test writes `godot/empire-omega/tests/r127-actual-drive-save-evidence.json` in CI. This is **short engine automation**, not independent human 15–20 min playthrough, not 3 uninstructed playtesters, not full mission playthrough certification.

## Full CI / SHA provenance

- Original `omega-r109-final-candidate-evidence.yml` now requires **37 full native source suites**, **20 original engine script files**, **3 SHA-pinned Poly Haven CC0 maps**, 4 genuine WebGL Chromium desktop/mobile/F9/host rAF scenarios, actual playable 7-file exported HTML/WASM/PCK, separate source/binary proof. The R121 exact checkout SHA guard remains active in *all* three jobs.
- Independent `omega-r127-street-b4-native-webgl-qa.yml` checks native urban/traffic/save suites and re-exports real Godot WebGL pixels on loopback. It checks exact HEAD, not GitHub's synthetic PR merge.
- Neither workflow has SSH, Pages publishing, git push to master or release automation. **At PR creation all new job statuses are unverified until final SUCCESS.**

## B5: evidence format for real desktop/Android (still HOLD)

The game already exports a 20-second original `empire-omega-real-frames-r36-v1` JSON using actual `Node._process(delta)` with p50/p95/p99 and draw calls. The new offline `scripts/omega-r127-physical-device-gate.py` validates *operator-acquired original device recordings*, 3 runs × 4 scenarios (city drive, live cabinet, night/rain, save/load) × desktop + Android, each with SHA-256 video, exact source SHA, model, GPU renderer, browser, real original Godot frame JSON and explicit operator observation. Desktop p95 ≤16.7 ms; Android LOW p95 ≤33.3 ms and physical two-finger controls observed. It rejects Mesa llvmpipe/SwiftShader, synthetic host rAF, partial samples, missing runs, mismatched file SHA and wrong source.

Example local usage **only after collecting physical recordings/reports**:

```sh
python3 scripts/omega-r127-physical-device-gate.py --packet private/device-run-packet.json --expected-sha FULL40CHARCOMMIT --output private/evidence-evaluation.json
```

The file format is `omega-r127-physical-run-packet-v1` with `operator`, `original_source_sha`, and `records`. Every record has `device_class`, `scenario`, `iteration`, `model`, `browser`, `gpu_renderer`, `operator_observed_device`, `original_source_sha`, `video_file`, `video_sha256`, `game_report`, and `two_finger_controls_observed` for Android.

**No real hardware was connected to this GitHub CI.** Even a structurally passing report is not independent proof that a real GPU/device was used. No automated script gives production authorization or artistic signoff.

## B6: independent final release HOLD

Master's original R87 manifest is the rollback baseline: `source_commit=43ae041e8df52418ca74c02405de9c196b59bd37`; WASM SHA-256 `e4a43dbae28662b2a68f6136857a94db6695430901515800b9883f6327cb7116`; PCK SHA-256 `c34d9b717b024bcec43239032d259229181568284186482ecfcd0f28e580fd4e`.

**Never merge main draft PR #500 into master.** A source change there can invoke `omega-godot-web.yml` automatic export and downstream VPS SSH publish, even if a PR author didn't request deploy. Stage candidate only after exact postmerge R90 native+WebGL/source proof, *visual comparison against both user reference pictures*, actual human 15–20 min playthrough / 40 missions, real hardware tests and separately approved rollback-guarded process. Until then: **PRODUCTION HOLD, AAA ART HOLD**.

