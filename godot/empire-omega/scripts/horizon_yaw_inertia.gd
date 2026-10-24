extends RefCounted
## HORIZON R17: measured-unit inspired, bounded kinematic yaw inertia.
## NOT a rigid-body suspension, per-wheel force solver, or claims of certified
## ABS / ESP. Designed for the existing Godot CharacterBody3D vehicle.
## Functions have no GameState, input, I/O, save, or frame-rate side effects.

const STEER_MIN_TIME: float = 0.105
const STEER_SPEED_TIME: float = 0.17
const YAW_MIN_TIME: float = 0.13
const YAW_SPEED_TIME: float = 0.15
const MAX_STEP: float = 0.10
const LATERAL_ACCEL_LIMIT: float = 9.5
const MAX_YAW_RATE: float = 1.25
const MIN_POWER_FACTOR: float = 0.74

static func _blend(seconds: float, time_constant: float) -> float:
	if not is_finite(seconds) or seconds <= 0.0:
		return 0.0
	return 1.0 - exp(-minf(seconds,MAX_STEP)/maxf(0.01,time_constant))

static func steer_step(previous: float, requested: float, forward_speed: float, grip: float, dt: float) -> float:
	if not is_finite(previous) or not is_finite(requested) or not is_finite(forward_speed) or not is_finite(grip):
		return 0.0
	if dt <= 0.0 or not is_finite(dt):
		return previous
	var speed_ratio: float = clampf(absf(forward_speed)/25.0,0.0,1.0)
	var wetness: float = clampf(1.0-grip,0.0,0.65)
	var tau: float = STEER_MIN_TIME+speed_ratio*STEER_SPEED_TIME+wetness*0.06
	return clampf(lerpf(clampf(previous,-1.0,1.0),clampf(requested,-1.0,1.0),_blend(dt,tau)),-1.0,1.0)

static func yaw_step(previous: float, desired: float, speed: float, grip: float, handbrake: bool, dt: float) -> float:
	if not is_finite(previous) or not is_finite(desired) or not is_finite(speed) or not is_finite(grip):
		return 0.0
	if dt <= 0.0 or not is_finite(dt):
		return previous
	var surface: float = clampf(grip,0.35,1.15)
	# Preserve the existing tyre friction / centripetal-acceleration cap.
	var cap: float = minf(MAX_YAW_RATE,LATERAL_ACCEL_LIMIT*surface/maxf(absf(speed),0.5))
	var speed_ratio: float = clampf(absf(speed)/27.0,0.0,1.0)
	var wetness: float = clampf(1.0-surface,0.0,0.65)
	var tau: float = YAW_MIN_TIME+speed_ratio*YAW_SPEED_TIME+wetness*0.10+(0.04 if handbrake else 0.0)
	var bounded_prior: float = clampf(previous,-cap,cap)
	var bounded_target: float = clampf(desired,-cap,cap)
	return clampf(lerpf(bounded_prior,bounded_target,_blend(dt,tau)),-cap,cap)

static func corner_power_factor(speed: float, yaw_rate: float, grip: float, handbrake: bool) -> float:
	if not is_finite(speed) or not is_finite(yaw_rate) or not is_finite(grip):
		return MIN_POWER_FACTOR
	if handbrake or absf(speed) < 5.0:
		return 1.0
	var surface: float = clampf(grip,0.35,1.15)
	var lateral_demand: float = absf(speed*yaw_rate)
	var fraction: float = clampf(lateral_demand/maxf(1.0,LATERAL_ACCEL_LIMIT*surface),0.0,1.0)
	# The existing vehicle has no wheel torque solver. Reserve only up to 26%
	# of positive drive effort during highly loaded turns; driver braking
	# and reverse intent are never modified.
	return clampf(1.0-(1.0-MIN_POWER_FACTOR)*fraction*fraction,MIN_POWER_FACTOR,1.0)
