extends SceneTree
## R87: forty authored objectives must never show false courier distances.
## Uses original GameState, MissionManager, genuine HUD and World script.
const NAV = preload("res://scripts/horizon_mission_navigation.gd")
var passed := 0
var failed := 0

func verify(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R87 HONEST NAVIGATION FAILED: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	verify(game != null and missions != null, "original authoritative autoloads")
	if game == null or missions == null:
		quit(1)
		return
	var prior: Dictionary = game.get("data").duplicate(true)
	var prior_locale: String = str(game.get("locale"))
	var state: Dictionary = game.call("new_game")
	game.set("data",state)
	game.set("locale","ru")
	var world_goals := 0
	var non_spatial := 0
	for stage in range(40):
		state["mission"] = stage
		var actual: Dictionary = missions.call("get_mission")
		var action: String = str(actual.get("id",""))
		var is_spatial: bool = NAV.has_world_goal(action,false,false,false,false)
		var expected: bool = NAV.WORLD_ACTIONS.has(action)
		verify(is_spatial == expected, "mission %d has no fabricated destination: %s" % [stage+1,action])
		if expected:
			world_goals += 1
		else:
			non_spatial += 1
			verify(not NAV.hud_hint(action,"ru").is_empty(),
				"mission %d has actionable hint rather than a fake distance" % [stage+1])
	verify(world_goals >= 8 and non_spatial >= 20,
		"all 40 authored missions classified, most non-spatial tasks have no false courier beacon")
	verify(NAV.has_world_goal("research",true,false,false,false),
		"real driving trial has precedence over office task")
	verify(NAV.has_world_goal("research",false,true,false,false),
		"active contract has genuine destination")
	verify(NAV.has_world_goal("neighborhood_deliver",false,false,true,false),
		"active resident errand has real destination")
	verify(NAV.has_world_goal("service_complete",false,false,false,true),
		"active public-service call has real destination")
	verify(not NAV.has_world_goal("neighborhood_deliver",false,false,false,false),
		"neighborhood task without an active errand does not borrow courier goal")
	verify(not NAV.has_world_goal("complete",false,false,false,false),
		"free play without active activities has no fabricated destination")
	verify(NAV.hud_hint("research","ru",true).contains("ГОРОД"),
		"touch player gets a button-specific city hint rather than keyboard-only Tab")
	verify(NAV.hud_hint("research","en",false).contains("TAB"),
		"desktop English gets an accurate governance hint")
	verify(NAV.hud_hint("neighborhood_accept","zh",true).contains("居民"),
		"localized real resident guidance retained")
	var source_main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var source_hud: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	var source_map: String = FileAccess.get_file_as_string("res://scripts/minimap.gd")
	verify(source_main.contains("MISSION_NAV.has_world_goal(") and
		source_main.contains("world.update_waypoint(goal,goal_visible)") and
		source_main.contains("hud.map.route.clear()"),
		"genuine playable scene suppresses false markers and non-target routes")
	verify(source_hud.contains("map.goal_active = goal_available") and
		source_hud.contains("MISSION_NAV.hud_hint("),
		"real HUD and minimap honor live mission navigation state")
	verify(source_map.contains("if goal_active:"),
		"minimap does not draw a nonexistent goal dot")
	var world_script: Variant = load("res://scripts/world_builder.gd")
	verify(world_script is Script and world_script.can_instantiate(),
		"world compiles AFTER original GameState autoload is initialized")
	if not (world_script is Script and world_script.can_instantiate()):
		game.set("data",prior)
		game.set("locale",prior_locale)
		quit(1)
		return
	var world: Node3D = world_script.new()
	var beacon := Node3D.new()
	world.set("waypoint_marker",beacon)
	world.call("update_waypoint",Vector3(130,0,-130),false)
	verify(not beacon.visible,"world beacon hides for governance objectives")
	world.call("update_waypoint",Vector3(130,0,-130),true)
	verify(beacon.visible and absf(beacon.position.x-130.0)<0.001,
		"original authored world beacon returns for genuine delivery")
	world.free()
	# Instantiate the ACTUAL native HUD and validate player-visible wording.
	state["mission"] = 2
	var hud_script: Variant = load("res://scripts/hud.gd")
	verify(hud_script is Script and hud_script.can_instantiate(),
		"actual HUD compiles after original game autoloads")
	if not (hud_script is Script and hud_script.can_instantiate()):
		game.set("data",prior)
		game.set("locale",prior_locale)
		quit(1)
		return
	var hud: CanvasLayer = hud_script.new()
	root.add_child(hud)
	hud.call("_refresh")
	hud.call("update_world_context", Vector3.ZERO,Vector3.ZERO,Vector3(130,0,-130),
		false,0.0,100.0,"",100.0,false,"N",0,0.0,0.0,0.0,false)
	var detail: Label = hud.get("mission_distance_label")
	verify(detail != null and detail.text.contains("КАБИНЕТ") and
		not detail.text.contains("ДО ЦЕЛИ"),
		"real authored third mission shows cabinet action, not invented courier meters")
	verify(not bool(hud.get("map").get("goal_active")),
		"real HUD turns off minimap goal for city office tasks")
	state["mission"] = 1
	hud.call("_refresh")
	hud.call("update_world_context", Vector3.ZERO,Vector3.ZERO,Vector3(130,0,-130),
		false,0.0,100.0,"",100.0,false,"N",0,0.0,0.0,0.0,true)
	verify(detail.text.contains("ДО ЦЕЛИ") and bool(hud.get("map").get("goal_active")),
		"original delivery mission restores distance and minimap target")
	hud.queue_free()
	game.set("data",prior)
	game.set("locale",prior_locale)
	await process_frame
	print("EMPIRE Ω R87 genuine native mission navigation: %d passed, %d failed" % [passed,failed])
	quit(0 if failed == 0 else 1)
