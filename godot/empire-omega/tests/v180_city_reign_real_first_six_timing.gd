extends SceneTree
## R177 genuine first-six verification rejects guessed five-to-ten minutes.
const SESSION=preload("res://scripts/city_reign_first_session_observer.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R177 REAL FIRST SIX TIMING FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var saved: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var state: Dictionary=sim.new_game()
	var untouched: Dictionary=state.duplicate(true)
	var observer=SESSION.new()
	observer.begin(state)
	check(observer.initial_step==0 and observer.events.is_empty() and
		not observer.full_run_observed(),
		"fresh original mission zero starts with no fabricated completion")
	for step in range(SESSION.FIRST_SIX):
		for frame in range(120):
			observer.observe(0.5,state,false,true)
		state["mission"]=step+1
		observer.observe(0.0,state,false,true)
		check(observer.events.size()==step+1 and observer.last_step==step+1,
			"each actual original advancing stage is precisely one event")
	var report: Dictionary=observer.report()
	check(observer.invariants_hold() and observer.full_run_observed() and
		report["status"]=="complete" and report["first_six_verified"],
		"only all six consecutive REAL source events count as full observed run")
	check(absf(observer.completed_at-360.0)<0.1 and
		report["timing_goal_evaluated"] and report["timing_goal_5_to_10_minutes_met"],
		"REAL six-minute unpaused active session satisfies 5–10 minute timing hypothesis")
	check((report["step_transitions"] as Array).size()==6 and
		int(report["current_source_mission"])==6,
		"only original 6 mission source IDs and active frame durations exported")
	check(report["has_network_telemetry"]==false and
		report["local_manual_export_only"]==true and
		report["full_human_playtest_attested"]==false,
		"no network transmission, device tracking or fake claim of observed human playtest")
	check(state["wallet"]==untouched["wallet"] and
		state["treasury"]==untouched["treasury"] and
		sim.get("data")==saved,"passive observer cannot mint money or mutate any actual original save")
	print("CITY REIGN R177 REAL FIRST SESSION TIMING: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
