extends SceneTree
## R42 combined-engine release check. Synthetic tests never certify hardware.
const LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
const BENCH = preload("res://scripts/horizon_device_frame_benchmark.gd")
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R42 FULL STACK FAILED: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for path in [
			"res://scripts/main.gd","res://scripts/hud.gd",
			"res://scripts/world_builder.gd","res://scripts/horizon_roadscape.gd",
			"res://scripts/horizon_intersection_details.gd",
			"res://scripts/horizon_vehicle_art.gd","res://scripts/vehicle_controller.gd",
			"res://scripts/horizon_r39_wheel_detail.gd","res://scripts/pedestrian_agent.gd",
			"res://scripts/horizon_pedestrian_yield.gd",
			"res://scripts/horizon_device_frame_benchmark.gd",
			"res://labs/r24_four_wheel_rigidbody.gd",
			"res://tests/v14_traffic_physics.gd"]:
		var script: Variant = load(path)
		check(script is Script and script.can_instantiate(),"real Godot parses "+path)
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var hud: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	var streets: String = FileAccess.get_file_as_string("res://scripts/horizon_roadscape.gd")
	var art: String = FileAccess.get_file_as_string("res://scripts/horizon_vehicle_art.gd")
	var civilians: String = FileAccess.get_file_as_string("res://scripts/pedestrian_agent.gd")
	check(main_src.contains("device_benchmark.record_frame("),"playable game samples opt-in FPS")
	check(main_src.contains("JavaScriptBridge.download_buffer("),"player exports real Web JSON")
	check(hud.contains("benchmark_start_requested") and hud.contains("benchmark_export_requested"),"live HUD has benchmark controls")
	check(streets.contains("R38_STREETS.new()"),"actual road uses instanced junction batches")
	check(art.contains("R39_DETAIL.new()"),"animated wheel rigs own R39 physical art")
	check(civilians.contains("TRAJECTORY.should_yield("),"city pedestrian path checks car trajectory")
	check(not main_src.contains("r24_four_wheel_rigidbody.gd"),"experimental physics never silently replaces live car")
	var bench = BENCH.new()
	check(bench.report().get("status")=="not-ready","no fabricated FPS report")
	bench.begin("cinematic",Vector2(390,844),"UnverifiedHardware")
	check(not bench.completed and not bench.report().get("physical_hardware_attested",false),"no fake hardware proof")
	for screen in [Vector2(320,568),Vector2(390,844),Vector2(844,390),Vector2(1366,768)]:
		var panel: Rect2 = LAYOUT.compute(screen)["diagnostics"]
		check(panel.size.x>0 and panel.size.y>0 and panel.end.y<=screen.y,
			"real performance controls fit "+str(screen))
	await process_frame
	print("EMPIRE OMEGA R42 INTEGRATION: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
