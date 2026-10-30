extends SceneTree
## R178 original real traffic signal Node3D controls 16 native 3D junctions.
const GRID=preload("res://scripts/traffic_signal_controller.gd")
const RULE=preload("res://scripts/city_reign_intersection_policy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R178 PHYSICAL SIGNAL ROAD MARKINGS FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var signals: Node3D=GRID.new()
	root.add_child(signals)
	signals.set_process(false)
	var road: Node3D=signals.get("stop_bars") as Node3D
	check(road!=null and bool(road.call("source_budget_ok")),
		"actual native signal grid installs only 3 shared GPU road-mark batches")
	check(signals.get("lights").size()==16 and
		signals.get("legacy_signal_roots").size()==16 and
		road.draws["white_stop_lines"].multimesh.instance_count==64,
		"same 16 real junctions and 64 painted approach lines, no new intersections")
	check(road.draws["x_reflectors"].multimesh.instance_count==32 and
		road.draws["z_reflectors"].multimesh.instance_count==32,
		"exact 64 reflective signal-linked approach studs, not 64 new lights")
	var xline: Transform3D=road.source_position(-156.0,-156.0,"x",1)
	var zline: Transform3D=road.source_position(-156.0,-156.0,"z",-1)
	check(absf(xline.origin.x-(-148.0))<0.01 and
		absf(zline.origin.z-(-164.0))<0.01 and
		absf(xline.origin.y-0.204)<0.01,
		"actual road line is outside original collision box and correctly placed")
	check(signals.call("permitted",Vector3(-156,0,-156),Vector3.RIGHT) and
		not signals.call("permitted",Vector3(-156,0,-156),Vector3.BACK),
		"original physical signal begins X GREEN, Z RED")
	signals.set("elapsed",10.6)
	signals.call("_update_lights")
	check(not signals.call("permitted",Vector3(-156,0,-156),Vector3.RIGHT) and
		signals.call("visual_state_is_consistent") and road.phases_match(10.6),
		"visible native amber signal and ACTUAL AI right of way agree")
	check(road.synced_states["x"]=="amber" and road.synced_states["z"]=="red",
		"shared source 3D reflector PBR tint follows actual source timer")
	signals.set("elapsed",12.0)
	signals.call("_update_lights")
	check(signals.call("permitted",Vector3(-156,0,-156),Vector3.BACK) and
		not signals.call("permitted",Vector3(-156,0,-156),Vector3.RIGHT),
		"after exact phase switch Z gets green and X gets real red")
	signals.call("sync_city_power",{"energy":0,"day_clock":22.0})
	check(not road.paints["x_reflectors"].emission_enabled and
		not road.paints["z_reflectors"].emission_enabled,
		"real zero-electricity city physically turns road reflectors off at night")
	signals.call("sync_city_power",{"energy":100,"day_clock":22.0})
	check(road.paints["x_reflectors"].emission_enabled and
		road.paints["z_reflectors"].emission_enabled,
		"same source state powers actual night reflective road geometry")
	signals.call("set_quality","low")
	check(road.draws["white_stop_lines"].visible and
		not road.draws["x_reflectors"].visible and
		not road.draws["z_reflectors"].visible,
		"LOW keeps source painted safety line but removes two premium GPU groups")
	signals.call("set_quality","cinematic")
	check(road.draws["x_reflectors"].visible and road.draws["z_reflectors"].visible
		and road.source_budget_ok() and signals.call("visual_state_is_consistent"),
		"cinematic reinstates same original three batches without extra geometry")
	check(road.find_children("*","CollisionShape3D",true,false).is_empty(),
		"R178 lane markings are paint, NEVER new invisible road collision walls")
	signals.queue_free()
	await process_frame
	print("CITY REIGN R178 REAL 16 JUNCTIONS 3D: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
