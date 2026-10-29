# CITY REIGN R171 — TRUE OBJECTIVE FABRIC / VERIFIED CITY ROAD ROUTING
Source parent: R170 `471daad1262b21cf77f1a2631340c9c182e02390`; no source visual mock, no new UI application, existing Godot 4.4.1.

## Engine block 1: unified authoritative goal selection
A single pure `city_reign_goal_fabric.gd` now chooses all real road-map, 3D guidance and mission targets from one hierarchy: actual current driving-trial checkpoint, citizen errand, emergency service, existing commercial freight, then genuine spatial career missions. First car uses the LIVE 3D actual vehicle transform; market/city hall are the original known buildings, commercial cargo uses exact real ContractManager pickup/dropoff and recovers after interruption. It never routes 40 career menu-only actions to a random previously selected freight station. Every node is finite/within the actual city bounds, otherwise no invented waypoint.
No new mission, reward, save schema, price, fake traffic, geolocation or collision physics.

## Engine block 2: exact existing road A* integrity
Original city `ROUTER.find_route` remains the ONE closure-aware road algorithm. Newly added `city_reign_route_integrity.gd` verifies genuine start/end coherency, nonfinite, overlong or smuggled straight-line segments. The existing map, 3D on-pavement road chevron and drivable route overlay share exactly the one accepted polyline; empty or stale paths cannot draw fake infrastructure. Source switch triggers route recalculation immediately; genuine off-route at most once every 0.75 s; ordinary 1.25s CPU budget retained. Never creates a second pathfinder or autofollows steering.

## Engine block 3: truthful accessible play experience
Existing original Godot HUD receives an optional source category and displays a short RU/EN/ZH actual task type alongside real distance on spacious desktops; compact phone HUD and keyboard/touch interaction retain original minimal display. Reduces confusing instruction where an active freight job competes with a different career menu step. Source manager remains read-only, no background native performance drain.

## Quality gates
- Native v162: all 40 source mission catalog actions, real urgent side-task precedence, malformed inputs, exact existing vehicle and freight recovery, RU/EN/ZH, zero saved state mutation.
- Native v163: original real street graph, rejected nonfinite/spoofed/oversized/stale routes, immediate source changes, bounded off-route replanning.
- Native v164: load exact original full 3D game, test true in-world first car -> market -> nonspatial next mission, no stale 2D route or fabricated road arrows, original 12 cars/34 residents and economy intact.
- Preserve full R170, R169 audio, R168 atmosphere, R167 materials, original R55 504 save/corruption assertions, source-SHA generated HTML/JS/WASM/PCK and real Chromium/WebGL2 keyboard/viewport acceptance.
- Release remains gated by private double-green CI and then isolated exact-SHA SSH/public browser checks; no physical mobile FPS or AAA parity claimed.
