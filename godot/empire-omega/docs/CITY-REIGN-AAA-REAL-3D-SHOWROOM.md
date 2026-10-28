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

## Dedicated REAL source-pixel browser acceptance (not game release)
- `tests/city_reign_real_showroom_visual_fixture.tscn` plus its `.gd` actor is a clearly labeled TEST-ONLY startup. Production `project.godot` remains unchanged in Git; only the ephemeral CI checkout changes `run/main_scene` for the isolated fixture export.
- `scripts/city-reign-aaa-real-showroom.spec.mjs`: real exported Godot 4.4.1 WASM + native OpenGL rendering under Chromium, original `HORIZON_BODY` and actual connected studio World3D.
- Accept actual rendered car PBR pixel variation, then switch compact → utility by real key input and demand a meaningful real RGB pixel difference, then rotate the real turntable by exactly 15 degrees and demand a different real frame.
- Upload actual raw WebGL/Chromium PNGs and measured JSON diagnostics. Never accept an unchanged screenshot, missing graphics, static HTML mock or image-generation substitute.
- This proves a software-Mesa-browser scene rendering, **not** physical desktop GPU/mobile FPS or a human AAA art signoff.

## A14–A15 — source-native architecture / physically based reflective studio
- **Real solid stage**, not a screenshot: 72 machined annular sectors and 12 gold tick marks in one real original 504-vertex ArrayMesh, one original satin-black backdrop mesh, and 7 individually positioned metal louvres in one GPU MultiMesh batch. Existing actual physical podium stays. All three additional draws are shadow-free and collision-free.
- **Real metallic reflections**: use one fully procedural Godot `ProceduralSkyMaterial` as a `Sky` reflection source against the original charcoal environment. No licensed .hdr download, GL-incompatible SSR or second cubemap import; no claim of ray tracing.
- **Interactive cinematic lighting**: separate native RU/EN/ZH touch/keyboard-accessible DAY/NIGHT controls; physically changes studio key/fill DirectionalLight3D colors/energy, ambient intensity, original brass stage emission and requests one GPU frame. No autoplay, no blinking or time-based workload.
- **Real mobile optimization**: no GPU studio until a phone user inspects; low tier disables preview; compact hides both architectural backdrop meshes and only retains real 3D car + inlaid stage ring.
- QA: `v118_city_reign_aaa_native_studio.gd` source-native unit and runtime assertions, plus standalone real Chromium WebGL compact/utility/turntable/**night illumination pixel delta** with source screenshots and no fake render substitution.
- Commercial photoreal AAA quality, artistic approval, physical phone and desktop GPU fps and licensed production car art remain **HOLD**.
