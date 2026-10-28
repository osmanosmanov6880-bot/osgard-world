extends SceneTree
## CITY REIGN AAA A23–A25: REAL native Godot 4.4.1 ORIGINAL city.
## Physical 3D landmark architecture visibly grows with actual purchased
## and completed saved civic works; never grant money or block traffic.
const HERO = preload("res://scripts/city_reign_landmark_architecture.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok:
		passed+=1
	else:
		failed+=1
		push_error("CITY REIGN AAA REAL HERO FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	check(sim!=null,"original authoritative real GameState exists")
	if sim==null:
		quit(2)
		return
	var old: Dictionary = sim.data.duplicate(true)
	var old_lang: String = str(sim.locale)
	sim.data = sim.new_game()
	var clean: Dictionary = sim.data.duplicate(true)
	var sculpture: Node3D = HERO.new()
	root.add_child(sculpture)
	check(sculpture.name=="CityReignPhysicalHeroBuildings" and
		bool(sculpture.call("graphics_are_bounded")),
		"4 different original sculpted city landmarks are exactly 8 real 3D draw nodes")
	check(sculpture.get_child_count()==4 and
		(sculpture.get("site_roots") as Dictionary).size()==4,
		"real FOUR original city service buildings, not an unrelated placeholder")
	var sites: Dictionary = sculpture.get("site_roots")
	var faces: Dictionary = sculpture.get("facades")
	var crowns: Dictionary = sculpture.get("upgrades")
	var materials: Dictionary = sculpture.get("upgrade_materials")
	var geometry_signatures: Dictionary = {}
	for id in HERO.ORDER:
		var spec: Dictionary = HERO.SITE[id]
		var root_piece: Node3D = sites[id]
		var front: MeshInstance3D = faces[id]
		var upgrade: MeshInstance3D = crowns[id]
		check(root_piece.position==spec["position"] and root_piece.get_child_count()==2,
			"art is co-located with REAL original game landmark/collider: "+id)
		check(front.mesh is ArrayMesh and upgrade.mesh is ArrayMesh,
			"physically authored Godot ArrayMeshes, not images: "+id)
		var vcount: int = front.mesh.surface_get_array_len(0)
		var ucount: int = upgrade.mesh.surface_get_array_len(0)
		check(vcount>250 and vcount<=HERO.MAX_VERTEX_COUNT_PER_SITE and ucount==180,
			"bounded unique detailed building vertex budget: "+id)
		geometry_signatures[vcount]=true
		check(not upgrade.visible,
			"unfunded original city has NO fabricated paid upgrades: "+id)
		var art_mat: StandardMaterial3D = front.material_override as StandardMaterial3D
		var accent_mat: StandardMaterial3D = upgrade.material_override as StandardMaterial3D
		check(art_mat.vertex_color_use_as_albedo and
			art_mat.roughness>0.3 and art_mat.metallic>=0.25 and
			accent_mat.metallic>=0.45,
			"genuine source-native PBR materials/metallic architecture: "+id)
		check(front.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and
			upgrade.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,
			"no new per-building render shadow maps or fake light: "+id)
		check(root_piece.find_children("*","CollisionShape3D",true,false).is_empty(),
			"no extra physics collider blocks citizens or original car at "+id)
		var points: PackedVector3Array = front.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
		for point in points:
			check(point.is_finite() and absf(point.x)<16.0 and
				absf(point.z)<16.0 and point.y>=0.0 and point.y<=35.0,
				"finite original 3D masonry/steel lies inside its own true building plot "+id)
	check(geometry_signatures.size()==4,
		"citadel, retail exchange, freight gantry and energy core each have a UNIQUE 3D shape")
	check(sim.data==clean,"building visualization doesn't award credits or auto-buy investments")
	var progressing: Dictionary = clean.duplicate(true)
	progressing["buildings"]["council"]=1
	progressing["buildings"]["homes"]=2
	progressing["buildings"]["factory"]=3
	progressing["projects_done"]=["clean_network","smart_substation"]
	progressing["day_clock"]=22.0
	progressing["energy"]=95
	sculpture.call("sync_state",progressing)
	var expected: Dictionary = {"cityhall":1,"market":2,"depot":3,"power":4}
	for id in HERO.ORDER:
		check(int((sculpture.get("progress_counts") as Dictionary)[id])==int(expected[id]),
			"real actual district-built level/finished projects map to distinct architectural state "+id)
		check((crowns[id] as MeshInstance3D).visible,
			"earned original 3D crowning metalwork physically appears after civic investment "+id)
		var mat: StandardMaterial3D = materials[id]
		check(mat.emission_enabled and mat.emission_energy_multiplier>0.1,
			"real city electricity powers qualified original upgrade illumination at NIGHT "+id)
	sculpture.call("update_ambience",12.0,95)
	for id in HERO.ORDER:
		check(not (materials[id] as StandardMaterial3D).emission_enabled,
			"physical city crown never emits artificial nighttime light in daytime "+id)
	sculpture.call("update_ambience",22.0,0)
	for id in HERO.ORDER:
		check(not (materials[id] as StandardMaterial3D).emission_enabled,
			"REAL POWER BLACKOUT removes ALL district ornamental electric light "+id)
	sculpture.call("update_ambience",22.0,95)
	sculpture.call("set_quality","low")
	for id in HERO.ORDER:
		check(not (faces[id] as MeshInstance3D).visible and
			not (crowns[id] as MeshInstance3D).visible,
			"mobile LOW disables original extra 3D mesh+upgrade draw calls "+id)
	sculpture.call("set_quality","standard")
	for id in HERO.ORDER:
		check((faces[id] as MeshInstance3D).visible and
			(crowns[id] as MeshInstance3D).visible,
			"normal gameplay STANDARD retains original 3D physical upgrade "+id)
	sculpture.call("set_quality","cinematic")
	check(bool(sculpture.call("graphics_are_bounded")),
		"upgrades switch live without creating new geometry or collisions")
	sculpture.call("sync_state",clean)
	for id in HERO.ORDER:
		check(int((sculpture.get("progress_counts") as Dictionary)[id])==0 and
			not (crowns[id] as MeshInstance3D).visible,
			"real original RESET removes every speculative built physical reward "+id)
	check(sim.data==clean,
		"source visuals never write wallet, treasury, saved buildings or civic initiatives")
	sculpture.queue_free()
	await process_frame
	var err: Error = change_scene_to_file("res://scenes/main.tscn")
	check(err==OK,"actual playable 3D CITY REIGN scene still compiles with source art")
	if err!=OK:
		sim.data=old
		sim.locale=old_lang
		quit(1)
		return
	await process_frame
	await physics_frame
	var game: Node3D = current_scene as Node3D
	var world: Node3D = game.get("world") as Node3D
	check(world!=null,"original real WorldBuilder drives city")
	if world!=null:
		var live: Node3D = world.get("city_reign_hero_architecture") as Node3D
		check(live!=null and live.is_inside_tree() and
			bool(live.call("graphics_are_bounded")),
			"4 source-original heroic facades actually placed in TRUE game world")
		var original_root: Node3D = world.get("city_root") as Node3D
		for id in HERO.ORDER:
			var original_body: StaticBody3D = original_root.get_node_or_null(id+"_landmark") as StaticBody3D
			check(original_body!=null and
				(original_body.get_node("CollisionShape3D") as CollisionShape3D).shape is BoxShape3D,
				"new identity does not remove original physical 25-metre city landmark collider "+id)
		check((game.get("ambient_cars") as Array).size()==12 and
			(game.get("pedestrians") as Array).size()==34,
			"genuine driveable city with existing car/people remains alive")
		var real_state: Dictionary = sim.data.duplicate(true)
		var treasury_before: int = int(sim.data["treasury"])
		check(bool(sim.call("build","council")),
			"REAL player investment action can buy and build council source project")
		check(int(sim.data["treasury"])<treasury_before and
			int(sim.data["buildings"]["council"])==1,
			"real single finance transaction funds original building and records level")
		world.call("update_development")
		var original_crown: MeshInstance3D = (live.get("upgrades") as Dictionary)["cityhall"]
		check(original_crown.visible and
			int((live.get("progress_counts") as Dictionary)["cityhall"])==1,
			"ACTUAL paid player building visibly unlocks physical 3D City Hall architecture")
		check(int(sim.data["treasury"])<treasury_before,
			"visual update does NOT refund or fabricate paid city treasury")
		var funds_after: int = int(sim.data["treasury"])
		world.call("update_development")
		check(int(sim.data["treasury"])==funds_after,
			"repeated art/redraw cannot duplicate cost, rewards, civic investment")
		world.call("apply_visual_budget","low")
		check(not (live.get("facades") as Dictionary)["cityhall"].visible,
			"actual game mobile LOW never renders extra 4 hero facades")
		world.call("apply_visual_budget","cinematic")
		check((live.get("facades") as Dictionary)["cityhall"].visible and
			original_crown.visible and bool(live.call("graphics_are_bounded")),
			"actual game CINEMATIC mode restores SAME original 8 cached draw nodes")
	current_scene.queue_free()
	await process_frame
	sim.data=old
	sim.locale=old_lang
	print("CITY REIGN AAA real 4 landmark upgrade architecture: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
