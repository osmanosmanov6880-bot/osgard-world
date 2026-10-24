extends SceneTree
## R12.1: square reference pixels + vertical FOV, with physically grounded
## geometry for 390x844 portrait and original 16:9 desktop sizes.
## This is native proof of configuration and responsive layout; the browser
## WebGL screenshot gate separately measures actual black pixels.
const SCREEN = preload("res://scripts/horizon_portrait_screen.gd")
const LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON PORTRAIT R12.1 FAILED: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var w: int = int(ProjectSettings.get_setting("display/window/size/viewport_width"))
	var h: int = int(ProjectSettings.get_setting("display/window/size/viewport_height"))
	check(w == 900 and h == 900,"square native design area is 900x900")
	check(ProjectSettings.get_setting("display/window/stretch/mode")=="canvas_items","retain real vector HUD scaling")
	check(ProjectSettings.get_setting("display/window/stretch/aspect")=="expand","window must expand in both axes")
	var win: Window = root
	var old_aspect: int = win.content_scale_aspect
	var old_scale: float = win.content_scale_factor
	check(SCREEN.apply_to(win,Vector2i(390,844)),"real 390x844 recognized as portrait")
	check(win.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND,"explicit expand overrides a runtime keep aspect")
	check(is_equal_approx(win.content_scale_factor,2.4),"mobile HUD scale is finger readable")
	var portrait_width: float = float(w)/win.content_scale_factor
	var portrait_height: float = float(h)*844.0/390.0/win.content_scale_factor
	check(portrait_width >= 360.0 and portrait_width <= 400.0,"portrait logical width matches the actual phone")
	check(portrait_height >= 775.0 and portrait_height <= 830.0,"portrait frame extends the game vertically instead of clipping")
	var mobile_layout: Dictionary = LAYOUT.compute(Vector2(portrait_width,portrait_height))
	check(bool(mobile_layout.get("compact",false)),"full height uses the real compact HUD")
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("Camera3D.KEEP_WIDTH"),"portrait camera keeps width instead of letterboxing a 16:9 view")
	check(main.contains("Camera3D.KEEP_HEIGHT"),"original desktop Hor+ framing remains available")
	check(main.contains("_refresh_portrait_fit()\n\tcamera.global_position"),"actual initialized camera receives portrait settings")
	for dims in [Vector2i(1366,768),Vector2i(1600,900),Vector2i(1920,1080)]:
		check(not SCREEN.apply_to(win,dims),"desktop/landscape never receives phone scale "+str(dims))
		check(is_equal_approx(win.content_scale_factor,1.0),"desktop content scale remains 1 "+str(dims))
	var desktop_width: float = float(w)*1366.0/768.0
	check(absf(desktop_width-1600.8)<2.0,"square base preserves the original 1600x900 desktop field of view")
	check(SCREEN.apply_to(win,Vector2i(390,844)),"portrait mode reactivates after rotation")
	check(is_equal_approx(win.content_scale_factor,2.4),"phone rotation response is idempotent")
	win.content_scale_aspect = old_aspect
	win.content_scale_factor = old_scale
	print("HORIZON R12.1 FULL PORTRAIT NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
