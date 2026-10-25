extends SceneTree
## R108 real original Godot mesh QA: smooth mineral ridge without
## single-face triangle mountains, physics or save mutation.
var passed := 0
var failed := 0

func check(ok: bool, reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R108 ORIGINAL MOUNTAINS FAIL: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null, "original GameState autoload available")
	if game == null:
		quit(1)
		return
	var before: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var world_script: Variant = load("res://scripts/horizon_roadscape.gd")
	check(world_script is Script and world_script.can_instantiate(),
		"actual scenic Godot shader/geometry source compiles")
	if not (world_script is Script and world_script.can_instantiate()):
		quit(1)
		return
	var scenic: Node3D = world_script.new()
	root.add_child(scenic)
	var mountain: MeshInstance3D = scenic.get_node_or_null("SurroundingMountainRange") as MeshInstance3D
	check(mountain != null, "real mountain node is present in the original open city")
	if mountain != null:
		var mesh: ArrayMesh = mountain.mesh as ArrayMesh
		check(mesh != null and mesh.get_surface_count() == 1,
			"one actual indexed native GPU surface, no billboards or screenshot planes")
		if mesh != null and mesh.get_surface_count() == 1:
			var arrays: Array = mesh.surface_get_arrays(0)
			var positions: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var triangles: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
			check(positions.size() == 5*97,
				"five smoothly connected rings with 96 circumferential segments")
			check(triangles.size() == 4*96*6,
				"bounded 768 real triangles across one continuous far horizon")
			var lowest := 999.0
			var highest := -999.0
			var radial_min := 999.0
			var radial_max := 0.0
			for vertex in positions:
				check(vertex.is_finite(),"original rocky vertices have finite coordinates")
				lowest = minf(lowest,vertex.y)
				highest = maxf(highest,vertex.y)
				var radius: float = Vector2(vertex.x,vertex.z).length()
				radial_min = minf(radial_min,radius)
				radial_max = maxf(radial_max,radius)
			check(radial_min >= 339.0 and radial_max <= 536.0,
				"no mountain geometry intersects 460m gameplay world/road boundaries")
			check(lowest >= -26.0 and highest <= 70.0 and highest >= 43.0,
				"mountain peaks form grounded bounded non-spiky distant silhouette")
		var metal: StandardMaterial3D = mountain.material_override as StandardMaterial3D
		check(metal != null and metal.vertex_color_use_as_albedo,
			"real mineral per-vertex PBR material, no green cartoon billboard")
		check(mountain.get_child_count() == 0 and not (mountain is StaticBody3D),
			"cosmetic mountains introduce zero colliders, mission triggers or lights")
		check(mountain.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"far-scene WebGL shadow performance remains bounded")
	check(game.get("data") == before,
		"3D scenery does not touch finances, civic policy, mission state or saves")
	scenic.queue_free()
	await process_frame
	print("EMPIRE OMEGA R108 native mineral mountains: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
