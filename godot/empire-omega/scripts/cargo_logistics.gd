extends RefCounted
## Single source of truth for physical freight: real driven distance, cargo wear,
## legacy saves, reward and actual supplies delivered. No money is minted here.
const MIN_DISTANCE := 65.0
const MAX_DISTANCE := 1500.0
const MAX_TRACKED_METERS := 100000.0

static func route_distance(pickup: Vector3, dropoff: Vector3) -> float:
	var horizontal: float = Vector2(pickup.x,pickup.z).distance_to(Vector2(dropoff.x,dropoff.z))
	return clampf(ceilf(horizontal * 0.55),MIN_DISTANCE,MAX_DISTANCE)

static func begin(offer: Dictionary, required: float, mileage: float, health: float, vehicle: String, turn: int) -> Dictionary:
	var result: Dictionary = offer.duplicate(true)
	result["accepted_turn"] = turn
	result["cargo_progress"] = {
		"meters":0.0,"required":clampf(required,MIN_DISTANCE,MAX_DISTANCE),
		"condition":100.0,"vehicle":vehicle,
		"last_mileage":clampf(mileage,0.0,50000000.0),
		"last_health":clampf(health,0.0,100.0),"legacy":false
	}
	return result

static func legacy_profile(offer: Dictionary, mileage: float, health: float, vehicle: String) -> Dictionary:
	# v0.11 contracts have already been accepted. Honour their original terms;
	# requiring an unseen trip would permanently strand a legitimate old save.
	return {
		"meters":MIN_DISTANCE,"required":MIN_DISTANCE,"condition":100.0,
		"vehicle":vehicle,"last_mileage":clampf(mileage,0.0,50000000.0),
		"last_health":clampf(health,0.0,100.0),"legacy":true
	}

static func update(active: Dictionary, mileage: float, health: float, moving: bool, weather: String) -> void:
	if active.is_empty() or not (active.get("cargo_progress") is Dictionary):
		return
	var progress: Dictionary = active["cargo_progress"]
	var previous_miles: float = float(progress.get("last_mileage",mileage))
	var previous_health: float = float(progress.get("last_health",health))
	var distance: float = maxf(0.0,mileage-previous_miles) if moving else 0.0
	# Reject impossible odometer jumps caused by teleporting or malformed saves.
	if distance > 25.0:
		distance = 0.0
	progress["last_mileage"] = clampf(mileage,0.0,50000000.0)
	progress["last_health"] = clampf(health,0.0,100.0)
	if bool(progress.get("legacy",false)) or not moving:
		return
	var damage: float = maxf(0.0,previous_health-health)
	var weather_wear: float = 0.008 if weather == "storm" else (0.004 if weather == "rain" else 0.002)
	progress["meters"] = minf(MAX_TRACKED_METERS,float(progress["meters"])+distance)
	progress["condition"] = clampf(float(progress["condition"])-damage*0.85-distance*weather_wear,5.0,100.0)

static func age(active: Dictionary) -> void:
	if active.is_empty() or not (active.get("cargo_progress") is Dictionary): return
	var progress: Dictionary = active["cargo_progress"]
	if not bool(progress.get("legacy",false)):
		progress["condition"] = maxf(5.0,float(progress["condition"])-1.5)

static func completion_fraction(active: Dictionary) -> float:
	var progress: Dictionary = active.get("cargo_progress",{})
	if progress.is_empty(): return 0.0
	return clampf(float(progress.get("meters",0.0))/maxf(1.0,float(progress.get("required",MIN_DISTANCE))),0.0,1.0)

static func ready(active: Dictionary) -> bool:
	var progress: Dictionary = active.get("cargo_progress",{})
	return not progress.is_empty() and (bool(progress.get("legacy",false)) or completion_fraction(active) >= 1.0)

static func payment(base: int, logistics_bonus: float, business_bonus: int, late: bool, condition: float) -> int:
	var before_quality: float = float(base) * (1.0 + logistics_bonus + float(business_bonus)/100.0)
	var quality_factor: float = 0.45 + clampf(condition,5.0,100.0)*0.0055
	return clampi(roundi(before_quality*quality_factor*(0.65 if late else 1.0)),75,5000)

static func delivered_quantity(active: Dictionary) -> int:
	var quantity: int = clampi(int(active.get("quantity",12)),1,100)
	var quality: float = float(active.get("cargo_progress",{}).get("condition",100.0))
	return clampi(roundi(float(quantity)*clampf(quality/100.0,0.05,1.0)),1,quantity)

static func valid_progress(value: Variant) -> bool:
	if not (value is Dictionary): return false
	if value.size() != 7: return false
	for field in ["meters","required","condition","last_mileage","last_health"]:
		var number: Variant = value.get(field,null)
		if not (number is float or number is int) or not is_finite(float(number)): return false
	if float(value["meters"]) < 0.0 or float(value["meters"]) > MAX_TRACKED_METERS: return false
	if float(value["required"]) < MIN_DISTANCE or float(value["required"]) > MAX_DISTANCE: return false
	if float(value["condition"]) < 5.0 or float(value["condition"]) > 100.0: return false
	if float(value["last_mileage"]) < 0.0 or float(value["last_mileage"]) > 50000000.0: return false
	if float(value["last_health"]) < 0.0 or float(value["last_health"]) > 100.0: return false
	if not (value.get("vehicle") is String) or not ["compact","courier","executive","utility"].has(value["vehicle"]): return false
	if not (value.get("legacy") is bool): return false
	return true
