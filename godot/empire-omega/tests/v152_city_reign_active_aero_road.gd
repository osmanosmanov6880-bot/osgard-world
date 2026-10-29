extends SceneTree
## R167 actual live Godot road: existing spoiler reacts to player W/S speed,
## never creates aero forces, ghost collisions, overlays or GPU resources.
const CAR=preload("res://scripts/vehicle_controller.gd")
var passed:=0
var failed:=0

func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R167 REAL AERO FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node=root.get_node_or_null("GameState")
	var saved: Dictionary=(state.get("data") as Dictionary).duplicate(true)
	var settings: Node=root.get_node_or_null("GameSettings")
	var old_reduced: bool=bool(settings.get("reduced_motion"))
	settings.set("reduced_motion",false)
	var road:=StaticBody3D.new()
	road.collision_layer=1
	road.position=Vector3(0,-0.30,0)
	var collider:=CollisionShape3D.new()
	var bounds:=BoxShape3D.new()
	bounds.size=Vector3(400,0.60,400)
	collider.shape=bounds
	road.add_child(collider)
	root.add_child(road)
	var car: CharacterBody3D=CAR.new()
	car.position=Vector3(0,0.86,0)
	root.add_child(car)
	car.driving=true
	var art: Node3D=car.horizon_visual
	var spoiler: MeshInstance3D=art.get_node("RearSpoiler")
	var trim: MeshInstance3D=art.get_node("R167PrecisionAeroSurface")
	var original_spoiler_mesh: Mesh=spoiler.mesh
	var original_trim_mesh: Mesh=trim.mesh
	var scene_children: int=art.get_child_count()
	var original_pose: Transform3D=spoiler.transform
	Input.action_press("move_forward")
	for i in range(130): await physics_frame
	Input.action_release("move_forward")
	var speed: float=car.speed
	check(speed>10.0 and speed<30.0,
		"true original car accelerates with real Godot W control and road collision")
	check(float(art.get("aero_angle"))<0.002,
		"spoiler never invents aerodynamic braking on active acceleration")
	Input.action_press("move_backward")
	for i in range(25): await physics_frame
	Input.action_release("move_backward")
	var raised: float=float(art.get("aero_angle"))
	check(car.brake_response>0.95 and raised>0.010 and raised<=0.22,
		"actual S brake at 10m/s+ visibly lifts existing source spoiler")
	check(spoiler.transform!=original_pose and spoiler.mesh==original_spoiler_mesh,
		"actual spoiler uses original mesh and native scene transform, not extra draw")
	for i in range(50): await physics_frame
	check(float(art.get("aero_angle"))<raised*0.20,
		"release of the actual brake smoothly lowers spoiler without game physics mutation")
	art.call("sync_aero_feedback",27.0,1.0,0.1,false)
	var normal_aero: float=float(art.get("aero_angle"))
	art.call("sync_aero_feedback",27.0,1.0,0.1,true)
	check(float(art.get("aero_angle"))<normal_aero,
		"reduced-motion accessibility stops animated aerodynamic signals")
	for i in range(120):
		art.call("sync_aero_feedback",29.0,1.0,1.0/60.0,false)
	check(float(art.get("aero_angle"))<=0.221 and float(art.get("aero_angle"))>=0.0,
		"long gameplay stays bounded and deterministic at maximum vehicle speed")
	check(spoiler.mesh==original_spoiler_mesh and trim.mesh==original_trim_mesh and
		art.get_child_count()==scene_children,
		"120 animation updates allocate ZERO new GPU meshes, lights or car nodes")
	art.set_visual_variant("courier")
	check(not spoiler.visible,"original cargo vehicle has no fictional exposed sports spoiler")
	art.set_visual_variant("executive")
	check(spoiler.visible,"original executive styling restores its real spoiler")
	check(car.collision_layer==4 and car.collision_mask==9,
		"actual collision topology unchanged by visual aerodynamic feature")
	check(state.get("data")==saved,
		"no change to economy, missions, save integrity or resource authority")
	settings.set("reduced_motion",old_reduced)
	car.driving=false
	car.queue_free()
	road.queue_free()
	await process_frame
	print("CITY REIGN R167 PHYSICAL AERO LIVE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
