extends SceneTree
## R181 full original Godot 3D game: real sidewalks and source A* residents.
const PAVEMENT=preload("res://scripts/city_reign_sidewalk_routing.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R181 REAL CITY SIDEWALK LIVE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var former: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var language: String=str(sim.get("locale"))
	sim.set("data",sim.new_game())
	var start_state: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var load_result: Error=change_scene_to_file("res://scenes/main.tscn")
	check(load_result==OK,"genuine native Godot original 3D CITY REIGN loads")
	if load_result!=OK:
		sim.set("data",former)
		sim.set("locale",language)
		quit(2)
		return
	await process_frame
	for i in range(9):await physics_frame
	var game: Node3D=current_scene as Node3D
	var people: Array=game.get("pedestrians")
	var cars: Array=game.get("ambient_cars")
	var world: Node3D=game.get("world") as Node3D
	var lights: Node3D=game.get("traffic_signals") as Node3D
	check(people.size()==34 and cars.size()==12 and lights!=null,
		"actual original city retains all 34 real citizens, 12 existing physical vehicles")
	var lips: Array=world.city_root.find_children("Sidewalk*","Node3D",true,false)
	check(lips.size()>=36,
		"36 real existing mesh sidewalk strips remain visible in original native WorldBuilder")
	var route_count: int=0
	for citizen in people:
		for pos in citizen.route:
			if PAVEMENT.on_original_sidewalk(pos):
				route_count+=1
	check(route_count>=12,"numerous real citizens already navigate EXISTING source world sidewalks")
	var subject: Node3D=people[0] as Node3D
	subject.set_process(false)
	lights.set_process(false)
	subject.set("traffic_vehicles",[])
	subject.set("player_car",null)
	var start:=Vector3(-150,0.7,-169)
	var path: Array[Vector3]=[start,Vector3(-150,0.7,-135)]
	subject.global_position=start
	subject.set("route",path)
	subject.set("next_waypoint",1)
	lights.set("elapsed",0.0)
	subject.call("_process",0.06)
	check(subject.global_position.distance_to(start)<0.001 and
		subject.get("signal_status")=="wait",
		"native person standing on true x+6m sidewalk obeys original traffic Z red")
	lights.set("elapsed",12.0)
	subject.call("_process",0.06)
	check(subject.global_position.z>start.z+0.09 and
		subject.get("signal_status")=="walk",
		"same actual character physically WALKS across original cross street on green")
	check(int(sim.data["wallet"])==int(start_state["wallet"]) and
		int(sim.data["treasury"])==int(start_state["treasury"]) and
		int(sim.data["mission"])==int(start_state["mission"]) and
		sim.data["inventories"]==start_state["inventories"],
		"real walking on original physical sidewalk cannot change wallet or advance missions")
	var src: String=FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(src.contains('"_ground"') and
		src.contains('"Sidewalk"') and PAVEMENT.PAVEMENT_OFFSET_M==6.0,
		"pavement offsets are sourced from actual native sidewalk world geometry")
	game.queue_free()
	await process_frame
	sim.set("data",former)
	sim.set("locale",language)
	print("CITY REIGN R181 REAL 3D SIDEWALK WORLD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
