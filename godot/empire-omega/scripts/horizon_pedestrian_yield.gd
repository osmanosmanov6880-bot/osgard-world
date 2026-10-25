extends RefCounted
## R41: predictive crossing/yielding in the real original Godot city.
## Horizontal-world metres and seconds; no physics proxies or fabricated AI.
const LOOK_AHEAD_SECONDS: float = 2.4
const SAFETY_RADIUS_M: float = 2.8
const MAX_AWARENESS_M: float = 80.0

static func closest_approach_seconds(walker: Vector3,walker_velocity: Vector3,
		car: Vector3,car_velocity: Vector3) -> float:
	if not walker.is_finite() or not walker_velocity.is_finite() or not car.is_finite() or not car_velocity.is_finite():
		return 0.0
	var relative := Vector2(walker.x-car.x,walker.z-car.z)
	var relative_speed := Vector2(walker_velocity.x-car_velocity.x,walker_velocity.z-car_velocity.z)
	if relative_speed.length_squared() < 0.04:
		return 0.0
	return clampf(-relative.dot(relative_speed)/relative_speed.length_squared(),0.0,LOOK_AHEAD_SECONDS)

static func should_yield(walker: Vector3,walker_velocity: Vector3,
		car: Vector3,car_velocity: Vector3) -> bool:
	# Invalid coordinates fail closed, never allowing a broken car transform
	# to justify knowingly walking into an unknown collision.
	if not walker.is_finite() or not walker_velocity.is_finite() or not car.is_finite() or not car_velocity.is_finite():
		return true
	var horizontal := Vector2(walker.x-car.x,walker.z-car.z)
	if horizontal.length_squared() > MAX_AWARENESS_M*MAX_AWARENESS_M:
		return false
	var relative_speed := Vector2(walker_velocity.x-car_velocity.x,walker_velocity.z-car_velocity.z)
	var at: float = closest_approach_seconds(walker,walker_velocity,car,car_velocity)
	var nearest: Vector2 = horizontal+relative_speed*at
	return nearest.length_squared() < SAFETY_RADIUS_M*SAFETY_RADIUS_M
