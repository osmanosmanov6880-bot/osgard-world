# EMPIRE Ω — R32 CINEMATIC CITY & DRIVING

## The real screenshot defect
The desktop governor cabinet used a 900×730 centred box and a 0.88-opacity
black scrim. It hid the driving world and made even correctly rendered
geometry appear almost black. The layout was also a long, hard-to-navigate
list of operations.

## Actual Godot 4.4.1 implementation
1. Desktop 1024px+ governance becomes a dock, at most ~55% of screen width
   including its left margin, leaving the vehicle and world unobstructed.
   Mobile/tablet retain scrollable modal geometry and existing input protection.
2. Scrim alpha changes 0.88 → 0.32. UI uses restrained brass-on-charcoal,
   accessible button states, clearer large headings, scroll-safe long actions,
   live treasury/wallet/net cards and PULSE/COUNCIL/ECONOMY/DISTRICTS navigation.
   RU/EN/ZH remain supported. All existing game decisions remain callable.
3. Weather-aware Godot sky/ambient grading raises dark tones. No faked 8K,
   ray tracing, costly postprocessing or external render assets. Existing
   LOW/standard/cinematic tiers and mobile adaptive quality remain available.
4. R29's **real** 72 GPU-instanced puddle positions now control tyre grip:
   at the centre of a puddle a rainy-road grip of 0.80 becomes 0.672, with
   a smooth falloff at its edge. Dry roads remain unchanged; LOW hides only
   graphics, never the physically simulated wet patch. Higher braking
   distance comes from the current real CharacterBody3D tyre model.
5. No saved state, economy, payouts, collision shapes, account data or
   authentication are changed. This is a physically motivated, bounded,
   kinematic approximation, **not** a VehicleBody3D/Chaos/Forza wheel solver.

## Acceptance gates
- Native R32: UI instantiated, 4 desktop/3 compact resolutions, real policy
  controls, colour grade and tyre deceleration over puddles.
- Existing native: R7 layout, R15 graphics, R18 sky, R21 driving, R29 puddles.
- Genuine fresh Godot WASM/PCK; 4-viewport real Chromium rendered-pixel
  acceptance; existing two-finger/mobile control E2E and native regressions.
- Merge only after applicable green CI. VPS requires an exact SHA-verified
  published export; a green PR test does not prove the public server is updated.
- FPS, heating and touch-to-photon latency on physical Android/iPhone are
  **not measured** by GitHub's software GPU. Require 3 runs each on real phones.

## Forward quality bar
A future AAA visual pass needs licensed high-quality building/car geometry,
authoritative art direction, curated PBR texture sets, GPU profiling and
device-specific LOD/collision tuning. A future full physics pass requires a
separate wheel dynamics experiment before replacing this shipped arcade car.
