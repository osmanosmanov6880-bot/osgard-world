# CITY REIGN R165 — APEX DYNAMICS / TRUE VEHICLE RESPONSE

**Base:** source-verified public R164 767a64fe530831d4636dbb26db81e4a41ac7cc04
**Engine:** original Godot 4.4.1 GL Compatibility / WebGL2, CharacterBody3D
**Scope:** actual interactive player vehicle, PBR car/cockpit, HUD, native performance and road tests.

## Three major code improvements

1. Actual driver brake response. Positive and reverse pedal inputs control the same original motor/brake model; when applied opposite to ongoing road motion, brake effort now ramps at a bounded exponential response (16/s build, 11.5/s release). The existing handbrake maintains immediate priority. Reverse remains available from a real stop, and all GameState financial and campaign authority remains untouched.
2. Combined braking/cornering load budget and torque response. Under simultaneous hard braking and fast steering, the previously capped Godot yaw rate is conservatively reduced by a bounded grip-reserve heuristic. At motorway speeds, available throttle effort trims smoothly by at most 19%; zero-speed launch and original driver assistance remain. No VehicleBody3D migration or unverified certified real-world tyre-force/ABS claim.
3. GENUINE physical visualization: source-author-created analog dashboard tick triangles share the original dashboard draw surface, the original speed needle reflects actual brake input, and the original glowing rear brake light adjusts intensity as the ACTUAL gameplay brake response evolves. Original three interior meshes, no additional collision, shader, GPU draw call, dynamic shadow, audio download or persistent preference.

## Quality / constraints
- Native v143 multi-rate 30/60/120 Hz dry/wet deterministic trace; v144 genuine full real road floor, source vehicle, Godot input actions, 4-wheel contact, speed decay, brake emission and GameState unchanged; v145 90 native cockpit frames and mesh-resource identity, visual response, original shell restoration and 3 localized strings.
- Historical v21 original speed / gear; v27 native driver aids; v67 native four-wheel load/grip and ALL R164/163/162/161/160 and 40 mission/save regressions.
- HTML/WASM/PCK source SHA-256 and real Chromium physical game frame tests in private CI.
- SSH shipping may happen ONLY after source-locked immutable SHA full QA PASS, atomic upload to only /games/city-reign, public file digests and independent desktop/mobile LIVE WebGL2 gameplay test PASS; rollback isolated to CITY REIGN.
- Visual target: a more responsive, believable driving interaction within the original Godot game, not GTA VI/Forza-equivalent PBR production. No physical Android/iPhone FPS claim.

## Clarification
The input-based response does not sense wheel rotational slip, cannot modulate wheel braking torques, and MUST NOT be advertised as an authentic hydraulic system, production ABS, ESP or experimentally validated stopping distance. The older R46 distance remains a numerical idealized diagnostic only.
