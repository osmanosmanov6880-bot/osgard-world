extends RefCounted
## Deterministic weather from campaign seed and turn; no global RNG mutation.
## Weather changes climate in the 3D world and the agricultural economy.
const TYPES = ["clear", "cloudy", "rain", "clear", "rain", "wind", "clear", "storm", "cloudy", "drought"]
const LABELS = {
	"clear":{"ru":"Ясно","en":"Clear","zh":"晴朗"},
	"cloudy":{"ru":"Облачно","en":"Cloudy","zh":"多云"},
	"rain":{"ru":"Дождь","en":"Rain","zh":"下雨"},
	"wind":{"ru":"Ветрено","en":"Windy","zh":"大风"},
	"storm":{"ru":"Шторм","en":"Storm","zh":"暴风雨"},
	"drought":{"ru":"Засуха","en":"Drought","zh":"干旱"}
}

static func for_turn(seed: int, turn: int) -> Dictionary:
	# Integer hash used in lieu of nondeterministic random calls.
	var rolled: int = posmod(seed * 31 + turn * 107 + (turn / 3) * 13, 997)
	var kind: String = TYPES[posmod(rolled + turn, TYPES.size())]
	var grain_factor: float = 0.60 if kind == "drought" else (0.76 if kind == "storm" else (1.13 if kind == "rain" else 1.0))
	var road_grip: float = 0.66 if kind == "storm" else (0.80 if kind == "rain" else 1.0)
	var energy_factor: float = 0.82 if kind == "storm" else 1.0
	return {"kind":kind,"grain_factor":grain_factor,"road_grip":road_grip,"energy_factor":energy_factor}
