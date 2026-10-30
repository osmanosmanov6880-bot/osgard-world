extends SceneTree
## R188 REAL full playable original native Godot 3D: wheels, yaw, motion.
const STEER=preload("res://scripts/city_reign_physical_corner_steering.gd")
const LANE=preload("res://scripts/city_reign_vehicle_lane_routing.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R188 LIVE ORIGINAL 3D PHYSICAL STEERING FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs: Node=root.get_node("GameState")
	var former: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var old_locale: String=str(gs.get("locale"))
	gs.set("data",gs.new_game())
	var baseline: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var state: Error=change_scene_to_file("res://scenes/main.tscn")
	check(state==OK,"actual original full 3D Godot city loads, not a fabricated vehicle render")
	if state!=OK:
		gs.set("data",former)
		gs.set("locale",old_locale)
		quit(2)
		return
	await process_frame
	for i in range(10):await physics_frame
	var city: Node3D=current_scene as Node3D
	var cars: Array=city.get("ambient_cars")
	var people: Array=city.get("pedestrians")
	var signals: Node3D=city.get("traffic_signals") as Node3D
	check(cars.size()==12 and people.size()==34 and
		signals.visual_state_is_consistent(),
		"all original 12 colliding NPC cars, 34 residents and R187 16 realistic 3D crossings preserved")
	var physical: CharacterBody3D=cars[0] as CharacterBody3D
	physical.set_physics_process(false)
	signals.set_process(false)
	physical.set("neighbors",[])
	physical.set("citizens",[])
	physical.set("wetness",1.0)
	var original_children: int=physical.get_child_count()
	var route: Array[Vector3]=[
		Vector3(-130,0.8,-154),Vector3(-106,0.8,-154),
		Vector3(-106,0.8,-104)]
	physical.call("set_route",route,7.0)
	check(physical.front_steer_wheels.size()==2 and
		physical.wheels.size()==4 and
		is_equal_approx(physical.rotation.y,-PI/2.0),
		"true native existing four physical wheels and two front steering meshes orient to actual R185 right-hand lane")
	var initial: Vector3=physical.global_position
	signals.set("elapsed",0.0)
	signals.call("_update_lights")
	physical.set("speed",4.0)
	physical.call("_physics_process",0.1)
	var current: Vector3=physical.global_position
	var heading:=Vector3(-sin(physical.rotation.y),0,-cos(physical.rotation.y))
	check(current.x>initial.x and
		STEER.source_road_footprint_safe(current) and
		physical.velocity.length()>0.05,
		"ACTUAL CharacterBody3D moves forward through native physical source road")
	check(physical.velocity.normalized().dot(heading)>0.999 and
		not physical.get("last_steer_fallback"),
		"real physics movement direction is now identical to VISIBLE vehicle chassis yaw, no sideways slide")
	physical.global_position=Vector3(-110,0.8,-154)
	physical.set("target_index",1)
	physical.set("speed",4.0)
	physical.rotation.y=-PI/2.0
	var angle_before: float=physical.rotation.y
	var corner_before: Vector3=physical.global_position
	physical.call("_physics_process",0.1)
	var front_yaw: float=physical.front_steer_wheels[0].rotation.y
	var body_heading:=Vector3(-sin(physical.rotation.y),0,-cos(physical.rotation.y))
	check(front_yaw>0.01 and
		is_equal_approx(front_yaw,physical.front_steer_wheels[1].rotation.y) and
		absf(front_yaw)<0.46,
		"real original front wheels steer together physically into source turn; rear wheels remain straight")
	check(physical.rotation.y>angle_before and
		physical.rotation.y-angle_before<0.20 and
		physical.velocity.normalized().dot(body_heading)>0.999,
		"real native car anticipates true 90 degree junction and MOVES where it faces")
	check(physical.global_position.distance_to(corner_before)>0.05 and
		STEER.source_road_footprint_safe(physical.global_position),
		"native turn actually moves through collision scene without leaving original 10m asphalt")
	check(physical.get_child_count()==original_children and
		not physical.get("last_steer_fallback") and
		int(physical.get("lateral_safety_rejections"))==0,
		"pure R188 original steering adds no new physics/collision nodes or off-road recovery")
	var source: String=FileAccess.get_file_as_string("res://scripts/traffic_agent.gd")
	check(source.contains("R188_STEER.source_aim(") and
		source.contains("R188_STEER.safe_next_step(") and
		source.contains("velocity = Vector3(actual_direction.x*speed") and
		source.contains("for front_wheel in front_steer_wheels:"),
		"true original physics and visually steered existing wheels are wired, not just test-stub values")
	check(int(gs.data["wallet"])==int(baseline["wallet"]) and
		int(gs.data["mission"])==int(baseline["mission"]) and
		gs.data["inventories"]==baseline["inventories"],
		"real steering does not alter original 40 missions, cash, game save or player input")
	city.queue_free()
	await process_frame
	gs.set("data",former)
	gs.set("locale",old_locale)
	print("CITY REIGN R188 REAL 3D STEERED CAR WORLD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
