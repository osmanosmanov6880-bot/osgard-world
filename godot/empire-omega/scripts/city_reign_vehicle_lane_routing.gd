extends RefCounted
## CITY REIGN R185 — 12 existing physical NPCs keep to a real asphalt
## traffic lane instead of sharing one centerline with opposing vehicles.
## The ORIGINAL closure-aware 9x9 A* still owns every traversed road edge.
## No new road graph, road signs, NPCs, collision bodies or teleportation.
const MOBILITY=preload("res://scripts/city_mobility.gd")
const ROADS=preload("res://scripts/city_reign_intersection_policy.gd")
const RIGHT_LANE_OFFSET_M: float=2.0
const VEHICLE_HALF_WIDTH_M: float=1.125
const GRID_TOLERANCE_M: float=0.12
const MAX_SOURCE_NODES: int=96
const MAX_RETURN_NODES: int=96
const MAX_VERTICAL_STEP_M: float=0.7
const MAX_PERPENDICULAR_SHIFT_M: float=2.84

static func _grid_axis(value: float) -> bool:
	if not is_finite(value):return false
	var n: int=roundi((value-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING)
	if n<0 or n>=MOBILITY.ROAD_SIZE:return false
	return (absf(value-(MOBILITY.ROAD_MIN+float(n)*MOBILITY.ROAD_SPACING))<
		GRID_TOLERANCE_M)

static func source_grid_vertex(at: Vector3) -> bool:
	return at.is_finite() and _grid_axis(at.x) and _grid_axis(at.z)

static func source_edge_right(a: Vector3,b: Vector3) -> Vector3:
	if not source_grid_vertex(a) or not source_grid_vertex(b):
		return Vector3.ZERO
	if absf(a.y-b.y)>MAX_VERTICAL_STEP_M:return Vector3.ZERO
	var difference: Vector3=b-a
	var dx: float=difference.x
	var dz: float=difference.z
	if (absf(absf(dx)-MOBILITY.ROAD_SPACING)<GRID_TOLERANCE_M and
			absf(dz)<GRID_TOLERANCE_M):
		# Travelling +X means the genuine right side is +Z.
		return Vector3(0,0,signf(dx)*RIGHT_LANE_OFFSET_M)
	if (absf(absf(dz)-MOBILITY.ROAD_SPACING)<GRID_TOLERANCE_M and
			absf(dx)<GRID_TOLERANCE_M):
		# Travelling +Z means the genuine right side is -X.
		return Vector3(-signf(dz)*RIGHT_LANE_OFFSET_M,0,0)
	return Vector3.ZERO

static func on_original_asphalt(at: Vector3) -> bool:
	if not at.is_finite() or absf(at.x)>225.0 or absf(at.z)>225.0:
		return false
	for index in range(MOBILITY.ROAD_SIZE):
		var center: float=MOBILITY.ROAD_MIN+float(index)*MOBILITY.ROAD_SPACING
		if (absf(at.x-center)<=ROADS.ROAD_HALF_WIDTH_M or
				absf(at.z-center)<=ROADS.ROAD_HALF_WIDTH_M):
			return true
	return false

static func to_right_hand_lane(original: Array[Vector3]) -> Array[Vector3]:
	# Never fabricate an alternative A* edge: shift only real adjacent
	# original grid vertices. Source start/end building offsets preserved.
	var unchanged: Array[Vector3]=original.duplicate()
	if original.size()<2 or original.size()>MAX_SOURCE_NODES:
		return unchanged
	var raw: Array[Vector3]=[]
	for p in original:
		if not p.is_finite():return unchanged
		if raw.is_empty() or raw[raw.size()-1].distance_squared_to(p)>0.001:
			raw.append(p)
	if raw.size()<2 or raw.size()>MAX_SOURCE_NODES:
		return unchanged
	var result: Array[Vector3]=[]
	for i in range(raw.size()):
		var before: Vector3=Vector3.ZERO
		var after: Vector3=Vector3.ZERO
		if i>0:
			before=source_edge_right(raw[i-1],raw[i])
		if i<raw.size()-1:
			after=source_edge_right(raw[i],raw[i+1])
		# At a true 90-degree turn, the physical car goes through the
		# intersection of its incoming and outgoing right-hand lanes.
		# This prevents a backward hook / diagonal into opposing traffic.
		if (before!=Vector3.ZERO and after!=Vector3.ZERO and
				before.dot(after)<-0.1):
			return unchanged # A* U-turn: don't invent a lane arc
		var offset: Vector3=Vector3.ZERO
		if before!=Vector3.ZERO:
			offset+=before
		if after!=Vector3.ZERO and after.distance_squared_to(before)>0.001:
			offset+=after
		# Do not add the same 2m shift twice on a straight segment.
		if offset.length()>MAX_PERPENDICULAR_SHIFT_M:
			return unchanged
		var lane: Vector3=raw[i]+offset
		if offset!=Vector3.ZERO and not on_original_asphalt(lane):
			return unchanged
		result.append(lane)
	if result.size()!=raw.size() or result.size()>MAX_RETURN_NODES:
		return unchanged
	return result

static func lateral_lane_error(at: Vector3,heading: Vector3) -> float:
	# In-game-only physical truth, not a location tracker. A vehicle
	# turning at a junction is explicitly excluded from lane scoring.
	if not at.is_finite() or not heading.is_finite():return INF
	var axis: Vector2=Vector2(heading.x,heading.z)
	if axis.length_squared()<0.001:return INF
	axis=axis.normalized()
	var x_moving: bool=absf(axis.x)>=0.92
	var z_moving: bool=absf(axis.y)>=0.92
	if not x_moving and not z_moving:return INF
	var transverse: float=at.z if x_moving else at.x
	var n: int=clampi(roundi((transverse-MOBILITY.ROAD_MIN)/
		MOBILITY.ROAD_SPACING),0,MOBILITY.ROAD_SIZE-1)
	var center: float=MOBILITY.ROAD_MIN+float(n)*MOBILITY.ROAD_SPACING
	var legal: float=(RIGHT_LANE_OFFSET_M*signf(axis.x) if x_moving
		else -RIGHT_LANE_OFFSET_M*signf(axis.y))
	return absf(transverse-(center+legal))

static func on_right_lane(at: Vector3,heading: Vector3) -> bool:
	return lateral_lane_error(at,heading)<=0.8

static func source_integrity() -> bool:
	return (MOBILITY.ROAD_SIZE==9 and MOBILITY.ROAD_SPACING==52.0 and
		MOBILITY.ROAD_MIN==-208.0 and ROADS.source_grid_valid() and
		RIGHT_LANE_OFFSET_M>VEHICLE_HALF_WIDTH_M and
		RIGHT_LANE_OFFSET_M+VEHICLE_HALF_WIDTH_M<ROADS.ROAD_HALF_WIDTH_M and
		MAX_PERPENDICULAR_SHIFT_M>RIGHT_LANE_OFFSET_M*1.414)
