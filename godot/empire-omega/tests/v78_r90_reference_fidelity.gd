extends SceneTree
## R90 first acceptance: actual authored Godot UI, source state and 3D.
# Defer dashboard class compilation until real Godot autoloads initialize.
const STYLE = preload("res://scripts/horizon_r90_reference_style.gd")
const DIAL = preload("res://scripts/horizon_r90_speed_dial.gd")
const URBAN = preload("res://scripts/horizon_r90_street_dressing.gd")
var passed := 0
var failed := 0

func verify(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R90 ORIGINAL AAA ART SLICE FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	verify(game != null and missions != null,
		"original authoritative GameState and MissionManager autoloads are mounted")
	if game == null or missions == null:
		quit(1)
		return
	var original_state: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var original_locale: String = str(game.get("locale"))
	var live: Dictionary = game.call("new_game")
	game.set("data",live)
	game.set("locale","ru")
	var forecast: Dictionary = game.call("forecast")
	var dial: Control = DIAL.new()
	root.add_child(dial)
	dial.call("set_vehicle",22.0,60.0,80.0)
	verify(is_equal_approx(float(dial.get("speed_kmh")),79.2),"dial reads actual metres/second")
	verify(is_equal_approx(float(dial.get("fuel_percent")),60.0),"real fuel fraction")
	dial.call("set_vehicle",NAN,NAN,NAN)
	verify(float(dial.get("speed_kmh"))==0.0 and float(dial.get("fuel_percent"))==0.0,"invalid telemetry fails closed")
	dial.queue_free()
	var urban: Node3D = URBAN.new()
	root.add_child(urban)
	verify(bool(urban.call("graphics_are_bounded")),"cosmetic batch sizes are finite")
	urban.call("set_quality","low")
	verify(not (urban.get("skyline") as MultiMeshInstance3D).visible and not (urban.get("bollards") as MultiMeshInstance3D).visible,"mobile low tier hides premium meshes")
	urban.call("set_quality","cinematic")
	verify((urban.get("skyline") as MultiMeshInstance3D).visible and (urban.get("bollards") as MultiMeshInstance3D).visible,"cinematic tier shows true meshes")
	verify(urban.get_child_count()==3,"real tower, bollard and detail instancing scene nodes")
	verify(bool(urban.call("graphics_are_bounded")),"original new geometry stays bounded")
	var additional: Node3D = urban.get("r91_architecture")
	verify(additional!=null and additional.get_child_count()==2,
		"each real 3D city uses precisely two additional GPU batches")
	urban.queue_free()
	for dimensions in [Vector2(1366,768),Vector2(1920,1080)]:
		var frame: Rect2 = STYLE.command_center_frame(dimensions)
		verify(frame.position.x>=10.0 and frame.position.y>=8.0,
			"dashboard has visual margin")
		verify(frame.end.x<=dimensions.x and frame.end.y<=dimensions.y,
			"dashboard stays inside desktop")
	var premium: Variant = load("res://scripts/horizon_r90_premium_dashboard.gd")
	verify(premium is Script and premium.can_instantiate(),"R90 dashboard source compiles at runtime")
	if not (premium is Script and premium.can_instantiate()):
		quit(1)
		return
	var preview: VBoxContainer = premium.new()
	root.add_child(preview)
	preview.call("build",live,forecast,str(missions.call("title","ru")),root.world_3d,false,"ru")
	verify(preview.get("preview")!=null and (preview.get("preview") as SubViewport).world_3d==root.world_3d,
		"command room renders the real authoritative game 3D world")
	verify((preview.get("preview") as SubViewport).get_camera_3d()!=null,
		"live command camera is attached to original Godot World3D")
	verify(preview.get_node_or_null("R90NavigationTabs")!=null,
		"signed-off seven top tabs exist in actual gameplay")
	verify(preview.find_child("R90DistrictPin_forum",true,false)!=null,
		"real city overview shows interactive district markers")
	verify(preview.get_node_or_null("R90FakeBackground")==null,
		"no fake reference artwork replaces real world")
	var calls: Array[String] = []
	preview.connect("navigate",func(id: String): calls.append(id))
	preview.call("_request_navigation","council")
	verify(calls==["council"],"cabinet navigation emits the original actionable section")
	preview.queue_free()
	var original_hud: Variant = load("res://scripts/hud.gd")
	verify(original_hud is Script and original_hud.can_instantiate(),"existing native HUD still compiles")
	if original_hud is Script and original_hud.can_instantiate():
		var hud: CanvasLayer = original_hud.new()
		root.add_child(hud)
		verify(hud.get("r90_speed_dial")!=null,"real gameplay HUD contains animated speed dial")
		hud.call("toggle_strategy")
		verify(bool(hud.call("is_strategy_open")),"native original Tab cabinet opens")
		verify((hud.get("strategy_contents") as VBoxContainer).get_node_or_null("R90LiveOperationsCabinet")!=null,
			"premium command room really integrated in authority HUD")
		verify((hud.get("strategy_anchors") as Dictionary).has("council") and (hud.get("strategy_anchors") as Dictionary).has("economy")
			and (hud.get("strategy_anchors") as Dictionary).has("district"),"existing live actions all reachable")
		hud.call("toggle_strategy")
		verify(not bool(hud.call("is_strategy_open")),"closed cabinet returns to normal gameplay")
		hud.queue_free()
	game.set("data",original_state)
	game.set("locale",original_locale)
	await process_frame
	print("EMPIRE OMEGA R90 genuine art direction slice: %d pass, %d fail" % [passed,failed])
	quit(0 if failed==0 else 1)
