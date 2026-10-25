# NEBULA R38 — graphics profiles from a real mobile touchscreen

## Why this is needed

R36 gave phones an on-screen FPS benchmark. R37 provided an offline viewer
for reports comparing MAX/HIGH/ECO. But the game still required F3/F11 to
choose these modes, a physical keyboard many phones do not have.

## New interaction

Open NEBULA 3D on a phone. Tap **FPS** to open the existing performance
lab, then tap the new graphics-mode control. Each true touch advances:

**АВТО → MAX → HIGH → ECO → АВТО**.

- AUTO enables the R12 FPS-driven adaptive controller (8 s sustained low
  FPS for downshift; 35 s high FPS for recovery; 25 s cooldown).
- MAX/HIGH/ECO immediately call the **actual Godot graphics setters** for
  city cladding/LOD, PBR architecture, environment, lighting and airframe.
  Switching to manual disables AUTO so a 20-second hardware benchmark
  uses a stable profile.
- During the 2-second warmup and 20-second benchmark, the quality button
  is disabled. Desktop F3/F11 are also blocked during the benchmark.
- The same panel still offers 20 С, JSON and close. It uses the R35
  notch-aware safe areas, with an expanded 210px landscape panel to fit
  the new button without covering HANGAR/CAMERA.

## Evidence

Native Godot smoke runs AUTO→MAX→HIGH→ECO→AUTO through the **actual
Button.pressed signal** and checks the real scene quality and
`adaptive_r12.auto_enabled`. It then verifies the benchmark lockout.

A true Chromium/WebAssembly mobile scenario sends actual CDP touch events
to the new button: QA starts in ECO, switches to AUTO/HIGH, then MAX,
then starts the hardware-profiler UI. It measures no fictitious FPS
on a physical device.

## Honest bounds

CI validates gameplay, touch command delivery and quality transitions
on SwiftShader. It does not certify GPU performance on actual Android
or iOS hardware. Compare real on-device R36 JSON reports using the
locally running R37 `performance-report.html` viewer after collection.
