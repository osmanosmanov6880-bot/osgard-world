extends RefCounted
## HORIZON R10: road-aware racing directions from the same closure-aware A*
## graph that powers the city's minimap. Presentation only: never changes
## GameState, checkpoints, real mileage or reward settlement.
const LABELS = {
	"ru":{"ahead":"ПРЯМО","left":"НАЛЕВО","right":"НАПРАВО","back":"РАЗВОРОТ","closed":"НЕТ ПРОЕЗДА"},
	"en":{"ahead":"STRAIGHT","left":"LEFT","right":"RIGHT","back":"TURN BACK","closed":"ROAD BLOCKED"},
	"zh":{"ahead":"直行","left":"左转","right":"右转","back":"掉头","closed":"道路封闭"}
}
const MAX_PATH_AGE_DISTANCE: float = 55.0
const MAX_ROAD_DEVIATION: float = 28.0
const MIN_LEAD: float = 10.0

static func _flat(world: Vector3) -> Vector2:
	return Vector2(world.x,world.z)

static func _valid(point: Vector3) -> bool:
	return is_finite(point.x) and is_finite(point.y) and is_finite(point.z)

static func _road_direction(delta: Vector2, yaw: float, tr: Dictionary) -> String:
	var forward := Vector2(-sin(yaw),-cos(yaw))
	var right := Vector2(cos(yaw),-sin(yaw))
	var ahead: float = delta.dot(forward)
	var side: float = delta.dot(right)
	if ahead < -absf(side)*0.65: return str(tr["back"])
	if side > absf(ahead)*0.50: return str(tr["right"])
	if side < -absf(ahead)*0.50: return str(tr["left"])
	return str(tr["ahead"])

static func decorate(base: Dictionary, car: Vector3, yaw: float, path: Array[Vector3], locale: String = "ru") -> Dictionary:
	if base.is_empty() or not _valid(car) or not is_finite(yaw):
		return base
	var straight_distance: float = float(base.get("distance",0.0))
	if not is_finite(straight_distance) or straight_distance <= 10.0:
		return base # the physical checkpoint gate always takes precedence
	if path.is_empty():
		return base # no fresh graph result yet; preserve useful R9 direction
	if not _valid(path[0]) or _flat(path[0]).distance_to(_flat(car)) > MAX_PATH_AGE_DISTANCE:
		return base # don't use a route from a distant, previously loaded position
	var tr: Dictionary = LABELS.get(locale,LABELS["ru"])
	var result: Dictionary = base.duplicate(true)
	if path.size() == 1:
		result["direction"] = tr["closed"]
		result["details"] = "%s · %d с" % [str(tr["closed"]),int(base.get("seconds",0))]
		result["road_status"] = "blocked"
		return result # an A* disconnected graph is not a straight-line route
	if path.size() > 100:
		return base
	var me := _flat(car)
	var closest_index: int = -1
	var closest_distance_squared: float = INF
	var closest_fraction: float = 0.0
	for i in range(path.size()-1):
		if not _valid(path[i]) or not _valid(path[i+1]):
			return base
		var a := _flat(path[i])
		var b := _flat(path[i+1])
		var segment := b-a
		var length_sq: float = segment.length_squared()
		if length_sq < 0.001: continue
		var fraction: float = clampf((me-a).dot(segment)/length_sq,0.0,1.0)
		var projection: Vector2 = a+segment*fraction
		var d2: float = me.distance_squared_to(projection)
		if d2 < closest_distance_squared:
			closest_distance_squared = d2
			closest_index = i
			closest_fraction = fraction
	if closest_index < 0 or closest_distance_squared > MAX_ROAD_DEVIATION*MAX_ROAD_DEVIATION:
		return base
	var start: Vector2 = _flat(path[closest_index])
	var finish: Vector2 = _flat(path[closest_index+1])
	var projected: Vector2 = start.lerp(finish,closest_fraction)
	var meters: float = me.distance_to(projected)+projected.distance_to(finish)
	for i in range(closest_index+2,path.size()):
		meters += _flat(path[i-1]).distance_to(_flat(path[i]))
	if not is_finite(meters) or meters < straight_distance*0.5 or meters > 5000.0:
		return base
	var lead: Vector2 = finish
	for i in range(closest_index+1,path.size()):
		var p := _flat(path[i])
		if me.distance_to(p) >= MIN_LEAD:
			lead = p
			break
	var course: Vector2 = lead-me
	if course.length() < 0.1:
		return base
	var direction: String = _road_direction(course,yaw,tr)
	result["direction"] = direction
	result["details"] = "%s · %d м · %d с" % [direction,roundi(meters),int(base.get("seconds",0))]
	result["road_distance"] = meters
	result["road_status"] = "routed"
	return result
