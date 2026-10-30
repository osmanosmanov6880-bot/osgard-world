extends SceneTree
## Source-authored real 3D WALK / WAIT GPU instances on original junctions.
const SIGNAL=preload("res://scripts/traffic_signal_controller.gd")
const ART=preload("res://scripts/city_reign_pedestrian_signal_art.gd")
const RULE=preload("res://scripts/city_reign_pedestrian_right_of_way.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,reason: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R180 REAL WALK SIGNAL ART FAIL: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var traffic: Node3D=SIGNAL.new()
	root.add_child(traffic)
	traffic.set_process(false)
	var walkers: Node3D=traffic.get("pedestrian_signs") as Node3D
	check(walkers!=null and bool(walkers.call("batches_are_bounded")),
		"exactly FIVE real 3D GPU batches with shared sculpted original walk/hand meshes")
	check(walkers.drawings.size()==5 and
		walkers.drawings["housing"].multimesh.instance_count==32,
		"two real housing heads at each of the same original sixteen intersections")
	for axis in ["x","z"]:
		check(walkers.drawings[axis+"_walk"].multimesh.instance_count==16 and
			walkers.drawings[axis+"_wait"].multimesh.instance_count==16,
			"original LED volumes have exactly 16 shared physical WALK and WAIT icons "+axis)
	check(traffic.call("visual_state_is_consistent") and
		walkers.states["x"]=="walk" and walkers.states["z"]=="wait",
		"actual signal visual begins consistent with green X and red Z source")
	traffic.set("elapsed",10.0)
	traffic.call("_process",0.02)
	check(walkers.states["x"]=="wait" and walkers.states["z"]=="wait",
		"insufficient crossing time reverses X face to WAIT BEFORE amber while cars remain green")
	traffic.set("elapsed",12.0)
	traffic.call("_update_lights")
	check(walkers.states["z"]=="walk" and walkers.states["x"]=="wait" and
		walkers.call("matches_source",12.0),
		"real source traffic phase transition drives the WALK signs without independent clock")
	traffic.call("sync_city_power",{"energy":0,"day_clock":23.0})
	check(not walkers.finishes["z_walk"].emission_enabled,
		"real city electricity loss extinguishes 3D pedestrian signal emission")
	traffic.call("sync_city_power",{"energy":100,"day_clock":23.0})
	check(walkers.finishes["z_walk"].emission_enabled,
		"original saved power restores physical night-time illumination")
	traffic.call("set_quality","low")
	check(not walkers.drawings["housing"].visible and
		not walkers.drawings["x_walk"].visible and
		traffic.stop_bars.draws["white_stop_lines"].visible,
		"LOW graphics disables all five expensive pedestrian batches while retaining road lines")
	traffic.call("set_quality","standard")
	check(walkers.drawings["housing"].visible and
		walkers.call("batches_are_bounded") and
		traffic.call("visual_state_is_consistent"),
		"original 3D walking heads restore without adding nodes, physics bodies or fake signals")
	check(walkers.find_children("*","CollisionShape3D",true,false).is_empty(),
		"walk signs never place invisible walls on real city roads")
	var walk_mesh: Mesh=walkers.drawings["x_walk"].multimesh.mesh
	check(walk_mesh is ArrayMesh and walk_mesh.get_surface_count()==1 and
		walk_mesh.surface_get_array_len(0)>=36,
		"real authored 3D pedestrian silhouettes, not photo billboards or CSS overlays")
	var src: String=FileAccess.get_file_as_string("res://scripts/traffic_signal_controller.gd")
	check(src.contains("R180_WALK_ART.new()") and
		src.contains("pedestrian_signs.call(\"sync_phase\"") and
		RULE.face_state(12.0,"z")=="walk",
		"actual existing 3D traffic signal source drives all new native walk heads")
	traffic.queue_free()
	await process_frame
	print("CITY REIGN R180 REAL GPU PEDESTRIAN SIGNALS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
