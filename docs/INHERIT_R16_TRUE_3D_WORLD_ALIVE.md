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

The GPU canvas has pointer-events:none. Underlying native game buttons remain intact. 3D hit selection uses a read-only raycast and delegates opening the selected object's real memory to its original native button; placing items still follows the normal world handler. Choosing 2D restores the old painted world without reload or lost data; GPU failure leaves the older game playable.

## Build and release verification

- npm run qa:inherit-3d compiles the actual esbuild source graph without writing an asset and checks geometry, deterministic terrain, model coverage and fallback behavior.
- npm run build executes prebuild, emitting public/games/inherit/aaa-three.bundle.js; Vite and SSH deployment copy it into dist/games/inherit.
- Offline cache version inherit-shell-v28 includes the bundle and CSS.
- Chrome desktop/mobile tests verify GPU frames where supported, save-safe switching, native placements, and simulated WebGL failure.
- Existing complete GitHub frontend, Cloudflare, account, SEO and release checks remain required.
- Exact byte verification after SSH uses the actual release archive at osgard-release/html/games/inherit. The deployment intentionally rewrites brand URLs in packaged HTML with a commit query suffix. Hashing unrewritten public source caused the R15 post-deploy failure; it does not by itself prove a missing game release.

## High-detail sculpture pass

- Ten native object types now have authored procedural high/medium/low detail models: real branches and exposed roots, dozens of individual leaf clusters, sculpted granite strata, separately laid arch voussoirs, brass lamp frames and glass, detailed footpath joints, petals/stems, wind-chime hardware, mushroom clusters, rune-bearing cairns and engraved markers.
- Reusable deterministic wood/stone/brass height textures drive physically based bump shading without CDN requests, remote assets or photos.
- Material-aware static geometry batching reduces detailed prop draw calls to at most 14 per model, even with dozens of modeled pieces.
- A center-weighted LOD scheduler reserves full geometric detail for the objects players see most clearly. Trees and pebbles across the landscape are instanced; 980 extra wild-grass blades and 180 flowers in high-quality mode cost only a few instanced draws. The founding architecture and wooden bridge are 3D mesh objects.
- An incremental GPU mesh cache reuses unchanged sculptures after each native game action or resize. Only added, removed or quality-changed meshes are rebuilt. Real-world progress and saved positions remain untouched.
- The quality toggle rebuilds saved-trace LOD immediately. Status diagnostics expose triangles, draw calls, LOD counts and reuse through `InheritAAA3D.getState()`.
- Added unit tests instantiate the actual Three.js geometries, validate finite vertex positions, verify 10/10 enhanced items, compare triangle counts, enforce batch draw budgets and record real Chrome screenshots.

## Honest AAA scope

This is a real-time 3D upgrade with authored procedural art, not a pre-rendered picture. It is NOT a completed photorealistic AAA console game. Hand-authored photogrammetry, character animation, real-time GI, cinematic storytelling, voice acting, large-scale exploration and a verified Godot/Unreal export are outside R16.

A future Godot 4.7+ vertical slice can re-use the saved-world coordinate model, game mechanics and art direction, but must pass its own build and performance tests before being called finished.
