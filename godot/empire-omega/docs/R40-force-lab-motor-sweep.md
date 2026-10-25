# HORIZON R40 laboratory calibration (not player vehicle)

Before this block, real A/B Godot compared the current arcade body at
19.16m with the independent force-based spring lab at 7.02m. The experiment
cannot replace the player car.

New native Godot test performs six consecutive physical spring settle,
acceleration and braking experiments at motor multipliers 1.0, 1.4, 1.8,
2.2, 2.7 and 3.2. Every run uses the same authentic 300m native road, 140
settle frames, 120 drive frames at 72% command and 90 brake frames. Each
one records real contact count, distance, velocity, spring force, and braking.
The target arcade distance/speed comes from the existing v49 A/B JSON.

A separate wet-grip trial uses 65% road traction for the measured best
motor, never a manually invented FPS or physical speed-up. The report
records normalized mismatch and the best observed tuning candidate,
but intentionally does not auto-change the lab default or production game.

The normal playable vehicle still uses CharacterBody3D, with all mobile
controls, missions, saves and published WebAssembly intact. Further work:
tire combined-slip, reproducible curves/surface transitions, force/yaw
parity, and real-device FPS+thermals before any reversible migration.
