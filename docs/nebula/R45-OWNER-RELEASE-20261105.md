# NEBULA R45 — verified-source release record

**Date:** 2026-11-05. **Status:** RELEASED AND PUBLICLY VERIFIED — isolated SSH activation #41916128495 and public 4/4 HTTPS byte parity #41916624645 succeeded. Physical-device QA remains NOT PERFORMED.

## Source and mandatory verification
- Source feature PR [#731](https://github.com/osmanosmanov6880-bot/osgard-world/pull/731) merged at `c20a1bf9b1dbf372e5e3efc521ea9abbcfd511cc`.
- Source Godot run [#41914578026](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41914578026) passed **native GDScript parse**, runtime scene / save / purchase guard, Godot WebAssembly export, genuine Chromium pilot movement and emulated mobile touchscreen gates. The optional SwiftShader pixel-capture stage was not completed at the point of merge; do not claim physical GPU acceptance.
- Initial R45 mobile test failed because CDP touchEnd was repeated without an active touch. The test harness now tracks active fingers and skips redundant release; the gameplay physics and purchase logic were not bypassed.
- Source contains three distinct, real procedural airframe conversion kits on the shared imported NX-08 model. This is not equivalent to three independent artist-made AAA GLTFs.

## Production release requirements
- [x] Fresh trusted master Godot export completed successfully: [master run #41915702181](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41915702181).
- [x] Git commit SHA: source `c20a1bf9b1dbf372e5e3efc521ea9abbcfd511cc`; exported assets `80f77f155ed60aa7f6bea151f9670307e8f7af5e`.
- [x] Pin exact four Git blob hashes in `.github/nebula-production-allowlist.json`; must still pass the independent production guard.
- [ ] Pass strict negative tests that prevent fake hardware QA claims.
- [x] Release PR #733 merged; isolated SSH rollout #41916128495 completed with rollback and Nginx health checks.
- [x] Public 4/4 HTTPS file hashes verified in #41916624645. The first public check #41916251523 failed due an outdated version-enum before hashing; fixed in PRs #734/#735.
- [ ] Real Android and iPhone physical-device QA **NOT PERFORMED**.

## Guardrails
- Current publicly verified R44 remains the rollback target until successful R45 deployment.
- R46 comparison PR #732 must remain a separate release; don't mix unapproved R46 source changes into this R45 artifact.
- No change to server-paid entitlement validation, prices, or save schema v1.

## Exact Web asset identities (Git blob SHA-1, not raw SHA-1)

| File | Git blob SHA | Bytes |
|---|---|---:|
| `index.html` | `7ebc26989d570e7197810ebe87e06f05c6198574` | 13,995 |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` | 279,815 |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` | 39,514,754 |
| `index.pck` | `002028a43ab1a3ae96e1d4376dea49d8027122a1` | 5,837,288 |

**Important:** This record proves exact generated files and source CI only. Until the SSH deployment and public HTTPS checks pass, R44 remains the publicly confirmed release.

## Final public evidence

- [Release policy PR #733](https://github.com/osmanosmanov6880-bot/osgard-world/pull/733) — exact SHA assets + owner-directed no-hardware-QA override
- [Production SSH deployment #41916128495](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41916128495) — success
- [Independent public HTTPS check #41916624645](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41916624645) — success, `NEBULA_PUBLIC_RELEASE_PARITY_PASS variant=R45 actual_hardware_qa=NOT_PERFORMED`
- **Not evidenced:** physical iPhone/Android frame rate, visual GPU approval by owner or full thirty-mission narrative.
