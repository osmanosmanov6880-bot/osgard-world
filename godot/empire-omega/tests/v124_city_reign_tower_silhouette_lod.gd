extends SceneTree
## CITY REIGN B49-B52 - REAL district-architectural surface upgrade.
## This test inspects real native ArrayMesh triangles and live WorldBuilder
## MeshInstance resources. It does not infer success from source file text.
const BODY = preload("res://scripts/city_reign_tower_body_lod.gd")
var passed: int = 0
var failed: int = 0

func verify(value: bool,why: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN B49 DISTRICT SILHOUETTE FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	verify(state!=null,"native original authoritative GameState autoload initialized")
	if state==null:
		quit(2)
		return
	var original: Dictionary = (state.get("data") as Dictionary).duplicate(true)
	var samples: Array[Dictionary] = [
		{"district":"forum","w":14.0,"h":74.0,"index":0},
		{"district":"housing","w":13.0,"h":32.0,"index":1},
		{"district":"lower","w":12.0,"h":19.0,"index":2},
		{"district":"aqueduct","w":15.0,"h":47.0,"index":3}
	]
	var vertex_signatures: Dictionary = {}
	for lot in samples:
		var spec: Dictionary = lot
		var width: float = float(spec["w"])
		var height: float = float(spec["h"])
		var district: String = str(spec["district"])
		var i: int = int(spec["index"])
		var standard: ArrayMesh = BODY.make_mesh(width,height,district,i,false)
		var cinematic: ArrayMesh = BODY.make_mesh(width,height,district,i,true)
		verify(bool(BODY.valid_mesh(standard,width,height,false)),
			"all faces have finite true vertex normals, colors and bounded 3D footprint: "+district)
		verify(bool(BODY.valid_mesh(cinematic,width,height,true)),
			"cinematic source authored true physical surfaces and roof depth: "+district)
		var n_standard: int = int(BODY.vertices_for(standard))
		var n_cinematic: int = int(BODY.vertices_for(cinematic))
		verify(n_standard>96 and n_standard<=BODY.MAX_VERTICES_PER_STANDARD,
			"closed 8-sided standard tower has bounded true elevation relief: "+district)
		verify(n_cinematic>n_standard+125 and n_cinematic<=BODY.MAX_VERTICES_PER_CINEMATIC,
			"cinematic district adds stone vertical piers, actual story lines and roof: "+district)
		var vertices: PackedVector3Array = cinematic.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		var min_height: float = INF
		var max_height: float = -INF
		var physical_outset: bool = false
		for v in vertices:
			min_height = minf(min_height,v.y)
			max_height = maxf(max_height,v.y)
			if absf(v.x) > width*0.5+0.04 or absf(v.z) > width*0.5+0.04:
				physical_outset = true
		verify(absf(min_height+height*0.5)<0.01 and
			max_height > height*0.5+0.4 and physical_outset,
			"actual upper mechanical/architecture silhouette has 3D extents: "+district)
		vertex_signatures[n_cinematic]=true
	verify(vertex_signatures.size()>=3,
		"four district architectural models have different native mesh complexity")
	# Avoid premature loading WorldBuilder: its GameState autoload is registered
	# by the native SceneTree, not by top-level script preloading.
	var script_source: Variant = load("res://scripts/world_builder.gd")
	verify(script_source is Script and script_source.can_instantiate(),
		"real original WorldBuilder imports and can be instantiated")
	if not (script_source is Script and script_source.can_instantiate()):
		quit(1)
		return
	var world: Node3D = script_source.new()
	root.add_child(world)
	var count: int = int(world.get("building_count"))
	var lods: Array = world.get("city_reign_tower_body_lods")
	verify(count>70 and count<=BODY.MAX_BUILDINGS and lods.size()==count,
		"one mesh-LOD record per ORIGINAL real building, no extra city plots")
	var scene_nodes: Array[Node] = []
	var collider_shapes: Array[Shape3D] = []
	var checked: int = 0
	var vertex_sum: int = 0
	for entry in lods:
		var item: Dictionary = entry
		var visual: MeshInstance3D = item["visual"]
		var physical: StaticBody3D = item["physical_body"]
		var original_mesh: Mesh = item["original_mesh"]
		var standard: Mesh = item["standard"]
		var cinematic: Mesh = item["cinematic"]
		var w: float = float(item["width"])
		var h: float = float(item["height"])
		var collider: CollisionShape3D = physical.get_node_or_null("CollisionShape3D") as CollisionShape3D
		verify(visual!=null and original_mesh is BoxMesh and
			standard is ArrayMesh and cinematic is ArrayMesh,
			"source-only detail upgrades ORIGINAL body MeshInstance: "+str(checked))
		verify(visual.get_parent()==physical and physical.get_child_count()==2 and
			collider!=null and collider.shape is BoxShape3D,
			"original physics tower retains same two children and one BoxShape3D")
		verify(visual.mesh==standard and
			(collider.shape as BoxShape3D).size.is_equal_approx(Vector3(w,h,w)),
			"original real STANDARD mesh and width/height collision alignment")
		verify(bool(BODY.valid_mesh(standard,w,h,false)) and
			bool(BODY.valid_mesh(cinematic,w,h,true)),
			"every world building contains native valid geometry, without leakage")
		var mat: StandardMaterial3D = visual.material_override as StandardMaterial3D
		verify(mat!=null and mat.albedo_texture!=null and mat.roughness_texture!=null and
			mat.vertex_color_use_as_albedo and mat.uv1_triplanar,
			"3 existing shared PBR city families remain authoritatively bound")
		scene_nodes.append(visual)
		collider_shapes.append(collider.shape)
		vertex_sum += int(BODY.vertices_for(cinematic))
		checked += 1
	verify(checked==count and vertex_sum<=count*BODY.MAX_VERTICES_PER_CINEMATIC,
		"all native cinematic geometry bounded in memory and count")
	world.call("apply_visual_budget","low")
	for i in range(lods.size()):
		var entry: Dictionary = lods[i]
		verify((entry["visual"] as MeshInstance3D).mesh==entry["original_mesh"],
			"LOW preserves authentic original lightweight box body")
	world.call("apply_visual_budget","standard")
	for i in range(lods.size()):
		var entry: Dictionary = lods[i]
		verify((entry["visual"] as MeshInstance3D).mesh==entry["standard"],
			"STANDARD restores physical chamfered architecture")
	world.call("apply_visual_budget","cinematic")
	for i in range(lods.size()):
		var entry: Dictionary = lods[i]
		verify((entry["visual"] as MeshInstance3D).mesh==entry["cinematic"],
			"CINEMATIC adds shape detail WITHOUT new buildings/objects")
	world.call("update_weather","storm")
	world.call("update_daynight",22.0)
	world.call("apply_visual_budget","low")
	world.call("apply_visual_budget","cinematic")
	for i in range(lods.size()):
		var entry: Dictionary = lods[i]
		var visual: MeshInstance3D = entry["visual"]
		var physical: StaticBody3D = entry["physical_body"]
		verify(visual==scene_nodes[i] and
			(physical.get_node("CollisionShape3D") as CollisionShape3D).shape==collider_shapes[i] and
			visual.mesh==entry["cinematic"],
			"lighting/weather/LOD cannot allocate, replace or move ORIGINAL collider")
	verify(state.get("data")==original,
		"cosmetic geometry never mutates original city money, buildings or mission")
	world.queue_free()
	await process_frame
	print("CITY REIGN WORLD B49-B52 TRUE NATIVE DISTRICT ARCHITECTURE: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
