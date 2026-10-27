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

static func policy_preview(state: Dictionary, buildings: Dictionary, course: String) -> Dictionary:
	if not ["balance","industry","energy","welfare"].has(course) or str(state.get("course","balance")) == course:
		return {}
	var baseline: Dictionary = ECONOMY.project(state,buildings)
	var alternate: Dictionary = state.duplicate(true)
	alternate["course"] = course
	var candidate: Dictionary = ECONOMY.project(alternate,buildings)
	return {
		"course":course,
		"net_delta":int(candidate["net"])-int(baseline["net"]),
		"energy_delta":int(candidate["energy"])-int(baseline["energy"]),
		"water_delta":int(candidate["water"])-int(baseline["water"]),
		"food_delta":int(candidate["food"])-int(baseline["food"]),
		"trust_per_turn_delta":int(candidate["trust_delta"])-int(baseline["trust_delta"]),
		"stability_per_turn_delta":int(candidate["stability_delta"])-int(baseline["stability_delta"]),
		"population_per_turn_delta":int(candidate["population_delta"])-int(baseline["population_delta"]),
		"turn":int(state["turn"])
	}

static func explain_policy(result: Dictionary, lang: String) -> String:
	if result.is_empty():
		return ""
	var forecast: String = "Следующий такт · при текущих условиях" if lang=="ru" else ("Next turn · current conditions" if lang=="en" else "下回合 · 按当前条件")
	var money: String = "баланс" if lang=="ru" else ("budget" if lang=="en" else "预算")
	var energy: String = "энергия" if lang=="ru" else ("energy" if lang=="en" else "能源")
	var trust: String = "доверие" if lang=="ru" else ("trust" if lang=="en" else "信任")
	var stability: String = "стабильность" if lang=="ru" else ("stability" if lang=="en" else "稳定")
	return "%s · %s %+d · %s %+d · %s %+d · %s %+d" % [
		forecast,money,int(result["net_delta"]),energy,int(result["energy_delta"]),
		trust,int(result["trust_per_turn_delta"]),stability,int(result["stability_per_turn_delta"])]
