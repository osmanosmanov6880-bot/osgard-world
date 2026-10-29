extends RefCounted
## CITY REIGN R171: one source-of-truth locator for the ACTUAL player.
## Read-only, bounded, zero allocations of nodes, save keys or user rewards.
## No fake GPS destination for menu-only city governance and empty contracts.
const MAX_WORLD_COORD: float = 450.0
const LANGUAGES = ["ru","en","zh"]
const CAPTIONS = {
	"ru":{"trial":"АВТОИСПЫТАНИЕ","resident":"ПОРУЧЕНИЕ ЖИТЕЛЯ","service":"ГОРОДСКОЙ ВЫЗОВ",
		"freight":"ДОСТАВКА ГРУЗА","vehicle":"ВАШ АВТОМОБИЛЬ","market":"ТОРГОВАЯ ГАЛЕРЕЯ",
		"cityhall":"ГОРОДСКОЕ УПРАВЛЕНИЕ","pickup":"ПОЛУЧИТЬ ГРУЗ","recover":"ВОССТАНОВИТЬ ДОСТАВКУ"},
	"en":{"trial":"DRIVING TRIAL","resident":"NEIGHBORHOOD TASK","service":"CITY SERVICE",
		"freight":"ACTIVE CARGO","vehicle":"YOUR VEHICLE","market":"MARKET GALLERY",
		"cityhall":"CITY MANAGEMENT","pickup":"PICK UP CARGO","recover":"RECOVER CARGO DELIVERY"},
	"zh":{"trial":"驾车考核","resident":"居民委托","service":"公共服务",
		"freight":"当前货物","vehicle":"你的车辆","market":"市场画廊",
		"cityhall":"城市管理","pickup":"领取货物","recover":"恢复配送"}
}
const MARKET: Vector3=Vector3(130,0,-130)
const CITY_HALL: Vector3=Vector3(-130,0,-130)
const SUPPORTED_WORLD_ACTIONS = [
	"enter_vehicle","deliver","contract_accept","contract_deliver","service_accept"
]

static func empty(reason: String="none") -> Dictionary:
	return {"active":false,"point":Vector3.ZERO,"source":"none","reason":reason}

static func safe(point: Variant) -> bool:
	if not (point is Vector3):
		return false
	var p: Vector3=point
	return p.is_finite() and absf(p.x)<=MAX_WORLD_COORD and absf(p.z)<=MAX_WORLD_COORD and absf(p.y)<=100.0 and p!=Vector3.ZERO

static func _located(point: Variant,source: String) -> Dictionary:
	if not safe(point):
		return empty("invalid_"+source)
	return {"active":true,"point":point,"source":source,"reason":"located"}

static func localized(source: String,locale: String="ru") -> String:
	var lang: String=locale if LANGUAGES.has(locale) else "en"
	return str(CAPTIONS[lang].get(source,""))

static func resolve(state: Dictionary,action: String,offer: Dictionary,
		locations: Dictionary,vehicle_at: Vector3,trial_goal: Vector3,
		resident_goal: Vector3,service_goal: Vector3) -> Dictionary:
	# The priority is identical to the ACTUAL GameState world objective,
	# except now every route is validated against its real source.
	var trial: Variant=state.get("driving_trial",{})
	if trial is Dictionary and not trial.is_empty():
		return _located(trial_goal,"trial")
	var resident: Variant=state.get("neighborhood_active",{})
	if resident is Dictionary and not resident.is_empty():
		return _located(resident_goal,"resident")
	var service: Variant=state.get("service_active",{})
	if service is Dictionary and not service.is_empty():
		return _located(service_goal,"service")
	var freight: Variant=state.get("active_contract",{})
	if freight is Dictionary and not freight.is_empty():
		var destination: String=str(freight.get("dropoff",""))
		return _located(locations.get(destination,Vector3.ZERO),"freight")
	if not SUPPORTED_WORLD_ACTIONS.has(action):
		return empty("non_spatial_mission")
	match action:
		"enter_vehicle":
			return _located(vehicle_at,"vehicle")
		"deliver":
			return _located(MARKET,"market")
		"service_accept":
			return _located(CITY_HALL,"cityhall")
		"contract_accept","contract_deliver":
			var pickup: String=str(offer.get("pickup",""))
			return _located(locations.get(pickup,Vector3.ZERO),
				"recover" if action=="contract_deliver" else "pickup")
	return empty("non_spatial_mission")
