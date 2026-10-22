extends RefCounted
## Medium-term infrastructure investments tied to inventories and budget.
## Finished projects produce permanent, visible economic changes; work takes turns.

const DISTRICTS = ["forum", "housing", "lower", "aqueduct"]
const ORDER = ["open_records", "civic_hospital", "safe_crossings", "community_park", "factory_safety", "freight_terminal", "clean_network", "smart_substation"]
const PROJECTS = {
	"open_records":{"district":"forum","ru":"Открытый бюджет","en":"Open budget","zh":"公开预算","cost":380,"materials":12,"goods":8,"turns":2,"revenue":10,"jobs":40,"energy":0,"water":0,"food":0,"science":2,"trust":3},
	"civic_hospital":{"district":"forum","ru":"Городской медицинский центр","en":"Civic hospital","zh":"城市医疗中心","cost":610,"materials":26,"goods":12,"turns":3,"revenue":0,"jobs":190,"energy":0,"water":0,"food":0,"science":2,"trust":4},
	"safe_crossings":{"district":"housing","ru":"Безопасные пешеходные переходы","en":"Safe crossings","zh":"安全人行横道","cost":330,"materials":15,"goods":8,"turns":2,"revenue":0,"jobs":70,"energy":0,"water":0,"food":0,"science":0,"trust":4},
	"community_park":{"district":"housing","ru":"Общественный парк","en":"Community park","zh":"社区公园","cost":460,"materials":18,"goods":12,"turns":3,"revenue":0,"jobs":60,"energy":0,"water":0,"food":2,"science":0,"trust":3},
	"factory_safety":{"district":"lower","ru":"Безопасное производство","en":"Factory safety","zh":"安全生产","cost":520,"materials":23,"goods":9,"turns":2,"revenue":15,"jobs":145,"energy":0,"water":0,"food":0,"science":0,"trust":3},
	"freight_terminal":{"district":"lower","ru":"Новый грузовой терминал","en":"Freight terminal","zh":"货运中心","cost":670,"materials":30,"goods":13,"turns":3,"revenue":29,"jobs":245,"energy":0,"water":0,"food":0,"science":0,"trust":2},
	"clean_network":{"district":"aqueduct","ru":"Модернизация водопровода","en":"Clean water network","zh":"清洁供水网络","cost":570,"materials":29,"goods":6,"turns":3,"revenue":0,"jobs":65,"energy":0,"water":12,"food":0,"science":1,"trust":3},
	"smart_substation":{"district":"aqueduct","ru":"Умная подстанция","en":"Smart substation","zh":"智能变电站","cost":590,"materials":29,"goods":10,"turns":3,"revenue":8,"jobs":75,"energy":13,"water":0,"food":0,"science":2,"trust":3}
}

static func valid(state: Dictionary) -> bool:
	if not (state.get("projects_active",null) is Dictionary):
		return false
	if not (state.get("projects_done",null) is Array):
		return false
	var active: Dictionary = state["projects_active"]
	var finished: Array = state["projects_done"]
	if active.size() > 2 or finished.size() > ORDER.size():
		return false
	var seen := {}
	for project_id in finished:
		if not (project_id is String) or not PROJECTS.has(project_id) or seen.has(project_id):
			return false
		seen[project_id] = true
	for project_id in active:
		if not PROJECTS.has(project_id) or seen.has(project_id):
			return false
		var record: Variant = active[project_id]
		if not (record is Dictionary):
			return false
		var remaining: Variant = record.get("remaining")
		if not (remaining is int or remaining is float) or not is_finite(float(remaining)):
			return false
		if float(remaining) != float(int(remaining)):
			return false
		if int(remaining) < 1 or int(record["remaining"]) > int(PROJECTS[project_id]["turns"]):
			return false
	return true

static func can_start(state: Dictionary, project_id: String) -> bool:
	if not PROJECTS.has(project_id) or not valid(state):
		return false
	var project: Dictionary = PROJECTS[project_id]
	if state["projects_done"].has(project_id) or state["projects_active"].has(project_id):
		return false
	if state["projects_active"].size() >= 2 or int(state["actions_left"]) < 1:
		return false
	if int(state["treasury"]) < int(project["cost"]):
		return false
	var stock: Dictionary = state.get("inventories",{})
	return int(stock.get("materials",0)) >= int(project["materials"]) and int(stock.get("goods",0)) >= int(project["goods"])

static func launch(state: Dictionary, project_id: String) -> bool:
	if not can_start(state,project_id):
		return false
	var project: Dictionary = PROJECTS[project_id]
	state["treasury"] = int(state["treasury"]) - int(project["cost"])
	state["inventories"]["materials"] = int(state["inventories"]["materials"]) - int(project["materials"])
	state["inventories"]["goods"] = int(state["inventories"]["goods"]) - int(project["goods"])
	state["actions_left"] = int(state["actions_left"]) - 1
	state["projects_active"][project_id] = {"remaining":int(project["turns"])}
	return true

static func advance(state: Dictionary) -> Array[String]:
	var finished: Array[String] = []
	var active: Dictionary = state.get("projects_active",{})
	for project_id in active.keys():
		var record: Dictionary = active[project_id]
		record["remaining"] = int(record["remaining"]) - 1
		if int(record["remaining"]) <= 0:
			active.erase(project_id)
			state["projects_done"].append(project_id)
			finished.append(project_id)
			var district: String = str(PROJECTS[project_id]["district"])
			var index: int = DISTRICTS.find(district)
			state["trust"][index] = mini(100,int(state["trust"][index]) + int(PROJECTS[project_id]["trust"]))
	return finished

static func modifiers(state: Dictionary) -> Dictionary:
	var bonuses := {"revenue":0,"jobs":0,"energy":0,"water":0,"food":0,"science":0}
	for project_id in state.get("projects_done",[]):
		if PROJECTS.has(project_id):
			for kind in bonuses:
				bonuses[kind] = int(bonuses[kind]) + int(PROJECTS[project_id][kind])
	return bonuses

static func district_bonus(state: Dictionary, district: String) -> int:
	var total := 0
	for project_id in state.get("projects_done",[]):
		if PROJECTS.has(project_id) and str(PROJECTS[project_id]["district"]) == district:
			total += 4
	return total
