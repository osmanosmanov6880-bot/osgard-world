# NEBULA R48 — owner-directed release evidence

**Date:** 2026-11-05. **State:** RELEASED AND PUBLICLY VERIFIED — R48 rollback-safe SSH activation #41925327744 PASSED and independent public HTTPS 4/4 byte parity #41925429274 PASSED. Real phone QA NOT PERFORMED; R47 remains verified rollback.

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

- [x] Exact-binary production guard synthetic negative tests for R48 all successful — #41925240692 and #41925327795
- [x] Release PR #744 merged; isolated SSH activated R48 with disk/lock/rollback/Nginx checks — #41925327744
- [x] Independent public HTTPS downloaded 4/4 files and matched **the exact SHA values above** with R48 approval — #41925429274
- [x] Publication status recorded here; implementation/GAME BIBLE updates recorded in separate documentation commits
- [ ] Physical Android/iPhone FPS, touch endurance and visual sign-off: **NOT PERFORMED**

Owner override is explicitly `R48_OWNER_DIRECTED_OVERRIDE`, with `physical_device_qa=NOT_PERFORMED`, `hardware_qa_certified=false`. R40's separate signed hardware attestation path remains unchanged. This is an exception for owner-directed publication of R48—not a fabricated real-device QA certificate.

Before the 4/4 public check passes, do not claim R48 is live even if SSH or HTTP 200 succeeded.

## Successful production evidence

- [Source PR #742](https://github.com/osmanosmanov6880-bot/osgard-world/pull/742) — implemented three mechanics and passed hard native/Chromium/mobile CI.
- [Exact release PR #744](https://github.com/osmanosmanov6880-bot/osgard-world/pull/744) — guarded, exact binary SHA pinned.
- [R48 isolated SSH activation #41925327744](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41925327744) — successful server activation and internal checks.
- [R48 independent public HTTPS verification #41925429274](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41925429274) — `NEBULA_PUBLIC_RELEASE_PARITY_PASS variant=R48 actual_hardware_qa=NOT_PERFORMED`.
- Actual public downloads: `index.html`, `index.js`, `index.wasm`, `index.pck` matched all **four** Git blob SHA-1 identities above. Their correct deployment does **not** constitute physical iPhone or Android acceptance, high-end frame-rate evidence, or proof that the 20 remaining story missions are implemented.
