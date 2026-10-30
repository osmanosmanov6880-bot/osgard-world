extends SceneTree
## R187 actual native original signal network and physical asphalt paint.
const SIG=preload("res://scripts/traffic_signal_controller.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R187 NATIVE REAL ROAD MARKING FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var lights: Node3D=SIG.new()
	root.add_child(lights)
	lights.set_process(false)
	var marks: Node3D=lights.get("real_junction_box_paint") as Node3D
	check(marks!=null and marks.source_geometry_valid() and
		marks.get_child_count()==2,
		"source original 16-junction traffic network physically contains 2 GPU keep-clear mesh groups")
	check(marks.painted["outline"].multimesh.instance_count==64 and
		marks.painted["diagonal"].multimesh.instance_count==80 and
		marks.painted["outline"].multimesh.mesh is BoxMesh,
		"real 144 original 3D painted road strips share TWO BoxMeshes without generated textures")
	check(marks.painted["outline"].visible and
		marks.painted["diagonal"].visible and
		lights.call("visual_state_is_consistent"),
		"standard original actual junctions have complete source visuals and correct 16 traffic clocks")
	lights.call("sync_city_power",{"energy":100,"day_clock":22.0})
	check(marks.materials["outline"].emission_enabled and
		marks.materials["diagonal"].emission_enabled,
		"original true city night and power drive understated source-painted yellow reflectance")
	lights.call("set_quality","low")
	check(marks.painted["outline"].visible and
		not marks.painted["diagonal"].visible and
		not marks.materials["outline"].emission_enabled and
		marks.source_geometry_valid(),
		"LOW keeps real legal box border but removes optional diagonal hatches and night glow")
	lights.call("set_quality","cinematic")
	check(marks.painted["diagonal"].visible and
		marks.materials["outline"].emission_enabled and
		is_equal_approx(marks.city_hour,22.0),
		"cinematic restores real 3D yellow hatches without resetting source night clock")
	lights.call("sync_city_power",{"energy":0,"day_clock":22.0})
	check(not marks.materials["outline"].emission_enabled and
		marks.painted["outline"].visible,
		"city power outage disables glow but real physical road hazard lines remain visible")
	check(marks.find_children("*","CollisionShape3D",true,false).is_empty() and
		marks.source_geometry_valid() and
		lights.call("visual_state_is_consistent"),
		"original physical signals remain valid with zero new collision walls")
	lights.queue_free()
	await process_frame
	print("CITY REIGN R187 TRUE GODOT BOX PAINT: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
