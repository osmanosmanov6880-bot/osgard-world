extends RefCounted
## CITY REIGN R181 — actually walk on the ORIGINAL 36 sidewalk strips.
## The existing road A* solver STILL owns road topology and closures.
## This is a bounded, deterministic geometric expansion of its REAL path,
## not a new route planner, invisible teleport, collider or new saved state.
const MOBILITY=preload("res://scripts/city_mobility.gd")
const PAVEMENT_OFFSET_M: float=6.0
const MAX_SOURCE_WAYPOINTS: int=64
const MAX_GENERATED_WAYPOINTS: int=193
const GRID_TOLERANCE_M: float=0.08
const CORNER_JOIN_M: float=8.5

static func _grid_aligned(value: float) -> bool:
	if not is_finite(value):return false
	var index: int=roundi((value-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING)
	if index<0 or index>=MOBILITY.ROAD_SIZE:return false
	return (absf(value-(MOBILITY.ROAD_MIN+float(index)*MOBILITY.ROAD_SPACING))<
		GRID_TOLERANCE_M)

static func is_original_road_point(at: Vector3) -> bool:
	return at.is_finite() and _grid_aligned(at.x) and _grid_aligned(at.z)

static func edge_sidewalk_offset(a: Vector3,b: Vector3,
		citizen_id: int) -> Vector3:
	if not is_original_road_point(a) or not is_original_road_point(b):
		return Vector3.ZERO
	var dx: float=b.x-a.x
	var dz: float=b.z-a.z
	var side: float=1.0 if posmod(citizen_id,2)==0 else -1.0
	# Only genuine adjacent 52m A* grid EDGES can be shifted. The
	# source solver omitted closed streets, so we never synthesize one.
	if (absf(absf(dx)-MOBILITY.ROAD_SPACING)<GRID_TOLERANCE_M and
			absf(dz)<GRID_TOLERANCE_M):
		return Vector3(0.0,0.0,side*PAVEMENT_OFFSET_M)
	if (absf(absf(dz)-MOBILITY.ROAD_SPACING)<GRID_TOLERANCE_M and
			absf(dx)<GRID_TOLERANCE_M):
		return Vector3(side*PAVEMENT_OFFSET_M,0.0,0.0)
	return Vector3.ZERO

static func _append_unique(points: Array[Vector3],at: Vector3) -> void:
	if points.is_empty() or points[points.size()-1].distance_squared_to(at)>0.001:
		points.append(at)

static func to_sidewalk_route(source: Array[Vector3],
		citizen_id: int) -> Array[Vector3]:
	var original: Array[Vector3]=source.duplicate()
	if source.size()<2 or source.size()>MAX_SOURCE_WAYPOINTS:
		return original
	for pos in source:
		if not pos.is_finite():return original
	var result: Array[Vector3]=[]
	_append_unique(result,source[0])
	var prior_offset: Vector3=Vector3.ZERO
	for i in range(source.size()-1):
		var from: Vector3=source[i]
		var to: Vector3=source[i+1]
		if from.distance_squared_to(to)<0.001:continue
		var shift: Vector3=edge_sidewalk_offset(from,to,citizen_id)
		if shift==Vector3.ZERO:
			# First/last links to a genuine home/shop are preserved. At
			# a transition to a building entry, approach from sidewalk.
			_append_unique(result,from)
			_append_unique(result,to)
			prior_offset=Vector3.ZERO
			continue
		if (prior_offset!=Vector3.ZERO and
				prior_offset.distance_squared_to(shift)>0.001):
			# At a true 90-degree street corner, join the two EXISTING
			# sidewalk lips at their original 6m x 6m corner. Never cut
			# through building blocks or across a closed A* edge.
			_append_unique(result,from+prior_offset+shift)
		_append_unique(result,from+shift)
		_append_unique(result,to+shift)
		prior_offset=shift
		if result.size()>MAX_GENERATED_WAYPOINTS:return original
	_append_unique(result,source[source.size()-1])
	if result.size()>MAX_GENERATED_WAYPOINTS:return original
	return result

static func on_original_sidewalk(point: Vector3) -> bool:
	if not point.is_finite():return false
	# Matches WORLD_BUILDER._create_roads() physical ±6m sidewalk lips,
	# not the 10-metre-wide asphalt center; coordinate domains [-224,224].
	if absf(point.x)>225.0 or absf(point.z)>225.0:return false
	for road in range(MOBILITY.ROAD_SIZE):
		var center: float=MOBILITY.ROAD_MIN+float(road)*MOBILITY.ROAD_SPACING
		if (absf(absf(point.x-center)-PAVEMENT_OFFSET_M)<0.1 or
			absf(absf(point.z-center)-PAVEMENT_OFFSET_M)<0.1):
			return true
	return false

static func source_geometry_consistent() -> bool:
	return (MOBILITY.ROAD_SPACING==52.0 and MOBILITY.ROAD_SIZE==9 and
		PAVEMENT_OFFSET_M==6.0 and
		MAX_GENERATED_WAYPOINTS>MAX_SOURCE_WAYPOINTS*2)
