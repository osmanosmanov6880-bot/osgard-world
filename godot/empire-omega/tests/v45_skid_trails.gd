extends SceneTree
## R22 live GameWorld skid trails: real contact, bounded render pool, low GPU.
const TRAILS = preload("res://scripts/horizon_skid_trails.gd")
const SURFACE = preload("res://scripts/horizon_four_wheel_surface.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func check(ok: bool, label: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("HORIZON R22 FAILED: "+label)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(not TRAILS.drift_eligible(0.0,8.0,true),"stationary handbrake creates no tyre marks")
	check(not TRAILS.drift_eligible(20.0,0.5,false),"ordinary corner should not leave deep skid")
	check(TRAILS.drift_eligible(18.0,5.0,true),"realistic drifting under handbrake triggers marks")
	check(TRAILS.drift_eligible(18.0,5.0,false),"high-slip turn can skid without handbrake")
	check(not TRAILS.drift_eligible(NAN,7.0,true),"invalid car speed is ignored")
	check(TRAILS.mark_opacity(0.66)<TRAILS.mark_opacity(1.0),"wet tracks are less dark than dry")
	var floor := StaticBody3D.new()
	floor.collision_layer=1
	floor.position=Vector3(0,-0.3,0)
	var collider := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size=Vector3(40,0.6,40)
	collider.shape=shape
	floor.add_child(collider)
	root.add_child(floor)
	var car: CharacterBody3D = CAR.new()
	root.add_child(car)
	car.global_position=Vector3(0,0.86,0)
	for i in range(5):
		await physics_frame
	car.set_physics_process(false)
	var support: Dictionary = SURFACE.probe(car)
	check(int(support["count"])==4,"world-grounded sportscar has all four true physics hits")
	var marks: Node3D = TRAILS.new()
	root.add_child(marks)
	check(marks.get_node_or_null("GroundedRearTyreMultiMesh")!=null,"a real GPU batched tyre mark mesh exists")
	var pool: MultiMeshInstance3D = marks.get_node("GroundedRearTyreMultiMesh") as MultiMeshInstance3D
	check(pool.multimesh.instance_count==TRAILS.CAPACITY,"bounded GPU pool has fixed capacity")
	check(pool.multimesh.visible_instance_count==0,"no phantom tracks appear before driving")
	car.driving=true
	car.speed=18.0
	car.lateral_speed=5.0
	car.handbrake_on=true
	var first: int = marks.call("update_trails",car,true,"cinematic",1.0/60.0)
	check(first==0,"first frame only establishes tyre contact origins")
	var before: Vector3 = car.global_position
	car.global_position.z -= 0.45
	var second: int = marks.call("update_trails",car,true,"cinematic",1.0/60.0)
	check(second==2,"real ground contact leaves two independent rear-wheel segments")
	check(int(marks.get("emitted_segments"))==2,"drift is represented by two actual mesh instances")
	check(pool.multimesh.visible_instance_count==2,"GPU pool draws precisely the new contact trails")
	check(car.global_position.z < before.z,"mark rendering does not seize vehicle position")
	check(is_equal_approx(car.speed,18.0),"skid visual does not change powertrain physics")
	car.global_position.z -= 0.42
	var third: int = marks.call("update_trails",car,true,"standard",1.0/60.0)
	check(third==2,"standard quality still draws grounded skid marks")
	var count_before: int = int(marks.get("emitted_segments"))
	car.global_position.z -= 0.42
	var low: int = marks.call("update_trails",car,true,"low",1.0/60.0)
	check(low==0 and not pool.visible,"low GPU mode disables drawing and new segments")
	check(int(marks.get("emitted_segments"))==count_before,"low GPU mode never allocates extra geometry")
	marks.call("update_trails",car,true,"cinematic",1.0/60.0)
	check(pool.visible,"return from low tier restores mark renderer")
	car.global_position=Vector3(10,0.86,0)
	var teleport: int = marks.call("update_trails",car,true,"cinematic",1.0/60.0)
	check(teleport==0,"teleport never draws an unbounded rubber line")
	car.global_position.z -= 0.43
	check(int(marks.call("update_trails",car,true,"cinematic",1.0/60.0))==2,"skid resumes after safe short movement")
	var p: Vector3 = Vector3(0,0,0)
	marks.call("_break_streak")
	for i in range(TRAILS.CAPACITY+30):
		var position: Vector3 = Vector3(float(i)*0.41,0.0,0.0)
		marks.call("_record_track",0,position,0.42,TRAILS.MIN_SEGMENT)
	check(pool.multimesh.instance_count==TRAILS.CAPACITY,"repeated drifting does not grow instance memory")
	check(pool.multimesh.visible_instance_count<=TRAILS.CAPACITY,"rendered quads never exceed cap")
	check(int(marks.get("_filled"))==TRAILS.CAPACITY,"ring buffer cycles without changing maximum size")
	for i in range(70):
		marks.call("update_trails",car,false,"cinematic",0.25)
	check(int(marks.call("active_marks"))==0,"old rubber tracks fade after their bounded lifetime")
	car.global_position=Vector3(0,8,0)
	marks.call("_break_streak")
	car.speed=20.0
	car.lateral_speed=6.0
	var missing: int = marks.call("update_trails",car,true,"cinematic",0.016)
	check(missing==0,"airborne tyres cannot paint floating roads")
	var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_source.contains("skid_trails.call(\"update_trails\",car,driving,adaptive_graphics.effective_quality(),delta)"),"real game loop owns skid effects")
	check(main_source.contains("SKID_SCENE.new()"),"real play scene instantiates a single pooled renderer")
	check(main_source.contains("soundscape.update_cues("),"R19 vehicle audio retained")
	car.queue_free()
	marks.queue_free()
	floor.queue_free()
	print("HORIZON R22 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
