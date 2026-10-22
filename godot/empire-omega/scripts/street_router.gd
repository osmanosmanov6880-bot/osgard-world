extends RefCounted
## Legacy routing facade; all clients now use the same closure-aware road graph.
const MOBILITY = preload("res://scripts/city_mobility.gd")
const GRID_SIZE = 9
const ROAD_SPACING = 52.0
const ROAD_MIN = -208.0

static func find_route(start: Vector3, destination: Vector3, state: Dictionary = {}) -> Array[Vector3]:
	return MOBILITY.find_route(start,destination,state)
