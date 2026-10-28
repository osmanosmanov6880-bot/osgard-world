# CITY REIGN R162 — DRIVE INTELLIGENCE

Engineering branch: feat/city-reign-r162-drive-intelligence-20261029
Parent verified native: R161 310afeb5766154065dc3efadd4c9fdf4591e19d1

## Real gameplay changes
1. Road navigation is measured along the actual street_router / city_mobility route, NOT Euclidean distance. The R161 world asphalt line and the original minimap share that route. Warnings about turns are only derived from physical road-grid segments; building connectors never get painted as roads.
2. Read-only driver-awareness sensor checks the actual relative velocity and position of visible original traffic cars and pedestrian agents. The upper limits are 18 cars and 42 walkers, sampled no more than four times per second. It performs zero physics raycasts and has NO authority to steer, stop cars, issue fines, alter money or write saves.
3. The existing HUD now shows real next maneuver and distance while driving to a valid spatial mission. Active driving trials keep their previously authored navigation priority. On danger it temporarily highlights the real hazard using RU/EN/ZH.
4. Signals from R161 remain available; the speed instrument can show the actual left, right or hazard state.

## Non-goals / honest limitations
This is bounded arcade guidance, not LiDAR, certified ADAS or physical car realism. GTA VI / Forza visual quality is NOT claimed. A Chromium/WebGL CI pass does not certify frame rate on real phones. No SSH publication occurs on this branch. R160 remains publicly playable until an approved source-locked release.

## Release gate
- Native script import and v136/v137/v134/v135/v133/v129/v68/v72 Godot suites must pass.
- Private Godot Web export must preserve SHA-256 and source SHA.
- Actual Chromium must load and render gameplay and R160 camera changes.
- Only after QA, manually review PR and the R160 release gate; publish from an intentionally updated deployment branch with original SHA locks, separate automated live QA, and rollback.
