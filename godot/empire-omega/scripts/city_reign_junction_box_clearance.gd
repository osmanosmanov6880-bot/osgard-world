extends RefCounted
## CITY REIGN R186 — source-authored physical "do not block the box".
## All original 12 native CharacterBody3D cars, R185 true right-hand
## +2m lanes, R178 real 16 signals and TrafficSafety remain authoritative.
## One bounded scan of EXISTING neighbors, no new collider, queue, NPC,
## traffic clock, saved law, mission, shader or background telemetry.
const SOURCE=preload("res://scripts/city_reign_intersection_policy.gd")
const SAFETY=preload("res://scripts/traffic_safety.gd")
const LANES=preload("res://scripts/city_reign_vehicle_lane_routing.gd")
const MAX_NEIGHBORS: int=16
const MAX_SOURCE_DISTANCE_M: float=28.0
const SOURCE_BOX_HALF_M: float=6.4
const EXIT_NEAR_M: float=6.5
const EXIT_FAR_M: float=19.0
const EXIT_LATERAL_M: float=1.6
const MIN_PEER_MOVING_MPS: float=1.2
const FORECAST_HORIZON_S: float=1.6
const CROSSING_MIN_SPEED_MPS: float=0.7
const MAX_CROSSING_SPEED_MPS: float=22.0
const JUNCTION_NO_HAZARD_M: float=1000000.0

static func source_gate_valid(sight: Dictionary,heading: Vector3) -> bool:
	if sight.is_empty() or not heading.is_finite():
		return false
	var center: Variant=sight.get("point",null)
	var free: float=float(sight.get("stop_distance",NAN))
	var distance: float=float(sight.get("distance_to_center",NAN))
	if not center is Vector3 or not (center as Vector3).is_finite():
		return false
	var point: Vector3=center
	if not SOURCE.JUNCTIONS.has(point.x) or not SOURCE.JUNCTIONS.has(point.z):
		return false
	if not is_finite(free) or not is_finite(distance):
		return false
	if free<0.0 or free>MAX_SOURCE_DISTANCE_M or distance<SOURCE.STOP_LINE_M-1.01:
		return false
	var axis:=Vector2(heading.x,heading.z)
	if axis.length_squared()<0.1:return false
	axis=axis.normalized()
	# An NPC must have a direction close to the source X/Z road,
	# not use projected box priority while changing its turn mid-crossing.
	return maxf(absf(axis.x),absf(axis.y))>=0.88

static func _in_source_box(relative: Vector2) -> bool:
	return (absf(relative.x)<=SOURCE_BOX_HALF_M and
		absf(relative.y)<=SOURCE_BOX_HALF_M)

static func classify(sight: Dictionary,heading: Vector3,speed: float,
		peer_at: Vector3,peer_motion: Vector3,peer_speed: float) -> String:
	if (not source_gate_valid(sight,heading) or not is_finite(speed) or
		not peer_at.is_finite() or not peer_motion.is_finite() or
		not is_finite(peer_speed)):
		return ""
	if speed<0.0:return ""
	var center: Vector3=sight["point"]
	if absf(peer_at.y-center.y)>3.0 and absf(peer_at.y-0.8)>2.7:
		return "" # aerial vehicles or elevated geometry aren't road traffic
	var axis:=Vector2(heading.x,heading.z).normalized()
	var motion:=Vector2(peer_motion.x,peer_motion.z)
	var relative:=Vector2(peer_at.x-center.x,peer_at.z-center.z)
	var ahead: float=relative.dot(axis)
	var lateral: float=axis.cross(relative)
	# FIRST: an existing physically stopped vehicle in the true EXIT
	# of our R185 +2m right-hand lane leaves no room for our 4.1m car
	# to clear the junction. Stay behind the original painted stop bar.
	# No imagined stoppage for another parallel street or opposite lane.
	if (ahead>=EXIT_NEAR_M and ahead<=EXIT_FAR_M and
		absf(lateral-LANES.RIGHT_LANE_OFFSET_M)<=EXIT_LATERAL_M and
		absf(peer_speed)<MIN_PEER_MOVING_MPS and
		motion.length()<MIN_PEER_MOVING_MPS):
		return "blocked_exit"
	# SECOND: already occupied ORIGINAL 16-junction road box.
	if _in_source_box(relative):
		if motion.length()>MIN_PEER_MOVING_MPS:
			var alignment: float=absf(motion.normalized().dot(axis))
			if alignment>=0.87:
				# The original R163 native car-following / collision ray
				# handles parallel traffic. Do NOT cross-yield for a car
				# moving on the safely separated opposing +2/-2 lane.
				return ""
		return "occupied_box"
	# THIRD: only a genuinely moving perpendicular vehicle could
	# enter the original box before our car reaches its stop line.
	# This is a short actual-velocity prediction, not a new AI planner.
	var pace: float=motion.length()
	if pace<CROSSING_MIN_SPEED_MPS or pace>MAX_CROSSING_SPEED_MPS:
		return ""
	if absf(motion.normalized().dot(axis))>0.55:return ""
	var t: float=clampf(float(sight["stop_distance"])/maxf(2.0,speed),
		0.1,FORECAST_HORIZON_S)
	var arriving: Vector2=relative+motion*t
	if _in_source_box(arriving) and not _in_source_box(relative):
		return "incoming_cross_traffic"
	return ""

static func safe_stop_cap(sight: Dictionary,heading: Vector3,
		cruise: float,wetness: float) -> float:
	if not source_gate_valid(sight,heading):
		return 0.0
	if not is_finite(cruise) or not is_finite(wetness):return 0.0
	# Exactly the original R178/R182 source painted stop bar, same
	# wet traction and the unchanged original TrafficSafety discipline.
	return SAFETY.safe_speed(float(sight["stop_distance"])+SAFETY.MIN_GAP,
		cruise,wetness)

static func scan(car: Node3D,neighbors: Array,heading: Vector3,
		current_speed: float,cruise: float,wetness: float,
		sight: Dictionary) -> Dictionary:
	if (car==null or not is_instance_valid(car) or
		not source_gate_valid(sight,heading) or
		not is_finite(current_speed) or not is_finite(cruise) or
		not is_finite(wetness)):
		return {}
	var primary: String=""
	var peer_count: int=0
	for i in range(mini(MAX_NEIGHBORS,neighbors.size())):
		var item: Variant=neighbors[i]
		if not is_instance_valid(item) or not item is Node3D:
			continue
		var other: Node3D=item as Node3D
		if other==car or not other.visible:continue
		var physical_velocity: Variant=other.get("velocity")
		var physical_speed: Variant=other.get("speed")
		if not physical_velocity is Vector3 or not (
			physical_speed is int or physical_speed is float):
			continue
		peer_count+=1
		var conflict: String=classify(sight,heading,current_speed,
			other.global_position,physical_velocity,float(physical_speed))
		if conflict=="occupied_box":
			primary=conflict
			break
		if conflict!="" and primary=="":
			primary=conflict
	if primary=="":return {}
	return {
		"reason":primary,
		"limit_mps":safe_stop_cap(sight,heading,cruise,wetness),
		"stop_distance_m":float(sight["stop_distance"]),
		"source":"original_r178_stop_bar",
		"observed_existing_peers":peer_count
	}

static func source_integrity() -> bool:
	return (SOURCE.source_grid_valid() and LANES.source_integrity() and
		MAX_NEIGHBORS>=12 and MAX_NEIGHBORS<=16 and
		MAX_SOURCE_DISTANCE_M<SOURCE.APPROACH_RANGE_M and
		EXIT_NEAR_M>SOURCE_BOX_HALF_M and EXIT_FAR_M<26.0 and
		absf(LANES.RIGHT_LANE_OFFSET_M-2.0)<0.001 and
		SOURCE.STOP_LINE_M==8.0 and SAFETY.MIN_GAP==4.0)
