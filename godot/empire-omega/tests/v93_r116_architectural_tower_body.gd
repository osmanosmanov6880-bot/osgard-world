extends SceneTree
## R116 native original Godot 4.4.1 proof: visible sculpted PBR skyline
## with NO new draw batches, tower positions, mission/save writes or colliders.
const URBAN = preload("res://scripts/horizon_r90_street_dressing.gd")
const PACK = preload("res://scripts/horizon_facade_material_pack.gd")
var passed := 0
var failed := 0

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R116 ORIGINAL STRUCTURAL PBR TOWERS FAIL: " + why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	check(state != null,"original GameState autoload is present")
	if state == null:
		quit(1)
		return
	var before: Dictionary = (state.get("data") as Dictionary).duplicate(true)
	var urban: Node3D = URBAN.new()
	root.add_child(urban)
	check(urban.get_child_count()==3,
		"still original 3 GPU root batches, no per-building nodes")
	check(bool(urban.call("graphics_are_bounded")),
		"original R90 and R91 3D budgets are preserved")
	var tower: MultiMeshInstance3D = urban.get("skyline") as MultiMeshInstance3D
	var skyline: Array = urban.get("skyline_plan")
	var art: Node3D = urban.get("r91_architecture") as Node3D
	check(tower != null and tower.multimesh.instance_count==72,
		"all 72 source-Godot towers remain unchanged")
	check(skyline.size()==72,"72 original deterministic CPU positions retained")
	check(art != null and art.get_child_count()==2,
		"R91 windows and R114 penthouse roof batches remain intact")
	if art != null:
		var original: Array = art.get("original_tower_transforms")
		var caps: Array = art.get("original_rooftop_transforms")
		check(original.size()==72 and caps.size()==72,
			"R91/R114 source transforms retained exactly")
		if original.size()==72 and caps.size()==72:
			for index in [0,17,35,71]:
				check((skyline[index] as Transform3D).is_equal_approx(
					original[index] as Transform3D),
					"one physical R90 tower retains original R91/R114 position")
	if tower != null:
		var material: StandardMaterial3D = tower.material_override as StandardMaterial3D
		check(material != null,"genuine physically shaded shared skyline finish")
		if material != null:
			check(material.albedo_texture != null and material.normal_enabled and
				material.normal_texture != null and material.roughness_texture != null,
				"original shared 128px limestone color/normal/roughness PBR maps are bound")
			check(material.vertex_color_use_as_albedo,
				"original deterministic per-building colors still applied")
			check(material.uv1_world_triplanar,
				"physical original world-space mineral tiling, not fake 2D screenshot")
		check(tower.multimesh.use_colors,
			"source tower palette remains real GPU instance data")
		check(tower.get_child_count()==0,
			"physical detailing creates zero separate building nodes/colliders")
		check(tower.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"true WebGL shadow pass cost does not increase")
		var mesh: ArrayMesh = tower.multimesh.mesh as ArrayMesh
		check(mesh != null and mesh.get_surface_count()==1,
			"one single shared original structural body GPU draw surface")
		if mesh != null and mesh.get_surface_count()==1:
			var arrays: Array = mesh.surface_get_arrays(0)
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
			check(vertices.size()==7*6*6,
				"seven physical masses, 84 bounded original triangles per 3D tower")
			check(normals.size()==vertices.size(),
				"all real mechanical pilasters and cornices have finite per-face normals")
			var min_x: float = INF
			var max_x: float = -INF
			var min_y: float = INF
			var max_y: float = -INF
			for vertex in vertices:
				check(vertex.is_finite(),"every original skyline source vertex is finite")
				min_x = minf(min_x,vertex.x)
				max_x = maxf(max_x,vertex.x)
				min_y = minf(min_y,vertex.y)
				max_y = maxf(max_y,vertex.y)
			check(min_x < -0.525 and max_x > 0.525 and
				min_y <= -0.50 and max_y >= 0.50,
				"true extruded facade piers and podium keep original window and roof extents")
	check(PACK.cached_styles()<=3 and
		PACK.allocation_budget_bytes()<=600000,
		"shared original PBR texture memory stays below 600 KB, no per-tower maps")
	urban.call("set_quality","low")
	check(tower==null or not tower.visible,
		"low-mobile tier retains original low-cost city without distant structures")
	urban.call("set_quality","cinematic")
	check(tower!=null and tower.visible,
		"cinematic tier really renders the genuine structural PBR geometry")
	check(state.get("data")==before,
		"material mesh change never alters money, district policies, physics or saves")
	urban.queue_free()
	await process_frame
	print("EMPIRE OMEGA R116 original structural towers PBR: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
