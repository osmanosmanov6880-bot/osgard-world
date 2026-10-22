# OSGARD PLAY — TIME EMPIRE / CHRONOS CITY v0.1

An independently testable **native Godot 4.7.2** strategy prototype. It **does not replace** the large production `/games/empire-orbit/` HTML game and does not inherit its existing save format. This is the first isolated gameplay slice for the approved Anno / Frostpunk-inspired cinematic future city. The visual style uses original procedural geometry, not artwork from reference games.

## Interactions already built

- City with a 3D animated chrono reactor, lights, GPU-instanced skyline, metal microtextures, districts, transportation rings, real camera orbit and zoom.
- Time currency: begins at 180 units, generates 2/sec, persists when building and upgrading.
- Build chrono districts in actual open city plots; each new district boosts time production by +3/sec.
- Upgrade the reactor; each core level adds +2/sec.
- Map/city camera switch, mouse drag orbit, mousewheel zoom and keyboard shortcuts.
- Russian-first high contrast HUD: objective, time balance, income, three controls. Mobile widths hide secondary panels.
- File-based local save/load with validation and recovery bounds.
- Godot 4.7.2 runtime regression tests for build/resource changes, map camera and persistence.
- Godot Web export only after passing tests; CI zip artifact, **not a production publication**.

## Run

Install Godot 4.7.2 and open `godot/time-empire/project.godot`, then use F5. For native tests: `godot --headless --editor --path godot/time-empire --import --quit && godot --headless --path godot/time-empire --script res://tests/runtime_smoke.gd`.

| Input | Gameplay |
|---|---|
| Build button / B | Build the next district |
| Upgrade button / U | Improve the chrono reactor |
| Map button / Tab / M | Toggle overhead map |
| Left mouse drag | Orbit the city |
| Mouse wheel / Up, Down / W, S | Zoom |
| Left, Right / A, D | Rotate |

This is a functional Godot vertical slice with procedural original art, not a false claim of photorealistic AAA content completion. Approval of screenshots, art passes, performance and functional parity is required before integrating with existing Empire saves and production route.