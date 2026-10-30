extends SceneTree
## R185 actual 3D full original game, 12 cars under real TrafficSafety.
const LANE=preload("res://scripts/city_reign_vehicle_lane_routing.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R185 ORIGINAL PHYSICAL TRAFFIC CITY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var state: Node=root.get_node("GameState")
	var original_state: Dictionary=(state.get("data") as Dictionary).duplicate(true)
	var original_locale: String=str(state.get("locale"))
	state.set("data",state.new_game())
	var budget: Dictionary=(state.get("data") as Dictionary).duplicate(true)
	var loaded: Error=change_scene_to_file("res://scenes/main.tscn")
	check(loaded==OK,"R185 original Godot playable 3D city actually loads")
	if loaded!=OK:
		state.set("data",original_state)
		state.set("locale",original_locale)
		quit(2)
		return
	await process_frame
	for i in range(9):await physics_frame
	var world: Node3D=current_scene as Node3D
	var npc: Array=world.get("ambient_cars")
	var residents: Array=world.get("pedestrians")
	var signals: Node3D=world.get("traffic_signals") as Node3D
	var own_car: CharacterBody3D=world.get("car") as CharacterBody3D
	check(npc.size()==12 and residents.size()==34 and own_car!=null,
		"ALL 12 existing collider NPC cars, 34 physical residents and original playable player vehicle kept")
	check(signals.true_speed_signs.source_integrity() and
		signals.real_zebra_crossings.source_geometry_valid() and
		signals.pedestrian_signs.batches_are_bounded(),
		"all R184 real road signs, R182 physical zebra and R180 WALK/WAIT meshes retained")
	var initial_positions: Array[Vector3]=[]
	var starting_speeds: Array[float]=[]
	var source_lane_segments: int=0
	for n in range(npc.size()):
		var car: CharacterBody3D=npc[n] as CharacterBody3D
		initial_positions.append(car.global_position)
		starting_speeds.append(float(car.get("speed")))
		var path: Array[Vector3]=car.get("points")
		var original_path: Array[Vector3]=world.call("_road_loop",n)
		check(path==original_path and path.size()>4 and
			car.get_child(0) is CollisionShape3D,
			"real NPC retains original collider and authentic closure-aware A* right-lane loop")
		for k in range(path.size()-1):
			if LANE.on_right_lane(path[k],path[k+1]-path[k]):
				source_lane_segments+=1
	check(source_lane_segments>=24 and LANE.source_integrity(),
		"dozens of ORIGINAL vehicle source points now follow right-hand asphalt, not centreline")
	var first: CharacterBody3D=npc[0] as CharacterBody3D
	var first_route: Array[Vector3]=first.get("points")
	check(first_route[1].x>first_route[0].x and
		LANE.on_right_lane(first_route[0],first_route[1]-first_route[0]),
		"real first playable traffic vehicle starts FORWARD on lawful lane, no initial 2m backwards motion")
	world.call("_replan_traffic")
	var unchanged: bool=true
	for n in range(npc.size()):
		var car: CharacterBody3D=npc[n] as CharacterBody3D
		if car.global_position.distance_to(initial_positions[n])>0.001 or (
				absf(float(car.get("speed"))-starting_speeds[n])>0.001):
			unchanged=false
	check(unchanged,
		"real roadwork reroute NEVER teleports or resets momentum of an already moving NPC")
	check(int(state.data["wallet"])==int(budget["wallet"]) and
		int(state.data["treasury"])==int(budget["treasury"]) and
		int(state.data["mission"])==int(budget["mission"]) and
		state.data["inventories"]==budget["inventories"],
		"road lane discipline changes no saved mission, lawful fine, currency or inventory")
	world.queue_free()
	await process_frame
	state.set("data",original_state)
	state.set("locale",original_locale)
	print("CITY REIGN R185 ORIGINAL 3D RIGHT-HAND TRAFFIC: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
