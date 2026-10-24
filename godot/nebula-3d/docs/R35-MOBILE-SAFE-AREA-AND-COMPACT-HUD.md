# NEBULA R35 — real safe areas, short portrait controls and premium mission HUD

## The actual UX defect

R34 correctly sent real multi-finger browser touches to Godot, but the
R21/R32 HUD still positioned its nine controls against the outside edges
of the browser viewport. That can hide GAS, camera or the steering pad
behind an iPhone-like camera cutout or a bottom OS home gesture bar.

The old two-column portrait action layout also cannot fit very short
320×480 browser viewports without crowded upper commands and HUD overlap.

## Implementation

- Full-screen canvas and true Godot 3D scene **remain unchanged**.
- An early, non-visible JavaScript CSS probe reads actual values of
  `env(safe-area-inset-left/top/right/bottom)` in CSS pixels.
- The probe avoids guessing the device name, model, operating system or
  devicePixelRatio. Values are clamped to the range 0–96 CSS pixels.
- `mobile_controls_r21.gd` reads safe areas through JavaScriptBridge,
  recomputes touch hit centres and cancels any active touch whose region
  moves due to a system-bar/notch layout change.
- Full-size portrait keeps the original two-column HUD.
- Compact portrait moves all nine independent commands into a 3×3 group
  to the right of the joystick.
- Short landscape (including 568×320) keeps the left joystick and
  two main action rows, with the autopilot above and the mission panel
  narrowed to avoid covering touch targets.
- All original R34 anti-stuck touch safeguards remain, including
  touchcancel, blur, pagehide, resize, orientation and hangar.

## QA acceptance

| Viewport (CSS pixels) | Simulated safe area L/T/R/B | Native Godot assertions |
|---|---|---|
| 390×844 | 0/62/0/34 | normal portrait, 9 independent actions |
| 568×320 | 59/0/59/21 | safe short landscape, unobstructed GAS |
| 568×320 | 59/60/59/34 | severe cutout, hit circles still inside safe rect |
| 320×480 | 0/62/0/34 | new compact portrait 3×3 map |
| 280×420 | 0/55/0/34 | small compact portrait map |
| 844×390 | 0/0/0/0 | full landscape, original hit targets |

Native tests check real `_role_at` hit-testing, nonoverlap among all nine
commands, separation from steering, release of THRUST, and HUD vs HANGAR
bounds. Safe areas in this *native matrix* are simulated to exercise known
geometries, **not** measurements of a physical iPhone.

Browser acceptance runs the real Godot WebAssembly export with Chromium
mobile CDP touches: portrait 390×844, landscape 844×390, and short portrait
320×480 must deliver real throttle and release through the browser DOM
bridge. The test separately reads the live CSS safe-area probe; hosted
Chromium normally reports zeros because it has no physical camera notch.

## Unverified hardware properties

Do not claim Android/iOS hardware performance, a real safe-area cutout test
on Safari, battery usage, thermal throttling or sustained physical GPU FPS.
Godot's F7 benchmark remains the proper local measurement on a real device.
The SwiftShader readback job is advisory and never counts as successful
hardware visual QA.
