extends SceneTree
## R70: test the actual new-game vehicle on the real generated street, not
## an empty physics room. Guards against the original City Hall portico crash.
# --script is parsed before the project autoload is fully registered. The
# eager WORLD preload previously failed to resolve GameState in world_builder.gd.
# Resolve both original game scripts after _initialize, when the real autoloads
# are alive; this does not mock or replace any scene/physics code.
const WORLD_PATH = "res://scripts/world_builder.gd"
const CAR_PATH = "res://scripts/vehicle_controller.gd"
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R70 REAL CITY START DRIVE FAILED: " + label)

func _initialize() -> void:
	call_deferred("_run")

func wait_frames(count: int) -> void:
	for i in range(count):
		await physics_frame

func _run() -> void:
	var gs: Node = root.get_node_or_null("GameState")
	check(gs != null,"original GameState autoload present")
	if gs == null:
		quit(1)
		return
	var old_state: Dictionary = gs.get("data").duplicate(true)
	var data: Dictionary = gs.call("new_game")
	gs.set("data",data)
	var coords: Array = data["vehicle_position"]
	var spawn: Vector3 = Vector3(float(coords[0]),float(coords[1]),float(coords[2]))
	var heading: float = float(data["vehicle_heading"])
	check(is_equal_approx(spawn.z,-104.0),"vehicle spawns on real east-west road z=-104")
	check(is_equal_approx(heading,PI*0.5),"new cars face west along road, away from palace portico")
	check(bool(gs.call("_valid_state",data)),"new game with road-facing heading remains save valid")

	var world_script: Script = load(WORLD_PATH) as Script
	var car_script: Script = load(CAR_PATH) as Script
	check(world_script != null and world_script.can_instantiate(),
		"original world compiles after GameState autoload is registered")
	check(car_script != null and car_script.can_instantiate(),
		"original CharacterBody3D car script compiles")
	if world_script == null or car_script == null:
		gs.set("data",old_state)
		quit(1)
		return
	if not world_script.can_instantiate() or not car_script.can_instantiate():
		gs.set("data",old_state)
		quit(1)
		return
	var world: Node3D = world_script.new() as Node3D
	root.add_child(world)
	var car: CharacterBody3D = car_script.new() as CharacterBody3D
	root.add_child(car)
	check(world != null and car != null,"real original Godot world and car instantiated")
	if world == null or car == null:
		gs.set("data",old_state)
		quit(1)
		return
	car.global_position = spawn
	car.rotation.y = heading
	car.driving = true
	await wait_frames(8)
	var before: Vector3 = car.global_position
	var before_mileage: float = float(car.get("mileage"))
	Input.action_press("move_forward")
	await wait_frames(65)
	var moving_position: Vector3 = car.global_position
	var running_speed: float = float(car.get("speed"))
	var running_miles: float = float(car.get("mileage")) - before_mileage
	check(running_speed>3.0,"actual car accelerates >3 m/s on first public road")
	check(moving_position.distance_to(before)>2.5,"first launch drives >2.5 m in real city geometry")
	check(running_miles>2.5,"distance comes from actual CharacterBody3D physics")
	check(car.global_position.z>-112.0 and car.global_position.z< -96.0,
		"road-facing start remains on open east-west street, no collision with palace")
	var first_heading: float = car.rotation.y
	Input.action_press("move_left")
	await wait_frames(55)
	check(Input.is_action_pressed("move_forward") and Input.is_action_pressed("move_left"),
		"real InputMap delivers simultaneously held gas and steering")
	check(absf(car.rotation.y-first_heading)>0.08,
		"real car rotates on west-facing road during simultaneous steer")
	check(float(car.get("mileage"))>before_mileage+5.0,
		"car continues growing authoritative odometer after turning")
	Input.action_release("move_left")
	Input.action_release("move_forward")
	check(car.global_position.distance_to(before)>5.0,
		"post-action car genuinely left starting space")
	var original_state: Dictionary = gs.get("data")
	check(bool(gs.call("_valid_state",original_state)),
		"new game remains valid, no mission/economy edited by test")
	car.queue_free()
	world.queue_free()
	gs.set("data",old_state)
	await process_frame
	print("EMPIRE OMEGA R70 REAL FIRST STREET DRIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
