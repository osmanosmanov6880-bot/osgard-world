extends SceneTree
## R171: 40 career actions, original side-job priority and bounded real GPS.
const GOAL=preload("res://scripts/city_reign_goal_fabric.gd")
const NAV=preload("res://scripts/horizon_mission_navigation.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R171 OBJECTIVE SOURCE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var career: Node=root.get_node_or_null("MissionManager")
	var cargo: Node=root.get_node_or_null("ContractManager")
	check(sim!=null and career!=null and cargo!=null,"original source autoloads initialized")
	if sim==null or career==null or cargo==null:
		quit(2)
		return
	var state: Dictionary=sim.new_game()
	var backup: Dictionary=state.duplicate(true)
	var offer: Dictionary=cargo.current_offer()
	var loc: Dictionary=cargo.POSITIONS
	var actual_car: Vector3=Vector3(-119,1.3,-105)
	var trial: Vector3=Vector3(-104,1.2,-104)
	var resident: Vector3=loc["market"]
	var service: Vector3=loc["depot"]
	for id in ["enter_vehicle","deliver","contract_accept","contract_deliver","service_accept"]:
		var goal: Dictionary=GOAL.resolve(state,id,offer,loc,actual_car,trial,resident,service)
		check(goal["active"] and GOAL.safe(goal["point"]),
			"real source location for original world mission "+id)
	check(GOAL.resolve(state,"enter_vehicle",offer,loc,actual_car,trial,resident,service)["point"]==actual_car,
		"initial navigation uses REAL moving source car, not hardcoded old save position")
	check(GOAL.resolve(state,"deliver",offer,loc,actual_car,trial,resident,service)["point"]==GOAL.MARKET,
		"physical first courier task leads to real market")
	check(GOAL.resolve(state,"service_accept",offer,loc,actual_car,trial,resident,service)["point"]==GOAL.CITY_HALL,
		"original service dispatcher lives at physical City Hall")
	var actions: Array=[]
	for mission in career.MISSIONS: actions.append(str(mission["id"]))
	check(actions.size()==40,"all forty real career steps remain unchanged")
	for id in actions:
		var objective: Dictionary=GOAL.resolve(state,id,offer,loc,actual_car,trial,resident,service)
		if not NAV.WORLD_ACTIONS.has(id):
			check(not objective["active"],"nonspatial career cannot spoof a physical destination: "+id)
	state["active_contract"]={"dropoff":"market","pickup":"depot"}
	state["service_active"]={"destination":"cityhall"}
	state["neighborhood_active"]={"id":"resident"}
	state["driving_trial"]={"id":"forum_loop"}
	check(GOAL.resolve(state,"business",offer,loc,actual_car,trial,resident,service)["source"]=="trial",
		"original genuine driving trial overrides all side tasks and main menu")
	state["driving_trial"]={}
	check(GOAL.resolve(state,"business",offer,loc,actual_car,trial,resident,service)["source"]=="resident",
		"real resident side job overrides service and cargo")
	state["neighborhood_active"]={}
	check(GOAL.resolve(state,"business",offer,loc,actual_car,trial,resident,service)["source"]=="service",
		"real city assistance overrides active contract")
	state["service_active"]={}
	var freight: Dictionary=GOAL.resolve(state,"business",offer,loc,actual_car,trial,resident,service)
	check(freight["source"]=="freight" and freight["point"]==loc["market"],
		"existing accepted commercial cargo keeps its TRUE physical dropoff")
	state["active_contract"]={}
	var recover: Dictionary=GOAL.resolve(state,"contract_deliver",offer,loc,actual_car,trial,resident,service)
	check(recover["source"]=="recover" and recover["point"]==loc[str(offer["pickup"])],
		"aborted cargo route recovers at real pickup, never fake finished")
	for corrupt in [Vector3(NAN,1,0),Vector3(900,0,0),Vector3.ZERO,Vector3(INF,0,0)]:
		check(not GOAL.safe(corrupt),"nonfinite/foreign/fake waypoint rejected")
	state["driving_trial"]={"id":"forum_loop"}
	check(not GOAL.resolve(state,"deliver",offer,loc,actual_car,Vector3(NAN,0,0),resident,service)["active"],
		"invalid top-priority trial cannot fall through to a phantom lower job")
	for lang in ["ru","en","zh"]:
		check(not GOAL.localized("freight",lang).is_empty(),
			"genuine location guidance localized in "+lang)
	check(state!=backup and sim.new_game()==backup,
		"pure goal model never mutates any original GameState save dictionary")
	print("CITY REIGN R171 SOURCE OBJECTIVES: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
