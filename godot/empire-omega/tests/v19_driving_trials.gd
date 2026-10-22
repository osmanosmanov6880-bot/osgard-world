extends SceneTree
## Native v0.19 acceptance: execute with Godot 4.4.1, not Python.
const TRIALS = preload("res://scripts/driving_trials.gd")
var passed := 0
var failures := 0

func check(value: bool, message: String) -> void:
	if value:
		passed += 1
	else:
		failures += 1
		push_error("DRIVING TRIAL FAILED: " + message)

func _initialize() -> void:
	call_deferred("_run")

func finish_route(state: Dictionary, miles: float) -> float:
	var route: Dictionary = TRIALS.offer(state)
	var result: String = TRIALS.begin(state,Vector3(-120,1.3,-104),0.0,miles,100.0,"compact",true)
	check(result == "started","accepted " + str(route.get("id","missing")))
	if result != "started": return miles
	check(TRIALS.valid(state),"in-progress save valid")
	var first: Vector3 = Vector3(-120,1.3,-104)
	var expected: int = route["checkpoints"].size()
	for index in range(expected):
		var next: Vector3 = TRIALS.checkpoint(route,index)
		miles += maxf(10.0,Vector2(first.x,first.z).distance_to(Vector2(next.x,next.z)) * 0.7)
		for filler in range(2):
			var waiting: Dictionary = TRIALS.tick(state,2.0,first,miles - maxf(10.0,Vector2(first.x,first.z).distance_to(Vector2(next.x,next.z)) * 0.7),100.0,"compact",true)
			check(waiting["status"] == "running","vehicle approaches checkpoint")
		var tick: Dictionary = TRIALS.tick(state,2.0,next,miles,100.0,"compact",true)
		check(tick["status"] == ("completed" if index == expected-1 else "checkpoint"),"checkpoint progression")
		first = next
	check(state["driving_trial"].is_empty(),"trial settlement finalizes")
	check(TRIALS.valid(state),"settled save valid")
	return miles

func _run() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	check(sim != null,"GameState autoload available")
	if sim == null:
		quit(2)
		return
	check(TRIALS.catalog().size() == 6,"six actual trial routes")
	var state: Dictionary = sim.new_game()
	check(sim._valid_state(state),"new game validates with trial fields")
	var initial_wallet: int = int(state["wallet"])
	check(TRIALS.begin(state,Vector3.ZERO,0.0,0.0,100.0,"compact",true) == "location","remote start rejected")
	check(TRIALS.begin(state,Vector3(-120,1.3,-104),0.0,0.0,100.0,"compact",false) == "location","must be driving")
	check(int(state["wallet"]) == initial_wallet,"rejected requests spend nothing")
	var mileage: float = 0.0
	var medals := {}
	for i in range(6):
		var offered: Dictionary = TRIALS.offer(state)
		check(not medals.has(offered["id"]),"six routes rotate")
		medals[offered["id"]] = true
		mileage = finish_route(state,mileage)
	check(state["trial_records"].size() == 6,"six records recorded")
	check(state["trial_history"].size() == 6,"six attempts preserved")
	check(int(state["wallet"]) > initial_wallet,"achievements award wallet once")
	var before: int = int(state["wallet"])
	mileage = finish_route(state,mileage)
	check(int(state["wallet"]) == before - TRIALS.ENTRY_FEE,"same medal gives no extra payment")
	check(sim._valid_state(state),"all results validate for save")
	check(sim._valid_state(JSON.parse_string(JSON.stringify(state))),"save JSON round-trip validates")
	var illegal: Dictionary = state.duplicate(true)
	illegal["trial_records"]["forum_loop"]["medal"] = 9
	check(not sim._valid_state(illegal),"tampered medals rejected")
	var wanted: Dictionary = sim.new_game()
	wanted["law"]["heat"] = 2
	check(TRIALS.begin(wanted,Vector3(-120,1.3,-104),0.0,0.0,100.0,"compact",true) == "wanted","wanted driver is ineligible")
	var poor: Dictionary = sim.new_game()
	poor["wallet"] = 15
	check(TRIALS.begin(poor,Vector3(-120,1.3,-104),0.0,0.0,100.0,"compact",true) == "funds","fee must be affordable")
	var broken: Dictionary = sim.new_game()
	check(TRIALS.begin(broken,Vector3(-120,1.3,-104),0.0,0.0,100.0,"compact",true) == "started","start for timeout")
	check(TRIALS.tick(broken,400.0,Vector3.ZERO,0.0,100.0,"compact",true)["status"] == "failed","oversized tick rejected without settlement")
	check(broken["trial_history"].size() == 1,"failure recorded exactly once")
	print("DRIVING TRIAL NATIVE: %d passed, %d failed" % [passed,failures])
	quit(0 if failures == 0 else 1)
