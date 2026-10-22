extends Node
## Repeatable, deterministic courier contracts; all money moves through GameState.
## The same destination is used by the world waypoint, minimap and HUD.

signal contract_changed(message_id: String)

const DATA_PATH = "res://data/contracts.json"
const CARGO = preload("res://scripts/cargo_logistics.gd")
const LOCATION_NAMES = {
	"cityhall":{"ru":"Дворец правителя","en":"City Hall","zh":"市政厅"},
	"market":{"ru":"Торговая галерея","en":"Market Gallery","zh":"贸易中心"},
	"depot":{"ru":"Логистический терминал","en":"Logistics Depot","zh":"物流中心"},
	"power":{"ru":"Энергетическая станция","en":"Power Station","zh":"发电站"}
}
const POSITIONS = {
	"cityhall":Vector3(-130.0,0.0,-130.0),
	"market":Vector3(130.0,0.0,-130.0),
	"depot":Vector3(-130.0,0.0,130.0),
	"power":Vector3(130.0,0.0,130.0)
}
var offers: Array[Dictionary] = []

func _ready() -> void:
	var content: String = FileAccess.get_file_as_string(DATA_PATH)
	var decoded: Variant = JSON.parse_string(content)
	if decoded is Dictionary and decoded.get("contracts",null) is Array:
		for value in decoded["contracts"]:
			if _safe_offer(value):
				offers.append(value)
	if offers.is_empty():
		push_error("OSGARD: contract catalog missing/invalid")

func _safe_offer(value: Variant) -> bool:
	if not (value is Dictionary): return false
	if not (value.get("id", null) is String): return false
	if not POSITIONS.has(value.get("pickup","")) or not POSITIONS.has(value.get("dropoff","")): return false
	if value["pickup"] == value["dropoff"]: return false
	if not (value.get("reward",null) is int) or value["reward"] < 50 or value["reward"] > 2000: return false
	if not (value.get("limit_turns",null) is int) or value["limit_turns"] < 1 or value["limit_turns"] > 10: return false
	if not (value.get("title",null) is Dictionary): return false
	if not (str(value.get("cargo", "goods")) in ["grain","materials","goods"]): return false
	if not (value.get("quantity",12) is int) or int(value.get("quantity",12)) < 1 or int(value.get("quantity",12)) > 100: return false
	for lang in ["ru","en","zh"]:
		if not (value["title"].get(lang,null) is String): return false
	return true

func current_offer() -> Dictionary:
	if offers.is_empty(): return {}
	var index: int = (int(GameState.data["turn"]) - 1 + int(GameState.data.get("contracts_completed",0))) % offers.size()
	return offers[index].duplicate(true)

func active_contract() -> Dictionary:
	var contract: Variant = GameState.data.get("active_contract",{})
	if contract is Dictionary: return contract
	return {}

func pickup_or_dropoff() -> String:
	var active := active_contract()
	if not active.is_empty(): return str(active.get("dropoff",""))
	return str(current_offer().get("pickup",""))

func destination() -> Vector3:
	return POSITIONS.get(pickup_or_dropoff(),Vector3.ZERO)

func goal_text(lang: String) -> String:
	var active := active_contract()
	var offer: Dictionary = current_offer() if active.is_empty() else active
	if offer.is_empty(): return ""
	var title_data: Dictionary = offer.get("title",{})
	var title: String = str(title_data.get(lang,title_data.get("ru",offer.get("id",""))))
	var destination_id: String = str(offer.get("pickup","")) if active.is_empty() else str(offer.get("dropoff",""))
	var destination_name: String = str(LOCATION_NAMES.get(destination_id,{}).get(lang,destination_id))
	var prefix: String = "Заберите" if lang == "ru" else ("Pick up" if lang == "en" else "取货")
	if not active.is_empty(): prefix = "Доставьте" if lang == "ru" else ("Deliver" if lang == "en" else "交货")
	var label: String = "%s: %s  ·  %s" % [prefix,title,destination_name]
	if not active.is_empty() and active.get("cargo_progress") is Dictionary:
		var progress: Dictionary = active["cargo_progress"]
		var percent: int = roundi(CARGO.completion_fraction(active)*100.0)
		var quality: int = roundi(float(progress.get("condition",100.0)))
		var progress_title: String = "ПРОБЕГ" if lang == "ru" else ("DISTANCE" if lang == "en" else "行驶里程")
		var quality_title: String = "ГРУЗ" if lang == "ru" else ("CARGO" if lang == "en" else "货物状态")
		label += "  ·  %s %d%%  ·  %s %d%%" % [progress_title,percent,quality_title,quality]
	return label

func interact(location_id: String, arrived_by_vehicle: bool = false, vehicle_speed: float = 0.0) -> String:
	if offers.is_empty(): return "unavailable"
	var active := active_contract()
	if active.is_empty():
		if not GameState.data.get("neighborhood_active",{}).is_empty(): return "busy"
		var offer := current_offer()
		if str(offer["pickup"]) != location_id: return "not_here"
		var required: float = CARGO.route_distance(POSITIONS[str(offer["pickup"])],POSITIONS[str(offer["dropoff"])])
		var payload: Dictionary = CARGO.begin(offer,required,float(GameState.data["vehicle_mileage"]),float(GameState.data["vehicle_health"]),str(GameState.data["vehicle_selected"]),int(GameState.data["turn"]))
		GameState.data["active_contract"] = payload
		GameState.record_action("contract_accept",str(payload["id"]))
		GameState.state_changed.emit("contract")
		contract_changed.emit("accepted")
		return "accepted"
	if str(active.get("dropoff","")) != location_id: return "not_here"
	var progress: Dictionary = active.get("cargo_progress",{})
	var legacy: bool = bool(progress.get("legacy",false)) if not progress.is_empty() else true
	if not legacy and not arrived_by_vehicle: return "vehicle_required"
	if arrived_by_vehicle and absf(vehicle_speed) > 1.5: return "stop_vehicle"
	if not legacy and str(progress.get("vehicle","")) != str(GameState.data["vehicle_selected"]): return "vehicle_required"
	if not CARGO.ready(active): return "travel_more"
	# Reward is calculated by the authoritative state engine. No UI or route
	# can submit a higher payment to the settlement method.
	var earned: int = GameState.courier_payment(active)
	if not GameState.complete_courier(active,earned):
		return "unavailable"
	contract_changed.emit("completed")
	return "completed"
