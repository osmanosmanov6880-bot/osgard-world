extends RefCounted
## v0.13: deterministic public-service assignments. All rewards are settled by GameState.
## No network traffic or real-world location is used. All movement is measured in-game.

const CATALOG_PATH = "res://data/service_calls.json"
const LOCATIONS = {
	"cityhall":Vector3(-130.0,0.0,-130.0),
	"market":Vector3(130.0,0.0,-130.0),
	"depot":Vector3(-130.0,0.0,130.0),
	"power":Vector3(130.0,0.0,130.0)
}
const DISTRICT_BY_LOCATION = {"market":"housing","depot":"lower","power":"aqueduct"}
const VEHICLES = ["compact","courier","executive","utility"]
const LIMIT = 50000000.0
const MAX_DRIVE_STEP = 25.0
static var _cached_catalog: Array = []

static func catalog() -> Array:
	if not _cached_catalog.is_empty(): return _cached_catalog
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not (raw is Dictionary) or not (raw.get("requests") is Array):
		return []
	_cached_catalog = raw["requests"]
	return _cached_catalog

static func request_by_id(request_id: String) -> Dictionary:
	for item in catalog():
		if item is Dictionary and str(item.get("id","")) == request_id:
			return item
	return {}

static func offer(state: Dictionary) -> Dictionary:
	var entries: Array = catalog()
	if entries.is_empty(): return {}
	var index: int = posmod(int(state.get("seed",1)) + 7 * int(state.get("turn",1)) + 3 * int(state.get("service_completed",0)) + 11 * int(state.get("service_failed",0)),entries.size())
	var result: Variant = entries[index]
	return result.duplicate(true) if result is Dictionary else {}

static func required_distance(destination: String) -> float:
	if not DISTRICT_BY_LOCATION.has(destination): return 0.0
	var a: Vector3 = LOCATIONS["cityhall"]
	var b: Vector3 = LOCATIONS[destination]
	var direct: float = Vector2(a.x,a.z).distance_to(Vector2(b.x,b.z))
	return clampf(ceilf(direct * 0.65),100.0,400.0)

static func begin(request: Dictionary, state: Dictionary) -> Dictionary:
	var destination: String = str(request.get("destination",""))
	if not DISTRICT_BY_LOCATION.has(destination): return {}
	return {
		"id":str(request["id"]),"destination":destination,
		"vehicle":str(state.get("vehicle_selected","compact")),
		"start_turn":int(state["turn"]),"due_turn":int(state["turn"]) + int(request.get("duration",2)),
		"required":required_distance(destination),"meters":0.0,"condition":100.0,
		"last_mileage":float(state.get("vehicle_mileage",0.0)),
		"last_health":float(state.get("vehicle_health",100.0))
	}

static func track(active: Dictionary, mileage: float, health: float, moving: bool, weather: String, selected: String) -> void:
	if active.is_empty() or str(active.get("vehicle","")) != selected:
		return
	var previous_mileage: float = float(active["last_mileage"])
	var previous_health: float = float(active["last_health"])
	var distance: float = maxf(0.0,mileage-previous_mileage) if moving else 0.0
	active["last_mileage"] = clampf(mileage,0.0,LIMIT)
	active["last_health"] = clampf(health,0.0,100.0)
	if not moving or distance > MAX_DRIVE_STEP:
		return
	var damage: float = maxf(0.0,previous_health-health)
	var exposure: float = 0.012 if weather == "storm" else (0.006 if weather == "rain" else 0.002)
	active["meters"] = minf(100000.0,float(active["meters"])+distance)
	active["condition"] = clampf(float(active["condition"])-damage*0.7-distance*exposure,5.0,100.0)

static func ready(active: Dictionary) -> bool:
	return not active.is_empty() and float(active.get("meters",0.0)) >= float(active.get("required",100.0))

static func payout(base: int, condition: float, bonus: float) -> int:
	var quality: float = 0.55 + 0.0045 * clampf(condition,5.0,100.0)
	return clampi(roundi(float(base)*quality*(1.0+clampf(bonus,0.0,0.4))),60,3200)

static func valid_active(value: Variant) -> bool:
	if not (value is Dictionary): return false
	if value.is_empty(): return true
	var fields := ["id","destination","vehicle","start_turn","due_turn","required","meters","condition","last_mileage","last_health"]
	if value.size() != fields.size(): return false
	for field in fields:
		if not value.has(field): return false
	var request: Dictionary = request_by_id(str(value["id"]))
	if request.is_empty() or str(value["destination"]) != str(request["destination"]): return false
	if not VEHICLES.has(str(value["vehicle"])): return false
	for field in ["start_turn","due_turn","required","meters","condition","last_mileage","last_health"]:
		var number: Variant = value[field]
		if not (number is int or number is float) or not is_finite(float(number)): return false
	if int(value["start_turn"]) < 1 or int(value["start_turn"]) > 100000: return false
	if int(value["due_turn"]) != int(value["start_turn"]) + int(request.get("duration",2)): return false
	if absf(float(value["required"])-required_distance(str(value["destination"]))) > 0.01: return false
	if float(value["meters"]) < 0.0 or float(value["meters"]) > 100000.0: return false
	if float(value["condition"]) < 5.0 or float(value["condition"]) > 100.0: return false
	if float(value["last_mileage"]) < 0.0 or float(value["last_mileage"]) > LIMIT: return false
	if float(value["last_health"]) < 0.0 or float(value["last_health"]) > 100.0: return false
	return true

static func valid_history(value: Variant) -> bool:
	if not (value is Array) or value.size() > 24: return false
	for item in value:
		if not (item is Dictionary) or item.size() != 4: return false
		if request_by_id(str(item.get("id",""))).is_empty(): return false
		if not ["completed","expired"].has(str(item.get("result",""))): return false
		if not (item.get("turn") is int or item.get("turn") is float): return false
		if int(item["turn"]) < 1 or int(item["turn"]) > 100000: return false
		if not (item.get("reward") is int or item.get("reward") is float): return false
		if int(item["reward"]) < 0 or int(item["reward"]) > 3200: return false
	return true

static func goal_text(state: Dictionary, language: String) -> String:
	var active: Dictionary = state.get("service_active",{})
	var request: Dictionary = offer(state) if active.is_empty() else request_by_id(str(active.get("id","")))
	if request.is_empty(): return ""
	var title: Dictionary = request.get("title",{})
	var local_title: String = str(title.get(language,title.get("ru","Service")))
	if active.is_empty():
		var intro := {"ru":"R у дворца: служба города", "en":"R at City Hall: public service", "zh":"市政厅按 R：公共服务"}
		return str(intro.get(language,intro["ru"])) + "\n" + local_title
	var target := {"market":{"ru":"Торговая галерея","en":"Market","zh":"市场"},"depot":{"ru":"Логистический терминал","en":"Depot","zh":"货运站"},"power":{"ru":"Энергетическая станция","en":"Power station","zh":"电站"}}
	var label: String = str(target.get(str(active["destination"]),{}).get(language,"Destination"))
	var percent: int = roundi(100.0 * minf(1.0,float(active["meters"])/maxf(1.0,float(active["required"]))))
	var progress := {"ru":"Маршрут", "en":"Distance", "zh":"路程"}
	return "%s\n%s · %s %d%% · %d/100" % [local_title,label,str(progress.get(language,progress["ru"])),percent,roundi(float(active["condition"]))]

static func status_message(code: String, language: String) -> String:
	var messages := {
		"accepted":["Городское поручение принято. Езжайте к цели.","Service call accepted. Drive to the destination.","已接城市任务，请驾车前往目的地。"],
		"completed":["Городское поручение выполнено. Награда начислена.","Public service completed. Reward awarded.","城市任务完成，奖励已发放。"],
		"busy":["Сначала завершите грузовой рейс или текущее поручение.","Finish your freight or current service call first.","请先完成货运或当前任务。"],
		"used":["Новое поручение появится в следующем такте.","Another dispatch opens next turn.","下一回合将有新任务。"],
		"wrong_vehicle":["Нужна машина, на которой было принято поручение.","Use the assigned vehicle.","请使用接单车辆。"],
		"stop":["Остановите машину перед завершением поручения.","Stop the vehicle before completing the call.","请停车后再完成任务。"],
		"travel_more":["Недостаточно пройденного пути: следуйте по дорогам.","Drive the remaining route before completion.","请继续行驶完成剩余路程。"],
		"expired":["Срок поручения истёк. Последствия отражены в городе.","Service call expired; the city felt the consequences.","任务已逾期，城市状况受到影响。"],
		"location":["Подъезжайте к дворцу правителя и нажмите R.","Drive to City Hall and press R.","请开车到市政厅并按 R。"],
		"unavailable":["Поручение сейчас недоступно.","Service not currently available.","当前无法接取任务。"]
	}
	var values: Array = messages.get(code,messages["unavailable"])
	return str(values[0] if language == "ru" else (values[1] if language == "en" else values[2]))
