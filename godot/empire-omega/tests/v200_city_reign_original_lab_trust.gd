extends SceneTree
## R183 original LAB remains explicit + honest about hardware attestations.
const LAB=preload("res://scripts/city_reign_mobility_evidence.gd")
const FRAMES=preload("res://scripts/horizon_device_frame_benchmark.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R183 REAL IN-GAME LAB INTEGRATION FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var core: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(core.contains("street_life_benchmark.observe(") and
		core.contains("street_life_benchmark.begin()") and
		core.contains("output_report[\"original_live_street_life\"]"),
		"original MAIN directly records mobility beside opt-in FPS and adds it to SAME user export")
	check(core.contains("device_benchmark.begin(") and
		core.contains("device_benchmark.record_frame(") and
		core.contains("device_benchmark.report()"),
		"all original measured render frame LAB functionality is kept without fake samples")
	var hud: String=FileAccess.get_file_as_string("res://scripts/hud.gd")
	check(hud.contains("benchmark_start_requested") and
		hud.contains("benchmark_export_requested") and
		hud.contains("r177_playtest_export"),
		"existing simple original benchmark and first-six report UI preserved; no extra controls")
	var real_frame: RefCounted=FRAMES.new()
	real_frame.call("begin","standard",Vector2(1280,720),"QA-SYNTHETIC")
	var snapshot: Dictionary=real_frame.call("report")
	check(snapshot.get("status","")=="not-ready" and
		snapshot.get("hardware_attested",false)==false,
		"unmeasured synthetic benchmark cannot be misrepresented as phone frame evidence")
	var lab=LAB.new()
	var before: Dictionary=lab.report()
	check(before.get("status","")=="not-ready" and
		before.get("hardware_attested",false)==false,
		"mobility audit also refuses to present nonexistent completed gameplay samples")
	var report: Dictionary=real_frame.call("report")
	report["original_live_street_life"]=lab.report()
	check(report["original_live_street_life"]["status"]=="not-ready" and
		report["status"]=="not-ready",
		"original frame JSON + mobility JSON are separate honest unfinished evidence")
	var encoded: String=JSON.stringify(report)
	check(encoded.contains("original_live_street_life") and
		encoded.contains("hardware_attested") and
		not encoded.contains("global_position"),
		"same local JSON remains machine-readable and privacy-safe")
	check(LAB.MAX_SNAPSHOTS==48 and LAB.CAPTURE_SECONDS==20.0 and
		LAB.SAMPLE_INTERVAL_SECONDS==0.5,
		"bounded 2Hz audit shares existing 20s real frame benchmark session")
	print("CITY REIGN R183 ORIGINAL LAB TRUST: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
