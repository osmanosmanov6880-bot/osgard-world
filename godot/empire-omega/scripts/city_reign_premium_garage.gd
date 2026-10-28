extends RefCounted
## CITY REIGN A9: premium real economy garage presentation. This module
## NEVER owns wallet, purchase permissions, physics or save states. It reads
## actual GameState and original vehicle catalog (which remains authority).
const CATALOG = preload("res://scripts/vehicle_catalog.gd")
const SPEC_LABELS = {
	"ru":{"speed":"СКОРОСТЬ","acceleration":"РАЗГОН","handling":"УПРАВЛЕНИЕ",
		"fuel":"РАСХОД","owned":"В СОБСТВЕННОСТИ","selected":"НА ДОРОГЕ",
		"locked":"НЕДОСТУПНО","condition":"СОСТОЯНИЕ",
		"buy":"КУПИТЬ","select":"ВЫБРАТЬ","active":"ВЫБРАНО",
		"money":"ЛИЧНЫЙ БАЛАНС","reputation":"РЕПУТАЦИЯ"},
	"en":{"speed":"SPEED","acceleration":"ACCELERATION","handling":"HANDLING",
		"fuel":"FUEL USAGE","owned":"OWNED","selected":"ON THE ROAD",
		"locked":"UNAVAILABLE","condition":"CONDITION",
		"buy":"BUY","select":"SELECT","active":"SELECTED",
		"money":"PERSONAL BALANCE","reputation":"REPUTATION"},
	"zh":{"speed":"速度","acceleration":"加速","handling":"操控",
		"fuel":"油耗","owned":"已拥有","selected":"正在驾驶",
		"locked":"尚未解锁","condition":"车辆状况",
		"buy":"购买","select":"选择","active":"已选择",
		"money":"个人余额","reputation":"声望"}
}
const STYLES = {
	"compact":{"ru":"Городской универсал","en":"City commuter","zh":"城市通勤"},
	"courier":{"ru":"Городская логистика","en":"Urban logistics","zh":"城市物流"},
	"executive":{"ru":"Представительский класс","en":"Executive class","zh":"行政级"},
	"utility":{"ru":"Инженерные задачи","en":"Municipal utility","zh":"市政工程"}
}
const MAX_COMPARE_FACTOR: float = 1.40

static func _lang(locale: String) -> String:
	return locale if SPEC_LABELS.has(locale) else "ru"

static func columns_for(width: float,phone: bool) -> int:
	return 1 if phone or not is_finite(width) or width < 1000.0 else 2

static func details(state: Dictionary,id: String,locale: String) -> Dictionary:
	if not CATALOG.VEHICLES.has(id):
		return {}
	var lang: String = _lang(locale)
	var spec: Dictionary = CATALOG.VEHICLES[id]
	var owned: bool = bool(state.get("vehicle_owned",{}).get(id,false))
	var selected: bool = str(state.get("vehicle_selected","compact")) == id
	var price: int = int(spec["price"])
	var rep: int = int(spec["reputation"])
	var can_buy: bool = int(state.get("wallet",0)) >= price and int(state.get("reputation",0)) >= rep
	var health: Dictionary = state.get("garage_status",{}).get(id,{})
	var labels: Dictionary = SPEC_LABELS[lang]
	var caption: String = str(STYLES[id][lang])
	var status: String = str(labels["selected"]) if selected else (
		str(labels["owned"]) if owned else str(labels["locked"]))
	var action: String = str(labels["active"]) if selected else (
		str(labels["select"]) if owned else str(labels["buy"]))
	return {
		"id":id,"title":str(spec.get(lang,spec["ru"])),"caption":caption,
		"status":status,"action":action,"owned":owned,"selected":selected,
		"disabled":selected or (not owned and not can_buy),
		"price":price,"reputation":rep,
		"speed":float(spec["speed"]),"acceleration":float(spec["acceleration"]),
		"handling":float(spec["handling"]),"fuel":float(spec["fuel"]),
		"health":clampf(float(health.get("health",100.0)),0.0,100.0),
		"remaining_fuel":clampf(float(health.get("fuel",100.0)),0.0,100.0),
		"labels":labels
	}
