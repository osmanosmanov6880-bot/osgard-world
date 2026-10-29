extends SceneTree
## R166 existing 48-particle spray gets actual 3D world-velocity wake.
const SPRAY = preload("res://scripts/horizon_ground_spray.gd")
const CONTACT = preload("res://scripts/horizon_four_wheel_surface.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func check(ok: bool,reason: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R166 SPRAY WAKE FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var back: Vector3 = SPRAY.wake_direction(Vector3(0,0,-18),Vector3.UP)
	var reverse: Vector3 = SPRAY.wake_direction(Vector3(0,0,18),Vector3.UP)
	check(back.y>0.60 and back.z>0.5 and reverse.z< -0.5,
		"true road velocity projects droplets up and backwards in both travel directions")
	check(SPRAY.wake_direction(Vector3.ZERO,Vector3.UP)==Vector3.UP,
		"parked car never invents movement direction")
	check(SPRAY.wake_direction(Vector3(INF,0,0),Vector3.UP)==Vector3.UP,
		"invalid physics values fail closed")
	var slope: Vector3=Vector3(0,0.96,0.28).normalized()
	check(SPRAY.wake_direction(Vector3(0,0,-18),slope).dot(slope)>0.35,
		"actual road slope contributes to the spray's upward direction")
	var floor := StaticBody3D.new()
	floor.collision_layer=1
	floor.position=Vector3(0,-0.30,0)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(90,0.6,90)
	shape.shape=box
	floor.add_child(shape)
	root.add_child(floor)
	var car: CharacterBody3D=CAR.new()
	car.position=Vector3(0,0.86,0)
	root.add_child(car)
	for i in range(5): await physics_frame
	car.set_physics_process(false)
	var support: Dictionary=CONTACT.probe(car)
	check(int(support["count"])==4,"original collision rays genuinely support all four wheels")
	car.driving=true
	car.speed=21.0
	car.velocity=Vector3(0,0,-21)
	car.traction_factor=0.64
	var spray: Node3D=SPRAY.new()
	root.add_child(spray)
	var emitters: Array=spray.get("emitters")
	var original_mesh: Mesh=(emitters[0] as GPUParticles3D).draw_pass_1
	var started: int=spray.update_spray(car,true,"cinematic",1.0/60.0)
	check(started==2 and (emitters[0] as GPUParticles3D).emitting,
		"two real wheel spray contacts emit under wet road motion")
	var mat: ParticleProcessMaterial=(emitters[0] as GPUParticles3D).process_material
	check(mat.direction.z>0.45 and mat.direction.y>0.50,
		"existing actual GPU particles now move behind the true velocity")
	check(mat.initial_velocity_max>1.65 and mat.initial_velocity_max<3.0,
		"water droplet velocity scales in bounded range with actual speed")
	car.velocity=Vector3(0,0,21)
	spray.update_spray(car,true,"standard",1.0/60.0)
	check(mat.direction.z< -0.45 and (emitters[0] as GPUParticles3D).amount_ratio<=0.41,
		"reverse road direction works with restrained STANDARD particle budget")
	var memory: int=0
	for emitter in emitters: memory += (emitter as GPUParticles3D).amount
	check(memory==SPRAY.MAX_ALLOWED and original_mesh==(emitters[0] as GPUParticles3D).draw_pass_1,
		"particle pool remains 48, with no dynamic mesh creation")
	check(spray.update_spray(car,true,"low",1.0/60.0)==0 and
		not (emitters[0] as GPUParticles3D).emitting,
		"mobile LOW completely disables true GPU spray")
	car.position=Vector3(0,12,0)
	check(spray.update_spray(car,true,"cinematic",1.0/60.0)==0,
		"airborne fake contacts never spray a floating street")
	car.driving=false
	car.queue_free()
	floor.queue_free()
	spray.queue_free()
	await process_frame
	print("CITY REIGN R166 TRUE ROAD SPRAY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
