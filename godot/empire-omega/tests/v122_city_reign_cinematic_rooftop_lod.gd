extends SceneTree
## Regression: CITY REIGN premium rooftop model is true Godot geometry.
## In particular it must NOT add a fourth R90 root or extra R91 draw batch.
const URBAN = preload("res://scripts/horizon_r90_street_dressing.gd")
const ROOF = preload("res://scripts/city_reign_rooftop_geometry.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN CINEMATIC ROOFTOP LOD FAIL: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	check(state != null, "unchanged authoritative GameState autoload")
	if state == null:
		quit(1)
		return
	var snapshot: Dictionary = (state.get("data") as Dictionary).duplicate(true)
	var streets: Node3D = URBAN.new()
	root.add_child(streets)
	var art: Node3D = streets.get("r91_architecture") as Node3D
	check(streets.get_child_count() == 3,
		"original R90 has exactly 3 roots; no extra shadow/render traversal")
	check(art != null and art.get_child_count() == 2,
		"original R91 remains TWO physical GPU batches")
	check(bool(streets.call("graphics_are_bounded")),
		"all draw instances remain bounded after scene creation")
	if art != null:
		var crowns: MultiMeshInstance3D = art.get("rooftop_crowns")
		var skyline: MultiMeshInstance3D = streets.get("skyline")
		var original: Array = streets.get("skyline_plan")
		check(crowns != null and skyline != null and original.size() == 72,
			"the 72 authoritative source towers remain unchanged")
		if crowns != null:
			var standard: ArrayMesh = art.get("rooftop_standard_mesh") as ArrayMesh
			var cinematic: ArrayMesh = art.get("rooftop_cinematic_mesh") as ArrayMesh
			check(standard != null and cinematic != null,
				"both original and cinematic real mesh LODs were generated")
			if standard != null and cinematic != null:
				var base_vertices: PackedVector3Array = standard.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
				var premium_arrays: Array = cinematic.surface_get_arrays(0)
				var premium_vertices: PackedVector3Array = premium_arrays[Mesh.ARRAY_VERTEX]
				var premium_normals: PackedVector3Array = premium_arrays[Mesh.ARRAY_NORMAL]
				var premium_colors: PackedColorArray = premium_arrays[Mesh.ARRAY_COLOR]
				check(base_vertices.size() == ROOF.expected_vertex_count(false),
					"standard retains exactly original four 3D box masses")
				check(premium_vertices.size() == ROOF.expected_vertex_count(true) and
					premium_vertices.size() > base_vertices.size() * 3,
					"cinematic has 20 physically modelled rooftop volumes")
				check(premium_normals.size() == premium_vertices.size() and
					premium_colors.size() == premium_vertices.size(),
					"all cinematic faces have physical normals and material tint")
				var finite: bool = true
				var min_y: float = INF
				var max_y: float = -INF
				for i in range(premium_vertices.size()):
					var v: Vector3 = premium_vertices[i]
					var n: Vector3 = premium_normals[i]
					var c: Color = premium_colors[i]
					if not v.is_finite() or not n.is_finite() or absf(n.length() - 1.0) > 0.02 or c.a < 0.99:
						finite = false
						break
					min_y = minf(min_y, v.y)
					max_y = maxf(max_y, v.y)
				check(finite and min_y <= -0.5 and max_y >= 3.1,
					"real roof geometry is finite, correctly shaded and 3D")
				check(crowns.multimesh.mesh == standard,
					"standard starts with original light model")
				var original_resource: MultiMesh = crowns.multimesh
				streets.call("set_quality", "cinematic")
				check(crowns.visible and crowns.multimesh == original_resource and
					crowns.multimesh.mesh == cinematic,
					"cinematic swaps mesh within ORIGINAL single GPU batch")
				check(crowns.multimesh.instance_count == 72 and
					crowns.get_child_count() == 0,
					"no per-building roof nodes, collisions or duplicate instances")
				streets.call("set_quality", "low")
				check(not crowns.visible, "low tier hides cinematic rooftop mesh")
				streets.call("set_quality", "standard")
				check(crowns.visible and crowns.multimesh.mesh == standard,
					"standard restores lightweight mesh with same MultiMesh")
				var material: StandardMaterial3D = crowns.material_override as StandardMaterial3D
				check(material != null and material.vertex_color_use_as_albedo and
					material.metallic > 0.4 and material.roughness > 0.3,
					"real vertex-tinted PBR metal material, not billboard or overlay")
				check(bool(streets.call("graphics_are_bounded")),
					"budgets remain valid after repeated quality changes")
	check(state.get("data") == snapshot,
		"purely visual mesh changes cannot spend money or mutate story state")
	streets.queue_free()
	await process_frame
	print("CITY REIGN cinematic rooftop source acceptance: %d PASS %d FAIL" %
		[passed, failed])
	quit(0 if failed == 0 else 1)
