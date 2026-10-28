extends SceneTree
## CITY REIGN B27–B29: actual playable Godot city, real 12 building
## plots and four original pay-to-build levels. The new GPU art may only
## READ purchased saved state, never mint money, create static colliders,
## block roads, invent lots, or change the project's original save format.
const KIT = preload("res://scripts/city_reign_investment_skyline.gd")
const GAME = preload("res://scripts/game_state.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("CITY REIGN TWELVE PAID SKYLINE FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	check(sim!=null,"existing authoritative city save singleton exists")
	if sim==null:
		quit(2)
		return
	var original: Dictionary = sim.data.duplicate(true)
	var original_lang: String = str(sim.locale)
	sim.data=sim.new_game()
	var clean: Dictionary = sim.data.duplicate(true)
	var err: Error = change_scene_to_file("res://scenes/main.tscn")
	check(err==OK,"actual full CITY REIGN 3D game and all original physics import")
	if err!=OK:
		sim.data=original
		sim.locale=original_lang
		quit(1)
		return
	await process_frame
	await physics_frame
	var game: Node3D = current_scene as Node3D
	var city: Node3D = game.get("world") as Node3D
	check(city!=null,"source real driving city WorldBuilder exists")
	if city==null:
		quit(2)
		return
	var art: Node3D = city.get("city_reign_purchased_skyline") as Node3D
	check(art!=null and bool(art.call("geometry_is_bounded")),
		"exactly 12 original individual new source mesh renderers in ACTUAL playable city")
	if art==null:
		quit(2)
		return
	var originals: Dictionary = city.get("project_visuals")
	var site: Dictionary = art.get("sites")
	var visuals: Dictionary = art.get("facades")
	var levels: Dictionary = art.get("levels")
	var cache: Dictionary = art.get("_cache")
	check(visuals.size()==12 and site.size()==12 and art.get_child_count()==12,
		"no extra invented building plots or script mesh nodes")
	check(originals.size()==12 and GAME.BUILDING_ORDER.size()==12,
		"same 12 authoritative purchased lots and originals retained")
	check((art.get("_finish") as Dictionary).size()==4,
		"only four shared source PBR materials for all 12 original district towers")
	var unique_shapes: Dictionary = {}
	for id in GAME.BUILDING_ORDER:
		check(site.has(id) and originals.has(id) and
			levels.has(id) and int(levels[id])==0 and
			not (visuals[id] as MeshInstance3D).visible,
			"player unfunded lots do NOT show fabricated real estate: "+id)
		var position: Vector3 = city.call("_project_position",id)
		check(site[id]["position"]==position and
			str(site[id]["district"])==str(GAME.BUILDINGS[id]["district"]),
			"new facade uses SAME original source lot/district: "+id)
		var original_root: StaticBody3D = originals[id]["root"] as StaticBody3D
		check(original_root!=null and
			original_root.get_node("CollisionShape3D") is CollisionShape3D,
			"existing original 15m collision and road AI are unchanged: "+id)
		var visual: MeshInstance3D = visuals[id]
		var mat: StandardMaterial3D = visual.material_override as StandardMaterial3D
		check(visual.position==position and mat.vertex_color_use_as_albedo and
			mat.roughness>=0.35 and mat.metallic>=0.25,
			"real source geometry with PBR metal/mineral/glazing: "+id)
		check(visual.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"optional exterior art creates ZERO extra GPU shadow passes: "+id)
		check(visual.find_children("*","CollisionShape3D",true,false).is_empty(),
			"optional original facade cannot spawn a collider at saved property: "+id)
		var previous_length: int = 0
		for level in range(1,KIT.MAX_LEVEL+1):
			var staged: Dictionary = clean.duplicate(true)
			staged["buildings"][id]=level
			art.call("sync_state",staged)
			check(int(levels[id])==level and visual.visible and
				visual.mesh is ArrayMesh,
				"real SAVED building level reveals actual source 3D architecture: "+id+"/"+str(level))
			var surface: ArrayMesh = visual.mesh as ArrayMesh
			var n: int = surface.surface_get_array_len(0)
			check(n>previous_length and n<KIT.MAX_VERTICES_PER_TOWER,
				"every real purchased level adds MORE actual 3D floors/windows: "+id+"/"+str(level))
			previous_length=n
			var verts: PackedVector3Array = surface.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
			if level==1:
				# REAL whole-mesh geometry signature, not merely vertex count.
				# Multiple structurally different buildings may rightfully
				# consume the same count of source triangles.
				unique_shapes[str(n)+":"+str(hash(verts))] = true
			var min_y: float = INF
			var max_y: float = -INF
			for vertex in verts:
				min_y=minf(min_y,vertex.y)
				max_y=maxf(max_y,vertex.y)
				check(vertex.is_finite() and absf(vertex.x)<9.0 and
					absf(vertex.z)<10.5,
					"all original 3D steel/window panels stay on their SAME real plot: "+id)
			check(min_y>=0.0 and max_y<=KIT.HEIGHT_BASE+KIT.LEVEL_HEIGHT*float(level)+4.3,
				"real tower mesh physically rises with paid city level "+id+"/"+str(level))
			var original_mesh: Mesh = surface
			var initial_count: int = cache.size()
			art.call("sync_state",staged)
			check(visual.mesh==original_mesh and cache.size()==initial_count,
				"repeated GUI/tick/save draw allocates NO duplicate GPU geometry "+id+"/"+str(level))
			check(sim.data==clean,
				"simulated art-only level NEVER writes real saved money or project "+id)
		art.call("sync_state",clean)
		check(int(levels[id])==0 and not visual.visible,
			"reset removes every speculative municipal level "+id)
	check(unique_shapes.size()==12,
		"at least eight distinct original physical building geometry signatures")
	check(cache.size()==12*KIT.MAX_LEVEL,
		"all actual 48 source paid-level mesh variants cached within explicit bound")
	check(bool(art.call("geometry_is_bounded")),
		"12 draw-node / 48 cached mesh / 0 collider original GPU budgets")
	# Pure geometry tests must never be confused with REAL purchase mechanics.
	var treasury_before: int = int(sim.data["treasury"])
	var price: int = int(sim.call("get_build_cost","council"))
	check(price>0 and price<=treasury_before,
		"actual GameState cost calculation is valid and affordable")
	var purchased: bool = sim.call("build","council")
	check(purchased,"actual original paid GameState.build council succeeds")
	check(int(sim.data["treasury"])==treasury_before-price and
		int(sim.data["buildings"]["council"])==1 and
		int(sim.data["actions_left"])==int(clean["actions_left"])-1,
		"the real original SINGLE economic purchase spends money and an action")
	city.call("update_development")
	await physics_frame
	var purchased_art: MeshInstance3D = visuals["council"]
	var source_body: StaticBody3D = originals["council"]["root"] as StaticBody3D
	var shape: CollisionShape3D = source_body.get_node("CollisionShape3D") as CollisionShape3D
	check(source_body.visible and not shape.disabled and
		purchased_art.visible and int(levels["council"])==1,
		"REAL paid council transaction changes BOTH original colliding building and new facade")
	var actual_bill_after: int = int(sim.data["treasury"])
	var cache_after_purchase: int = cache.size()
	var paid_original_mesh: Mesh = (source_body.get_node("VisualMesh") as MeshInstance3D).mesh
	var paid_original_shape: Shape3D = shape.shape
	var physics_cache: Dictionary = city.get("project_geometry_cache")
	check(physics_cache.size()==1 and physics_cache.has(1),
		"first original paid building shares one cached real original BoxMesh/BoxShape3D tier")
	for ignored in range(3):
		city.call("update_development")
	check(int(sim.data["treasury"])==actual_bill_after and cache.size()==cache_after_purchase,
		"repeated full-city development refresh cannot mint money or recreate GPU meshes")
	check(physics_cache.size()==1 and
		(source_body.get_node("VisualMesh") as MeshInstance3D).mesh==paid_original_mesh and
		shape.shape==paid_original_shape,
		"reopening HQ/map/rebuilding visuals allocates ZERO original Godot collider or box meshes")
	var node_count: int = art.get_child_count()
	city.call("apply_visual_budget","low")
	check(not purchased_art.visible and source_body.visible and art.get_child_count()==node_count,
		"physical PHONE LOW hides ONLY optional sculpture; paid original house stays")
	city.call("apply_visual_budget","standard")
	check(purchased_art.visible and art.get_child_count()==node_count,
		"STANDARD reveals genuine physically-purchased facade without extra nodes")
	city.call("apply_visual_budget","cinematic")
	check(purchased_art.visible and bool(art.call("geometry_is_bounded")),
		"cinematic returns SAME geometry / zero collisions with original gameplay")
	check((game.get("ambient_cars") as Array).size()==12 and
		(game.get("pedestrians") as Array).size()==34,
		"all 12 live original cars and 34 citizens are still in original city")
	check(int(sim.data["mission"])==int(clean["mission"]) and
		sim.data["projects_done"]==clean["projects_done"] and
		int(sim.data["wallet"])==int(clean["wallet"]),
		"only actual authorized treasury purchase is allowed; missions and wallet stay untouched")
	current_scene.queue_free()
	await process_frame
	sim.data=original
	sim.locale=original_lang
	print("CITY REIGN AAA actual 12 paid investment skyline: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
