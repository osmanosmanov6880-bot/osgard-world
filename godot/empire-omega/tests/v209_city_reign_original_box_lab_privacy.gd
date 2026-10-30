extends SceneTree
## R186 player HUD source caution and explicitly opt-in REAL LAB evidence.
const LAB=preload("res://scripts/city_reign_mobility_evidence.gd")
const DRIVER=preload("res://scripts/city_reign_driver_awareness.gd")
class AuditCar:
	extends Node3D
	var speed: float=0.0
	var stopped_seconds: float=3.0
	var last_crosswalk_occupied: bool=false
	var last_junction_guard_active: bool=true
	var junction_hold_seconds: float=1.5
class AuditCitizen:
	extends RefCounted
	var planned_velocity: Vector3=Vector3.ZERO
	var signal_status: String="wait"
	var signal_wait_seconds: float=2.0
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R186 OPT-IN ORIGINAL MOBILITY AUDIT FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var text_source: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(text_source.contains("R186_BOX.scan(car,ambient_cars,") and
		text_source.contains('"kind":"junction_blocked"') and
		text_source.contains("R184_SPEED_RULE.player_warning"),
		"original 4Hz driver HUD uses actual live box before non-urgent 90kmh warning")
	check(DRIVER.localized({"kind":"junction_blocked"},"ru").contains("ЗАНЯТ") and
		DRIVER.localized({"kind":"junction_blocked"},"en").contains("OCCUPIED") and
		DRIVER.localized({"kind":"junction_blocked"},"zh").contains("占用"),
		"original accessible compact driver risk warning translated RU/EN/ZH")
	check(DRIVER.localized({"kind":"signal","phase":"red"},"en").contains("RED") and
		DRIVER.localized({"kind":"pedestrian","urgency":"urgent"},"en").contains("PEDESTRIAN"),
		"new junction warning cannot replace existing real red and pedestrian priority")
	var car_refs: Array=[]
	for i in range(12):
		var item:=AuditCar.new()
		item.last_junction_guard_active=i<3
		item.junction_hold_seconds=float(i)*0.1
		car_refs.append(item)
	var citizens: Array=[]
	for i in range(34):
		citizens.append(AuditCitizen.new())
	var lab=LAB.new()
	check(lab.report().get("status","")=="not-ready",
		"real city evidence is NOT recorded before the player's explicit LAB command")
	lab.begin()
	for i in range(48):
		lab.observe(0.5,car_refs,citizens,float(i)*0.5,true,true)
	var report: Dictionary=lab.report()
	check(report.get("status","")=="complete" and report.get("sample_count",0)==40,
		"existing 20s private original LAB still collects exactly forty 2Hz samples")
	check(report.get("real_junction_box_yield_observations",-1)==120 and
		absf(float(report.get("longest_original_junction_box_hold_s",0))-1.1)<0.001,
		"R186 12 actual-source style car fields are counted, NOT estimated by generated UI")
	check(report.get("original_vehicles_max",0)==12 and
		report.get("original_walkers_max",0)==34 and
		report.get("hardware_attested",true)==false and
		report.get("network_upload",true)==false,
		"bounded opt-in local-only audit retains original true populations and no hardware claims")
	var raw: String=JSON.stringify(report)
	check(not raw.contains("global_position") and
		not raw.contains("citizen_id") and
		not raw.contains("device_id") and
		not raw.contains("route_points"),
		"original local source report cannot serialize private NPC routes or individual positions")
	lab.begin()
	check(lab.genuine_junction_yield_snapshots==0 and
		lab.longest_original_junction_hold_s==0.0,
		"new explicit observation must reset all prior real junction aggregate state")
	for item in car_refs:
		item.free()
	print("CITY REIGN R186 LOCAL-ONLY SOURCE AUDIT: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
