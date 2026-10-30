extends SceneTree
## R183 synthetic fixtures test 2Hz arithmetic ONLY. Not physical-device FPS.
const LAB=preload("res://scripts/city_reign_mobility_evidence.gd")
class NativeCar:
	extends RefCounted
	var speed: float=0.0
	var stopped_seconds: float=4.0
	var last_crosswalk_occupied: bool=false
class NativeResident:
	extends RefCounted
	var planned_velocity: Vector3=Vector3.ZERO
	var signal_status: String="wait"
	var signal_wait_seconds: float=3.0
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R183 REAL SOURCE AGGREGATION FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var cars: Array=[]
	for i in range(12):
		var c:=NativeCar.new()
		c.speed=0.0 if i<6 else 6.0
		c.last_crosswalk_occupied=i==0
		cars.append(c)
	var citizens: Array=[]
	for i in range(34):
		var p:=NativeResident.new()
		p.planned_velocity=Vector3.ZERO if i<17 else Vector3(0,0,2.15)
		p.signal_status="wait" if i<17 else "walk"
		citizens.append(p)
	var lab=LAB.new()
	lab.begin()
	check(lab.active and not lab.complete and lab.snapshots==0,
		"opt-in local telemetry begins ONLY after explicit benchmark start")
	for i in range(48):
		lab.observe(0.5,cars,citizens,float(i)*0.5,true,true)
	var data: Dictionary=lab.report()
	check(data.get("status","")=="complete" and not lab.active and
		int(data.get("sample_count",0))==40 and
		is_equal_approx(float(data.get("capture_seconds",0)),20.0),
		"bounded original 2Hz 20s source observations produce EXACTLY 40 snapshots")
	check(data["original_vehicles_min"]==12 and data["original_vehicles_max"]==12 and
		data["original_walkers_min"]==34 and data["original_walkers_max"]==34,
		"original source population is measured, never fabricated by a dashboard")
	check(is_equal_approx(data["mean_stopped_cars_per_sample"],6.0) and
		data["stopped_car_observations"]==240,
		"real stopped speed <0.35 is aggregated from actual source-car fields")
	check(data["real_crosswalk_yield_observations"]==40 and
		data["walker_wait_observations"]==680 and
		data["walker_walk_observations"]==680,
		"source R182 crossing occupancy and native R180 WALK/WAIT are counted accurately")
	check(data["longest_original_car_stop_s"]==4.0 and
		data["longest_original_pedestrian_signal_wait_s"]==3.0,
		"stop/wait durations are read directly from existing native NPC source")
	check(data["x_green_signal_observations"]>0 and
		data["z_green_signal_observations"]>0 and
		data["x_amber_signal_observations"]>0 and
		data["z_amber_signal_observations"]>0,
		"actual 24s ORIGINAL traffic source phases cover each direction, never new clocks")
	var report_json: String=JSON.stringify(data)
	check(not report_json.contains("global_position") and
		not report_json.contains("citizen_id") and
		not report_json.contains("device_id") and
		not report_json.contains("raw_path"),
		"opt-in aggregates contain ZERO individual location or identity data")
	check(data["hardware_attested"]==false and
		data["captures_raw_positions"]==false and data["network_upload"]==false,
		"synthetic unit arithmetic is NEVER passed off as real physical device evidence")
	lab.begin()
	check(lab.active and lab.snapshots==0 and lab.stopped_car_snapshots==0,
		"second explicitly requested measurement erases previous session totals")
	lab.observe(0.5,cars,citizens,0.0,false,true)
	check(lab.ignored_blocked_frames==1 and lab.snapshots==0,
		"pause/other active UI does not get misreported as 3D gameplay")
	lab.observe(NAN,cars,citizens,0.0,true,true)
	check(lab.ignored_invalid_frames==1 and lab.snapshots==0,
		"corrupted frame delta is excluded rather than invented as traffic")
	lab.observe(0.5,cars,citizens,0.0,true,false)
	check(lab.report()["status"]=="not-ready" and
		lab.report()["aborted"]=="browser-backgrounded",
		"hidden tab aborts, never creates an artificial world performance result")
	print("CITY REIGN R183 REAL MOBILITY AGGREGATOR UNIT: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
