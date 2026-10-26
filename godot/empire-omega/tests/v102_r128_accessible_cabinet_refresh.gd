extends SceneTree
## R128 original engine B3: actual native phone target sizes, native focus
## and scroll persistence after real authoritative GameState notification.
## No image, UI mock, source mission mutation, or hardware-FPS claims.
var passed: int = 0
var failed: int = 0

func verify(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R128 REAL GODOT CABINET ACCESSIBILITY FAIL: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	verify(state != null, "authoritative GameState autoload exists")
	if state == null:
		quit(1)
		return
	var before: Dictionary = (state.get("data") as Dictionary).duplicate(true)
	var original_screen: Vector2i = root.size
	var script: Variant = load("res://scripts/hud.gd")
	verify(script is Script and script.can_instantiate(),
		"original imported Godot 4.4.1 HUD is executable")
	if not (script is Script and script.can_instantiate()):
		quit(1)
		return
	var hud: CanvasLayer = script.new()
	root.add_child(hud)
	var close_button: Button = hud.get("strategy_close_button") as Button
	var scroll: ScrollContainer = hud.get("strategy_scroll") as ScrollContainer
	var tabs: Dictionary = hud.get("strategy_nav_buttons") as Dictionary
	verify(close_button != null and scroll != null and tabs.size() == 4,
		"original interactive council, economy and district controls exist")
	if close_button == null or scroll == null or tabs.size() != 4:
		hud.queue_free()
		quit(1)
		return
	verify(close_button.custom_minimum_size.y >= 44.0 and
		close_button.focus_mode == Control.FOCUS_ALL,
		"real close input meets minimum 44px touch/keyboard focus area")
	verify(close_button.get_theme_stylebox("focus") is StyleBoxFlat,
		"original brass visible focus outline remains installed")
	for section in ["overview","council","economy","district"]:
		var button: Button = tabs.get(section) as Button
		verify(button != null, "real section tab exists: " + section)
		if button != null:
			verify(button.custom_minimum_size.y >= 44.0 and
				button.focus_mode == Control.FOCUS_ALL and
				button.pressed.is_connected(
					Callable(hud,"_jump_to_strategy_section").bind(section)),
				"real native mobile tab is >=44px, keyboard focusable and actionable: " + section)
	for dimensions in [Vector2i(320,568),Vector2i(390,844),
			Vector2i(844,390),Vector2i(1366,768)]:
		root.size = dimensions
		await process_frame
		hud.call("_apply_responsive_layout")
		if not bool(hud.get("open")):
			hud.call("toggle_strategy")
		await process_frame
		await process_frame
		verify(bool(hud.get("open")) and (hud.get("overlay") as ColorRect).visible,
			"actual cabinet opens at source viewport " + str(dimensions))
		verify(close_button.is_visible_in_tree(),
			"native real close button remains visible at " + str(dimensions))
		var operations: VBoxContainer = (hud.get("strategy_contents") as VBoxContainer).get_node_or_null(
			"R90LiveOperationsCabinet") as VBoxContainer
		verify(operations != null,
			"actual GameState-backed Godot command room survives responsive redraw")
		if operations != null:
			verify(operations.get("preview") is SubViewport and
				(operations.get("preview") as SubViewport).world_3d == root.world_3d,
				"actual live 3D city, not a static screenshot, remains visible")
		# Four original navigation actions must be accessible at 320px even if
		# the parent scroll container is long.
		for section in ["overview","council","economy","district"]:
			var button: Button = tabs[section] as Button
			verify(button.custom_minimum_size.y >= 44.0 and
				button.get_theme_stylebox("focus") is StyleBoxFlat,
				"real press and keyboard focus survive screen " + str(dimensions))
		# Economic/game events historically destroyed all scroll children
		# and silently returned the player to the top of the cabinet.
		scroll.scroll_vertical = 190
		await process_frame
		var before_scroll: int = scroll.scroll_vertical
		verify(before_scroll >= 90, "cabinet has genuine scrollable sections")
		state.emit_signal("state_changed","r128_verified_real_native_ui_refresh")
		await process_frame
		await process_frame
		verify(abs(scroll.scroll_vertical - before_scroll) <= 2,
			"real economic refresh retains native scroll at " + str(dimensions))
		verify((hud.get("strategy_contents") as VBoxContainer).get_node_or_null(
			"R90LiveOperationsCabinet") != null,
			"actual command scene remains interactive after state redraw")
		verify(state.get("data") == before,
			"UI responsive/scroll/focus never modify mission, wallet or saves")
	root.size = original_screen
	hud.queue_free()
	await process_frame
	print("EMPIRE OMEGA R128 ORIGINAL ACCESSIBLE CABINET: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed == 0 else 1)
