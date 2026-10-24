# OSGARD R135 W9 — a playable guided diagnostic chapter

W9 is stacked on W8 adaptive HUD QA and W7 studio scene. It changes **the educational experience**, while retaining the tested W5 safety interlocks and original HERO/ECO meshes.

## Implemented

- Each of three simulated faults produces a unique clue displayed during play:
  - Optical alignment: synthetic edge-offset reading
  - Cooling airflow: synthetic low-flow reading
  - Service interlock: synthetic unsealed contact indication
- Every clue is explicitly marked `(SIM)`; these are educational game values, **not real sensor measurements**.
- The player's actions remain physical-interaction buttons: stop drive → open hatch → choose view → scan → close hatch → restart. No scene can bypass the stop/lid interlock.
- After an inspection, the operator HUD explains the safety lesson in words; success is not conveyed by a light color alone.
- Save per-case completion flags to the local Godot `ConfigFile`. A player who completes all three scenarios sees `ALL 3 SIMULATION CASES CLEARED`. This is **not** a professional qualification or certificate.
- Expose the score penalty breakdown (simulation duration and wrong-action count) so the player understands why a score was reduced.
- Native smoke test completes three different faults and asserts three distinct cases were stored, clue evidence is labeled simulated, and the scoring explanation matches the actual error count.
- Touch browser smoke verifies that a successful simulation registers learning progress.

## Test and delivery policy

- Godot 4.4.1, genuine desktop/mobile WebGL, real UI controls and Nginx WASM/PCK range checks are mandatory.
- W7 and W8 must be validated and merged first. W9 PR targets W8 branch; never force-push across concurrently edited `master`.
- All physical-device FPS, long-duration thermals and cinematic fidelity are separate non-automated release gates.
