extends SceneTree
## R180 original main scene, same 34 actual moving walking residents.
const AGENT=preload("res://scripts/pedestrian_agent.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,reason: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R180 REAL CITY CROSSING FAIL: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var old: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var locale: String=str(sim.get("locale"))
	sim.set("data",sim.new_game())
	var source: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var result: Error=change_scene_to_file("res://scenes/main.tscn")
	check(result==OK,"original existing full 3D playable Godot main.tscn actually loads")
	if result!=OK:
		sim.set("data",old)
		sim.set("locale",locale)
		quit(2)
		return
	await process_frame
	for i in range(9):await physics_frame
	var game: Node3D=current_scene as Node3D
	var people: Array=game.get("pedestrians")
	var cars: Array=game.get("ambient_cars")
	var signals: Node3D=game.get("traffic_signals") as Node3D
	check(people.size()==34 and cars.size()==12,
		"same source original city has exactly 34 visible pedestrians and 12 collision-capable NPC cars")
	check(signals!=null and signals.pedestrian_signs!=null and
		bool(signals.pedestrian_signs.call("batches_are_bounded")),
		"true original 16-intersection WALK/WAIT 3D art exists in actual city")
	var citizen: Node3D=people[0] as Node3D
	citizen.set_process(false)
	signals.set_process(false)
	citizen.set("traffic_vehicles",[])
	citizen.set("player_car",null)
	check(citizen.signal_controller==signals and
		citizen.get_child_count()==1 and citizen.get_child(0) is MeshInstance3D,
		"real source street agent shares correct signal timer and retains one lightweight mesh")
	var at:=Vector3(-156,0.7,-169)
	var route: Array[Vector3]=[at,Vector3(-156,0.7,-130)]
	citizen.global_position=at
	citizen.set("route",route)
	citizen.set("next_waypoint",1)
	citizen.set("speed",2.15)
	signals.set("elapsed",0.0)
	citizen.call("_process",0.06)
	check(citizen.global_position.distance_to(at)<0.001 and
		citizen.get("signal_status")=="wait" and
		(citizen.get("planned_velocity") as Vector3).length()<0.001,
		"actual 3D resident stands physically still on source RED instead of ghost walking")
	signals.set("elapsed",12.0)
	citizen.call("_process",0.06)
	check(citizen.global_position.z>at.z+0.09 and
		citizen.get("signal_status")=="walk" and
		(citizen.get("planned_velocity") as Vector3).z>1.0,
		"same true walking citizen resumes physical trip when original 24s signal permits")
	signals.set("elapsed",18.6)
	citizen.global_position=at
	citizen.call("_process",0.06)
	check(citizen.global_position.distance_to(at)<0.001 and
		citizen.get("signal_status")=="wait",
		"late vehicle green no longer strands pedestrian inside original crossing")
	signals.set("elapsed",0.0)
	citizen.global_position=Vector3(-156,0.7,-163.5)
	citizen.call("_process",0.06)
	check(citizen.global_position.z>-163.49,
		"walker already INSIDE junction may clear on red instead of getting stuck")
	var src: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	var agent: String=FileAccess.get_file_as_string("res://scripts/pedestrian_agent.gd")
	check(src.contains("citizen.signal_controller = traffic_signals") and
		agent.contains("R180_CROSSWALK.permission(") and
		agent.contains("planned_velocity=Vector3.ZERO"),
		"actual source main scene—not fake facade—gates native citizen velocity")
	check(int(sim.data["wallet"])==int(source["wallet"]) and
		int(sim.data["treasury"])==int(source["treasury"]) and
		int(sim.data["mission"])==int(source["mission"]) and
		sim.data["inventories"]==source["inventories"],
		"true pedestrian right-of-way cannot invent money or finish the 40 missions")
	game.queue_free()
	await process_frame
	sim.set("data",old)
	sim.set("locale",locale)
	print("CITY REIGN R180 NATIVE 3D WALKING CITY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
