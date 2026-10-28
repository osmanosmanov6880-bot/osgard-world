extends SceneTree
## R125 native source-level regression. No screenshot mocks and no state writes.
## Desktop command center must retain an honest aperture to the original
## GameState-controlled playable World3D while compact layout stays intact.
const STYLE = preload("res://scripts/horizon_r90_reference_style.gd")
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R125 DESKTOP LIVE CITY APERTURE FAIL: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null, "original authoritative GameState is loaded")
	if game == null:
		quit(1)
		return
	var before: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var original_size: Vector2i = root.size
	var script: Variant = load("res://scripts/hud.gd")
	check(script is Script and script.can_instantiate(),
		"real original HUD imports under Godot 4.4.1")
	if not (script is Script and script.can_instantiate()):
		quit(1)
		return
	var hud: CanvasLayer = script.new()
	root.add_child(hud)
	var scrim: ColorRect = hud.get("overlay") as ColorRect
	var window: PanelContainer = hud.get("strategy_window") as PanelContainer
	check(scrim != null and window != null,
		"actual native command scrim and interactive panel exist")
	if scrim == null or window == null:
		hud.queue_free()
		quit(1)
		return
	for dimensions in [Vector2i(1200,680), Vector2i(1366,768), Vector2i(1920,1080)]:
		root.size = dimensions
		await process_frame
		hud.call("_apply_responsive_layout")
		var screen: Vector2 = root.get_visible_rect().size
		var frame: Rect2 = STYLE.command_center_frame(screen)
		check(frame.position.x >= 12.0 and frame.position.y >= 10.0,
			"desktop command stays within authored safe margins")
		check(frame.end.x <= screen.x - 120.0 and frame.end.y <= screen.y,
			"wide native window reserves an actual uncovered city aperture")
		check(frame.size.x >= 1020.0 and frame.size.y >= 640.0,
			"command center keeps real operating room readable and usable")
		check(is_equal_approx(window.offset_left,frame.position.x) and
			is_equal_approx(window.offset_right,frame.end.x),
			"real HUD applies safe R125 frame instead of drawing a concept PNG")
		check(is_equal_approx(scrim.color.a,0.18) and
			scrim.mouse_filter == Control.MOUSE_FILTER_STOP,
			"wide original 3D street remains visible; input still blocked behind governance")
	check(hud.get("strategy_close_button") is Button,
		"real mouse/keyboard close control survives narrower desktop cabinet")
	root.size = Vector2i(390,844)
	await process_frame
	hud.call("_apply_responsive_layout")
	check(is_equal_approx(scrim.color.a,0.36),
		"portrait restores its original high-contrast modal scrim")
	check(hud.get("r90_legacy_navigation") != null,
		"compact game still has original accessible native navigation")
	check(game.get("data") == before,
		"visual-only command width/scrim never touches missions, economy, or saves")
	root.size = original_size
	hud.queue_free()
	await process_frame
	print("EMPIRE OMEGA R125 honest live 3D aperture: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed == 0 else 1)
