# EMPIRE Omega R38 - real GPU-batched junction furnishings

Actual 52m road lattice (9 x 9 intersections) gets original small real
3D street features:
1. 324 solid curbstone transitions on pedestrian-side corners
2. 648 road-flush storm grates at the outer drive edge
3. 324 metal pedestrian bollards outside driveable road strips
4. 324 contrasting steel caps

All four categories use single global MultiMeshInstance3D batches with
instance colors and bounded mesh counts. No added static vehicle collisions,
no new player controls, no nav graph changes and no per-intersection nodes.
The existing world_builder -> horizon_roadscape pipeline creates the
new details in original Godot runtime, not in generated concept art.

LOW suppresses all four groups; STANDARD hides the smallest metal caps;
CINEMATIC displays them. This visual tier never changes four-wheel tyre
traction or physical hit geometry. Native acceptance instantiates the actual
world and validates all GPU batches and quality transitions.

No claim that these simplified procedural roadside meshes are AAA-quality
assets. Dedicated expert modeling, surface scans, visual LOD profiling and
physical iPhone/Android FPS are separate release requirements.

R38 detailing upgrade: storm-drain grates use five sculpted rails in one
shared procedural ArrayMesh. Slots are real openings between bars, not a
single painted rectangle; 648 placements stay inside the same one GPU batch.
Native acceptance validates the mesh vertex budget, placement count, road
height and LOW/CINEMATIC visibility. Real WebGL four-viewport pixel QA is
also required; neither a screenshot nor Godot headless alone proves FPS.
