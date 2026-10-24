extends SceneTree
## HORIZON R12: regression for the real 390x844 Chromium screenshot that
## previously rendered only y=312..530 (219px of 844, 74% black bars).
const SCREEN = preload("res://scripts/horizon_portrait_screen.gd")
const TOUCH = preload("res://scripts/horizon_touch_controls.gd")
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R12 PORTRAIT: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(str(ProjectSettings.get_setting("display/window/stretch/mode"))=="canvas_items","native Godot UI retains canvas_items")
	check(str(ProjectSettings.get_setting("display/window/stretch/aspect"))=="expand","real phone viewport expands instead of keep/black letterboxes")
	for width_height in [Vector2i(390,844),Vector2i(360,780),Vector2i(412,915),Vector2i(768,1024)]:
		check(SCREEN.is_phone_portrait(width_height),"portrait detected "+str(width_height))
		check(is_equal_approx(SCREEN.content_factor(width_height),2.4),"mobile HUD is enlarged "+str(width_height))
	for width_height in [Vector2i(1366,768),Vector2i(1600,900),Vector2i(390,600),Vector2i(1920,1080)]:
		check(not SCREEN.is_phone_portrait(width_height),"no false mobile match "+str(width_height))
		check(is_equal_approx(SCREEN.content_factor(width_height),1.0),"desktop and landscape remain 1:1 "+str(width_height))
	var main := FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("PORTRAIT_SCREEN.apply_to(get_window())"),"actual world applies Web viewport policy")
	check(main.contains("get_window().size_changed.connect(_refresh_portrait_fit)"),"mobile orientation changes update layout")
	check(main.find("_refresh_portrait_fit()") < main.find("hud = HUD_SCENE.new()"),"mobile scale set before HUD is created")
	var original_factor: float = root.content_scale_factor
	var original_aspect: int = root.content_scale_aspect
	check(SCREEN.apply_to(root,Vector2i(390,844)),"simulated 390x844 triggers mobile mode in real Window")
	check(root.content_scale_aspect == Window.CONTENT_SCALE_ASPECT_EXPAND,"Window aspect set to EXPAND")
	check(is_equal_approx(root.content_scale_factor,2.4),"live Window sets actual phone UI scale")
	check(SCREEN.apply_to(root,Vector2i(390,844)),"idempotent resize has no unbounded update loop")
	check(is_equal_approx(root.content_scale_factor,2.4),"repeated portrait resize is stable")
	check(not SCREEN.apply_to(root,Vector2i(1366,768)),"return to desktop mode")
	check(is_equal_approx(root.content_scale_factor,1.0),"desktop UI is not over-enlarged")
	root.content_scale_factor = original_factor
	root.content_scale_aspect = original_aspect
	check(TOUCH != null,"native eight-button touch HUD remains wired")
	print("HORIZON R12 PORTRAIT NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
