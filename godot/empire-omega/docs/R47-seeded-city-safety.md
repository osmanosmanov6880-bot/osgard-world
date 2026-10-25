# EMPIRE Omega R47 — reproduce urban pedestrian safety

The live city already has predictive yielding and physically colliding traffic.
This verification block runs the existing logic in real Godot 4.4.1.

Protocol: five RNG seeds times 40 geometric trajectories = 200 analytic
cases across approaching, retreating, adjacent-lane and crossing-walker
scenarios. In addition the actual CharacterBody3D traffic and pedestrian
agents run against one real StaticBody3D roadblock for 240 physics ticks;
the vehicle must stop without tunneling and pedestrians must yield only
when the nearby vehicle is moving.

Every input, clearance, wet/dry safe speed, and predicted yield is reported
as JSON and separately checked by a strict Python validator.

IMPORTANT: 200 geometric predictions are NOT 200 live-physics collision
worlds. Only ONE actual 240-tick obstacle scenario was executed. The
record explicitly does not claim full crowd simulation, physical-phone
FPS, human-safety certification, or production AI enhancements.

Next: more physical crossings, traffic-light schedules, saved-state city
simulation and reproducible mobile device benchmarks before production
release R50. No gameplay or production server files changed here.
