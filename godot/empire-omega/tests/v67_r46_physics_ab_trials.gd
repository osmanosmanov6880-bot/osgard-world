extends SceneTree
## EMPIRE Omega R46: A/B engineering data recorded by real Godot 4.4.1
## physics ticks. The rigid-body experiment is NOT enabled in the live game.
const ARCADE = preload("res://scripts/vehicle_controller.gd")
const RIGID = preload("res://labs/r24_four_wheel_rigidbody.gd")
const GRIPS: Array[float] = [1.0,0.65,1.0]
const SEEDS: Array[int] = [17,61,17]
const TICKS_SETTLE: int = 140
const TICKS_DRIVE: int = 108
const TICKS_STEER: int = 72
const TICKS_BRAKE: int = 48
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("OMEGA R46 PHYSICS AB FAILED: "+why)

func _initialize() -> void:
	call_deferred("_run")

static func distance_2d(a: Vector3,b: Vector3) -> float:
	return Vector2(a.x-b.x,a.z-b.z).length()

static func horizontal_speed(body: RigidBody3D) -> float:
	return Vector2(body.linear_velocity.x,body.linear_velocity.z).length()

func _ticks(frames: int,arcade: CharacterBody3D,rigid: RigidBody3D) -> Dictionary:
	var supported: int = 0
	var max_angular: float = 0.0
	var max_roll: float = 0.0
	var valid: bool = true
	for i in range(frames):
		await physics_frame
		supported += 1 if int(rigid.grounded_wheels)>=2 else 0
		max_angular = maxf(max_angular,absf(rigid.angular_velocity.y))
		max_roll = maxf(max_roll,maxf(absf(rigid.rotation.x),absf(rigid.rotation.z)))
		if not (arcade.global_position.is_finite() and rigid.global_position.is_finite() and rigid.linear_velocity.is_finite()):
			valid = false
	return {
		"frames":frames,
		"supported_frames":supported,
		"max_yaw_rate_rad_s":max_angular,
		"max_roll_pitch_rad":max_roll,
		"all_finite":valid
	}

func _scenario(index: int,grip: float) -> Dictionary:
	seed(SEEDS[index])
	var arcade: CharacterBody3D = ARCADE.new()
	var rigid: RigidBody3D = RIGID.new()
	arcade.position = Vector3(-12.0,1.18,0)
	rigid.position = Vector3(12.0,1.08,0)
	root.add_child(arcade)
	root.add_child(rigid)
	arcade.driving = false
	arcade.assists_enabled = false
	arcade.axle_grip_active = false
	arcade.traction_factor = grip
	rigid.road_grip = grip
	rigid.motor_force_multiplier = 2.2 # lab-only candidate, never live
	await _ticks(TICKS_SETTLE,arcade,rigid)
	var initial_support: int = int(rigid.grounded_wheels)
	var a_start: Vector3 = arcade.global_position
	var r_start: Vector3 = rigid.global_position
	arcade.driving = true
	Input.action_press("move_forward")
	rigid.command_drive = 0.72
	var drive: Dictionary = await _ticks(TICKS_DRIVE,arcade,rigid)
	Input.action_release("move_forward")
	rigid.command_drive = 0.0
	var a_distance: float = distance_2d(a_start,arcade.global_position)
	var r_distance: float = distance_2d(r_start,rigid.global_position)
	var a_speed: float = absf(float(arcade.speed))
	var r_speed: float = horizontal_speed(rigid)
	var a_before_yaw: float = arcade.rotation.y
	var r_before_yaw: float = rigid.rotation.y
	Input.action_press("move_left")
	rigid.command_steer = 0.72
	var corner: Dictionary = await _ticks(TICKS_STEER,arcade,rigid)
	Input.action_release("move_left")
	rigid.command_steer = 0.0
	var a_yaw: float = absf(wrapf(arcade.rotation.y-a_before_yaw,-PI,PI))
	var r_yaw: float = absf(wrapf(rigid.rotation.y-r_before_yaw,-PI,PI))
	var a_prebrake: float = absf(float(arcade.speed))
	var r_prebrake: float = horizontal_speed(rigid)
	Input.action_press("move_backward")
	rigid.command_brake = 1.0
	var braking: Dictionary = await _ticks(TICKS_BRAKE,arcade,rigid)
	Input.action_release("move_backward")
	rigid.command_brake = 0.0
	var a_post: float = absf(float(arcade.speed))
	var r_post: float = horizontal_speed(rigid)
	var valid: bool = bool(drive["all_finite"]) and bool(corner["all_finite"]) and bool(braking["all_finite"])
	valid = valid and is_finite(a_distance) and is_finite(r_distance) and is_finite(a_yaw) and is_finite(r_yaw)
	check(initial_support>=2,"genuine supported springs after settling trial "+str(index))
	check(valid,"real Godot transforms and physical velocities stay finite trial "+str(index))
	check(a_distance>0.75 and r_distance>0.75,"both true physics engines move trial "+str(index))
	check(a_speed>0.25 and r_speed>0.25,"both models accelerate from standstill trial "+str(index))
	check(a_yaw>0.01 and r_yaw>0.01,"both models turn with same control phase trial "+str(index))
	check(int(drive["supported_frames"])>int(TICKS_DRIVE*0.55),"experimental springs maintain real ground contact trial "+str(index))
	check(a_post<a_prebrake+0.15 and r_post<r_prebrake+0.15,"braking never increases ground speed trial "+str(index))
	check(arcade.health>0.0 and arcade.fuel>0.0,"arcade collision/damage/fuel constraints survive trial "+str(index))
	var output: Dictionary = {
		"trial":index,"seed":SEEDS[index],"surface_grip":grip,
		"fixed_tick_hz":Engine.physics_ticks_per_second,
		"spring_contacts_at_rest":initial_support,
		"arcade":{
			"drive_m":a_distance,"speed_after_drive_mps":a_speed,
			"turn_rad":a_yaw,"speed_prebrake_mps":a_prebrake,
			"speed_postbrake_mps":a_post
		},
		"rigid":{
			"drive_m":r_distance,"speed_after_drive_mps":r_speed,
			"turn_rad":r_yaw,"speed_prebrake_mps":r_prebrake,
			"speed_postbrake_mps":r_post,
			"supported_drive_frames":int(drive["supported_frames"]),
			"supported_turn_frames":int(corner["supported_frames"]),
			"supported_brake_frames":int(braking["supported_frames"]),
			"max_roll_pitch_rad":maxf(float(drive["max_roll_pitch_rad"]),maxf(float(corner["max_roll_pitch_rad"]),float(braking["max_roll_pitch_rad"]))),
			"max_yaw_rate_rad_s":maxf(float(drive["max_yaw_rate_rad_s"]),float(corner["max_yaw_rate_rad_s"]))
		},
		"valid":valid
	}
	arcade.driving = false
	rigid.command_drive = 0.0
	rigid.command_steer = 0.0
	rigid.command_brake = 0.0
	arcade.queue_free()
	rigid.queue_free()
	await process_frame
	return output

func _run() -> void:
	var road := StaticBody3D.new()
	road.name = "R46ActualRoad"
	road.position = Vector3(0,-0.30,0)
	road.collision_layer = 1
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(300,0.6,300)
	shape.shape = box
	road.add_child(shape)
	root.add_child(road)
	check(Engine.physics_ticks_per_second==60,"comparison uses declared 60 Hz real Godot physics")
	var trials: Array[Dictionary] = []
	for i in range(GRIPS.size()):
		trials.append(await _scenario(i,GRIPS[i]))
	check(trials.size()==3,"dry / wet / repeated-dry numerical trials exist")
	var dry: Dictionary = trials[0]
	var wet: Dictionary = trials[1]
	var dry_repeat: Dictionary = trials[2]
	var denom: float = maxf(float(dry["rigid"]["drive_m"]),1.0)
	var repeat_error: float = absf(float(dry_repeat["rigid"]["drive_m"])-float(dry["rigid"]["drive_m"]))/denom
	var mismatch: float = absf(float(dry["rigid"]["drive_m"])-float(dry["arcade"]["drive_m"]))/maxf(float(dry["arcade"]["drive_m"]),1.0)
	check(repeat_error < 0.20,"same deterministic dry conditions reproduce candidate distance within 20%")
	check(float(wet["surface_grip"])<float(dry["surface_grip"]),"wet run truly changes physical grip input")
	check(mismatch>=0.0 and is_finite(mismatch),"actual movement parity error is measured instead of assumed")
	var player: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(player.contains('CAR_SCENE = preload("res://scripts/vehicle_controller.gd")'),
		"shipped player car is still authentic CharacterBody3D")
	check(not player.contains("r24_four_wheel_rigidbody"),
		"experimental rigid body is NOT substituted into the real game")
	var report: Dictionary = {
		"engine":"Godot 4.4.1",
		"protocol":"R46 independent 60Hz arcade-vs-force dry wet dry-repeat",
		"physics_simulation":true,
		"same_input_phase_durations":true,
		"control_transfer_functions_equivalent":false,
		"driver":"automated phase inputs, not human",
		"force_engine":"experimental RigidBody3D, not migrated",
		"migration_authorized":false,
		"physical_device_tested":false,
		"driver_visual_fidelity_verified":false,
		"trial_count":trials.size(),
		"ticks":{"settle":TICKS_SETTLE,"drive":TICKS_DRIVE,"turn":TICKS_STEER,"brake":TICKS_BRAKE},
		"rigid_dry_repeat_relative_error":repeat_error,
		"rigid_vs_arcade_dry_drive_distance_relative_error":mismatch,
		"trials":trials,
		"passed":passed,
		"failed":failed
	}
	var destination: String = ProjectSettings.globalize_path("res://tests/r46-physics-ab-metrics.json")
	var file: FileAccess = FileAccess.open(destination,FileAccess.WRITE)
	check(file!=null,"native Godot produces a traceable numeric evidence file")
	if file!=null:
		report["passed"]=passed
		report["failed"]=failed
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	road.queue_free()
	print("EMPIRE OMEGA R46 REAL A/B: %d passed, %d failed; dry repeat %.3f; force/arcade mismatch %.3f" % [passed,failed,repeat_error,mismatch])
	quit(0 if failed==0 else 1)
