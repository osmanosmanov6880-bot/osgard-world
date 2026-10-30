extends SceneTree
## R179 genuine original Godot 3D player car and saved patrol citation.
const LAW=preload("res://scripts/city_law.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R179 REAL PLAYER CAR RED LAW FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var old: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var lang: String=str(sim.get("locale"))
	sim.set("data",sim.new_game())
	var original: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var status: Error=change_scene_to_file("res://scenes/main.tscn")
	check(status==OK,"full original game loads, not standalone mocked law UI")
	if status!=OK:
		sim.set("data",old)
		sim.set("locale",lang)
		quit(2)
		return
	await process_frame
	for i in range(8):await physics_frame
	var game: Node3D=current_scene as Node3D
	var car: CharacterBody3D=game.get("car") as CharacterBody3D
	var signal_grid: Node3D=game.get("traffic_signals") as Node3D
	check(car!=null and signal_grid!=null and signal_grid.stop_bars!=null,
		"real original player car shares R178 authentic 16-junction signal source")
	check((game.get("ambient_cars") as Array).size()==12 and
		(game.get("pedestrians") as Array).size()==34,
		"all original 12 NPC vehicles and 34 physical citizens remain")
	car.set_physics_process(false)
	signal_grid.set_process(false)
	game.set("driving",true)
	car.set("speed",8.0)
	car.rotation.y=PI
	car.global_position=Vector3(-156.0,1.3,-165.0)
	signal_grid.set("elapsed",0.1)
	game.call("_sample_true_red_light_law")
	check(int(sim.data["law"]["fine"])==0,
		"first physical sample is NEVER enough evidence to fine a player")
	car.global_position=Vector3(-156.0,1.3,-163.0)
	signal_grid.set("elapsed",0.35)
	game.call("_sample_true_red_light_law")
	check(int(sim.data["law"]["fine"])==115 and
		int(sim.data["law"]["heat"])==1 and
		sim.data["law"]["history"][0]["type"]=="red_light",
		"actual native moving player's car incurs ONE original lawful red signal event")
	check(LAW.valid(sim.data["law"],int(sim.data["turn"])) and
		int(sim.data["wallet"])==int(original["wallet"]),
		"real signed source citation uses authentic existing JSON law save schema")
	sim.data["law"]=LAW.initial()
	game.set("red_law_previous_at",Vector3.INF)
	game.set("red_law_previous_clock",-1.0)
	car.rotation.y=-PI/2
	car.global_position=Vector3(-165.0,1.3,-156.0)
	signal_grid.set("elapsed",10.7)
	game.call("_sample_true_red_light_law")
	car.global_position=Vector3(-163.0,1.3,-156.0)
	signal_grid.set("elapsed",10.9)
	game.call("_sample_true_red_light_law")
	check(int(sim.data["law"]["fine"])==0 and
		int(sim.data["law"]["infractions"])==0,
		"same real moving car on physical amber cannot be unfairly ticketed")
	game.set("driving",false)
	game.call("_sample_true_red_light_law")
	check(game.red_law_previous_clock<0 and
		not game.red_law_previous_at.is_finite(),
		"leaving actual car resets previous red-signal sample to avoid teleport false positives")
	var main_src: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_src.contains("_sample_true_red_light_law()") and
		main_src.contains("register_traffic_offence(\"red_light\")"),
		"4Hz real game scene directly invokes original GameState law, not a mock citation")
	check(int(sim.data["treasury"])==int(original["treasury"]) and
		int(sim.data["mission"])==int(original["mission"]) and
		sim.data["inventories"]==original["inventories"],
		"physical legal evidence changes no economy, inventory or 40-mission progress")
	game.queue_free()
	await process_frame
	sim.set("data",old)
	sim.set("locale",lang)
	print("CITY REIGN R179 REAL 3D SIGNAL CITATION: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
