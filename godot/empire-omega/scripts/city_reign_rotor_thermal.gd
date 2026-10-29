extends RefCounted
## CITY REIGN R166: source-driven NORMALIZED brake rotor energy proxy.
## Temperature is a 0..1 visual indicator, NOT Celsius and NOT a certified
## temperature, ABS, tyre lock, stopping distance or a physics force.
## Reads ONLY measured before/after car speed, measured wheel support,
## input brake response, rain grip and the R46 axle-load estimate.
## Has NO economy, mission, score, save, sound or torque authority.
const MAX_STEP: float = 0.10
const GAIN_PER_MPS_SQUARED: float = 0.008
const HEAT_LIMIT: float = 1.0

static func dissipated_energy(before_mps: float,after_mps: float,pressure: float) -> float:
	if not is_finite(before_mps) or not is_finite(after_mps) or not is_finite(pressure):
		return 0.0
	var before: float = clampf(absf(before_mps),0.0,65.0)
	var after: float = clampf(absf(after_mps),0.0,65.0)
	# Road deceleration alone (coasting / drag / collision) never heats a rotor;
	# the actual driver must have applied measurable braking.
	var request: float = clampf(pressure,0.0,1.0)
	if request<0.08 or after>=before:
		return 0.0
	return maxf(0.0,before*before-after*after)*request

static func supported_axles(contacts: Array[bool]) -> Vector2:
	# Existing wheel probe order LF, LR, RF, RR.
	if contacts.size()!=4:
		return Vector2.ZERO
	var front: float = float(int(contacts[0])+int(contacts[2]))*0.5
	var rear: float = float(int(contacts[1])+int(contacts[3]))*0.5
	return Vector2(front,rear)

static func step(previous: Vector2, before_mps: float,after_mps: float,
		pressure: float,road_grip: float,front_fraction: float,
		contacts: Array[bool],dt: float) -> Vector2:
	var prior := Vector2(
		clampf(previous.x if is_finite(previous.x) else 0.0,0.0,HEAT_LIMIT),
		clampf(previous.y if is_finite(previous.y) else 0.0,0.0,HEAT_LIMIT))
	if not is_finite(dt) or dt<=0.0:
		return prior
	var timestep: float = minf(dt,MAX_STEP)
	var road: float = clampf(road_grip if is_finite(road_grip) else 1.0,0.35,1.15)
	var wetness: float = clampf(1.0-road,0.0,0.65)
	var speed: float = clampf(absf(after_mps) if is_finite(after_mps) else 0.0,0.0,65.0)
	var cooling: float = exp(-timestep*(0.11+speed*0.012+wetness*0.50))
	var result: Vector2 = prior*cooling
	var energy: float = dissipated_energy(before_mps,after_mps,pressure)
	var grounded: Vector2 = supported_axles(contacts)
	var front: float = clampf(front_fraction if is_finite(front_fraction) else 0.52,0.30,0.75)
	result.x += energy*GAIN_PER_MPS_SQUARED*front*grounded.x
	result.y += energy*GAIN_PER_MPS_SQUARED*(1.0-front)*grounded.y
	return Vector2(clampf(result.x,0.0,HEAT_LIMIT),clampf(result.y,0.0,HEAT_LIMIT))

static func visible_glow(heat: float) -> float:
	if not is_finite(heat):
		return 0.0
	# The rotor stays physically metallic until sustained warm braking.
	var normalized: float = clampf((heat-0.18)/0.82,0.0,1.0)
	return normalized*normalized*(3.0-2.0*normalized)

static func valid(state: Vector2) -> bool:
	return state.is_finite() and state.x>=0.0 and state.y>=0.0 and state.x<=1.0 and state.y<=1.0
