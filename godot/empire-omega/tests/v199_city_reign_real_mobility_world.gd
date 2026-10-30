extends SceneTree
## R183 observe actual existing 12 cars / 34 pedestrians in full Godot city.
const LAB=preload("res://scripts/city_reign_mobility_evidence.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R183 ORIGINAL LIVE CITY TELEMETRY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var game_state: Node=root.get_node("GameState")
	var old: Dictionary=(game_state.get("data") as Dictionary).duplicate(true)
	var old_locale: String=str(game_state.get("locale"))
	game_state.set("data",game_state.new_game())
	var original: Dictionary=(game_state.get("data") as Dictionary).duplicate(true)
	var status: Error=change_scene_to_file("res://scenes/main.tscn")
	check(status==OK,"R183 loads original playable native 3D source, not generated HTML mock")
	if status!=OK:
		game_state.set("data",old)
		game_state.set("locale",old_locale)
		quit(2)
		return
	await process_frame
	for i in range(9):await physics_frame
	var root_game: Node3D=current_scene as Node3D
	var cars: Array=root_game.get("ambient_cars")
	var people: Array=root_game.get("pedestrians")
	var signals: Node3D=root_game.get("traffic_signals") as Node3D
	var lab=root_game.get("street_life_benchmark")
	check(cars.size()==12 and people.size()==34 and signals!=null,
		"12 authentic physical NPC vehicles and 34 actual single-body citizens retained")
	check(lab!=null and not lab.active,
		"source city does NOT silently log mobility until player explicitly presses LAB")
	lab.begin()
	for i in range(48):
		# Synthetic CLOCK increments intentionally test only aggregation of
		# REAL original native entities, not fake hardware/60FPS claims.
		lab.observe(0.5,cars,people,float(i)*0.5,true,true)
	var report: Dictionary=lab.report()
	check(report.get("status","")=="complete" and
		report.get("sample_count",0)==40,
		"original 3D city objects generate bounded 20s synthetic QA of aggregate fields")
	check(report["original_vehicles_min"]==12 and
		report["original_walkers_min"]==34 and
		report["original_vehicles_max"]==12 and
		report["original_walkers_max"]==34,
		"all observed vehicles and resident counts are the real city objects")
	check(report["hardware_attested"]==false and
		report["captures_raw_positions"]==false and
		report["network_upload"]==false,
		"real source simulation cannot impersonate measured FPS on a physical phone")
	var json: String=JSON.stringify(report)
	check(not json.contains("global_position") and
		not json.contains("citizen_id") and
		not json.contains("device_model"),
		"no raw NPC coordinates, account information or unverifiable phone model in report")
	check(int(game_state.data["wallet"])==int(original["wallet"]) and
		int(game_state.data["mission"])==int(original["mission"]) and
		game_state.data["inventories"]==original["inventories"],
		"physical traffic analytics cannot mutate original game economy, property or quests")
	check(signals.real_zebra_crossings.source_geometry_valid() and
		signals.pedestrian_signs.batches_are_bounded(),
		"R183 preserves actual R182 384 road zebras and original WALK/WAIT source")
	root_game.queue_free()
	await process_frame
	game_state.set("data",old)
	game_state.set("locale",old_locale)
	print("CITY REIGN R183 ORIGINAL NATIVE CITY MOBILITY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
