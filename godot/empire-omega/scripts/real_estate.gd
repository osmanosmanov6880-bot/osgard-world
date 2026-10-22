extends RefCounted
## Single-player property market. No real-money transactions.
## Pure forecast: ownership, neighbourhood services and utilities determine rent.

const MAX_LEVEL = 3
const PROPERTY_IDS = ["arcade", "forum_flats", "garden_lofts", "east_residence", "foundry", "depot_offices", "canal_house", "skyline"]
const PROPERTIES = {
	"arcade":{"district":"forum","price":420,"rent":38,"upkeep":9,"name":{"ru":"Аркада форума","en":"Forum Arcade","zh":"广场拱廊"},"position":Vector3(-182.0,0.0,-78.0)},
	"forum_flats":{"district":"forum","price":1050,"rent":96,"upkeep":22,"name":{"ru":"Квартиры сената","en":"Senate Apartments","zh":"议会公寓"},"position":Vector3(-78.0,0.0,-182.0)},
	"garden_lofts":{"district":"housing","price":620,"rent":65,"upkeep":14,"name":{"ru":"Садовые лофты","en":"Garden Lofts","zh":"花园阁楼"},"position":Vector3(78.0,0.0,-182.0)},
	"east_residence":{"district":"housing","price":1420,"rent":133,"upkeep":28,"name":{"ru":"Восточная резиденция","en":"East Residence","zh":"东区公馆"},"position":Vector3(182.0,0.0,-78.0)},
	"foundry":{"district":"lower","price":980,"rent":89,"upkeep":21,"name":{"ru":"Промышленный двор","en":"Foundry Courtyard","zh":"工业庭院"},"position":Vector3(-182.0,0.0,78.0)},
	"depot_offices":{"district":"lower","price":1850,"rent":171,"upkeep":34,"name":{"ru":"Логистический комплекс","en":"Logistics Complex","zh":"物流综合体"},"position":Vector3(-78.0,0.0,182.0)},
	"canal_house":{"district":"aqueduct","price":740,"rent":68,"upkeep":15,"name":{"ru":"Дом у канала","en":"Canal House","zh":"运河住宅"},"position":Vector3(78.0,0.0,182.0)},
	"skyline":{"district":"aqueduct","price":2250,"rent":218,"upkeep":48,"name":{"ru":"Башня горизонта","en":"Skyline Tower","zh":"天际塔"},"position":Vector3(182.0,0.0,78.0)}
}

static func default_properties() -> Dictionary:
	var output := {}
	for key in PROPERTY_IDS:
		output[key] = 0
	return output

static func purchase_cost(id: String, level: int) -> int:
	if not PROPERTIES.has(id) or level >= MAX_LEVEL or level < 0:
		return -1
	var initial: int = int(PROPERTIES[id]["price"])
	return initial if level == 0 else roundi(float(initial) * (0.55 + float(level) * 0.32))

static func project(state: Dictionary, district_scores: Dictionary) -> Dictionary:
	var owned: Dictionary = state.get("properties",default_properties())
	var entries: Array = []
	var revenue := 0
	var costs := 0
	var occupied := 0
	var total := 0
	for id in PROPERTY_IDS:
		var level: int = int(owned.get(id,0))
		if level < 1:
			continue
		var spec: Dictionary = PROPERTIES[id]
		var district: String = str(spec["district"])
		var wellbeing: int = int(district_scores.get(district,50))
		var unemployment: int = int(state.get("unemployment",40))
		var utilities: int = mini(int(state["energy"]),int(state["water"]))
		# The forecast remains deterministic and occupancy cannot exceed 100%.
		var outage_penalty: int = maxi(0,40-utilities)*2
		var occupation: int = clampi(45 + wellbeing / 2 - unemployment / 3 + (utilities - 60) / 6 - outage_penalty,5,98)
		var rent: int = roundi(float(int(spec["rent"])) * (1.0 + float(level-1)*0.65) * float(occupation) / 100.0)
		var upkeep: int = int(spec["upkeep"]) + (level-1)*roundi(float(spec["upkeep"])*0.55)
		revenue += rent
		costs += upkeep
		occupied += occupation
		total += 1
		entries.append({"id":id,"level":level,"occupancy":occupation,"revenue":rent,"upkeep":upkeep,"net":rent-upkeep})
	return {"revenue":revenue,"expenses":costs,"net":revenue-costs,"mean_occupancy":roundi(float(occupied)/float(maxi(1,total))),"entries":entries}
