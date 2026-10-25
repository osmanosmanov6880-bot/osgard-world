extends SceneTree
## R48 sustained actual frame-pacing adaptation and opt-in per-frame budget QA.
## Synthetic native input verifies math; physical phone attestation stays false.
const GOVERNOR = preload("res://scripts/horizon_adaptive_graphics.gd")
const BENCH = preload("res://scripts/horizon_device_frame_benchmark.gd")
var passed := 0
var failed := 0
func check(ok: bool,label: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("EMPIRE R48 FRAME PACING FAILED: "+label)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gov = GOVERNOR.new()
	gov.configure("cinematic",true)
	for i in range(6):
		check(not gov.observe_frame_pacing(60.0,16.667,240,1.0),"first six real frame seconds are warmup")
	check(gov.effective_quality()=="cinematic","warmup preserves user maximum")
	for i in range(3):
		check(not gov.observe_frame_pacing(65.0,46.0,240,1.0),"jank needs sustained period not a one-second false downgrade")
	check(gov.observe_frame_pacing(65.0,46.0,240,1.0),"severe 46ms p95 degrades graphics even when averaged FPS is 65")
	check(gov.effective_quality()=="standard","mobile lowers exactly one visual tier")
	for i in range(4):
		gov.observe_frame_pacing(65.0,49.0,240,1.0)
	check(gov.effective_quality()=="low","persistent high p95 selects constrained GPU tier")
	for i in range(12):
		gov.observe_frame_pacing(60.0,38.0,240,1.0)
	check(gov.effective_quality()=="low","poor p95 prevents false recovery under good average FPS")
	for i in range(12):
		gov.observe_frame_pacing(60.0,16.5,240,1.0)
	check(gov.effective_quality()=="standard","sustained genuinely smooth frames restore one tier")
	for i in range(12):
		gov.observe_frame_pacing(60.0,16.5,240,1.0)
	check(gov.effective_quality()=="cinematic","recovery never exceeds player's cinematic ceiling")
	gov.configure("cinematic",true)
	for i in range(5):
		gov.observe_frame_pacing(60.0,120.0,3,1.0)
	check(gov.effective_quality()=="cinematic","unqualified p95 from only 3 frames cannot downgrade")
	for i in range(6):
		gov.observe_frame_pacing(60.0,16.0,240,1.0)
	for i in range(8):
		gov.observe_frame_pacing(65.0,50.0,240,1.0,false)
	check(gov.effective_quality()=="cinematic","background browser never triggers a false downgrade")
	gov.configure("standard",false)
	for i in range(30):
		gov.observe_frame_pacing(10.0,100.0,240,1.0)
	check(gov.effective_quality()=="standard","desktop manual quality is never overridden")
	gov.configure("low",true)
	for i in range(30):
		gov.observe_frame_pacing(10.0,100.0,240,1.0)
	check(gov.effective_quality()=="low","lowest device tier cannot be driven below its minimum")
	var bench = BENCH.new()
	check(bench.report()["status"]=="not-ready","benchmark cannot claim synthetic device proof before capture")
	bench.begin("cinematic",Vector2(390,844),"SyntheticNativeTest")
	for i in range(1500):
		if not bench.active: break
		bench.record_frame(0.050 if i%5==0 else 1.0/60.0,45)
	check(bench.completed,"full 2s warmup + 20s capture completes with mixed real-frame samples")
	var report: Dictionary = bench.report()
	check(report["status"]=="complete","no report is emitted before capture ends")
	check(int(report["r48_over_30fps_frame_budget"])>70,"30fps stutter count is measured, not guessed")
	check(int(report["r48_over_60fps_frame_budget"])>=int(report["r48_over_30fps_frame_budget"]),"slow 60fps counts include 30fps misses")
	check(float(report["r48_stutter_frame_percent_30fps"])>12.0,"stutter ratio follows real sampled frame times")
	check(float(report["r48_max_render_frame_ms"])>=49.9,"50ms hitch is not hidden by average FPS")
	check(float(report["p95_frame_ms"])>=49.0,"p95 frame percentile detects periodic stutters")
	check(float(report["r48_p95_fps_equivalent"])<25.0,"p95 FPS equivalent honestly reflects visible jank")
	check(report["physical_hardware_attested"]==false and report["source_sha_verified"]==false,"no synthetic Android/iOS certification")
	bench.begin("low",Vector2(320,568),"SyntheticNativeTest")
	check(bench.over_30fps_budget==0 and bench.over_60fps_budget==0 and bench.worst_frame_ms==0.0,"new measurement resets all R48 counters")
	bench.record_frame(NAN,40)
	check(bench.dropped==1 and bench.over_30fps_budget==0,"NaN cannot fabricate jank readings")
	var main: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("adaptive_graphics.observe_frame_pacing("),"real live game runs actual p95-aware governor")
	check(main.contains("frame_metrics.p95_ms(),frame_metrics.samples()"),"qualifying rolling render-frame samples are passed to GPU governor")
	check(main.contains("device_benchmark.record_frame(delta,draw_calls,DisplayServer.window_is_focused())"),"opt-in frame tester still measures true player render ticks")
	var runtime: Variant=load("res://scripts/main.gd")
	check(runtime is Script and runtime.can_instantiate(),"original player gameplay parses after R48 diagnostics upgrade")
	await process_frame
	print("EMPIRE OMEGA R48 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
