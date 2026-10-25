extends SceneTree
## R90 first acceptance: actual authored Godot UI, source state and 3D.
const DASH = preload("res://scripts/horizon_r90_premium_dashboard.gd")
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
	var original_state: Dictionary = GameState.data.duplicate(true)
	var original_locale: String = GameState.locale
	var live: Dictionary = GameState.new_game()
	GameState.data = live
	GameState.locale = "ru"
	var forecast: Dictionary = GameState.forecast()
	var dial: Control = DIAL.new()
	root.add_child(dial)
	dial.set_vehicle(22.0,60.0,80.0)
	verify(is_equal_approx(dial.speed_kmh,79.2),"dial reads actual metres/second")
	verify(is_equal_approx(dial.fuel_percent,60.0),"real fuel fraction")
	dial.set_vehicle(NAN,NAN,NAN)
	verify(dial.speed_kmh==0.0 and dial.fuel_percent==0.0,"invalid telemetry fails closed")
	dial.queue_free()
	var urban: Node3D = URBAN.new()
	root.add_child(urban)
	verify(urban.graphics_are_bounded(),"cosmetic batch sizes are finite")
	urban.set_quality("low")
	verify(not urban.skyline.visible and not urban.bollards.visible,"mobile low tier hides premium meshes")
	urban.set_quality("cinematic")
	verify(urban.skyline.visible and urban.bollards.visible,"cinematic tier shows true meshes")
	verify(urban.get_child_count()==2,"no extra per-prop scene nodes")
	urban.queue_free()
	for dimensions in [Vector2(1366,768),Vector2(1920,1080)]:
		var frame: Rect2 = STYLE.command_center_frame(dimensions)
		verify(frame.position.x>=10.0 and frame.position.y>=8.0,
			"dashboard has visual margin")
		verify(frame.end.x<=dimensions.x and frame.end.y<=dimensions.y,
			"dashboard stays inside desktop")
	var preview: VBoxContainer = DASH.new()
	root.add_child(preview)
	preview.build(live,forecast,MissionManager.title("ru"),root.world_3d,false,"ru")
	verify(preview.preview!=null and preview.preview.world_3d==root.world_3d,
		"command room renders the real authoritative game 3D world")
	verify(preview.preview.get_camera_3d()!=null,
		"live command camera is attached to original Godot World3D")
	verify(preview.get_node_or_null("R90FakeBackground")==null,
		"no fake reference artwork replaces real world")
	var calls: Array[String] = []
	preview.navigate.connect(func(id: String): calls.append(id))
	preview._request_navigation("council")
	verify(calls==["council"],"cabinet navigation emits the original actionable section")
	preview.queue_free()
	var original_hud: Variant = load("res://scripts/hud.gd")
	verify(original_hud is Script and original_hud.can_instantiate(),"existing native HUD still compiles")
	if original_hud is Script and original_hud.can_instantiate():
		var hud: CanvasLayer = original_hud.new()
		root.add_child(hud)
		verify(hud.get("r90_speed_dial")!=null,"real gameplay HUD contains animated speed dial")
		hud.toggle_strategy()
		verify(hud.is_strategy_open(),"native original Tab cabinet opens")
		verify(hud.strategy_contents.get_node_or_null("R90LiveOperationsCabinet")!=null,
			"premium command room really integrated in authority HUD")
		verify(hud.strategy_anchors.has("council") and hud.strategy_anchors.has("economy")
			and hud.strategy_anchors.has("district"),"existing live actions all reachable")
		hud.toggle_strategy()
		verify(not hud.is_strategy_open(),"closed cabinet returns to normal gameplay")
		hud.queue_free()
	GameState.data = original_state
	GameState.locale = original_locale
	await process_frame
	print("EMPIRE OMEGA R90 genuine art direction slice: %d pass, %d fail" % [passed,failed])
	quit(0 if failed==0 else 1)
