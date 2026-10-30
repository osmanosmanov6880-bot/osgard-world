# CITY REIGN R181 — ORIGINAL PHYSICAL SIDEWALK ROUTING

Parent: R180 original true pedestrian WALK/WAIT, candidate exact SHA \`18609a23cf4abcb218baf556901e01b6c547fc74\` (strict native regressions PASS).

## First-person player quality / world simulation
The original city has 36 actual native 3D sidewalk lip strips at x/z road center ±6 metres, but pre-R181 walkers traversed the **centres of car lanes**. R181 gives all 34 genuine \`PedestrianAgent\` characters real reproducible sidewalk walking routes rather than adding more mock citizens or an animation.

1. Original \`MOBILITY.find_route\` remains the **ONLY** A* planner. City road closures, open roads, source quest travel and citizen daily home/work/leisure plans stay authoritative. The new pure \`city_reign_sidewalk_routing.gd\` projects only real immediate adjacent 52m road-grid walking legs onto the corresponding original WorldBuilder sidewalk meshes at 6m left/right. Different resident IDs deterministically choose different sidewalks. Corners are joined around the actual sidewalk lips at 6m x 6m intersections rather than cutting diagonally through building blocks. Building endpoints remain unchanged and nobody teleports.
2. A future/invalid, incomplete or non-grid path cannot fabricate a new traversable road. No new road coordinates, car routes, physics colliders, nav meshes, mission flags, rewards, account telemetry or external art. Geometry and output length are bounded, low mobile mode unchanged.
3. R180 walker right-of-way now includes the real 6m city sidewalk offset while excluding unrelated 8m outer lanes. True physical citizens wait for original RED / too-late GREEN, continue on valid WALK, and clear inside-road transitions. The original 12 vehicles keep their physics, the 34 visual residents keep their single original 3D mesh and predictive car-yield rules.

## Native regression gates
- \`v192\`: original 9x9 grid, 52m leg bounds, +6/-6 genuine sidewalk placements, proper 90-degree corner, no fake edges / NaN teleport, deterministic 2-sided routes.
- \`v193\`: original closure-aware A* route, actual saved source road closure avoidance, physical sidewalk route contains source waypoints without re-routing closed edges, WALK/WAIT now at offset6.
- \`v194\`: actual entire native main.tscn, visible original 36 WorldBuilder sidewalk meshes, 34 original agents and 12 collision cars, source physical sidewalk movement on red/green, unchanged original economy/missions.
- Complete inherited R180–R169 strict native Godot 4.4.1 / 40-mission/regression, WebGL2 build and real Chromium original driving/camera/source-SHA checks, screenshots/log evidence.

**No independent claim of AAA GTA-grade visuals, commercial launch, uncoached human playtest, native phone FPS or public deployment.** Draft source only.
