extends SceneTree
## R177 interrupted, resumed and backgrounded actual-playing counter.
const SESSION=preload("res://scripts/city_reign_first_session_observer.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R177 PRIVACY AND RESUME FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var state: Dictionary=sim.new_game()
	state["mission"]=3
	var o=SESSION.new()
	o.begin(state)
	check(not o.first_run and o.initial_step==3,
		"loading an already-active original career is NOT new complete playthrough")
	o.observe(60.0,state,false,true)
	o.observe(0.5,state,false,false)
	o.observe(0.5,state,true,true)
	check(o.elapsed_active==0.0 and o.excluded_frames==1 and
		o.background_frames==1 and o.menu_frames==1,
		"only playable foreground frames count, paused/long/background frames excluded")
	state["mission"]=4
	o.observe(0.25,state)
	state["mission"]=6
	o.observe(0.25,state)
	var report: Dictionary=o.report()
	check(report["status"]=="unverified" and
		not o.full_run_observed() and
		report["timing_goal_5_to_10_minutes_met"]==null and
		not report["timing_goal_evaluated"],
		"resumed skipped missions cannot prove uncoached full six or 5–10min")
	check(o.skipped_count==1 and o.invariants_hold(),
		"one real multi-step source jump represented honestly without fabricating intermediate actions")
	state["mission"]=0
	o.observe(0.0,state)
	check(o.first_run and o.initial_step==0 and o.events.is_empty() and
		o.start_reason=="load",
		"load/reset into mission zero starts a fresh isolated measurement")
	o.elapsed_active=SESSION.MAX_SECONDS-0.1
	o.observe(0.25,state,false,true)
	check(o.over_budget and o.elapsed_active<=SESSION.MAX_SECONDS,
		"bounded observer cannot produce unlimited analytics data in memory")
	o.begin(state)
	check(o.events.is_empty() and o.elapsed_active==0.0 and
		o.excluded_frames==0 and not o.over_budget,
		"new game clears all prior session counters")
	check(SESSION.actual_step({"mission":-10})==0 and
		SESSION.actual_step({"mission":200})==6,
		"invalid or next-chapter indices cannot inflate six-step verification")
	print("CITY REIGN R177 PRIVATE SESSION HONESTY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
