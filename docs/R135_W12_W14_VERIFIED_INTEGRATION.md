# R135 W12–W14 integration against current master — 25 October 2026

## Source provenance
- Shared ancestor: `50dd2dc1f9e07e62fa5e42bdcac39a6c5df6b822`.
- W14 code imported from head `1273ee620596e8712359e8740349eb814f76c3d9`.
- The **only change** after independently successful game build `4d1aec6c5f59f07d4f6bf1c4b97a46379d9d7d9e` was to the master completion roadmap document.
- Independent full Godot 4.4.1, desktop Chromium, emulated Pixel touch, real Nginx WASM/PCK byte-range run: [40175524463](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40175524463), SUCCESS.
- Browser completion on that run: three distinct faults via actual controls, 90/150 desktop and 74/150 emulated Pixel, W14 persisted-record schema and V1-migration native tests.

## Conflict-safe port
Seven existing changed source/test/workflow files were verified **blob-identical** between the shared ancestor and current master at the integration branch base `2422ec743047626e2b9c25b4393c2ded6f1316a5`. Therefore all 13 W12–W14 changed files are ported byte-for-byte; no newer code from the other OSGARD projects is overwritten. Only the workflow push-branch filter was extended for this integrated branch.
- Main lesson: STOP motor **before** opening simulated hatch; never teach unsafe maintenance order.
- Every scenario remains an educational simulation. It is not a live equipment command, energy-isolation procedure or industrial qualification.
- User local history: v2 per-fault metrics with careful import of old v1 best score and three completion flags; do not invent historical per-fault attempts.

## Release gates
1. Run new integrated branch native Godot, all-three-fault real Chromium desktop and mobile emulation, screenshot hash evidence, gzip WASM and PCK 206.
2. Review genuine desktop and portrait screenshots; physical Android/iOS GPU FPS and thermals remain **unverified** until real-device evidence is uploaded.
3. Only after successful CI, merge this integration PR. Keep published W11 asset pin and deployment path untouched.
4. Create separate promotion PR pinning the specific successful W14 Web archive's SHA-256, source commit and version; test SSH space, rollback, other routes and public manifest byte-for-byte. Never infer that merging means public publication.
5. The old stacked PRs #364, #370 and #386 can then be closed as superseded, with a clear link to the integrated PR and merge proof.
