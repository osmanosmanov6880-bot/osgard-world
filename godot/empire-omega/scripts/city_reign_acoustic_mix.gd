extends RefCounted
## CITY REIGN R169: dynamic acoustic signatures sampled from the original car.
## Arcade psychoacoustics only; no authority over engine torque or missions.
const MUTE_DB: float = -65.0
const MAX_GAIN_DB: float = -20.0
const MAX_ADDED_VOICES: int = 2
const TIERS = ["low","standard","cinematic"]

static func safe_quality(q: String) -> String:
	return q if TIERS.has(q) else "low"

static func safe_speed(speed: float) -> float:
	return clampf(absf(speed),0.0,42.0) if is_finite(speed) else 0.0

static func load_volume(driving: bool,speed: float,throttle: float,gear: int,
		quality: String,inside: bool) -> float:
	if not driving or safe_quality(quality)=="low":
		return MUTE_DB
	var load: float = clampf(throttle if is_finite(throttle) else 0.0,0.0,1.0)
	var pace: float = clampf(safe_speed(speed)/33.0,0.0,1.0)
	var db: float = -46.0+11.0*load+3.2*pace+(1.0 if gear>1 else 0.0)
	if inside: db-=1.5
	return clampf(db,-48.0,MAX_GAIN_DB)

static func road_volume(driving: bool,speed: float,lateral_speed: float,grip: float,
		weather: String,quality: String,inside: bool) -> float:
	if not driving or safe_quality(quality)=="low" or safe_speed(speed)<2.0:
		return MUTE_DB
	var slip: float = clampf(absf(lateral_speed)/6.0,0.0,1.0) if is_finite(lateral_speed) else 0.0
	var traction: float = clampf(grip,0.35,1.15) if is_finite(grip) else 1.0
	var wet: float = 1.0 if weather in ["rain","storm"] else 0.0
	var db: float = -49.0+0.52*safe_speed(speed)+7.0*slip+4.0*(1.0-traction)+3.0*wet
	if inside: db-=5.0
	return clampf(db,-52.0,MAX_GAIN_DB)

static func rolling_pitch(speed: float,wet: bool) -> float:
	return clampf(0.67+safe_speed(speed)*0.022+(0.045 if wet else 0.0),0.67,1.65)

static func cabin_engine(inside: bool) -> float:
	return -1.7 if inside else 0.0

static func cabin_rain(inside: bool) -> float:
	return -4.0 if inside else 0.0

static func cockpit_slip(lateral_speed: float,reduced_motion: bool) -> float:
	if reduced_motion or not is_finite(lateral_speed): return 0.0
	return clampf(lateral_speed*0.004,-0.028,0.028)

static func cockpit_brake(brake: float,reduced_motion: bool) -> float:
	if reduced_motion or not is_finite(brake): return 0.0
	return clampf(brake,0.0,1.0)*0.012
