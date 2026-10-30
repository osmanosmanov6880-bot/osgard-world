extends SceneTree
## R188 original opt-in LAB: real physical steering from CharacterBody3D,
## NEVER confused with synthetic device FPS or individual route telemetry.
const LAB=preload("res://scripts/city_reign_mobility_evidence.gd")
class NativeSteeredCar:
	extends CharacterBody3D
	var speed: float=3.0
	var stopped_seconds: float=0.0
	var last_crosswalk_occupied: bool=false
	var last_junction_guard_active: bool=false
	var junction_hold_seconds: float=0.0
	var last_steer_command_rad: float=0.24
	var last_steer_fallback: bool=false
class NativeCitizen:
	extends RefCounted
	var planned_velocity: Vector3=Vector3.ZERO
	var signal_status: String="wait"
	var signal_wait_seconds: float=0.0
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R188 LIVE CITY OPT-IN PHYSICAL STEER LAB FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var lab=LAB.new()
	check(lab.report()["status"]=="not-ready" and not lab.active,
		"real native steering observation never starts before explicit player LAB action")
	var vehicles: Array=[]
	var people: Array=[]
	for i in range(12):
		var car:=NativeSteeredCar.new()
		car.last_steer_command_rad=0.24 if i<4 else 0.0
		car.last_steer_fallback=i==6
		vehicles.append(car)
	for i in range(34):
		people.append(NativeCitizen.new())
	lab.begin()
	for i in range(48):
		lab.observe(0.5,vehicles,people,float(i)*0.5,true,true)
	var report: Dictionary=lab.report()
	check(report.get("status","")=="complete" and report["sample_count"]==40 and
		report["original_vehicles_min"]==12 and report["original_walkers_max"]==34,
		"original source 2Hz traffic report samples exactly 40 frames of 12 actual native bodies")
	check(report["physical_front_wheel_steering_observations"]==160 and
		report["real_asphalt_safety_rejections"]==40 and
		absf(float(report["maximum_observed_front_wheel_angle_deg"])-rad_to_deg(0.24))<0.001,
		"native 3D steering and actual rejected physical road-edge motion are aggregated correctly")
	check(report["hardware_attested"]==false and
		report["captures_raw_positions"]==false and
		report["network_upload"]==false,
		"synthetic 20s fixture is arithmetic only, NEVER fabricated real smartphone FPS evidence")
	var payload: String=JSON.stringify(report)
	check(not payload.contains("global_position") and
		not payload.contains("citizen_id") and
		not payload.contains("device_id") and
		not payload.contains("route_points"),
		"original user-controlled export NEVER contains individual trajectory or identity data")
	lab.begin()
	check(lab.physical_corner_steer_snapshots==0 and
		lab.lateral_guard_snapshots==0 and
		lab.highest_native_wheel_steer_degrees==0.0,
		"fresh opt-in measurement clears true steering state instead of reusing prior city snapshot")
	lab.observe(0.5,vehicles,people,0.0,true,false)
	check(lab.report()["status"]=="not-ready" and
		lab.report()["aborted"]=="browser-backgrounded",
		"background tab cannot be passed off as real 3D live performance evidence")
	for car in vehicles:
		car.free()
	print("CITY REIGN R188 PRIVATE SOURCE STEERING EVIDENCE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
