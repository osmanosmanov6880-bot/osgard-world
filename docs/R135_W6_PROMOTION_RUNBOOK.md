# R135 W6.4 — controlled release / rollback runbook

**Candidate source:** `947b4627080636543ae5e873b88b50e61f13beb4`
**Browser+Godot+Nginx run:** [40109700192](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40109700192) — success.
**Pinned artifact ID:** `12565818008`
**Immutable manifest SHA-256:** `0638f1ad5c0ab26d2d112e63bd1759923e5401a85ad4f2cedd450bbb7def2f61`
**Version:** `r135-web-framing-w6-20261024`
**Release engine:** Godot 4.4.1.
**Web ZIP:** approximately 103 MiB; native runtime with `index.wasm`, precompressed WASM and `index.pck`.

## Separating code and public deployment

PR #300 merged W6.4 camera, the legible in-world fault label and real desktop/mobile QA into `master`. Production remained pinned to the stable W5 artifact. This separate promotion PR changes only delivery, manifest source pin, production smoke, catalog state and supplementary pixel validation. It does not rewrite the 3D game code.

## Release gates

1. `R135 W6.4 verified artifact promotion gate` downloads **exact Actions run 40109700192**, never latest.
2. Independently check manifest SHA-256, source SHA and every ZIP member checksum before extracting the W6.4 runtime.
3. Re-run the portrait image gate using the genuine W6.4 screenshot. Require active orange caption in its upper safe band, in addition to 3D geometry coverage.
4. Serve the verified ZIP through the actual Nginx routing rules. Require correct WASM gzip and HTTP 206 PCK byte ranges.
5. Simulate fallback re-download from a local HTTP server and cryptographically revalidate the reconstructed package.
6. Only after a successful promotion gate, merge the delivery PR. The existing `OSGARD frontend deploy` workflow activates the package on SSH with rollback support and checks the **public** `/games/r135-service/` manifest digest/source and PCK streaming.
7. Verify other OSGARD game routes remain functional; keep W5 as an independent known-good artifact, and never substitute an unvalidated build.

**If the promotion artifact expires:** the fallback may recover W6.4 only when the live server is already serving the identical manifest; otherwise it rejects the restore. Before the first W6.4 publication, an unavailable artifact is a hard failure (W5 remains untouched). If public deployment fails, use the frontend workflow's backup/rollback and maintain the W5 runtime.

## Evidence and limitations

- Godot native mission and three diagnostic fault scenarios passed on the candidate.
- Real Chromium and Pixel emulator passed; in portrait, the active optical caption is visibly above the upper rail.
- First visible industrial structure: W5 41.05% of screen height → W6.4 26.25%; use a fixed RGB heuristic, **not** an art-quality score.
- This is **not** a performance benchmark on physical Android/iOS devices and does not certify AAA photorealism.
