# CITY REIGN R178 — REAL INTERSECTION RIGHT OF WAY

**Parent:** R177 original game commit \`a21d63f101f9f0a7ae6b6f0a845a42840b7192db\`, independently 2/2 GitHub CI SUCCESS.

## 1. Real amber, red and wet stopping for 16 existing junctions

The original Godot \`TrafficSignalGrid\` runs 24-second coordinated phases at the **same 16 original road junctions**. Until R178 it showed physical AMBER lenses before changing phase, but its ambient-car permission logic still treated amber as green. R178 changes that one authoritative permission and adds a pure, bounded \`city_reign_intersection_policy.gd\` that reads \`signal_controller.elapsed\` directly. It locates each **actual stop bar** 8m before the existing physical intersection and respects same-lane width. It never freezes NPCs already beyond the stop line. The \`traffic_agent.gd\` applies a lower bound using EXISTING \`TrafficSafety.safe_speed\`, including wet road traction, after the original raycast, convoy/pedestrian detection and corner limits. Its yellow-light dilemma-zone rule permits passage only when braking in the available distance is physically impractical; **RED always stops** before the actual stop bar. There are still exactly 12 ordinary NPC traffic cars. No new physics, population, vehicles, money, policy, collision proxies or teleportation.

## 2. Actual in-world source-authored road markings

A single procedural **64-instance MultiMesh** paints four source-truth stop bars at each of the 16 existing junctions. Two additional GPU batches hold the original 32+32 approach reflector strips for the X and Z directions. Material phases come from the **same original traffic signal timer**, not a secondary animated mockup, and actual saved municipal electricity / day-night time determines whether these native PBR metal markers emit at night. LOW keeps one white marking draw and disables two premium batches. All are authored in source as actual Godot mesh instances, no external image/texture/video; ZERO collision bodies, ZERO shadow casting, no lane changes or road graph changes.

## 3. Native driver awareness and live pedestrians

The original 4Hz driver awareness scan now optionally warns of the same actual approaching red or amber signal in RU/EN/ZH, without changing human car controls and without overriding a truly urgent collision warning from a walker or vehicle. A waiting pedestrian now truthfully publishes \`planned_velocity=Vector3.ZERO\`, rather than claiming to be walking while yielded; existing R47 real-trajectory intersection prediction continues unchanged.

## Automated QA and honest scope

- \`v183\`: deterministic real 24s phase, amber, wet safety, stop line, lane, yellow dilemma zone, driver warnings and NaN fail-closed
- \`v184\`: native 16-junction source scene, 3 real GPU batches, lamps/stop bars agreement, LOW, city power and zero colliders
- \`v185\`: full native original 3D main scene, actual NPC CharacterBody3D red brake and green release, 12 cars/34 citizens, source owner untouched
- Inherit all R177–R169 native original 40-mission, vehicle and save tests and full real Chromium/WebGL2 export and camera/drive source-SHA checks.
- **No claim of photorealism, certifiable traffic simulation, phone FPS, human playtest, commercial launch or live public production release.**
- Remains a draft integration PR until the new SHA independently passes two complete CI runs; public R170 is untouched.
