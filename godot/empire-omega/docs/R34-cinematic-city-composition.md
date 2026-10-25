# EMPIRE Ω R34 — grounded city composition

## Problem confirmed on real R33 Chromium screenshot
The authentic Tab-open government cabinet is now left-docked and readable, but
the road scene behind it remains heavily top-down. The 3D view resembles a
topographic/roof map instead of an approachable street-level world.

## Actual Godot 4.4.1 change
- A desktop-only camera presentation at 0.22 radians or lower with a 1.2m
  look-forward offset to expose street depth and building faces.
- The original cam_pitch and cam_yaw are never rewritten; closing Tab resumes
  the user's camera preference automatically.
- The existing safe raycast/collision solver and frame-time smoothing still
  own the camera position. No teleport, velocity, physics or mission changes.
- Portrait phone, short landscape mobile, and reduced-motion preferences
  explicitly disable the automatic cinema shot.

## Acceptance
- Native R34 camera state regression on desktop/mobile/accessibility,
  non-finite inputs, loaded main scene, and safe raycast path.
- Existing R20 camera, R33 wheel physics, R32 HUD and R29 rain regressions.
- A true Godot browser UI screenshot after opening Tab; art quality still
  requires licensed assets, material work, vegetation and pixel-level review.
- Do not call it ray tracing or AAA physical fidelity. Production publication
  only after all release gates and public SHA-256 checks.

## Intermittent real Chromium screenshot timeouts
On the exact R34 head, the desktop SwiftShader compositor intermittently
stalled during screenshot capture (CDP, canvas copy and Playwright all reached
their bounded timeouts). R34's dedicated 1366x768 actual Tab-open scene and
R12 four-viewport acceptance passed separately; R33/R27 browser probes failed
in other runners on screenshot extraction after valid asset imports.

Both browser test configurations now permit **one bounded fresh-worker retry**.
The same original Godot WebGL scene must be fully reloaded and all actual
PNG pixel, world brightness, four viewport and Tab-open dock assertions must
pass on a retry. No stale screenshots, dummy pixels or test skips are allowed.
Failed attempts are still documented in the GitHub Actions test reports; a
second failure blocks merge. This addresses known screenshot nondeterminism,
not GPU FPS or the need for physical mobile-device profiling.
