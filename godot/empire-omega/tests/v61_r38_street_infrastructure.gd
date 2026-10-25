extends SceneTree
## R38 native street props: genuine Godot MultiMesh intersection architecture.
const PROPS = preload("res://scripts/horizon_intersection_details.gd")
const ROADSCAPE = preload("res://scripts/horizon_roadscape.gd")
var passed := 0
var failed := 0
func check(ok: bool,reason: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("EMPIRE OMEGA R38 ROAD FAILED: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var details: Node3D = PROPS.new()
	root.add_child(details)
	check(details.get("intersection_count")==81,"original 9x9 road grid generates 81 intersections")
	check(details.get("batch_count")==4 and details.get_child_count()==4,"only four real draw-call batches")
	check(details.get_node("R38RealCurbStones") is MultiMeshInstance3D,"real 3D curb stone geometry")
	check(details.get_node("R38StormDrainGrates") is MultiMeshInstance3D,"real sunken road edge grates")
	check(details.get_node("R38ProtectiveMetalBollards") is MultiMeshInstance3D,"actual metal bollard mesh")
	check(details.get_node("R38BollardMetalCaps") is MultiMeshInstance3D,"actual metal cap mesh")
	check(details.call("geometry_instances")==81*20,"exact 1620 real geometry instances across 4 GPU batches")
	for node in details.get_children():
		check(node is MultiMeshInstance3D,"all fixtures batched, no per-corner object explosion")
		if node is MultiMeshInstance3D:
			check(node.multimesh.instance_count<=PROPS.MAX_INSTANCES,"mesh instance budget enforced")
			check(node.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"additional metal details do not add shadow passes")
			check(node.get_child_count()==0,"decorative mesh has no fake physical collisions or gameplay forces")
	var curb: Transform3D=details.get_node("R38RealCurbStones").multimesh.get_instance_transform(0)
	check(absf(curb.origin.x)<=224.0 and absf(curb.origin.z)<=224.0,"actual curb stays inside playable map")
	var drain: Transform3D=details.get_node("R38StormDrainGrates").multimesh.get_instance_transform(0)
	print("R38 REAL DRAIN ORIGIN: ",drain.origin," | world: ",details.global_position)
	check(absf(drain.origin.y-0.20)<0.01,"storm grate sits flush with existing road")
	details.call("set_quality","low")
	check(not details.visible,"LOW hides all four decorative mesh batches")
	details.call("set_quality","standard")
	check(details.visible and not details.get_node("R38BollardMetalCaps").visible,"STANDARD removes micro-details")
	details.call("set_quality","cinematic")
	check(details.get_node("R38BollardMetalCaps").visible,"CINEMATIC restores original 3D metal caps")
	details.queue_free()
	var streets: Node3D=ROADSCAPE.new()
	root.add_child(streets)
	var city_details: Node3D=streets.get("intersection_details")
	check(city_details!=null and city_details.is_inside_tree(),"original real roadscape now contains R38")
	streets.call("set_intersection_quality","low")
	check(not city_details.visible,"real roadscape exposes mobile LOD controls")
	streets.queue_free()
	var world_script: Variant=load("res://scripts/world_builder.gd")
	check(world_script!=null and world_script is Script and world_script.can_instantiate(),"original city world parses with R37 textures and R38 props")
	if world_script!=null and world_script is Script and world_script.can_instantiate():
		var world: Node3D=world_script.new()
		root.add_child(world)
		var scenic: Node3D=world.get("horizon_scenic")
		check(scenic!=null and scenic.is_inside_tree(),"live gameplay city includes original scenic systems")
		var instance: Node3D=scenic.get("intersection_details") if scenic!=null else null
		check(instance!=null and instance.get("batch_count")==4,"real playable city receives 4 bounded batches")
		world.call("apply_visual_budget","low")
		check(instance!=null and not instance.visible,"actual mobile LOW budget hides decorations")
		world.call("apply_visual_budget","cinematic")
		check(instance!=null and instance.visible,"actual cinematic tier displays new urban geometry")
		world.queue_free()
	var original: Variant=load("res://scripts/main.gd")
	check(original!=null,"unmodified driving game still parses")
	await process_frame
	print("EMPIRE OMEGA R38 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
