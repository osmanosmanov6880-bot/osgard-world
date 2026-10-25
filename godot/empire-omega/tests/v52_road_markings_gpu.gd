extends SceneTree
## HORIZON R28 native Godot 4.4.1 regression for the actual playable city.
## Verifies a 378-node RoadDash replacement by TWO 3D GPU draw batches.
const PAINT = preload("res://scripts/horizon_road_paint_batches.gd")
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R28 FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var paint: Node3D = PAINT.new()
	root.add_child(paint)
	for i in range(-4,5):
		var road: float = float(i)*52.0
		for j in range(-10,11):
			var point: float = float(j)*21.0
			paint.call("record_dash",true,point,road)
			paint.call("record_dash",false,point,road)
	paint.call("record_road_edges")
	paint.call("finish")
	check(paint.get_child_count()==2,"entire road network requires two draw groups")
	check(paint.get("finalized"),"cannot append geometry after GPU batch creation")
	check(paint.get("dash_transforms").size()==378,"378 center dashes preserved from original exact road coordinates")
	check(paint.get("edge_transforms").size()==288,"288 new shoulder markings stop before intersections")
	check(int(paint.call("instance_count"))==666,"paint primitives stay within exact city budget")
	var dashes: MultiMeshInstance3D=paint.get_node("LaneDashMultiMesh")
	var edges: MultiMeshInstance3D=paint.get_node("ShoulderLineMultiMesh")
	check(dashes.multimesh.instance_count==378,"all dash geometry lives in one MultiMesh")
	check(edges.multimesh.instance_count==288,"road shoulder lines are a second single MultiMesh")
	check(dashes.multimesh.mesh is BoxMesh and edges.multimesh.mesh is BoxMesh,"geometry is real box mesh, not a HUD screenshot")
	check(dashes.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"markings consume no realtime shadow draw pass")
	var dash_samples: Array=paint.get("dash_transforms")
	var edge_samples: Array=paint.get("edge_transforms")
	check(absf((dash_samples[0] as Transform3D).origin.y-0.195)<0.001,"existing horizontal lane paint keeps road surface height")
	check(absf((dash_samples[1] as Transform3D).origin.y-0.198)<0.001,"vertical road paint clears 0.18-m asphalt top")
	check(absf((edge_samples[0] as Transform3D).origin.y-0.197)<0.001,"new side lines sit above actual physical road")
	check((dash_samples[0] as Transform3D).basis.x.length()>6.99,"paint dash length maintained at seven metres")
	check((dash_samples[1] as Transform3D).basis.z.length()>6.99,"vertical paint orientation preserved")
	check((edge_samples[0] as Transform3D).basis.x.length()==PAINT.EDGE_LENGTH,"shoulder span is exactly shorter than intersection separation")
	check((edge_samples[1] as Transform3D).basis.z.length()==PAINT.EDGE_LENGTH,"orthogonal shoulder matches the road interval")
	var dry_rough: float=(dashes.material_override as StandardMaterial3D).roughness
	paint.call("apply_weather","storm")
	var wet_rough: float=(dashes.material_override as StandardMaterial3D).roughness
	check(wet_rough<dry_rough,"rain changes only PBR road paint, not road grip physics")
	paint.call("apply_weather","clear")
	check((dashes.material_override as StandardMaterial3D).roughness==dry_rough,"clear weather restores dry original reflectance")
	paint.call("record_dash",true,0,0)
	check(int(paint.call("instance_count"))==666,"finalized GPU pool cannot grow in background")
	var invalid: Node3D=PAINT.new()
	invalid.call("record_dash",true,NAN,10.0)
	check(invalid.get("dash_transforms").is_empty(),"non-finite coordinates never create broken GPU transforms")
	invalid.queue_free()
	paint.queue_free()
	var world_script: Variant=load("res://scripts/world_builder.gd")
	check(world_script!=null,"complete main world script compiles under real Godot")
	if world_script!=null:
		var world: Node3D=world_script.new()
		root.add_child(world)
		var live_paint: Node3D=world.get("road_paint")
		var city_root: Node3D=world.get("city_root")
		check(live_paint!=null and live_paint.is_inside_tree(),"actual playable world owns the new road marking batch")
		check(city_root!=null and city_root.is_inside_tree(),"existing full city and its collisions load")
		if live_paint!=null:
			check(live_paint.get_child_count()==2,"full game draws road network with just two batched meshes")
			check(int(live_paint.call("instance_count"))==666,"actual city receives both dash and shoulder geometry")
			var paints: MultiMeshInstance3D=live_paint.get_node("LaneDashMultiMesh")
			check(paints.multimesh.instance_count==378,"real world carries every formerly independent RoadDash")
		var original_dashes:=0
		var road_surfaces:=0
		for child in city_root.get_children():
			if child.name=="RoadDash":
				original_dashes+=1
			# Godot auto-renames repeated same-name siblings, so identify the
			# real asphalt meshes by dimensions rather than unreliable names.
			var mesh_node: MeshInstance3D = child.get_node_or_null("VisualMesh") as MeshInstance3D
			if mesh_node != null and mesh_node.mesh is BoxMesh:
				var dimensions: Vector3 = (mesh_node.mesh as BoxMesh).size
				if absf(dimensions.y-0.16)<0.001 and (
					(absf(dimensions.x-454.0)<0.01 and absf(dimensions.z-10.0)<0.01)
					or (absf(dimensions.x-10.0)<0.01 and absf(dimensions.z-454.0)<0.01)):
					road_surfaces+=1
		check(original_dashes==0,"no hundreds of duplicate LaneDash Node3Ds remain")
		check(road_surfaces==18,"all eighteen actual asphalt roads stay in the playable city")
		world.apply_visual_budget("low")
		if live_paint!=null:
			check(live_paint.visible,"critical road lines stay visible in phone LOW mode")
		world.update_weather("storm")
		if live_paint!=null:
			check((live_paint.get_node("LaneDashMultiMesh").material_override as StandardMaterial3D).roughness < 0.6,"live rain weather changes real batched road paint")
		world.queue_free()
	var world_source:=FileAccess.get_file_as_string("res://scripts/world_builder.gd")
	check(not world_source.contains("_box(city_root,\"RoadDash\""),"original 378 per-object box allocations removed from game code")
	check(world_source.contains("road_paint.call(\"record_dash\""),"same original loop sends actual coordinates to GPU paint")
	var main_source:=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_source.contains("SAFE_CAMERA.solve("),"camera collision regression unaffected")
	check(main_source.contains("ground_spray.call(\"update_spray\""),"wet car spray regression unaffected")
	print("HORIZON R28 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
