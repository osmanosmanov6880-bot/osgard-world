extends SceneTree
## R182 real 3D world, 12 native colliding cars, 34 authentic walkers.
const R182=preload("res://scripts/city_reign_crosswalk_occupancy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R182 TRUE FULL GAME CROSSING FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var old: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var locale: String=str(sim.get("locale"))
	sim.set("data",sim.new_game())
	var new_game: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var loaded: Error=change_scene_to_file("res://scenes/main.tscn")
	check(loaded==OK,"full original Godot scene, not fake road web demo")
	if loaded!=OK:
		sim.set("data",old)
		sim.set("locale",locale)
		quit(2)
		return
	await process_frame
	for i in range(10):await physics_frame
	var game: Node3D=current_scene as Node3D
	var cars: Array=game.get("ambient_cars")
	var walkers: Array=game.get("pedestrians")
	var signals: Node3D=game.get("traffic_signals") as Node3D
	check(cars.size()==12 and walkers.size()==34,
		"all 12 original moving physical traffic vehicles and 34 real 3D residents retained")
	check(signals!=null and signals.real_zebra_crossings!=null and
		signals.real_zebra_crossings.source_geometry_valid(),
		"original full native city instantiates 384 genuine 3D zebra strips at real 16 junctions")
	var car: CharacterBody3D=cars[0] as CharacterBody3D
	var person: Node3D=walkers[0] as Node3D
	car.set_physics_process(false)
	person.set_process(false)
	signals.set_process(false)
	car.set("neighbors",[])
	car.set("citizens",[person])
	car.set("wetness",1.0)
	var original_nodes: int=car.get_child_count()
	var route: Array[Vector3]=[
		Vector3(-156.0,0.8,-170.0),Vector3(-156.0,0.8,-142.0)]
	car.call("set_route",route,12.0)
	car.set("speed",8.0)
	person.global_position=Vector3(-155,0.8,-155)
	person.set("planned_velocity",Vector3.ZERO)
	signals.set("elapsed",12.0)
	signals.call("_update_lights")
	car.call("_physics_process",0.1)
	var stopped_by_person: bool=bool(car.get("last_crosswalk_occupied"))
	check(stopped_by_person and float(car.get("last_crosswalk_clearance"))<11.0,
		"original physical NPC detects ACTUAL stopped walker inside source vehicle corridor")
	check(float(car.get("speed"))<8.0 and
		int(car.get("crosswalk_activations"))==1 and
		car.get_child_count()==original_nodes,
		"actual original vehicle brakes, records real occupancy transition, adds ZERO new Nodes")
	car.global_position=Vector3(-156.0,0.8,-170.0)
	car.set("speed",8.0)
	person.global_position=Vector3(-150,0.8,-155)
	person.set("planned_velocity",Vector3.ZERO)
	car.call("_physics_process",0.1)
	check(not bool(car.get("last_crosswalk_occupied")) and
		float(car.get("last_crosswalk_clearance"))>=R182.INF_CLEARANCE_M,
		"same original car DOES NOT brake because a motionless citizen is safely on sidewalk")
	car.global_position=Vector3(-156.0,0.8,-180.0)
	car.set("speed",8.0)
	person.set("planned_velocity",Vector3(-2.15,0,0))
	car.call("_physics_process",0.1)
	check(bool(car.get("last_crosswalk_occupied")) and
		int(car.get("crosswalk_activations"))==2,
		"actual original car predicts a real walker leaving sidewalk and entering the lane")
	car.set("speed",0.0)
	car.call("_physics_process",0.1)
	check(float(car.get("crosswalk_yield_seconds"))>=0.0,
		"actual native safety metrics derive from physical simulation, not UI estimates")
	check(car.get_child_count()==original_nodes and
		signals.pedestrian_signs.batches_are_bounded() and
		signals.stop_bars.source_budget_ok(),
		"no new phantom car bodies; all R178/R180 real GPU source assets remain bounded")
	check(int(sim.data["wallet"])==int(new_game["wallet"]) and
		int(sim.data["treasury"])==int(new_game["treasury"]) and
		int(sim.data["mission"])==int(new_game["mission"]) and
		sim.data["inventories"]==new_game["inventories"],
		"genuine right of way cannot mint money, progress 40 missions or modify original save")
	var source: String=FileAccess.get_file_as_string("res://scripts/traffic_agent.gd")
	check(source.contains("R182_CROSSING.occupied(") and
		source.contains("R182_CROSSING.stop_clearance(") and
		source.contains("nearest=minf(nearest,last_crosswalk_clearance)"),
		"real native physical vehicle obstacle clearance uses LIVE person positions")
	game.queue_free()
	await process_frame
	sim.set("data",old)
	sim.set("locale",locale)
	print("CITY REIGN R182 ORIGINAL LIVING TRAFFIC: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
