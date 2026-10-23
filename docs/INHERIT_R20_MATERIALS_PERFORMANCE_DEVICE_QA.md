# INHERIT R20 — Materials, motion and real-device performance validation

## Delivered source changes

- surface-microclimate.mjs: deterministic instanced radial contact shadows (36/80/136), clearcoat tidal pools (0/21/54) and GPU-animated weather particles (0/118/320), with no external assets.
- world-geometry.mjs: integrates microclimate into the existing sculpted island and the true native game-coordinate height field. Fictional generation season controls wetness, without modifying the saved world.
- cinematic-postfx.mjs: controlled HDR bloom, OutputPass, season-dependent golden highlights, cool shadows, FXAA and restrained film grain (disabled by reduced-motion).
- adaptive-resolution.mjs: measured frame interval budgets by quality tier, eight-second cooldown, 0.64-1.0 dynamic pixel-density scale and gradual resolution recovery. Never change quality while a benchmark is running.
- hardware-benchmark-ui.mjs: guaranteed monotonic deadline even when software rendering stalls. Sparse samples yield INCONCLUSIVE, never invented GPU performance.
- Original native save, account ownership, moves and generation handoffs are unchanged. All GPU effects run in the existing bounded animation loop.

## Real hardware is NOT yet independently verified

The GitHub runner may use SwiftShader, which rasterizes on CPU. A browser adapter name cannot independently prove a physical GPU. Passing Chromium CI is not evidence of tested hardware. Independent physical-device evidence requires running the on-device benchmark and recording output.

To perform real-device validation, open the published INHERIT game on the named device, enable 3D, select a quality preset, enable cinematic effects when supported, and click **Тест FPS · 10 с**. Keep the tab visible. Use **Копировать отчёт** to retrieve actual frame samples, then repeat each preset three times after warmup, and once again after five minutes of gameplay to capture thermal throttling.

| Physical device category | Preset | Proposed target (NOT an achieved result) | Required evidence |
|---|---|---|---|
| Discrete GPU desktop | High + full effects | p95 <= 20 ms (60 FPS goal) | Three completed 10-second reports and warm run |
| Integrated GPU laptop | Balanced | p95 <= 36 ms (30 FPS goal) | Three completed reports and native input check |
| Midrange Android | Efficient | p95 <= 45 ms | Three completed reports and responsive real tap tests |
| Recent iPhone Safari | Balanced / Efficient | p95 <= 36/45 ms | Three reports and genuine save/handoff checks |
| Low-end / absent WebGL | Native 2D | Original save and interactions pass | Two-dimensional fallback evidence |

These are release targets, not performance measurements.

### Required report fields

Schema, reason, samples, rendererClassification, hardwareEvidence, qualityTested, pixelRatio, viewport, averageFps, frameP95Ms, frameP99Ms, cpuSubmitP95Ms, gpuTimerMeasured, gpuP95Ms, drawCalls, triangles and recommendation. The operator should also identify the device, browser version and test date.

Reports with fewer than 45 intervals, a completion reason other than complete, a hidden tab or a software rasterizer classification cannot independently establish a physical GPU performance pass. GPU time must remain null unless valid non-disjoint WebGL timer-query samples are available; CPU submission time is not GPU execution time.

## Automated gates

- npm run qa:inherit-3d compiles the actual offline Three.js code and runs real source regressions including scripts/inherit-r20-smoke.mjs.
- Dedicated desktop/mobile Chrome scenes must verify real 3D instancing, season changes, native save integrity, frame stats, and WebGL failure fallback.
- Full frontend, Cloudflare Pages and exact-byte SSH gates remain mandatory.
- Software rasterizers open native 2D by default to keep the game responsive; players can explicitly enable 3D. Hardware-backed browsers default to 3D.

Do not merge, deploy or claim physical-device performance without passing CI and recording the requested physical tests.
