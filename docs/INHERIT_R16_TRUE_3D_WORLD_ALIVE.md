# INHERIT R16 — TRUE 3D / World Alive

## What actually ships

R16 introduces a real Three.js / WebGL scene inside the existing INHERIT browser game, replacing the painted island with real perspective-projected meshes when a GPU is available.

- Procedurally generated rugged shoreline and beveled cliffs, with a deterministic height field, vertex colors and computed normals
- Animated shader-based sea, water ripples and foam, coastal stream and traversing footpath
- Real 3D vegetation using instanced trunks, layered crowns, bushes and rocks
- Physically lit models for all 10 real INHERIT trace types: tree, stone, lantern, path, flowers, arch, wind chime, moss, cairn and marker
- Fictional founding landmarks, fog, ACES tone mapping, directional shadowing, hemispheric illumination and cool rim light
- Optional 6.5-second cinematic camera orbit; native placement pauses only during the flyover
- Automatic low-power mobile quality, manual quality switch, bounded pixel ratio, offscreen pausing and explicit original 2D fallback
- Season lighting synchronized with genuine generation data, not actual weather
- Fully offline runtime: installed Three.js is bundled via esbuild before Vite copies public game assets. No runtime CDN

## The original game stays authoritative

The renderer reads the existing InheritGame.snapshot() API. It never writes the game, calls its APIs or invents achievements. World coordinates remain native x/y percentages. The original DOM click handler, placement budget, account authorization, atlas, first-run coaching, replay mode, handoffs and saved format remain unchanged.

The GPU canvas has pointer-events:none. Underlying native game buttons remain intact. Choosing 2D restores the old painted world without reload or lost data; GPU failure leaves the older game playable.

## Build and release verification

- npm run qa:inherit-3d compiles the actual esbuild source graph without writing an asset and checks geometry, deterministic terrain, model coverage and fallback behavior.
- npm run build executes prebuild, emitting public/games/inherit/aaa-three.bundle.js; Vite and SSH deployment copy it into dist/games/inherit.
- Offline cache version inherit-shell-v28 includes the bundle and CSS.
- Chrome desktop/mobile tests verify GPU frames where supported, save-safe switching, native placements, and simulated WebGL failure.
- Existing complete GitHub frontend, Cloudflare, account, SEO and release checks remain required.
- Exact byte verification after SSH uses the actual release archive at osgard-release/html/games/inherit. The deployment intentionally rewrites brand URLs in packaged HTML with a commit query suffix. Hashing unrewritten public source caused the R15 post-deploy failure; it does not by itself prove a missing game release.

## Honest AAA scope

This is a real-time 3D upgrade with authored procedural art, not a pre-rendered picture. It is NOT a completed photorealistic AAA console game. Hand-authored photogrammetry, character animation, real-time GI, cinematic storytelling, voice acting, large-scale exploration and a verified Godot/Unreal export are outside R16.

A future Godot 4.7+ vertical slice can re-use the saved-world coordinate model, game mechanics and art direction, but must pass its own build and performance tests before being called finished.
