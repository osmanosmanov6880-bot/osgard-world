extends RefCounted
## Data-driven neighborhood errands: talk -> collect -> physically drive -> deliver.
## All state changes are made by GameState, never by map/HUD objects.
## Only fixed allow-listed catalog fields are interpreted; JSON is not executable.

const DATA_PATH = "res://data/neighborhood_jobs.json"
const REGIONS = ["forum", "housing", "lower", "aqueduct"]
const LOCATIONS = ["cityhall", "market", "depot", "power"]
const LOCATION_NAMES = {
	"cityhall":{"ru":"Дворец правителя","en":"City Hall","zh":"市政厅"},
	"market":{"ru":"Торговая галерея","en":"Market Gallery","zh":"市场"},
	"depot":{"ru":"Логистический терминал","en":"Logistics Depot","zh":"物流站"},
	"power":{"ru":"Энергетическая станция","en":"Power Station","zh":"电站"}
}
const EFFECT_LIMITS = {
	"energy":[0,100], "water":[0,100], "food":[0,100],
	"stability":[0,100], "unemployment":[0,100],
	"road_quality":[0,100], "science":[0,200000]
}
const MAX_HISTORY = 24
static var _entries: Array = []

static func _integer(value: Variant, minimum: int, maximum: int) -> bool:
	if not (value is int or value is float): return false
	var n: float = float(value)
	return is_finite(n) and n == floorf(n) and n >= float(minimum) and n <= float(maximum)

static func _valid_entry(entry: Variant) -> bool:
	if not (entry is Dictionary): return false
	if not (entry.get("id") is String) or str(entry["id"]).length() > 48: return false
	if not REGIONS.has(str(entry.get("district",""))): return false
	if not LOCATIONS.has(str(entry.get("pickup",""))) or not LOCATIONS.has(str(entry.get("dropoff",""))): return false
	if entry["pickup"] == entry["dropoff"]: return false
	if not _integer(entry.get("supply_cost"),10,100): return false
	if not _integer(entry.get("reward"),60,1000): return false
	if int(entry["reward"]) <= int(entry["supply_cost"]): return false
	if not _integer(entry.get("min_drive"),60,500): return false
	if not _integer(entry.get("due_turns"),1,4): return false
	var effect: String = str(entry.get("effect",""))
	if not EFFECT_LIMITS.has(effect): return false
	if not _integer(entry.get("impact"),-15,15): return false
	for field in ["title","description"]:
		if not (entry.get(field) is Dictionary): return false
		for lang in ["ru","en","zh"]:
			var translated: Variant = entry[field].get(lang)
			if not (translated is String) or translated.length() < 3 or translated.length() > 200: return false
	return true

static func catalog() -> Array:
	if not _entries.is_empty(): return _entries
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (data is Dictionary) or not _integer(data.get("schema"),1,1):
		push_error("OSGARD: invalid neighborhood catalog header")
		return []
	var jobs: Variant = data.get("jobs",[])
	if not (jobs is Array) or jobs.size() < 8 or jobs.size() > 80: return []
	var unique := {}
	for entry in jobs:
		if not _valid_entry(entry):
			push_error("OSGARD: invalid neighborhood template")
			return []
		if unique.has(entry["id"]): return []
		unique[entry["id"]] = true
	_entries = jobs
	return _entries

static func by_id(job_id: String) -> Dictionary:
	for item in catalog():
		if str(item["id"]) == job_id: return item
	return {}

static func offer(state: Dictionary, citizen_id: int, district: String) -> Dictionary:
	if citizen_id < 0 or citizen_id >= 34 or not REGIONS.has(district): return {}
	var candidates: Array = []
	for job in catalog():
		if str(job["district"]) == district: candidates.append(job)
	if candidates.is_empty(): return {}
	var seed: int = int(state.get("seed",1)) + int(state.get("turn",1))*17 + citizen_id*13
	return candidates[posmod(seed,candidates.size())]

static func can_accept(state: Dictionary, citizen_id: int, district: String) -> bool:
	if not state.get("neighborhood_active",{}).is_empty(): return false
	if not state.get("active_contract",{}).is_empty() or not state.get("service_active",{}).is_empty(): return false
	if int(state.get("neighborhood_last_turn",0)) == int(state.get("turn",1)): return false
	if int(state.get("citizen_contacts",{}).get(str(citizen_id),-1)) == int(state.get("turn",1)): return false
	return not offer(state,citizen_id,district).is_empty()

static func accept(state: Dictionary, citizen_id: int, district: String) -> bool:
	if not can_accept(state,citizen_id,district): return false
	var job: Dictionary = offer(state,citizen_id,district)
	var turn: int = int(state["turn"])
	state["neighborhood_active"] = {
		"id":str(job["id"]),"citizen":citizen_id,"district":district,"stage":"pickup",
		"accepted_turn":turn,"due_turn":turn+int(job["due_turns"]),
		"vehicle":"","start_meter":0.0
	}
	state["neighborhood_last_turn"] = turn
	state["citizen_contacts"][str(citizen_id)] = turn
	return true

static func goal_location(state: Dictionary) -> String:
	var active: Dictionary = state.get("neighborhood_active",{})
	if active.is_empty(): return ""
	var job: Dictionary = by_id(str(active.get("id","")))
	if job.is_empty(): return ""
	return str(job["pickup"] if active.get("stage","") == "pickup" else job["dropoff"])

static func interact(state: Dictionary, location: String, vehicle_near: bool, driving: bool, speed: float) -> String:
	var active: Dictionary = state.get("neighborhood_active",{})
	if active.is_empty(): return "not_active"
	var job: Dictionary = by_id(str(active.get("id","")))
	if job.is_empty() or location != goal_location(state): return "not_here"
	if int(state["turn"]) > int(active["due_turn"]): return "expired"
	if absf(speed) > 1.5: return "stop"
	if active["stage"] == "pickup":
		if not vehicle_near: return "vehicle_near"
		if int(state["wallet"]) < int(job["supply_cost"]): return "funds"
		state["wallet"] -= int(job["supply_cost"])
		active["stage"] = "deliver"
		active["vehicle"] = str(state["vehicle_selected"])
		active["start_meter"] = float(state["vehicle_mileage"])
		return "collected"
	if active["stage"] != "deliver": return "unavailable"
	if not driving or str(state["vehicle_selected"]) != str(active["vehicle"]): return "wrong_vehicle"
	if float(state["vehicle_mileage"]) - float(active["start_meter"]) + 0.0001 < float(job["min_drive"]):
		return "distance"
	var earned: int = int(job["reward"])
	if int(state["wallet"]) + earned > 30000000: return "wallet_full"
	state["wallet"] += earned
	state["money_earned"] = mini(20000000,int(state["money_earned"]) + earned)
	state["neighborhood_completed"] = mini(100000,int(state.get("neighborhood_completed",0))+1)
	state["reputation"] = mini(100,int(state.get("reputation",35))+2)
	var region: int = REGIONS.find(str(job["district"]))
	state["trust"][region] = mini(100,int(state["trust"][region])+3)
	var effect_name: String = str(job["effect"])
	var bounds: Array = EFFECT_LIMITS[effect_name]
	state[effect_name] = clampi(int(state.get(effect_name,0))+int(job["impact"]),int(bounds[0]),int(bounds[1]))
	_record(state,job,"completed",earned)
	state["neighborhood_active"] = {}
	return "completed"

static func _record(state: Dictionary, job: Dictionary, outcome: String, reward: int) -> void:
	var history: Array = state["neighborhood_history"]
	history.push_front({"id":str(job["id"]),"turn":int(state["turn"]),"status":outcome,"reward":reward,"citizen":int(state["neighborhood_active"]["citizen"])})
	if history.size() > MAX_HISTORY: history.resize(MAX_HISTORY)

static func expire(state: Dictionary) -> String:
	var active: Dictionary = state.get("neighborhood_active",{})
	if active.is_empty() or int(state.get("turn",0)) <= int(active.get("due_turn",100000)): return ""
	var job: Dictionary = by_id(str(active.get("id","")))
	if job.is_empty():
		state["neighborhood_active"] = {}
		return ""
	var idx: int = REGIONS.find(str(job["district"]))
	state["trust"][idx] = maxi(0,int(state["trust"][idx])-2)
	state["reputation"] = maxi(0,int(state.get("reputation",35))-1)
	_record(state,job,"expired",0)
	state["neighborhood_active"] = {}
	return str(job["id"])

static func valid(state: Dictionary) -> bool:
	if state.has("neighborhood_last_turn"):
		if not _integer(state["neighborhood_last_turn"],0,100000): return false
		if int(state["neighborhood_last_turn"]) > int(state.get("turn",0)): return false
	if state.has("neighborhood_completed") and not _integer(state["neighborhood_completed"],0,100000): return false
	if state.has("neighborhood_history"):
		if not (state["neighborhood_history"] is Array) or state["neighborhood_history"].size() > MAX_HISTORY: return false
		for item in state["neighborhood_history"]:
			if not (item is Dictionary) or item.size() != 5: return false
			var job: Dictionary = by_id(str(item.get("id","")))
			if job.is_empty(): return false
			if not _integer(item.get("turn"),1,int(state.get("turn",1))): return false
			if not _integer(item.get("citizen"),0,33): return false
			var result: String = str(item.get("status",""))
			if not ["completed","expired"].has(result): return false
			if not _integer(item.get("reward"),0,1000): return false
			if int(item["reward"]) != (int(job["reward"]) if result == "completed" else 0): return false
	if state.has("neighborhood_active"):
		if not (state["neighborhood_active"] is Dictionary): return false
		var active: Dictionary = state["neighborhood_active"]
		if not active.is_empty():
			if active.size() != 8: return false
			var job: Dictionary = by_id(str(active.get("id","")))
			if job.is_empty(): return false
			if str(active.get("district","")) != str(job["district"]): return false
			if not _integer(active.get("citizen"),0,33): return false
			if not ["pickup","deliver"].has(str(active.get("stage",""))): return false
			if not _integer(active.get("accepted_turn"),1,100000): return false
			if not _integer(active.get("due_turn"),1,100004): return false
			if int(active["due_turn"]) != int(active["accepted_turn"])+int(job["due_turns"]): return false
			if int(active["accepted_turn"]) > int(state.get("turn",0)) or int(active["due_turn"]) < int(state.get("turn",0)): return false
			if int(state.get("neighborhood_last_turn",0)) != int(active["accepted_turn"]): return false
			if int(state.get("citizen_contacts",{}).get(str(active["citizen"]),-1)) != int(active["accepted_turn"]): return false
			if not (active.get("vehicle") is String): return false
			if not (active.get("start_meter") is int or active.get("start_meter") is float): return false
			if not is_finite(float(active["start_meter"])) or float(active["start_meter"]) < 0.0: return false
			if active["stage"] == "pickup":
				if active["vehicle"] != "" or float(active["start_meter"]) != 0.0: return false
			else:
				if str(active["vehicle"]) != str(state.get("vehicle_selected","")): return false
				if float(active["start_meter"]) > float(state.get("vehicle_mileage",0.0)) + 0.001: return false
	return true

static func goal_text(state: Dictionary, lang: String) -> String:
	var active: Dictionary = state.get("neighborhood_active",{})
	if active.is_empty():
		var empty := {"ru":"Поговорите с жителем (J) — новые поручения","en":"Talk to a resident (J) for local work","zh":"与居民交谈 (J) 接受委托"}
		return str(empty.get(lang,empty["ru"]))
	var job: Dictionary = by_id(str(active.get("id","")))
	if job.is_empty(): return ""
	var local_name: String = str(job["title"].get(lang,job["title"]["ru"]))
	var target: String = goal_location(state)
	var at: String = str(LOCATION_NAMES[target].get(lang,LOCATION_NAMES[target]["ru"]))
	if active["stage"] == "pickup":
		var prefix := {"ru":"Заберите материалы","en":"Collect supplies","zh":"领取物资"}
		return "%s: %s  ·  %d ₽\n%s" % [str(prefix.get(lang,prefix["ru"])),at,int(job["supply_cost"]),local_name]
	var progress: int = clampi(roundi(100.0 * maxf(0.0,float(state["vehicle_mileage"])-float(active["start_meter"])) / float(job["min_drive"])),0,100)
	var deliver := {"ru":"Доставьте","en":"Deliver","zh":"送往"}
	return "%s: %s  ·  %d%%\n%s" % [str(deliver.get(lang,deliver["ru"])),at,progress,local_name]

static func status_text(code: String, lang: String) -> String:
	var descriptions := {
		"accepted":["Поручение принято. Следуйте к месту выдачи.","Errand accepted. Go to the pickup.","已接受委托，请前往领取地点。"],
		"collected":["Материалы оплачены и погружены. Езжайте к получателю.","Supplies purchased and loaded. Drive to the destination.","物资已购买装车，请驾车前往目的地。"],
		"completed":["Поручение выполнено. Награда и доверие начислены.","Errand complete. Payment and trust awarded.","委托完成，已获得报酬及信任。"],
		"busy":["Сначала завершите текущее задание. Одно поручение за такт.","Finish your existing assignment first; one job per turn.","请先完成当前任务，每回合限接一个委托。"],
		"vehicle_near":["Припаркуйте автомобиль рядом с местом выдачи.","Park your vehicle near the pickup.","请将车辆停在领取点附近。"],
		"stop":["Остановите автомобиль для погрузки или разгрузки.","Stop the vehicle before loading or delivery.","装卸前请停车。"],
		"funds":["Не хватает личных денег на покупку материалов.","Not enough personal money for supplies.","个人资金不足，无法购买物资。"],
		"wrong_vehicle":["Привезите заказ на той машине, на которую его погрузили.","Deliver using the vehicle that collected the supplies.","请用装货时的车辆送达。"],
		"distance":["Недостаточно пробега: отвезите груз по улицам.","Drive the required distance before delivery.","行驶里程不足，请按路线运送。"],
		"expired":["Срок поручения истёк. Доверие жителей снизилось.","Job expired. District trust has fallen.","委托已逾期，地区信任下降。"],
		"wallet_full":["Кошелёк достиг игрового лимита.","Wallet reached the game limit.","钱包已达到游戏上限。"],
		"not_here":["Следуйте к месту назначения, отмеченному на карте.","Follow the marked destination on the map.","请前往地图标记的目的地。"],
		"unavailable":["Поручение сейчас недоступно.","This job is unavailable.","当前无法接受此委托。"]
	}
	var values: Array = descriptions.get(code,descriptions["unavailable"])
	return str(values[0] if lang == "ru" else (values[1] if lang == "en" else values[2]))
