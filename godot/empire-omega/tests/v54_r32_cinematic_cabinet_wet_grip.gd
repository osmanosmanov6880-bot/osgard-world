extends SceneTree
## R32 native acceptance: actual governance UI geometry, lighting, and real
## physical tyre response over the same 72 instanced rainy road patches.
const LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
const GRADE = preload("res://scripts/horizon_light_grade.gd")
const PUDDLES = preload("res://scripts/horizon_rain_puddles.gd")
const DYNAMICS = preload("res://scripts/driving_dynamics.gd")
var passed := 0
var failed := 0

func check(ok: bool, explanation: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R32 CINEMATIC CITY FAILED: "+explanation)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for resolution in [Vector2(1024,768),Vector2(1366,768),Vector2(1720,930),Vector2(1920,1080)]:
		var dock: Rect2 = LAYOUT.strategy_dock(resolution)
		check(dock.position.x >= 16.0 and dock.position.y >= 20.0,"desktop cabinet has a breathable inset")
		check(dock.end.x < resolution.x*0.55,"world stays exposed behind the cabinet")
		check(dock.end.y <= resolution.y and dock.size.y >= resolution.y*0.82,"cabinet fits desktop without clipping")
		check(not LAYOUT.is_compact(resolution),"desktop mode stays a real dock")
	for resolution in [Vector2(320,568),Vector2(390,844),Vector2(860,540)]:
		check(LAYOUT.strategy_dock(resolution)==LAYOUT.compute(resolution)["modal"],
			"compact phone keeps reachable, scrollable modal")
	var env := Environment.new()
	var sun := DirectionalLight3D.new()
	var sky := ProceduralSkyMaterial.new()
	GRADE.apply_to(env,sun,sky,"clear","cinematic",1.0)
	check(env.adjustment_brightness>=0.95 and env.adjustment_brightness<1.0,
		"3D world raises crushed shadows without clipping all highlights")
	check(env.ambient_light_energy>=0.85 and env.ambient_light_energy<=0.98,
		"sunlit city retains bounded indirect light")
	check(sun.light_energy>=0.95 and sun.light_energy<=1.10,
		"real daylight luminance remains stable")
	GRADE.apply_to(env,sun,sky,"storm","low",1.0)
	check(not env.fog_enabled,"LOW disables high-cost atmospheric effects")
	check(sun.light_energy>0.3,"storm remains visible without fake brightness pass")
	var layer: MultiMeshInstance3D = PUDDLES.new()
	root.add_child(layer)
	check(layer.multimesh.instance_count==72,"same 72 instanced rain polygons drive tyre contact")
	var centre: Vector3 = layer.planned_transforms[0].origin
	layer.set_conditions("clear","standard")
	check(is_zero_approx(layer.contact_at(centre)),"dry game has no artificial puddle grip loss")
	layer.set_conditions("rain","standard")
	check(layer.contact_at(centre)>0.95,"actual puddle centre is detected")
	check(layer.contact_at(centre+Vector3(15,0,12))==0.0,"far tyre does not slip on an invisible puddle")
	layer.set_conditions("storm","low")
	check(not layer.visible and layer.contact_at(centre)>0.95,
		"LOW hides transparent graphics without silently changing traction gameplay")
	var normal_grip: float = PUDDLES.effective_grip(0.80,0.0)
	var pooled_grip: float = PUDDLES.effective_grip(0.80,layer.contact_at(centre))
	check(is_equal_approx(normal_grip,0.80),"ordinary rainy asphalt grip unchanged")
	check(pooled_grip<normal_grip and pooled_grip>=0.65,
		"visible standing water applies physically bounded extra grip loss")
	check(PUDDLES.effective_grip(NAN,NAN)==1.0,
		"invalid sample cannot inject NaN into tyre physics")
	var dry_braking: float = DYNAMICS.speed_step(18.0,-1.0,normal_grip,1.0,29.0,9.0,9.5,10.5,2.4,false,0.25)
	var pooled_braking: float = DYNAMICS.speed_step(18.0,-1.0,pooled_grip,1.0,29.0,9.0,9.5,10.5,2.4,false,0.25)
	check(pooled_braking>dry_braking,
		"actual lower tyre grip increases braking distance, not just HUD text")
	layer.queue_free()
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("ROAD_WETNESS.effective_grip(base_road_grip,wetness)"),
		"live game physics loop uses actual weather and real puddle contact")
	var hud_script: Variant = load("res://scripts/hud.gd")
	check(hud_script!=null,"real governor HUD script parses")
	if hud_script!=null:
		var hud: CanvasLayer = hud_script.new()
		root.add_child(hud)
		check(hud.overlay.color.a<=0.40,"cabinet does not black out the 3D city")
		check(hud.strategy_nav_buttons.size()==4,"four live cabinet navigation buttons exist")
		check(hud.strategy_scroll.horizontal_scroll_mode == ScrollContainer.SCROLL_MODE_DISABLED,
			"long civic decisions cannot force sideways scrolling")
		hud.toggle_strategy()
		check(hud.is_strategy_open() and hud.strategy_anchors.has("council"),
			"real cabinet renders council content and navigation")
		check(hud.strategy_anchors.has("economy") and hud.strategy_anchors.has("district"),
			"economic, city and policy content remain reachable")
		hud.toggle_strategy()
		check(not hud.is_strategy_open(),"cabinet still closes through actual game action")
		hud.queue_free()
	print("EMPIRE OMEGA R32 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
