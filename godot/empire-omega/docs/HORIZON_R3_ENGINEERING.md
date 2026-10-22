# OSGARD HORIZON DRIVE R3 — real implementation, not a promotional rendering

This original Godot 4.4.1 source implements:
- Semi-arcade, deterministic **lateral tire slip** on top of the existing longitudinal bicycle/yaw simulation: velocity now retains sideways momentum rather than snapping to heading each frame.
- Weather and handbrake reduce lateral damping. The existing grip-limited yaw and forward brake/reverse safeguards remain.
- Four ground probes (physics raycasts) feed cosmetic independent wheel travel. A critically damped spring animates the original PBR body as it rolls and pitches; **this is not a full multibody physical wheel/suspension simulation**.
- True gameplay drift chain: after sustained controlled oversteer, validated score grants 5–55 in-game credits once; State reward journal and all existing saves remain compatible.
- Deterministically generated, seamless asphalt and sidewalk albedo/normal textures (128 x 128, built in Godot). Triplanar UV mapping avoids stretching across original roads.
- Native Godot regression test v25 covers numeric limits, wet versus dry grip, reward anti-farming, chassis spring, PBR textures and actual vehicle binding.

Acceptance: import, 21 native regression tests (plus dedicated visual capture), authentic Web export, GitHub checksum validation and SSH activation to production. Windows Forward+ build is independent. No Forza code, models, trademarks or content are included. **This is an iterative stylized game, not yet Forza Horizon 5-grade rendering.**
