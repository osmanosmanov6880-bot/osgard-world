# NEBULA R47 — production release evidence

**Date:** 2026-11-05. **State:** RELEASE CANDIDATE — verified master export and exact hashes pinned; public R46 remains live until isolated SSH deploy and independent HTTPS parity PASS.

## Planned release scope

- Two real 3D wingman pads and occupied escort/ace craft in the isolated Aurora hangar;
- ownership-gated equip/detach connected to the live R15 fleet (credits or server-confirmed premium), existing save schema v1, two-slot limit;
- no ally firing from the protected garage; existing combat resumes on the actual sortie;
- a short in-flight chase-camera FOV sweep at launch, without suppressing touch input or physics.

## Source / build proof

- Source feature [PR #738](https://github.com/osmanosmanov6880-bot/osgard-world/pull/738) merged after mandatory Godot native scene/runtime, real WebAssembly Chromium flight, emulated mobile touchscreen, secure commerce gates in [#41919514769](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41919514769). Hosted SwiftShader visual check is advisory and does NOT certify physical hardware.
- Master source merge commit: `3102888ee9ed7e0e8997c55820b9ac74a87975aa`.
- Master Godot Web export [#41920850005](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41920850005) succeeded; exact Web export commit `5bb7948d770c1a7c784a1f3848020d916e10d101`.
- Four artifact identities from verified export are pinned below, **not** copied from R46.

## Release checklist

- [x] Source PR #738 merged after native Godot runtime, browser flight and mobile touch gates passed — #41919514769
- [x] Fresh master Web export generated, committed, and succeeded — #41920850005
- [x] Four real Git blob SHA-1 hashes pinned in the allowlist with precise source/export provenance and successful run ID
- [ ] R47 exact-binary negative guard tests passed on release PR
- [ ] R47 owner-directed override explicitly declares `physical_device_qa=NOT_PERFORMED` and `hardware_qa_certified=false`
- [ ] R40's independent real-hardware evidence rule unchanged
- [ ] Only isolated SSH deployment activates R47 with disk, lock, rollback and internal Nginx checks
- [ ] Independent public HTTPS 4/4 exact file hash parity confirms R47
- [ ] Real Android/iPhone performance, sustained FPS and visual acceptance not yet performed

## Rollback and boundaries

- Prior public R46 bytes remain the rollback baseline until a complete R47 check finishes.
- Neither a GitHub PR merge nor a server HTTP 200 proves the 3D flight is usable on a physical phone.
- The shared NX model and new procedural companion geometry are authentic Godot meshes, **not** a claim of AAA film-quality art or an animated hangar-door cutscene.

## Exact verified Web export (Git blob SHA-1, not raw SHA-1)

| File | Git blob identity | Bytes |
|---|---|---:|
| `index.html` | `f2ad1bb91c71412dd44fe38addcf5f848c951d13` | 13,995 |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` | 279,815 |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` | 39,514,754 |
| `index.pck` | `99f54fa47073b1ededeb93f5f822b7800a24af0d` | 5,873,932 |

**Do not mark public production success until the independent HTTPS four-byte identity check returns `NEBULA_PUBLIC_RELEASE_PARITY_PASS variant=R47`.**
