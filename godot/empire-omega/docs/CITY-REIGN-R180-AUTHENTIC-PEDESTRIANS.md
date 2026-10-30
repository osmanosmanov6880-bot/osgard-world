# CITY REIGN R180 — WORLD PEDESTRIAN RIGHT OF WAY

Source parent: R179, exact \`210214e230fd82c7361fe918bc65bde5896139d3\`, independently 2/2 CI SUCCESS.

## Gameplay, not decorative screens

1. **Actual original 34 street residents:** each existing \`PedestrianAgent\` reads the original \`TrafficSignalGrid.elapsed\` through a reference supplied by the original Main scene. Their existing route, work/leisure schedules, collision-yield trajectory, 3D body, AI car detection and physics layer are preserved. A finite-safe \`city_reign_pedestrian_right_of_way.gd\` evaluates the **16 actual road intersections** and the **same source stop line** used by actual AI cars. A pedestrian approaching the road gate 8–14m before a junction on a conflicting RED/AMBER stops physically; \`planned_velocity\` becomes zero. On GREEN, crossing is permitted only if **enough real seconds remain** to complete the actual 9.9m road crossing plus sidewalk approach. Citizens already inside the crossing (past 8m) finish rather than freeze under newly changed signals; the existing live car-collision forecast remains independently conservative.
2. **Physically authored 3D WALK/WAIT signal network:** add two actual directional native crossing heads to each of the same **16 intersections**. WALK sculpted people and WAIT raised hands are each original 3D source-volume meshes, **not generated images, fake UI, photorealistic assets or external licensed models**. All are one-cached-surface shared meshes across **5 real MultiMesh GPU batches** (32 housings, 32 WALK shapes, 32 WAIT shapes). No added colliders, shadow draws, vehicle AI, roads, new citizens, physics bodies or per-frame mesh allocation. Walk/Wait LEDs follow the existing clock and saved municipal electricity + day-night. LOW disables all five decorative batches without disabling actual walking safety. 
3. **Real source integrity, no reward or save changes:** the same R178 original 16-junction phase clock drives physical AI vehicle braking, player red violations, 34 pedestrian movements and real GPU crossing signs. No new persistent fields, unauthorised camera or network telemetry. City budget, 40 missions and original native driving remain owned by the original GameState.

## Engineering verification

Native Godot 4.4.1: \`v189\` phase/walk geometry/finite/safety; \`v190\` true 16-junction five-GPU-batch sign and electricity integration; \`v191\` complete original native 3D game and real pedestrian movement on RED/GREEN/late GREEN and mid-road crossing, while original wallet/mission/save remain untouched. Full inherited R179–R169 native regressions, strict source import, authentic WebGL2 export and real desktop/mobile emulated Chromium camera/controls and SHA evidence.

**No claims** of human 5–10-minute playtest, native phone FPS, photorealistic AAA art or public production release. Draft PR; public R170 untouched. Final PASS only after GitHub CI confirms exact release SHA.
