# INHERIT R22 — physical shoreline geology, surf and hardware acceptance

## Implemented, not a picture

Original Three.js geometry at coastline coordinates, no external assets. R21 adds animated shader foam following the jagged coast: low 384, medium 1,280, high 2,880 surf triangles in one draw call. R22 adds 3D weathered sediment shelves, fractured basalt, and real lichen meshes in two or three instanced batches. The new geology tiers produce low 89, medium 384, high 820 objects. All seasons change wetness and PBR roughness. Motion respects reduced-motion preferences. These layers do not alter gameplay, accounts, object placement, generation history, or save data.

Existing R20: GPU animated particles, saved artifact motion, seasonal cinematic grading, FXAA and adaptive resolution based on measured frame pacing remain intact.

## Verification and release gates

- `npm ci && npm run qa:inherit-3d && npm run build`
- Real-Chromium desktop/mobile WebGL smoke, visual screenshots and native 2D fallback
- User actions: season cycling, Atlas replay, placed object click, artifact studio, generation handoff and reduced-motion
- GPU measurement: use `npm run qa:inherit-benchmark:gpu` locally on a system reporting a non-software renderer, then run the in-game 10-second FPS test on an actual phone or laptop. Record real device model, browser, OS, resolution/DPR, tier, p50/p95 frame intervals, CPU submit p95 and GPU timer p95 only when supported.
- Apply `scripts/inherit-device-acceptance.mjs` to exported benchmark JSON per tier and device.
- Reject software renderer (SwiftShader, llvmpipe) for physical-GPU performance certification. A WebGL adapter string alone cannot independently authenticate the GPU.

**Not yet confirmed:** physical GPU FPS, GPU-driver coverage, actual desktop/mobile frame captures and SSH deployment. Do not merge before CI, browser captures and release checks are green.
