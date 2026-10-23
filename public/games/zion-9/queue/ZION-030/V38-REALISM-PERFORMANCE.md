# ZION-030 v38 — living city realism with bounded GPU cost

## What changed in the REAL playable scene

1. **True curved leaf geometry**: one deterministic multi-vertex leaf mesh, instanced across the exact real street trees. Leaves are not rectangular alpha-billboards or screenshot overlays. Wind displaces the instance transforms at approximately 12 Hz, not 60 Hz; gameplay positions and collision remain canonical.
2. **Tree branches and street litter**: two further shared batches of tiny supports and fallen leaves, anchored to known vegetation groups. They are rendered with high roughness and weather-responsive colors.
3. **Civil weathering**: an authored 96×192 RGBA atlas of vertical water stains and oxidation. The same texture and one wall-plane InstancedMesh cover real facades. Moisture opacity changes with actual rain/night state.
4. **No extra interaction or hitbox**: this is world decoration only, with zero changes to missions, car physics, saves, reward systems or UI navigation.
5. **Performance engineering**: v37 fallback desktop mineral PBR atlas lowered from 768 to 512 px per channel (9 texture maps, 9.0 MiB raw instead of 20.25 MiB). Genuine 1K Poly Haven CC0 diffuse and normal textures still progressively replace the procedural fallback on suitable desktop GPUs. **CDN photo requests do not begin until the first actual gameplay frame**.
6. **Tier discipline**: ULTRA has up to 52 deforming leaves per actual tree; MOBILE has 20 per tree; SOFTWARE and reduced-motion have zero additional foliage/decal batches. ECO/adaptive hides the entire v38 layer. Resource disposal tears down all geometry, material and generated texture objects.
7. **Physical GPU evidence**: existing self-hosted `zion-gpu` runner checks daytime, rain/night and ECO weather quality, authentic material load, v38 leaf visibility, p95 frame intervals and screenshots. GitHub-hosted SwiftShader tests are not used to claim physical FPS.

## Design and verification contract

- Detail is restricted to physically plausible close-range scenes: tree crowns, buildings, facade age and street-level debris. There are no giant sci-fi visual effects that obscure the cooling-zone objective.
- Scene additions use a maximum of four new InstancedMesh batches when high quality is active; software path creates zero optional instances.
- v37 procedural albedo, roughness and tangent-space normal maps remain correlated with the same height field. Photo materials are CC0 with provenance documented in `PHOTOREAL-37-SOURCES.md`.
- Reproducible regression evidence: `node scripts/zion-open-city-v38-smoke.mjs` and the desktop/mobile ZION browser acceptance workflow.
- A visual quality or AAA claim requires approved screenshots from an accelerated GPU, licensed source photographs, measured frame time and review of lighting fidelity. This stage does not claim ray tracing, UE5/Nanite/Lumen, scan-based geometry or fully certified AAA photorealism.
