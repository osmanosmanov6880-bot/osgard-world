extends RefCounted
## Deterministic, state-aware 9x9 road network shared by traffic, pedestrians,
## GPS, road repair, and economic transport efficiency. No random global state.
const CATALOG_PATH = "res://data/road_incidents.json"
const ROAD_MIN = -208.0
const ROAD_SPACING = 52.0
const ROAD_SIZE = 9
static var _catalog: Dictionary = {}

static func catalog() -> Dictionary:
	if _catalog.is_empty():
		var decoded: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
		if decoded is Dictionary:
			_catalog = decoded
	return _catalog

static func _grid(pos: Vector3) -> Vector2i:
	return Vector2i(clampi(roundi((pos.x - ROAD_MIN) / ROAD_SPACING), 0, ROAD_SIZE-1),clampi(roundi((pos.z - ROAD_MIN) / ROAD_SPACING), 0, ROAD_SIZE-1))

static func _pos(point: Vector2i) -> Vector3:
	return Vector3(ROAD_MIN + float(point.x)*ROAD_SPACING,0.8,ROAD_MIN + float(point.y)*ROAD_SPACING)

static func _id(point: Vector2i) -> int:
	return point.y * ROAD_SIZE + point.x

static func edge_key(a: Vector2i, b: Vector2i) -> String:
	var first: int = mini(_id(a),_id(b))
	var second: int = maxi(_id(a),_id(b))
	return "%d:%d" % [first,second]

static func _incident_edge(incident: Dictionary) -> String:
	var a: Array = incident["a"]
	var b: Array = incident["b"]
	return edge_key(Vector2i(int(a[0]),int(a[1])),Vector2i(int(b[0]),int(b[1])))

static func active_incidents(state: Dictionary) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var entries: Array = catalog().get("incidents",[])
	if entries.is_empty():
		return results
	var turn: int = maxi(1,int(state.get("turn",1)))
	var seed: int = int(state.get("seed",781413))
	var first: int = posmod(seed + turn*7,entries.size())
	var selected: Array[int] = [first]
	if turn % 3 == 0 and int(state.get("road_quality",75)) < 90:
		selected.append((first+5) % entries.size())
	var cleared: Array = state.get("roads_cleared",[])
	for index in selected:
		var incident: Dictionary = entries[index]
		if not cleared.has(str(incident["id"])):
			results.append(incident)
	return results

static func incident_by_id(id: String) -> Dictionary:
	for item in catalog().get("incidents",[]):
		if str(item.get("id","")) == id:
			return item
	return {}

static func incident_at(id: String) -> Vector3:
	var info: Dictionary = incident_by_id(id)
	if info.is_empty():
		return Vector3.ZERO
	var a: Array = info["a"]
	var b: Array = info["b"]
	return (_pos(Vector2i(int(a[0]),int(a[1]))) + _pos(Vector2i(int(b[0]),int(b[1])))) * 0.5

static func freight_efficiency(state: Dictionary) -> float:
	# An understandable citywide loss, rather than invisible magic deductions.
	var blocked: int = active_incidents(state).size()
	var quality: int = clampi(int(state.get("road_quality",75)),0,100)
	return clampf(1.0 - float(blocked)*0.035 - float(100-quality)*0.0015,0.72,1.0)

static func find_route(start: Vector3, destination: Vector3, state: Dictionary = {}) -> Array[Vector3]:
	var solver := AStar2D.new()
	var closures := {}
	for incident in active_incidents(state):
		closures[_incident_edge(incident)] = true
	for y in range(ROAD_SIZE):
		for x in range(ROAD_SIZE):
			var here: Vector2i = Vector2i(x,y)
			var coords: Vector3 = _pos(here)
			solver.add_point(_id(here),Vector2(coords.x,coords.z))
	for y in range(ROAD_SIZE):
		for x in range(ROAD_SIZE):
			var here: Vector2i = Vector2i(x,y)
			if x+1 < ROAD_SIZE:
				var east: Vector2i = here + Vector2i.RIGHT
				if not closures.has(edge_key(here,east)):
					solver.connect_points(_id(here),_id(east))
			if y+1 < ROAD_SIZE:
				var south: Vector2i = here + Vector2i.DOWN
				if not closures.has(edge_key(here,south)):
					solver.connect_points(_id(here),_id(south))
	var route: PackedInt64Array = solver.get_id_path(_id(_grid(start)),_id(_grid(destination)))
	var answer: Array[Vector3] = [start]
	if route.is_empty():
		return answer # disconnected destination: don't invent a straight-line route
	for node in route:
		var x: int = int(node) % ROAD_SIZE
		var y: int = int(int(node) / ROAD_SIZE)
		answer.append(_pos(Vector2i(x,y)))
	answer.append(destination)
	return answer

static func length(route: Array[Vector3]) -> float:
	var meters := 0.0
	for i in range(1,route.size()):
		meters += route[i].distance_to(route[i-1])
	return meters
