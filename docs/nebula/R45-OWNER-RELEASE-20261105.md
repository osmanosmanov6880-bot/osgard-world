# NEBULA R45 — verified-source release record

**Date:** 2026-11-05. **Status:** release candidate, **not** production confirmation until independent public HTTPS parity passes.

## Source and mandatory verification
- Source feature PR [#731](https://github.com/osmanosmanov6880-bot/osgard-world/pull/731) merged at `c20a1bf9b1dbf372e5e3efc521ea9abbcfd511cc`.
- Source Godot run [#41914578026](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41914578026) passed **native GDScript parse**, runtime scene / save / purchase guard, Godot WebAssembly export, genuine Chromium pilot movement and emulated mobile touchscreen gates. The optional SwiftShader pixel-capture stage was not completed at the point of merge; do not claim physical GPU acceptance.
- Initial R45 mobile test failed because CDP touchEnd was repeated without an active touch. The test harness now tracks active fingers and skips redundant release; the gameplay physics and purchase logic were not bypassed.
- Source contains three distinct, real procedural airframe conversion kits on the shared imported NX-08 model. This is not equivalent to three independent artist-made AAA GLTFs.

## Production release requirements
- [ ] Fresh trusted master Godot export completed successfully: [master run #41915702181](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41915702181).
- [ ] Record Git commit SHA of exact exported Web assets and source commit separately.
- [ ] Pin Git blob hashes for `index.html`, `index.js`, `index.wasm`, `index.pck` in `.github/nebula-production-allowlist.json` on release branch.
- [ ] Pass strict negative tests that prevent fake hardware QA claims.
- [ ] Merge release PR only after confirmation, invoking isolated SSH rollout with rollback.
- [ ] Verify 4/4 public HTTPS assets match exact approved hashes; **do not** equate server HTTP health with actual gameplay.
- [ ] Real Android and iPhone physical-device QA **NOT PERFORMED**.

## Guardrails
- Current publicly verified R44 remains the rollback target until successful R45 deployment.
- R46 comparison PR #732 must remain a separate release; don't mix unapproved R46 source changes into this R45 artifact.
- No change to server-paid entitlement validation, prices, or save schema v1.
