extends RefCounted
## v0.17: Deterministic council support, one public programme per turn, periodic elections.
## This module mutates ONLY the supplied authoritative state; views never change outcomes.

const GROUPS = ["residents", "workers", "merchants", "scholars"]
const LABELS = {
	"residents":{"ru":"Жители","en":"Residents","zh":"居民"},
	"workers":{"ru":"Трудящиеся","en":"Workers","zh":"劳动者"},
	"merchants":{"ru":"Предприниматели","en":"Merchants","zh":"企业家"},
	"scholars":{"ru":"Исследователи","en":"Scholars","zh":"科研人员"}
}
const WEIGHTS = {"residents":36,"workers":29,"merchants":20,"scholars":15}
const BALLOT_INTERVAL = 8
const MEASURE_ORDER = ["public_forum", "jobs_pact", "small_business", "science_grant"]
const MEASURES = {
	"public_forum": {
		"title":{"ru":"Общественные слушания","en":"Public hearings","zh":"公众听证会"},
		"treasury":110,"materials":0,"goods":0,"science":0,"stability":1,"unemployment":0,
		"trust":[4,4,4,4],"support":{"residents":8,"workers":2}
	},
	"jobs_pact": {
		"title":{"ru":"Соглашение о рабочих местах","en":"Jobs agreement","zh":"就业协议"},
		"treasury":160,"materials":10,"goods":0,"science":0,"stability":1,"unemployment":-5,
		"trust":[0,1,5,0],"support":{"workers":11,"merchants":2}
	},
	"small_business": {
		"title":{"ru":"Программа для малого бизнеса","en":"Small business support","zh":"小微企业扶持"},
		"treasury":180,"materials":0,"goods":6,"science":0,"stability":0,"unemployment":-2,
		"trust":[0,0,2,0],"support":{"merchants":12,"residents":2}
	},
	"science_grant": {
		"title":{"ru":"Гранты на исследования","en":"Research grants","zh":"科研资助"},
		"treasury":150,"materials":12,"goods":0,"science":25,"stability":0,"unemployment":0,
		"trust":[2,0,0,2],"support":{"scholars":12,"residents":1}
	}
}

static func initial() -> Dictionary:
	return {
		"support":{"residents":62,"workers":58,"merchants":60,"scholars":55},
		"mandate":58,"last_update_turn":1,"last_measure_turn":0,"last_measure":"",
		"last_ballot":{},"ballot_history":[]
	}

static func _number(value: Variant, lower: int, upper: int) -> bool:
	if not (value is int or value is float): return false
	var n: float = float(value)
	return is_finite(n) and n == floorf(n) and n >= float(lower) and n <= float(upper)

static func valid(value: Variant, turn: int) -> bool:
	if not value is Dictionary: return false
	var support: Variant = value.get("support")
	if not support is Dictionary or support.size() != GROUPS.size(): return false
	for group in GROUPS:
		if not _number(support.get(group,-1),0,100): return false
	if not _number(value.get("mandate",-1),0,100): return false
	if not _number(value.get("last_update_turn",-1),1,turn): return false
	if not _number(value.get("last_measure_turn",-1),0,turn): return false
	var selected: Variant = value.get("last_measure")
	if not selected is String or (selected != "" and not MEASURES.has(selected)): return false
	if selected != "" and int(value["last_measure_turn"]) == 0: return false
	var history: Variant = value.get("ballot_history")
	if not history is Array or history.size() > 12: return false
	var previous := 0
	for entry in history:
		if not _valid_ballot(entry,turn): return false
		if int(entry["turn"]) <= previous: return false
		previous = int(entry["turn"])
	var latest: Variant = value.get("last_ballot")
	if not latest is Dictionary: return false
	if not latest.is_empty():
		if not _valid_ballot(latest,turn): return false
		if history.is_empty() or history.back() != latest: return false
	elif not history.is_empty():
		return false
	return true

static func _valid_ballot(value: Variant, turn: int) -> bool:
	if not value is Dictionary: return false
	if not _number(value.get("turn",-1),BALLOT_INTERVAL,turn): return false
	if int(value["turn"]) % BALLOT_INTERVAL != 0: return false
	if not _number(value.get("share",-1),0,100): return false
	if not _number(value.get("turnout",-1),0,100): return false
	if not value.get("won") is bool: return false
	return bool(value["won"]) == (int(value["share"]) >= 52)

static func election_in(turn: int) -> int:
	return BALLOT_INTERVAL - (turn % BALLOT_INTERVAL)

static func poll(support: Dictionary) -> int:
	var total: int = 0
	for group in GROUPS:
		total += int(support.get(group,0)) * int(WEIGHTS[group])
	return clampi(roundi(float(total) / 100.0),0,100)

static func current_poll(state: Dictionary) -> int:
	var political: Dictionary = state.get("politics",initial())
	return poll(political["support"])

static func build_cost_multiplier(state: Dictionary) -> float:
	var mandate: int = int(state.get("politics",initial()).get("mandate",58))
	if mandate < 40: return 1.08
	if mandate >= 70: return 0.96
	return 1.0

static func can_enact(state: Dictionary, measure: String) -> bool:
	if not MEASURES.has(measure): return false
	var political: Dictionary = state.get("politics",initial())
	if int(political.get("last_measure_turn",0)) == int(state["turn"]): return false
	if int(state.get("actions_left",0)) < 1: return false
	var plan: Dictionary = MEASURES[measure]
	if int(state.get("treasury",0)) < int(plan["treasury"]): return false
	var stock: Dictionary = state.get("inventories",{})
	return int(stock.get("materials",0)) >= int(plan["materials"]) and int(stock.get("goods",0)) >= int(plan["goods"])

static func enact(state: Dictionary, measure: String) -> bool:
	# Check all constraints first. Failure MUST be completely side-effect free.
	if not can_enact(state,measure): return false
	var plan: Dictionary = MEASURES[measure]
	var political: Dictionary = state["politics"]
	state["treasury"] = int(state["treasury"]) - int(plan["treasury"])
	state["inventories"]["materials"] = int(state["inventories"]["materials"]) - int(plan["materials"])
	state["inventories"]["goods"] = int(state["inventories"]["goods"]) - int(plan["goods"])
	state["science"] = int(state["science"]) + int(plan["science"])
	state["unemployment"] = clampi(int(state["unemployment"]) + int(plan["unemployment"]),0,100)
	state["stability"] = clampi(int(state["stability"]) + int(plan["stability"]),0,100)
	for i in range(4):
		state["trust"][i] = clampi(int(state["trust"][i]) + int(plan["trust"][i]),0,100)
	for group in plan["support"]:
		political["support"][group] = clampi(int(political["support"][group]) + int(plan["support"][group]),0,100)
	political["last_measure_turn"] = int(state["turn"])
	political["last_measure"] = measure
	state["actions_left"] = int(state["actions_left"]) - 1
	return true

static func _targets(state: Dictionary) -> Dictionary:
	var trusts: Array = state["trust"]
	var average_trust: float = (float(trusts[0]) + float(trusts[1]) + float(trusts[2]) + float(trusts[3])) / 4.0
	var stability: float = float(state["stability"])
	var utilities: float = (float(state["energy"]) + float(state["water"]) + float(state["food"])) / 3.0
	var jobs: float = 100.0-float(state.get("unemployment",45))
	var tax: float = float(state["tax"])
	var course: String = str(state["course"])
	var inventory: Dictionary = state.get("inventories",{})
	var supply_score: float = minf(12.0,float(inventory.get("goods",0)) / 10.0)
	var buildings: Dictionary = state.get("buildings",{})
	return {
		"residents":clampi(roundi(average_trust*0.56+stability*0.28+utilities*0.16),0,100),
		"workers":clampi(roundi(16.0+float(trusts[2])*0.40+jobs*0.28+(5.0 if course == "welfare" else (2.0 if course == "industry" else 0.0))-(4.0 if tax >= 25.0 else 0.0)),0,100),
		"merchants":clampi(roundi(30.0+stability*0.22+float(trusts[2])*0.24+supply_score-tax*0.45+(7.0 if course == "industry" else 0.0)),0,100),
		"scholars":clampi(roundi(20.0+stability*0.22+float(trusts[0])*0.26+float(buildings.get("academy",0))*3.0+(10.0 if state["technologies"]["councilAI"] else 0.0)),0,100)
	}

static func advance(state: Dictionary) -> Dictionary:
	# Called once, after the actual economic turn has been applied.
	# No stochastic sources: identical state / seed / turn yields identical ballots.
	var political: Dictionary = state["politics"]
	var turn: int = int(state["turn"])
	# Guard against a second settlement or smoothing for the same calendar turn.
	if int(political.get("last_update_turn",0)) == turn: return {}
	political["last_update_turn"] = turn
	var desired: Dictionary = _targets(state)
	for group in GROUPS:
		political["support"][group] = clampi(roundi(float(political["support"][group]) * 0.70 + float(desired[group]) * 0.30),0,100)
	if turn % BALLOT_INTERVAL != 0: return {}
	var swing: int = int((int(state["seed"]) + turn * 13) % 5) - 2
	var result: int = clampi(poll(political["support"]) + swing,0,100)
	var turnout: int = clampi(roundi(43.0 + float(state["stability"])*0.30),35,85)
	var ballot: Dictionary = {"turn":turn,"share":result,"turnout":turnout,"won":result >= 52}
	political["last_ballot"] = ballot.duplicate(true)
	political["ballot_history"].append(ballot.duplicate(true))
	if political["ballot_history"].size() > 12:
		political["ballot_history"].pop_front()
	political["mandate"] = result
	# Victory provides a small stability boost, defeat imposes political costs,
	# but the player retains control to rebuild public confidence.
	if ballot["won"]:
		state["stability"] = clampi(int(state["stability"]) + 2,0,100)
	else:
		state["stability"] = clampi(int(state["stability"]) - 5,0,100)
		for i in range(4):
			state["trust"][i] = clampi(int(state["trust"][i]) - 2,0,100)
	return ballot
