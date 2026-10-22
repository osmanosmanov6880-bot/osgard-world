extends RefCounted
## Original proxy vehicle designs; upgrade to authored GLB assets when available.
const ORDER = ["compact", "courier", "executive", "utility"]
const VEHICLES = {
	"compact":{"price":0,"reputation":0,"speed":1.0,"acceleration":1.0,"fuel":1.0,"handling":1.0,"paint":"335770",
		"ru":"Городской хэтчбек","en":"City hatchback","zh":"城市掀背车"},
	"courier":{"price":1200,"reputation":18,"speed":0.81,"acceleration":0.78,"fuel":1.18,"handling":0.81,"paint":"a5794b",
		"ru":"Грузовой фургон","en":"Delivery van","zh":"配送厢式货车"},
	"executive":{"price":2700,"reputation":32,"speed":1.32,"acceleration":1.28,"fuel":1.27,"handling":1.06,"paint":"6f819b",
		"ru":"Представительский седан","en":"Executive sedan","zh":"行政轿车"},
	"utility":{"price":4400,"reputation":52,"speed":0.91,"acceleration":0.88,"fuel":1.40,"handling":0.77,"paint":"738770",
		"ru":"Инженерный внедорожник","en":"Utility off-roader","zh":"工程越野车"}
}

static func default_owned() -> Dictionary:
	var owned := {}
	for id in ORDER:
		owned[id] = id == "compact"
	return owned

static func default_garage_status() -> Dictionary:
	var garage := {}
	for id in ORDER:
		garage[id] = {"fuel":100.0,"health":100.0,"mileage":0.0}
	return garage

static func valid_garage(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for id in ORDER:
		var entry: Variant = value.get(id)
		if not (entry is Dictionary):
			return false
		for key in ["fuel","health","mileage"]:
			var n: Variant = entry.get(key)
			if not (n is float or n is int) or not is_finite(float(n)):
				return false
			if float(n) < 0.0 or float(n) > (50000000.0 if key == "mileage" else 100.0):
				return false
	return true

static func available(id: String) -> bool:
	return VEHICLES.has(id)
