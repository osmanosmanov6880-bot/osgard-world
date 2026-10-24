# EMPIRE Ω R33 — per-wheel road wetness and genuine night light

R32 linked 72 genuine instanced puddles to grip using the body centre. R33
uses the four wheel-ground physics-ray positions in LF/LR/RF/RR order.
Supported wheels influence total friction and front/rear axle wetness
independently; airborne wheels contribute zero. Rear tyre friction changes
the existing lateral slide model while total tyre grip affects steering
and braking. LOW graphics hides puddle polygons but never changes physics.

Two actual Godot SpotLight3D beams illuminate the road at night. Shadows are
disabled, range 19m, cone angle 34 degrees. Daytime or LOW disables the
expensive spot lights; STANDARD lowers energy. Existing geometry remains.

This is a bounded CharacterBody3D kinematic tyre approximation, not a
validated AAA rigid-body tyre model. Hardware phone FPS and p95 are still
unverified until actual physical-device testing.

## Required acceptance
- Native R33 v55 test plus R32 v54 and real R21/R29 regressions.
- Actual Godot WebAssembly export from fresh source and 7/7 public SHA.
- Chromium screenshot and touch-drive E2E after server activation.
- Never merge or deploy on failed tests or stale release checks.
