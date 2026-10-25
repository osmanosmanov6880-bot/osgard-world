# EMPIRE Omega R39 - original physically animated wheel surface detail

An inspection of the actual Godot 4.4.1 car found a sculpted >1200-triangle
original body but simplistic alloy cylinders and little tyre surface detail.
R39 changes real vehicle art only (not the separately validated driving body):

- 4 actual machined brake rotor cylinder meshes, following wheel rotation
- 5 alloy fixing bolts per wheel rendered as one local MultiMesh
- 24 pieces of tyre shoulder relief per wheel as one local MultiMesh
- 4 independent wheel rigs stay controlled by original acceleration,
  steering and four actual raycast wheel-contact suspension samples.
- Each wheel pack exposes LOW (off), STANDARD (rotor only) and CINEMATIC
  (disc + bolts + grooves). The live car's existing update_headlights
  quality event controls every pack with no new per-frame game loop.

The added car is a genuine real-time mesh/LOD upgrade, not 8K textures,
hardware ray tracing, licensed Forza assets or calibrated rigid-body
wheel physics. Four extra meshes and eight instance batches are bounded,
with no added collision shapes, brake-force change, player saves or input.

Native QA loads the authentic drivable car, verifies all 4 rolling wheel
nodes, geometry counts, adaptive quality modes and original collision;
Godot Web export and four real Chromium image captures are release gates.
