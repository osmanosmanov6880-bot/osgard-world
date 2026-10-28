# CITY REIGN R163 — STREET DYNAMICS / Actual Godot game

Parent: R162 647ed1b14ee8b42ee8a86e8b3e617c1d3ac47d98.
Godot 4.4.1, genuine 3D playable source, no generated illustrations.

## Three source-real changes

1. Ambient traffic convoy anticipation: existing 12 genuine CharacterBody3D vehicles now use bounded lane-aware following from the actual velocities and positions of neighboring traffic. An original physical collision raycast, traffic signal, funded crosswalk, weather grip and pedestrian yield ALWAYS remain authoritative; the new following module only LOWERS a safe target. Never spawns hundreds of physics objects or loops indefinitely.
2. Player-controlled amber indicators cancel after a real >=0.76-radian turn, >=5.5m physical movement, and steering re-centering. Right turns are negative yaw in the current Godot -Z-forward controller; hazard mode remains manual and is never auto-cleared. No economic or save-file changes.
3. One physically rendered low-cost road chevron is placed on asphalt after the nearest actual road graph corner (<70m) using R162 next-turn information; single 9-vertex triangle mesh, reused without per-frame allocation, no collision bodies. It disappears for off-route and non-spatial public policy missions. No newly downloaded images/textures.

## Performance
- MAX_NEIGHBORS=16 per moving AI vehicle, zero new physics ray casts.
- Turn indicator checks use values already computed by car physics, no raycast.
- Static arrow mesh created once, updated only on existing 1.25s path refresh; dynamically recolored by current graphics quality.

## Release discipline
R163 stays a draft engineering branch until the full original Godot, WebGL and desktop/mobile Chromium QA passes. SHA-locked isolated SSH release and independent public browser acceptance must be checked separately. Real-world phone GPU FPS and GTA VI / Forza graphics parity remain unverified.

## Native test suites
v138 car-following identity, gap and wetness; v139 turn-cancellation; v140 truthful physical road chevron; inherited v136/v137/v134/v135/v133/v129/v68/v72.
