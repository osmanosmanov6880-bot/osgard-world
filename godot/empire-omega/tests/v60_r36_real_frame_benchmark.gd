extends SceneTree
## R36 actual game frame reporter regression. Inputs are synthetic unit
## samples; hardware proof is provided ONLY by users running real game.
const BENCH = preload("res://scripts/horizon_device_frame_benchmark.gd")
const HUD = preload("res://scripts/hud.gd")
const LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
var passed := 0
var failed := 0
var starts := 0
var exports := 0
func verify(ok: bool,label: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R36 HARDWARE REPORTER FAILED: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _on_start() -> void:
	starts+=1
func _on_export() -> void:
	exports+=1
func _run() -> void:
	var bench = BENCH.new()
	verify(not bench.active and not bench.completed and bench.report()["status"]=="not-ready","never fabricates benchmark before input")
	bench.begin("cinematic",Vector2(1366,768),"UnitTestLinux")
	verify(bench.active and not bench.completed,"explicit user request starts only measurement")
	for i in range(1380):
		bench.record_frame(1.0/60.0,32+(i%4))
	verify(not bench.active and bench.completed,"actual frame time expires after 2s warmup and 20s capture")
	var report: Dictionary = bench.report()
	verify(report["status"]=="complete" and report["schema"]=="empire-omega-real-frames-r36-v1","JSON has explicit stable schema")
	verify(int(report["frame_count"])>=1100 and int(report["frame_count"])<=1380,"FPS data comes from counted input frames")
	verify(absf(float(report["p50_frame_ms"])-16.6667)<0.1,"p50 returns milliseconds")
	verify(float(report["p95_frame_ms"])>=float(report["p50_frame_ms"]),"p95 cannot be better than p50")
	verify(float(report["p99_frame_ms"])>=float(report["p95_frame_ms"]),"p99 cannot be better than p95")
	verify(float(report["p95_draw_calls"])>=32.0 and int(report["maximum_draw_calls"])==35,"GPU draw-call reports preserve renderer counters")
	verify(float(report["capture_s"])>=20.0 and report["graphics_quality"]=="cinematic","contains actual capture duration and requested graphics quality")
	verify(report["physical_hardware_attested"]==false and report["source_sha_verified"]==false,"does not falsely claim hardware identity or release SHA")
	verify(report["platform_reported_by_engine"]=="UnitTestLinux","platform is reported data, not certified hardware")
	bench.begin("low",Vector2(390,844),"Web")
	bench.record_frame(NAN,25)
	verify(bench.dropped==1 and not bench.completed,"invalid frame never becomes valid hardware data")
	bench.record_frame(0.016,20,false)
	verify(bench.aborted=="browser-backgrounded" and not bench.completed,"background tab aborts measurement")
	verify(bench.report()["status"]=="not-ready","cannot export silently truncated background capture")
	for size in [Vector2(320,568),Vector2(390,844),Vector2(860,540)]:
		var panel: Rect2 = LAYOUT.compute(size)["diagnostics"]
		verify(panel.end.y<size.y-120.0,"expanded panel does not cover phone driving buttons")
		verify(not panel.intersects(LAYOUT.compute(size)["quick_toggle"]),"benchmark never blocks FPS toggle")
	var hud: CanvasLayer = HUD.new()
	root.add_child(hud)
	hud.benchmark_start_requested.connect(_on_start)
	hud.benchmark_export_requested.connect(_on_export)
	verify(hud.benchmark_start_button!=null and hud.benchmark_export_button!=null,"real Godot HUD provides two accessible buttons")
	hud.toggle_diagnostics()
	verify(hud.diagnostic_panel.visible,"native diagnostics opens by gameplay command")
	hud.benchmark_start_button.pressed.emit()
	hud.benchmark_export_button.pressed.emit()
	verify(starts==1 and exports==1,"both native touch/mouse button signals reach gameplay")
	hud.update_benchmark_status(0.5,false,"")
	verify(hud.benchmark_status_label.text.contains("50%"),"live progress visible to player")
	hud.update_benchmark_status(1.0,true,"")
	verify(hud.benchmark_status_label.text.contains("JSON"),"native report export discoverable")
	hud.queue_free()
	var main: Variant = load("res://scripts/main.gd")
	verify(main!=null,"original main gameplay script compiles")
	var source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	verify(source.contains("device_benchmark.record_frame(delta,draw_calls,DisplayServer.window_is_focused())"),"samples real game render-frame ticks")
	verify(source.contains("Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME"),"Godot real renderer draw-call monitor wired")
	verify(source.contains("JavaScriptBridge.download_buffer(bytes"),"web export writes user-requested native JSON")
	verify(source.contains("frame_metrics.record_frame(delta,DisplayServer.window_is_focused())"),"existing R16 telemetry preserved")
	await process_frame
	print("EMPIRE OMEGA R36 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
