# R135 W14 — controlled publication and operations runbook

**Release identity:** `r135-case-progress-w14-20261025`  
**Reviewed gameplay source:** `4d1aec6c5f59f07d4f6bf1c4b97a46379d9d7d9e`  
**Independent desktop+mobile emulation / Godot / Nginx run:** [40175524463](https://github.com/osmanosmanov6880-bot/osgard-world/actions/runs/40175524463) — SUCCESS  
**Source artifact:** run 40175524463, artifact 12592898463  
**SHA256 archive:** `704131eda3a1ba1c3a860690c7f2beb0115bae65d818fc7887c0cb44b9817245`  
**SHA256 manifest:** `4a2333a8fdaef0da270a224b85ee8a763170f923f2449635018a74626398d05b`  
**Rollback:** permanent W11 GitHub Release tag `r135-web-legibility-w11-20261025` and SSH activation backup.

## Why W14 source commit differs from the integration merge SHA

Integration PR #393 transferred the **eight runtime/test source blobs byte-for-byte** from the fully successful W14 candidate onto current master. The final W14 original branch's additional commit changed only a roadmap document. Therefore packaging the original successful W14 game is legitimate. The public manifest continues to identify the actual source commit used to build the WebAssembly and PCK; never rewrite that SHA to match a later PR merge.

## Production go/no-go

1. Confirm PR #393 is merged and the real integrated Godot/Chromium smoke has no regressions.
2. Confirm the exact-pin [W14 promotion gate](https://github.com/osmanosmanov6880-bot/osgard-world/actions/workflows/r135-w14-promotion-gate.yml) passes. It rechecks the archive and every file, real two-device three-case evidence, luminance, candidate Nginx gzip WASM / PCK HTTP206, and live-package recovery using a **local test server**.
3. Check the server has sufficient space; the earlier SCP failure was caused by a 100% full disk. Stale OSGARD upload directories were cleaned. The deploy preflight must reject insufficient space without deleting active backups or Docker images.
4. Merge PR #397 only after the positive promotion gate. This is the sole action changing the public R135 version.
5. In the GitHub Actions **frontend deploy** run, require success from each of the following: archive stage and checksum; candidate Nginx; SSH archive activation; exact public W14 manifest SHA/version/source with PCK byte ranges; unrelated OSGARD route matrix.
6. Open the public R135 scene on desktop and a phone, test 8 controls, stop-drive-first training and a complete simulated fault. If a test fails, use the verified SSH rollback / restore the reviewed W11 release rather than leaving a partially promoted W14.

## Artifact lifecycle

Actions artifacts have finite retention. The **first** W14 publication downloads the original artifact by fixed run ID (never `latest`), checks its ZIP SHA and every member. If unavailable before W14 is already live, publication **fails closed**.

After public W14 activation, later deploys can reconstruct the WebGL ZIP only from a public host serving **exactly** the pinned W14 manifest and the SHA-matching binary files. A W11 host or a corrupted W14 host cannot be used as a substitute. A permanent separately backed-up binary is still recommended for disaster recovery when neither GitHub nor the original server is available.

## What is and is not complete

- Complete: Godot source, three simulated interactive fault scenarios, safety-first ordering, local v2 statistics and v1 migration, desktop Chromium and Pixel emulation QA, pinned WebAssembly and PCK, rollback plan.
- **Not certified:** FPS / 1% lows / thermal performance on physical Android and iPhone, user-tested accessibility, true photorealism/AAA-level asset production. Software SwiftShader frame timings cannot stand in for actual mobile hardware.
- The entire game is an **educational simulation**, not a live machine control or authorized lockout/tagout procedure.
