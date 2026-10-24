extends SceneTree
## HORIZON R17: native Godot tests for bounded yaw inertia and real car wiring.
## Does not claim a per-wheel Pacejka or full rigid-body suspension solver.
const MOTION = preload("res://scripts/horizon_yaw_inertia.gd")
const DYNAMICS = preload("res://scripts/driving_dynamics.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R17 FAILURE: "+description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(is_equal_approx(MOTION.steer_step(0.2,0.7,14.0,1.0,0.0),0.2),"paused game never changes steering")
	var first_steer: float = MOTION.steer_step(0.0,1.0,24.0,1.0,1.0/60.0)
	check(first_steer > 0.0 and first_steer < 0.15,"high speed cannot snap immediately to full steering")
	var slow_response: float = MOTION.steer_step(0.0,1.0,2.0,1.0,1.0/60.0)
	check(slow_response > first_steer,"parking speed is more responsive than high speed")
	var wet_steer: float = MOTION.steer_step(0.0,1.0,24.0,0.45,1.0/60.0)
	check(wet_steer < first_steer,"rain smooths sharp steering")
	var saturated: float = MOTION.steer_step(0.0,5.0,3.0,1.0,1.0)
	check(saturated <= 1.0 and saturated > 0.0,"impossible input and large resume timestep stay bounded")
	check(MOTION.steer_step(0.0,NAN,14.0,1.0,0.016)==0.0,"nonfinite steering fails safely")
	var target_yaw: float = DYNAMICS.yaw_rate(20.0,0.8,1.0,false)
	var first_yaw: float = MOTION.yaw_step(0.0,target_yaw,20.0,1.0,false,1.0/60.0)
	check(first_yaw > 0.0 and first_yaw < target_yaw*0.20,"vehicle turn starts smoothly instead of instantaneous yaw")
	var rate: float = first_yaw
	for i in range(180):
		rate = MOTION.yaw_step(rate,target_yaw,20.0,1.0,false,1.0/60.0)
	check(absf(rate-target_yaw)<0.01,"stable sustained turn eventually reaches physical yaw target")
	var easing: float = MOTION.yaw_step(rate,0.0,20.0,1.0,false,1.0/60.0)
	check(easing < rate and easing > 0.0,"steering release decays yaw rather than snapping")
	var reversed: float = MOTION.yaw_step(0.0,-0.5,-10.0,1.0,false,1.0/60.0)
	check(reversed < 0.0,"reverse gear produces opposite yaw")
	var rain_rate: float = MOTION.yaw_step(0.0,target_yaw,20.0,0.45,false,1.0/60.0)
	check(rain_rate < first_yaw,"wet surface softens yaw response")
	check(absf(MOTION.yaw_step(1.0,1.0,28.0,0.35,true,0.5)) <= (MOTION.LATERAL_ACCEL_LIMIT*0.35/28.0)+0.0001,"low grip obeys lateral acceleration envelope")
	check(is_zero_approx(MOTION.yaw_step(0.5,0.0,0.0,1.0,false,0.016)),"stopped car does not spin on its own")
	check(is_equal_approx(MOTION.yaw_step(0.3,0.5,15.0,1.0,false,0.0),0.3),"paused yaw stays unchanged")
	var twice: float = MOTION.yaw_step(0.0,target_yaw,15.0,1.0,false,0.016)
	twice = MOTION.yaw_step(twice,target_yaw,15.0,1.0,false,0.016)
	var once: float = MOTION.yaw_step(0.0,target_yaw,15.0,1.0,false,0.032)
	check(absf(once-twice)<0.0001,"equivalent elapsed times lead to equivalent inertial yaw")
	var dry_power: float = MOTION.corner_power_factor(20.0,0.35,1.0,false)
	var wet_power: float = MOTION.corner_power_factor(20.0,0.35,0.5,false)
	check(dry_power >= MOTION.MIN_POWER_FACTOR and dry_power < 1.0,"loaded turn modestly reserves engine torque")
	check(wet_power < dry_power,"less tire grip reserves more torque in wet turn")
	check(is_equal_approx(MOTION.corner_power_factor(1.0,0.4,0.5,false),1.0),"parking moves keep full torque")
	check(is_equal_approx(MOTION.corner_power_factor(20.0,0.4,0.5,true),1.0),"handbrake slides bypass throttle reserve")
	check(MOTION.corner_power_factor(25.0,999.0,0.35,false)>=MOTION.MIN_POWER_FACTOR,"torque reduction has strict lower limit")
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	floor.position = Vector3(0.0,-1.0,0.0)
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(500.0,2.0,500.0)
	shape_node.shape = box
	floor.add_child(shape_node)
	root.add_child(floor)
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	car.position = Vector3(0,1.4,0)
	car.driving = true
	car.traction_factor = 0.7
	for i in range(3):
		await physics_frame
	Input.action_press("move_forward")
	for i in range(70):
		await physics_frame
	check(float(car.get("speed"))>4.0,"actual car accelerates on wet asphalt with new model")
	var previous_yaw: float = car.rotation.y
	Input.action_press("move_left")
	for i in range(50):
		await physics_frame
	check(absf(car.rotation.y-previous_yaw)>0.10,"actual car turns on held steering command")
	check(absf(float(car.get("current_yaw_rate")))>0.02,"inertial yaw is wired into physical movement")
	check(is_finite(car.global_position.x) and is_finite(car.global_position.z),"position remains finite after simultaneous gas and turning")
	Input.action_release("move_left")
	Input.action_release("move_forward")
	var vehicle_source: String = FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
	check(vehicle_source.contains("YAW_INERTIA.steer_step") and vehicle_source.contains("YAW_INERTIA.yaw_step"),"the real playable car uses R17 dynamic steering, not a test-only module")
	check(vehicle_source.contains("YAW_INERTIA.corner_power_factor"),"real vehicle respects cornering power reserve")
	car.queue_free()
	floor.queue_free()
	print("HORIZON R17 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
