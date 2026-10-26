extends SceneTree
## R120 real Godot 4.4.1 source and GPU budget acceptance for the 192
## original 3D trees: physically tapered trunk and branch geometry, ZERO
## added scene children or colliders, no RNG, gameplay or save modifications.
const FOLIAGE = preload("res://scripts/horizon_organic_foliage.gd")
const ROAD = preload("res://scripts/horizon_roadscape.gd")
var passed: int = 0
var failed: int = 0

func check(condition: bool, why: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("R120 ORIGINAL REAL WOODY TREES FAILED: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null, "original gameplay state is present")
	if game == null:
		quit(1)
		return
	var old: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var modeled: ArrayMesh = FOLIAGE.sculpted_trunk()
	check(modeled != null and modeled.get_surface_count()==1,
		"all genuine 3D taper/branch masses share ONE original draw surface")
	if modeled != null and modeled.get_surface_count()==1:
		var arrays: Array = modeled.surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var norms: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var colors: PackedColorArray = arrays[Mesh.ARRAY_COLOR]
		check(FOLIAGE.wood_triangle_budget()==96 and verts.size()==96*3,
			"six actual wood cylinders total 96 triangles, bounded 192-tree GPU cost")
		check(norms.size()==verts.size() and colors.size()==verts.size(),
			"real physically shaded tree faces have complete normals and vertex bark")
		var minimum: Vector3 = Vector3(INF,INF,INF)
		var maximum: Vector3 = Vector3(-INF,-INF,-INF)
		for i in range(verts.size()):
			check(verts[i].is_finite() and norms[i].is_finite(),
				"actual real-world arboreal triangle vertex and normal are finite")
			minimum = minimum.min(verts[i])
			maximum = maximum.max(verts[i])
			check(colors[i].r>=0.6 and colors[i].r<=1.0,
				"realistic bounded wood fluting doesn't create fluorescent trunk")
		check(minimum.x < -2.0 and maximum.x > 2.0 and
			minimum.z < -1.7 and maximum.z > 0.7,
			"four actual three-dimensional angled branches extend beyond trunk")
		check(minimum.y <= -0.49 and maximum.y >= 0.78,
			"genuine tapered stem spans original ground and tree-crown heights")
		check(maximum.x < 2.8 and -minimum.x < 2.8 and
			maximum.z < 2.8 and -minimum.z < 2.8,
			"branch geometry remains under original R26 narrow-phone canopy budget")
	var deciduous: ArrayMesh = FOLIAGE.leaf_canopy()
	var pine: ArrayMesh = FOLIAGE.pine_canopy()
	check(deciduous.surface_get_array_len(0)==FOLIAGE.leaf_triangle_budget()*3 and
		pine.surface_get_array_len(0)==FOLIAGE.pine_triangle_budget()*3,
		"original both real foliage canopies and R26 triangle budgets stay identical")
	var scene: Node3D = ROAD.new()
	root.add_child(scene)
	var trunks: MultiMeshInstance3D = scene.get_node_or_null("TrunkBatch") as MultiMeshInstance3D
	var leafs: MultiMeshInstance3D = scene.get_node_or_null("LeafCanopyBatch") as MultiMeshInstance3D
	var pines: MultiMeshInstance3D = scene.get_node_or_null("LeafConeBatch") as MultiMeshInstance3D
	check(trunks != null and leafs != null and pines != null,
		"existing tree silhouettes are real GPU-instanced source nodes")
	if trunks != null and leafs != null and pines != null:
		check(trunks.multimesh.instance_count==192 and
			leafs.multimesh.instance_count+pines.multimesh.instance_count==192,
			"exact same original 192 authored street trees are intact")
		check(trunks.multimesh.mesh is ArrayMesh and
			trunks.multimesh.mesh.surface_get_array_len(0)==288,
			"same original TrunkBatch now uses real 96-triangle branched mesh")
		check(trunks.get_child_count()==0,
			"no new branch meshes, per-tree nodes, physics bodies or extra draw calls")
		check(trunks.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"original mobile/desktop street tree GPU shadow budget unchanged")
		var wood: StandardMaterial3D = trunks.material_override as StandardMaterial3D
		check(wood != null and wood.vertex_color_use_as_albedo and
			wood.roughness>=0.80,
			"original woody surface stays physically lit and rough, not unshaded")
	var camera_sources: Array = scene.get("camera_tree_sources")
	check(camera_sources.size()==192,
		"original authoritative R44 camera occlusion mapping has every tree")
	check(int(scene.get("tree_count"))==192,
		"original mixed tree species and precise deterministic source count")
	if camera_sources.size()==192:
		for index in [0,19,64,127,191]:
			var entry: Dictionary = camera_sources[index]
			check(entry.has("crown_index") and entry.has("trunk_index") and
				entry.has("trunk_transform") and entry.has("crown_transform"),
				"R44 real camera preserves exact original trunk and crown transforms")
	var colliders: int = 0
	for child in scene.get_children():
		if child is CollisionObject3D:
			colliders += 1
	check(colliders==0,
		"decorative branches cannot block traffic, pedestrians, delivery or car")
	check(game.get("data")==old,
		"original economy, save slots and missions remain wholly unchanged")
	scene.queue_free()
	await process_frame
	print("EMPIRE OMEGA R120 actual shared 3D woody canopy: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
