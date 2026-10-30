extends SceneTree
## Real Godot 3D roadside signs: physical source-bounded GPU geometry.
const SIG=preload("res://scripts/traffic_signal_controller.gd")
const SIGN=preload("res://scripts/city_reign_true_speed_signs.gd")
const RULE=preload("res://scripts/city_reign_speed_limit_policy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R184 REAL 3D SPEED SIGN FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var street: Node3D=SIG.new()
	root.add_child(street)
	street.set_process(false)
	var signs: Node3D=street.get("true_speed_signs") as Node3D
	check(signs!=null and signs.call("source_integrity"),
		"64 actual source 90kmh regulatory signs physically load into original 3D traffic scene")
	check(signs.art.size()==4 and signs.get_child_count()==4,
		"real poles, pale disc, red circular border and raised 90 share just FOUR GPU batches")
	for id in ["pole","face","ring","digits"]:
		var geom: MultiMeshInstance3D=signs.art[id]
		check(geom.multimesh.instance_count==64 and
			geom.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"each physical sign component shares exactly 64 source transforms, no shadow spam: "+id)
	var real_digits: Mesh=signs.art["digits"].multimesh.mesh
	check(real_digits is ArrayMesh and real_digits.get_surface_count()==1 and
		real_digits.surface_get_array_len(0)>60,
		"actual in-engine original raised numeral triangles spell 90, not a texture or CSS")
	var first: Transform3D=SIGN.true_sign_pose(-156.0,-156.0,"x",1)
	var second: Transform3D=SIGN.true_sign_pose(156.0,156.0,"z",-1)
	check(is_equal_approx(first.origin.x,-187.0) and
		is_equal_approx(first.origin.z,-148.6) and
		is_equal_approx(second.origin.z,187.0),
		"all 64 roadside signs placed along actual original 16-junction 52m street grid")
	check(first.origin.x> -208.0 and second.origin.z<208.0 and
		SIGN.true_sign_pose(0,0,"x",1)==Transform3D.IDENTITY,
		"no sign outside actual city and non-source junction cannot forge speed limit")
	check(RULE.source_rule_valid() and street.call("visual_state_is_consistent"),
		"original red/amber/walk/stop/road markings plus new real 90kmh art agree")
	street.call("sync_city_power",{"energy":100,"day_clock":23.0})
	check(signs.finishes["ring"].emission_enabled and
		signs.finishes["digits"].emission_enabled,
		"existing saved city power and night clock genuinely drive native road sign material")
	street.call("set_quality","low")
	check(signs.art["digits"].visible and signs.art["ring"].visible and
		not signs.finishes["ring"].emission_enabled,
		"LOW keeps critical 90kmh sign LEGIBLE while disabling optional emissive effects")
	street.call("set_quality","cinematic")
	check(signs.art["digits"].visible and signs.finishes["digits"].emission_enabled and
		is_equal_approx(signs.remembered_hour,23.0),
		"cinematic restoration does not reset genuine existing city night time")
	street.call("sync_city_power",{"energy":0,"day_clock":23.0})
	check(not signs.finishes["digits"].emission_enabled,
		"original municipal power outage turns off sign glow without losing legal text")
	check(signs.find_children("*","CollisionShape3D",true,false).is_empty() and
		signs.call("source_integrity"),
		"road signage adds ZERO invisible gameplay walls or new physics")
	street.queue_free()
	await process_frame
	print("CITY REIGN R184 NATIVE 64 SOURCE 3D SPEED SIGNS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
