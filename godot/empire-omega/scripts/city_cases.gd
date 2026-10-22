extends RefCounted
## Repeatable, deterministic side stories with independent costs, deadlines and consequences.
## JSON contains only allow-listed resource effects; never executable script content.

const DATA_PATH = "res://data/city_cases.json"
const REGION_ORDER = ["forum", "housing", "lower", "aqueduct"]
const VALID_SITES = ["cityhall", "market", "depot", "power"]
const RESOURCE_LIMITS = {
	"treasury": [-20000000, 20000000], "wallet": [0, 30000000],
	"energy": [0, 100], "water": [0, 100], "food": [0, 100],
	"stability": [0, 100], "reputation": [0, 100], "road_quality": [0, 100],
	"science": [0, 200000], "unemployment": [0, 100]
}
static var _catalog_cache: Array = []

static func catalog() -> Array:
	if not _catalog_cache.is_empty():
		return _catalog_cache
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
	if not (parsed is Dictionary) or int(parsed.get("schema", -1)) != 1:
		push_error("OSGARD: invalid city-case catalog")
		return []
	var entries: Variant = parsed.get("cases", [])
	if not (entries is Array):
		return []
	_catalog_cache = entries
	return _catalog_cache

static func by_id(case_id: String) -> Dictionary:
	for entry in catalog():
		if str(entry.get("id", "")) == case_id:
			return entry
	return {}

static func current(state: Dictionary) -> Dictionary:
	var active: Dictionary = state.get("city_case", {})
	if active.is_empty():
		return {}
	return by_id(str(active.get("id", "")))

static func site(state: Dictionary) -> String:
	return str(current(state).get("site", ""))

static func _recently_used(state: Dictionary, case_id: String) -> bool:
	var prior: Array = state.get("case_history", [])
	for offset in range(maxi(0, prior.size()-6), prior.size()):
		if str(prior[offset].get("id", "")) == case_id:
			return true
	return false

static func maybe_open(state: Dictionary) -> bool:
	if not state.get("city_case", {}).is_empty() or int(state.get("turn", 1)) < 3:
		return false
	if int(state["turn"]) % 2 == 0:
		return false
	var eligible: Array = []
	for entry in catalog():
		if int(entry["min_turn"]) <= int(state["turn"]) and not _recently_used(state, str(entry["id"])):
			eligible.append(entry)
	if eligible.is_empty():
		return false
	var selector: int = int(state.get("seed",1)) + int(state["turn"]) * 17 + floori(float(state.get("population", 0)) / 50.0)
	var chosen: Dictionary = eligible[posmod(selector, eligible.size())]
	state["city_case"] = {"id":str(chosen["id"]),"opened_turn":int(state["turn"]),"due_turn":int(state["turn"])+2}
	return true

static func can_pay(state: Dictionary, option: Dictionary) -> bool:
	var costs: Dictionary = option.get("cost", {})
	for key in costs:
		var amount: int = int(costs[key])
		if amount < 0:
			return false
		if key == "materials" or key == "goods" or key == "grain":
			if int(state.get("inventories", {}).get(key, 0)) < amount:
				return false
		elif key == "wallet" or key == "treasury":
			if int(state.get(key,0)) < amount:
				return false
		else:
			return false
	return true

static func _apply_effects(state: Dictionary, case: Dictionary, effects: Dictionary) -> void:
	var district: String = str(case["district"])
	for key in effects:
		var amount: int = int(effects[key])
		if key == "trust":
			var idx: int = REGION_ORDER.find(district)
			if idx >= 0:
				state["trust"][idx] = clampi(int(state["trust"][idx])+amount,0,100)
		elif RESOURCE_LIMITS.has(key):
			var limits: Array = RESOURCE_LIMITS[key]
			state[key] = clampi(int(state.get(key,0))+amount,int(limits[0]),int(limits[1]))
		elif key in ["grain", "goods", "materials"]:
			state["inventories"][key] = clampi(int(state["inventories"].get(key,0))+amount,0,10000)

static func _record(state: Dictionary, case_id: String, outcome: String) -> void:
	state["case_history"].append({"id":case_id,"turn":int(state["turn"]),"outcome":outcome})
	while state["case_history"].size() > 24:
		state["case_history"].pop_front()

static func resolve(state: Dictionary, option_id: String) -> bool:
	var case: Dictionary = current(state)
	if case.is_empty():
		return false
	var active: Dictionary = state["city_case"]
	if int(state["turn"]) >= int(active["due_turn"]):
		return false
	var chosen: Dictionary = {}
	for option in case["options"]:
		if str(option["id"]) == option_id:
			chosen = option
			break
	if chosen.is_empty() or not can_pay(state,chosen):
		return false
	for resource in chosen["cost"]:
		var amount: int = int(chosen["cost"][resource])
		if resource in ["materials", "goods", "grain"]:
			state["inventories"][resource] -= amount
		else:
			state[resource] -= amount
	_apply_effects(state,case,chosen.get("effects",{}))
	_record(state,str(case["id"]),option_id)
	state["city_case"] = {}
	return true

static func expire(state: Dictionary) -> String:
	var active: Dictionary = state.get("city_case", {})
	if active.is_empty() or int(state["turn"]) < int(active.get("due_turn",1000000)):
		return ""
	var case: Dictionary = current(state)
	if case.is_empty():
		state["city_case"] = {}
		return ""
	_apply_effects(state,case,case.get("expire_effects",{}))
	_record(state,str(case["id"]),"expired")
	state["city_case"] = {}
	return str(case["id"])

static func _integer_like(value: Variant, low: int, high: int) -> bool:
	if not (value is float or value is int): return false
	var number: float = float(value)
	return is_finite(number) and number >= float(low) and number <= float(high) and floorf(number) == number

static func valid_state(state: Dictionary) -> bool:
	if state.has("city_case"):
		if not (state["city_case"] is Dictionary): return false
		var active: Dictionary = state["city_case"]
		if not active.is_empty():
			if active.size() != 3 or by_id(str(active.get("id", ""))).is_empty(): return false
			if not _integer_like(active.get("opened_turn"),3,100000) or not _integer_like(active.get("due_turn"),3,100002): return false
			if int(active["opened_turn"]) < 3 or int(active["opened_turn"]) > int(state.get("turn",0)): return false
			if int(active["due_turn"]) != int(active["opened_turn"]) + 2: return false
			if int(active["due_turn"]) <= int(state.get("turn",0)): return false
	if state.has("case_history"):
		if not (state["case_history"] is Array) or state["case_history"].size() > 24: return false
		for record in state["case_history"]:
			if not (record is Dictionary) or record.size() != 3: return false
			if by_id(str(record.get("id", ""))).is_empty(): return false
			if not ["invest", "mobilize", "expired"].has(str(record.get("outcome", ""))): return false
			if not _integer_like(record.get("turn"),1,int(state.get("turn",0))): return false
	return true
