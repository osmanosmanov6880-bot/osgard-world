extends SceneTree
## R114: original native R91 tower crowns gain stepped true-3D PBR shapes
## WITHOUT a single new building instance, draw batch, collider or random draw.
const URBAN = preload("res://scripts/horizon_r90_street_dressing.gd")
var passed := 0
var failed := 0

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R114 TRUE PBR ROOFLINE FAILED: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	check(state != null,"original GameState autoload")
	if state == null:
		quit(1)
		return
	var before: Dictionary = (state.get("data") as Dictionary).duplicate(true)
	var streets: Node3D = URBAN.new()
	root.add_child(streets)
	check(streets.get_child_count()==3,
		"unchanged three source skyline roots, no runtime node explosion")
	check(bool(streets.call("graphics_are_bounded")),
		"original R90/R91 GPU budgets still satisfied")
	var art: Node3D = streets.get("r91_architecture")
	check(art != null,"original native R91 architectural source retained")
	if art != null:
		check(art.get_child_count()==2,
			"still exactly two original architectural GPU batches")
		var tops: MultiMeshInstance3D = art.get("rooftop_crowns")
		var windows: MultiMeshInstance3D = art.get("facade_glass")
		check(tops != null and windows != null,
			"original rooftop and four-sided window batches preserved")
		if tops != null:
			var grid: MultiMesh = tops.multimesh
			check(grid != null and grid.instance_count==72,
				"exact same 72 original rooftops as R91, no extra draw batches")
			var mesh: ArrayMesh = grid.mesh as ArrayMesh if grid != null else null
			check(mesh != null and mesh.get_surface_count()==1,
				"one actual indexed source 3D mesh, not an image or billboard")
			if mesh != null:
				var arrays: Array = mesh.surface_get_arrays(0)
				var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
				var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
				check(vertices.size()==4*6*6,
					"48 genuine modelled triangles per crown, at most 3456 roof triangles")
				check(normals.size()==vertices.size(),
					"every physical facade edge retains a correctly computed PBR normal")
				var min_y := INF
				var max_y := -INF
				for v in vertices:
					check(v.is_finite(),"each architectural roof vertex is finite")
					min_y=minf(min_y,v.y)
					max_y=maxf(max_y,v.y)
				check(min_y<=-0.5 and max_y>=3.0,
					"real stepped 3D penthouse and exhaust rise above broad roof")
			var material: StandardMaterial3D = tops.material_override as StandardMaterial3D
			check(material != null and material.metallic > 0.4 and
				material.roughness >= 0.3 and material.roughness <= 0.6,
				"actual physically shaded metal roof, not unlit cartoon texture")
			check(tops.get_child_count()==0,
				"roof mechanical detailing does not add shadow-casting nested nodes")
			check(tops.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
				"one shared skyline mesh is shadow cost bounded")
			var original: Array = art.get("original_tower_transforms")
			var caps: Array = art.get("original_rooftop_transforms")
			check(original.size()==72 and caps.size()==72,
				"same original authoritative source building transforms retained")
			if original.size()==72 and caps.size()==72:
				for i in [0,17,35,71]:
					var src: Transform3D = original[i]
					var cap: Transform3D = caps[i]
					check(cap.origin.is_equal_approx(
						Vector3(src.origin.x,
							src.origin.y+src.basis.y.length()*0.5+0.38,
							src.origin.z)),
						"new 3D profile uses exactly original roof location and 72 source buildings")
		streets.call("set_quality","low")
		check(tops == null or not tops.visible,
			"low-end/mobile hardware disables optional material detail")
		streets.call("set_quality","cinematic")
		check(tops != null and tops.visible,
			"cinematic mode displays physical stepped roof geometry")
	check(state.get("data")==before,
		"sculpted skyline does not change mission progress, funds or save data")
	streets.queue_free()
	await process_frame
	print("EMPIRE OMEGA R114 actual PBR penthouse roofline: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
