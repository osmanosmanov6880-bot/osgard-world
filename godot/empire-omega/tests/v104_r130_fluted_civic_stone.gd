extends SceneTree
## R130 true native Godot 4.4.1 test for player-start civic landmark:
## 6 genuinely FLUTED cylindrical shafts + 6 stepped stone capitals,
## existing 7 GPU batches, zero added per-column nodes/physics/saves.
const CIVIC = preload("res://scripts/horizon_civic_gateway.gd")
## Load original WorldBuilder AFTER GameState singleton initialization (Godot strict headless import).
var passed: int = 0
var failed: int = 0

func check(ok: bool, why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("EMPIRE OMEGA R130 PHYSICAL CIVIC STONE FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	check(game != null,"real authoritative game autoload exists")
	if game==null:
		quit(1)
		return
	var before: Dictionary = (game.get("data") as Dictionary).duplicate(true)
	var civic: Node3D = CIVIC.new()
	root.add_child(civic)
	check(civic.get_child_count()==CIVIC.MAX_BATCHES and
		int(civic.get("batches"))==7 and int(civic.get("pieces"))==58,
		"all 58 original world-space architecture parts still use EXACT 7 native GPU batches")
	var pillars: MultiMeshInstance3D = civic.get_node_or_null("CivicStonePillars") as MultiMeshInstance3D
	var capitals: MultiMeshInstance3D = civic.get_node_or_null("CivicCapitals") as MultiMeshInstance3D
	check(pillars != null and capitals != null and
		pillars.multimesh.instance_count==6 and capitals.multimesh.instance_count==6,
		"all original SIX 10.8m entrance columns and SIX capitals remain batched")
	if pillars != null and capitals != null:
		check(pillars.get_child_count()==0 and capitals.get_child_count()==0,
			"no new per-pillar/carved ornament nodes, draw passes or colliders")
		var mesh: ArrayMesh = pillars.multimesh.mesh as ArrayMesh
		var cap: ArrayMesh = capitals.multimesh.mesh as ArrayMesh
		check(mesh!=null and cap!=null and mesh.get_surface_count()==1 and
			cap.get_surface_count()==1,
			"both authentic limestone surfaces are exactly one shared ArrayMesh")
		if mesh != null and cap != null:
			var source: Array = mesh.surface_get_arrays(0)
			var pts: PackedVector3Array = source[Mesh.ARRAY_VERTEX]
			var normals: PackedVector3Array = source[Mesh.ARRAY_NORMAL]
			var colors: PackedColorArray = source[Mesh.ARRAY_COLOR]
			check(CIVIC.R130_SECTORS==48 and CIVIC.R130_FLUTES==12 and
				CIVIC.R130_SHAFT_SEGMENTS==8 and
				CIVIC.R130_COLUMN_TRIANGLES==864,
				"R130 12 physical inset grooves, 48 radial samples, 8 real height stages")
			check(pts.size()==2592 and normals.size()==pts.size() and
				colors.size()==pts.size(),
				"exact 864 native triangles per column have real 3D normals and original stone colors")
			var min_v: Vector3 = Vector3(INF,INF,INF)
			var max_v: Vector3 = Vector3(-INF,-INF,-INF)
			var groove_min: float = INF
			var groove_max: float = -INF
			for i in range(pts.size()):
				check(pts[i].is_finite() and normals[i].is_finite(),
					"every original actual fluted limestone surface triangle has finite 3D position/normal")
				min_v = min_v.min(pts[i])
				max_v = max_v.max(pts[i])
				if is_equal_approx(pts[i].y,-0.18):
					var radius: float = Vector2(pts[i].x,pts[i].z).length()
					groove_min = minf(groove_min,radius)
					groove_max = maxf(groove_max,radius)
			check(groove_max-groove_min > 0.020 and
				groove_max-groove_min < 0.060,
				"actual front-facing flutes create 2-6cm physical stone grooves, not fake bump paint")
			check(min_v.y <= -0.499 and max_v.y >= 0.499 and
				min_v.x < -0.45 and max_v.x > 0.45,
				"authentic column retains original local unit-height footprint and realistic taper")
			check(normals[0].x > 0.50,
				"first actual 3D shaft face normal points OUTWARD to Godot sunlight")
			var cap_arrays: Array = cap.surface_get_arrays(0)
			var cap_points: PackedVector3Array = cap_arrays[Mesh.ARRAY_VERTEX]
			var cap_normals: PackedVector3Array = cap_arrays[Mesh.ARRAY_NORMAL]
			var cap_colors: PackedColorArray = cap_arrays[Mesh.ARRAY_COLOR]
			check(cap_points.size()==CIVIC.R130_CAPITAL_TRIANGLES*3 and
				cap_points.size()==144 and cap_normals.size()==144 and
				cap_colors.size()==144,
				"four actual stacked stepped stone masses form ONE 48-triangle source capital")
			var tint_values: Dictionary = {}
			for tint in cap_colors:
				tint_values[str(tint)] = true
			check(tint_values.size()==4,
				"each real 3D capital moulding course has a distinct quiet mineral color")
			var cap_bounds: AABB = cap.get_aabb()
			check(cap_bounds.size.x > 0.99 and
				cap_bounds.size.y >= 0.99 and
				cap_bounds.size.z > 0.99,
				"real capital is full 3D sculpted architectural object, no screen-oriented quad")
		var stone: StandardMaterial3D = pillars.material_override as StandardMaterial3D
		check(stone != null and stone.normal_enabled and
			stone.normal_texture!=null and stone.uv1_world_triplanar and
			stone.shading_mode!=BaseMaterial3D.SHADING_MODE_UNSHADED,
			"new sculpted limestone uses existing real PBR stone normal/roughness under sun")
		check(pillars.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"12 architectural stone pieces introduce zero extra mobile shadow-caster passes")
		for i in range(6):
			var origin: Vector3 = pillars.multimesh.get_instance_transform(i).origin
			var capital_origin: Vector3 = capitals.multimesh.get_instance_transform(i).origin
			if i == 0:
				print("R130 SOURCE POSES first pillar=",origin,
					" capital=",capital_origin," expected pillars=(-10,5.40,14) capitals=(-10,10.93,14)")
			check(origin.is_equal_approx(Vector3(-10.0+float(i)*4.0,5.40,14.0)) and
				capital_origin.is_equal_approx(Vector3(-10.0+float(i)*4.0,10.93,14.0)),
				"original landmark pillars/capitals keep exact authored physical locations")
	# WorldBuilder references genuine GameState autoload during compilation:
	# a preloaded static constant races that binding in Godot headless --script.
	var world_source: Variant = load("res://scripts/world_builder.gd")
	check(world_source is Script and world_source.can_instantiate(),
		"original actual city world script must load after live GameState autoload")
	if not (world_source is Script and world_source.can_instantiate()):
		civic.queue_free()
		await process_frame
		quit(1)
		return
	var world: Node3D = world_source.new()
	root.add_child(world)
	var live: Node3D = world.get("cityhall_gateway") as Node3D
	check(live != null and live.is_inside_tree() and
		live.position==Vector3(-130.0,0.0,-130.0),
		"authoritative original live WorldBuilder still spawns real portico at correct site")
	var landmark: StaticBody3D = world.get_node_or_null("ProceduralDistricts/cityhall_landmark") as StaticBody3D
	check(landmark != null and
		landmark.get_node_or_null("CollisionShape3D") is CollisionShape3D,
		"unchanged actual 25m cityhall collision remains the ONLY original physics authority")
	world.call("apply_visual_budget","low")
	check(live != null and not live.visible,
		"original GPU-constrained mobile LOW hides 7 source portico batches")
	world.call("apply_visual_budget","cinematic")
	check(live != null and live.visible,
		"original CINEMATIC displays genuine sculpted stone and existing civic window/glass")
	check(game.get("data")==before,
		"new architectural sculpting cannot mutate missions, money, driving or save slots")
	world.queue_free()
	civic.queue_free()
	await process_frame
	print("EMPIRE OMEGA R130 original sculpted limestone civic: %d PASS %d FAIL" %
		[passed,failed])
	quit(0 if failed==0 else 1)
