# NEBULA R56 — protected modular workbench production release

**Status:** candidate only. Latest-head six checks, trusted SSH deployment with rollback, and independent public HTTPS parity are required before announcing R56 live.

## Trusted origin and exact bytes

- Source PR [#758](https://github.com/osmanosmanov6880-bot/osgard-world/pull/758), latest-head **6/6 SUCCESS**, original head `2cc5c31636cb74ab509f9def62944d3feb32440d`.
- Accepted source merge `6b4e44146ebf98e0f82ee3dea85d65bb04200625`.
- Official Godot 4.7.2 native release [run #42138745704](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42138745704) **SUCCESS**.
- Trusted Web export commit `5c3596f3379fb1710d5d862f48a7ca50c5623246`, direct sole parent = accepted source merge.

| Existing asset | Exact bytes | Git blob SHA-1 |
|---|---:|---|
| `index.html` | 13,995 | `06af36b0a154163b74fcfd48446931af498971c0` |
| `index.js` | 279,815 | `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39` |
| `index.wasm` | 39,514,754 | `8f900d00d644a698bbce67439bf6daf73bdfa4b7` |
| `index.pck` | 6,317,352 | `ce9a499468b8b920d451979ca29d1ed8349819ef` |

These are **Git blob SHA-1** digests, not raw-file SHA-1, and not mutable approval labels. Release PR never alters browser binaries.

## In-scope features

Existing R54 Aurora industrial 3D garage and R55 unique 3D NX-08/NX-12/NX-21 hulls. New R56 «МОДУЛИ»: priced armor, shield and radar ranks for each independently owned ship; real hull/shield max stats and radar meter range; visible purchased armor plates, shield emitters and radar antennas in the 3D dock and real flight. Existing paid engine, weapon and captain academy preserved. Same 14-story-mission campaign. **R57 contracts and R53 mission 15 are NOT in this release.**

## Trust boundaries

Last independently confirmed public release is R55 [HTTPS 4/4 run #42139241911](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42139241911), kept as rollback until R56 exact 4/4 public verification passes.

**Physical Android/iPhone NOT_PERFORMED**. Local user:// CR economy is not hardened server-side currency. Real mobile GPU FPS, thermals and multi-hour stability not verified. Never silently claim production, true phone testing or real-money payments from CI alone.
