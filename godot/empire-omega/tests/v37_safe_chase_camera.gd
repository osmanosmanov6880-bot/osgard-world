extends SceneTree
## HORIZON R14. Actual Godot 4.4.1 collision queries against a real StaticBody
## wall; failed camera clipping cannot be hidden by a pretty HUD screenshot.
const RIG = preload("res://scripts/horizon_camera_collision.gd")
var passed := 0
var failed := 0

func verify(ok: bool, detail: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R14 CAMERA: "+detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var stage := Node3D.new()
	stage.name = "CameraWallTest"
	root.add_child(stage)
	var wall := StaticBody3D.new()
	wall.name = "SolidBuilding"
	wall.collision_layer = 1
	wall.collision_mask = 1
	wall.position = Vector3(0,2,5)
	var collision := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(24,8,1)
	collision.shape = shape
	wall.add_child(collision)
	stage.add_child(wall)
	await physics_frame
	await physics_frame
	var space: PhysicsDirectSpaceState3D = stage.get_world_3d().direct_space_state
	var exclude: Array[RID] = []
	var focus := Vector3(0,2,0)
	var desired := Vector3(0,4,12)
	var blocked: Dictionary = RIG.solve(focus,desired,desired,space,exclude,1.0/60.0,true)
	verify(bool(blocked["occluded"]),"a real building occludes the camera")
	var hit_position: Vector3 = blocked["position"]
	verify(hit_position.z > 2.0 and hit_position.z < 4.5,"camera snaps to safe side of solid wall")
	verify(hit_position.distance_to(focus)>0.5,"camera remains at a usable distance from driver")
	verify(is_finite(float(blocked["distance"])),"camera reports valid physical distance")
	var no_time: Dictionary = RIG.solve(focus,desired,desired,space,exclude,0.0,false)
	verify(float((no_time["position"] as Vector3).z) < 4.6,"second ray stops camera tunneling even at zero frame time")
	var goal_after_turn := Vector3(7,3,13)
	var turning: Dictionary = RIG.solve(focus,goal_after_turn,desired,space,exclude,0.1,false)
	verify((turning["position"] as Vector3).z < 5.0,"camera turn interpolation remains on safe side of wall")
	var exclude_wall: Array[RID] = [wall.get_rid()]
	var ignored: Dictionary = RIG.solve(focus,desired,hit_position,space,exclude_wall,1.0/60.0,true)
	verify(not bool(ignored["occluded"]),"camera respects controlled body RIDs in physics mask")
	verify((ignored["position"] as Vector3).distance_to(desired)<0.001,"excluded geometry never shortens camera view")
	wall.collision_layer = 0
	await physics_frame
	await physics_frame
	var easing: Dictionary = RIG.solve(focus,desired,hit_position,space,exclude,1.0/60.0,false)
	var eased: Vector3 = easing["position"]
	verify(not bool(easing["occluded"]),"released wall no longer blocks the view")
	verify(eased.z > hit_position.z and eased.z < desired.z,"camera slowly eases out without snapping")
	var reduced: Dictionary = RIG.solve(focus,desired,eased,space,exclude,1.0/60.0,true)
	verify((reduced["position"] as Vector3).distance_to(desired)<0.001,"reduced-motion preference skips animated zoom")
	var zero_delta: Dictionary = RIG.solve(focus,desired,eased,space,exclude,0.0,false)
	verify((zero_delta["position"] as Vector3).distance_to(eased)<0.001,"paused simulation does not move camera")
	verify(RIG.portrait(Vector2(390,844)),"real touch phone detected")
	verify(RIG.portrait(Vector2(768,1024)),"tablet portrait detected")
	verify(not RIG.portrait(Vector2(1366,768)),"desktop viewport is not mistaken for phone portrait")
	verify(not RIG.portrait(Vector2(844,390)),"mobile landscape maintains normal framing")
	var phone: Vector3 = RIG.desired_position(focus,0.0,0.38,23.0,true,Vector2(390,844))
	var desk: Vector3 = RIG.desired_position(focus,0.0,0.38,23.0,true,Vector2(1366,768))
	verify(focus.distance_to(phone) < focus.distance_to(desk),"portrait car framing keeps the vehicle larger on a narrow screen")
	verify(phone.z>0 and desk.z>phone.z,"chase camera remains behind moving vehicle")
	var standing: Vector3 = RIG.desired_position(focus,0.0,0.38,0.0,false,Vector2(390,844))
	verify(standing.distance_to(focus) < phone.distance_to(focus),"walking camera follows closer than high-speed driving")
	var extreme_speed: Vector3 = RIG.desired_position(focus,0.0,0.38,10000.0,true,Vector2(390,844))
	verify(focus.distance_to(extreme_speed) < 17.0,"very high speed has a camera distance cap")
	verify(RIG.follow_rate(24.0,true)>RIG.follow_rate(24.0,false),"mobile heading catches turns faster than desktop")
	verify(RIG.follow_rate(24.0,true)>RIG.follow_rate(0.0,true),"high-speed car yaw recovery is responsive")
	verify(RIG.follow_rate(50000.0,true)<3.0,"yaw follow rate is bounded at very high speed")
	var invalid: Dictionary = RIG.solve(focus,Vector3(NAN,0,0),eased,space,exclude,0.1,false)
	verify(bool(invalid["occluded"]) and (invalid["position"] as Vector3) == focus,"nonfinite target fails safely")
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	verify(source.contains("SAFE_CAMERA.desired_position(focus,cam_yaw,camera_pitch,car.speed,driving,viewport_size)") and
		source.contains("SAFE_CAMERA.cabinet_pitch(cam_pitch,cabinet_open,viewport_size,GameSettings.reduced_motion)") and
		source.contains("SAFE_CAMERA.cabinet_focus(focus,cam_yaw,cabinet_open,viewport_size,GameSettings.reduced_motion)"),
		"real R14 collision-safe portrait camera retains its viewport plus R34 bounded cabinet framing")
	verify(source.contains("SAFE_CAMERA.solve(focus,ideal,camera.global_position,"),"live third-person camera uses two-stage obstacle safety")
	verify(not source.contains("ideal = result[\"position\"]"),"old unsafe single-ray camera removed")
	wall.queue_free()
	stage.queue_free()
	print("HORIZON R14 CAMERA NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
