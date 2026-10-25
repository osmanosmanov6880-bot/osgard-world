# EMPIRE Ω — R60 integrated native candidate and release evidence

This branch combines exactly the validated original **R56** real headlamp
geometry and full OpenGL A/B pixel test with **R58** mandatory Godot Web
pre-export graphics gate, on current master including R53 genuine Chromium
screencast and R55 40-event save recovery.

## Exact source provenance (never confuse merge with export SHA)
- Integration base commit: `f6f3f181dafeb0bf5fef40b9ac1d0d2b4ffe88fc`
- R56 source candidate: `5846cbf3f4a366fcf76372c8fd8aeaff7e0d8d33`
- R58 strict visual pre-export candidate: `8873eb8b1c2061adacc48667806aa527b2e2e02e`
- Production source SHA: **must come from a successful native Godot Web export after merge**, and be recorded in `public/games/omega-3d-preview/release.json`.
- No CDN/SSH operation may publish a superseded source tree.

## Mandatory release gates
1. Godot 4.4.1 `--headless` runs actual original gameplay and R46/R47/R48/R49/R52/R55/R56 regression suites, not GPU screenshot programs.
2. Same main export job runs XVFB/OpenGL 1366x768 original playable city **day and night**; authentic PNG bytes/dimensions verified. This step **precedes** WASM/PCK export and must fail on absent frames or black lighting.
3. R56 dedicated GPU test measures real asphalt pixels with SpotLight3D beams enabled and disabled, not unrelated arbitrary screen locations; R33 original energy/memory bounds remain enforced.
4. GitHub Actions must rebuild original Godot Web `index.wasm`, `index.pck`, HTML/JS and seven-file source manifest.
5. Only the verified source candidate activates over hardened SSH after checking exact master game tree freshness.
6. Re-fetch seven public assets and calculate SHA-256 for each: exactly 7/7 must match release.json byte hashes; source_commit must equal the new game's export source, **not the PR merge commit by assumption**.
7. Independently load published WebGL on desktop and touch emulation, prove rendered moving pixels, vehicle movement and source match; preserve original traces.
8. Real Android/iPhone FPS/latency/thermal checks, human 40-mission walkthrough, visual asset quality and licensing remain separate HARD HOLD requirements. A green CI is not AAA certification.

## Explicitly prohibited false positives
A green SSH workflow with a `SUPERSEDED` notice and `ready=false`
means **no new publication**. A headless screenshot is not evidence of real
OpenGL. Simulated smartphone Chromium is not physical-device performance.

## Why one unified candidate
Earlier R56, R57 and R58 PR branches used an older base than the latest
website/game master; independent PR checks alone cannot certify their
combination. This branch uses the exact original updated assets plus the
current base. No extra render filters or invented gameplay were added.
