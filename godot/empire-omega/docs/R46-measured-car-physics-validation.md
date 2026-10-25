# EMPIRE Ω R46 — measured physics before migration

## Engineering intent
Do not replace a working arcade CharacterBody3D car with an uncalibrated
RigidBody3D vehicle on the strength of pretty screenshots. The existing
independent R24 and R40 labs are real Godot physics experiments, but R40 only
compares forward distance and speed under differently transferred inputs.
R46 adds a repeatable **live 60 Hz Godot A/B laboratory** under a common
flat road, same phase durations and dry / wet / repeated-dry inputs.

### Test protocol (Godot 4.4.1)
- For each trial: 140 physics ticks settling, 108 forward ticks, 72 turn
  ticks, 48 braking ticks; physical state measured from actual nodes.
- Dry (grip 1.0), wet (0.65) and a repeated dry run with identical RNG seed.
- Both cars run in parallel on separate road lanes. Data includes travelled
  horizontal metres, speeds before/after braking, yaw, at least two supported
  springs, maximum roll/pitch and angular speed. Non-finite states fail.
- Rigid candidate uses **2.2 motor multiplier only inside the lab**.
- JSON with real measurements is validated independently by a Python gate.
- The two engine input transfer functions are still different, so the report
  MUST NOT claim matched identical real-world physics or approve production
  replacement. Physical-device handling and frame-time measurements remain
  unperformed. A visually perfect trace says nothing about tyre accuracy.

### Release gates
1. New Godot native suite R46 and independent schema validation succeed.
2. Existing v21, v47 and v49 native regressions stay green.
3. For a production RigidBody3D migration, further calibrated equivalence
   requires matched speed profile, braking distance, yaw response, identical
   real contacts, collision/save compatibility, controllability and sustained
   Android/iOS hardware testing.
4. No migration authorization is contained in this PR. Frontend, Godot live
   controller, server assets and VPS deployment remain unmodified.

**Verdict: VALIDATE.** Do not label physics AAA until quantitatively proven.
