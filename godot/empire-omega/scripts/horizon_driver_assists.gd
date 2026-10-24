extends RefCounted
## HORIZON R5: deterministic driver-aid heuristics for the arcade vehicle.
## Observes only chassis speed, sideways slip and weather grip; NOT a wheel-slip
## sensor, ABS, ESP certification, or a replacement for suspension physics.
## Steering and brakes remain controlled by the player.

const MIN_SPEED: float = 5.0
const MAX_POWER_REDUCTION: float = 0.58
const MAX_STEER_CORRECTION: float = 0.23

static func drive_power(command: float, forward_speed: float, lateral_speed: float, grip: float, handbrake: bool) -> float:
	var requested: float = clampf(command,-1.0,1.0)
	# Never change reverse/braking intent or interfere with deliberate handbrake slides.
	if requested <= 0.0 or handbrake or absf(forward_speed) < MIN_SPEED:
		return requested
	var slip_ratio: float = clampf(absf(lateral_speed)/maxf(absf(forward_speed),MIN_SPEED),0.0,0.65)
	var wet_factor: float = clampf(1.0-grip,0.0,0.65)
	var reduction: float = minf(MAX_POWER_REDUCTION,slip_ratio*(1.20+wet_factor*1.1))
	return requested * (1.0-reduction)

static func stabilize_steering(command: float, forward_speed: float, lateral_speed: float, grip: float, handbrake: bool) -> float:
	var requested: float = clampf(command,-1.0,1.0)
	if handbrake or absf(forward_speed) < MIN_SPEED or absf(lateral_speed) < 0.7:
		return requested
	var slip_ratio: float = clampf(lateral_speed/maxf(absf(forward_speed),MIN_SPEED),-0.65,0.65)
	var speed_weight: float = clampf((absf(forward_speed)-MIN_SPEED)/18.0,0.0,1.0)
	var wet_factor: float = clampf(1.0-grip,0.0,0.65)
	var correction: float = clampf(slip_ratio * (0.5+wet_factor*0.5) * speed_weight,-MAX_STEER_CORRECTION,MAX_STEER_CORRECTION)
	# In reverse, the response direction changes consistently with the yaw model.
	if forward_speed < 0.0:
		correction = -correction
	return clampf(requested-correction,-1.0,1.0)
