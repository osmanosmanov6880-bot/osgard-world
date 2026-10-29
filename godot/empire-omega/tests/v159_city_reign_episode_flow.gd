extends SceneTree
## R170 pure source-truth 6-step episode projection, RU/EN/ZH and save recovery.
const EP=preload("res://scripts/city_reign_episode_sequence.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R170 EPISODE FLOW FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var mission: Node=root.get_node_or_null("MissionManager")
	var contract: Node=root.get_node_or_null("ContractManager")
	check(sim!=null and mission!=null and contract!=null,"real original authority autoloads")
	if sim==null or mission==null or contract==null:
		quit(2)
		return
	var untouched: Dictionary=sim.data.duplicate(true)
	var state: Dictionary=sim.new_game()
	var offer: Dictionary=contract.current_offer()
	# The native offer reads GameState. Use an actual offer after temporary
	# state assignment, then restore without writing user:// save files.
	sim.data=state
	offer=contract.current_offer()
	var original: Dictionary=state.duplicate(true)
	for lang in ["ru","en","zh"]:
		for stage in range(EP.TOTAL_STEPS):
			state["mission"]=stage
			var actual: Dictionary=EP.first_six(state,offer,contract.POSITIONS,lang)
			check(actual["step"]==stage+1 and actual["total"]==6 and
				actual["action"]==mission.MISSIONS[stage]["id"] and not actual["completed"],
				"every original campaign action matches authentic episode step "+str(stage)+"/"+lang)
			check(not str(actual["heading"]).is_empty() and
				not str(actual["hint"]).is_empty() and not str(actual["body"]).is_empty(),
				"human-language instructions for "+lang+" / "+str(stage))
			check(bool(actual["goal_available"]) and
				(actual["goal"] as Vector3).is_finite(),
				"all six steps have physically real finite source coordinates")
		state["mission"]=6
		var done: Dictionary=EP.first_six(state,offer,contract.POSITIONS,lang)
		check(done["completed"] and done["action"]=="" and not done["goal_available"] and
			done["progress"]=="6/6","first actual complete original chapter is acknowledged, no further fake objective")
	state["mission"]=5
	state["active_contract"]={}
	var missing: Dictionary=EP.first_six(state,offer,contract.POSITIONS,"en")
	check(missing["status"]=="recover" and
		missing["goal"]==contract.POSITIONS[str(offer["pickup"])],
		"aborted original delivery recovers by actually travelling to live pickup")
	state["active_contract"]=offer.duplicate(true)
	var delivering: Dictionary=EP.first_six(state,offer,contract.POSITIONS,"en")
	check(delivering["status"]=="active" and
		delivering["goal"]==contract.POSITIONS[str(offer["dropoff"])],
		"live accepted cargo switches exact goal to authoritative dropoff")
	state["driving_trial"]={"id":"forum_loop"}
	check(EP.first_six(state,offer,contract.POSITIONS,"en")["status"]=="trial",
		"active original physical trial takes priority over career hints")
	state["mission"]=0
	state["driving_trial"]={}
	state["vehicle_position"]=[NAN,1.3,INF]
	check(not EP.first_six(state,offer,contract.POSITIONS,"en")["goal_available"],
		"nonfinite saved coordinates cannot create unsafe fake world markers")
	check(EP.local("it")==EP.local("en"),"unsupported locale gracefully falls back")
	sim.data=untouched
	check(original.size()==untouched.size() and
		EP.EXPECTED_ACTIONS.size()==6,
		"episode projection adds ZERO new mission/save keys")
	print("CITY REIGN R170 EPISODE FLOW: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
