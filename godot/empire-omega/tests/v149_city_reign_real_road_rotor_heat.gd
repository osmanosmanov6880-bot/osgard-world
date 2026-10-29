extends SceneTree
## R166 physical CharacterBody3D drives rotor materials only from measured
## real slowing on a real Godot collider. Never modify original car physics.
const CAR = preload("res://scripts/vehicle_controller.gd")
const THERMAL = preload("res://scripts/city_reign_rotor_thermal.gd")
var passed:=0
var failed:=0

func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R166 REAL ROTOR FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node=root.get_node_or_null("GameState")
	var prior_state: Dictionary=(game.get("data") as Dictionary).duplicate(true)
	var ground := StaticBody3D.new()
	ground.collision_layer=1
	ground.position=Vector3(0,-0.3,0)
	var ground_shape := CollisionShape3D.new()
	var road := BoxShape3D.new()
	road.size=Vector3(200,0.6,200)
	ground_shape.shape=road
	ground.add_child(ground_shape)
	root.add_child(ground)
	var car: CharacterBody3D=CAR.new()
	car.position=Vector3(0,0.86,0)
	root.add_child(car)
	car.driving=true
	var shell: Node3D=car.horizon_visual
	var details: Array=shell.wheel_detail_nodes
	check(details.size()==4 and car.collision_layer==4,
		"original physical player car has exactly four existing premium brake rotor packs")
	var front: Node3D=details[0]
	var rear: Node3D=details[1]
	var front_rotor: MeshInstance3D=front.rotor
	var old_mesh: Mesh=front_rotor.mesh
	Input.action_press("move_forward")
	for i in range(112): await physics_frame
	Input.action_release("move_forward")
	var at_speed: float=car.speed
	check(at_speed>9.0 and car.rotor_heat==Vector2.ZERO,
		"real game acceleration alone cannot spawn fake glowing brake rotors")
	Input.action_press("move_backward")
	for i in range(38): await physics_frame
	Input.action_release("move_backward")
	var current: Vector2=car.rotor_heat
	var hue: StandardMaterial3D=front_rotor.material_override as StandardMaterial3D
	check(car.speed<at_speed-2.0 and car.brake_response>0.90,
		"genuine old vehicle decelerates on real driver brake input")
	check(THERMAL.valid(current) and current.x>0.25 and current.x>current.y,
		"measured four-wheel supported brake energy warms front rotors more")
	check(front.normalized_heat>0.25 and rear.normalized_heat>0.02,
		"all actual wheel packs consume front/rear energy, not a DOM imitation")
	check(hue.emission_enabled and hue.emission_energy_multiplier>0.05,
		"original brake rotor physically glows through its own 3D material")
	check(front_rotor.mesh==old_mesh and front.get_child_count()==3,
		"no extra mesh, light, or visual object allocated during real braking")
	for i in range(90): await physics_frame
	check(car.rotor_heat.x<current.x and
		car.rotor_heat.y<current.y,"rotors physically cool when driver releases brakes")
	shell.set_detail_quality("low")
	check(not front.rotor.visible and not rear.rotor.visible,
		"LOW budget hides brake rotor even when heat is still tracked")
	shell.set_detail_quality("cinematic")
	check(front.rotor.visible and front_rotor.mesh==old_mesh,
		"graphics tier restores SAME material and mesh without reallocation")
	check(game.get("data")==prior_state,
		"rotor visuals do not alter campaign, save, wallet or city economic authority")
	var source: String=FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
	check(source.contains("ROTOR_THERMAL.step(") and
		source.contains('horizon_visual.call("sync_rotor_heat",rotor_heat)'),
		"the original source scene drives genuine 3D brake discs")
	car.driving=false
	car.queue_free()
	ground.queue_free()
	await process_frame
	print("CITY REIGN R166 REAL BRAKE ROAD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
