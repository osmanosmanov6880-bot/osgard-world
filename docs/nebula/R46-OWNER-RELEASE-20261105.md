# NEBULA R46 — exact-binary production release record

**Date:** 2026-11-05 · **State:** release candidate until SSH activation and independent public HTTPS parity succeed. **Real mobile device QA:** NOT PERFORMED.

## Verified engineering scope

R46 adds a low-cognitive-load optional comparison of the actual ships and a succinct live loadout panel in the Aurora 3D garage. The comparison uses the **same R15 gameplay profile source** for hull HP, shield HP and turning speed, not fabricated marketing stats. Shows owned/locked ships, actual current weapon damage, rockets, engine rank and occupied wingman slots. The comparison button is hidden by default and never spends CR, changes Stripe rights or launches a mission.

## Source and trusted build

- [Source PR #732](https://github.com/osmanosmanov6880-bot/osgard-world/pull/732), merged source SHA `5968de331a1b9d057a57a6856460540a983a016d`.
- [Mandatory source CI #41915003756](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41915003756): Godot scene parsing, native smoke, WebAssembly export, real Chromium flight and emulated mobile touch gates all succeeded. Hosted SwiftShader GPU capture is advisory and **not actual GPU certification**.
- [Verified master Godot Web export #41916829357](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/41916829357), export commit `fdff484974369fb821e84f9021ea21f85d21a833`.

## Exact R46 four-file Git blob identities (not raw SHA-1)

| File | Git blob SHA-1 | Bytes |
|---|---|---:|
| `index.html` | `fe1ae0f80781a32083f96b38d1e70ff066f4e6d3` | 13,995 |
| `index.js` | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` | 279,815 |
| `index.wasm` | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` | 39,514,754 |
| `index.pck` | `0fe54d9d68bc5b1e781fc03503ea27bab509299a` | 5,848,344 |

## Owner release policy

The user repeatedly requested direct NEBULA production delivery. This policy retains `R46_OWNER_DIRECTED_OVERRIDE` with explicit `physical_device_qa=NOT_PERFORMED`, `hardware_qa_certified=false` and source/build provenance. R40's separate hardware evidence approval remains unchanged; approval for R46 is **not an R40 hardware certification**. Last independently verified public version R45 is the rollback baseline.

## Release checklist

- [ ] R46 guard synthetic negative tests + exact local four-binary guard green
- [ ] Release PR merged after CI, not a manual insecure file swap
- [ ] Isolated SSH activation with disk quota, lock, rollback and internal Nginx checks
- [ ] Independent public HTTPS parity of four 4/4 exact file hashes against updated allowlist
- [ ] Update this document with actual successful run URLs and failed attempts
- [ ] Physical Android/iPhone FPS + owner visual acceptance (not performed)

**Do not call the release deployed based only on source PR, verified master export or HTTP 200.**
