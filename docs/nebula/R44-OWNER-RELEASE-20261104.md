# NEBULA R44 — owner-directed exact-binary release record

**Date:** 2026-11-04. **Status:** RELEASE CANDIDATE; do not claim live until SSH workflow and independent public HTTPS exact-byte check succeed. **Physical-device QA:** NOT PERFORMED.

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

- [ ] PR asset guard and negative tests prove exact four-file identity; invalid/missing QA provenance rejected.
- [ ] Merged policy triggers isolated SSH deploy using host key checks, keepalive, release lock, staging space, rollback and Nginx health.
- [ ] Public route `https://osgard.world/games/remix/arena-v2/nebula-3d/` independently downloaded via GitHub-hosted HTTPS.
- [ ] Public hashes of all four assets exactly match this allowlist with `NEBULA_PUBLIC_RELEASE_PARITY_PASS variant=R44`.
- [ ] Physical Android/iPhone visual, FPS and complete playthrough — NOT PERFORMED (remains outstanding).

### Rollback

A failed production hash check, SSH disconnect or route check must preserve the last functioning R43. Never use partial file uploads as proof of a successful release. The GitHub PR merge is only source approval, not public activation.

**Full implementation details:** [R44-REAL-3D-HANGAR-IMPLEMENTATION.md](R44-REAL-3D-HANGAR-IMPLEMENTATION.md).
