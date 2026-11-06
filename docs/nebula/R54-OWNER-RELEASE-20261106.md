# NEBULA R54 — protected exact-byte production release

**Status:** release candidate only. Source merged and trusted export complete; production still requires merge → SSH rollback-safe activation → independent public HTTPS 4/4.

## Evidence

- Source PR #755 all **6/6 checks passed** on `7f6dd200c924c422b6e2db24690d263de1c320d3`, merged as `baf64cf87e3c6af61c25c30cf2dc90f8d8306c4a`.
- Godot 4.7.2 trusted export run [#42134411859](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42134411859) SUCCESS, commit `24b162aca6af7afa5b2da10e854b3a171efae0e2` directly descended from that merge (sole parent).
- `index.html` 13,995 B Git blob `ee6804a81ac646b6462f43b1e2d4334ca7650179`
- `index.js` 279,815 B Git blob `c84b7de50f26f0dd21bd4b2885de851a3ea6ff39`
- `index.wasm` 39,514,754 B Git blob `8f900d00d644a698bbce67439bf6daf73bdfa4b7`
- `index.pck` 6,215,596 B Git blob `3c51bb39082f40d7be53b3d97a91c326e2e9b654`

Exact Git blob SHA-1 hashes, not raw-file SHA-1. No binaries are changed in the release PR.

## Scope

R54 releases physical enclosed Aurora hangar, 1:1 responsive Godot 3D view, desktop shadows with touch quality tier, fixed visible CR/XP and store, user-facing fleet/pilot/mission tabs, docked credit upgrades, safe rank 0–3 Ada/Kai/Leya academy (650/1100/1800 CR) affecting flight and legitimate mission rewards. Existing R52 fourteen-mission story is retained. R53 mission 15 and R55 unique airframes are NOT included or approved.

## Safety and rollback

Last independently confirmed public build: R52, [HTTPS 4/4 run #42132943973](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/42132943973). Keep it rollback until independent R54 HTTPS 4/4 passes. Do not bypass latest-head checks, branch protection or source provenance. R40 physical-device attestation remains unchanged.

**Real Android/iPhone, real GPU/FPS, heat and prolonged device QA: NOT_PERFORMED.** hardware_qa_certified=false. Desktop Chromium and emulated touchscreen successful CI are not hardware certification.
