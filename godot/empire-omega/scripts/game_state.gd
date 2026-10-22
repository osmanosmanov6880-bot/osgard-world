extends Node
## Authoritative game simulation: no game-rule mutation in HUD/world rendering.
## Explicit JSON versioned saves. Imported v3 statistics are preserved where safe.

signal state_changed(reason: String)
signal turn_advanced(turn_number: int)
signal alert_created(message: String)

const SAVE_PATH = "user://osgard_empire_save_v4.json"
const TEMP_SAVE_PATH = "user://osgard_empire_save_v4.pending"
const BACKUP_SAVE_PATH = "user://osgard_empire_save_v4.backup.json"
const VERSION = 4
const CITY_ECONOMY = preload("res://scripts/city_economy.gd")
const REAL_ESTATE = preload("res://scripts/real_estate.gd")
const CITY_WEATHER = preload("res://scripts/city_weather.gd")
const CITIZEN_REQUESTS = preload("res://scripts/citizen_requests.gd")
const CITY_MARKET = preload("res://scripts/city_market.gd")
const VEHICLE_CATALOG = preload("res://scripts/vehicle_catalog.gd")
const CAREER = preload("res://scripts/career_progress.gd")
const INITIATIVES = preload("res://scripts/civic_initiatives.gd")
const MOBILITY = preload("res://scripts/city_mobility.gd")
const CITY_CASES = preload("res://scripts/city_cases.gd")
const CARGO = preload("res://scripts/cargo_logistics.gd")
const SERVICE = preload("res://scripts/service_dispatch.gd")
const LAW = preload("res://scripts/city_law.gd")
const NEIGHBORHOOD = preload("res://scripts/neighborhood_jobs.gd")
const POLITICS = preload("res://scripts/civic_politics.gd")
const TRIALS = preload("res://scripts/driving_trials.gd")
const DISCOVERY = preload("res://scripts/city_discovery.gd")
const DISTRICTS = ["forum", "housing", "lower", "aqueduct"]
const BUILDING_ORDER = ["council", "clinic", "academy", "homes", "gardens", "school", "market", "factory", "depot", "plant", "purifier", "reservoir"]
const RESEARCH_ORDER = ["grid", "filtration", "councilAI", "commerce", "agronomy", "automation"]
const BUILDINGS = {
	"council": {"district":"forum", "cost":230, "rise":1.52, "upkeep":9},
	"clinic": {"district":"forum", "cost":205, "rise":1.45, "upkeep":8},
	"academy": {"district":"forum", "cost":270, "rise":1.50, "upkeep":11},
	"homes": {"district":"housing", "cost":190, "rise":1.48, "upkeep":5},
	"gardens": {"district":"housing", "cost":175, "rise":1.42, "upkeep":6},
	"school": {"district":"housing", "cost":240, "rise":1.50, "upkeep":8},
	"market": {"district":"lower", "cost":230, "rise":1.50, "upkeep":8},
	"factory": {"district":"lower", "cost":310, "rise":1.55, "upkeep":15},
	"depot": {"district":"lower", "cost":170, "rise":1.48, "upkeep":5},
	"plant": {"district":"aqueduct", "cost":255, "rise":1.54, "upkeep":10},
	"purifier": {"district":"aqueduct", "cost":230, "rise":1.48, "upkeep":9},
	"reservoir": {"district":"aqueduct", "cost":185, "rise":1.43, "upkeep":5}
}
const TECH = {
	"grid":{"science":45,"cost":175,"requires":[]},
	"filtration":{"science":50,"cost":185,"requires":[]},
	"councilAI":{"science":65,"cost":245,"requires":[]},
	"commerce":{"science":75,"cost":265,"requires":[]},
	"agronomy":{"science":70,"cost":210,"requires":[]},
	"automation":{"science":130,"cost":410,"requires":["grid","commerce"]}
}
const BUSINESSES = {
	"market_stall":{"cost":500,"income":42,"name":"Торговая галерея"},
	"logistics":{"cost":980,"income":87,"name":"Логистическая компания"},
	"workshop":{"cost":1550,"income":155,"name":"Промышленная мастерская"}
}
const LOCATIONS = {
	"forum":Vector3(-130.0, 0.0, -130.0),
	"housing":Vector3(130.0, 0.0, -130.0),
	"lower":Vector3(-130.0, 0.0, 130.0),
	"aqueduct":Vector3(130.0, 0.0, 130.0)
}
const DEFAULT_POSITION = [ -115.0, 1.3, -104.0 ]

# Overridable save paths allow native tests to use disposable user:// fixtures
# without ever modifying a player's own campaign.
var save_path: String = SAVE_PATH
var pending_save_path: String = TEMP_SAVE_PATH
var backup_save_path: String = BACKUP_SAVE_PATH

var locale := "ru"
var data: Dictionary = {}
# Exposed to the HUD: only report a save/load as successful after IO succeeds.
var last_save_ok := false
var last_load_source := ""

func _ready() -> void:
	data = new_game()
	# An interrupted previous write may leave only the backup behind.
	load_game()

func new_game() -> Dictionary:
	var buildings := {}
	var technologies := {}
	var businesses := {}
	for key in BUILDING_ORDER:
		buildings[key] = 0
	for key in RESEARCH_ORDER:
		technologies[key] = false
	for key in BUSINESSES:
		businesses[key] = false
	return {
		"version":VERSION,"seed":781413,"turn":1,"treasury":1000,"population":12800,
		"energy":93,"water":87,"food":83,"stability":72,"trust":[62,65,59,70],
		"science":24,"debt":0,"tax":10,"course":"balance","selected":"forum",
		"buildings":buildings,"technologies":technologies,"businesses":businesses,
		"actions_left":2,"incident":"","mission":0,"deliveries":0,
		"player_position":DEFAULT_POSITION.duplicate(),"vehicle_position":[-120.0,1.3,-104.0],
		"vehicle_heading":0.0,"day_clock":8.0,"log":[],"history":[],"money_earned":0,
		"wallet":600,"active_contract":{},"contracts_completed":0,"cargo_quality_sum":0,"business_revenue":0,"vehicle_fuel":100.0,"vehicle_health":100.0,
		"inventories":CITY_ECONOMY.default_inventories(),"unemployment":45,"district_scores":{"forum":66,"housing":66,"lower":64,"aqueduct":67},"economy_ledger":[],"deliveries_value":0,
		"properties":REAL_ESTATE.default_properties(),"real_estate_revenue":0,"reputation":35,"personal_debt":0,"citizen_contacts":{},
		"market_orders":0,"market_history":[],"vehicle_owned":VEHICLE_CATALOG.default_owned(),"vehicle_selected":"compact","vehicle_mileage":0.0,"interior":"",
		"garage_status":VEHICLE_CATALOG.default_garage_status(),"career_xp":CAREER.default_xp(),"projects_active":{},"projects_done":[],"interior_return":DEFAULT_POSITION.duplicate(),
		"road_quality":75,"roads_cleared":[],"roads_repaired_total":0,
		"city_case":{},"case_history":[],
		"service_active":{},"service_completed":0,"service_failed":0,"service_history":[],"service_last_turn":0,
		"law":LAW.initial(),"neighborhood_active":{},"neighborhood_history":[],"neighborhood_completed":0,"neighborhood_last_turn":0,"politics":POLITICS.initial(),"driving_trial":{},"trial_records":{},"trial_history":[],"discovered_sites":[],"discovery_history":[]
	}

func reset_game() -> void:
	data = new_game()
	state_changed.emit("reset")

func get_build_cost(id: String) -> int:
	if not BUILDINGS.has(id):
		return -1
	var building: Dictionary = BUILDINGS[id]
	var level: int = int(data["buildings"][id])
	return roundi(float(building["cost"]) * pow(float(building["rise"]), level) * (0.9 if data["technologies"]["automation"] else 1.0) * (1.0 - CAREER.bonus(data,"engineering")) * POLITICS.build_cost_multiplier(data))

func _bounded(value: float) -> int:
	return clampi(roundi(value), 0, 100)

func current_weather() -> Dictionary:
	return CITY_WEATHER.for_turn(int(data["seed"]),int(data["turn"]))

func real_estate_forecast() -> Dictionary:
	var city: Dictionary = CITY_ECONOMY.project(data, BUILDINGS)
	return REAL_ESTATE.project(data,city["district_scores"])

func forecast() -> Dictionary:
	# This projection is exactly the one consumed by advance_turn.
	var result: Dictionary = CITY_ECONOMY.project(data, BUILDINGS)
	var estate: Dictionary = REAL_ESTATE.project(data,result["district_scores"])
	result["real_estate"] = estate
	result["personal_interest"] = ceili(float(data.get("personal_debt",0)) * 0.02)
	result["personal_income"] = private_turn_income() + int(estate["net"]) - int(result["personal_interest"])
	return result

func start_driving_trial(position: Vector3, speed: float, mileage: float, health: float, driving: bool) -> String:
	var result: String = TRIALS.begin(data,position,speed,mileage,health,str(data["vehicle_selected"]),driving)
	if result == "started":
		_log("trial_start",str(data["driving_trial"]["id"]))
		state_changed.emit("trial")
	return result

func tick_driving_trial(delta: float, position: Vector3, mileage: float, health: float, driving: bool) -> Dictionary:
	if data.get("driving_trial",{}).is_empty(): return {"status":"idle"}
	var result: Dictionary = TRIALS.tick(data,delta,position,mileage,health,str(data["vehicle_selected"]),driving)
	var status: String = str(result.get("status","idle"))
	if status == "completed":
		if int(result.get("reward",0)) > 0: _award_career("logistics",45)
		_log("trial_completed",str(result.get("reward",0)))
		state_changed.emit("trial")
	elif status == "expired" or status == "failed":
		_log("trial_failed",status)
		state_changed.emit("trial")
	elif status == "checkpoint":
		state_changed.emit("trial")
	return result

func explore_site(id: String, player_at: Vector3, driving: bool, indoor: bool) -> Dictionary:
	var result: Dictionary = DISCOVERY.discover(data,id,player_at,driving,indoor)
	if str(result.get("status","")) == "discovered":
		_log("exploration",id)
		state_changed.emit("exploration")
	return result

func _log(action: String, detail: String) -> void:
	data["log"].push_front({"turn":data["turn"],"type":action,"detail":detail})
	if data["log"].size() > 55:
		data["log"].resize(55)

func build(id: String) -> bool:
	if not BUILDINGS.has(id) or data["actions_left"] < 1 or data["buildings"][id] >= 4:
		return false
	var cost: int = get_build_cost(id)
	if cost < 0 or data["treasury"] < cost:
		return false
	data["treasury"] -= cost
	data["actions_left"] -= 1
	data["buildings"][id] += 1
	if id == "plant": data["energy"] = _bounded(data["energy"] + 12)
	if id == "purifier": data["water"] = _bounded(data["water"] + 10)
	if id == "gardens": data["food"] = _bounded(data["food"] + 8)
	if id == "clinic": data["stability"] = _bounded(data["stability"] + 2)
	_award_career("engineering",30)
	_log("build", id)
	state_changed.emit("build")
	return true

func research(id: String) -> bool:
	if not TECH.has(id) or data["technologies"][id] or data["actions_left"] < 1:
		return false
	var tech: Dictionary = TECH[id]
	for requirement in tech["requires"]:
		if not data["technologies"][requirement]:
			return false
	if data["science"] < tech["science"] or data["treasury"] < tech["cost"]:
		return false
	data["science"] -= tech["science"]
	data["treasury"] -= tech["cost"]
	data["technologies"][id] = true
	data["actions_left"] -= 1
	_award_career("engineering",65)
	_log("research", id)
	state_changed.emit("research")
	return true

func enact_council_measure(id: String) -> bool:
	if not POLITICS.enact(data,id):
		return false
	_award_career("civic",42)
	_log("council_measure",id)
	state_changed.emit("council_measure")
	return true

func set_tax(tax: int) -> bool:
	if tax < 0 or tax > 40:
		return false
	data["tax"] = tax
	state_changed.emit("policy")
	return true

func set_course(course: String) -> bool:
	if not ["balance", "industry", "energy", "welfare"].has(course):
		return false
	data["course"] = course
	state_changed.emit("policy")
	return true

func set_district(district: String) -> void:
	if DISTRICTS.has(district):
		data["selected"] = district
		state_changed.emit("district")

func buy_business(id: String) -> bool:
	if not BUSINESSES.has(id) or data["businesses"][id]:
		return false
	var cost: int = BUSINESSES[id]["cost"]
	if int(data["wallet"]) < cost:
		return false
	data["wallet"] -= cost
	data["businesses"][id] = true
	_award_career("enterprise",70)
	_log("business", id)
	state_changed.emit("business")
	return true

func market_quote(product: String, buying: bool, quantity: int = 10) -> Dictionary:
	return CITY_MARKET.quote(data,product,buying,quantity)

func trade_goods(product: String, buying: bool, quantity: int = 10) -> bool:
	var quote: Dictionary = market_quote(product,buying,quantity)
	if quote.is_empty() or not bool(quote["allowed"]):
		return false
	var cost: int = int(quote["total"])
	if buying:
		data["treasury"] -= cost
		data["inventories"][product] = int(data["inventories"][product]) + quantity
	else:
		data["treasury"] += cost
		data["inventories"][product] = int(data["inventories"][product]) - quantity
	data["market_orders"] = int(data.get("market_orders",0)) + 1
	var history: Array = data.get("market_history",[])
	history.append({"turn":int(data["turn"]),"product":product,"buy":buying,"quantity":quantity,"total":cost})
	if history.size() > 40:
		history.pop_front()
	data["market_history"] = history
	_award_career("enterprise",16)
	_log("market_buy" if buying else "market_sell",product+":"+str(quantity)+":"+str(cost))
	state_changed.emit("market")
	return true

func buy_vehicle(id: String) -> bool:
	if not VEHICLE_CATALOG.available(id) or bool(data["vehicle_owned"].get(id,false)):
		return false
	var profile: Dictionary = VEHICLE_CATALOG.VEHICLES[id]
	if int(data["wallet"]) < int(profile["price"]) or int(data["reputation"]) < int(profile["reputation"]):
		return false
	data["wallet"] -= int(profile["price"])
	data["vehicle_owned"][id] = true
	if not data["garage_status"].has(id):
		data["garage_status"][id] = {"fuel":100.0,"health":100.0,"mileage":0.0}
	_award_career("enterprise",35)
	_log("vehicle_purchase",id)
	state_changed.emit("garage")
	return true

func select_vehicle(id: String) -> bool:
	if not VEHICLE_CATALOG.available(id) or not bool(data["vehicle_owned"].get(id,false)):
		return false
	# A loaded vehicle cannot be swapped for a full tank or a fresh chassis.
	if not data.get("active_contract",{}).is_empty() or not data.get("service_active",{}).is_empty() or not data.get("neighborhood_active",{}).is_empty():
		return false
	if str(data["vehicle_selected"]) == id:
		return false
	var previous: String = str(data["vehicle_selected"])
	data["garage_status"][previous] = {"fuel":float(data["vehicle_fuel"]),"health":float(data["vehicle_health"]),"mileage":float(data["vehicle_mileage"])}
	data["vehicle_selected"] = id
	var profile: Dictionary = data["garage_status"][id]
	data["vehicle_fuel"] = float(profile["fuel"])
	data["vehicle_health"] = float(profile["health"])
	data["vehicle_mileage"] = float(profile["mileage"])
	_log("vehicle_select",id)
	state_changed.emit("garage")
	return true

func sync_vehicle_live(fuel: float, health: float, mileage: float, moving: bool = false) -> void:
	# Called by the 3D controller without spamming UI signals.
	var selected: String = str(data.get("vehicle_selected","compact"))
	if not VEHICLE_CATALOG.available(selected):
		return
	var entry := {"fuel":clampf(fuel,0.0,100.0),"health":clampf(health,0.0,100.0),"mileage":clampf(mileage,0.0,50000000.0)}
	data["garage_status"][selected] = entry
	data["vehicle_fuel"] = entry["fuel"]
	data["vehicle_health"] = entry["health"]
	data["vehicle_mileage"] = entry["mileage"]
	var active: Dictionary = data.get("active_contract",{})
	if not active.is_empty() and active.get("cargo_progress") is Dictionary:
		var profile: Dictionary = active["cargo_progress"]
		if str(profile.get("vehicle","")) == selected:
			CARGO.update(active,float(entry["mileage"]),float(entry["health"]),moving,str(current_weather()["kind"]))
	var service: Dictionary = data.get("service_active",{})
	if not service.is_empty():
		SERVICE.track(service,float(entry["mileage"]),float(entry["health"]),moving,str(current_weather()["kind"]),selected)

func _award_career(track: String, points: int) -> void:
	var previous: int = CAREER.level(int(data.get("career_xp",{}).get(track,0)))
	if CAREER.award(data,track,points):
		var current: int = CAREER.level(int(data["career_xp"][track]))
		if current > previous:
			_log("career_level_up",track + ":" + str(current))

func career_level(track: String) -> int:
	return CAREER.level(int(data.get("career_xp",{}).get(track,0)))

func start_initiative(project_id: String) -> bool:
	if not INITIATIVES.launch(data,project_id):
		return false
	_award_career("civic",30)
	_log("initiative_started",project_id)
	state_changed.emit("initiative")
	return true

func accept_neighborhood_job(citizen_id: int, district: String) -> bool:
	if not NEIGHBORHOOD.accept(data,citizen_id,district): return false
	_log("neighborhood_accept",str(data["neighborhood_active"]["id"]))
	state_changed.emit("neighborhood")
	return true

func neighborhood_interact(location_id: String, vehicle_near: bool, driving: bool, speed: float) -> String:
	var result: String = NEIGHBORHOOD.interact(data,location_id,vehicle_near,driving,speed)
	if result == "collected":
		_log("neighborhood_supplies",str(data["neighborhood_active"]["id"]))
		state_changed.emit("neighborhood")
	elif result == "completed":
		_award_career("logistics",35)
		_award_career("civic",30)
		_log("neighborhood_completed",str(data["neighborhood_history"][0]["id"]))
		state_changed.emit("neighborhood")
	return result

func _expire_neighborhood_if_needed() -> void:
	var expired: String = NEIGHBORHOOD.expire(data)
	if expired != "":
		_log("neighborhood_expired",expired)
		alert_created.emit(NEIGHBORHOOD.status_text("expired",locale))

func citizen_available(citizen_id: int) -> bool:
	if citizen_id < 0 or citizen_id >= 34:
		return false
	return int(data.get("citizen_contacts",{}).get(str(citizen_id),-1)) != int(data["turn"])

func respond_to_citizen(citizen_id: int, district: String, action: String) -> bool:
	if not citizen_available(citizen_id) or not DISTRICTS.has(district):
		return false
	if action != "listen" and action != "support":
		return false
	if action == "support" and int(data["treasury"]) < 75:
		return false
	var theme: String = CITIZEN_REQUESTS.topic(data,citizen_id)
	if action == "support":
		data["treasury"] -= 75
		match theme:
			"power": data["energy"] = _bounded(float(data["energy"]) + 7.0)
			"water": data["water"] = _bounded(float(data["water"]) + 7.0)
			"food": data["food"] = _bounded(float(data["food"]) + 7.0)
			"jobs": data["unemployment"] = maxi(0,int(data["unemployment"])-2)
			_: data["stability"] = _bounded(float(data["stability"]) + 2.0)
	data["trust"][DISTRICTS.find(district)] = _bounded(float(data["trust"][DISTRICTS.find(district)]) + (3 if action == "support" else 1))
	data["reputation"] = mini(100,int(data.get("reputation",35)) + (2 if action == "support" else 1))
	data["citizen_contacts"][str(citizen_id)] = int(data["turn"])
	_award_career("civic",35 if action == "support" else 15)
	_log("citizen_" + action,str(citizen_id) + ":" + theme)
	state_changed.emit("citizen")
	return true

func property_cost(id: String) -> int:
	if not REAL_ESTATE.PROPERTIES.has(id):
		return -1
	return REAL_ESTATE.purchase_cost(id,int(data["properties"].get(id,0)))

func buy_property(id: String) -> bool:
	if not REAL_ESTATE.PROPERTIES.has(id):
		return false
	if int(data["properties"].get(id,0)) != 0:
		return false
	var cost: int = property_cost(id)
	if cost < 1 or int(data["wallet"]) < cost:
		return false
	data["wallet"] -= cost
	data["properties"][id] = 1
	data["reputation"] = mini(100,int(data["reputation"])+2)
	_award_career("enterprise",40)
	_log("property_purchase",id)
	state_changed.emit("property")
	return true

func renovate_property(id: String) -> bool:
	if not REAL_ESTATE.PROPERTIES.has(id):
		return false
	var level: int = int(data["properties"].get(id,0))
	if level < 1 or level >= REAL_ESTATE.MAX_LEVEL:
		return false
	var cost: int = property_cost(id)
	if cost < 1 or int(data["wallet"]) < cost:
		return false
	data["wallet"] -= cost
	data["properties"][id] = level + 1
	_award_career("engineering",25)
	_log("property_renovation",id)
	state_changed.emit("property")
	return true

func register_traffic_offence(code: String) -> bool:
	if not LAW.register(data,code): return false
	_log("traffic_offence",code)
	state_changed.emit("law")
	return true

func tick_city_law(delta: float, patrol_nearby: bool) -> void:
	if LAW.progress(data,delta,patrol_nearby):
		_log("escaped_patrol","heat_reduced")
		state_changed.emit("law")

func resolve_traffic_fines(detained: bool = false) -> bool:
	if not LAW.settle(data,detained): return false
	_log("traffic_fines","patrol_stop" if detained else "voluntary")
	state_changed.emit("law")
	return true

func add_reward(amount: int, reason: String) -> void:
	if amount <= 0 or amount > 100000:
		return
	data["wallet"] += amount
	data["money_earned"] += amount
	_log("reward", reason)
	state_changed.emit("reward")

func courier_payment(contract: Dictionary) -> int:
	var late: bool = int(data["turn"])-int(contract.get("accepted_turn",0)) > int(contract.get("limit_turns",1))
	var bonus: int = (20 if bool(data["businesses"]["logistics"]) else 0) + (10 if bool(data["businesses"]["market_stall"]) else 0)
	var quality: float = float(contract.get("cargo_progress",{}).get("condition",100.0))
	return CARGO.payment(int(contract.get("reward",0)),CAREER.bonus(data,"logistics"),bonus,late,quality)

func complete_courier(contract: Dictionary, amount: int) -> bool:
	var active: Dictionary = data.get("active_contract",{})
	if active.is_empty() or active.get("id","") != contract.get("id",""):
		return false
	if active.has("cargo_progress") and not CARGO.ready(active):
		return false
	if amount < 75 or amount > 5000 or amount != courier_payment(active):
		return false
	data["active_contract"] = {}
	data["contracts_completed"] = int(data["contracts_completed"]) + 1
	data["reputation"] = mini(100,int(data.get("reputation",35))+1)
	data["wallet"] = int(data["wallet"]) + amount
	data["money_earned"] = int(data["money_earned"]) + amount
	data["deliveries_value"] = int(data.get("deliveries_value",0)) + amount
	data["cargo_quality_sum"] = int(data.get("cargo_quality_sum",0)) + roundi(float(active.get("cargo_progress",{}).get("condition",100.0)))
	var cargo: String = str(contract.get("cargo","goods"))
	if CITY_ECONOMY.STOCK_TYPES.has(cargo):
		var quantity: int = CARGO.delivered_quantity(active)
		var stock: Dictionary = data.get("inventories",CITY_ECONOMY.default_inventories())
		stock[cargo] = mini(CITY_ECONOMY.STOCK_LIMIT,int(stock.get(cargo,0)) + quantity)
		data["inventories"] = stock
	_award_career("logistics",70)
	_log("courier",str(contract.get("id","")))
	state_changed.emit("courier")
	return true

func transfer_to_city(amount: int) -> bool:
	if amount < 1 or amount > 10000 or int(data["wallet"]) < amount:
		return false
	data["wallet"] -= amount
	data["treasury"] += amount
	_log("transfer", str(amount))
	state_changed.emit("transfer")
	return true

func repay_private_debt(amount: int) -> bool:
	if amount <= 0 or int(data.get("personal_debt",0)) <= 0:
		return false
	var payment: int = mini(amount,mini(int(data["personal_debt"]),int(data["wallet"])))
	if payment <= 0:
		return false
	data["personal_debt"] -= payment
	data["wallet"] -= payment
	_log("private_debt_repayment",str(payment))
	state_changed.emit("debt_repayment")
	return true

func refuel_vehicle() -> bool:
	const COST := 85
	if int(data["wallet"]) < COST or float(data["vehicle_fuel"]) >= 99.5:
		return false
	data["wallet"] -= COST
	data["vehicle_fuel"] = 100.0
	data["garage_status"][str(data["vehicle_selected"])]["fuel"] = 100.0
	_log("refuel",str(COST))
	state_changed.emit("refuel")
	return true

func repair_vehicle() -> bool:
	var current: float = float(data.get("vehicle_health",100.0))
	if current >= 99.9: return false
	var cost: int = maxi(80,roundi((100.0-current)*4.5))
	if int(data["wallet"]) < cost: return false
	data["wallet"] -= cost
	data["vehicle_health"] = 100.0
	data["garage_status"][str(data["vehicle_selected"])]["health"] = 100.0
	_award_career("engineering",18)
	_log("vehicle_repair",str(cost))
	state_changed.emit("vehicle_repair")
	return true

func repair_cost() -> int:
	return maxi(80,roundi((100.0-float(data.get("vehicle_health",100.0)))*4.5))

func record_action(category: String, detail: String) -> void:
	_log(category,detail)

func repair_road(incident_id: String) -> bool:
	# Authorized municipal action: repairing a blocked segment uses real treasury,
	# city materials and one action; a repeated repair cannot generate rewards.
	var incident: Dictionary = MOBILITY.incident_by_id(incident_id)
	if incident.is_empty(): return false
	var present := false
	for active in MOBILITY.active_incidents(data):
		if str(active["id"]) == incident_id: present = true
	if not present: return false
	var cost: Dictionary = MOBILITY.catalog().get("repairs",{})
	var cash: int = int(cost.get("treasury",120))
	var materials: int = int(cost.get("materials",6))
	if int(data["actions_left"]) < 1 or int(data["treasury"]) < cash or int(data["inventories"]["materials"]) < materials:
		return false
	data["treasury"] -= cash
	data["inventories"]["materials"] -= materials
	data["actions_left"] -= 1
	data["roads_cleared"].append(incident_id)
	data["road_quality"] = mini(100,int(data["road_quality"])+3)
	data["roads_repaired_total"] = int(data["roads_repaired_total"])+1
	data["stability"] = _bounded(float(data["stability"])+1.0)
	_award_career("engineering",35)
	_log("road_repaired",incident_id)
	state_changed.emit("road_repair")
	return true

func maintain_roads() -> bool:
	if int(data["actions_left"]) < 1 or int(data["treasury"]) < 190 or int(data["inventories"]["materials"]) < 8 or int(data["road_quality"]) >= 100:
		return false
	data["treasury"] -= 190
	data["inventories"]["materials"] -= 8
	data["actions_left"] -= 1
	data["road_quality"] = mini(100,int(data["road_quality"])+14)
	_award_career("engineering",30)
	_log("road_maintenance",str(data["road_quality"]))
	state_changed.emit("road_maintenance")
	return true

func accept_service() -> String:
	# Only one public-service assignment per turn and never alongside freight.
	if not data.get("service_active",{}).is_empty() or not data.get("active_contract",{}).is_empty() or not data.get("neighborhood_active",{}).is_empty():
		return "busy"
	if int(data.get("service_last_turn",0)) == int(data["turn"]):
		return "used"
	var selected_offer: Dictionary = SERVICE.offer(data)
	if selected_offer.is_empty(): return "unavailable"
	var assignment: Dictionary = SERVICE.begin(selected_offer,data)
	if assignment.is_empty(): return "unavailable"
	data["service_active"] = assignment
	data["service_last_turn"] = int(data["turn"])
	_log("service_accept",str(assignment["id"]))
	state_changed.emit("service")
	return "accepted"

func finish_service(location_id: String, arrived_by_vehicle: bool, vehicle_speed: float) -> String:
	var assignment: Dictionary = data.get("service_active",{})
	if assignment.is_empty() or location_id != str(assignment.get("destination","")):
		return "not_here"
	if not arrived_by_vehicle or str(assignment["vehicle"]) != str(data["vehicle_selected"]):
		return "wrong_vehicle"
	if absf(vehicle_speed) > 1.5:
		return "stop"
	if not SERVICE.ready(assignment): return "travel_more"
	if int(data["turn"]) > int(assignment["due_turn"]): return "expired"
	var request: Dictionary = SERVICE.request_by_id(str(assignment["id"]))
	if request.is_empty(): return "unavailable"
	var bonus: float = CAREER.bonus(data,"civic")
	var earned: int = SERVICE.payout(int(request["reward"]),float(assignment["condition"]),bonus)
	var target: String = str(assignment["destination"])
	var region: String = str(SERVICE.DISTRICT_BY_LOCATION.get(target,"forum"))
	var resource: String = str(request["effect"])
	var effect: int = int(request["impact"])
	data["service_active"] = {}
	data["wallet"] = int(data["wallet"]) + earned
	data["money_earned"] = int(data["money_earned"]) + earned
	data["service_completed"] = int(data["service_completed"]) + 1
	data["reputation"] = mini(100,int(data["reputation"]) + 2)
	if resource == "trust":
		var district_index: int = DISTRICTS.find(region)
		if district_index >= 0: data["trust"][district_index] = _bounded(float(data["trust"][district_index]) + float(effect))
	elif ["energy","water","food","stability"].has(resource):
		data[resource] = _bounded(float(data[resource]) + float(effect))
	_award_career("civic",40)
	_award_career("logistics",30)
	data["service_history"].push_front({"id":str(request["id"]),"turn":int(data["turn"]),"result":"completed","reward":earned})
	if data["service_history"].size() > 24: data["service_history"].resize(24)
	_log("service_completed",str(request["id"]) + ":" + str(earned))
	state_changed.emit("service")
	return "completed"

func _expire_service_if_needed() -> void:
	var assignment: Dictionary = data.get("service_active",{})
	if assignment.is_empty() or int(data["turn"]) <= int(assignment.get("due_turn",100000)):
		return
	var destination: String = str(assignment.get("destination",""))
	var district: String = str(SERVICE.DISTRICT_BY_LOCATION.get(destination,"forum"))
	var region: int = DISTRICTS.find(district)
	if region >= 0: data["trust"][region] = _bounded(float(data["trust"][region]) - 3.0)
	data["stability"] = _bounded(float(data["stability"]) - 2.0)
	data["service_failed"] = int(data.get("service_failed",0)) + 1
	data["service_history"].push_front({"id":str(assignment["id"]),"turn":int(data["turn"]),"result":"expired","reward":0})
	if data["service_history"].size() > 24: data["service_history"].resize(24)
	_log("service_expired",str(assignment["id"]))
	data["service_active"] = {}
	alert_created.emit(SERVICE.status_message("expired",locale))

func private_turn_income() -> int:
	var income := 0
	for id in BUSINESSES:
		if bool(data["businesses"][id]):
			income += int(BUSINESSES[id]["income"])
	return roundi(float(income) * (1.0 + CAREER.bonus(data,"enterprise")))

func resolve_city_case(choice: String) -> bool:
	if not CITY_CASES.resolve(data, choice):
		return false
	_award_career("civic",45)
	_log("city_case", choice)
	state_changed.emit("city_case")
	return true

func advance_turn() -> bool:
	if not data.get("driving_trial",{}).is_empty():
		alert_created.emit("Finish the driving trial before advancing the city turn")
		return false
	if str(data.get("incident","")) != "":
		alert_created.emit("Сначала разрешите текущий городской кризис")
		return false
	var f: Dictionary = forecast()
	data["turn"] += 1
	_expire_service_if_needed()
	_expire_neighborhood_if_needed()
	data["treasury"] += f["net"]
	var personal_profit: int = int(f["personal_income"])
	data["real_estate_revenue"] = int(data.get("real_estate_revenue",0)) + int(f["real_estate"]["net"])
	# Operating losses cannot create an invalid negative wallet.
	# Unpaid costs become personal debt; positive profits retire debt over time.
	var balance: int = int(data["wallet"]) + personal_profit
	if balance < 0:
		data["personal_debt"] = mini(20000000,int(data["personal_debt"])-balance)
		data["wallet"] = 0
	else:
		var repayment: int = mini(int(data["personal_debt"]),maxi(0,balance / 5))
		data["personal_debt"] -= repayment
		data["wallet"] = balance - repayment
	data["business_revenue"] += private_turn_income()
	data["energy"] = f["energy"]
	data["water"] = f["water"]
	data["food"] = f["food"]
	data["inventories"] = f["inventories"].duplicate(true)
	data["unemployment"] = f["unemployment"]
	data["district_scores"] = f["district_scores"].duplicate(true)
	data["economy_ledger"] = f["ledger"].duplicate(true)
	data["population"] = maxi(5000, data["population"] + f["population_delta"])
	data["stability"] = _bounded(data["stability"] + f["stability_delta"])
	for i in range(4):
		data["trust"][i] = _bounded(data["trust"][i] + f["trust_delta"])
	data["science"] += f["science_gain"]
	data["actions_left"] = 2
	for finished_id in INITIATIVES.advance(data):
		_log("initiative_completed",finished_id)
	data["market_orders"] = 0
	data["roads_cleared"] = [] # New turn means new incidents; no infinite repair credit.
	data["road_quality"] = maxi(0,int(data["road_quality"]) - (2 if str(f["weather"]["kind"]) == "storm" else 1))
	data["day_clock"] = 8.0
	CARGO.age(data.get("active_contract",{}))
	var expired_id: String = CITY_CASES.expire(data)
	if expired_id != "":
		_log("city_case_expired",expired_id)
	if CITY_CASES.maybe_open(data):
		_log("city_case_opened",str(data["city_case"]["id"]))
	var election: Dictionary = POLITICS.advance(data)
	if not election.is_empty():
		_log("election",str(election["share"]) + "%")
		var election_note: String = ("Поддержка избирателей подтверждена: " if election["won"] else "Поддержка избирателей утрачена: ") if locale == "ru" else (("Public mandate renewed: " if election["won"] else "Public mandate lost: ") if locale == "en" else ("选举支持已确认：" if election["won"] else "选举支持不足："))
		alert_created.emit(election_note + str(election["share"]) + "%")
	_log("turn", str(f["net"]))
	if data["turn"] % 3 == 0 and data["incident"] == "":
		var event_name: String = ["drought", "strike", "blackout", "fire", "epidemic"][int(data["turn"] / 3) % 5]
		data["incident"] = event_name
		_apply_incident(event_name)
		alert_created.emit("Кризис: " + event_name + ". Откройте кабинет правителя.")
	data["history"].append({"turn":data["turn"],"treasury":data["treasury"],"wallet":data["wallet"],"population":data["population"],"stability":data["stability"],"net":f["net"]})
	if data["history"].size() > 40: data["history"].pop_front()
	turn_advanced.emit(data["turn"])
	state_changed.emit("turn")
	return true

func _apply_incident(id: String) -> void:
	match id:
		"drought":
			data["water"] = _bounded(data["water"] - 18)
			data["food"] = _bounded(data["food"] - 9)
		"strike":
			data["treasury"] -= 70
			data["trust"][2] = _bounded(data["trust"][2] - 7)
		"blackout":
			data["energy"] = _bounded(data["energy"] - 24)
		"fire":
			data["stability"] = _bounded(data["stability"] - 7)
		"epidemic":
			data["population"] = maxi(5000,data["population"] - 95)
			data["stability"] = _bounded(data["stability"] - 4)
	data["stability"] = _bounded(data["stability"] - 2)
	_log("incident",id)

func resolve_incident(pay_for_help: bool) -> bool:
	if data["incident"] == "":
		return false
	if pay_for_help and data["treasury"] < 175:
		return false
	if pay_for_help:
		data["treasury"] -= 175
		data["stability"] = _bounded(data["stability"] + 3)
		data["energy"] = _bounded(data["energy"] + 12)
		data["water"] = _bounded(data["water"] + 12)
	else:
		data["stability"] = _bounded(data["stability"] - 5)
	_award_career("civic",65 if pay_for_help else 18)
	_log("incident_resolved","aid" if pay_for_help else "defer")
	data["incident"] = ""
	state_changed.emit("incident")
	return true

func _save_state_payload() -> Dictionary:
	return {"format":"osgard-empire-omega","version":VERSION,"state":data.duplicate(true)}

func _read_valid_save(path: String) -> Dictionary:
	# Read-only: does not alter the active campaign, even on malformed input.
	if not FileAccess.file_exists(path):
		return {}
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		return {}
	var size: int = file.get_length()
	if size < 2 or size > 500000:
		file.close()
		return {}
	var raw: Variant = JSON.parse_string(file.get_as_text())
	file.close()
	if not (raw is Dictionary):
		return {}
	if raw.get("format", "") != "osgard-empire-omega" or raw.get("version", 0) != VERSION:
		return {}
	if not _valid_state(raw.get("state", null)):
		return {}
	return raw

func save_game() -> bool:
	last_save_ok = false
	if not _valid_state(data):
		return false
	# Stage a complete snapshot before touching any existing save or backup.
	var temporary: FileAccess = FileAccess.open(pending_save_path, FileAccess.WRITE)
	if temporary == null:
		return false
	temporary.store_string(JSON.stringify(_save_state_payload(), "  "))
	temporary.flush()
	var write_ok: bool = temporary.get_error() == OK
	temporary.close()
	if not write_ok or _read_valid_save(pending_save_path).is_empty():
		return false
	var pending_absolute: String = ProjectSettings.globalize_path(pending_save_path)
	var primary_absolute: String = ProjectSettings.globalize_path(save_path)
	var backup_absolute: String = ProjectSettings.globalize_path(backup_save_path)
	# Never let a corrupt primary replace the last verified backup.
	var primary_exists: bool = FileAccess.file_exists(save_path)
	var primary_valid: bool = primary_exists and not _read_valid_save(save_path).is_empty()
	if primary_valid:
		if DirAccess.copy_absolute(primary_absolute, backup_absolute) != OK:
			return false
	if primary_exists:
		if DirAccess.remove_absolute(primary_absolute) != OK:
			return false
	if DirAccess.rename_absolute(pending_absolute, primary_absolute) != OK:
		# On a failed rename, preserve or restore the latest verified snapshot.
		if not _read_valid_save(backup_save_path).is_empty():
			DirAccess.copy_absolute(backup_absolute, primary_absolute)
		return false
	last_save_ok = true
	return true

func load_game() -> bool:
	last_load_source = ""
	if _load_from_path(save_path):
		return true
	# Also covers the case when the primary file is missing altogether.
	if _load_from_path(backup_save_path):
		return true
	# The first ever save might have been staged but interrupted before commit.
	return _load_from_path(pending_save_path)

func _load_from_path(path: String) -> bool:
	var payload: Dictionary = _read_valid_save(path)
	if payload.is_empty():
		return false
	# A failed validation must never partially mutate the live game.
	data = _upgrade_state(payload["state"])
	last_load_source = "backup" if path == backup_save_path else ("staged" if path == pending_save_path else "primary")
	state_changed.emit("load")
	return true

func _upgrade_state(state: Dictionary) -> Dictionary:
	# Compatible migration of already-issued version 4 saves.
	var defaults := {"wallet":600,"active_contract":{},"contracts_completed":0,"cargo_quality_sum":0,"business_revenue":0,"vehicle_fuel":100.0,"vehicle_health":100.0,
		"inventories":CITY_ECONOMY.default_inventories(),"unemployment":45,"district_scores":{"forum":66,"housing":66,"lower":64,"aqueduct":67},"economy_ledger":[],"deliveries_value":0,
		"properties":REAL_ESTATE.default_properties(),"real_estate_revenue":0,"reputation":35,"personal_debt":0,"citizen_contacts":{},
		"market_orders":0,"market_history":[],"vehicle_owned":VEHICLE_CATALOG.default_owned(),"vehicle_selected":"compact","vehicle_mileage":0.0,"interior":"",
		"garage_status":VEHICLE_CATALOG.default_garage_status(),"career_xp":CAREER.default_xp(),"projects_active":{},"projects_done":[],"interior_return":DEFAULT_POSITION.duplicate(),
		"road_quality":75,"roads_cleared":[],"roads_repaired_total":0,"city_case":{},"case_history":[],
		"service_active":{},"service_completed":0,"service_failed":0,"service_history":[],"service_last_turn":0,
		"law":LAW.initial(),"neighborhood_active":{},"neighborhood_history":[],"neighborhood_completed":0,"neighborhood_last_turn":0,"politics":POLITICS.initial(),"driving_trial":{},"trial_records":{},"trial_history":[],"discovered_sites":[],"discovery_history":[]}
	var legacy_car: String = str(state.get("vehicle_selected","compact"))
	var has_return: bool = state.has("interior_return")
	var has_garage: bool = state.has("garage_status")
	var has_quality_history: bool = state.has("cargo_quality_sum")
	for field in defaults:
		if not state.has(field):
			state[field] = defaults[field].duplicate(true) if defaults[field] is Dictionary or defaults[field] is Array else defaults[field]
	if not has_quality_history:
		# Earlier successful deliveries were not graded; retain their historical
		# result as fully delivered rather than showing a false 0% average.
		state["cargo_quality_sum"] = 100 * int(state.get("contracts_completed",0))
	if not has_return:
		var previous_room: String = str(state.get("interior",""))
		var room_locations := {"cityhall":"forum","market":"housing","depot":"lower","power":"aqueduct"}
		if room_locations.has(previous_room):
			var region: String = str(room_locations[previous_room])
			var outside: Vector3 = LOCATIONS[region]
			state["interior_return"] = [outside.x,outside.y + 1.3,outside.z + 8.0]
	if not has_garage and VEHICLE_CATALOG.available(legacy_car):
		state["garage_status"][legacy_car] = {"fuel":float(state.get("vehicle_fuel",100.0)),"health":float(state.get("vehicle_health",100.0)),"mileage":float(state.get("vehicle_mileage",0.0))}
	var old_contract: Dictionary = state.get("active_contract",{})
	if not old_contract.is_empty() and not old_contract.has("cargo_progress"):
		old_contract["cargo_progress"] = CARGO.legacy_profile(old_contract,float(state["vehicle_mileage"]),float(state["vehicle_health"]),str(state["vehicle_selected"]))
	return state

func _valid_state(state: Variant) -> bool:
	if not (state is Dictionary) or state.get("version", 0) != VERSION:
		return false
	var required := ["turn", "treasury", "population", "energy", "water", "food", "stability", "science", "tax", "selected", "buildings", "technologies", "businesses", "actions_left", "trust", "mission", "player_position", "vehicle_position", "seed", "debt", "course", "incident", "day_clock", "log", "history", "money_earned", "deliveries", "vehicle_heading"]
	for key in required:
		if not state.has(key): return false
	if not state["buildings"] is Dictionary or not state["technologies"] is Dictionary or not state["businesses"] is Dictionary:
		return false
	for key in BUILDING_ORDER:
		if not state["buildings"].has(key) or not _safe_number(state["buildings"][key], 0, 4): return false
	for key in RESEARCH_ORDER:
		if not state["technologies"].has(key) or not state["technologies"][key] is bool: return false
	for key in BUSINESSES:
		if not state["businesses"].has(key) or not state["businesses"][key] is bool: return false
	if not _safe_number(state["turn"],1,100000) or not _safe_number(state["treasury"],-20000000,20000000): return false
	if not _safe_number(state["population"],5000,3000000) or not _safe_number(state["mission"],0,100): return false
	if not _safe_number(state["tax"],0,40) or not _safe_number(state["actions_left"],0,2): return false
	if not _safe_number(state["seed"],1,4294967295) or not _safe_number(state["debt"],0,20000000): return false
	if not _safe_number(state["science"],0,200000) or not _safe_number(state["money_earned"],0,20000000): return false
	if not _safe_number(state["day_clock"],0,24) or not _safe_number(state["vehicle_heading"],-100000,100000): return false
	if not _safe_number(state["deliveries"],0,100000): return false
	if state.has("wallet") and not _safe_number(state["wallet"],0,30000000): return false
	if state.has("vehicle_fuel") and not _safe_number(state["vehicle_fuel"],0,100): return false
	if state.has("vehicle_health") and not _safe_number(state["vehicle_health"],0,100): return false
	if state.has("contracts_completed") and not _safe_number(state["contracts_completed"],0,100000): return false
	if state.has("business_revenue") and not _safe_number(state["business_revenue"],0,30000000): return false
	if state.has("cargo_quality_sum"):
		if not _safe_number(state["cargo_quality_sum"],0,10000000): return false
		if state.has("contracts_completed") and int(state["cargo_quality_sum"]) > 100 * int(state["contracts_completed"]): return false
	if state.has("active_contract"):
		if not (state["active_contract"] is Dictionary): return false
		var active: Dictionary = state["active_contract"]
		if not active.is_empty():
			for field in ["id","pickup","dropoff","reward","limit_turns","accepted_turn","title"]:
				if not active.has(field): return false
			if not (active["id"] is String) or active["id"].length() > 45: return false
			if not ["cityhall","market","depot","power"].has(active["pickup"]): return false
			if not ["cityhall","market","depot","power"].has(active["dropoff"]): return false
			if active["pickup"] == active["dropoff"]: return false
			if not _safe_number(active["reward"],50,2000): return false
			if not _safe_number(active["limit_turns"],1,10): return false
			if not _safe_number(active["accepted_turn"],1,100000): return false
			if active.has("cargo") and not str(active["cargo"]) in CITY_ECONOMY.STOCK_TYPES: return false
			if active.has("quantity") and not _safe_number(active["quantity"],1,100): return false
			if not (active["title"] is Dictionary): return false
			if active.has("cargo_progress") and not CARGO.valid_progress(active["cargo_progress"]): return false
			for lang in ["ru","en","zh"]:
				if not (active["title"].get(lang,null) is String) or active["title"][lang].length() > 120: return false
	if state.has("inventories"):
		if not (state["inventories"] is Dictionary): return false
		for product in CITY_ECONOMY.STOCK_TYPES:
			if not _safe_number(state["inventories"].get(product,-1),0,CITY_ECONOMY.STOCK_LIMIT): return false
	if state.has("unemployment") and not _safe_number(state["unemployment"],0,100): return false
	if state.has("deliveries_value") and not _safe_number(state["deliveries_value"],0,20000000): return false
	if state.has("reputation") and not _safe_number(state["reputation"],0,100): return false
	if state.has("citizen_contacts"):
		if not (state["citizen_contacts"] is Dictionary) or state["citizen_contacts"].size() > 34: return false
		for key in state["citizen_contacts"]:
			if not str(key).is_valid_int() or int(key) < 0 or int(key) >= 34: return false
			if not _safe_number(state["citizen_contacts"][key],1,100000): return false
	if state.has("market_orders") and not _safe_number(state["market_orders"],0,4): return false
	if state.has("market_history"):
		if not state["market_history"] is Array or state["market_history"].size() > 40: return false
		for entry in state["market_history"]:
			if not entry is Dictionary: return false
			if not CITY_MARKET.GOODS.has(str(entry.get("product",""))): return false
			if not (entry.get("buy",null) is bool): return false
			if not _safe_number(entry.get("turn",-1),1,100000): return false
			if not _safe_number(entry.get("quantity",-1),1,100): return false
			if not _safe_number(entry.get("total",-1),1,100000): return false
	if state.has("vehicle_owned"):
		if not state["vehicle_owned"] is Dictionary: return false
		for vehicle_id in VEHICLE_CATALOG.ORDER:
			if not (state["vehicle_owned"].get(vehicle_id,null) is bool): return false
		if not bool(state["vehicle_owned"].get("compact",false)): return false
	if state.has("vehicle_selected"):
		if not VEHICLE_CATALOG.available(str(state["vehicle_selected"])): return false
		if state.has("vehicle_owned") and not bool(state["vehicle_owned"].get(state["vehicle_selected"],false)): return false
	if state.has("vehicle_mileage") and not _safe_number(state["vehicle_mileage"],0,50000000): return false
	if state.has("garage_status") and not VEHICLE_CATALOG.valid_garage(state["garage_status"]): return false
	if state.has("career_xp") and not CAREER.valid_xp(state["career_xp"]): return false
	if state.has("road_quality") and not _safe_number(state["road_quality"],0,100): return false
	if state.has("roads_repaired_total") and not _safe_number(state["roads_repaired_total"],0,100000): return false
	if state.has("roads_cleared"):
		if not state["roads_cleared"] is Array or state["roads_cleared"].size() > 2: return false
		var seen_roads := {}
		for road_id in state["roads_cleared"]:
			if not road_id is String or MOBILITY.incident_by_id(road_id).is_empty() or seen_roads.has(road_id): return false
			seen_roads[road_id] = true
	# Optional for compatibility with version-4 snapshots made before v0.13.
	if state.has("service_active") and not SERVICE.valid_active(state["service_active"]): return false
	if state.has("service_completed") and not _safe_number(state["service_completed"],0,100000): return false
	if state.has("service_failed") and not _safe_number(state["service_failed"],0,100000): return false
	if state.has("service_last_turn"):
		if not _safe_number(state["service_last_turn"],0,100000): return false
		if int(state["service_last_turn"]) > int(state["turn"]): return false
	if state.has("service_history") and not SERVICE.valid_history(state["service_history"]): return false
	if state.has("law") and not LAW.valid(state["law"],int(state["turn"])): return false
	if not NEIGHBORHOOD.valid(state): return false
	if not TRIALS.valid(state): return false
	if not DISCOVERY.valid_state(state): return false
	if state.has("politics") and not POLITICS.valid(state["politics"],int(state["turn"])): return false
	if state.has("neighborhood_active") and not state["neighborhood_active"].is_empty():
		if state.has("active_contract") and not state["active_contract"].is_empty(): return false
		if state.has("service_active") and not state["service_active"].is_empty(): return false
	if state.has("service_active") and not state["service_active"].is_empty():
		if int(state["service_active"]["start_turn"]) > int(state["turn"]): return false
		if int(state["turn"]) > int(state["service_active"]["due_turn"]): return false
		if state.has("service_last_turn") and int(state["service_last_turn"]) != int(state["service_active"]["start_turn"]): return false
		if state.has("active_contract") and not state["active_contract"].is_empty(): return false
	if not CITY_CASES.valid_state(state): return false
	if state.has("projects_active") or state.has("projects_done"):
		if not (state.has("projects_active") and state.has("projects_done") and INITIATIVES.valid(state)): return false
	if state.has("interior") and not ["","cityhall","market","depot","power","council","clinic","academy","homes","school","gardens","factory","purifier"].has(str(state["interior"])): return false
	if state.has("personal_debt") and not _safe_number(state["personal_debt"],0,20000000): return false
	if state.has("real_estate_revenue") and not _safe_number(state["real_estate_revenue"],-30000000,30000000): return false
	if state.has("properties"):
		if not (state["properties"] is Dictionary): return false
		for property_id in REAL_ESTATE.PROPERTY_IDS:
			if not _safe_number(state["properties"].get(property_id,-1),0,REAL_ESTATE.MAX_LEVEL): return false
	if state.has("district_scores"):
		if not (state["district_scores"] is Dictionary): return false
		for region in DISTRICTS:
			if not _safe_number(state["district_scores"].get(region,-1),0,100): return false
	if state.has("economy_ledger"):
		if not (state["economy_ledger"] is Array) or state["economy_ledger"].size() > 16: return false
		for item in state["economy_ledger"]:
			if not (item is Dictionary) or not (item.get("code") is String) or not _safe_number(item.get("amount"),-1000000,1000000): return false
			if not (item.get("detail") is String) or item["detail"].length() > 150: return false
	if not (state["course"] in ["balance", "industry", "energy", "welfare"]): return false
	if not (state["incident"] is String) or state["incident"].length() > 40: return false
	if not (state["log"] is Array) or state["log"].size() > 55: return false
	if not (state["history"] is Array) or state["history"].size() > 60: return false
	for point in state["history"]:
		if not (point is Dictionary): return false
		for key in ["turn","treasury","wallet","population","stability","net"]:
			if not point.has(key) or not _safe_number(point[key],-30000000,30000000): return false
	for k in ["energy","water","food","stability"]:
		if not _safe_number(state[k],0,100): return false
	if not DISTRICTS.has(state["selected"]): return false
	if not (state["trust"] is Array) or state["trust"].size() != 4: return false
	for v in state["trust"]:
		if not _safe_number(v,0,100): return false
	if state.has("interior_return"):
		if not (state["interior_return"] is Array) or state["interior_return"].size() != 3: return false
		for element in state["interior_return"]:
			if not _safe_number(element,-10000,10000): return false
	for name in ["player_position", "vehicle_position"]:
		if not (state[name] is Array) or state[name].size() != 3: return false
		for v in state[name]:
			if not _safe_number(v,-10000,10000): return false
	return true

func _safe_number(value: Variant, low: float, high: float) -> bool:
	if not (value is float or value is int): return false
	return is_finite(float(value)) and value >= low and value <= high

func import_v3_payload(payload: Dictionary) -> bool:
	if payload.get("format", "") != "osgard-time-omega" or int(payload.get("version", 0)) != 3:
		return false
	var prior: Variant = payload.get("state", null)
	if not (prior is Dictionary):
		return false
	var required := ["turn", "treasury", "population", "energy", "water", "food", "stability", "trust", "science", "debt", "tax", "course", "buildings", "technologies"]
	for key in required:
		if not prior.has(key): return false
	for key in ["energy", "water", "food", "stability"]:
		if not _safe_number(prior[key], 0, 100): return false
	if not _safe_number(prior["turn"], 1, 100000) or not _safe_number(prior["treasury"], -20000000, 20000000): return false
	if not _safe_number(prior["population"], 5000, 3000000) or not _safe_number(prior["tax"],0,40): return false
	if not prior["buildings"] is Dictionary or not prior["technologies"] is Dictionary: return false
	for key in BUILDING_ORDER:
		if not _safe_number(prior["buildings"].get(key, -1), 0, 4): return false
	for key in RESEARCH_ORDER:
		if not (prior["technologies"].get(key, null) is bool): return false
	if not (prior["trust"] is Array) or prior["trust"].size() != 4: return false
	for value in prior["trust"]:
		if not _safe_number(value,0,100): return false
	var fresh := new_game()
	for key in ["seed", "turn", "treasury", "population", "energy", "water", "food", "stability", "trust", "science", "debt", "tax", "course", "buildings", "technologies", "selected"]:
		if prior.has(key): fresh[key] = prior[key].duplicate(true) if prior[key] is Dictionary or prior[key] is Array else prior[key]
	if not DISTRICTS.has(fresh["selected"]): fresh["selected"] = "forum"
	if not ["balance", "industry", "energy", "welfare"].has(fresh["course"]): fresh["course"] = "balance"
	if prior.has("actionsLeft") and _safe_number(prior["actionsLeft"],0,2):
		fresh["actions_left"] = int(prior["actionsLeft"])
	if not _valid_state(fresh): return false
	data = fresh
	state_changed.emit("migrated")
	return true
