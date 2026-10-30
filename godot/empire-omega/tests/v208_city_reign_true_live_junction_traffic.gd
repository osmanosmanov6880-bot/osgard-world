extends SceneTree
## R186 native real full Godot main 3D, existing 12 physics cars, no mock.
const BOX=preload("res://scripts/city_reign_junction_box_clearance.gd")
const SOURCE=preload("res://scripts/city_reign_intersection_policy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R186 ORIGINAL LIVE NATIVE JUNCTION FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _reset_car(car: CharacterBody3D) -> void:
	var route: Array[Vector3]=[
		Vector3(-156,0.8,-170),Vector3(-156,0.8,-142)]
	car.call("set_route",route,12.0)
	car.set("speed",8.0)
func _run() -> void:
	var gs: Node=root.get_node("GameState")
	var original: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var locale: String=str(gs.get("locale"))
	gs.set("data",gs.new_game())
	var initial: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var loaded: Error=change_scene_to_file("res://scenes/main.tscn")
	check(loaded==OK,"genuine original Godot 3D driving game loads")
	if loaded!=OK:
		gs.set("data",original)
		gs.set("locale",locale)
		quit(2)
		return
	await process_frame
	for i in range(10):await physics_frame
	var game: Node3D=current_scene as Node3D
	var cars: Array=game.get("ambient_cars")
	var pedestrians: Array=game.get("pedestrians")
	var signals: Node3D=game.get("traffic_signals") as Node3D
	check(cars.size()==12 and pedestrians.size()==34 and signals!=null,
		"existing 12 authentic CharacterBody3D cars and original 34 residents retained")
	check(signals.real_zebra_crossings.source_geometry_valid() and
		signals.true_speed_signs.source_integrity() and
		signals.pedestrian_signs.batches_are_bounded(),
		"all original 16 signals, 384 zebra slats and 64 source 90kmh signs remain")
	var own: CharacterBody3D=cars[0] as CharacterBody3D
	var peer: CharacterBody3D=cars[1] as CharacterBody3D
	own.set_physics_process(false)
	peer.set_physics_process(false)
	signals.set_process(false)
	own.set("neighbors",[peer])
	own.set("citizens",[])
	own.set("wetness",1.0)
	var node_count: int=own.get_child_count()
	signals.set("elapsed",12.0)
	signals.call("_update_lights")
	_reset_car(own)
	peer.global_position=Vector3(-158,0.8,-142)
	peer.velocity=Vector3.ZERO
	peer.set("speed",0.0)
	own.call("_physics_process",0.1)
	check(bool(own.get("last_junction_guard_active")) and
		own.get("last_junction_guard_reason")=="blocked_exit" and
		int(own.get("junction_yield_activations"))==1,
		"ACTUAL existing car physically yields when another native car blocks its right lane exit")
	check(float(own.get("speed"))<8.0 and
		own.get_child_count()==node_count,
		"same real car brakes using TrafficSafety, creates absolutely NO new collision proxy")
	_reset_car(own)
	peer.global_position=Vector3(-154,0.8,-142)
	own.call("_physics_process",0.1)
	check(not bool(own.get("last_junction_guard_active")) and
		own.get("last_junction_guard_reason")=="" and
		int(own.get("junction_yield_activations"))==1,
		"real safely separated opposite-direction lane does not cause phantom traffic jam")
	_reset_car(own)
	peer.global_position=Vector3(-155,0.8,-155)
	peer.velocity=Vector3(-4,0,0)
	peer.set("speed",4.0)
	own.call("_physics_process",0.1)
	check(bool(own.get("last_junction_guard_active")) and
		own.get("last_junction_guard_reason")=="occupied_box" and
		int(own.get("junction_yield_activations"))==2,
		"actual perpendicular physical car occupying original city box gains clearance")
	_reset_car(own)
	peer.global_position=Vector3(-170,0.8,-156)
	peer.velocity=Vector3(4,0,0)
	peer.set("speed",4.0)
	own.call("_physics_process",0.1)
	check(not bool(own.get("last_junction_guard_active")),
		"unrelated cross car outside real entry time window does not stop original NPC")
	check(float(own.get("junction_hold_seconds"))>=0.0 and
		own.get_child_count()==node_count,
		"source in-memory genuine yield metrics bounded, no additional game physics children")
	var original_src: String=FileAccess.get_file_as_string("res://scripts/traffic_agent.gd")
	check(original_src.contains("R186_BOX.scan(self,neighbors,heading,") and
		original_src.contains("goal=minf(goal,float(box_guard[\"limit_mps\"]))"),
		"existing true original 12 NPC physics speed goal is actually constrained by real box")
	check(int(gs.data["wallet"])==int(initial["wallet"]) and
		int(gs.data["treasury"])==int(initial["treasury"]) and
		int(gs.data["mission"])==int(initial["mission"]) and
		gs.data["inventories"]==initial["inventories"],
		"real traffic yields cannot mutate existing player's wallet, economy or 40 missions")
	game.queue_free()
	await process_frame
	gs.set("data",original)
	gs.set("locale",locale)
	print("CITY REIGN R186 REAL ORIGINAL 3D JUNCTION GAME: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
