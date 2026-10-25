extends RefCounted
## EMPIRE Ω R47 — bounded future crossing predictor for REAL traffic agents.
## A car slows before pedestrians enter its lane, without colliding or teleporting.
## Horizontal metres, metres/second, finite inputs, horizon <= 2.4s.
const MAX_PREDICTION_S: float = 2.4
const HALF_LANE_SAFETY_M: float = 2.2
const PEDESTRIAN_MARGIN_M: float = 1.5
const INFINITE_CLEARANCE_M: float = 1000000.0
const MAX_WALK_SPEED_MPS: float = 4.0

static func clearance(car: Vector3,heading: Vector3, car_speed: float,
		walker: Vector3,walk_velocity: Vector3,look_metres: float) -> float:
	if not car.is_finite() or not heading.is_finite() or not walker.is_finite() or not walk_velocity.is_finite():
		return 0.0
	if not is_finite(car_speed) or not is_finite(look_metres) or look_metres <= 0.0:
		return 0.0
	var axis := Vector2(heading.x,heading.z)
	if axis.length_squared()<0.1:
		return INFINITE_CLEARANCE_M
	axis=axis.normalized()
	var relative := Vector2(walker.x-car.x,walker.z-car.z)
	var ahead: float = relative.dot(axis)
	if ahead<=0.0 or ahead>=look_metres:
		return INFINITE_CLEARANCE_M
	var side := Vector2(-axis.y,axis.x)
	var lateral: float = relative.dot(side)
	var walker_v := Vector2(walk_velocity.x,walk_velocity.z)
	walker_v=walker_v.limit_length(MAX_WALK_SPEED_MPS)
	var arrival_seconds: float = clampf(maxf(0.0,ahead-PEDESTRIAN_MARGIN_M)/maxf(2.0,car_speed),0.0,MAX_PREDICTION_S)
	var future_lateral: float = lateral+walker_v.dot(side)*arrival_seconds
	# Conservative lane occupancy: a crossing route crosses the safety strip
	# BEFORE our projected arrival, or the walker is already in it.
	var crossing: bool = absf(lateral)<HALF_LANE_SAFETY_M or absf(future_lateral)<HALF_LANE_SAFETY_M
	if lateral*future_lateral <= 0.0:
		crossing=true
	return maxf(0.0,ahead-PEDESTRIAN_MARGIN_M) if crossing else INFINITE_CLEARANCE_M
