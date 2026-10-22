extends RefCounted
## v0.21: deterministic arcade car motion, measured in metres and seconds.
## Use with CharacterBody3D; this is NOT a VehicleBody3D suspension simulation.
## A negative throttle brakes a moving car before engaging reverse.

const WHEELBASE: float = 3.35
const MAX_STEER_RADIANS: float = 0.52
const LATERAL_ACCELERATION: float = 9.5
const MAX_YAW_RATE: float = 1.25
const MAX_PHYSICS_STEP: float = 0.1
const MAX_FRAME_CATCHUP: float = 0.5

static func speed_step(current: float, throttle: float, grip: float, condition: float, max_forward: float, max_reverse: float, acceleration: float, braking: float, coasting: float, handbrake: bool, dt: float) -> float:
	# Prevent massive speed jumps if the application is resumed after a pause.
	if dt <= 0.0:
		return current
	# Wave 1: consume the elapsed time in bounded deterministic substeps instead
	# of dropping all time after the first 100 ms. Cap catch-up at 500 ms
	# to prevent a resumed browser/window from simulating many seconds at once.
	var remaining: float = minf(dt,MAX_FRAME_CATCHUP)
	var value: float = current
	while remaining > 0.000001:
		var step: float = minf(remaining,MAX_PHYSICS_STEP)
		value = _speed_substep(value,throttle,grip,condition,max_forward,max_reverse,acceleration,braking,coasting,handbrake,step)
		remaining -= step
	return value

static func _speed_substep(current: float, throttle: float, grip: float, condition: float, max_forward: float, max_reverse: float, acceleration: float, braking: float, coasting: float, handbrake: bool, step: float) -> float:
	var surface: float = clampf(grip,0.35,1.15)
	var health: float = clampf(condition,0.25,1.0)
	var forward_limit: float = maxf(0.0,max_forward) * health
	var reverse_limit: float = maxf(0.0,max_reverse) * health
	var power: float = maxf(0.0,acceleration) * health * surface
	var stop: float = maxf(0.0,braking) * surface
	var value: float = clampf(current,-reverse_limit,forward_limit)
	if handbrake:
		# Parking brake has no accelerator/reverse effect; never accelerates a car.
		value = move_toward(value,0.0,stop * 0.85 * step)
	elif throttle > 0.05:
		if value < 0.0:
			value = move_toward(value,0.0,stop * throttle * step)
		else:
			value = move_toward(value,forward_limit,power * throttle * step)
	elif throttle < -0.05:
		if value > 0.0:
			value = move_toward(value,0.0,stop * -throttle * step)
		else:
			value = move_toward(value,-reverse_limit,power * 0.55 * -throttle * step)
	else:
		value = move_toward(value,0.0,maxf(0.0,coasting)*step)
	return clampf(value,-reverse_limit,forward_limit)

static func yaw_rate(speed: float, steering: float, grip: float, handbrake: bool = false) -> float:
	if absf(speed) < 0.3 or absf(steering) < 0.01:
		return 0.0
	var surface: float = clampf(grip,0.35,1.15)
	# Smaller steering angle and capped lateral acceleration at high speeds:
	# this prevents an arcade turn from behaving like an instant 90-degree spin.
	var angle: float = clampf(steering,-1.0,1.0) * MAX_STEER_RADIANS / (1.0+absf(speed)*0.035)
	var ideal: float = speed / WHEELBASE * tan(angle)
	var lateral_limit: float = LATERAL_ACCELERATION * surface * (0.68 if handbrake else 1.0)
	var angular_limit: float = minf(MAX_YAW_RATE,lateral_limit/maxf(absf(speed),0.5))
	return clampf(ideal*surface,-angular_limit,angular_limit)

static func brake_lamps(speed: float, throttle: float, handbrake: bool) -> bool:
	return handbrake or (speed > 0.25 and throttle < -0.05) or (speed < -0.25 and throttle > 0.05)

static func gear(speed: float) -> String:
	if speed < -0.35:
		return "R"
	if speed > 0.35:
		return "D"
	return "N"
