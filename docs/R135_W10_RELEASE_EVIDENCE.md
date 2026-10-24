# OSGARD R135 W10 — reproducible software release evidence

W10 is stacked on W9, W8, and W7. It does not grant “AAA certification”, assert tested hardware FPS or upload gameplay to production.

## New executable acceptance gate

`scripts/r135-w10-release-readiness.py` requires an actual Godot 4.4.1 Web ZIP, matching source commit, verified native/browser QA flags, original HERO/ECO GLB retention, unmodified exact manifest, SHA-256 for **every ZIP member**, no duplicate or path-traversal members, genuine gzip-compressed WASM decompressing to the same hash as `index.wasm`, and genuine portrait PNG dimensions.

It enforces PCK transfer budget under 100 MB, precompressed WASM under 70% raw size and full ZIP under 135 MB. Its output `r135-w10-release-evidence.json` includes source SHA, artifact SHA, exact member count and states explicitly:
`hardware_gpu_fps_certified: false`, `real_phone_thermals_certified: false`.

The existing candidate Nginx proof still runs **after** the W10 evidence gate, checking MIME, gzip WASM and 206 range PCK delivery. This gate is a second independent check beyond package creation.

## Integration

- Branch `feat/r135-w10-release-evidence-qa-20261024`, inherited from the W9 diagnostics branch.
- CI job `OSGARD R135 optimized web candidate` uses release ID `r135-web-release-qa-w10-20261024` and must pass native Godot + actual desktop/mobile SwiftShader gameplay.
- Real screenshots and machine-readable W10 evidence are stored in the CI artifact.
- After W7→W10 stacked PRs are reviewed and safely integrated into `master`, create a separate release PR that pins one successful run's exact archive manifest SHA before touching the publicly deployed W6.4 game.
- Until physical Android/iOS FPS, heat, endurance, voice and accessible real-user tests exist, mark the browser runtime **software QA tested**, not flagship AAA finished.

## Hard stop conditions

Fail if the archive differs from manifest in any asset, if a ZIP member is unlisted/unsafe, if source SHA differs, if portrait evidence is missing, if simulated fault state could be confused with live machine data, or if the public delivery smoke cannot verify a byte-identical release and other OSGARD game routes.
