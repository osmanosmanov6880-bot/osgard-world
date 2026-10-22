extends RefCounted
## v0.20: one-time on-foot exploration tied to the authoritative GameState.
## All locations are on street intersections and have no additional colliders.
const FILE = "res://data/city_discoveries.json"
const DISTRICTS = ["forum","housing","lower","aqueduct"]
const LANGUAGES = ["ru","en","zh"]
const WALLET_REWARD = 60
const SCIENCE_REWARD = 4
const MAX_HISTORY = 12
static var _catalog: Array = []

static func sites() -> Array:
	if not _catalog.is_empty(): return _catalog
	var raw: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	if not (raw is Dictionary) or int(raw.get("schema",0)) != 1: return []
	var values: Variant = raw.get("sites",[])
	if not (values is Array) or values.size() != 12: return []
	var visited := {}
	for item in values:
		if not valid_site(item) or visited.has(item["id"]): return []
		visited[item["id"]] = true
	_catalog = values
	return _catalog

static func valid_site(item: Variant) -> bool:
	if not (item is Dictionary): return false
	if not (item.get("id") is String) or str(item["id"]).length() > 40 or str(item["id"]).is_empty(): return false
	if not DISTRICTS.has(str(item.get("district",""))): return false
	var pos: Variant = item.get("position")
	if not (pos is Array) or pos.size() != 2: return false
	for element in pos:
		if not (element is float or element is int): return false
		if not is_finite(float(element)) or absf(float(element)) > 208.0: return false
	var x: float = float(pos[0])
	var z: float = float(pos[1])
	if (x < 0.0) != (str(item["district"]) == "forum" or str(item["district"]) == "lower"): return false
	if (z < 0.0) != (str(item["district"]) == "forum" or str(item["district"]) == "housing"): return false
	for field in ["name","description"]:
		var names: Variant = item.get(field)
		if not (names is Dictionary): return false
		for language in LANGUAGES:
			if not (names.get(language) is String) or str(names[language]).length() < 3 or str(names[language]).length() > 160: return false
	return true

static func find_site(id: String) -> Dictionary:
	for item in sites():
		if str(item["id"]) == id: return item
	return {}

static func position(item: Dictionary) -> Vector3:
	var pair: Array = item["position"]
	return Vector3(float(pair[0]),0.95,float(pair[1]))

static func nearest_unvisited(state: Dictionary, player_at: Vector3, radius: float = 8.0) -> String:
	var completed: Array = state.get("discovered_sites",[])
	var closest: String = ""
	var minimum: float = radius * radius
	for item in sites():
		if completed.has(str(item["id"])): continue
		var location: Vector3 = position(item)
		var distance: float = Vector2(player_at.x-location.x,player_at.z-location.z).length_squared()
		if distance <= minimum:
			closest = str(item["id"])
			minimum = distance
	return closest

static func discover(state: Dictionary, id: String, player_at: Vector3, driving: bool, indoor: bool) -> Dictionary:
	var item: Dictionary = find_site(id)
	if item.is_empty(): return {"status":"unknown"}
	if driving or indoor: return {"status":"on_foot"}
	if state.get("discovered_sites",[]).has(id): return {"status":"already"}
	if nearest_unvisited(state,player_at,8.0) != id: return {"status":"distance"}
	if int(state.get("wallet",0)) > 30000000-WALLET_REWARD: return {"status":"wallet_full"}
	if int(state.get("money_earned",0)) > 20000000-WALLET_REWARD: return {"status":"wallet_full"}
	state["discovered_sites"].append(id)
	state["wallet"] = int(state["wallet"]) + WALLET_REWARD
	state["money_earned"] = int(state["money_earned"]) + WALLET_REWARD
	state["science"] = mini(200000,int(state["science"]) + SCIENCE_REWARD)
	state["reputation"] = mini(100,int(state["reputation"]) + 1)
	var idx: int = DISTRICTS.find(str(item["district"]))
	state["trust"][idx] = mini(100,int(state["trust"][idx]) + 1)
	state["discovery_history"].push_front({"id":id,"turn":int(state["turn"]),"reward":WALLET_REWARD})
	if state["discovery_history"].size() > MAX_HISTORY: state["discovery_history"].resize(MAX_HISTORY)
	return {"status":"discovered","reward":WALLET_REWARD,"count":state["discovered_sites"].size(),"id":id}

static func valid_state(state: Dictionary) -> bool:
	# Optional for previous v4 campaigns: the migration adds both fields.
	var found: Variant = state.get("discovered_sites",[])
	var history: Variant = state.get("discovery_history",[])
	if not (found is Array) or not (history is Array): return false
	if found.size() > 12 or history.size() > MAX_HISTORY: return false
	var known := {}
	for id in found:
		if not (id is String) or find_site(id).is_empty() or known.has(id): return false
		known[id] = true
	var seen := {}
	for record in history:
		if not (record is Dictionary) or record.size() != 3: return false
		var id: Variant = record.get("id",null)
		if not (id is String) or not known.has(id) or seen.has(id): return false
		if not (record.get("turn",null) is int or record.get("turn",null) is float): return false
		if float(record["turn"]) < 1 or float(record["turn"]) > float(state.get("turn",0)) or floorf(float(record["turn"])) != float(record["turn"]): return false
		if record.get("reward",-1) != WALLET_REWARD: return false
		seen[id] = true
	return history.size() == found.size()

static func title(item: Dictionary, language: String) -> String:
	var names: Dictionary = item.get("name",{})
	return str(names.get(language,names.get("ru","")))
