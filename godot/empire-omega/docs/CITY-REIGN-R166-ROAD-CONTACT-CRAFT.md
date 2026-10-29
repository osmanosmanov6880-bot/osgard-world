# CITY REIGN R166 — ROAD CONTACT CRAFT / ORIGINAL GODOT SOURCE
Baseline: publicly deployed R165 `8b32c05575ee492e875f606212341ad07febfe18`
Engine: original Godot 4.4.1 / GL Compatibility / real WebGL2, car `CharacterBody3D`.
This document is technical release acceptance, not proof of production AAA parity.

## Three substantive world-driving improvements
1. **Source-driven brake disc thermal visual.** The original four R39 machined rotors now accumulate a bounded front/rear 0..1 normalized energy estimate from genuine speed-squared reduction WHILE real brake response is pressed, actual four supported road contacts and the existing R46 physical front axle load fraction. Rotors cool over time and faster on wet roads. Real rotor materials transition from cold metallic to warm/amber via their existing emission material, with zero additional meshes, shadows, dynamic lights, textures or physics authority. The 0..1 value is intentionally not a measured Celsius temperature or ABS reading.
2. **Normal-aligned tyre markings.** The ORIGINAL 96-segment MultiMesh ring remains. Real existing LF/LR/RF/RR collision normal from the same physics ray cache is used for each rubber quad orientation on sloping road geometry. Normal invalid/underneath fails safely to UP. No tracks when airborne/low quality/teleport. The original skid qualification and scoring remain unchanged.
3. **Velocity-directed bounded tyre water/dust.** The ORIGINAL two GPUParticles3D emitters, 24 each, continue using actual rear-wheel collision points/normal, but spray now points away from TRUE vehicle horizontal velocity instead of always vertically up. Bounded speed-dependent droplet intensity, wet/dry color and tiered particle ratios retain the existing budget. On LOW all emitters stop.

## Release gates
- New real Godot tests: v146 30/60/120Hz normalized rotor heat A/B, v147 sloped real-collider rubber normal & ring budget, v148 grounded GPUParticles velocity wake and mobile LOW, v149 actual original player-car W/S brake on native Godot road, rotor material glow, cool-down and save isolation.
- Inherited native checks: v45 skid trails, v46 grounded spray, v62 actual wheel art, R165 v143-145 dry/wet brakes and cockpit feedback, R164 cabin meshes/cameras, R163 active lane guidance, all original campaign + 40 missions corruption recovery.
- Source-locked real HTML/JS/WASM/PCK with SHA256; original true Chromium WebGL2 3D game with actual E/V/W/S and Tab on desktop/mobile-shaped viewport.
- Isolated exact-SHA SSH publish to only `/games/city-reign/` after ALL above pass, public server SHA256, independent LIVE game Chromium and fail-closed rollback.
- NO claims of measured frame rate on physical phones, automatic tyre-lock detection, hydraulic pressure sensor, actual disc temperature or GTA VI/Forza parity without independent measurement and licensed 3D assets.

## Next milestone
R167: vehicle silhouette/material sculpt and real lighting polish; benchmark midrange desktop + physical mobile hardware before extensive surface detail. Version number never substitutes for validated gameplay quality.
