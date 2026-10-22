extends RefCounted
## v0.19: timed, physically-driven checkpoint trials with non-repeatable medal rewards.
## No visuals grant progress, all settlements happen on the authoritative state.
const CATALOG_PATH = "res://data/driving_trials.json"
const VEHICLES = ["compact","courier","executive","utility"]
const MAX_HISTORY = 24
const ENTRY_FEE = 35
const MEDALS = ["none","bronze","silver","gold"]
const HUB = Vector3(-130.0, 0.0, -130.0)
static var _routes: Array = []

static func _num(v: Variant, lo: float, hi: float, integer: bool = false) -> bool:
	if not (v is int or v is float): return false
	var n: float = float(v)
	return is_finite(n) and n >= lo and n <= hi and (not integer or n == floorf(n))

static func catalog() -> Array:
	if not _routes.is_empty(): return _routes
	var root: Variant = JSON.parse_string(FileAccess.get_file_as_string(CATALOG_PATH))
	if not (root is Dictionary) or int(root.get("schema",0)) != 1: return []
	var values: Variant = root.get("routes",[])
	if not (values is Array) or values.size() < 4 or values.size() > 20: return []
	var seen := {}
	for value in values:
		if not valid_route(value): return []
		if seen.has(value["id"]): return []
		seen[value["id"]] = true
	_routes = values
	return _routes

static func valid_route(v: Variant) -> bool:
	if not (v is Dictionary): return false
	if not (v.get("id") is String) or str(v["id"]).length() > 40 or str(v["id"]).is_empty(): return false
	if not _num(v.get("reward",0),100,1000,true): return false
	if not _num(v.get("limit_seconds",0),100,400,true): return false
	var names: Variant = v.get("title")
	if not (names is Dictionary): return false
	for lang in ["ru","en","zh"]:
		if not (names.get(lang) is String) or str(names[lang]).length() < 3 or str(names[lang]).length() > 100: return false
	var coords: Variant = v.get("checkpoints")
	if not (coords is Array) or coords.size() < 3 or coords.size() > 10: return false
	var last := Vector2(100000,100000)
	for point in coords:
		if not (point is Array) or point.size() != 2: return false
		if not _num(point[0],-215,215) or not _num(point[1],-215,215): return false
		var here := Vector2(float(point[0]),float(point[1]))
		if here.distance_to(last) < 15: return false
		last = here
	return true

static func find_route(id: String) -> Dictionary:
	for entry in catalog():
		if str(entry["id"]) == id: return entry
	return {}

static func offer(state: Dictionary) -> Dictionary:
	var options: Array = catalog()
	if options.is_empty(): return {}
	var count: int = 0
	for v in state.get("trial_records",{}).values():
		count += int(v.get("completed",0))
	return options[posmod(int(state.get("turn",1)) - 1 + count, options.size())]

static func checkpoint(route: Dictionary, index: int) -> Vector3:
	var points: Array = route.get("checkpoints",[])
	if index < 0 or index >= points.size(): return Vector3.ZERO
	var pair: Array = points[index]
	return Vector3(float(pair[0]),1.2,float(pair[1]))

static func target(state: Dictionary) -> Vector3:
	var active: Dictionary = state.get("driving_trial",{})
	if active.is_empty(): return Vector3.ZERO
	return checkpoint(find_route(str(active.get("id",""))),int(active.get("step",0)))

static func begin(state: Dictionary, pos: Vector3, speed: float, mileage: float, health: float, variant: String, driving: bool) -> String:
	if not state.get("driving_trial",{}).is_empty(): return "busy"
	if not state.get("active_contract",{}).is_empty() or not state.get("service_active",{}).is_empty() or not state.get("neighborhood_active",{}).is_empty(): return "busy"
	if int(state.get("law",{}).get("heat",0)) > 0: return "wanted"
	if not driving or absf(speed) > 1.5 or pos.distance_to(HUB) > 42.0: return "location"
	if not VEHICLES.has(variant) or not _num(mileage,0,50000000) or not _num(health,25,100): return "vehicle"
	if int(state.get("wallet",0)) < ENTRY_FEE: return "funds"
	var route: Dictionary = offer(state)
	if route.is_empty(): return "unavailable"
	state["wallet"] -= ENTRY_FEE
	state["driving_trial"] = {
		"id":str(route["id"]),"step":0,"elapsed":0.0,"start_meter":mileage,
		"last_meter":mileage,"start_point":[pos.x,pos.z],"start_health":health,
		"vehicle":variant,"turn":int(state["turn"])
	}
	return "started"

static func _finish(state: Dictionary, status: String, medal: int = 0, payout: int = 0) -> Dictionary:
	var active: Dictionary = state["driving_trial"]
	var id: String = str(active["id"])
	var history: Array = state["trial_history"]
	history.push_front({"id":id,"turn":int(state["turn"]),"status":status,"medal":medal,"reward":payout,"seconds":roundi(float(active["elapsed"]))})
	if history.size() > MAX_HISTORY: history.resize(MAX_HISTORY)
	state["driving_trial"] = {}
	return {"status":status,"medal":medal,"reward":payout}

static func tick(state: Dictionary, delta: float, pos: Vector3, mileage: float, health: float, vehicle: String, driving: bool) -> Dictionary:
	var active: Dictionary = state.get("driving_trial",{})
	if active.is_empty(): return {"status":"idle"}
	var route: Dictionary = find_route(str(active.get("id","")))
	if route.is_empty(): return _finish(state,"failed")
	if not _num(delta,0,2) or not _num(mileage,0,50000000) or not _num(health,0,100): return _finish(state,"failed")
	active["elapsed"] = minf(401.0,float(active["elapsed"])+delta)
	if not driving or str(active["vehicle"]) != vehicle or health < 25.0 or int(state.get("law",{}).get("heat",0)) > 0 or mileage + 0.001 < float(active["last_meter"]):
		return _finish(state,"failed")
	if float(active["elapsed"]) > float(route["limit_seconds"]): return _finish(state,"expired")
	var current: int = int(active["step"])
	var goal: Vector3 = checkpoint(route,current)
	if Vector2(pos.x,pos.z).distance_to(Vector2(goal.x,goal.z)) > 10.0: return {"status":"running"}
	var previous: Vector2 = Vector2(float(active["start_point"][0]),float(active["start_point"][1])) if current == 0 else Vector2(checkpoint(route,current-1).x,checkpoint(route,current-1).z)
	var needed: float = maxf(9.0,previous.distance_to(Vector2(goal.x,goal.z)) * 0.45)
	if mileage - float(active["last_meter"]) + 0.001 < needed: return {"status":"distance"}
	active["step"] = current+1
	active["last_meter"] = mileage
	if int(active["step"]) < route["checkpoints"].size(): return {"status":"checkpoint","step":int(active["step"])}
	var duration: float = float(active["elapsed"])
	var damage: float = maxf(0.0,float(active["start_health"]) - health)
	var effective: float = duration + damage*2.0
	var medal: int = 3 if effective <= float(route["limit_seconds"])*0.55 else (2 if effective <= float(route["limit_seconds"])*0.78 else 1)
	var records: Dictionary = state["trial_records"]
	var prior: Dictionary = records.get(str(route["id"]),{"medal":0,"best_seconds":0.0,"completed":0})
	var previous_medal: int = int(prior["medal"])
	var payout: int = roundi(float(route["reward"]) * float(maxi(0,medal - previous_medal)) / 3.0)
	# Monetary settlement is bounded and can never be repeated for the same grade.
	if int(state["wallet"]) + payout > 30000000: payout = 0
	state["wallet"] += payout
	state["money_earned"] = mini(20000000,int(state["money_earned"]) + payout)
	state["reputation"] = mini(100,int(state.get("reputation",35)) + (1 if medal > previous_medal else 0))
	var best: float = float(prior["best_seconds"])
	records[str(route["id"])] = {"medal":maxi(medal,previous_medal),"best_seconds":duration if best <= 0.0 else minf(best,duration),"completed":mini(100000,int(prior["completed"])+1)}
	return _finish(state,"completed",medal,payout)

static func valid(state: Dictionary) -> bool:
	var active: Variant = state.get("driving_trial",{})
	if not (active is Dictionary): return false
	if not active.is_empty():
		var route: Dictionary = find_route(str(active.get("id","")))
		if route.is_empty() or active.size() != 9: return false
		if not _num(active.get("step"),0,route["checkpoints"].size()-1,true): return false
		if not _num(active.get("elapsed"),0,float(route["limit_seconds"])+1): return false
		if not _num(active.get("start_meter"),0,50000000) or not _num(active.get("last_meter"),float(active["start_meter"]),50000000): return false
		if not _num(active.get("start_health"),25,100): return false
		if not VEHICLES.has(str(active.get("vehicle",""))): return false
		if not _num(active.get("turn"),1,int(state["turn"]),true) or int(active["turn"]) != int(state["turn"]): return false
		var point: Variant = active.get("start_point")
		if not point is Array or point.size() != 2: return false
		if not _num(point[0],-300,300) or not _num(point[1],-300,300): return false
		if not state.get("active_contract",{}).is_empty() or not state.get("service_active",{}).is_empty() or not state.get("neighborhood_active",{}).is_empty(): return false
	var records: Variant = state.get("trial_records",{})
	if not records is Dictionary or records.size() > catalog().size(): return false
	for id in records:
		if find_route(str(id)).is_empty(): return false
		var record: Variant = records[id]
		if not record is Dictionary or record.size() != 3: return false
		if not _num(record.get("medal"),1,3,true) or not _num(record.get("completed"),1,100000,true): return false
		if not _num(record.get("best_seconds"),0.01,400): return false
	var history: Variant = state.get("trial_history",[])
	if not history is Array or history.size() > MAX_HISTORY: return false
	for item in history:
		if not item is Dictionary or item.size() != 6: return false
		if find_route(str(item.get("id",""))).is_empty(): return false
		if not ["completed","expired","failed"].has(item.get("status","")): return false
		if not _num(item.get("turn"),1,int(state["turn"]),true): return false
		if not _num(item.get("medal"),0,3,true) or not _num(item.get("reward"),0,1000,true): return false
		if not _num(item.get("seconds"),0,401,true): return false
	return true
