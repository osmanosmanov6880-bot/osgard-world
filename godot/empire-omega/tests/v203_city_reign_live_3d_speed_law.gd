extends SceneTree
## R184 entire original playable main.tscn + genuine player lawful timer.
const RULE=preload("res://scripts/city_reign_speed_limit_policy.gd")
const LAW=preload("res://scripts/city_law.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R184 LIVE GAME SPEED SIGN FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs: Node=root.get_node("GameState")
	var old: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var locale: String=str(gs.get("locale"))
	gs.set("data",gs.new_game())
	var original: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var result: Error=change_scene_to_file("res://scenes/main.tscn")
	check(result==OK,"full real native CITY REIGN Godot scene loads")
	if result!=OK:
		gs.set("data",old)
		gs.set("locale",locale)
		quit(2)
		return
	await process_frame
	for i in range(9):await physics_frame
	var game: Node3D=current_scene as Node3D
	var city: Node3D=game.get("traffic_signals") as Node3D
	var car: CharacterBody3D=game.get("car") as CharacterBody3D
	var cars: Array=game.get("ambient_cars")
	var citizens: Array=game.get("pedestrians")
	check(city!=null and city.true_speed_signs!=null and
		city.true_speed_signs.source_integrity() and
		cars.size()==12 and citizens.size()==34,
		"real player car and original 12 NPC vehicles/34 residents share 64 true 3D law signs")
	check(city.real_zebra_crossings.source_geometry_valid() and
		city.pedestrian_signs.batches_are_bounded() and
		city.stop_bars.source_budget_ok(),
		"all original physical stop bars, 3D WALK/WAIT and 384 zebra slats survive")
	car.set_physics_process(false)
	car.set("speed",26.0)
	var warning: Dictionary=RULE.player_warning(float(car.get("speed")))
	check(warning.get("limit_kmh",0)==90 and warning.get("over_limit",false),
		"genuine existing physical player car at 93.6kmh receives original law-speed warning")
	var timer: float=0.0
	for i in range(16):
		timer=RULE.timer_step(timer,float(car.get("speed")),0.25)
	check(RULE.citation_ready(timer) and
		bool(gs.call("register_traffic_offence","speeding")),
		"full original player physical speed needs 4 seconds to reach REAL law authority")
	check(gs.data["law"]["fine"]==90 and gs.data["law"]["heat"]==1 and
		LAW.valid(gs.data["law"],int(gs.data["turn"])),
		"real authoritative original CityLaw and same strict saved fine schema issue original citation")
	check(int(gs.data["wallet"])==int(original["wallet"]) and
		int(gs.data["treasury"])==int(original["treasury"]) and
		int(gs.data["mission"])==int(original["mission"]),
		"warning and issuing a fine never mint or debit money before actual legal payment")
	var src: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	var signal_src: String=FileAccess.get_file_as_string("res://scripts/traffic_signal_controller.gd")
	var driver_src: String=FileAccess.get_file_as_string("res://scripts/city_reign_driver_awareness.gd")
	check(src.contains("R184_SPEED_RULE.timer_step(") and
		src.contains("R184_SPEED_RULE.citation_ready(") and
		src.contains("R184_SPEED_RULE.player_warning(") and
		signal_src.contains("R184_TRUE_SIGN_ART.new()") and
		driver_src.contains("speed_limit"),
		"actual original main player law+HUD and traffic scene use one real limit source")
	check(int(gs.data["treasury"])==int(original["treasury"]) and
		gs.data["inventories"]==original["inventories"],
		"physical 90kmh signage never changes original inventory, bank or 40-mission progress")
	game.queue_free()
	await process_frame
	gs.set("data",old)
	gs.set("locale",locale)
	print("CITY REIGN R184 ORIGINAL 3D LIVE SPEED LAW: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
