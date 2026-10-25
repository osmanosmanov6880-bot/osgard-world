extends SceneTree
## EMPIRE Ω R45: actual stone roof-crown ArrayMesh in a single bounded
## Godot MultiMesh batch, plus integration into original playable city.
const TRIM = preload("res://scripts/horizon_architecture_trim.gd")
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R45 ROOFLINE FAILED: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var trim: MultiMeshInstance3D = TRIM.new()
	trim.record(Vector3(15,7,22),12.0,14.0)
	trim.record(Vector3(-25,12,-30),15.0,24.0)
	trim.finalize()
	check(trim.source_buildings==2,"source has two real roof plans")
	check(trim.placements.size()==8 and trim.authored_tints.size()==8,
		"four stone beams per building with a deterministic masonry tint")
	check(trim.multimesh.instance_count==8 and trim.multimesh.use_colors,
		"all roof beams and per-building colors stay in ONE draw call")
	check(trim.geometry_triangle_budget()==8*TRIM.TRIANGLES_PER_BEAM,
		"bounded geometric budget agrees with actual instance count")
	check(trim.authored_tints[0] != trim.authored_tints[4],
		"two distinct buildings produce different masonry tones")
	check(trim.multimesh.mesh is ArrayMesh,"original square prism replaced by sculpted stone crown")
	if trim.multimesh.mesh is ArrayMesh:
		var stone: ArrayMesh = trim.multimesh.mesh
		check(stone.get_surface_count()==1,"one original geometry surface")
		var arrays: Array = stone.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		check(vertices.size()==TRIM.TRIANGLES_PER_BEAM*3,
			"two-level bevel physically creates 52 independently shaded triangles")
		check(normals.size()==vertices.size(),"all bevelled faces have real surface normals")
		var all_finite := true
		var distinct_slopes: Dictionary = {}
		for n in normals:
			if not n.is_finite() or absf(n.length()-1.0)>0.01:
				all_finite=false
				break
			distinct_slopes[snappedf(n.y,0.1)] = true
		check(all_finite and distinct_slopes.size()>2,
			"bevels have legitimate flat, horizontal and slanted normal orientations")
		for v in vertices:
			if not v.is_finite() or absf(v.x)>0.51 or absf(v.y)>0.51 or absf(v.z)>0.51:
				all_finite=false
				break
		check(all_finite,"sculpted mesh remains inside bounded local geometry")
	check(trim.get_child_count()==0 and trim.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
		"architecture remains one batch with no decorative collision or new shadow map")
	var finish: StandardMaterial3D = trim.material_override as StandardMaterial3D
	check(finish!=null and finish.vertex_color_use_as_albedo and finish.roughness>=0.70,
		"premium stone remains physically shaded matte masonry rather than neon")
	trim.queue_free()
	# Load WORLD only after SceneTree autoload initialization, as every original
	# R35/R37 integration test already does; do not eagerly preload GameState.
	var world_script: Variant = load("res://scripts/world_builder.gd")
	check(world_script is Script and world_script.can_instantiate(),
		"real playable city source compiles with stone crown")
	if not (world_script is Script and world_script.can_instantiate()):
		print("EMPIRE OMEGA R45 NATIVE: %d passed, %d failed" % [passed,failed])
		quit(1)
		return
	var world: Node3D = world_script.new()
	root.add_child(world)
	var installed: MultiMeshInstance3D = world.get("architecture_trim")
	check(installed!=null and installed.is_inside_tree(),"live city owns the actual R45 roofline")
	if installed!=null:
		check(installed.multimesh.mesh is ArrayMesh and installed.multimesh.use_colors,
			"real procedural buildings render the actual bevelled one-batch geometry")
		check(installed.multimesh.instance_count==int(world.get("building_count"))*4,
			"every authored building owns four accurate roof edges")
		check(installed.geometry_triangle_budget()<=TRIM.LIMIT*TRIM.TRIANGLES_PER_BEAM,
			"all live roof geometry stays within bounded mobile triangle limit")
		world.apply_visual_budget("low")
		check(not installed.visible,"LOW GPU tier removes high-end roof detail")
		world.apply_visual_budget("cinematic")
		check(installed.visible,"CINEMATIC tier restores true sculpted masonry")
	world.queue_free()
	await process_frame
	print("EMPIRE OMEGA R45 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
