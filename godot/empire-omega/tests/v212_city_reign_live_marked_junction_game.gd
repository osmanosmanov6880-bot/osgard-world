extends SceneTree
## R187 FULL original playable 3D world and source R186 physical box.
const BOX=preload("res://scripts/city_reign_junction_box_clearance.gd")
const SOURCE=preload("res://scripts/city_reign_intersection_policy.gd")
const MARKS=preload("res://scripts/city_reign_real_junction_box_paint.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R187 ORIGINAL LIVING 3D CITY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs: Node=root.get_node("GameState")
	var old: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var locale: String=str(gs.get("locale"))
	gs.set("data",gs.new_game())
	var original: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var loaded: Error=change_scene_to_file("res://scenes/main.tscn")
	check(loaded==OK,"actual original Godot 3D world, not image mock")
	if loaded!=OK:
		gs.set("data",old)
		gs.set("locale",locale)
		quit(2)
		return
	await process_frame
	for i in range(9):await physics_frame
	var world: Node3D=current_scene as Node3D
	var vehicles: Array=world.get("ambient_cars")
	var people: Array=world.get("pedestrians")
	var signals: Node3D=world.get("traffic_signals") as Node3D
	var driver: CharacterBody3D=world.get("car") as CharacterBody3D
	var paint: Node3D=signals.get("real_junction_box_paint") as Node3D
	check(vehicles.size()==12 and people.size()==34 and driver!=null,
		"actual original 12 native physical NPC cars, 34 residents and player car retained")
	check(paint!=null and paint.source_geometry_valid() and
		signals.real_zebra_crossings.source_geometry_valid() and
		signals.true_speed_signs.source_integrity(),
		"full native original city contains real 144 yellow marks, 384 white zebra slats and 64 speed signs")
	var center:=Vector3(-156,0,-156)
	var approaching:=Vector3(-156,0.8,-170)
	var heading:=Vector3.BACK
	var source: Dictionary=SOURCE.approach(approaching,heading,12.0)
	var border: Transform3D=MARKS.outline_transform(center.x,center.z,"x",1)
	check(BOX.source_gate_valid(source,heading) and
		is_equal_approx(border.origin.x,center.x+MARKS.ROAD_PAINT_HALF_M) and
		MARKS.ROAD_PAINT_HALF_M<BOX.SOURCE_BOX_HALF_M,
		"visible ORIGINAL road-box paint is source-aligned with actual R186 physical junction guard")
	var stopped:=Vector3(-158,0.8,-142)
	check(BOX.classify(source,heading,8.0,stopped,Vector3.ZERO,0.0)=="blocked_exit",
		"real in-game stopped right-lane car has the exact physical keep-clear constraint shown to player")
	var file: String=FileAccess.get_file_as_string("res://scripts/traffic_signal_controller.gd")
	check(file.contains("R187_REAL_BOX_PAINT.new()") and
		file.contains("real_junction_box_paint.call(\"sync_city\"") and
		signals.call("visual_state_is_consistent"),
		"new actual art is really driven by the original city signal/power scene, not separate image")
	check(int(gs.data["wallet"])==int(original["wallet"]) and
		int(gs.data["treasury"])==int(original["treasury"]) and
		int(gs.data["mission"])==int(original["mission"]) and
		gs.data["inventories"]==original["inventories"],
		"real premium road appearance has ZERO impact on original save, 40 missions or economy")
	world.queue_free()
	await process_frame
	gs.set("data",old)
	gs.set("locale",locale)
	print("CITY REIGN R187 ORIGINAL TRUE JUNCTION PAINT IN 3D: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
