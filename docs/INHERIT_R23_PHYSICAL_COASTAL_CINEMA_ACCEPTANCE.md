# INHERIT R23 — Cinematic Coastal World and Real-Device Acceptance

## Implemented in native game source

- Season-specific offline sky radiance with 128×64 Medium and 256×128 High equirectangular PBR reflection maps. Low/software renderer disables the extra GPU work.
- Closed and sculpted sea-stack geometry, physical erosion grooves, mineral patina, locally instanced broken stone and four quality-bounded shader draw calls.
- GPU animated spray with 65/180 sea droplets in Medium/High. Its motion freezes under the operating-system reduced-motion preference.
- Seasonal film halation uses four samples in the existing grade pass, rather than an additional framebuffer. Disabled in Low and software renderer profiles.
- WebGL initialization failure no longer causes 2D save-state mutation observers to invoke missing Three.js objects. CI's disabled-button test creates a native object first.

## Release and performance proof

1. Run npm ci, npm run qa:inherit-3d and npm run build.
2. Use Chrome desktop/mobile visual tests and ensure R23 scene actually renders, seasons change materials, original save JSON does not change, and 2D fallback remains interactive.
3. On a physical desktop GPU run npm run qa:inherit-benchmark:gpu and archive raw JSON, screenshot, GPU model verified separately in the operating system, tier, viewport/DPR, driver, CPU and power mode.
4. On a physical phone run the in-game opt-in 10-second FPS benchmark at both efficient and balanced tiers; on capable GPU additionally test High. Record p50/p95 frame intervals, CPU p95 and GPU timer p95 only when the extension returns valid data.
5. Check scripts/inherit-device-acceptance.mjs outputs, reject SwiftShader/llvmpipe, mismatched quality, interrupted tests and insufficient samples. Browser adapter strings cannot independently prove physical GPU identity.
6. Do not deploy to a public server or claim verified AAA performance until mandatory CI and real-device GPU acceptance are complete.

No user saves or gameplay rules were changed. Photogrammetry and Unreal Engine builds are not claimed.