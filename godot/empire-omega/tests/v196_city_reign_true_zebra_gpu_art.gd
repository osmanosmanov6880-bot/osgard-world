extends SceneTree
## R182 actual Godot 3D GPU road zebra paint on 16 real intersections.
const SIGNAL=preload("res://scripts/traffic_signal_controller.gd")
const ART=preload("res://scripts/city_reign_real_zebra_crossings.gd")
const SOURCE=preload("res://scripts/city_reign_intersection_policy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R182 REAL SOURCE 3D ZEBRA FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var original: Node3D=SIGNAL.new()
	root.add_child(original)
	original.set_process(false)
	var zebras: Node3D=original.get("real_zebra_crossings") as Node3D
	check(zebras!=null and zebras.source_geometry_valid(),
		"original native signal source authors 64 physical zebra crossings in TWO GPU batches")
	check(zebras.paint_instances.size()==2 and
		zebras.paint_instances["x"].multimesh.instance_count==192 and
		zebras.paint_instances["z"].multimesh.instance_count==192,
		"384 actual authored source zebra volume strips in exactly TWO draw batches")
	var a: Transform3D=ART.stripe_transform(-156.0,-156.0,"x",-1,0)
	var b: Transform3D=ART.stripe_transform(-156.0,-156.0,"z",1,5)
	check(is_equal_approx(a.origin.x,-162.325) and
		is_equal_approx(b.origin.z,-149.675) and
		is_equal_approx(a.origin.y,0.209),
		"source stripe is between source junction and original painted stop bar")
	check(a.origin.x>-156-SOURCE.STOP_LINE_M and
		b.origin.z< -156+SOURCE.STOP_LINE_M,
		"actual road paint NEVER extends across the physical original stop bar")
	var mesh: Mesh=zebras.paint_instances["x"].multimesh.mesh
	check(mesh is BoxMesh and is_equal_approx((mesh as BoxMesh).size.z,8.7) and
		(mesh as BoxMesh).size.x<0.3,
		"real native physical BoxMesh zebra crosses original 10m paved road surface")
	check(original.call("visual_state_is_consistent") and
		original.stop_bars.source_budget_ok() and
		original.pedestrian_signs.batches_are_bounded(),
		"source stop lines, WALK/WAIT 3D heads and all new real zebra meshes agree")
	original.call("sync_city_power",{"energy":100,"day_clock":23.0})
	check(zebras.paint_finishes["x"].emission_enabled and
		zebras.paint_finishes["z"].emission_enabled,
		"original saved night/power changes real reflective road paint illumination")
	original.call("set_quality","low")
	check(zebras.paint_instances["x"].visible and
		zebras.paint_instances["z"].visible and
		not zebras.paint_finishes["x"].emission_enabled,
		"LOW retains mandatory road paint but removes premium night emission")
	original.call("set_quality","cinematic")
	check(zebras.paint_instances["x"].visible and
		zebras.paint_finishes["x"].emission_enabled and
		zebras.current_hour==23.0,
		"cinematic quality DOES NOT corrupt the original city night clock")
	original.call("sync_city_power",{"energy":0,"day_clock":23.0})
	check(not zebras.paint_finishes["x"].emission_enabled,
		"power failure correctly disables native emissive zebra while paint remains visible")
	check(zebras.find_children("*","CollisionShape3D",true,false).is_empty(),
		"R182 zebra road paint has absolutely zero invisible physics/collision obstructions")
	check(zebras.source_geometry_valid() and original.call("visual_state_is_consistent"),
		"new road geometry does not invalidate the original signals and original scenes")
	original.queue_free()
	await process_frame
	print("CITY REIGN R182 ACTUAL 3D ZEBRA GPU PAINT: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
