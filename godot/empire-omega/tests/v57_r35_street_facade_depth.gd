extends SceneTree
## R35: genuine geometric street-facing balconies in <=4 shared GPU batches.
const BALCONIES = preload("res://scripts/horizon_facade_balconies.gd")
const WORLD = preload("res://scripts/world_builder.gd")
var passed := 0
var failed := 0
func check(ok: bool,why: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("R35 ARCHITECTURE FAILED: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var balconies := BALCONIES.new()
	balconies.record(Vector3(0,11,0),12,22,0,0)
	balconies.record(Vector3(52,7.5,0),11,15,1,3)
	balconies.record(Vector3(0,9.5,52),13,19,2,1)
	check(balconies.source_buildings==3,"all valid buildings are counted")
	check(balconies.balcony_count==6,"only selected buildings receive three upper floor assemblies")
	check(balconies.slab_poses.size()==6 and balconies.guard_poses.size()==6,"one real slab and guard per balcony")
	check(balconies.post_poses.size()==12 and balconies.rail_poses.size()==6,"two solid metal posts per unit")
	check(balconies.slab_poses[0].origin.z < -6.0,"front-facing balconies project outside real wall")
	check(balconies.slab_poses[3].origin.x < -6.5,"rotated side-facing balconies project outside side wall")
	balconies.finalize()
	check(balconies.batch_count==4 and balconies.get_child_count()==4,"four batches total, not a node per building")
	check(balconies.surface_instance_count()==30,"all five physical parts per balcony are GPU-instanced")
	for child in balconies.get_children():
		check(child is MultiMeshInstance3D,"no extraneous collision or physics nodes in premium detail")
		if child is MultiMeshInstance3D:
			check(child.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"extra detail does not inflate expensive shadow passes")
			check(child.multimesh.instance_count<=BALCONIES.MAX_INSTANCES_PER_GROUP,"bounded GPU instance array")
	balconies.set_quality("low")
	check(not balconies.visible,"LOW tier removes balcony draw calls entirely")
	balconies.set_quality("standard")
	check(balconies.visible and not balconies.get_node("R35MetalCornerPosts").visible,
		"STANDARD keeps authentic slabs but avoids fine-metal detail")
	balconies.set_quality("cinematic")
	check(balconies.get_node("R35MetalCornerPosts").visible,
		"CINEMATIC restores genuine 3D metallic trim geometry")
	balconies.queue_free()
	var world := WORLD.new()
	root.add_child(world)
	var original: Node3D = world.get("facade_balconies")
	check(original!=null and original.is_inside_tree(),"real world owns the new batched architecture")
	if original!=null:
		check(original.get_parent().name=="ProceduralDistricts",
			"detail belongs to original city geometry")
		check(int(original.get("balcony_count"))>25,
			"playable urban environment receives repeated varied upper-floor detail")
		check(int(original.get("batch_count"))<=4,"real built city obeys four GPU-batch budget")
		check(int(original.call("surface_instance_count"))<=
			int(original.get("balcony_count"))*5,
			"real city draw instances are bounded by balcony count")
		world.apply_visual_budget("low")
		check(not original.visible,"actual phone LOW budget disables extras")
		world.apply_visual_budget("cinematic")
		check(original.visible and original.get_node("R35MetalCornerPosts").visible,
			"actual cinematic world restores detail")
	var main: Variant = load("res://scripts/main.gd")
	check(main!=null,"real world entry script parses")
	var source: String=FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(source.contains('facade_balconies.call("record"'),"actual building generator constructs real geometry")
	check(source.contains('facade_balconies.call("set_quality",visual_budget)'),
		"runtime responds to hardware-adaptive quality")
	world.queue_free()
	await process_frame
	print("EMPIRE OMEGA R35 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
