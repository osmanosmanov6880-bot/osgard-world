# NEBULA R43 — release evidence and rollback record

**Date:** 2026-11-04. **State:** RELEASE CANDIDATE — not a deployment certificate until the isolated production workflow and public HTTPS byte-parity check complete.

## Scope

The real Godot R43 gameplay brings a failure/retry loop on top of R42 commanders:
- hull destruction fails the active sortie and returns to the secure Aurora garage;
- repairs the ship before retry, no hidden 220-CR penalty or mission reward;
- mission enemies and pending kill bounty are cleared, while ambient city traffic remains;
- explicit Russian failure briefing; preserved local v1 save and existing purchases;
- fresh 7-second incoming enemy-fire grace period after a real garage launch, including a retry;
- emulated mobile browser tests detect a *real* defeat and use the actual Godot sortie button instead of simulating unlocked flight.

## Immutable source and build evidence

- Source PR: https://github.com/osmanosmanov6880-bot/osgard-world/pull/723
- Native/source merge commit: `55efdad0e8661ad9ea9c6f0ba3bb4d02c85d0baf`
- Native master Godot 4.7.2 source parse, runtime smoke, WebAssembly export: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41851169153
- Exact exported master commit: `f87747b31f3f4fe9ad7cf030a5449d22015f3425`
- PR #723 browser WebAssembly and touch-emulated mobile hard gates: https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41849503005
- Hosted SwiftShader pixel readback is advisory. **No real phone or GPU acceptance** is claimed.

## File hashes — Git blob SHA-1, not ordinary raw SHA-1

| File | Approved Git blob identity |
|---|---|
| `index.html` | `e2e9eda43de697d2229616fdea49d864c112f7b4` |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` |
| `index.pck` | `99dc9c81b71734c3531ad08a9fb00b99cea1a9a0` |

## Owner-directed risk acceptance

The repository owner repeatedly requested direct publishing in the current NEBULA workflow. The release policy explicitly records `R43_OWNER_DIRECTED_OVERRIDE`, `physical_device_qa=NOT_PERFORMED`, and `hardware_qa_certified=false`. This is **not** a certification of the separate R40 approved physical-device source; R40's strict evidence rules are preserved.

## Activation checklist

- [ ] PR validates exact release metadata/negative tests.
- [ ] PR merges only with correct four-byte identities from the verified source export.
- [ ] Isolated SSH deploy verifies R43 hashes, staging disk space, rollback and internal Nginx health.
- [ ] Public `https://osgard.world/games/remix/arena-v2/nebula-3d/` returns all four exact approved Git blob hashes.
- [ ] Actual Android/iPhone device QA **not performed** (future independent acceptance).

**Rollback:** Previous R42 allowlist and last healthy on-server release remain the rollback baseline; no unverified R43 files should be activated on any hash, disk or HTTP check failure.
