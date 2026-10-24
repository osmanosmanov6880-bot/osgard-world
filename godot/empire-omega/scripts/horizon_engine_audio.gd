extends RefCounted
## HORIZON R19: low-cost, deterministic virtual gearbox and engine tone.
## The virtual gear is an AUDIO cue, not a true torque curve or wheel RPM.
## All speeds are metres/second. Physics, speed caps and saved values remain
## authoritative in vehicle_controller.gd.

const UPSHIFTS = [7.0, 13.0, 20.0, 27.0]
const MIN_PITCH: float = 0.70
const MAX_PITCH: float = 1.60
const ENGINE_FADE_DB: float = -65.0

static func next_gear(previous: int, speed: float) -> int:
	if not is_finite(speed):
		return clampi(previous,0,5)
	if speed < -0.35:
		return 0
	var gear: int = clampi(previous,1,5)
	if gear < 5 and speed > float(UPSHIFTS[gear-1])+0.6:
		gear += 1
	elif gear > 1 and speed < float(UPSHIFTS[gear-2])-1.4:
		gear -= 1
	return gear

static func pitch(speed: float, throttle: float, gear: int) -> float:
	if not is_finite(speed) or not is_finite(throttle):
		return 0.77
	if gear == 0 or speed < -0.35:
		return clampf(0.79+absf(speed)*0.034,MIN_PITCH,1.20)
	var selected: int = clampi(gear,1,5)
	var lower: float = float(UPSHIFTS[selected-2]) if selected > 1 else 0.0
	var upper: float = float(UPSHIFTS[selected-1]) if selected < 5 else 34.0
	var in_gear: float = clampf((maxf(0.0,speed)-lower)/maxf(1.0,upper-lower),0.0,1.0)
	var load: float = clampf(throttle,0.0,1.0)
	# A rising pitch within each virtual gear provides perceived acceleration.
	# The drop after an upshift is deliberate but interpolated in update_cues.
	return clampf(0.78+in_gear*0.56+load*0.12,MIN_PITCH,MAX_PITCH)

static func volume(driving: bool, speed: float, throttle: float, handbrake: bool) -> float:
	if not driving:
		return ENGINE_FADE_DB
	if not is_finite(speed) or not is_finite(throttle):
		return -31.0
	var load: float = clampf(throttle,0.0,1.0)
	var gain: float = clampf(absf(speed)*0.17,0.0,5.0)
	return clampf(-30.0+gain+load*4.0-(2.0 if handbrake else 0.0),-33.0,-19.0)

static func smooth(previous: float, target: float, delta: float, response: float = 9.0) -> float:
	if not is_finite(previous) or not is_finite(target):
		return previous if is_finite(previous) else 0.0
	if not is_finite(delta) or delta <= 0.0:
		return previous
	var alpha: float = 1.0-exp(-clampf(delta,0.0,0.1)*clampf(response,0.2,30.0))
	return lerpf(previous,target,alpha)
