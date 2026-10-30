extends RefCounted
## CITY REIGN R178: real, phase-locked physical intersection right of way.
## The ORIGINAL signal_controller.elapsed is the sole clock; the ORIGINAL
## traffic_safety limiter remains the sole braking rule. Zero new city state,
## AI authority, reward, node, raycast or traffic collision shape.
const SAFETY=preload("res://scripts/traffic_safety.gd")
const JUNCTIONS=[-156.0,-52.0,52.0,156.0]
const CYCLE_SECONDS: float=24.0
const PHASE_SECONDS: float=12.0
const AMBER_SECONDS: float=1.5
const STOP_LINE_M: float=8.0
# Keep the original signal stop active for small physics overshoot at the
# painted line; release only once genuinely inside the junction.
const STOP_LINE_OVERRUN_M: float=1.0
const ROAD_HALF_WIDTH_M: float=4.95
const APPROACH_RANGE_M: float=44.0
const MAX_SENSE_M: float=36.0
const MIN_DRIVER_SPEED_MPS: float=2.5
const EPSILON: float=0.0001

static func state_at(elapsed: float,heading: Vector3) -> String:
	if not is_finite(elapsed) or not heading.is_finite(): return "unknown"
	var axis: Vector2=Vector2(heading.x,heading.z)
	if axis.length_squared()<EPSILON: return "unknown"
	var cycle: float=fposmod(elapsed,CYCLE_SECONDS)
	var zero: bool=cycle<PHASE_SECONDS
	var aligned_x: bool=absf(axis.x)>=absf(axis.y)
	var permitted: bool=(zero and aligned_x) or (not zero and not aligned_x)
	if not permitted: return "red"
	if fposmod(cycle,PHASE_SECONDS)>=PHASE_SECONDS-AMBER_SECONDS: return "amber"
	return "green"

static func seconds_to_phase_end(elapsed: float) -> float:
	if not is_finite(elapsed): return 0.0
	return PHASE_SECONDS-fposmod(elapsed,PHASE_SECONDS)

static func approach(origin: Vector3,heading: Vector3,elapsed: float) -> Dictionary:
	if not origin.is_finite() or not heading.is_finite() or not is_finite(elapsed):
		return {}
	var axis: Vector2=Vector2(heading.x,heading.z)
	if axis.length_squared()<EPSILON:return {}
	axis=axis.normalized()
	var cross: Vector2=Vector2(-axis.y,axis.x)
	var nearest: float=APPROACH_RANGE_M+1.0
	var best: Vector3=Vector3.ZERO
	for x in JUNCTIONS:
		for z in JUNCTIONS:
			var relative:=Vector2(float(x)-origin.x,float(z)-origin.z)
			var ahead: float=relative.dot(axis)
			var lateral: float=absf(relative.dot(cross))
			# Small overshoot stays on STOP. Only a car genuinely past the
			# line + grace zone may clear the physical junction.
			if ahead<STOP_LINE_M-STOP_LINE_OVERRUN_M or ahead>APPROACH_RANGE_M or lateral>ROAD_HALF_WIDTH_M:
				continue
			if ahead<nearest:
				nearest=ahead
				best=Vector3(float(x),0.0,float(z))
	if nearest>APPROACH_RANGE_M:return {}
	return {"point":best,"distance_to_center":nearest,
		"stop_distance":maxf(0.0,nearest-STOP_LINE_M),
		"phase":state_at(elapsed,heading),
		"phase_end_seconds":seconds_to_phase_end(elapsed)}

static func speed_cap(origin: Vector3,heading: Vector3,current_speed: float,
		cruise: float,wetness: float,elapsed: float) -> float:
	# Invalid physics must NEVER give a faster speed or skip braking.
	if not origin.is_finite() or not heading.is_finite() or not is_finite(current_speed) or not is_finite(cruise) or not is_finite(wetness) or not is_finite(elapsed):
		return 0.0
	var allowed: float=maxf(0.0,cruise)
	var sight: Dictionary=approach(origin,heading,elapsed)
	if sight.is_empty():return allowed
	var phase: String=str(sight["phase"])
	var free: float=float(sight["stop_distance"])
	if phase=="green":
		# The REAL phase may expire before a car could reach its stop bar.
		# Approach at the original smooth safe-speed curve; don't invent an
		# amber cycle or make an unconditional right of way.
		var travel_time: float=free/maxf(2.0,current_speed)
		if travel_time<float(sight["phase_end_seconds"]):return allowed
	elif phase=="amber":
		# Dilemma zone: at last-second amber, hard braking INSIDE the
		# junction is more dangerous than clearing it. Red never bypasses.
		var safe_brake: float=SAFETY.COMFORT_BRAKE*clampf(wetness,0.4,1.0)
		var needed: float=current_speed*current_speed/(2.0*safe_brake)
		if free<needed+0.5 and current_speed>3.0:
			return allowed
	elif phase!="red":
		return 0.0
	# Original TrafficSafety governs wet braking and smooth deceleration.
	# Add its existing safety margin so the real floor aligns with paint.
	var limit: float=SAFETY.safe_speed(free+SAFETY.MIN_GAP,allowed,wetness)
	return minf(allowed,limit)

static func driver_warning(origin: Vector3,angle: float,speed: float,elapsed: float) -> Dictionary:
	if not origin.is_finite() or not is_finite(angle) or not is_finite(speed) or not is_finite(elapsed):
		return {}
	if speed<MIN_DRIVER_SPEED_MPS:return {}
	var heading: Vector3=Vector3(-sin(angle),0.0,-cos(angle))
	var sight: Dictionary=approach(origin,heading,elapsed)
	if sight.is_empty() or float(sight["stop_distance"])>MAX_SENSE_M:return {}
	var phase: String=str(sight["phase"])
	if phase=="green": return {}
	var free: float=float(sight["stop_distance"])
	var ttc: float=free/maxf(speed,2.0)
	return {"kind":"signal","phase":phase,"urgency":"urgent" if ttc<1.8 else "caution",
		"seconds":ttc,"distance_m":free,
		"source":"original physical signal clock"}

static func source_grid_valid() -> bool:
	if JUNCTIONS.size()!=4 or CYCLE_SECONDS!=24.0 or AMBER_SECONDS!=1.5:
		return false
	for p in JUNCTIONS:
		if not is_finite(float(p)):return false
	return true
