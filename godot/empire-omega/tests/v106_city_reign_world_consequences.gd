extends SceneTree
## CITY REIGN C1: actual Godot-native brand + causal streets regression.
## Do not count this as PASS until it ran in Godot 4.4.1 on this exact SHA.
var passed: int = 0
var failed: int = 0

func check(condition: bool, detail: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN C1 FAIL: " + detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	if sim == null:
		push_error("Missing original GameState autoload")
		quit(2)
		return
	var before: Dictionary = sim.data.duplicate(true)
	var prior_locale: String = str(sim.locale)
	sim.data = sim.new_game()
	check(str(ProjectSettings.get_setting("application/config/name")).begins_with("CITY REIGN"),
		"real native Godot application title")
	check(str(sim.SAVE_PATH) == "user://osgard_empire_save_v4.json",
		"old v4 save location is preserved, not silently forked")
	var hud_script: Script = load("res://scripts/hud.gd") as Script
	check(hud_script != null and hud_script.can_instantiate(),
		"HUD source is a loadable real Godot script")
	if hud_script == null or not hud_script.can_instantiate():
		sim.data = before
		sim.locale = prior_locale
		quit(1)
		return
	var hud: CanvasLayer = hud_script.new()
	root.add_child(hud)
	var header: Label = hud.get("header_value") as Label
	var title: Label = hud.get("strategy_title") as Label
	var pause: Label = hud.get("pause_heading") as Label
	check(header != null and title != null and pause != null,
		"real native title controls exist")
	for lang in ["ru","en","zh"]:
		sim.locale = lang
		hud.call("_refresh")
		hud.call("_redraw_strategy")
		hud.call("_redraw_pause")
		if header != null and title != null and pause != null:
			check(header.text.contains("CITY REIGN") and
				title.text.contains("CITY REIGN") and
				pause.text.contains("CITY REIGN"),
				"live HUD/cabinet/pause titles show CITY REIGN in " + lang)
		var dashboard: Node = (hud.get("strategy_contents") as Node).get_node_or_null("R90LiveOperationsCabinet")
		check(dashboard != null,"real R90 operations screen exists in " + lang)
		if dashboard != null:
			var has_brand: bool = false
			for label in dashboard.find_children("*","Label",true,false):
				if (label as Label).text.contains("CITY REIGN"):
					has_brand = true
			check(has_brand,"premium screen renders CITY REIGN brand in " + lang)
	var initial_revenue: int = int(sim.forecast()["revenue"])
	var landmarks_script: Script = load("res://scripts/project_landmarks.gd") as Script
	check(landmarks_script != null and landmarks_script.can_instantiate(),
		"real 3D worksite source is loadable")
	if landmarks_script == null or not landmarks_script.can_instantiate():
		hud.queue_free()
		sim.data = before
		sim.locale = prior_locale
		quit(1)
		return
	var landmarks: Node3D = landmarks_script.new()
	root.add_child(landmarks)
	var snapshot: Dictionary = sim.data.duplicate(true)
	check(sim.start_initiative("open_records"),"civic investment really debits authoritative resources")
	landmarks.sync_projects(sim.data["projects_done"],sim.data["projects_active"])
	var worksites: Dictionary = landmarks.get("construction")
	check(worksites.size() == 1 and worksites.has("open_records"),
		"one actual in-world scaffolding site appears immediately")
	check(landmarks.get("created").size() == 0,"unfinished site is not yet a completed landmark")
	var origin: Dictionary = worksites["open_records"]
	check(origin["root"] is Node3D and origin["core"] is MeshInstance3D and
		origin["sign"] is Label3D and (origin["root"] as Node3D).get_child_count() >= 10,
		"site uses original visible 3D geometry, without background images")
	var initial_height: float = (origin["core"] as MeshInstance3D).scale.y
	check(sim.advance_turn(),"real authoritative city turn advances initiative")
	landmarks.sync_projects(sim.data["projects_done"],sim.data["projects_active"])
	var after_turn: Dictionary = (landmarks.get("construction") as Dictionary)["open_records"]
	check((after_turn["core"] as MeshInstance3D).scale.y > initial_height,
		"visible core grows after actual turn, not from invented UI counter")
	landmarks.update_language("en")
	check((after_turn["sign"] as Label3D).text.contains("CONSTRUCTION") and
		(after_turn["sign"] as Label3D).text.contains("1/2"),
		"localized construction sign uses authoritative saved remaining turns")
	check(sim.advance_turn(),"second real turn finishes two-turn construction")
	landmarks.sync_projects(sim.data["projects_done"],sim.data["projects_active"])
	check((landmarks.get("construction") as Dictionary).is_empty() and
		(landmarks.get("created") as Dictionary).has("open_records"),
		"finished site becomes existing completed 3D landmark")
	check(int(sim.forecast()["revenue"]) >= initial_revenue + 8,
		"actual completed initiative changes the city's fiscal simulation")
	landmarks.sync_projects([],{"safe_crossings":{"remaining":2}})
	check((landmarks.get("created") as Dictionary).is_empty() and
		(landmarks.get("construction") as Dictionary).has("safe_crossings"),
		"reset removes completed landmark and shows only restored active site")
	landmarks.sync_projects([],{})
	check((landmarks.get("created") as Dictionary).is_empty() and
		(landmarks.get("construction") as Dictionary).is_empty(),
		"empty save clears all completed and active world geometry")
	check(snapshot != sim.data,"real gameplay changes came from GameState, not the renderer")
	landmarks.queue_free()
	hud.queue_free()
	await process_frame
	sim.data = before
	sim.locale = prior_locale
	print("CITY REIGN C1 real Godot world consequences: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
