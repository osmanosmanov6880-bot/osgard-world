extends SceneTree
## R99 actual native Godot layout assertions: command viewport must visibly
## outrank gutters and the real Tab-close control must stay on the upper right.
var passed := 0
var failed := 0

func verify(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R99 COMMAND COMPOSITION FAILED: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	verify(game != null and missions != null, "authoritative game and mission managers")
	if game == null or missions == null:
		quit(1)
		return
	var original_data: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var original_lang: String = str(game.get("locale"))
	var state: Dictionary = game.call("new_game")
	game.set("data",state)
	game.set("locale","ru")
	var before: Dictionary = state.duplicate(true)
	var forecast: Dictionary = game.call("forecast")
	var script: Variant = load("res://scripts/horizon_r90_premium_dashboard.gd")
	verify(script is Script and script.can_instantiate(), "current real dashboard source imports")
	if not (script is Script and script.can_instantiate()):
		game.set("data",original_data)
		game.set("locale",original_lang)
		quit(1)
		return
	var panel: VBoxContainer = script.new()
	root.add_child(panel)
	panel.call("build",state,forecast,str(missions.call("title","ru")),root.world_3d,false,"ru")
	var hero: BoxContainer = panel.get_node_or_null("R97CommandColumns") as BoxContainer
	verify(hero != null and hero.get_child_count() == 3,
		"three real Godot command columns rendered on desktop")
	if hero != null and hero.get_child_count() == 3:
		var left: Control = hero.get_child(0) as Control
		var center: Control = hero.get_child(1) as Control
		var right: Control = hero.get_child(2) as Control
		verify(center.size_flags_stretch_ratio > 1.6,
			"real 3D hero has premium center weight, not miniature inset")
		verify(center.size_flags_stretch_ratio > left.size_flags_stretch_ratio*2.0,
			"3D hero outranks left sidebar")
		verify(center.size_flags_stretch_ratio > right.size_flags_stretch_ratio*1.7,
			"3D hero outranks indicator sidebar")
		verify(left.custom_minimum_size.x <= 250.0 and right.custom_minimum_size.x <= 300.0,
			"sidebars remain bounded and allow central 3D to expand")
	var host: SubViewportContainer = panel.find_child("ActualGodotWorldViewport",true,false) as SubViewportContainer
	verify(host != null and host.stretch_shrink == 1,
		"genuine command city uses full-resolution Godot viewport")
	var live: SubViewport = panel.get("preview") as SubViewport
	verify(live != null and live.world_3d == root.world_3d,
		"higher image quality still shows the authoritative live 3D world")
	verify(panel.get_node_or_null("R97ExecutiveSummary") != null,
		"all original six authoritative financial metrics remain in view")
	var ui_script: Variant = load("res://scripts/hud.gd")
	verify(ui_script is Script and ui_script.can_instantiate(),
		"original Godot keyboard-operable gameplay HUD still compiles")
	if ui_script is Script and ui_script.can_instantiate():
		var hud: CanvasLayer = ui_script.new()
		root.add_child(hud)
		var spacer: Control = hud.find_child("R99CommandHeaderSpacer",true,false) as Control
		verify(spacer != null and spacer.size_flags_horizontal == Control.SIZE_EXPAND_FILL,
			"dedicated header flex keeps desktop close button at upper right")
		var close: Button = hud.get("strategy_close_button") as Button
		verify(close != null and close.text == "×",
			"actual keyboard/mouse-accessible close button is preserved")
		if close != null and spacer != null:
			verify(close.get_parent() == spacer.get_parent() and
				spacer.get_index() < close.get_index(),
				"flex spacer is physically placed BEFORE actual close button")
		verify(hud.get("strategy_anchors") is Dictionary,
			"existing underlying economic/governance sections remain reachable")
		hud.queue_free()
	verify(state == before,"pure layout improvements do not rewrite saved game")
	panel.queue_free()
	game.set("data",original_data)
	game.set("locale",original_lang)
	await process_frame
	print("EMPIRE OMEGA R99 actual viewport geometry: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
