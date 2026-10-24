extends SceneTree
## R20 native Godot: chase camera composition and mobile motion guardrails.
const RIG = preload("res://scripts/horizon_camera_collision.gd")
var passed := 0
var failed := 0

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R20 FAILED: "+description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var car := Vector3(12.0,1.0,24.0)
	var phone := Vector2(390.0,844.0)
	var desktop := Vector2(1920.0,1080.0)
	var at_rest: Vector3 = RIG.look_ahead_focus(car,0.0,0.0,0.0,phone,false)
	check(at_rest == car+Vector3(0,2,0),"stopped car has no artificial lookahead")
	var moving_phone: Vector3 = RIG.look_ahead_focus(car,0.0,27.0,0.0,phone,false)
	var moving_desktop: Vector3 = RIG.look_ahead_focus(car,0.0,27.0,0.0,desktop,false)
	check(moving_phone.z < at_rest.z,"speed gives more view of road ahead in portrait")
	check(moving_desktop.z < moving_phone.z,"desktop has more lookahead than tall phone")
	var reversing: Vector3 = RIG.look_ahead_focus(car,0.0,-9.0,0.0,desktop,false)
	check(reversing.z > at_rest.z,"reverse gear looks toward actual backward travel")
	check(at_rest.distance_to(moving_phone)<1.41,"phone camera lookahead stays capped")
	var corner: Vector3 = RIG.look_ahead_focus(car,0.0,22.0,0.45,desktop,false)
	check(corner.x > moving_desktop.x,"corner anticipates road toward positive steering")
	var corner_other: Vector3 = RIG.look_ahead_focus(car,0.0,22.0,-0.45,desktop,false)
	check(corner_other.x < moving_desktop.x,"opposite turn tracks opposite road direction")
	var still: Vector3 = RIG.look_ahead_focus(car,0.0,30.0,1.0,phone,true)
	check(still == at_rest,"reduced motion disables speed and turn lookahead")
	check(RIG.look_ahead_focus(car,NAN,20.0,0.0,phone,false)==at_rest,"invalid yaw does not create corrupt camera focus")
	check(RIG.target_fov(0.0,false,false,false)==76.0,"walking has stable comfortable FOV")
	check(RIG.target_fov(35.0,true,true,true)==76.0,"reduced motion disables speed-FOV effects")
	check(RIG.target_fov(27.0,true,true,false)<RIG.target_fov(27.0,true,false,false),"portrait reduces peripheral distortion")
	check(RIG.target_fov(10000.0,true,false,false)<=83.0,"extreme speed never produces fish-eye view")
	check(RIG.target_fov(10000.0,true,true,false)<=81.0,"tall mobile stays within narrow speed-FOV range")
	check(RIG.target_fov(NAN,true,false,false)==77.0,"invalid speed cannot break FOV")
	var one: float = RIG.time_alpha(2.2,1.0/30.0)
	var half: float = RIG.time_alpha(2.2,1.0/60.0)
	check(absf(one-(half+(1.0-half)*half))<0.0001,"camera smoothing has equal 30/60 FPS response")
	check(RIG.time_alpha(2.2,0.0)==0.0,"pause does not advance camera animation")
	check(RIG.time_alpha(2.2,NAN)==0.0,"invalid frame time does not advance camera")
	check(RIG.time_alpha(100000.0,500.0)<=1.0,"large browser resume cannot overrun interpolation")
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("SAFE_CAMERA.look_ahead_focus("),"real game uses road-ahead camera focus")
	check(main.contains("SAFE_CAMERA.target_fov(car.speed,driving,phone_view,GameSettings.reduced_motion)"),"real game applies reduced-motion and portrait FOV rules")
	check(main.contains("SAFE_CAMERA.solve(focus,ideal,camera.global_position,"),"real game preserves obstruction-safe camera rays")
	check(main.contains("SAFE_CAMERA.time_alpha(SAFE_CAMERA.follow_rate"),"real camera turn smoothing is frame-rate aware")
	print("HORIZON R20 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
