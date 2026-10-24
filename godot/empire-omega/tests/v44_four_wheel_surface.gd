extends SceneTree
## R21: real Godot static-world raycasts + measurable wheel attitude.
const SURFACE = preload("res://scripts/horizon_four_wheel_surface.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("R21 WHEEL SURFACE FAILED: " + label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(is_equal_approx(SURFACE.support_ratio([true,true,true,true]),1.0),"four supports report full support")
	check(is_equal_approx(SURFACE.support_ratio([true,false,false,false]),0.25),"single supported wheel reports quarter")
	check(is_equal_approx(SURFACE.support_ratio([false,false,false,false]),0.0),"unsupported chassis reports zero support")
	check(is_equal_approx(SURFACE.support_ratio([]),0.0),"malformed support masks fail closed")
	check(SURFACE.terrain_attitude([])==Vector2.ZERO,"malformed sample cannot corrupt body tilt")
	check(SURFACE.terrain_attitude([0.0,0.0,0.0,0.0])==Vector2.ZERO,"flat four-wheel surface has no artificial camber")
	check(SURFACE.terrain_attitude([0.18,0.18,-0.10,-0.10]).x>0.05,"left wheel rise produces measurable roll")
	check(SURFACE.terrain_attitude([-0.10,-0.10,0.18,0.18]).x< -0.05,"right wheel rise produces opposite roll")
	check(SURFACE.terrain_attitude([0.18,-0.10,0.18,-0.10]).y>0.05,"raised front wheels produce nose pitch")
	check(SURFACE.terrain_attitude([-0.10,0.18,-0.10,0.18]).y< -0.05,"raised rear wheels reverse nose pitch")
	check(SURFACE.terrain_attitude([0.18,-0.10,-0.10,-0.10],[true,false,false,false])==Vector2.ZERO,"one grounded wheel cannot invent a cross-body road plane")
	check(is_equal_approx(SURFACE.visual_travel(0.8,true),0.18),"wheel compression capped")
	check(is_equal_approx(SURFACE.visual_travel(-3.0,true),-0.10),"spring extension capped")
	check(is_equal_approx(SURFACE.visual_travel(0.1,false),-0.10),"wheel droops instead of compressing without ground")
	var floor := StaticBody3D.new()
	floor.name = "PhysicalTireContactFloor"
	floor.collision_layer=1
	floor.position=Vector3(0,-0.30,0)
	var floor_hit := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size=Vector3(20.0,0.60,20.0)
	floor_hit.shape=floor_box
	floor.add_child(floor_hit)
	root.add_child(floor)
	var vehicle: CharacterBody3D = CAR.new()
	root.add_child(vehicle)
	vehicle.set_physics_process(false)
	vehicle.global_position=Vector3(0,0.86,0)
	await physics_frame
	await physics_frame
	var flat: Dictionary = SURFACE.probe(vehicle)
	check(int(flat["count"])==4,"real downward physics rays find four road contacts")
	var mask: Array[bool] = flat["grounded"]
	check(SURFACE.support_ratio(mask)==1.0,"real contact array preserves all wheel support")
	var samples: Array[float] = flat["travel"]
	check(samples.size()==4 and samples.max()<0.18,"flat chassis measures four spring travels")
	var stone := StaticBody3D.new()
	stone.name = "FrontLeftRoadBump"
	stone.collision_layer=1
	stone.position=Vector3(-1.34,0.12,-1.75)
	var bump_hit := CollisionShape3D.new()
	var bump_box := BoxShape3D.new()
	bump_box.size=Vector3(1.1,0.24,1.0)
	bump_hit.shape=bump_box
	stone.add_child(bump_hit)
	root.add_child(stone)
	await physics_frame
	await physics_frame
	var uneven: Dictionary = SURFACE.probe(vehicle)
	var bumps: Array[float] = uneven["travel"]
	var valid: Array[bool] = uneven["grounded"]
	check(int(uneven["count"])==4,"single bump does not remove road support under other tyres")
	check(bumps[0] > bumps[1]+0.08 and bumps[0] > bumps[2]+0.08,"raised front-left ground changes only measured wheel spring")
	var attitude: Vector2 = SURFACE.terrain_attitude(bumps,valid)
	check(attitude.length()>0.005,"actual static-world bump produces chassis roll and pitch")
	var art: Node3D = vehicle.get_node_or_null("HorizonCoupe")
	check(art!=null,"real playable car contains four-wheel animated art")
	if art!=null:
		for i in range(50):
			art.call("simulate_chassis",0.0,0.0,0.0,1.0,false,bumps,1.0/60.0,valid)
		check(absf(float(art.get("roll_angle")))>0.003,"real 3D body rolls toward raised contact")
		check(absf(float(art.get("pitch_angle")))>0.003,"real 3D body pitches toward raised front axle")
		var wheel_rigs: Array = art.get("wheel_rigs")
		check(wheel_rigs.size()==4,"original wheel pivots survive upgrade")
		if wheel_rigs.size()==4:
			check((wheel_rigs[0] as Node3D).position.y>(wheel_rigs[1] as Node3D).position.y+0.07,"front-left wheel moves independently of rear-left")
		var suspended: Array[bool] = [false,false,false,false]
		for i in range(60):
			art.call("simulate_chassis",0.0,0.0,0.0,1.0,false,bumps,1.0/60.0,suspended)
		if wheel_rigs.size()==4:
			check((wheel_rigs[0] as Node3D).position.y < -0.37,"unsupported wheel visibly droops")
	vehicle.global_position=Vector3(0,6.0,0)
	await physics_frame
	await physics_frame
	var airborne: Dictionary = SURFACE.probe(vehicle)
	check(int(airborne["count"])==0,"real airborne car has zero raycast contacts")
	var heights: Array[float] = airborne["travel"]
	check(heights.size()==4 and is_equal_approx(heights[0],SURFACE.MAX_DROOP),"airborne wheel travels extend safely")
	var source: String = FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
	check(source.contains("WHEEL_SURFACE.probe(self)") and source.contains("wheel_support[\"grounded\"]"),"actual car animation uses grounded wheel rays")
	var art_source: String = FileAccess.get_file_as_string("res://scripts/horizon_vehicle_art.gd")
	check(art_source.contains("WHEEL_SURFACE.terrain_attitude(contacts,grounded)"),"actual PBR car uses measured contact slope")
	check(art_source.contains("WHEEL_SURFACE.visual_travel"),"wheels droop when not grounded")
	vehicle.queue_free()
	stone.queue_free()
	floor.queue_free()
	print("HORIZON R21 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
