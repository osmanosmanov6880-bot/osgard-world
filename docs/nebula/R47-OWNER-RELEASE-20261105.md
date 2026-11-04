# NEBULA R47 — production release evidence

**Date:** 2026-11-05. **State:** DRAFT — no R47 deployment certified. The public verified release remains R46 until the steps below pass.

## Planned release scope

- Two real 3D wingman pads and occupied escort/ace craft in the isolated Aurora hangar;
- ownership-gated equip/detach connected to the live R15 fleet (credits or server-confirmed premium), existing save schema v1, two-slot limit;
- no ally firing from the protected garage; existing combat resumes on the actual sortie;
- a short in-flight chase-camera FOV sweep at launch, without suppressing touch input or physics.

## Source / build proof

- Source feature [PR #738](https://github.com/osmanosmanov6880-bot/osgard-world/pull/738). **Wait for mandatory Godot, real Chromium and emulated touchscreen CI to complete.**
- Master source merge commit: PENDING.
- Master export CI run and exact exported commit: PENDING.
- Artifact identities: PENDING — do not copy prior R46 hashes, especially `index.pck` and `index.html`.

## Release checklist

- [ ] Source PR #738 merged **only after** native Godot runtime, browser flight and mobile touch gates passed
- [ ] Fresh master Web export generated, committed, and succeeded
- [ ] Four real Git blob SHA-1 hashes pinned in the allowlist with precise source/export provenance and successful run ID
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
