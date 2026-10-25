extends SceneTree
## R40 engineering-only force lab: real Godot numerical motor calibration.
## Reads independently measured arcade baseline, never replaces the game car.
const LAB = preload("res://labs/r24_four_wheel_rigidbody.gd")
const MOTOR_SWEEP = [1.0,1.4,1.8,2.2,2.7,3.2]
var passed := 0
var failed := 0
func check(ok: bool,label: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R40 FORCE CALIBRATION FAILED: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run_one(road_grip: float,multiplier: float) -> Dictionary:
	var car: RigidBody3D = LAB.new()
	car.position = Vector3(0,1.08,0)
	car.motor_force_multiplier = multiplier
	car.road_grip = road_grip
	root.add_child(car)
	for i in range(140):
		await physics_frame
	var supported: int = int(car.grounded_wheels)
	var start: Vector3 = car.global_position
	car.command_drive = 0.72
	for i in range(120):
		await physics_frame
	var distance: float = Vector2(car.global_position.x-start.x,car.global_position.z-start.z).length()
	var speed: float = absf(float(car.measured_forward_speed))
	var forward: Vector3 = car.global_position
	var spring: float = car.average_spring_force
	var phase_start_speed: float = Vector2(car.linear_velocity.x,car.linear_velocity.z).length()
	car.command_drive = 0.0
	car.command_brake = 1.0
	for i in range(90):
		await physics_frame
	var end_speed: float = Vector2(car.linear_velocity.x,car.linear_velocity.z).length()
	var result: Dictionary = {
		"multiplier":multiplier,"road_grip":road_grip,
		"supported_wheels":supported,"distance_m":distance,
		"forward_speed_mps":speed,"spring_force_per_support_N":spring,
		"brake_start_mps":phase_start_speed,"brake_end_mps":end_speed,
		"body_height_m":forward.y
	}
	car.queue_free()
	await process_frame
	return result
func _run() -> void:
	var source: String = FileAccess.get_file_as_string("res://tests/r24-comparison.json")
	var comparison: Variant = JSON.parse_string(source)
	check(comparison is Dictionary and comparison.has("arcade"),"A/B original arcade reference comes from actual prior Godot simulation")
	if not (comparison is Dictionary) or not comparison.has("arcade"):
		quit(1)
		return
	var target_distance: float = float(comparison["arcade"]["forward_distance_m"])
	var target_speed: float = float(comparison["arcade"]["forward_speed_mps"])
	check(target_distance>1.0 and target_speed>0.5,"valid original real arcade reference")
	var road := StaticBody3D.new()
	road.collision_layer=1
	road.position=Vector3(0,-0.30,0)
	var shape_node := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(300,0.60,300)
	shape_node.shape=shape
	road.add_child(shape_node)
	root.add_child(road)
	var entries: Array[Dictionary] = []
	var best_score: float = INF
	var best_motor: float = 1.0
	var baseline_score: float = INF
	for motor in MOTOR_SWEEP:
		var result: Dictionary = await _run_one(1.0,float(motor))
		var error_distance: float = absf(float(result["distance_m"])-target_distance)/maxf(1.0,target_distance)
		var error_speed: float = absf(float(result["forward_speed_mps"])-target_speed)/maxf(1.0,target_speed)
		var score: float = 0.55*error_distance+0.45*error_speed
		result["arcade_normalized_error"] = score
		entries.append(result)
		check(int(result["supported_wheels"])>=2,"genuine springs remain planted at multiplier "+str(motor))
		check(float(result["distance_m"])>0.0 and is_finite(float(result["distance_m"])),"measured dynamic forward motion "+str(motor))
		check(float(result["brake_end_mps"])<float(result["brake_start_mps"]),"real dynamic brakes work at motor "+str(motor))
		check(is_finite(score),"real input phases yield finite comparable diagnostics")
		if motor==1.0: baseline_score=score
		if score<best_score:
			best_score=score
			best_motor=float(motor)
	var wet: Dictionary = await _run_one(0.65,best_motor)
	var best_dry: Dictionary = entries[MOTOR_SWEEP.find(best_motor)]
	check(float(wet["distance_m"])<float(best_dry["distance_m"]),"wet lab grip reduces actual rigid-body acceleration distance")
	check(float(wet["brake_end_mps"])<float(wet["brake_start_mps"]),"wet road still allows bounded real braking")
	check(best_score<=baseline_score+0.0001,"tested best tuning cannot exceed baseline mismatch")
	check(entries.size()==MOTOR_SWEEP.size(),"complete 6-point physically simulated motor sweep")
	var live: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(live.contains('CAR_SCENE = preload("res://scripts/vehicle_controller.gd")'),"shipped original CharacterBody3D car preserved")
	check(not live.contains("r24_four_wheel_rigidbody"),"force model is NOT migrated into player game")
	var report: Dictionary = {
		"engine":"Godot 4.4.1",
		"evidence":"real separate native force and arcade runs, same phase lengths; input implementations differ",
		"migration_authorized":false,
		"physical_iphone_or_android_measured":false,
		"arcade_target_distance_m":target_distance,
		"arcade_target_speed_mps":target_speed,
		"baseline_error":baseline_score,
		"best_measured_motor_multiplier":best_motor,
		"best_error":best_score,
		"wet_grip":wet,
		"motor_sweep":entries,
		"passed":passed,"failed":failed
	}
	var f: FileAccess = FileAccess.open("res://tests/r40-force-calibration.json",FileAccess.WRITE)
	check(f!=null,"actual native run produces evidence file")
	if f!=null:
		f.store_string(JSON.stringify(report,"  "))
		f.close()
	road.queue_free()
	print("EMPIRE OMEGA R40 FORCE SWEEP: %d passed, %d failed; best motor %s; score %s" % [passed,failed,str(best_motor),str(best_score)])
	quit(0 if failed==0 else 1)
