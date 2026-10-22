extends RefCounted
## Pure arcade traffic safety rules: all distances in Godot world metres,
## speeds in m/s. Isolated from rendering for deterministic engine tests.
const MIN_GAP := 4.0
const HEADWAY_SECONDS := 1.15
const COMFORT_BRAKE := 8.0
const HARD_BRAKE := 16.0
const ACCELERATION := 4.5
const STOP_EPSILON := 0.35

static func safe_speed(clearance: float, cruise: float, wetness: float = 1.0) -> float:
	# A car must be able to stop in the space remaining after its safety gap.
	# wetness < 1 means less traction and a longer stopping distance.
	if not is_finite(clearance) or not is_finite(cruise) or not is_finite(wetness):
		return 0.0
	var free_distance: float = maxf(0.0,clearance-MIN_GAP)
	var braking: float = COMFORT_BRAKE*clampf(wetness,0.4,1.0)
	var stopping_limit: float = sqrt(2.0*braking*free_distance)
	var headway_limit: float = free_distance/HEADWAY_SECONDS
	return clampf(minf(stopping_limit,headway_limit),0.0,maxf(0.0,cruise))

static func desired_speed(cruise: float, obstacle_metres: float, signal_metres: float, wetness: float = 1.0) -> float:
	var obstruction: float = minf(obstacle_metres,signal_metres)
	if obstruction >= 100000.0:
		return maxf(0.0,cruise)
	return safe_speed(obstruction,cruise,wetness)

static func corner_speed(direction: Vector3, next_direction: Vector3, metres: float, cruise: float) -> float:
	# Reduce speed before a sharp corner instead of snapping a fast car 90 degrees.
	if direction.length_squared() < 0.001 or next_direction.length_squared() < 0.001:
		return maxf(0.0,cruise)
	var angle: float = acos(clampf(direction.normalized().dot(next_direction.normalized()),-1.0,1.0))
	if angle < 0.22:
		return maxf(0.0,cruise)
	var corner_limit: float = maxf(2.5,cruise*(1.0-angle/PI)*0.58)
	var approach_limit: float = sqrt(corner_limit*corner_limit+2.0*COMFORT_BRAKE*maxf(0.0,metres-3.0))
	return clampf(approach_limit,0.0,maxf(0.0,cruise))

static func approach_speed(current: float, target: float, delta: float) -> float:
	var rate: float = ACCELERATION if target > current else HARD_BRAKE
	return move_toward(maxf(0.0,current),maxf(0.0,target),rate*clampf(delta,0.0,0.1))

static func should_brake(cruise: float, actual_speed: float) -> bool:
	return actual_speed < maxf(1.0,cruise*0.65)
