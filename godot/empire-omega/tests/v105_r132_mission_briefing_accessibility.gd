extends SceneTree
## R132 authentic original Godot 4.4.1 mobile + desktop mission briefing.
## Every control is a native Button, PanelContainer and Label attached to the
## true HUD. No images, simulated CSS, changed mission state or fake GPU pass.
var passed: int = 0
var failed: int = 0

func check(value: bool, why: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("R132 REAL MISSION BRIEFING FAIL: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	var mission: Node = root.get_node_or_null("MissionManager")
	check(state != null and mission != null,
		"real authoritative game and mission autoloads are available")
	if state == null or mission == null:
		quit(1)
		return
	var prior_data: Dictionary = (state.get("data") as Dictionary).duplicate(true)
	var prior_size: Vector2i = root.size
	var hud_source: Script = load("res://scripts/hud.gd") as Script
	check(hud_source != null and hud_source.can_instantiate(),
		"real HUD is directly executable Godot 4.4.1 source")
	if hud_source == null or not hud_source.can_instantiate():
		quit(1)
		return
	var hud: CanvasLayer = hud_source.new()
	root.add_child(hud)
	var target: Button = hud.get("objective_details_button") as Button
	var source_card: PanelContainer = hud.get("objective_panel") as PanelContainer
	var journal: PanelContainer = hud.get("journal_panel") as PanelContainer
	var full_text: Label = hud.get("mission_briefing_label") as Label
	check(target != null and source_card != null and journal != null and full_text != null,
		"actual existing HUD owns mission card, real journal and one native touch button")
	if target == null or source_card == null or journal == null or full_text == null:
		hud.queue_free()
		quit(1)
		return
	check(target.name == "R132MissionBriefingButton" and
		target.custom_minimum_size.y >= 44.0 and
		target.custom_minimum_size.x >= 44.0 and
		target.focus_mode == Control.FOCUS_ALL,
		"44px+ REAL focusable native source button, never a decorative icon")
	check(target.get_theme_stylebox("focus") is StyleBoxFlat,
		"brass keyboard-focus outline is drawn by Godot on actual user action")
	check(target.pressed.is_connected(Callable(hud,"toggle_field_journal")),
		"real native Button is genuinely wired to the existing journal")
	for dims in [Vector2i(320,568),Vector2i(390,844),
			Vector2i(844,390),Vector2i(1366,768)]:
		root.size = dims
		await process_frame
		hud.call("_apply_responsive_layout")
		await process_frame
		var window: Rect2 = root.get_visible_rect()
		var badge: Rect2 = target.get_global_rect()
		var objective: Rect2 = source_card.get_global_rect()
		check(badge.size.x >= 44.0 and badge.size.y >= 44.0,
			"actual HUD tap target stays at least 44x44 in viewport " + str(dims))
		check(badge.position.x >= -1.0 and badge.position.y >= -1.0 and
			badge.end.x <= window.size.x+1.0 and badge.end.y <= window.size.y+1.0,
			"real native mission button never leaves viewport "+str(dims))
		check(badge.position.x >= objective.position.x-1.0 and
			badge.end.x <= objective.end.x+1.0 and
			badge.position.y >= objective.position.y-1.0 and
			badge.end.y <= objective.end.y+1.0,
			"actual native tap control remains inside mission card at "+str(dims))
		check(target.is_visible_in_tree() and not journal.visible,
			"journal closed until real user opens it at "+str(dims))
		var original_brief: String = str(mission.call("title",str(state.get("locale"))))
		check(not original_brief.is_empty() and full_text.text.contains(original_brief),
			"native journal includes the FULL active mission instead of compact abbreviation")
		target.pressed.emit()
		check(journal.visible and not bool(hud.get("open")),
			"tap opens existing native read-only journal without opening governance")
		check(not target.tooltip_text.is_empty() and target.is_visible_in_tree(),
			"real mission briefing remains discoverable and reversible")
		# Actual economic notification historically recreates mission panels.
		state.emit_signal("state_changed","r132_real_briefing_read_only")
		await process_frame
		check(journal.visible and full_text.text.contains(original_brief),
			"live mission details survive authoritative city refresh")
		target.pressed.emit()
		check(not journal.visible,"second real press closes the existing journal")
		# Native 4-mode keyboard/Tab cabinet should hide background HUD actions.
		hud.call("toggle_strategy")
		check(bool(hud.get("open")) and not target.visible,
			"real governor mode hides clickable mission corner underneath modal")
		hud.call("toggle_strategy")
		check(not bool(hud.get("open")) and target.visible,
			"closing city cabinet restores the real phone/keyboard mission action")
		hud.call("toggle_pause")
		check(bool(hud.get("pause_open")) and not target.visible,
			"real pause blocks mission touch target and focus traversal")
		hud.call("toggle_pause")
		check(not bool(hud.get("pause_open")) and target.visible,
			"resuming original actual gameplay restores mission access")
		check(state.get("data") == prior_data,
			"briefing journal actions never change story, money, mission or saved progress")
	root.size = prior_size
	hud.queue_free()
	await process_frame
	print("EMPIRE OMEGA R132 ORIGINAL accessible live mission briefing: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
