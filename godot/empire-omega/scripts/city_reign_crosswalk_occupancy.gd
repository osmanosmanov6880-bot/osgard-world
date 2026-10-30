extends RefCounted
## CITY REIGN R182 — live physical crosswalk occupation, not a fake
## pedestrian warning or a new collision proxy. Uses original R178
## stop bars, 16 original junctions, R47 actual citizen trajectories,
## and the existing TrafficSafety limiter. No save/telemetry/network.
const INTERSECTIONS=preload("res://scripts/city_reign_intersection_policy.gd")
const SAFETY=preload("res://scripts/traffic_safety.gd")
const MAX_GUARD_STOP_DISTANCE_M: float=32.0
const CROSSING_HALF_SPAN_M: float=8.2
const INNER_LANE_HALF_WIDTH_M: float=3.85
const PREDICTION_SOURCE_HALF_WIDTH_M: float=7.2
const PREDICTION_HORIZON_S: float=2.1
const MAX_WALK_VELOCITY_MPS: float=4.0
const MIN_MOVEMENT_MPS: float=0.12
const INF_CLEARANCE_M: float=1000000.0

static func gate(car: Vector3,heading: Vector3,signal_elapsed: float) -> Dictionary:
	if not car.is_finite() or not heading.is_finite() or not is_finite(signal_elapsed):
		return {}
	var source: Dictionary=INTERSECTIONS.approach(car,heading,signal_elapsed)
	if source.is_empty():return {}
	var free: float=float(source["stop_distance"])
	if free>MAX_GUARD_STOP_DISTANCE_M:return {}
	# In the very same actual 1m stop-line overrun grace zone as R178:
	# never invent a new stop when physically already inside junction.
	return {"point":source["point"],"stop_distance":free}

static func _inside_relative(relative: Vector2,axis: Vector2) -> bool:
	var along: float=relative.dot(axis)
	var lateral: float=absf(relative.cross(axis))
	return (absf(along)<=CROSSING_HALF_SPAN_M and
		lateral<=INNER_LANE_HALF_WIDTH_M)

static func occupied(crossing: Dictionary,heading: Vector3,
		walker: Vector3,walking_velocity: Vector3,
		car_speed: float) -> bool:
	if crossing.is_empty() or not heading.is_finite() or
		not walker.is_finite() or not walking_velocity.is_finite() or
		not is_finite(car_speed):
		return false
	var center: Vector3=crossing.get("point",Vector3.ZERO)
	if not center.is_finite():return false
	var axis:=Vector2(heading.x,heading.z)
	if axis.length_squared()<0.01:return false
	axis=axis.normalized()
	var current:=Vector2(walker.x-center.x,walker.z-center.z)
	# Actual occupied ROAD corridor: a stopped person already inside
	# the vehicle path has right of way until physically clear.
	if _inside_relative(current,axis):return true
	var lateral: float=absf(current.cross(axis))
	if lateral>PREDICTION_SOURCE_HALF_WIDTH_M:
		return false
	var walking:=Vector2(walking_velocity.x,walking_velocity.z)
	var pace: float=walking.length()
	if pace<MIN_MOVEMENT_MPS or pace>MAX_WALK_VELOCITY_MPS:
		return false
	# Only predict the REAL instant the approaching car reaches its
	# painted stop bar. Ordinary walkers parallel to cars on a safe
	# sidewalk remain outside the vehicle lane and never trigger.
	var stop_distance: float=float(crossing.get("stop_distance",0.0))
	var arrival: float=minf(PREDICTION_HORIZON_S,
		stop_distance/maxf(2.0,absf(car_speed)))
	var future: Vector2=current+walking*arrival
	if not _inside_relative(future,axis):return false
	# The movement must genuinely approach or enter the car corridor,
	# not run away along its boundary.
	return absf(future.cross(axis))<absf(current.cross(axis))+0.01

static func stop_clearance(crossing: Dictionary) -> float:
	if crossing.is_empty():return INF_CLEARANCE_M
	var free: float=float(crossing.get("stop_distance",INF_CLEARANCE_M))
	if not is_finite(free):return 0.0
	return maxf(0.0,free)+SAFETY.MIN_GAP

static func reduced_speed(crossing: Dictionary,cruise: float,
		wetness: float,actual_occupied: bool) -> float:
	if not is_finite(cruise) or not is_finite(wetness):
		return 0.0
	if not actual_occupied or crossing.is_empty():return maxf(0.0,cruise)
	return SAFETY.safe_speed(stop_clearance(crossing),cruise,wetness)

static func source_geometry_consistent() -> bool:
	return (INTERSECTIONS.source_grid_valid() and
		CROSSING_HALF_SPAN_M<=INTERSECTIONS.STOP_LINE_M+
			INTERSECTIONS.STOP_LINE_OVERRUN_M and
		INNER_LANE_HALF_WIDTH_M<INTERSECTIONS.ROAD_HALF_WIDTH_M and
		PREDICTION_SOURCE_HALF_WIDTH_M>6.0 and
		MAX_GUARD_STOP_DISTANCE_M<=INTERSECTIONS.APPROACH_RANGE_M)
