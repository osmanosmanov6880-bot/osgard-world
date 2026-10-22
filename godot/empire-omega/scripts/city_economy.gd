extends RefCounted
## Pure, deterministic economy projection. Does not mutate its input.
## All turn results and governor forecasts use the same function.
## GameState remains the sole owner of persistent data and transactions.

const CITY_WEATHER = preload("res://scripts/city_weather.gd")
const INITIATIVES = preload("res://scripts/civic_initiatives.gd")
const MOBILITY = preload("res://scripts/city_mobility.gd")
const STOCK_LIMIT = 100000
const STOCK_TYPES = ["grain", "materials", "goods"]
const BASE_INVENTORIES = {"grain": 140, "materials": 90, "goods": 80}

static func default_inventories() -> Dictionary:
	return BASE_INVENTORIES.duplicate(true)

static func _bound(value: float) -> int:
	return clampi(roundi(value), 0, 100)

static func _stock(value: int) -> int:
	return clampi(value, 0, STOCK_LIMIT)

static func _trust_mean(values: Array) -> float:
	var total := 0.0
	for value in values:
		total += float(value)
	return total / maxf(1.0, float(values.size()))

static func project(state: Dictionary, definitions: Dictionary) -> Dictionary:
	var buildings: Dictionary = state["buildings"]
	var technologies: Dictionary = state["technologies"]
	var businesses: Dictionary = state["businesses"]
	var policy: String = str(state["course"])
	var pop: float = float(state["population"])
	var inventories: Dictionary = state.get("inventories", default_inventories())
	var ledger: Array = []
	var weather: Dictionary = CITY_WEATHER.for_turn(int(state["seed"]),int(state["turn"]))
	var project_bonus: Dictionary = INITIATIVES.modifiers(state)
	var freight_factor: float = MOBILITY.freight_efficiency(state)

	# Municipal utilities. Persistent percentages are reserves: supply-demand changes them.
	var supply_energy: int = roundi((29 + int(project_bonus["energy"]) + int(buildings["plant"]) * 21 + (17 if policy == "energy" else 0) + (9 if technologies["grid"] else 0) + (8 if technologies["automation"] else 0)) * float(weather["energy_factor"]))
	var need_energy: int = roundi(28.0 + pop / 1200.0 + int(buildings["homes"]) * 4 + int(buildings["factory"]) * 13 + int(buildings["market"]) * 3 + int(buildings["purifier"]) * 2)
	var supply_water: int = 30 + int(project_bonus["water"]) + int(buildings["purifier"]) * 19 + int(buildings["reservoir"]) * 9 + (11 if technologies["filtration"] else 0)
	var need_water: int = roundi(22.0 + pop / 1750.0 + int(buildings["factory"]) * 5 + int(buildings["homes"]) * 3 + int(buildings["gardens"]) * 2)
	var supply_food: int = 27 + int(project_bonus["food"]) + int(buildings["gardens"]) * 13 + int(buildings["depot"]) * 10 + int(buildings["market"]) * 3 + (13 if technologies["agronomy"] else 0)
	var need_food: int = roundi(29.0 + pop / 2600.0 + int(buildings["homes"]) * 3)
	var energy: int = _bound(float(state["energy"]) + supply_energy - need_energy)
	var water: int = _bound(float(state["water"]) + supply_water - need_water)
	var food: int = _bound(float(state["food"]) + supply_food - need_food)
	var resource_stress: int = int(energy < 25) + int(water < 25) + int(food < 25)
	var severe: int = int(energy < 8) + int(water < 8) + int(food < 8)

	# Connected production: farms -> grain, facilities -> materials, factories -> goods.
	# Each upstream resource can constrain downstream throughput.
	var workforce: int = roundi(pop * 0.58)
	var jobs: int = 4200 + int(project_bonus["jobs"]) + int(buildings["factory"]) * 580 + int(buildings["market"]) * 310 + int(buildings["depot"]) * 260 + int(buildings["academy"]) * 180 + int(buildings["homes"]) * 130 + int(buildings["clinic"]) * 140
	for estate_level in state.get("properties",{}).values():
		jobs += int(estate_level) * 22
	if businesses["market_stall"]: jobs += 100
	if businesses["logistics"]: jobs += 280
	if businesses["workshop"]: jobs += 420
	var employment_ratio: float = clampf(float(jobs) / maxf(1.0, float(workforce)), 0.0, 1.0)
	var unemployment: int = _bound((1.0 - employment_ratio) * 100.0)
	var utility_factor: float = clampf(minf(float(energy), float(water)) / 60.0, 0.20, 1.0)
	var worker_factor: float = clampf(employment_ratio / 0.65, 0.4, 1.0)
	var grain_produced: int = roundi((42.0 + int(buildings["gardens"]) * 36.0 + int(buildings["depot"]) * 9.0) * (1.25 if technologies["agronomy"] else 1.0) * float(weather["grain_factor"]))
	var grain_demand: int = roundi(pop / 280.0 + int(buildings["homes"]) * 5.0)
	var grain_available: int = int(inventories.get("grain", 0)) + grain_produced
	var grain_consumed: int = mini(grain_demand, grain_available)
	var grain_shortage: int = grain_demand - grain_consumed
	var grain_next: int = _stock(grain_available - grain_consumed)

	var raw_materials_produced: int = roundi((14.0 + int(buildings["factory"]) * 32.0 + int(buildings["depot"]) * 14.0) * utility_factor * worker_factor * freight_factor)
	var industrial_need: int = int(buildings["factory"]) * 15 + (12 if businesses["workshop"] else 0)
	var infrastructure_need: int = 11 + int(buildings["homes"]) * 3 + int(buildings["plant"]) * 2
	var raw_available: int = int(inventories.get("materials", 0)) + raw_materials_produced
	var used_infrastructure: int = mini(infrastructure_need, raw_available)
	var raw_remaining: int = raw_available - used_infrastructure
	var used_industry: int = mini(industrial_need, raw_remaining)
	var materials_shortage: int = infrastructure_need + industrial_need - used_infrastructure - used_industry
	var material_next: int = _stock(raw_remaining - used_industry)
	var production_capacity: int = roundi((15.0 + int(buildings["factory"]) * 37.0 + (19 if businesses["workshop"] else 0)) * utility_factor * worker_factor)
	var consumer_goods_produced: int = roundi(float(mini(production_capacity, 15 + used_industry * 3)) * freight_factor)
	var consumer_goods_demand: int = roundi(pop / 440.0 + int(buildings["market"]) * 6.0)
	var goods_available: int = int(inventories.get("goods", 0)) + consumer_goods_produced
	var consumer_goods_sold: int = mini(goods_available, consumer_goods_demand)
	var goods_shortage: int = consumer_goods_demand - consumer_goods_sold
	var goods_next: int = _stock(goods_available - consumer_goods_sold)
	var shortages: int = grain_shortage + materials_shortage + goods_shortage
	var market_health: float = clampf(1.0 - float(shortages) / maxf(1.0, float(grain_demand + infrastructure_need + industrial_need + consumer_goods_demand)), 0.3, 1.0)

	var revenue: int = roundi((33.0 + float(project_bonus["revenue"]) + pop * float(state["tax"]) / 2000.0 + int(buildings["market"]) * 48 + int(buildings["factory"]) * 75 + int(buildings["depot"]) * 7 + (32 if policy == "industry" else 0) + (27 if technologies["commerce"] else 0) + (24 if technologies["automation"] else 0)) * market_health)
	var upkeep := 0
	for id in definitions:
		upkeep += int(buildings[id]) * int(definitions[id]["upkeep"])
	var relief_cost: int = mini(30, grain_shortage + goods_shortage)
	var expenses: int = roundi(54.0 + pop / 1300.0 + upkeep + (16 if policy == "welfare" else 0) + ceil(float(state["debt"]) * 0.04) + relief_cost)

	var social: int = (19 if policy == "welfare" else 0) + int(buildings["clinic"]) * 8 + int(buildings["school"]) * 5
	var capacity: int = 13000 + int(buildings["homes"]) * 1700
	var healthy: bool = resource_stress == 0 and grain_shortage == 0
	var pop_delta: int = roundi(48.0 + float(social) + int(buildings["homes"]) * 22 - float(unemployment) * 0.35) if healthy else roundi(-80.0 * resource_stress - 150.0 * severe - 4.0 * grain_shortage)
	if int(state["population"]) + pop_delta > capacity:
		pop_delta = maxi(-150, roundi(float(capacity - int(state["population"])) / 6.0))
	var tax: int = int(state["tax"])
	var discontent: int = -7 if tax >= 30 else (-4 if tax >= 21 else (2 if tax <= 6 else 0))
	var trust_delta: int = discontent + (3 if policy == "welfare" else 0) + int(buildings["clinic"]) + (1 if technologies["councilAI"] else 0) + (0 if healthy else -3 * resource_stress) - mini(5, int(float(shortages) / 8.0))
	var stability_delta: int = roundi((2.0 if policy == "balance" else 0.0) + int(buildings["council"]) + (2 if technologies["councilAI"] else 0) + int(buildings["gardens"]) * 0.5 + (-3 if _trust_mean(state["trust"]) < 35.0 else 0) + (-4 if int(state["treasury"]) + revenue - expenses < -100 else 0) + (0 if healthy else -6 * resource_stress) + (-3 if tax > 25 else 0) + (-int(buildings["factory"]) if not technologies["filtration"] else 0) - mini(4, int(float(shortages) / 10.0)))

	var district_scores := {}
	for district in ["forum", "housing", "lower", "aqueduct"]:
		var services: int = 0
		for id in definitions:
			if str(definitions[id]["district"]) == district:
				services += int(buildings[id])
		var trust_index: int = ["forum", "housing", "lower", "aqueduct"].find(district)
		district_scores[district] = _bound(float(state["trust"][trust_index]) * 0.68 + float(INITIATIVES.district_bonus(state,district)) + float(services) * 5.0 + float(energy + water + food) / 9.0 - float(unemployment) * 0.13)

	ledger.append({"code":"tax","amount": revenue, "detail": "Сборы и деятельность города"})
	ledger.append({"code":"freight","amount": roundi(freight_factor * 100.0),"detail":"Проходимость дорог и логистическая доступность, %"})
	ledger.append({"code":"services","amount": -expenses, "detail": "Содержание служб и инфраструктуры"})
	ledger.append({"code":"grain","amount": grain_produced - grain_consumed, "detail": "Производство и потребление продовольствия"})
	ledger.append({"code":"materials","amount": raw_materials_produced - infrastructure_need - industrial_need + materials_shortage, "detail": "Производственная цепочка материалов"})
	ledger.append({"code":"goods","amount": consumer_goods_produced - consumer_goods_sold, "detail": "Товары на рынке"})
	ledger.append({"code":"work","amount": -unemployment, "detail": "Безработица в процентах"})
	if shortages > 0:
		ledger.append({"code":"shortage","amount": -shortages, "detail": "Дефицит ресурсов и товаров"})

	return {"revenue":revenue, "expenses":expenses, "net":revenue-expenses,
		"energy":energy,"water":water,"food":food,
		"population_delta":pop_delta,"trust_delta":trust_delta,"stability_delta":stability_delta,
		"science_gain":6 + int(project_bonus["science"]) + int(buildings["academy"]) * 10 + int(buildings["school"]) * 6 + (2 if technologies["councilAI"] else 0),
		"inventories":{"grain":grain_next,"materials":material_next,"goods":goods_next},
		"unemployment":unemployment,"jobs":jobs,"workforce":workforce,
		"district_scores":district_scores,"ledger":ledger,"shortages":shortages,"weather":weather,
		"production":{"grain":grain_produced,"materials":raw_materials_produced,"goods":consumer_goods_produced},"freight_efficiency":freight_factor}
