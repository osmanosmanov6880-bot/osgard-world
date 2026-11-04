# NEBULA R44 — owner-directed exact-binary release record

**Date:** 2026-11-04. **Status:** DEPLOYED; isolated SSH activation and independent public HTTPS exact-byte identity both verified on 2026-11-04. **Physical-device QA:** NOT PERFORMED.

## Source changes included

- Real NX-08 glTF mesh reused from the actual Godot game in isolated `SubViewport/World3D`, with 3D dock, service ring, lighting and a controllable orbit camera.
- Responsive Russian garage for wide/portrait/small screen and actual source-linked commander, equipped ship and mission briefings.
- 44+px turn controls, mouse drag and screen drag for actual 3D model orbit, distinct from unlocked live flight.
- Flight physics, mission progression and existing payments/entitlements are unchanged.
- All currently purchasable R15 loadout variants still use a common actual NX base mesh; separate designed models for NX-12/NX-21 not claimed.

## Approved source and export

- Feature/source PR: [#728](https://github.com/osmanosmanov6880-bot/osgard-world/pull/728).
- Source merge commit: `8141e2673ad22bf1de18bd2ecae26eabf71f83fb`.
- Mandatory Godot source compile, runtime smoke, Chromium **actual WebAssembly flight** and mobile touch emulation: [#41856828041](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41856828041). Hosted SwiftShader screenshot is advisory only; does not establish physical device fidelity.
- Master export workflow: [#41858815024](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41858815024), SUCCESS.
- Exact generated master Web export commit: `f271ef0249fd0fe1d61871e05d17315b54f1d13f`.

### Immutable Git blob SHA-1 hashes (not plain-byte SHA-1)

| File | Git blob SHA-1 | Observed source size |
|---|---|---:|
| `index.html` | `014a832779b265ac184fa691d803f28d594d5fdb` | 13,995 B |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` | 279,815 B |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` | 39,514,754 B |
| `index.pck` | `dd107191b25b38b508640749123cbaf309536d9a` | 5,811,732 B |

## Owner-directed risk acceptance and safeguards

The owner explicitly requested continued direct game improvements and publication. The release is explicitly labeled `R44_OWNER_DIRECTED_OVERRIDE` and must not be confused with separate `R40_HARDWARE_QA_APPROVED` (which still has strict human/phone evidence requirements).

R44 risk record: `physical_device_qa=NOT_PERFORMED`, `hardware_qa_certified=false`. The 3D model is automated-runtime tested, **not** visually accepted on an actual Android/iPhone. Paid user entitlements, real money and local save-v1 schema are unchanged.

## Rollout and evidence checklist

- [x] PR asset guard and negative tests passed — #41859309208.
- [x] Production release completed — #41859410528, hardened SSH/rollback/Nginx checks passed.
- [x] Independent public HTTPS download performed — #41859512556.
- [x] All four approved Git blob hashes matched; `NEBULA_PUBLIC_RELEASE_PARITY_PASS variant=R44 actual_hardware_qa=NOT_PERFORMED`.
- [ ] Physical Android/iPhone visual, FPS and complete playthrough — NOT PERFORMED (remains outstanding).

### Rollback

A failed production hash check, SSH disconnect or route check must preserve the last functioning R43. Never use partial file uploads as proof of a successful release. The GitHub PR merge is only source approval, not public activation.

**Full implementation details:** [R44-REAL-3D-HANGAR-IMPLEMENTATION.md](R44-REAL-3D-HANGAR-IMPLEMENTATION.md).

## Verified actual deployment (2026-11-04)

- Production allowlist PR [#729](https://github.com/osmanosmanov6880-bot/osgard-world/pull/729) merged at `617efcda758aa2810057ac150b52616a3ac44068`.
- Isolated deployment workflow [#41859410528](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41859410528): **SUCCESS**, including R44 asset identity and rollback-safe SSH activation.
- A push-triggered parity check [#41859410369](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41859410369) ran *before the SSH deployment completed*. It saw the previous R43 public files and failed as it should. This was a race in the monitoring schedule, **not** proof that R44 deployed unsuccessfully.
- Post-deployment [public HTTPS exact-byte parity #41859512556](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41859512556): **SUCCESS**.
  - `index.html` 13,995 bytes — `014a832779b265ac184fa691d803f28d594d5fdb`
  - `index.js` 279,815 bytes — `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39`
  - `index.wasm` 39,514,754 bytes — `8f900d00d644a698bbce67439bf6daf73bdfa4b7`
  - `index.pck` 5,811,732 bytes — `dd107191b25b38b508640749123cbaf309536d9a`
- Result: `NEBULA_PUBLIC_RELEASE_PARITY_PASS variant=R44 actual_hardware_qa=NOT_PERFORMED`.

This proves exact release bytes are served publicly. It is **not** proof of correct appearance on an actual iPhone/Android GPU or sustained mobile FPS. Unique silhouettes for NX-12/NX-21 and acts III–V also remain incomplete.
