# CITY REIGN R169 — AUTHORED ACOUSTICS / REAL COCKPIT FEEDBACK
Parent: R168 `feat/city-reign-r168-atmospheric-optics-20261029`. Source: original Godot 4.4.1 game `godot/empire-omega`.

## Three source-only engineering blocks
1. Source-generated 16kHz mono PCM16 harmonic load + deterministic filtered asphalt-grain loops. Exactly two extra native `AudioStreamPlayer3D` attached to the ACTUAL physical vehicle; existing five sound players retained. No copyrighted recordings, procedural runtime audio threads or network calls.
2. Physical cue envelope: actual W throttle, speed, wheel lateral slip, rear contact/grip, real game rain/storm, current graphics tier and cockpit camera. Original R19 exponential envelope, smooth stop on car exit. LOW suppresses extra voices; no changes to torque, grip, player balance or missions.
3. Reuse the existing exactly THREE original R164 3D cockpit meshes. Steering wheel now reacts to actual lateral slip at at most 0.028 radians and brake lean within 0.012m. Reduced motion sets both responses to zero instantly without jarring driver camera or adding GPU geometry.

## Release validation
- `tools/verify_r169_audio.py` tests the actual generated assets (signed PCM16 mono, sample rate, size, energy and loop seam) before importing/exporting Godot.
- v156 original native 3D audio players, source WAV and bounded original car attachment.
- v157 real 3D player motor/tyre sounds: grip/weather/cabin, nonfinite, LOW/exit fades, exact live original player code.
- v158 genuine 3D cockpit tactile function, reduced motion, mesh resource identities, save-state isolation.
- Original R19 audio v42, R164 camera, R165 cockpit HUD, R166 road and R167 car art, R168 weather, entire existing 40-mission/corrupt save suite, real WebGL2 Chromium source-SHA acceptance.
- Only a passing *immutable source* can enter isolated SSH release and public Chromium acceptance. CI is not public deployment.
- No claims of studio-produced real car recordings, GPU-perf on phones or GTA/Forza parity.

Next R170: 5–10 minute genuine first-episode gameplay with objectives, retry and progress recovery.
