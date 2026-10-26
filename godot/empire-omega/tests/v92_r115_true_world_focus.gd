extends SceneTree
## R115: actual Godot 3D fullscreen-like atlas, not a mock image.
## Original source cards, actions, world, city metrics and saved games persist.
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R115 CINEMATIC CITY FOCUS FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	check(game != null and missions != null,"real authoritative game and 40 missions")
	if game == null or missions == null:
		quit(1)
		return
	var old: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var language: String = str(game.get("locale"))
	var current: Dictionary = game.call("new_game")
	game.set("data",current)
	game.set("locale","ru")
	var source: Dictionary = current.duplicate(true)
	var forecast: Dictionary = game.call("forecast")
	var dashboard_source: Variant = load("res://scripts/horizon_r90_premium_dashboard.gd")
	check(dashboard_source is Script and dashboard_source.can_instantiate(),
		"real current Godot cabinet with focus compiles")
	if not (dashboard_source is Script and dashboard_source.can_instantiate()):
		game.set("data",old)
		game.set("locale",language)
		quit(1)
		return
	var panel: VBoxContainer = dashboard_source.new()
	root.add_child(panel)
	panel.call("build",current,forecast,str(missions.call("title","ru")),
		root.world_3d,false,"ru")
	var controls: Button = panel.find_child("R115CinematicFocusToggle",true,false) as Button
	var cols: BoxContainer = panel.get_node_or_null("R97CommandColumns") as BoxContainer
	var stats: Container = panel.get_node_or_null("R97ExecutiveSummary") as Container
	var atlas: Control = panel.find_child("R112AtlasCameraControls",true,false)
	var viewport: SubViewport = panel.get("preview") as SubViewport
	check(controls is Button and (controls as Button).focus_mode == Control.FOCUS_ALL,
		"live focus toggle is a real Godot keyboard and pointer-accessible button")
	check(cols != null and cols.get_child_count()==3,
		"original mission / city / economy cards kept in original 3 columns")
	check(atlas != null and atlas.get_child_count()==2,
		"R112 original overview/details controls remain at exactly two")
	check(stats != null and stats.get_child_count()==6,
		"all six authoritative original finance and political metrics preserved")
	check(viewport != null and viewport.world_3d == root.world_3d,
		"focus uses the ONE real original World3D and existing rendering camera")
	var before_scene: SubViewport = viewport
	if cols != null and cols.get_child_count()==3 and controls is Button:
		var left: Control = cols.get_child(0) as Control
		var center: Control = cols.get_child(1) as Control
		var right: Control = cols.get_child(2) as Control
		check(left.visible and right.visible and center.visible,
			"original actionable sidebars visible before focus")
		(controls as Button).pressed.emit()
		check(bool(panel.get("city_focus_active")),
			"real button activates full-width cinematic city mode")
		check(not left.visible and not right.visible and center.visible,
			"only real original sidebars hide, existing city stage remains visible")
		check(stats != null and not stats.visible,
			"executive metrics remain mounted but are visually collapsed in focus")
		check(is_equal_approx(center.size_flags_stretch_ratio,1.0),
			"true remaining central Godot city fills the HBox layout")
		check(cols.custom_minimum_size.y >= 565.0 and
			(panel.get("focus_stage") as Control).custom_minimum_size.y >= 548.0,
			"original city rendering region physically grows taller, not only wider")
		check(viewport == before_scene and viewport.get_child_count()==1,
			"no additional rendering pass, substitution or World3D reallocation")
		check(controls.text.contains("ВЕРНУТЬ"),
			"real exit state is clear to a Russian-language player")
		# Real camera inspection and district selection are still interactive.
		panel.call("_switch_atlas_mode","architecture")
		check(str(panel.get("atlas_mode"))=="architecture",
			"R112 true 3D camera remains usable in focus mode")
		panel.call("_switch_atlas_mode","overview")
		var changed: Array[String] = []
		panel.connect("select_district",func(id: String): changed.append(id))
		var district: Button = panel.find_child("R90DistrictPin_forum",true,false) as Button
		if district != null:
			district.pressed.emit()
		check(changed == ["forum"],
			"real 3D-projected marker still selects authentic city district")
		(controls as Button).pressed.emit()
		check(not bool(panel.get("city_focus_active")),
			"same focus button restores full original governance interface")
		check(left.visible and right.visible and center.visible and stats.visible,
			"all original playable actions and metrics are restored, not re-created")
		check(stats.get_child_count()==6 and viewport==before_scene,
			"returning to governance restores six real stats and original camera")
		check(is_equal_approx(center.size_flags_stretch_ratio,1.72),
			"reference-approved original desktop proportions restore exactly")
		check(is_equal_approx(cols.custom_minimum_size.y,450.0) and
			is_equal_approx((panel.get("focus_stage") as Control).custom_minimum_size.y,436.0),
			"original reference viewport dimensions restore after exiting focus")
	check(current==source and game.get("data")==source,
		"showing real city does not change money, missions or game saves")
	panel.queue_free()
	var mobile: VBoxContainer = dashboard_source.new()
	root.add_child(mobile)
	mobile.call("build",current,forecast,str(missions.call("title","ru")),
		root.world_3d,true,"ru")
	check(mobile.get("preview")==null and
		mobile.find_child("R115CinematicFocusToggle",true,false)==null,
		"portrait mobile keeps original fast one-pass gameplay fallback")
	check(mobile.get_node_or_null("R97ExecutiveSummary") != null,
		"phone still shows original real city economics without second 3D pass")
	mobile.queue_free()
	game.set("data",old)
	game.set("locale",language)
	await process_frame
	print("EMPIRE OMEGA R115 original cinematic city focus: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
