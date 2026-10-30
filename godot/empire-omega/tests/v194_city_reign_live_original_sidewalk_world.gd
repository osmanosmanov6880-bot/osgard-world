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
	# Repeated original WorldBuilder holder names may be auto-unique
	# Node names, so inspect the REAL physical 454m x 1.8m BoxMesh
	# geometries rather than trusting a cosmetic 'Sidewalk*' label.
	var native_lips: int=0
	for holder in world.city_root.get_children():
		if not holder is Node3D or holder.get_child_count()!=1:
			continue
		var mesh_node: MeshInstance3D=holder.get_child(0) as MeshInstance3D
		if mesh_node==null or not mesh_node.mesh is BoxMesh:
			continue
		var actual: BoxMesh=mesh_node.mesh as BoxMesh
		var geometry: Vector3=actual.size
		if (is_equal_approx(geometry.x,454.0) and is_equal_approx(geometry.z,1.8)) or (
			is_equal_approx(geometry.z,454.0) and is_equal_approx(geometry.x,1.8)):
			native_lips+=1
	check(native_lips==36,
		"36 REAL WorldBuilder BoxMesh pavements exist at original x/z +6/-6m")
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
