extends RefCounted
## CITY REIGN B62 — the ACTUAL funded "safe_crossings" changes NPC traffic.
## A pure read-only speed limit computed exclusively from the saved city state
## and the same source-locked road coordinates that earn genuine zebra stripes.
## No ghost collision zones, no mission/reward writes, no new traffic nodes,
## no teleportation, no change to player car or emergency patrol response.
const PUBLIC_WORKS = preload("res://scripts/city_reign_civic_outcomes.gd")
const SPEED_LIMIT_MPS: float = 4.8
const INNER_SLOW_ZONE_M: float = 16.0
const MAX_LOOK_AHEAD_M: float = 30.0
const HALF_ROAD_WIDTH_M: float = 5.3
const PASSED_CLEARANCE_M: float = 2.0

static func funded(state: Dictionary) -> bool:
	var completed: Variant = state.get("projects_done",[])
	return completed is Array and completed.has("safe_crossings")

static func speed_cap(state: Dictionary,car_at: Vector3,heading: Vector3,
		cruising_speed: float,is_emergency: bool) -> float:
	# Valid vehicles outside the funded zone retain their ORIGINAL route AI.
	# Invalid input fails to a conservative zero-speed cap, not unsafe speed.
	if not car_at.is_finite() or not heading.is_finite() or not is_finite(cruising_speed):
		return 0.0
	var original_speed: float = maxf(0.0,cruising_speed)
	if is_emergency or not funded(state) or original_speed<=SPEED_LIMIT_MPS:
		return original_speed
	var forward := Vector2(heading.x,heading.z)
	if forward.length_squared()<0.05:
		return original_speed
	forward=forward.normalized()
	var side := Vector2(-forward.y,forward.x)
	var cap: float = original_speed
	for crossing in PUBLIC_WORKS.CROSSINGS:
		var center: Vector3 = crossing
		var displacement := Vector2(center.x-car_at.x,center.z-car_at.z)
		var ahead: float = displacement.dot(forward)
		var lateral: float = absf(displacement.dot(side))
		if ahead < -PASSED_CLEARANCE_M or ahead > MAX_LOOK_AHEAD_M:
			continue
		if lateral > HALF_ROAD_WIDTH_M:
			continue
		# Progressive approach from real original road speed; within 16m
		# of the actual installed crossing, keep <=4.8m/s (~17.3 km/h).
		var blend: float = clampf(
			(ahead-INNER_SLOW_ZONE_M)/(MAX_LOOK_AHEAD_M-INNER_SLOW_ZONE_M),
			0.0,1.0)
		var limit: float = lerpf(SPEED_LIMIT_MPS,original_speed,blend)
		cap=minf(cap,limit)
	return cap

static func geometry_matches_installed_city() -> bool:
	return PUBLIC_WORKS.CROSSING_COUNT==PUBLIC_WORKS.CROSSINGS.size() and (
		PUBLIC_WORKS.STRIPES_PER_CROSSING==9 and PUBLIC_WORKS.STUDS_PER_CROSSING==10)
