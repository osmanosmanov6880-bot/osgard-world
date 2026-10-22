extends RefCounted
## Career progression is deterministic, bounded and stored exclusively in the save state.
## A level is earned through game activity, never purchased with real money.

const TRACKS = ["logistics", "enterprise", "engineering", "civic"]
const LABELS = {
	"logistics":{"ru":"Логистика","en":"Logistics","zh":"物流"},
	"enterprise":{"ru":"Предпринимательство","en":"Enterprise","zh":"经营"},
	"engineering":{"ru":"Инженерия","en":"Engineering","zh":"工程"},
	"civic":{"ru":"Общественное влияние","en":"Civic influence","zh":"公共影响"}
}
const THRESHOLDS = [0, 100, 260, 520, 900, 1400]
const MAX_XP = 200000

static func default_xp() -> Dictionary:
	var output := {}
	for track in TRACKS:
		output[track] = 0
	return output

static func valid_xp(value: Variant) -> bool:
	if not (value is Dictionary):
		return false
	for track in TRACKS:
		var number: Variant = value.get(track)
		if not (number is int or number is float):
			return false
		if not is_finite(float(number)) or float(number) != float(int(number)):
			return false
		if int(number) < 0 or int(number) > MAX_XP:
			return false
	return true

static func level(xp: int) -> int:
	var rank := 1
	for threshold in THRESHOLDS:
		if xp >= int(threshold):
			rank += 1
	return clampi(rank - 1, 1, THRESHOLDS.size())

static func next_level_xp(xp: int) -> int:
	for threshold in THRESHOLDS:
		if xp < int(threshold):
			return int(threshold)
	return -1

static func award(state: Dictionary, track: String, xp: int) -> bool:
	if not TRACKS.has(track) or xp <= 0 or xp > 5000:
		return false
	var ranks: Dictionary = state.get("career_xp",default_xp())
	var current: int = clampi(int(ranks.get(track,0)),0,MAX_XP)
	ranks[track] = mini(MAX_XP,current + xp)
	state["career_xp"] = ranks
	return true

static func bonus(state: Dictionary, track: String) -> float:
	if not TRACKS.has(track):
		return 0.0
	var ranks: Dictionary = state.get("career_xp",default_xp())
	var extra_levels: int = maxi(0,level(int(ranks.get(track,0))) - 1)
	match track:
		"logistics": return float(extra_levels) * 0.04
		"enterprise": return float(extra_levels) * 0.05
		"engineering": return float(extra_levels) * 0.02
		"civic": return float(extra_levels) * 0.02
	return 0.0
