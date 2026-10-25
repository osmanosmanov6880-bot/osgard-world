extends SceneTree
## R46 real Godot car braking integration plus bounded four-wheel contact rule.
## Experimental RigidBody3D lab MUST NOT silently replace player CharacterBody3D.
const LOAD = preload("res://scripts/horizon_r46_load_transfer.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0
func verify(ok: bool,reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("EMPIRE R46 BRAKING FAILED: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var support: Array[bool] = [true,true,true,true]
	var rear_lift: Array[bool] = [true,false,true,true]
	var front_lift: Array[bool] = [false,true,true,true]
	var two_front: Array[bool] = [true,false,true,false]
	var static_front: float = LOAD.front_axle_fraction(0.0)
	var stopping_front: float = LOAD.front_axle_fraction(-6.0)
	var accelerating_front: float = LOAD.front_axle_fraction(6.0)
	verify(absf(static_front-0.52)<0.0001,"loaded car has 52 percent static front normal force")
	verify(stopping_front>static_front and stopping_front<0.75,"braking physically shifts load to front axle")
	verify(accelerating_front<static_front and accelerating_front>0.30,"acceleration physically shifts load rearwards")
	verify(LOAD.front_axle_fraction(NAN)==static_front,"invalid acceleration cannot corrupt load")
	verify(LOAD.front_axle_fraction(INF)<=0.75,"infinite acceleration clamps safely")
	verify(is_equal_approx(LOAD.contact_fraction(support,stopping_front),1.0),"four actual supports retain all available normal force")
	verify(is_equal_approx(LOAD.contact_fraction(two_front,stopping_front),stopping_front),"front axle carries calculated braking load")
	verify(LOAD.contact_fraction(front_lift,stopping_front)<LOAD.contact_fraction(rear_lift,stopping_front),"lost front wheel costs more grip during braking")
	verify(LOAD.contact_fraction([],static_front)==0.0,"invalid wheel probe cannot fake full contact")
	verify(LOAD.contact_fraction([false,false,false,false],static_front)==0.0,"airborne car has no tyre normal force")
	verify(LOAD.braking_grip(1.0,support,stopping_front)==1.0,"fully planted dry car preserves original real brake tuning")
	verify(LOAD.braking_grip(0.6,support,stopping_front)==0.6,"fully planted wet car preserves old weather handling")
	verify(LOAD.braking_grip(1.0,front_lift,stopping_front)<LOAD.braking_grip(1.0,rear_lift,stopping_front),"contact loss has front-biased force impact")
	verify(LOAD.braking_grip(1.0,front_lift,stopping_front)>=0.35,"brake grip cannot become negative")
	verify(LOAD.braking_grip(NAN,support,static_front)==0.35,"invalid wetness fails to minimum grip")
	verify(LOAD.estimated_brake_distance(20.0,0.6)>LOAD.estimated_brake_distance(20.0,1.0),"wet tyre needs longer estimated stopping distance")
	verify(LOAD.estimated_brake_distance(20.0,1.0)>LOAD.estimated_brake_distance(10.0,1.0)*3.9,"stopping distance scales as v squared")
	verify(LOAD.estimated_brake_distance(NAN,1.0)==0.0,"nonfinite speed never exported as distance")
	var sample: Dictionary = LOAD.diagnostics(15.0,-5.0,0.65,front_lift)
	verify(absf(float(sample["front_axle_load_ratio"])+float(sample["rear_axle_load_ratio"])-1.0)<0.001,"front and rear loads sum to one")
	verify(float(sample["estimated_full_brake_m"])>0.0 and float(sample["available_brake_grip"])<0.65,"report responds to real contact loss")
	verify(sample["measured_physical_road_stopping_distance"]==false,"estimated distance is honestly labelled not measured")
	var floor := StaticBody3D.new()
	floor.collision_layer=1
	floor.position=Vector3(0,-0.30,0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(100,0.60,100)
	shape.shape=box
	floor.add_child(shape)
	root.add_child(floor)
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	car.global_position=Vector3(0,0.86,0)
	car.driving=true
	verify(car is CharacterBody3D and car.get("r46_brake_diagnostics") is Dictionary,"original live car still owns R46 module")
	Input.action_press("move_forward")
	for i in range(70):
		await physics_frame
	Input.action_release("move_forward")
	var accelerated_speed: float = float(car.get("speed"))
	verify(accelerated_speed>3.5,"native Godot real car accelerates on physical road")
	Input.action_press("move_backward")
	for i in range(15):
		await physics_frame
	Input.action_release("move_backward")
	var slowed: float = float(car.get("speed"))
	verify(slowed<accelerated_speed,"full real brake input reduces actual car velocity")
	var live_metrics: Dictionary = car.get("r46_brake_diagnostics")
	verify(live_metrics.has("front_axle_load_ratio") and live_metrics.has("estimated_full_brake_m"),"original production car writes contact-aware telemetry")
	verify(float(live_metrics["estimated_full_brake_m"])>=0.0 and is_finite(float(live_metrics["estimated_full_brake_m"])),"runtime stopping estimate cannot overflow")
	verify(float(car.get("r46_front_load_ratio"))>=0.30 and float(car.get("r46_front_load_ratio"))<=0.75,"real body tracks bounded transfer")
	verify(float(car.get("r46_brake_grip"))>=0.35 and float(car.get("r46_brake_grip"))<=1.15,"real brakes never receive invalid friction multiplier")
	var source: String=FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
	verify(source.contains("R46_LOAD_TRANSFER.braking_grip(") and source.contains("R46_LOAD_TRANSFER.diagnostics("),"real player car uses BOTH physical braking and road-contact diagnostics")
	var gameplay: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	verify(gameplay.contains('CAR_SCENE = preload("res://scripts/vehicle_controller.gd")'),"real driving game retains its live vehicle scene")
	verify(not gameplay.contains("r24_four_wheel_rigidbody.gd"),"unvalidated force lab remains isolated")
	car.driving=false
	car.queue_free()
	floor.queue_free()
	await process_frame
	print("EMPIRE OMEGA R46 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
