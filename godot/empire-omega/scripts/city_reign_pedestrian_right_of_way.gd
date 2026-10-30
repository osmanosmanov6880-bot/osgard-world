extends RefCounted
## CITY REIGN R180 — genuine phase-locked pedestrian crossing safety.
## Reads ONLY the existing sixteen-junction R178 traffic authority. No new
## road graph, pedestrian colliders, timers, currencies, saved fields or
## network telemetry. A real walker stops at the real 8m crossing gate.
const SIGNAL=preload("res://scripts/city_reign_intersection_policy.gd")
const GATE_OUTER_M: float=14.0
const GATE_INNER_M: float=SIGNAL.STOP_LINE_M
const CROSSING_WIDTH_M: float=SIGNAL.ROAD_HALF_WIDTH_M*2.0+1.4
const CROSSING_BUFFER_S: float=0.65
const LANE_WIDTH_M: float=5.0
const MAX_WALKER_MPS: float=3.6
const MIN_WALKER_MPS: float=0.3
const MAX_CANDIDATES: int=16

static func required_green_seconds(ahead: float,walk_speed: float) -> float:
	if not is_finite(ahead) or not is_finite(walk_speed) or walk_speed<=0.0:
		return INF
	# The green window must cover both the actual approach to the
	# painted crossing and the time needed to exit the opposing roadway.
	var metres: float=CROSSING_WIDTH_M+maxf(0.0,ahead-GATE_INNER_M)
	return metres/clampf(walk_speed,MIN_WALKER_MPS,MAX_WALKER_MPS)+CROSSING_BUFFER_S

static func permission(at: Vector3,route_velocity: Vector3,
		walk_speed: float,signal_elapsed: float) -> Dictionary:
	# Bad source state fails CLOSED rather than inventing a WALK right.
	if not at.is_finite() or not route_velocity.is_finite() or
			not is_finite(walk_speed) or not is_finite(signal_elapsed):
		return {"wait":true,"state":"unknown","point":Vector3.ZERO}
	if walk_speed<=0.0: return {"wait":true,"state":"stopped","point":Vector3.ZERO}
	var axis:=Vector2(route_velocity.x,route_velocity.z)
	if axis.length_squared()<0.0001:return {}
	axis=axis.normalized()
	var sideways:=Vector2(-axis.y,axis.x)
	var best_ahead: float=GATE_OUTER_M+1.0
	var best_point: Vector3=Vector3.ZERO
	var inspected: int=0
	for x in SIGNAL.JUNCTIONS:
		for z in SIGNAL.JUNCTIONS:
			inspected+=1
			if inspected>MAX_CANDIDATES:break
			var relative:=Vector2(float(x)-at.x,float(z)-at.z)
			var ahead: float=relative.dot(axis)
			if ahead<GATE_INNER_M or ahead>GATE_OUTER_M:
				continue
			if absf(relative.dot(sideways))>LANE_WIDTH_M:
				continue
			if ahead<best_ahead:
				best_ahead=ahead
				best_point=Vector3(float(x),0.0,float(z))
	if best_ahead>GATE_OUTER_M:return {}
	var heading:=Vector3(axis.x,0.0,axis.y)
	var phase: String=SIGNAL.state_at(signal_elapsed,heading)
	var green_remaining: float=SIGNAL.seconds_to_phase_end(signal_elapsed)
	var required: float=required_green_seconds(best_ahead,walk_speed)
	# At the terminal seconds of a real vehicle GREEN phase, a walker
	# legitimately sees WAIT: starting then could strand them mid-road.
	# Once physically past the 8m line no new gate is checked, so a
	# walker already crossing can clear even if the phase later changes.
	var permitted: bool=phase=="green" and green_remaining>=required
	return {
		"wait":not permitted,
		"state":"walk" if permitted else "wait",
		"source_phase":phase,
		"point":best_point,
		"distance_to_center":best_ahead,
		"green_remaining_s":green_remaining,
		"required_s":required
	}

static func face_state(signal_elapsed: float,axis: String) -> String:
	if not is_finite(signal_elapsed) or not ["x","z"].has(axis):
		return "wait"
	var heading: Vector3=Vector3.RIGHT if axis=="x" else Vector3.BACK
	if SIGNAL.state_at(signal_elapsed,heading)!="green":return "wait"
	var needed: float=required_green_seconds(GATE_INNER_M,2.15)
	return "walk" if SIGNAL.seconds_to_phase_end(signal_elapsed)>=needed else "wait"

static func consistent_with_original_grid() -> bool:
	return (SIGNAL.source_grid_valid() and MAX_CANDIDATES==16 and
		GATE_INNER_M==SIGNAL.STOP_LINE_M and
		GATE_OUTER_M>GATE_INNER_M and CROSSING_WIDTH_M>9.0)
