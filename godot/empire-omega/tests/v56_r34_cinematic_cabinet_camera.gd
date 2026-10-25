extends SceneTree
## R34: native cinematic government view without changing player input, physics,
## collision-safe camera authority or portrait/reduced-motion behaviour.
const RIG = preload("res://scripts/horizon_camera_collision.gd")
var passed := 0
var failed := 0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R34 CAMERA FAILED: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var desktop := Vector2(1366,768)
	var wide := Vector2(1920,1080)
	var small := Vector2(390,844)
	var landscape := Vector2(844,390)
	check(RIG.cabinet_cinema_enabled(true,desktop,false),"desktop government enables grounded cinematic shot")
	check(RIG.cabinet_cinema_enabled(true,wide,false),"high-resolution desktop uses same safe framing")
	check(not RIG.cabinet_cinema_enabled(false,desktop,false),"normal gameplay retains original camera")
	check(not RIG.cabinet_cinema_enabled(true,small,false),"portrait phone framing untouched")
	check(not RIG.cabinet_cinema_enabled(true,landscape,false),"landscape phone framing untouched")
	check(not RIG.cabinet_cinema_enabled(true,desktop,true),"reduced motion disables automatic camera framing")
	check(RIG.cabinet_pitch(0.4,true,desktop,false)<=0.221,"opened cabinet avoids top-down roof-map perspective")
	check(is_equal_approx(RIG.cabinet_pitch(0.4,false,desktop,false),0.4),"closing restores original pitch without saving a new value")
	check(is_equal_approx(RIG.cabinet_pitch(0.4,true,desktop,true),0.4),"accessibility respects original pitch")
	check(is_equal_approx(RIG.cabinet_pitch(0.18,true,desktop,false),0.18),"an already low-angle camera never gets lifted")
	check(is_equal_approx(RIG.cabinet_pitch(NAN,true,desktop,false),0.22),"non-finite camera input does not contaminate 3D transform")
	var focus := Vector3(10,2,22)
	var city := RIG.cabinet_focus(focus,0.0,true,desktop,false)
	check(city.z<focus.z and is_equal_approx(focus.distance_to(city),1.2),"shifts towards actual road, not rooftop")
	check(RIG.cabinet_focus(focus,0.0,false,desktop,false)==focus,"closing keeps original focus")
	check(RIG.cabinet_focus(focus,0.0,true,small,false)==focus,"phone focus has no cinematics")
	check(RIG.cabinet_focus(focus,0.0,true,desktop,true)==focus,"reduced motion has no camera focus animation")
	check(RIG.cabinet_focus(focus,NAN,true,desktop,false)==focus,"invalid heading guarded")
	check(RIG.cabinet_focus(Vector3(NAN,0,0),0.0,true,desktop,false)==Vector3.ZERO,"invalid world coordinate safe")
	var ideal: Vector3 = RIG.desired_position(city,0.0,RIG.cabinet_pitch(0.4,true,desktop,false),0.0,false,desktop)
	check(ideal.y>city.y and ideal.distance_to(city)<11.0,"new city look is a real grounded camera position")
	var main: Variant = load("res://scripts/main.gd")
	check(main!=null,"real main Godot scene script parses")
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(source.contains("SAFE_CAMERA.cabinet_pitch("),"live frame loop drives cinematic pitch")
	check(source.contains("SAFE_CAMERA.cabinet_focus("),"real Godot camera focus uses actual street heading")
	check(source.contains("SAFE_CAMERA.solve(focus,ideal,camera.global_position"),"all camera world collision checks remain authoritative")
	check(source.contains("SAFE_CAMERA.target_fov("),"existing accessibility & speed FOV preserved")
	print("EMPIRE OMEGA R34 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
