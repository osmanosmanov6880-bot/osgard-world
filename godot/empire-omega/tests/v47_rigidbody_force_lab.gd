extends SceneTree
## R24 independent force suspension acceptance: real native Godot 4.4.1.
## This test NEVER replaces the existing playable car in main.gd.
const LAB = preload("res://labs/r24_four_wheel_rigidbody.gd")
var passed:=0
var failed:=0

func check(ok: bool, reason: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("HORIZON R24 PHYSICS FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(LAB.traction(1.0,4)>LAB.traction(0.65,4),"wet grip below dry")
	check(LAB.traction(1.0,2)<LAB.traction(1.0,4),"loss of ground contact reduces drive grip")
	check(is_zero_approx(LAB.traction(1.0,0)),"zero grounded wheels has zero motor traction")
	check(LAB.spring_force(0.18,-1.0)>LAB.spring_force(0.18,1.0),"damper resists wheel compression")
	check(LAB.spring_force(-1.0,0.0)==0.0,"negative spring compression does not push car")
	check(LAB.spring_force(1000.0,-100.0)<=LAB.MAX_WHEEL_FORCE,"extreme spring values strictly bounded")
	check(LAB.spring_force(NAN,1.0)==0.0,"invalid physical measurement rejected")
	var floor:=StaticBody3D.new()
	floor.name="LabRoad"
	floor.collision_layer=1
	floor.position=Vector3(0,-0.30,0)
	var collision:=CollisionShape3D.new()
	var shape:=BoxShape3D.new()
	shape.size=Vector3(180,0.6,180)
	collision.shape=shape
	floor.add_child(collision)
	root.add_child(floor)
	var lab: RigidBody3D = LAB.new()
	lab.position=Vector3(0,1.08,0)
	root.add_child(lab)
	var peak_contacts:=0
	for i in range(140):
		await physics_frame
		peak_contacts=maxi(peak_contacts,int(lab.get("grounded_wheels")))
	check(lab.mass==LAB.BODY_MASS,"body carries declared physical mass")
	check(lab is RigidBody3D,"test uses actual dynamic body, not kinematic impostor")
	check(peak_contacts>=3,"real downward rays hit actual static road")
	check(lab.global_position.y>0.50 and lab.global_position.y<2.00,"physical springs stabilize body above road")
	check(is_finite(lab.linear_velocity.y),"vertical velocity remains finite")
	check(absf(lab.rotation.x)<1.1 and absf(lab.rotation.z)<1.1,"resting chassis does not roll or pitch uncontrollably")
	check(int(lab.get("grounded_wheels"))>=2,"car has stabilized on at least two wheels")
	check(float(lab.get("average_spring_force"))>1000.0,"physical spring actually supports mass")
	var start: Vector3=lab.global_position
	lab.set("command_drive",0.72)
	for i in range(90):
		await physics_frame
	var traveled: float=Vector2(lab.global_position.x-start.x,lab.global_position.z-start.z).length()
	check(traveled>0.75,"real motor force moves rigid body across road")
	check(lab.linear_velocity.length()>0.65,"real body acquires velocity under engine force")
	var angle_start: float=lab.rotation.y
	lab.set("command_steer",0.75)
	for i in range(95):
		await physics_frame
	check(absf(wrapf(lab.rotation.y-angle_start,-PI,PI))>0.03,"actual force torque steers rigid body")
	check(is_finite(lab.global_position.x) and is_finite(lab.global_position.z),"force-based path stays finite")
	lab.set("command_drive",0.0)
	lab.set("command_steer",0.0)
	var fast: float=Vector2(lab.linear_velocity.x,lab.linear_velocity.z).length()
	lab.set("command_brake",1.0)
	for i in range(100):
		await physics_frame
	var slow: float=Vector2(lab.linear_velocity.x,lab.linear_velocity.z).length()
	check(slow<fast,"wheel-ground brake reduces horizontal speed")
	check(lab.get_child_count()>=2 and lab.get_node_or_null("ExperimentalMassBody")!=null,"the isolated experiment is an actual 3D body with collision")
	var above: RigidBody3D=LAB.new()
	above.position=Vector3(40,7.0,0)
	above.command_drive=1.0
	root.add_child(above)
	for i in range(10):
		await physics_frame
	check(int(above.get("grounded_wheels"))==0,"airborne lab car has no fictitious contacts")
	check(absf(above.linear_velocity.x)<0.1 and absf(above.linear_velocity.z)<0.1,"motor cannot accelerate through air without tire traction")
	var live_source:=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(live_source.contains("CAR_SCENE = preload(\"res://scripts/vehicle_controller.gd\")"),"live game car remains unchanged in source")
	check(not live_source.contains("r24_four_wheel_rigidbody"),"experimental physics cannot silently replace player vehicle")
	var report: Dictionary = {
		"experiment":"HORIZON R24 — isolated Godot RigidBody3D candidate",
		"status":"experimental-not-in-player-game",
		"engine":"Godot 4.4.1",
		"mass_kg":LAB.BODY_MASS,
		"peak_real_wheel_contacts":peak_contacts,
		"settled_height_m":lab.global_position.y,
		"drive_test_metres":traveled,
		"yaw_delta_rad":absf(wrapf(lab.rotation.y-angle_start,-PI,PI)),
		"speed_before_brake_mps":fast,
		"speed_after_brake_mps":slow,
		"airborne_wheel_contacts":int(above.get("grounded_wheels")),
		"passed":passed,
		"failed":failed,
		"device_performance_measured":false
	}
	var output: FileAccess = FileAccess.open("res://tests/r24-force-metrics.json",FileAccess.WRITE)
	if output != null:
		output.store_string(JSON.stringify(report,"  "))
		output.close()
	else:
		check(false,"native Godot experiment must produce measurable physics report")
	lab.queue_free()
	above.queue_free()
	floor.queue_free()
	print("HORIZON R24 FORCE LAB NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
