extends RefCounted
## HORIZON R3 - deterministic semi-arcade lateral tire response.
## Forward acceleration remains in driving_dynamics.gd; no fake full suspension claim.
## Lateral velocity is in vehicle-local coordinates: positive = slip toward local +X.

const MAX_CATCH_UP: float = 0.5
const SUBSTEP: float = 0.025
const MAX_SLIP_SPEED: float = 9.5

static func step_lateral(current: float, forward_speed: float, yaw_rate: float, grip: float, handbrake: bool, dt: float) -> float:
	if dt <= 0.0:
		return current
	var remaining: float = minf(dt,MAX_CATCH_UP)
	var response: float = current
	var surface_grip: float = clampf(grip,0.35,1.15)
	# Kinematic tire model: yaw produces outward body-frame lateral slip,
	# while tire friction dissipates it. Handbrake unlocks the rear axis.
	var damping: float = 6.5*surface_grip*(0.24 if handbrake else 1.0)
	while remaining > 0.0000001:
		var step: float = minf(SUBSTEP,remaining)
		response += forward_speed*yaw_rate*step
		response *= exp(-damping*step)
		var cap: float = minf(MAX_SLIP_SPEED,maxf(1.0,absf(forward_speed)*0.52))
		response = clampf(response,-cap,cap)
		remaining -= step
	if absf(forward_speed) < 0.25:
		response = move_toward(response,0.0,6.0*minf(dt,MAX_CATCH_UP))
	return response

static func slip_angle_degrees(forward_speed: float, lateral_speed: float) -> float:
	if absf(forward_speed) < 0.4:
		return 0.0
	return rad_to_deg(atan2(absf(lateral_speed),absf(forward_speed)))

static func drift_gain(forward_speed: float, lateral_speed: float, handbrake: bool, dt: float) -> float:
	if dt <= 0.0 or absf(forward_speed) < 9.0:
		return 0.0
	var angle: float = slip_angle_degrees(forward_speed,lateral_speed)
	# A regular corner should not grant rewards: need significant slip or handbrake.
	if angle < (4.5 if handbrake else 9.0):
		return 0.0
	return minf(100.0,absf(forward_speed)*clampf(angle,0.0,35.0)*0.12*minf(dt,0.1))

static func bank_reward(points: float, duration: float) -> int:
	# Prevent one-frame score farming and cap awards per validated drift chain.
	if not is_finite(points) or duration < 0.75 or points < 45.0:
		return 0
	return clampi(roundi(points/8.0),5,55)
