# INHERIT R17 — CINEMATIC ENVIRONMENT AND VERIFIED PERFORMANCE

## Shipped source work

R17 builds on INHERIT's genuine R16 Three.js game. All scene objects remain visualizations of authentic InheritGame snapshots; it never bypasses account permissions, generation handoffs or original click placement.

**Environment and materials.** The island and cliff geometries now have proper UVs and locally computed 64–192px PBR tile families. The eight deterministic families are soil, limestone, basalt, forest ground, weathered tree bark, timber, shore sand and fern. Each high-quality surface includes distinct sRGB albedo, tangent-space normal map and linear roughness texture; mipmaps, anisotropic filtering and texture caching control GPU resource use. No third-party texture URLs, tracking pixels or unlicensed images.

**Moving world.** Real vertex shader displacement bends foliage and understory based on in-game wind. GPU particle vertices drift and wrap around the island rather than generating new DOM objects, while a maximum of four low-poly gulls orbit and flap their wings. A shader ocean uses three wave frequencies, wind-dependent crest, glints, shoreline colors and view-dependent fresnel. At low quality the density of foliage, pollen and birds is reduced.

**Postproduction.** Compatible hardware can enable a genuine Three.js EffectComposer pipeline: RenderPass, restrained half-screen bloom for glowing objects, a grading/vignette pass, and OutputPass. High-tier hardware defaults to cinematic processing; SwiftShader and low-power devices default to no extra passes and offer optional lightweight grading. The 3D interface has functional FX and FPS buttons, without covering any native gameplay controls.

**Adaptive rendering.** On-device metrics include actual browser frame interval FPS, p50/p95, measured JS-to-WebGL CPU submission time, three.js draw calls, triangle count, point/line count, tracked textures and geometries. If the rolling p85 interval exceeds 49ms after enough samples, the high-tier camera reduces render pixel ratio by 20% rather than modifying game objects or saved state.

## Local real GPU benchmark — Windows, Linux, macOS

Clone the GitHub repository on a real computer with a current system Chrome and a properly installed hardware GPU driver, then run:

    npm ci
    npm run qa:inherit-benchmark:gpu

This builds the production game, launches a local preview in a real Chrome instance, renders desktop 1440x900 and mobile 390x844 profiles at reducedMotion=no-preference and writes browser-report/inherit-r17-hardware-profile.json.

The strict :gpu command fails if WebGL is absent, if the adapter is SwiftShader/llvmpipe/WARP/software, or if its identity is masked/unverified. It measures frame intervals and CPU submission time **not GPU execution time**. The model and driver fingerprint are recorded; no claim of a hardware FPS measurement is made until that run actually succeeds. On headless CI use node scripts/inherit-hardware-benchmark.mjs --serve --swiftshader --require-webgl, which records a legitimate **software-renderer** baseline, not a GPU result.

The FPS button in the live game displays user-visible snapshots of FPS, p95 interval, CPU submission, draw calls and the WebGL renderer. A local :gpu run is required before labelling any machine- or GPU-specific performance as hardware-validated.

## Target metrics (performance budgets, not measured claims)

| Target | High desktop hardware | Typical mobile |
|---|---:|---:|
| Delivered FPS in stable camera | >= 30 fps | >= 24 fps |
| P95 frame interval | <= 50 ms | <= 75 ms |
| WebGL context loss | 0 | 0 |
| Core saved game write by visual layer | 0 | 0 |
| 3D atlas replay mutates present saved game | No | No |
| Works without hardware GPU | Native 2D | Native 2D |

Do not claim these targets are achieved without an actual local hardware benchmark. CI verifies the source, runtime and reports measured SwiftShader results from a Linux hosted runner; a real hardware workstation remains a separate physical verification.

## Release safety and compatibility

- There are no new server APIs or game state migrations.
- WebGL failure, tab hide, reduced motion and switching to 2D all preserve native gameplay.
- Browser tests protect the full legacy button hit area (earlier R16 overlays intercepted Legacy and research clicks).
- The SSH post-deploy verifier compares the final versioned HTML and 3D bundle with the files actually uploaded in the release archive.
- CI test gate: npm run qa:inherit-3d includes R16 and R17 material, animation, PBR, shader and instrumentation smoke tests.
- Real desktop/mobile Chrome QA and benchmark JSON are uploaded to GitHub Action artifacts for traceable acceptance.

## AAA development scope

This is a high-detail browser 3D vertical slice, not a claim of a finished photorealistic AAA game. Larger hand-authored environments, production photogrammetry, characters, full animation pipeline, physically verified global illumination, sound recording and dedicated discrete-GPU performance validation require additional funded stages. Godot/Unreal exports remain independent unverified deliverables.
