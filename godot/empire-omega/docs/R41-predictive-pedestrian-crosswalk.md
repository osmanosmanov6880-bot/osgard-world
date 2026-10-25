# EMPIRE Ω R41 — predictive pedestrian crossing safety

Actual original Godot city pedestrian proxies formerly stopped whenever a
moving NPC vehicle was in a crude 6-8m radial circle. This stopped residents
even when a car was on another lane or already moving away.

R41 now solves closest approach between the *actual* pedestrian route
velocity and the horizontal velocity of real traffic/patrol and player-car
entities. The finite horizon is 2.4 seconds, the collision margin 2.8m, and
the computation has an 80m guard. Stationary cars remain traversable so a
road queue does not freeze residents. Cars on adjacent lanes and vehicles
retreating from the crossing do not halt pedestrians.

No per-pedestrian physics collider has been added: the original traffic
safety system still brakes for walkers inside actual drive lanes. This is a
predictive arcadey avoidance model, not a full crowd simulator or a human
safety guarantee. All mission data, navigation graph, saved games and
player-car controls remain unchanged.

QA: real Godot 4.4.1 2-route tests, future collision/retreat/lane separation,
active pedestrian and CharacterBody3D traffic instantiation, invalid
coordinates, unchanged main script. Genuine WebAssembly export and four
Chromium viewport pixel tests needed before merging. Physical phone FPS and
heat are not inferred from CI.
