extends RefCounted
## CITY REIGN R179: strictly source-verified REAL stop-line crossing.
## Read-only single sampling window; no vehicle tracking, camera, location
## logs, persistent evidence, network telemetry, raycast, GPS or fine minting.
## Fine/heat is awarded ONLY by existing authoritative GameState/CITY_LAW.
const INTERSECTION=preload("res://scripts/city_reign_intersection_policy.gd")
const MAX_SAMPLE_S: float=0.41
const MAX_PHYSICAL_STEP_M: float=16.0
const MIN_ACTUAL_SPEED_MPS: float=3.0
const MIN_MOVEMENT_M: float=0.10
const LANE_REACH_M: float=4.75
const VERTICAL_TOLERANCE_M: float=2.4
const MOVEMENT_HEADING_DOT: float=0.82
const LINE_MARGIN_M: float=0.02

static func crossing(before: Vector3,after: Vector3,yaw: float,
		speed_mps: float,prior_signal_seconds: float,
		next_signal_seconds: float) -> Dictionary:
	if not before.is_finite() or not after.is_finite() or not is_finite(yaw) or not is_finite(speed_mps) or not is_finite(prior_signal_seconds) or not is_finite(next_signal_seconds):
		return {}
	if speed_mps<MIN_ACTUAL_SPEED_MPS:
		return {}
	var elapsed: float=next_signal_seconds-prior_signal_seconds
	if elapsed<=0.0 or elapsed>MAX_SAMPLE_S:
		return {}
	if absf(after.y-before.y)>VERTICAL_TOLERANCE_M:
		return {}
	var movement: Vector2=Vector2(after.x-before.x,after.z-before.z)
	var meters: float=movement.length()
	if meters<=MIN_MOVEMENT_M or meters>MAX_PHYSICAL_STEP_M:
		return {}
	var axis: Vector2=Vector2(-sin(yaw),-cos(yaw)).normalized()
	if movement.normalized().dot(axis)<MOVEMENT_HEADING_DOT:
		# Reversing, drifting sideways or teleporting cannot create a fine.
		return {}
	var fwd: Vector3=Vector3(axis.x,0.0,axis.y)
	# Both authoritative real signal samples MUST be RED. A light that
	# becomes red halfway through a 4Hz frame does not punish the driver.
	if INTERSECTION.state_at(prior_signal_seconds,fwd)!="red" or
			INTERSECTION.state_at(next_signal_seconds,fwd)!="red":
		return {}
	var lateral_axis: Vector2=Vector2(-axis.y,axis.x)
	var forward_travel: float=movement.dot(axis)
	for x in INTERSECTION.JUNCTIONS:
		for z in INTERSECTION.JUNCTIONS:
			var center:=Vector2(float(x),float(z))
			var prior: Vector2=center-Vector2(before.x,before.z)
			var remaining: float=prior.dot(axis)-INTERSECTION.STOP_LINE_M
			if remaining<=LINE_MARGIN_M or remaining>forward_travel+LINE_MARGIN_M:
				continue
			if absf(prior.dot(lateral_axis))>LANE_REACH_M:
				continue
			var last: Vector2=center-Vector2(after.x,after.z)
			if absf(last.dot(lateral_axis))>LANE_REACH_M:
				continue
			# NO saved coordinates or timestamps; these only prove a real
			# local crossing in one live physics sample.
			return {"violation":true,"kind":"red_light",
				"axis":"x" if absf(axis.x)>absf(axis.y) else "z",
				"source":"original source red phase and physically crossed stop bar",
				"distance_m":forward_travel}
	return {}

static func evidence_is_supported(data: Dictionary) -> bool:
	return data.is_empty() or (data.get("violation",false)==true
		and data.get("kind","")=="red_light" and
		is_finite(float(data.get("distance_m",-1.0))) and
		float(data.get("distance_m",0.0))<=MAX_PHYSICAL_STEP_M)
