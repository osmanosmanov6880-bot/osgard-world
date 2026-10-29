extends SceneTree
## R166 physically aligned existing 96-quad rear tyre trace ring.
## Real collision normals are sampled through the original four wheel rays.
const SKID = preload("res://scripts/horizon_skid_trails.gd")
const SURFACE = preload("res://scripts/horizon_four_wheel_surface.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func check(ok: bool,what: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R166 ROAD NORMAL FAIL: "+what)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var floor := StaticBody3D.new()
	floor.collision_layer = 1
	floor.position = Vector3(0,-0.30,0)
	floor.rotation.x = 0.11
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size=Vector3(70,0.60,70)
	shape.shape=box
	floor.add_child(shape)
	root.add_child(floor)
	var car: CharacterBody3D = CAR.new()
	car.position=Vector3(0,0.86,0)
	root.add_child(car)
	for i in range(5): await physics_frame
	car.set_physics_process(false)
	var sampled: Dictionary = SURFACE.probe(car)
	check(int(sampled["count"])>=2,
		"two or more actual tyres have measured real sloped road collisions")
	var road_normal: Vector3 = (sampled["normals"] as Array)[0]
	check(road_normal.is_finite() and road_normal.y>0.45,
		"original Godot PhysicsDirectSpaceState returns finite sloped road normals")
	var marks: Node3D=SKID.new()
	root.add_child(marks)
	var mesh: MultiMeshInstance3D=marks.get_node("GroundedRearTyreMultiMesh")
	var original_mesh: Mesh=mesh.multimesh.mesh
	var first: bool=marks._record_track(0,Vector3(0,0,0),0.38,0.22,road_normal)
	var second: bool=marks._record_track(0,Vector3(0,0,0.41),0.38,0.22,road_normal)
	check(not first and second,
		"real contact creates segment only after a measurable second grounded movement")
	# Read back the exact source-computed transform submitted to MultiMesh.
	# Headless RenderingServer may report identity on GPU transform readback.
	var transform: Transform3D=marks.last_record_transform
	check(transform.basis.y.normalized().dot(road_normal)>0.99,
		"pooled rubber quad lies along the actual sloped road normal")
	var tangent_dot: float = transform.basis.z.normalized().dot(road_normal)
	print("R166 SOURCE TRACK BASIS: road=",road_normal," submittedY=",transform.basis.y,
		" submittedZ=",transform.basis.z," dot=",tangent_dot)
	check(absf(tangent_dot)<0.02,
		"tyre segment tangent follows the real asphalt plane; measured dot "+str(tangent_dot))
	check(mesh.multimesh.instance_count==SKID.CAPACITY and
		mesh.multimesh.visible_instance_count==1,
		"existing fixed GPU ring does not grow per frame")
	var far: bool=marks._record_track(0,Vector3(12,0,12),0.40,0.22,road_normal)
	check(not far and mesh.multimesh.visible_instance_count==1,
		"car teleports cannot paint a massive track across city")
	marks._break_streak()
	marks._record_track(1,Vector3(0,0,0),0.4,0.22,Vector3.DOWN)
	marks._record_track(1,Vector3(0,0,-0.4),0.4,0.22,Vector3.DOWN)
	var fallback: Transform3D=marks.last_record_transform
	check(fallback.basis.y.normalized().dot(Vector3.UP)>0.99,
		"invalid underside road normals never invert visible tyre geometry")
	for i in range(SKID.CAPACITY+15):
		var center: Vector3=Vector3(float(i)*0.4,0,0)
		marks._record_track(1,center,0.35,0.22,road_normal)
	check(mesh.multimesh.instance_count==SKID.CAPACITY and
		mesh.multimesh.visible_instance_count<=SKID.CAPACITY and
		mesh.multimesh.mesh==original_mesh,
		"100+ real segments reuse the exact same original mesh resource")
	marks.update_trails(car,false,"low",1.0/60.0)
	check(not mesh.visible and mesh.multimesh.instance_count==SKID.CAPACITY,
		"LOW tier still deactivates tyre effect with no allocations")
	var source: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(source.contains('skid_trails.call("update_trails",car,driving,adaptive_graphics.effective_quality(),delta)'),
		"the actual game loop still owns tire trails with adaptive graphics")
	car.queue_free()
	floor.queue_free()
	marks.queue_free()
	await process_frame
	print("CITY REIGN R166 SLOPE-REAL RUBBER TRACKS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
