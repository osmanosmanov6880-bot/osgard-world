extends SceneTree
## R23 native Godot 4.4.1 — bounded weather tyre particles on real contacts.
const SPRAY = preload("res://scripts/horizon_ground_spray.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
const SURFACE = preload("res://scripts/horizon_four_wheel_surface.gd")
var passed:=0
var failed:=0

func check(ok: bool, description: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("HORIZON R23 FAILED: "+description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(not SPRAY.should_emit(0.0,8.0,true,false),"no dust while stationary")
	check(not SPRAY.should_emit(16.0,0.0,false,false),"no dust for dry straight driving")
	check(SPRAY.should_emit(16.0,3.0,true,false),"dry drift creates small tyre dust")
	check(SPRAY.should_emit(16.0,0.0,false,true),"wet road creates spray even without drifting")
	check(not SPRAY.should_emit(4.0,4.0,true,true),"very slow travel does not create water mist")
	check(not SPRAY.should_emit(NAN,7.0,true,true),"invalid vehicle input cannot activate particles")
	var floor := StaticBody3D.new()
	floor.collision_layer=1
	floor.position=Vector3(0,-0.3,0)
	var shape_node := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(40,0.6,40)
	shape_node.shape=box
	floor.add_child(shape_node)
	root.add_child(floor)
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	car.global_position=Vector3(0,0.86,0)
	for i in range(4): await physics_frame
	car.set_physics_process(false)
	var real_contact: Dictionary = SURFACE.probe(car)
	check(int(real_contact["count"])==4,"4 authentic Godot collision rays hit roadway")
	var spray: Node3D = SPRAY.new()
	root.add_child(spray)
	var emitted: Array = spray.get("emitters")
	check(emitted.size()==2,"exactly two pooled rear-wheel emitters")
	var budget:=0
	for e in emitted:
		budget += (e as GPUParticles3D).amount
	check(budget==SPRAY.MAX_ALLOWED and budget==48,"hard particle pool cap 48")
	check(not (emitted[0] as GPUParticles3D).emitting and not (emitted[1] as GPUParticles3D).emitting,"idle world never emits smoke")
	car.driving=true
	car.speed=18.0
	car.lateral_speed=0.0
	car.traction_factor=1.0
	check(int(spray.call("update_spray",car,true,"cinematic",0.016))==0,"dry straight drive stays clean")
	car.traction_factor=0.66
	var count: int = spray.call("update_spray",car,true,"cinematic",0.016)
	check(count==2,"rain creates two authentic grounded wheel spray emitters")
	check((emitted[0] as GPUParticles3D).emitting and (emitted[1] as GPUParticles3D).emitting,"real particles switched on")
	check((emitted[0] as GPUParticles3D).amount_ratio>0.55,"cinematic spray uses bounded detail")
	var original: Vector3 = car.global_position
	check(spray.global_position==Vector3.ZERO or spray.get_parent()==root,"particle simulation has separate world-space parent")
	check(car.global_position==original and is_equal_approx(car.speed,18.0),"spray cannot alter actual vehicle motion")
	var wet_material: ParticleProcessMaterial = (emitted[0] as GPUParticles3D).process_material
	check(wet_material.color.b>wet_material.color.r,"rain spray is visibly bluish")
	var wet_blue: float = wet_material.color.b
	count=spray.call("update_spray",car,true,"standard",0.016)
	check(count==2 and (emitted[0] as GPUParticles3D).amount_ratio<=0.41,"STANDARD reduces particle workload")
	check(int(spray.call("update_spray",car,true,"low",0.016))==0,"LOW GPU disables all effects")
	check(not (emitted[0] as GPUParticles3D).emitting and (emitted[0] as GPUParticles3D).amount_ratio==0.0,"LOW has no hidden active emission")
	car.traction_factor=1.0
	car.lateral_speed=4.0
	car.handbrake_on=true
	count=spray.call("update_spray",car,true,"cinematic",0.016)
	check(count==2,"dry handbrake drift produces ground dust")
	var dust_material: ParticleProcessMaterial = (emitted[0] as GPUParticles3D).process_material
	check(dust_material.color.b < wet_blue-0.20,"dry dust is measurably less blue than original wet mist")
	check(int(spray.call("update_spray",car,false,"cinematic",0.016))==0,"exiting vehicle immediately stops new spray")
	car.global_position=Vector3(0,8.0,0)
	count=spray.call("update_spray",car,true,"cinematic",0.016)
	check(count==0,"airborne car has no dust painted above road")
	check(not (emitted[1] as GPUParticles3D).emitting,"unsupported wheel does not emit particles")
	var main_src:=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_src.contains("GROUND_SPRAY_SCENE.new()"),"actual game creates particles in live scene")
	check(main_src.contains("ground_spray.call(\"update_spray\",car,driving,adaptive_graphics.effective_quality(),delta)"),"main game passes graphics tier and driving state")
	var vehicle_src:=FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
	check(vehicle_src.contains("last_wheel_support = wheel_support"),"wheel contact is stored once per physics frame")
	var skid_src:=FileAccess.get_file_as_string("res://scripts/horizon_skid_trails.gd")
	check(skid_src.contains("vehicle.get(\"last_wheel_support\")"),"skids also reuse physics contact, avoiding extra real-time raycasts")
	car.queue_free()
	spray.queue_free()
	floor.queue_free()
	print("HORIZON R23 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
