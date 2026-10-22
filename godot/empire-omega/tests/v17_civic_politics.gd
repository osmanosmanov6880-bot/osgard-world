extends SceneTree
## Native acceptance for v0.17: must be executed by Godot 4.4.1, NOT Python.
const COUNCIL = preload("res://scripts/civic_politics.gd")
var assertions := 0
var failures := 0

func check(condition: bool, description: String) -> void:
	assertions += 1
	if not condition:
		failures += 1
		push_error("COUNCIL FAILED: " + description)
	else:
		print("COUNCIL OK: " + description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	check(sim != null,"GameState autoload available")
	if sim == null:
		quit(2)
		return
	var baseline: Dictionary = sim.new_game()
	check(sim._valid_state(baseline),"new save includes valid politics")
	check(COUNCIL.election_in(1) == 7,"seven turns until first ballot")
	check(COUNCIL.poll(COUNCIL.initial()["support"]) > 50,"initial poll computed from four groups")
	for measure in COUNCIL.MEASURE_ORDER:
		var state: Dictionary = sim.new_game()
		var definition: Dictionary = COUNCIL.MEASURES[measure]
		var treasury: int = int(state["treasury"])
		var materials: int = int(state["inventories"]["materials"])
		var goods: int = int(state["inventories"]["goods"])
		var actions: int = int(state["actions_left"])
		check(COUNCIL.can_enact(state,measure),"can offer " + measure)
		check(COUNCIL.enact(state,measure),"enact " + measure)
		check(int(state["treasury"]) == treasury-int(definition["treasury"]),"treasury cost " + measure)
		check(int(state["inventories"]["materials"]) == materials-int(definition["materials"]),"materials cost " + measure)
		check(int(state["inventories"]["goods"]) == goods-int(definition["goods"]),"goods cost " + measure)
		check(int(state["actions_left"]) == actions-1,"one action used " + measure)
		check(COUNCIL.valid(state["politics"],int(state["turn"])),"valid after measure " + measure)
		var snapshot: String = JSON.stringify(state)
		check(not COUNCIL.enact(state,measure),"duplicate measure rejected " + measure)
		check(snapshot == JSON.stringify(state),"no side effects after rejection " + measure)
	var broke: Dictionary = sim.new_game()
	broke["treasury"] = 0
	var original: String = JSON.stringify(broke)
	check(not COUNCIL.enact(broke,"science_grant"),"reject inadequate treasury")
	check(original == JSON.stringify(broke),"reject does not mutate resources")
	check(not COUNCIL.enact(broke,"not_real"),"reject unknown policy")
	var limited: Dictionary = sim.new_game()
	limited["inventories"]["materials"] = 0
	check(not COUNCIL.enact(limited,"science_grant"),"reject missing materials")
	var legacy: Dictionary = sim.new_game()
	legacy.erase("politics")
	check(sim._valid_state(legacy),"old v4 snapshots accepted without council")
	var restored: Dictionary = sim._upgrade_state(legacy)
	check(COUNCIL.valid(restored["politics"],int(restored["turn"])),"old snapshot receives default council")
	var two: Dictionary = restored.duplicate(true)
	for turn in range(2,49):
		restored["turn"] = turn
		two["turn"] = turn
		var ballot: Dictionary = COUNCIL.advance(restored)
		var second: Dictionary = COUNCIL.advance(two)
		check(ballot == second,"deterministic step " + str(turn))
		check(ballot.is_empty() == (turn % 8 != 0),"elections every eighth turn " + str(turn))
		check(COUNCIL.valid(restored["politics"],turn),"valid political state " + str(turn))
	check(restored["politics"]["ballot_history"].size() == 6,"six unique ballots by turn 48")
	check(restored == two,"replays produce the same state")
	var before_repeat: String = JSON.stringify(restored)
	check(COUNCIL.advance(restored).is_empty(),"repeated settlement does not award votes")
	check(before_repeat == JSON.stringify(restored),"repeated settlement is side-effect-free")
	check(sim._valid_state(restored),"council save validates with latest ballot")
	var roundtrip: Variant = JSON.parse_string(JSON.stringify(restored))
	check(roundtrip is Dictionary and sim._valid_state(roundtrip),"JSON round trip validates")
	var invalid: Dictionary = restored.duplicate(true)
	invalid["politics"]["support"]["workers"] = 1000
	check(not sim._valid_state(invalid),"tampered group support rejected")
	invalid = restored.duplicate(true)
	invalid["politics"]["ballot_history"][0]["won"] = not bool(invalid["politics"]["ballot_history"][0]["won"])
	check(not sim._valid_state(invalid),"tampered ballot outcome rejected")
	var champion: Dictionary = sim.new_game()
	champion["politics"]["mandate"] = 82
	var suspended: Dictionary = sim.new_game()
	suspended["politics"]["mandate"] = 28
	check(COUNCIL.build_cost_multiplier(champion) < 1.0,"strong mandate reduces construction cost")
	check(COUNCIL.build_cost_multiplier(suspended) > 1.0,"weak mandate raises construction cost")
	print("COUNCIL NATIVE: %d assertions, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
