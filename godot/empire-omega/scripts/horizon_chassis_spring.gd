extends RefCounted
## HORIZON R3 - explicit critically-damped cosmetic chassis spring.
## This is a visual overlay; wheel contact / vehicle authority stays in controller.

const STEP_LIMIT: float = 0.05
const FREQUENCY: float = 5.8
const DAMPING: float = 1.0

static func integrate(position: float, velocity: float, goal: float, dt: float, frequency: float = FREQUENCY) -> Vector2:
	if dt <= 0.0:
		return Vector2(position,velocity)
	var remaining: float = minf(dt,0.5)
	var value: float = position
	var moving: float = velocity
	# Substeps prevent overshoot after a browser tab resumes.
	var omega: float = TAU*clampf(frequency,0.5,12.0)
	while remaining > 0.000001:
		var step: float = minf(remaining,0.0125)
		var acceleration: float = (goal-value)*omega*omega - 2.0*DAMPING*omega*moving
		moving += acceleration*step
		value += moving*step
		remaining -= step
	return Vector2(value,moving)

static func target_roll(forward_speed: float, yaw_rate: float, grip: float, handbrake: bool) -> float:
	var lateral_acc: float = forward_speed*yaw_rate
	return clampf(lateral_acc*0.009*(1.2 if handbrake else 1.0)/clampf(grip,0.35,1.15),-0.13,0.13)

static func target_pitch(longitudinal_acceleration: float) -> float:
	# Positive acceleration lifts the nose; heavy braking dips the nose.
	return clampf(-longitudinal_acceleration*0.008,-0.115,0.115)
