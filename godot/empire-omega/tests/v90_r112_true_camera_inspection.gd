extends SceneTree
## R112 native acceptance: interactive actual 3D Godot camera inspection.
## No additional viewport, fabricated pins, frozen images, or altered saves.
var passed := 0
var failed := 0

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R112 LIVE GODOT CAMERA FAILED: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	check(game != null and missions != null, "original autoloads")
	if game == null or missions == null:
		quit(1)
		return
	var original_data: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var original_lang: String = str(game.get("locale"))
	var data: Dictionary = game.call("new_game")
	game.set("data",data)
	game.set("locale","ru")
	var source: Dictionary = data.duplicate(true)
	var forecast: Dictionary = game.call("forecast")
	var script: Variant = load("res://scripts/horizon_r90_premium_dashboard.gd")
	check(script is Script and script.can_instantiate(),
		"real cinematic dashboard compiles")
	if not (script is Script and script.can_instantiate()):
		game.set("data",original_data)
		game.set("locale",original_lang)
		quit(1)
		return
	var panel: VBoxContainer = script.new()
	root.add_child(panel)
	panel.call("build",data,forecast,str(missions.call("title","ru")),
		root.world_3d,false,"ru")
	var viewport: SubViewport = panel.get("preview") as SubViewport
	var camera: Camera3D = panel.get("atlas_camera") as Camera3D
	check(viewport != null and viewport.world_3d == root.world_3d,
		"city preview shares the single authoritative original 3D world")
	check(camera != null and camera.get_parent() == viewport,
		"only one real subviewport command camera is used")
	var controls: HBoxContainer = panel.find_child("R112AtlasCameraControls",true,false) as HBoxContainer
	var details: Button = panel.find_child("R112AtlasView_architecture",true,false) as Button
	var overview: Button = panel.find_child("R112AtlasView_overview",true,false) as Button
	check(controls != null and controls.get_child_count() == 2,
		"two real view modes are visible in the original command atlas")
	check(details != null and overview != null,
		"native camera mode buttons remain keyboard-operable")
	if details != null and overview != null:
		check(details.focus_mode == Control.FOCUS_ALL and
			overview.focus_mode == Control.FOCUS_ALL,
			"both actual buttons have visible keyboard focus")
	check(str(panel.get("atlas_mode")) == "overview",
		"command mode starts on the original authoritative district overview")
	var old_pos: Vector3 = camera.position if camera != null else Vector3.ZERO
	var old_fov: float = camera.fov if camera != null else 0.0
	var pins: Dictionary = panel.get("atlas_pins")
	check(pins.size() == 4,"actual four original game districts remain projected")
	var original_forum: Vector2 = Vector2.ZERO
	if pins.has("forum"):
		var marker: Button = pins["forum"] as Button
		original_forum = Vector2(marker.anchor_left,marker.anchor_top)
	if details != null:
		details.pressed.emit()
	check(str(panel.get("atlas_mode")) == "architecture",
		"real button selects architectural cinematic inspection")
	check(camera != null and camera.position.distance_to(old_pos) > 70.0 and
		camera.fov < old_fov,
		"native 3D camera physically moves closer with real different FOV")
	check(overview != null and not overview.disabled and details != null and details.disabled,
		"actual mode controls communicate selected camera and accessible alternative")
	var new_forum: Vector2 = Vector2.ZERO
	if pins.has("forum"):
		var marker: Button = pins["forum"] as Button
		new_forum = Vector2(marker.anchor_left,marker.anchor_top)
	check(original_forum.distance_to(new_forum) > 0.01,
		"real district pin moves with actual 3D camera, not static 2D positions")
	var selected: Array[String] = []
	panel.connect("select_district",func(id: String): selected.append(id))
	if pins.has("forum"):
		(pins["forum"] as Button).pressed.emit()
	check(selected == ["forum"], "real projected district still selects actual city policy section")
	if overview != null:
		overview.pressed.emit()
	check(str(panel.get("atlas_mode")) == "overview",
		"first camera mode restores original navigable 3D overview")
	check(camera != null and camera.position.is_equal_approx(old_pos) and
		is_equal_approx(camera.fov,old_fov),
		"same original real camera transform restored without reloading world")
	check(viewport != null and viewport.get_child_count() == 1,
		"no extra real-time camera render pass or replacement PNG is created")
	panel.call("_switch_atlas_mode","forged")
	check(str(panel.get("atlas_mode")) == "overview",
		"invalid camera mode cannot mutate original city state")
	check(data == source and game.get("data") == source,
		"switching view modes does not alter saved city finances, missions or gameplay")
	panel.queue_free()
	game.set("data",original_data)
	game.set("locale",original_lang)
	await process_frame
	print("EMPIRE OMEGA R112 original Godot 3D camera inspection: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed == 0 else 1)
