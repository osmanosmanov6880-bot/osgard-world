# NEBULA R48 — owner-directed release evidence

**Date:** 2026-11-05. **State:** R48 verified source/export and pinned assets; **NOT PUBLICLY CONFIRMED** until rollback-safe SSH activation plus 4/4 independent public HTTPS parity succeed. Verified public rollback: R47.

## Precisely implemented

This update changes three playable missions in the EXISTING ten-mission Godot campaign, preserving mission numbering, progression, v1 saves, existing CR/XP rewards and premium authorization:
- **02 «Неоновый квартал»** now requires proximity and timed hold to pick up civilians, then a physically separate safe-zone delivery/hold. No advance at the old single reach point.
- **05 «Разлом»** now requires three distinct real mesh probes, visited in sequence with timed proximity holds. HUD/nav/radar follows the next active objective; no premature reward.
- **08 «Похищенный конвой»** now uses a moving real Godot 3D convoy with 200 HP; pilots must stay within the escort perimeter so it advances. Three actual attack drones spawn as it starts moving and target/damage it. Destroyed convoy returns to the garage as a failed sortie with **zero CR/XP reward**; success requires arrival with HP remaining.

The convoy is scripted Node3D movement with enemy laser/contact damage, not a full rigid-body urban collision simulation. The 20 later chapters in the AAA game bible remain plans.

## Verified source and export

- [R48 source PR #742](https://github.com/osmanosmanov6880-bot/osgard-world/pull/742) merged at `4404add12bae0c82e104d2d4bce8d4960bcf75df`.
- [R48 required Godot/native + actual browser flight + emulated mobile touch #41923987577](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41923987577): mandatory gates PASSED. Source initial runtime test failed on a test-loop post-success state; corrected before approval. Hosted SwiftShader pixel-capture is advisory and cannot stand in for actual phone/GPU testing.
- [Trusted master Godot export #41924907118](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41924907118): SUCCESS, export source commit `708a0dce4624890e42bf10a44028dbf5ca377ab0`.

## Exact R48 files (Git blob SHA-1, not raw SHA-1)

| File | Git blob SHA-1 | Bytes |
|---|---|---:|
| `index.html` | `f173fab08d1147e3cde720ac560dcdfe412e5acc` | 13,995 |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` | 279,815 |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` | 39,514,754 |
| `index.pck` | `a5dff5ca5e14fa09e525219e3c5db60ce70d76d2` | 5,916,024 |

## Release gates

- [ ] Exact-binary production guard synthetic negative tests for R48 all successful
- [ ] Merge owner release PR, then only existing isolated SSH pipeline performs activation with disk/lock/rollback/Nginx verification
- [ ] Independent public HTTPS check downloads 4/4 files and matches **the exact SHA values above** with R48 approval status
- [ ] Update implementation/GAME BIBLE statuses after public parity success
- [ ] Physical Android/iPhone FPS, touch endurance and visual sign-off: **NOT PERFORMED**

Owner override is explicitly `R48_OWNER_DIRECTED_OVERRIDE`, with `physical_device_qa=NOT_PERFORMED`, `hardware_qa_certified=false`. R40's separate signed hardware attestation path remains unchanged. This is an exception for owner-directed publication of R48—not a fabricated real-device QA certificate.

Before the 4/4 public check passes, do not claim R48 is live even if SSH or HTTP 200 succeeded.
