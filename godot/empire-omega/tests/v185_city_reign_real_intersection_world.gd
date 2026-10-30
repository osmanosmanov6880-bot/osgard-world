extends SceneTree
## R178 TRUE playable 3D city: original physical NPC braking + driver cues.
const RULE=preload("res://scripts/city_reign_intersection_policy.gd")
const SENSE=preload("res://scripts/city_reign_driver_awareness.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R178 REAL ROAD-GAME INTEGRATION FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var old: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var old_locale: String=str(sim.get("locale"))
	sim.set("data",sim.new_game())
	var start: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var status: Error=change_scene_to_file("res://scenes/main.tscn")
	check(status==OK,"source original playable game loads in real native Godot")
	if status!=OK:
		sim.set("data",old)
		sim.set("locale",old_locale)
		quit(2)
		return
	await process_frame
	for i in range(10):await physics_frame
	var game: Node3D=current_scene as Node3D
	var signals: Node3D=game.get("traffic_signals")
	var road: Node3D=signals.get("stop_bars") as Node3D
	var agents: Array=game.get("ambient_cars")
	var people: Array=game.get("pedestrians")
	check(signals!=null and road!=null and bool(road.call("source_budget_ok")),
		"R178 in same original world uses true signal network and real 3D road paint")
	check(agents.size()==12 and people.size()==34,
		"12 original physically colliding NPC vehicles and 34 pedestrians retained")
	var car: CharacterBody3D=agents[0] as CharacterBody3D
	car.set_physics_process(false)
	car.set("citizens",[])
	car.set("neighbors",[])
	car.set("wetness",1.0)
	car.set("signal_controller",signals)
	var route: Array[Vector3]=[
		Vector3(-156.0,0.8,-169.0),Vector3(-156.0,0.8,-142.0)]
	car.call("set_route",route,12.0)
	signals.set("elapsed",0.0)
	signals.call("_update_lights")
	car.set("speed",8.0)
	car.call("_physics_process",0.1)
	var stopped_speed: float=float(car.get("speed"))
	var red_limit: float=float(car.get("last_signal_speed"))
	check(car.get("last_signal_phase")=="red" and red_limit<8.0 and stopped_speed<8.0,
		"actual original native NPC brakes physically BEFORE real red approach")
	signals.set("elapsed",12.0)
	signals.call("_update_lights")
	car.global_position=Vector3(-156.0,0.8,-169.0)
	car.set("speed",8.0)
	car.call("_physics_process",0.1)
	var green_limit: float=float(car.get("last_signal_speed"))
	var green_speed: float=float(car.get("speed"))
	check(car.get("last_signal_phase")=="green" and green_limit>red_limit and
		green_speed>=stopped_speed,
		"same genuine moving NPC resumes real traffic progress on Z green")
	var signal: Dictionary=RULE.driver_warning(Vector3(-156,1.3,-169),PI,9.0,0.0)
	check(signal.get("phase")=="red" and
		SENSE.localized(signal,"ru").contains("КРАСНЫЙ") and
		SENSE.localized(signal,"en").contains("RED") and
		SENSE.localized(signal,"zh").contains("红灯"),
		"source-powered true driver signal warning in three real locales")
	var main_src: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	var traffic_src: String=FileAccess.get_file_as_string("res://scripts/traffic_agent.gd")
	var walker_src: String=FileAccess.get_file_as_string("res://scripts/pedestrian_agent.gd")
	check(main_src.contains("R178_SIGNAL.driver_warning(") and
		traffic_src.contains("R178_SIGNAL.speed_cap(") and
		walker_src.contains("planned_velocity=Vector3.ZERO"),
		"real source traffic, genuine driver and pedestrian waiting all connected")
	check(int(sim.data["wallet"])==int(start["wallet"]) and
		int(sim.data["mission"])==int(start["mission"]) and
		sim.data["inventories"]==start["inventories"],
		"right of way cannot mint money, move missions or alter original production")
	game.queue_free()
	await process_frame
	sim.set("data",old)
	sim.set("locale",old_locale)
	print("CITY REIGN R178 PHYSICAL REAL ROAD GAME: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
