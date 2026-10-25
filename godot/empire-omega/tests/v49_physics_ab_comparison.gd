extends SceneTree
## HORIZON R24 A/B. Both vehicles drive the same flat test world with the
## same input phase durations. Results are diagnostic, not parity claims.
const ARCADE = preload("res://scripts/vehicle_controller.gd")
const FORCE = preload("res://labs/r24_four_wheel_rigidbody.gd")
var passed := 0
var failed := 0

func verify(value: bool, label: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("R24 A/B FAILED: "+label)

func _initialize() -> void:
	call_deferred("_run")

func _horizontal(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

func _write_metrics(data: Dictionary) -> void:
	var out: FileAccess = FileAccess.open("res://tests/r24-comparison.json",FileAccess.WRITE)
	if out == null:
		verify(false,"comparison report file must open")
		return
	out.store_string(JSON.stringify(data,"  "))
	out.close()

func _run() -> void:
	var road := StaticBody3D.new()
	road.collision_layer=1
	road.name="A_B_PhysicsRoad"
	road.position=Vector3(0,-0.30,0)
	var shape_node:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(300,0.60,300)
	shape_node.shape=shape
	road.add_child(shape_node)
	root.add_child(road)
	var arcade: CharacterBody3D=ARCADE.new()
	arcade.position=Vector3(-12,1.18,0)
	root.add_child(arcade)
	arcade.driving=false
	var force: RigidBody3D=FORCE.new()
	force.position=Vector3(12,1.08,0)
	root.add_child(force)
	for i in range(140):
		await physics_frame
	verify(force.grounded_wheels>=2,"force vehicle settles on real grounded springs")
	verify(is_zero_approx(float(arcade.get("speed"))),"original car starts stationary")
	var arcade_initial: Vector3=arcade.global_position
	var force_initial: Vector3=force.global_position
	arcade.driving=true
	arcade.traction_factor=1.0
	force.road_grip=1.0
	force.command_drive=0.72
	Input.action_press("move_forward")
	for i in range(120):
		await physics_frame
	Input.action_release("move_forward")
	var arcade_distance: float=_horizontal(arcade_initial,arcade.global_position)
	var force_distance: float=_horizontal(force_initial,force.global_position)
	var old_speed: float=absf(arcade.speed)
	var real_speed: float=absf(force.measured_forward_speed)
	verify(arcade_distance>1.0 and force_distance>1.0,"both engines move when issued positive drive input")
	verify(old_speed>0.4 and real_speed>0.4,"both systems register driving speed")
	var arcade_yaw_start: float=arcade.rotation.y
	var force_yaw_start: float=force.rotation.y
	arcade.traction_factor=0.8
	force.road_grip=0.8
	Input.action_press("move_left")
	force.command_steer=0.7
	for i in range(85):
		await physics_frame
	Input.action_release("move_left")
	force.command_drive=0.0
	force.command_steer=0.0
	var arcade_turn: float=absf(wrapf(arcade.rotation.y-arcade_yaw_start,-PI,PI))
	var force_turn: float=absf(wrapf(force.rotation.y-force_yaw_start,-PI,PI))
	verify(arcade_turn>0.015 and force_turn>0.015,"both cars respond to turn command")
	verify(is_finite(force.global_position.y) and is_finite(arcade.global_position.y),"both physics states remain finite")
	var arcade_before_brake: float=absf(arcade.speed)
	var force_before_brake: float=Vector2(force.linear_velocity.x,force.linear_velocity.z).length()
	Input.action_press("move_backward")
	force.command_brake=1.0
	for i in range(100):
		await physics_frame
	Input.action_release("move_backward")
	var arcade_after_brake: float=absf(arcade.speed)
	var force_after_brake: float=Vector2(force.linear_velocity.x,force.linear_velocity.z).length()
	verify(arcade_after_brake<arcade_before_brake,"existing arcade car retains reverse-as-brake behavior")
	verify(force_after_brake<force_before_brake,"new rigid-body brakes reduce actual velocity")
	verify(arcade.health>0.0 and arcade.fuel>0.0,"existing game still retains damage/fuel logic")
	verify(arcade.collision_layer==4 and force.collision_layer==4,"both bodies use compatible collision layers")
	var data: Dictionary={
		"engine":"Godot 4.4.1",
		"experiment":"HORIZON R24 force vs current arcade dynamics",
		"scope":"same flat road and input phase durations; not calibrated physical comparison",
		"drive_frames":120,
		"turn_frames":85,
		"brake_frames":100,
		"road_grip_dry":1.0,
		"road_grip_corner":0.8,
		"physical_phone_test":false,
		"arcade":{
			"forward_distance_m":arcade_distance,
			"forward_speed_mps":old_speed,
			"turn_radians":arcade_turn,
			"brake_speed_before_mps":arcade_before_brake,
			"brake_speed_after_mps":arcade_after_brake
		},
		"force_body":{
			"forward_distance_m":force_distance,
			"forward_speed_mps":real_speed,
			"turn_radians":force_turn,
			"brake_speed_before_mps":force_before_brake,
			"brake_speed_after_mps":force_after_brake,
			"supported_wheels_final":force.grounded_wheels
		},
		"checks_passed":passed,
		"checks_failed":failed
	}
	_write_metrics(data)
	arcade.driving=false
	force.command_brake=0.0
	arcade.queue_free()
	force.queue_free()
	road.queue_free()
	print("HORIZON R24 A/B: %d checks passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
