# EMPIRE Ω R44 — physical night road lighting with WebGL budget

This is an actual Godot 4.4.1 code modification, not a reference render.
The pre-existing R38/R26 scenic map includes 162 real instanced lantern
meshes but only emissive material, so nearby wet roads and curb details
were not lit as they would be by physically positioned point lights.

## Real implementation
- Keep all existing 162 decorative lantern instances and two GPU batched
  meshes. Store the authored lantern coordinates when building the scene.
- Create exactly FOUR reusable OmniLight3D nodes, not 162 individual lights.
  Position them at the nearest **real** lantern mesh sites to the player's
  current city chunk; each has warm light, inverse spatial falloff, a 13m
  bounded radius and disabled real-time shadow maps.
- Godot world chunk updates reuse the four lights without allocations;
  time of day and graphics tier update the same nodes.
- LOW disables all; STANDARD activates two at lower energy; CINEMATIC
  activates up to four. Daylight shuts them all off. No physics, economy,
  collision, save, or mission change. No hardware ray tracing claim.
- R29 physically-based wet asphalt material already has lower roughness,
  so these real sources can affect its specular response naturally.

## QA gates
- New native Godot test v65 verifies 162 authored lamp positions,
  four light nodes, no shadow cost, intensity bounds, night/day transitions,
  short distance culling, LOW/STANDARD/CINEMATIC behaviour and actual world
  integration. Run native v21 driving, v53 rain, v61 road details.
- Real WebGL/PCK candidate from current Godot 4.4.1 source; capture actual
  Chromium pixels on desktop and portrait phone. A daylight screenshot
  proves baseline regression only, not nocturnal art direction.
- Merge only after green CI and exact reviewed source. New SSH release,
  7/7 publicly verified SHA-256, independent driving and manual night-scene
  screenshot before any final art-quality claim.
- Physical Android/iPhone FPS, p95, battery and thermal proof still require
  actual hardware and must not be synthesized or inferred from SwiftShader.
