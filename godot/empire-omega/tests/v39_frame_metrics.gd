extends SceneTree
## Native 4.4.1 R16 acceptance for bounded frame times and real touch events.
const METRICS = preload("res://scripts/horizon_frame_metrics.gd")
const TOUCH = preload("res://scripts/horizon_touch_controls.gd")
const LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
var passed := 0
var failed := 0

class ActionProbe extends Node:
	var pressed: Array[String] = []
	func _input(event: InputEvent) -> void:
		if event is InputEventAction and event.pressed:
			pressed.append(event.action)

func verify(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R16 FAILED: " + message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var metrics = METRICS.new()
	verify(metrics.samples() == 0 and not metrics.ready(),"sampler starts unqualified")
	for i in range(29):
		metrics.record_frame(0.016)
	verify(not metrics.ready() and metrics.p95_ms() == 0.0,"insufficient frames never claim benchmark")
	metrics.record_frame(0.016)
	verify(metrics.ready(),"30 measured render frames qualify the reading")
	verify(absf(metrics.p95_ms()-16.0)<0.1,"p95 is milliseconds")
	for i in range(50):
		metrics.record_frame(0.060)
	verify(metrics.p95_ms()>59.0,"jank raises p95 as expected")
	verify(metrics.p99_ms()>=metrics.p95_ms(),"p99 cannot be below p95")
	var before: int = metrics.samples()
	metrics.record_frame(3.0)
	metrics.record_frame(-1.0)
	metrics.record_frame(NAN)
	verify(metrics.samples()==before,"resume and invalid deltas are excluded")
	verify(metrics.dropped_samples==3,"excluded deltas are tracked")
	for i in range(400):
		metrics.record_frame(0.020)
	verify(metrics.samples()==METRICS.MAX_SAMPLES,"bounded storage keeps exactly 240 samples")
	verify(absf(metrics.p95_ms()-20.0)<0.1,"old samples evicted from ring buffer")
	metrics.record_frame(0.016,false)
	verify(metrics.samples()==0 and not metrics.ready(),"background resets stale readings")
	metrics.record_frame(0.03)
	verify(metrics.p95_ms()==0.0,"post-resume warmup is reported as sampling")
	var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var hud_src: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	verify(main_src.contains("frame_metrics.record_frame(delta,DisplayServer.window_is_focused())"),"real render loop records frame duration")
	verify(main_src.contains("frame_metrics.p95_ms(),adaptive_graphics.effective_quality()"),"real HUD receives p95 and current tier")
	verify(hud_src.contains("P95: %s") and hud_src.contains("sampling"),"HUD reports qualified data")
	for size in [Vector2(320,568),Vector2(390,844),Vector2(860,540)]:
		var frames: Dictionary = LAYOUT.compute(size)
		var frame: Rect2 = frames["diagnostics"]
		verify(not frame.intersects(frames["quick_toggle"]),"FPS card does not cover the native quick-actions toggle")
		verify(frame.end.y < size.y-120.0,"FPS card leaves room for driving controls")
	verify(hud_src.contains("map_visible_before_diagnostics"),"HUD saves and restores minimap when diagnostics cover map")
	var controls: CanvasLayer = TOUCH.new()
	root.add_child(controls)
	var probe := ActionProbe.new()
	root.add_child(probe)
	controls.call("set_preview",true)
	controls.call("set_mode",true,false)
	var quick: Dictionary = controls.get("_quick_buttons")
	verify(quick.has("diagnostics") and quick.size()==7,"phone exposes a native FPS action")
	var button: Button = quick.get("diagnostics")
	verify(button!=null and button.text.contains("FPS"),"button label readable")
	controls.call("_toggle_quick_actions")
	verify((controls.get("quick_panel") as PanelContainer).visible,"touch actions menu opens")
	controls.call("_activate_quick","diagnostics")
	await create_timer(0.2).timeout
	verify(probe.pressed.has("diagnostics"),"FPS command reaches actual InputEvent pipeline")
	verify(not (controls.get("quick_panel") as PanelContainer).visible,"diagnostic command closes menu")
	probe.queue_free()
	controls.queue_free()
	print("HORIZON R16 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
