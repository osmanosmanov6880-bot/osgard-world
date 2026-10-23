# ZION-030 v34 — PBR WORLD / FILM / PERFORMANCE

## Implementation status

Source code is implemented in the stacked v34 feature branch. Passing source smoke tests, browser playback and remote SSH checks are separate requirements. **It is not an Unreal Engine 5 game or proven AAA photorealism.** All additions are rendered inside the playable Three.js scene, not prerendered promotional screenshots.

### 1. Physical material response, responsibly budgeted

- Three reusable deterministic CanvasTexture families — travertine/stone masonry, plaster, brushed metallic trim. Each family has **albedo + linear normal + roughness maps**. All layers are generated locally with repeatable noise, grout, grain and milling marks.
- ULTRA textures are 512 px square with height-derived tangent-space normal maps; MOBILE textures are 192 px; software WebGL and reduced motion create none. Existing street materials are patched in place and restored on disposal.
- Nine texture maps total on eligible tiers. Allocation is explicitly tracked as estimated uncompressed pixel bytes, **not claimed as actual GPU VRAM**.
- ECO/adaptive shading releases fragment shader map sampling but retains allocated atlas objects for seamless quality switching. No save-game rules or vehicle physics change.

### 2. Street-scale geometry and motion

- Genuine instanced cornices, drain leaders, etched doorway surrounds, metal railings, drainage grilles and pavement seams, grounded against the original authoritative building/traffic grid.
- A bounded number of anchored planter trees with individually wind-swayed crown groups.
- Rotating rooftop extractor fans and civic cloth banners, throttled for low-end rendering.
- Rain ripple mesh instances become visible under existing weather controls.
- Three tiers: ULTRA, MOBILE and LITE; LITE never allocates normal/roughness atlases, animated fan geometry or wet rings.

### 3. Cinema-grade presentation (bounded, not HDR-ray-tracing)

- Optional one-pass, full-scene WebGL postprocess in a capped offscreen target (max 2048 × 1536).
- Subtle screen-space bright-pass glow, warm/cool scene grading, restrained vignette, near-subpixel chromatic separation and dithering. Existing ACES tone mapping and day/night lighting remain the source.
- Only available by default on hardware-backed desktop WebGL when motion is not reduced. Disabled in ECO/adaptive, software WebGL and mobile. Fallback keeps the world playable if the shader or render target fails. HUD stays crisp as DOM content and is not postprocessed.

### 4. Measured performance, not invented FPS

The **◷ FPS** button (or **B**) opens a 15-second render benchmark. Report includes:
- Hardware renderer classification (**hardware-reported / software / unknown**), with WebGL vendor/renderer string and a conspicuous warning on SwiftShader or unknown devices;
- Browser-measured rendered FPS and median/p95 frame intervals;
- CPU render p50/p95, draw-call/triangle p95 and optional GPU timer queries via \`EXT_disjoint_timer_query_webgl2\` if available;
- Actual sample count and validity. Frame cadence is correctly reported as low in intentionally throttled software mode; never infer 60 FPS from geometry budgets.

On a computer with a physical GPU and installed Chrome, run:

\`\`\`bash
npm ci
OSGARD_GPU_BENCH_URL="https://osgard.world/games/zion-9/queue/ZION-030/index.html" \
  node scripts/zion-v34-hardware-benchmark.mjs
\`\`\`

The target URL **must actually serve v34** (or a local v34 preview), otherwise the script fails. By default the script rejects any software-only or unknown GPU as non-hardware evidence. The report is saved as timestamped JSON in \`reports/gpu/\`. Set \`OSGARD_MAX_FRAME_P95_MS=33.3\` to enforce a strict desktop timing gate, after first choosing an appropriate target for the hardware class.

A physical device with GPU acceleration is **not connected to the present AI/GitHub CI environment**. GitHub-hosted Chrome may run SwiftShader. A pass in CI is a functional regression, **not** physical-GPU performance certification.

### Acceptance

- \`scripts/zion-open-city-v34-smoke.mjs\` runs real construction code with deterministic mock geometry across three tiers, verifying material lifecycles, bounded postprocessing, animation and lack of stale state.
- \`scripts/zion-v34-browser.spec.mjs\` tests actual Chrome gameplay on desktop/mobile, H/B controls, weather, quality, real browser timing reports, cinematic screenshots and return to the original puzzle.
- All v26–v33 game tests remain enabled.
- \`scripts/zion-030-live-assets.mjs\` includes **18** mandatory v34 game assets, compared byte-for-byte over public HTTPS only after SSH activation.
- CI: software-WebGL data cannot be relabeled as real physical-GPU measurements; physical testing remains pending until the hardware CLI actually produces a \`physicalGpuConfirmed: true\` report.

**Definition of done:** successful local smoke + desktop/mobile browser + production SSH checksum + at least one trusted hardware report with concrete frame-time budget. No claim of 4K/60 FPS or AAA-finished status without that evidence.
