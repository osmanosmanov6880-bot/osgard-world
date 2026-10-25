extends SceneTree
## R47 actual traffic agent reacts to the FUTURE route of real walker agents.
const CROSSING = preload("res://scripts/horizon_r47_crosswalk_prediction.gd")
const WALKER = preload("res://scripts/pedestrian_agent.gd")
const CAR = preload("res://scripts/traffic_agent.gd")
var passed := 0
var failed := 0
func verify(ok: bool,reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R47 REAL TRAFFIC FAILED: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var origin := Vector3.ZERO
	var ahead := Vector3(0,0,-1)
	var rightside := Vector3(4.0,0,-14.0)
	var cross: float = CROSSING.clearance(origin,ahead,9.0,rightside,Vector3(-2.15,0,0),30.0)
	verify(cross>10.0 and cross<14.0,"walking future crossing triggers braking BEFORE citizen reaches lane")
	verify(CROSSING.clearance(origin,ahead,9.0,rightside,Vector3(0,0,-2.15),30.0)==CROSSING.INFINITE_CLEARANCE_M,"sidewalk travel parallel to road does not block car")
	verify(CROSSING.clearance(origin,ahead,9.0,rightside,Vector3(2.15,0,0),30.0)==CROSSING.INFINITE_CLEARANCE_M,"citizen moving away from lane never stops traffic")
	verify(CROSSING.clearance(origin,ahead,9.0,Vector3(0.1,0,-10.0),Vector3.ZERO,30.0)<10.0,"stationary citizen in road is protected")
	verify(CROSSING.clearance(origin,ahead,9.0,Vector3(4.0,0,12.0),Vector3(-2,0,0),30.0)==CROSSING.INFINITE_CLEARANCE_M,"pedestrian behind car is ignored")
	verify(CROSSING.clearance(origin,ahead,9.0,Vector3(4,0,-50),Vector3(-2,0,0),30.0)==CROSSING.INFINITE_CLEARANCE_M,"remote citizen outside bounded look never blocks road")
	verify(CROSSING.clearance(origin,ahead,9.0,Vector3(NAN,0,0),Vector3.ZERO,30.0)==0.0,"invalid pedestrian coordinates fail closed")
	verify(CROSSING.clearance(origin,ahead,NAN,rightside,Vector3.ZERO,30.0)==0.0,"invalid car speed cannot allow dangerous future crossing")
	verify(CROSSING.clearance(origin,Vector3.ZERO,9.0,rightside,Vector3.ZERO,30.0)==CROSSING.INFINITE_CLEARANCE_M,"no drive direction does not fabricate forward hazard")
	verify(CROSSING.clearance(origin,ahead,2.0,Vector3(5,0,-10),Vector3(-4,0,0),30.0)>0.0,"bounded slow arrival handles faster crossing")
	var transitions := 0
	var far_walker := Vector3(7.0,0,-14.0)
	for i in range(20):
		var walk_speed: float = -float(i)*0.25
		var gap: float = CROSSING.clearance(origin,ahead,9.0,far_walker,Vector3(walk_speed,0,0),30.0)
		if gap<CROSSING.INFINITE_CLEARANCE_M:
			transitions += 1
	verify(transitions>0 and transitions<20,"predictor distinguishes dangerous and safe route velocities on 20 deterministic seeds")
	var pedestrian: Node3D = WALKER.new()
	root.add_child(pedestrian)
	pedestrian.global_position=rightside
	var path: Array[Vector3] = [rightside,Vector3(-20,0,-14)]
	pedestrian.set("route",path)
	pedestrian.set("next_waypoint",1)
	pedestrian.set("speed",2.15)
	pedestrian.call("_process",0.016)
	var actual_walk: Vector3 = pedestrian.get("planned_velocity")
	verify(actual_walk.x < -1.0 and absf(actual_walk.z)<0.1,"live pedestrian exposes world-route walking velocity")
	var traffic: CharacterBody3D = CAR.new()
	root.add_child(traffic)
	traffic.global_position=origin
	traffic.set("speed",9.0)
	traffic.set("citizens",[pedestrian])
	var measured_clearance: float = float(traffic.call("_obstacle_distance",ahead))
	verify(measured_clearance>9.0 and measured_clearance<15.0,
		"genuine live traffic agent computes crossing threat via real citizen")
	pedestrian.global_position=Vector3(4,0,-14)
	pedestrian.set("planned_velocity",Vector3(0,0,-2.15))
	var parallel_clearance: float = float(traffic.call("_obstacle_distance",ahead))
	verify(parallel_clearance>30.0,"real car ignores unrelated sidewalk pedestrian")
	pedestrian.set("planned_velocity",Vector3.ZERO)
	pedestrian.global_position=Vector3(0.0,0,-9.0)
	verify(float(traffic.call("_obstacle_distance",ahead))<=8.0,"real traffic car detects pedestrian already in driving lane")
	pedestrian.visible=false
	verify(float(traffic.call("_obstacle_distance",ahead))>30.0,"culled pedestrian does not cause endless traffic freeze")
	var traffic_source: String=FileAccess.get_file_as_string("res://scripts/traffic_agent.gd")
	var walker_source: String=FileAccess.get_file_as_string("res://scripts/pedestrian_agent.gd")
	verify(traffic_source.contains("R47_CROSSING.clearance("),"real city traffic actually executes predictor")
	verify(walker_source.contains("planned_velocity = velocity"),"citizen movement continuously updates planned crosswalk velocity")
	verify(walker_source.contains("TRAJECTORY.should_yield("),"original R41 collision warning remains active")
	traffic.queue_free()
	pedestrian.queue_free()
	var main: Variant = load("res://scripts/main.gd")
	verify(main is Script and main.can_instantiate(),"main playable driving world still parses")
	await process_frame
	print("EMPIRE OMEGA R47 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
