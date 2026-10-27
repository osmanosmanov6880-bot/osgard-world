extends RefCounted
## CITY REIGN - deterministic, READ-ONLY civic project impact forecast.
## Compares the exact same turn/weather/market with and without ONE completed
## initiative. It is not a promise of future GDP, and never mutates GameState.
const ECONOMY = preload("res://scripts/city_economy.gd")
const INITIATIVES = preload("res://scripts/civic_initiatives.gd")

static func preview(state: Dictionary, buildings: Dictionary, project_id: String) -> Dictionary:
	if not INITIATIVES.PROJECTS.has(project_id):
		return {}
	if not (state.get("projects_done",null) is Array) or not (state.get("trust",null) is Array):
		return {}
	if state["projects_done"].has(project_id) or state["trust"].size() != 4:
		return {}
	var project: Dictionary = INITIATIVES.PROJECTS[project_id]
	var before: Dictionary = ECONOMY.project(state,buildings)
	var simulated: Dictionary = state.duplicate(true)
	var finished: Array = simulated["projects_done"]
	finished.append(project_id)
	var region: String = str(project["district"])
	var region_index: int = INITIATIVES.DISTRICTS.find(region)
	if region_index < 0:
		return {}
	var trust_before: int = int(state["trust"][region_index])
	var trust_after: int = mini(100,trust_before + int(project["trust"]))
	simulated["trust"][region_index] = trust_after
	var after: Dictionary = ECONOMY.project(simulated,buildings)
	return {
		"id":project_id,
		"district":region,
		"cost":int(project["cost"]),
		"materials":int(project["materials"]),
		"goods":int(project["goods"]),
		"duration":int(project["turns"]),
		"jobs_delta":int(after["jobs"]) - int(before["jobs"]),
		"revenue_delta":int(after["revenue"]) - int(before["revenue"]),
		"net_delta":int(after["net"]) - int(before["net"]),
		"energy_delta":int(after["energy"]) - int(before["energy"]),
		"water_delta":int(after["water"]) - int(before["water"]),
		"food_delta":int(after["food"]) - int(before["food"]),
		"science_delta":int(after["science_gain"]) - int(before["science_gain"]),
		"unemployment_delta":int(after["unemployment"]) - int(before["unemployment"]),
		"district_delta":int(after["district_scores"][region]) - int(before["district_scores"][region]),
		"trust_delta":trust_after - trust_before,
		"turn":int(state["turn"])
	}

static func explain(result: Dictionary, lang: String) -> String:
	if result.is_empty():
		return ""
	var t: String = "ПОСЛЕ СДАЧИ · прогноз при текущих условиях" if lang == "ru" else ("AFTER DELIVERY · forecast at current conditions" if lang == "en" else "竣工预测 · 按当前条件")
	var jobs: String = "рабочих мест" if lang == "ru" else ("jobs" if lang == "en" else "岗位")
	var net: String = "бюджет/такт" if lang == "ru" else ("budget/turn" if lang == "en" else "每回合预算")
	var trust: String = "доверие" if lang == "ru" else ("trust" if lang == "en" else "信任")
	var district: String = "район" if lang == "ru" else ("district" if lang == "en" else "城区")
	return "%s\n%s %+d   ·   %s %+d   ·   %s %+d   ·   %s %+d" % [
		t,jobs,int(result["jobs_delta"]),net,int(result["net_delta"]),
		trust,int(result["trust_delta"]),district,int(result["district_delta"])]
