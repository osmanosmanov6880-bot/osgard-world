# EMPIRE Ω R122 — original combined PBR art and readable game UI gate

**Status:** isolated UNPUBLISHED draft release candidate. Not an approved photoreal AAA release, not the current R87 public server.

## Exact authoritative source

Repository: `osmanosmanov6880-bot/osgard-world`.
Base staging (before R122): `154803f1f970eae4431d30369110ddee576b38f1` on `feat/omega-r90-aaa-reference-first-slice-20261026`.
This branch must be accepted against the **actual R90 staging HEAD**, not a `pull_request` synthetic merge commit. The R121 bug fix is retained in all three source/build/provenance jobs.

## Two real 3D visual blocks integrated

**R119 — distant city and governance UX.** All original 72 R116 tower transforms and R114 rooftops are unchanged. Thousands of 4-sided glass windows use the **existing ONE original R91 batched MultiMesh**, with a single 20-triangle double-sided custom window surface: physically modeled dark metal mullions + recessed glass, normals on both faces, shaded metallic/rough surface, deterministic per-window colors. No new per-pane nodes, lights, shadows, physics or RNG. The actual four city district labels are now 44px minimum height and 15px minimum text; existing seven strategy tabs, R112 Camera3D and R117 F9 focus are unchanged.

**R120 — immediate playable street view.** Every original building/window position/collider, traffic event, and save remains intact. Nearby street windows use real original sun/sky PBR shading **during daytime on standard/cinematic** tiers, original visible unshaded colored windows **at night** (including outages), and cheap old unshaded shaders in **low/mobile**. Metal window perimeter becomes restrained physically shaded gunmetal without any new scene nodes or GPU draw passes.

## Final exact-SHA evidence required

1. `scripts/omega-r109-release-sentinel.py` verifies **15 authoritative source scripts and 24 actual native suite files** plus original SHA-256-locked three Poly Haven CC0 1K albedo/GL-normal/roughness maps. Missing or tampered source/asset must HARD FAIL.
2. `.github/workflows/omega-r109-final-candidate-evidence.yml` must use the exact `github.event.pull_request.head.sha` on PR or `github.sha` on staging push in **all three jobs**; `git rev-parse HEAD` is compared to that exact expected SHA. No synthetic merge-head is a valid R90 stage release SHA.
3. Import the actual 4.4.1 Godot game without script errors and run all **24** native source/regression suites, including original 40-mission policy tests, R87, R90, R91, R95, R106, R108, R111, R114, R115, R116, R119 `v95` and R120 `v96`. All exit code 0.
4. Export the same exact checkout into **actual playable `index.wasm` and `index.pck`**; run four real Chromium tests: actual gameplay + Tab cabinet, 390×844 portrait mobile canvas, host `requestAnimationFrame` scheduling (NOT real device GPU FPS), and actual F9 focus/restore with 3 source-rendered frame differences. Check for browser/page errors.
5. Preserve real screenshot/telemetry evidence, exact tested checkout source SHA, binary SHA-256 and playable seven-file WebGL ZIP using the existing `include-hidden-files: true` for the scoped `.build-web` folder. Final SHA manifest is produced only after both native/browser jobs succeed.
6. When independently verified R119 and R120 are accepted, merge **only** into R90 staging; rerun the exact same workflow on the new integrated SHA and archive those final exact-SHA results. Do not claim that a PR head success automatically validates a later, different mainline commit.

## Independent high-quality art signoff (still required)

Current city screen is a real procedural stylized Godot 3D world; it has not achieved comparison with the user's two approved AAA photoreal visual references. Compiler and WebGL PASS are engineering evidence, **not** final art approval. Genuine in-game screenshots, materials, readable typography, architecture, vehicle detail, desktop and mobile composition plus target hardware framerate must be reviewed separately.

**Hard release hold:** `master` PR #500 stays DRAFT. `omega-godot-web.yml` can automatically publish real WASM/PCK binaries into `master`, then follow with production SSH deployment. Preserve released public R87 source SHA `43ae041e8df52418ca74c02405de9c196b59bd37` and its actual binary rollback manifest. This R122 workflow performs no deployment.
