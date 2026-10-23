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

## R16.4 — authored monumental environment, not repeated low-poly props

The playable scene now generates original, physically shaded high-detail environmental objects. These are fictional landmarks, not player-owned saved traces.

- **Sanctuary:** layered twelve-sided limestone foundations; separately offset stone courses; colored stone mosaics; twelve fluted columns with capitals; keystone arch; octagonal lookout tower with carved masonry, crenellations, copper roof, windows, vines, rubble and lanterns.
- **Harbor:** timber pier with separate planks, piling joints, sagging rope railings, coastal stairs, weathered lanterns and deterministic driftwood.
- **Rowing skiff:** curved genuinely three-dimensional hollow hull, independent ribs, bench seats, hull rails, fittings, ropes and wooden oars.
- **Physically based materials:** seeded 96px stone normal and roughness maps with local stone, wood, copper, brass and glass.
- **Performance:** high/medium/low geometric budgets, instanced repeated masonry, mosaic stones, vines, debris and pilings. Low mode retains silhouettes while reducing triangles and fine detail.

The heritage-environment.mjs module exports the complete real 3D ensemble and geometry budget statistics. Node tests assert finite vertices, actual PBR normal maps, instancing, tier differences and offline-only assets. This is authored procedural geometry, not scan-based photorealistic production art.

## R18 — environment craftsmanship and on-device performance evidence

### Visual upgrade
The high tier now uses 51 radial rings and 148 angular segments across the island top, with 144 angular and 12 vertical segments for eroded cliffs. Medium and low tiers remain less expensive. The existing eight procedural albedo/normal/roughness texture families, GPU-blown vegetation, living pollen, circling wildlife, ocean swell and camera post-effects are retained.

Real PBR material parameters respond to the saved generation's *fictional* season: basalt, grasses and earth become optically wetter under tide/mist than sunshine. These visual changes do not touch gameplay state.

### Actual device benchmark

The on-screen **Тест FPS · 10 с** button runs an opt-in, uncapped ten-second moving-camera stress test. All samples come from the current browser and device: frame intervals, p95, CPU render-submission duration, triangle count and draw calls. GPU duration remains null unless a supported WebGL2 disjoint timer query returns valid measurements. CPU submission is never labeled GPU time.

The report is never sent automatically. **Копировать отчёт** copies measured data only after a user gesture. A browser-reported adapter name is not independent proof of the physical GPU; SwiftShader must be marked software.

To obtain a reproducible desktop Chrome report locally: run npm ci, then npm run qa:inherit-benchmark -- --require-gpu. The script builds and previews the game, measures the 1440×900 desktop and 390×844 mobile-sized *desktop Chrome* viewports and writes local JSON evidence under browser-report. A mobile-sized desktop viewport is NOT a real Android/iPhone test.

### Physical hardware acceptance matrix

- On a real desktop GPU and a real smartphone, run cold startup, warm ten-second benchmark, and ten minutes of extended play to observe throttling. Record OS/browser, DPR, hardware information from the device, battery-saver setting, FPS/p95 and camera/scene load.
- Desired performance budget: ordinary 30 FPS desktop gameplay and 24–30 FPS mobile gameplay without obscured controls, thermal instability or lost saves. These are targets until real measurements prove them.
- Retest native item placement, budget, account read-only mode, generations, Atlas, 2D fallback, reduced motion, tab visibility and the inspector while the GPU renderer is enabled.
- The GitHub runner's software WebGL tests validate compatibility, NOT a retail GPU/phone. No physical device acceptance has yet been conducted in this environment; do not call the release hardware-verified before genuine results exist.
