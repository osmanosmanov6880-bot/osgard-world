extends SceneTree
## CITY REIGN AAA ART A1-A3: actual Godot 4.4.1 geometry and render budgets.
## Explicitly NOT a human visual or photoreal-art approval.
var passed: int = 0
var failed: int = 0

func check(value: bool,why: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN AAA ART FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	if sim == null:
		quit(2)
		return
	var old: Dictionary = sim.data.duplicate(true)
	var lang_before: String = str(sim.locale)
	sim.data = sim.new_game()
	var source_facade: Script = load("res://scripts/city_reign_cinematic_facades.gd") as Script
	var source_squares: Script = load("res://scripts/city_reign_signature_squares.gd") as Script
	check(source_facade != null and source_squares != null,
		"native physical scene scripts import")
	var facade: Node3D = source_facade.new()
	root.add_child(facade)
	var originals: Array = [
		{"center":Vector3(-85.0,22.0,-85.0),"w":14.0,"h":44.0,"district":"forum","face":0},
		{"center":Vector3(85.0,16.0,-85.0),"w":12.0,"h":32.0,"district":"housing","face":1},
		{"center":Vector3(-85.0,12.0,85.0),"w":13.0,"h":24.0,"district":"lower","face":2},
		{"center":Vector3(85.0,20.0,85.0),"w":15.0,"h":40.0,"district":"aqueduct","face":3}
	]
	for row in originals:
		facade.call("record",row["center"],row["w"],row["h"],row["district"],row["face"])
	check(int(facade.get("building_count")) == 4,
		"four different original district facade records accepted")
	facade.call("record",Vector3.INF,14.0,40.0,"forum",0)
	facade.call("record",Vector3(-85.0,10.0,-85.0),500.0,20.0,"forum",0)
	facade.call("record",Vector3(-85.0,10.0,-85.0),14.0,20.0,"invalid",0)
	check(int(facade.get("building_count")) == 4,
		"bad placement and unknown district cannot create geometry")
	facade.call("finalize")
	check(bool(facade.call("graphics_are_bounded")) and facade.get_child_count()==4,
		"only four original GPU instancing batches with zero child nodes")
	check(int(facade.call("instance_count"))==29,
		"four 3D parapets and three facade details per real building plus one rooftop plant")
	var groups: Dictionary = facade.get("groups")
	check((groups["CinematicRoofCornices"] as MultiMeshInstance3D).multimesh.instance_count==16,
		"all four actual original roof edges are 3D")
	check((groups["CinematicEntryBands"] as MultiMeshInstance3D).multimesh.instance_count==4,
		"one realistic canopy header per real building")
	check((groups["CinematicVerticalJambs"] as MultiMeshInstance3D).multimesh.instance_count==8,
		"two real facade reveals per 3D storefront")
	for mode in ["low","standard","cinematic"]:
		facade.call("set_quality",mode)
		var roof: MultiMeshInstance3D = groups["CinematicRoofCornices"]
		var jamb: MultiMeshInstance3D = groups["CinematicVerticalJambs"]
		check(roof.visible == (mode!="low") and jamb.visible == (mode=="cinematic"),
			"three hardware tiers respect source-locked geometry policy: "+mode)
	var entry_finish: StandardMaterial3D = facade.get("accent_finish")
	facade.call("set_quality","cinematic")
	facade.call("update_ambience",12.0,100)
	check(not entry_finish.emission_enabled or entry_finish.emission_energy_multiplier < 0.001,
		"no fictitious midday city power glow")
	facade.call("update_ambience",22.0,100)
	check(entry_finish.emission_enabled and entry_finish.emission_energy_multiplier > 0.3,
		"real evening and live power produce subdued PBR accent")
	facade.call("update_ambience",22.0,0)
	check(not entry_finish.emission_enabled,
		"full city blackout removes ornamental facade electricity")
	var squares: Node3D = source_squares.new()
	root.add_child(squares)
	check(bool(squares.call("graphics_are_bounded")),
		"four actual solid sculpted municipal sites plus 12 shared accent meshes")
	var identities: Dictionary = squares.get("sites")
	check(identities.size()==4 and squares.get_child_count()==5,
		"exactly four original district installations and one night-light batch")
	for site_id in identities:
		var entry: Node3D = identities[site_id]
		var node: MeshInstance3D = entry.get_node("OriginalSculpted_"+site_id) as MeshInstance3D
		check(node.mesh is ArrayMesh and node.mesh.get_surface_count()>0,
			"no photo billboard: independently sculpted physical mesh at "+site_id)
		check(entry.find_children("*","CollisionShape3D",true,false).is_empty(),
			"civic architecture does not block vehicle/sidewalk navigation")
		var at: Vector3 = entry.position
		check(absf(at.x-roundf(at.x/52.0)*52.0)>=8.5 and
			absf(at.z-roundf(at.z/52.0)*52.0)>=8.5,
			"site avoids original 10m road axes in true 3D")
		for language in ["ru","en","zh"]:
			squares.call("sync_language",language)
			var label: Label3D = squares.get("site_labels")[site_id] as Label3D
			check(label.text==str((source_squares.get_script_constant_map()["SITES"] as Dictionary)[site_id][language]),
				"live real-world site label translates in "+language+": "+site_id)
	squares.call("set_quality","low")
	check(not identities["market"].visible and not (squares.get("accent") as MultiMeshInstance3D).visible,
		"phone LOW hardware skips nonessential original sculpture draw calls")
	squares.call("set_quality","cinematic")
	squares.call("sync_ambience",12.0,100)
	var light_finish: StandardMaterial3D = squares.get("accent_finish")
	check(not light_finish.emission_enabled,"original daylight has no artificial electric glow")
	squares.call("sync_ambience",22.0,100)
	check(light_finish.emission_enabled and light_finish.emission_energy_multiplier > 0.3,
		"nighttime accent comes from real game-time and supply")
	squares.call("sync_ambience",22.0,0)
	check(not light_finish.emission_enabled,"city energy zero cuts actual artistic light emission")
	facade.queue_free()
	squares.queue_free()
	await process_frame
	var clean: Dictionary = sim.data.duplicate(true)
	var err: Error = change_scene_to_file("res://scenes/main.tscn")
	check(err==OK,"the actual playable full-city Godot scene loads")
	if err != OK:
		sim.data = old
		sim.locale = lang_before
		quit(1)
		return
	await process_frame
	await physics_frame
	var game: Node3D = current_scene as Node3D
	var world: Node3D = game.get("world") as Node3D
	check(world != null,"real shipped city WorldBuilder exists")
	if world != null:
		var architecture: Node3D = world.get("city_reign_facades") as Node3D
		var plaza: Node3D = world.get("city_reign_squares") as Node3D
		var number: int = int(world.get("building_count"))
		check(number>70 and number<=128,"only original city lots and bounded building counts")
		check(architecture!=null and plaza!=null and bool(architecture.call("graphics_are_bounded")),
			"premium facade kit is actually installed on real 3D city scene")
		check(bool(plaza.call("graphics_are_bounded")) and plaza.is_inside_tree(),
			"four original sculptural sites occupy the actual live game world")
		check(int(architecture.get("building_count"))==number,
			"roof kit exactly follows original physical buildings without duplicate lots")
		var materials: Array = world.get("city_reign_building_finishes")
		check(materials.size()==number,
			"each physical original building receives true PBR albedo / roughness")
		var pack: Script = load("res://scripts/horizon_facade_material_pack.gd") as Script
		check(int(pack.call("cached_styles"))==3 and
			pack.call("allocation_budget_bytes") <= 3*128*128*3*4,
			"all city walls share just three bounded 128px material families")
		if materials.size()>3:
			check(pack.call("textures_reused",materials[0],materials[3]),
				"every fourth building reuses the SAME actual GPU textures")
		world.call("apply_visual_budget","low")
		check(not (architecture.get("groups") as Dictionary)["CinematicRoofCornices"].visible and
			not (plaza.get("sites") as Dictionary)["market"].visible and
			not (materials[0] as StandardMaterial3D).normal_enabled,
			"real full-city mobile tier disables optional geometry and normals")
		world.call("apply_visual_budget","cinematic")
		check((architecture.get("groups") as Dictionary)["CinematicRoofCornices"].visible and
			(plaza.get("sites") as Dictionary)["market"].visible and
			(materials[0] as StandardMaterial3D).normal_enabled,
			"real full-city cinematic tier enables original PBR geometry/normals")
		world.call("update_language","zh")
		check(((plaza.get("site_labels") as Dictionary)["cityhall"] as Label3D).text=="市政广场",
			"actual game language updates the 3D civic place names")
		check((game.get("pedestrians") as Array).size()==34 and
			(game.get("ambient_cars") as Array).size()==12,
			"cinematic art does not replace real citizens and original road traffic")
	check(int(sim.data["mission"])==int(clean["mission"]) and
		int(sim.data["treasury"])==int(clean["treasury"]) and
		int(sim.data["wallet"])==int(clean["wallet"]) and
		sim.data["projects_done"]==clean["projects_done"],
		"rendering never touches city money, progression or owned infrastructure")
	current_scene.queue_free()
	await process_frame
	sim.data = old
	sim.locale = lang_before
	print("CITY REIGN AAA source-native art pass: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
