# INHERIT R24 — Water, Horizon, Focus & Graphics Readiness

## Changes

- Camera-space water normals, time-varying wave slopes, Schlick Fresnel and directional sun glints in a local Three.js ShaderMaterial.
- Atmospheric alpha horizon with elliptical coverage removes hard rectangular edges. Mist, wind, sun and tide use different fade distances.
- Three quality profiles bound the wave grid: Low 20×20, Medium 30×24, High 42×34 segments; no external image downloads.
- Compact native mobile 3D controls, every actual action retains an accessible minimum 44px target.
- User-triggered full-viewport cinematic focus (not fake fullscreen images); Escape returns to ordinary gameplay; unavailable when WebGL falls back to 2D.
- High and Medium foliage is upgraded to thousands of individually sculpted, color-varied curved PBR leaves in one GPU-instanced draw call; original wind deformation drives them without new JS frame loops. Low tier skips this work entirely.
- Original game budget, saves, generation transfer, installed offline service-worker and object interaction stay authoritative.

## Evidence and gates

Run npm ci, npm run qa:inherit-3d, npm run build. Perform desktop/mobile Chrome QA of the new R24 focus switch and seasonal ocean changes. Save screenshots, monitor runtime page errors and prove save JSON remains identical before/after focus. Benchmark full 10s on real hardware and classify SwiftShader exclusively as software evidence; no honest physical-GPU FPS is established until actual device runs. Keep PR #204 and PR #222 prerequisites. No automatic merge or SSH production deployment.