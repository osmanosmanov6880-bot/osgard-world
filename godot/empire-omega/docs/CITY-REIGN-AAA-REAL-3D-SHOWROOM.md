# CITY REIGN — ORIGINAL REAL-TIME 3D AUTOMOTIVE SHOWROOM

## Current source-implementation
The playable R90 city operations cabinet presents four source-real ownership/vehicle cards and, on PC, an additional **original Godot 4.4.1 3D vehicle turntable**. It reuses the original `horizon_vehicle_art.gd` and physically distinct `city_reign_player_vehicle_profiles.gd` sculpt that the real player drives, not a new car model invented only for a purchase-page screenshot.

### Visual design
- Original graphite-brass R90 UI; one full-width studio stage with a satin-basalt cylinder, two original unshadowed studio lights, nuanced ambient lighting, a real Godot `Camera3D`, actual procedural PBR vehicle body, four wheels, genuine roof and glass. Brand palette: bronze/champagne on slate gray, not excessive fake neon.
- Car cards include an unconditionally independent **Inspect 3D** action for every car **before purchase**. Preview cannot bypass actual ownership requirements.
- View controls rotate the real 3D `Node3D` exactly 15 degrees per click, not a fake HTML 360 image. No idle auto-rotate; reduced-motion and low GPU respected.
- Standard/cinematic desktop may initialize the showroom on card construction. Phone creates ZERO new GPU render passes until the user explicitly chooses a car inspection. Low graphics disables additional 3D rendering entirely and retains every actionable real car purchase/select control.
- Exactly one source SubViewport, at most 620 × 282 effective desktop pixels or 340 × 184 mobile pixels (within 320px root safely). It renders on demand through `UPDATE_ONCE`; no per-frame animation loop, new traffic physics, shadow passes, asset import or event-driven extra purchases.
- One real offscreen `World3D` for the car at the command cabinet, separate from the previously approved real district atlas and from the main playable city. The atlas and its existing source camera remain untouched.

## Acceptance and hard blockers
- New original native test `v117_city_reign_aaa_actual_showroom.gd` verifies 4 real model profile pointers, zero car ownership/save changes, actual game HUD preview buttons, rotation, mobile lazy GPU allocation, low-tier NO new preview, single SubViewport, original camera + physics-free scene.
- Strict exact-head Godot import, R126 traffic, A7 garage physics, A9 actual purchase, Chromium WebGL and source integrity/regression must pass before any staging merge.
- This **does not claim AAA photorealistic human visual approval**. Still missing final licensed hero cars, studio-polished metallic/normal textures, raytraced/high-quality reflections for high-end PC, animation, real phone frame benchmarks, player playtests, native photo/pixel inspection, independent aesthetic signoff and commercial licensing.
- **No master, no public R87, no SSH deploy. Production HOLD.**
