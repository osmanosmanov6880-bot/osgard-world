# OSGARD OBSIDIAN / W49-W52 — independent release acceptance

Status: **source changes prepared, production HOLD until exact-head checks and device review finish**.

## Exact release ancestry

- W47 original Godot 4.4.1 baseline SHA: `14be69cdaa1fdffa4e209645eed0b1964581858a`.
- W48 review: [PR #530](https://github.com/osmanosmanov6880-bot/osgard-world/pull/530) (draft, parent W47).
- Never change `osgard.world`, `master`, production host, or live release without independent approval.
- W48 changes 84 small BoxMesh reactor segments into **one legacy MeshInstance3D plus three MultiMeshInstance3D groups with 27 + 28 + 28 instances**. This means **four drawable nodes for that group** (95.24% fewer *nodes in that group*), not a proven 95.24% reduction in whole-scene draw calls and never an FPS benchmark.

## New automatic verification chain

| Wave | Evidence or test | Mandatory source binding | What passing actually means |
| --- | --- | --- | --- |
| W49 | `w49_source_contract.py` | Git merge-base, pinned W47, exact PR head | W48 changed only allowed scene/profiling/test/CI/doc paths; core, mission tests, scenes, export profile and production stay byte-identical to W47 |
| W48 expanded | `test_w48_ring_instancing.gd` | Real Godot 4.4.1 PR-head native import | 84 original W47 positions and complete 3-axis basis, PBR size/material/shadow, HERO/ECO, six mission controls, three cameras |
| W50 | `w51_paired_comparison.py` | Two **pristine**, unmodified, independently exported W47 and W48 Godot WebGL builds | Ten real Chromium frames (HERO overview, inspection, service; desktop ECO; and touch-emulated HERO, each on both SHAs) plus an original visual comparison sheet, with PNG SHA-256 |
| W51 | Same paired runner | Both Godot 4.4.1 WebGL sources on *one* runner/SwiftShader renderer | Real Godot FPS for both SHAs and W48 actual draw-call/object samples; pristine W47 has no draw-call probe |
| W51 strict | Existing `godot_software_performance.py` | W48 exact-head WebGL evidence | Three W48 measured scenarios, nonzero Godot draw-call samples and advancing native engine frame counter |
| W52 | `w52_release_gate.py` | All upstream exact-head artifacts | Independent ZIP CRC, every member hash, nested WebGL/Windows/PNG manifests, W42 SHA256SUMS and build-report cross-checks, six Chromium missions, Windows 2022 boot, touch and screenshots |
| W49/W52 negatives | `test_w49_w52_gate_regressions.py` | Python standard library, synthetic **negative** fixtures | 24 unit checks cover changed W47 core, deploy paths, moved SHA, unsafe ZIPs and image bytes, plus W42 ZIP/build-report/SHA256SUMS cross-checks; **does not** certify rendering |
| W52 final | `w52-independent-final-verdict` | Every actual upstream job's `needs.result` | Always uploads `PASS` software-only or `BLOCKED_PRODUCTION_HOLD` JSON and the exact SHA; never promotes |


### Actions artifact names

Look under the **same** PR-head commit in `.github/workflows/r135-w33-operator-debrief-native-qa.yml`:

- `osgard-w49-original-source-contract-<SHA>` — source integrity manifest.
- `osgard-w50-w51-original-paired-<SHA>` — ten real screenshots, contact sheet, real software frame/draw diagnostics, paired JSON.
- `osgard-w44-real-godot-software-fps-<SHA>` — strict W48 diagnostic report.
- `osgard-w39-original-cinematic-visual-evidence-<SHA>` — five source-bound rendered screenshots and original Godot contact sheet.
- `osgard-w33-playable-browser-evidence-<SHA>` — real six-mission Chromium controls.
- `osgard-w45-mobile-touch-real-canvas-evidence-<SHA>` — 390px touchscreen-emulated mission 0.
- `osgard-w34-actual-windows-exe-boot-<SHA>` — Windows runner stdout/stderr and native EXE verdict.
- `osgard-w42-reproducible-candidate-<SHA>` — original deterministic ZIP, `SHA256SUMS.txt`, `build-report.json` and byte manifest. W52 requires **all three** independent outer references to agree.
- `osgard-w52-source-bound-release-gate-<SHA>` — final software review report, explicitly **HOLD production**.
- `osgard-w52-ci-final-verdict-<SHA>` — consolidated result for **all** required checks, preserved even if native, packaging or benchmark steps fail; production remains HOLD.

A queued, cancelled, stale, failing or different-SHA Actions run is **not** acceptable proof. Each CI update cancels previous head's run by workflow concurrency. Only one *completed, successful, source-matched* attempt of the latest head is acceptable.

## Important interpretation constraints

1. MultiMesh merges ring drawables; it does **not** guarantee exactly three renderer draw calls. Shadow and rendering passes may submit extra draws. Only Godot's `RenderingServer` counters on real frames are draw-call measurements.
2. W47 is exported **without any added instrumenting code**. Its actual engine FPS is comparable on the same CI runner; W47 renderer draw-call count is *unknown*. Do not report a numeric W47→W48 total draw-call reduction from the 84→4 node count.
3. The two scenes animate. Screenshot pixel differences are diagnostic only. Pixel-perfect equality is neither asserted nor used to certify the geometry. Real-native 84-transform comparison is mandatory for geometry parity; a human must compare screenshots.
4. Chromium SwiftShader measurements are **software/emulated**, not actual dedicated-GPU frame rates and not physical Android/iPhone results. Single-pair FPS changes lack statistical significance and have no guaranteed positive sign.
5. The operator is an *offline reactor training simulation*, not control software for any physical reactor. No real-world control authority is added by this release.
6. HERO, ECO, mission logic, safety interlocks and saved session state must not be modified to make an art/performance test pass.

## Release gate / human actions

The GitHub gate may emit `status=PASS` with `decision=STAGING_CANDIDATE_VERIFIED_PRODUCTION_HOLD`; **this is not a production GO**.

The W49 job additionally runs the negative-test standard-library suite before it reads Git blobs. The tests construct **synthetic invalid inputs** and deliberately reject them; passing unit tests must not be misrepresented as successful Godot exports or customer-ready packages. The final W52 job records mandatory job failures and emits a source-bound JSON `BLOCKED_PRODUCTION_HOLD` instead of silently lacking an acceptance report.

Before approval, the reviewer must examine the W47/W48 visual sheet and original W48 native screenshots at desktop HERO, desktop ECO and 390px emulation; confirm no flickering, ring disappearance, shadow/regression, cropped HUD, unreadable type, changed six-mission routes, or safety violations. Reproduce on a real Windows GPU, a physical Android device and a physical iPhone (mobile support where applicable). Record GPU/OS/browser, device-native resolution, 1% low FPS, median frame time, WebGL warnings, thermal throttling and HERO/ECO differences. Set objective performance budgets **before** promoting.

No files in this series deploy artifacts, merge a PR, overwrite live build folders, issue real-world plant commands or give hardware/FPS/AAA certification. Promotion and rollback require a separate auditable decision with exact SHA, URL, verified hashes and recovery plan.

## If Actions is still queued

Do not infer PASS from source-only tests. The new run will be scheduled by GitHub when a runner becomes available; monitor the PR check list. The source and manifest files are useful before the runner completes, but the gate's outcome is **pending**.
