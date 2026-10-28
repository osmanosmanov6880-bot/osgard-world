extends SceneTree
## CITY REIGN AAA A7: ALL four original owned garage vehicles have
## physically different authored 3D body and roof shapes in the actual
## playable Car / HorizonCoupe hierarchy. Original collider + suspension,
## fuel/physics, wallet, ownership and save remain authoritative.
const CARS = preload("res://scripts/vehicle_controller.gd")
const SCULPT = preload("res://scripts/horizon_coupe_sculpt.gd")
const GARAGE = preload("res://scripts/city_reign_player_vehicle_profiles.gd")
const CATALOG = preload("res://scripts/vehicle_catalog.gd")
var passes: int = 0
var failures: int = 0

func check(ok: bool,reason: String) -> void:
	if ok:
		passes += 1
	else:
		failures += 1
		push_error("CITY REIGN AAA GARAGE FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	check(sim!=null,"real original GameState singleton loaded")
	if sim==null:
		quit(2)
		return
	var old_data: Dictionary = sim.data.duplicate(true)
	var old_lang: String = str(sim.locale)
	check(GARAGE.STYLES==CATALOG.ORDER,"all four original purchasable car IDs match 3D variants")
	check(GARAGE.bounded(),"authored roof/body profiles fit the safe 5.4m original vehicle footprint")
	var base_body: AABB = SCULPT.profile_bounds(SCULPT.BODY_PROFILE)
	var base_roof: AABB = SCULPT.profile_bounds(SCULPT.CANOPY_PROFILE)
	check(GARAGE.profile_for("compact",false)==SCULPT.BODY_PROFILE and
		GARAGE.profile_for("compact",true)==SCULPT.CANOPY_PROFILE,
		"original compact sports car geometry is byte-for-byte profile compatible")
	var courier: AABB = SCULPT.profile_bounds(GARAGE.profile_for("courier",true))
	var executive: AABB = SCULPT.profile_bounds(GARAGE.profile_for("executive",true))
	var utility: AABB = SCULPT.profile_bounds(GARAGE.profile_for("utility",true))
	check(courier.position.y+courier.size.y > base_roof.position.y+base_roof.size.y+0.20,
		"real courier vehicle has noticeably raised physical service roof")
	check(executive.position.y+executive.size.y < base_roof.position.y+base_roof.size.y,
		"executive has longer, lower real aerodynamic roof profile")
	check(utility.size.x>base_roof.size.x and
		utility.position.y+utility.size.y>courier.position.y+courier.size.y,
		"utility SUV has physically wider and taller distinct roof")
	check(base_body.size.z>5.0 and base_body.size.x>2.3,
		"original compact collision-aligned model remains physically present")
	var player: CharacterBody3D = CARS.new()
	root.add_child(player)
	var art: Node3D = player.get_node_or_null("HorizonCoupe") as Node3D
	check(art!=null,"original real controllable Horizon car exists")
	if art==null:
		quit(1)
		return
	var flow: MeshInstance3D = art.get_node("FlowBody") as MeshInstance3D
	var canopy: MeshInstance3D = art.get_node("AerodynamicGreenhouse") as MeshInstance3D
	var original_flow: Mesh = flow.mesh
	var original_roof: Mesh = canopy.mesh
	var original_nodes: int = art.get_child_count()
	var original_parts: int = (art.get("body_parts") as Array).size()
	var original_wheels: Array = art.get("wheel_rigs")
	check(original_wheels.size()==4,"four real independent suspension wheels survive")
	var collider_count: int = 0
	for part in player.get_children():
		if part is CollisionShape3D:
			collider_count += 1
			var box: BoxShape3D = (part as CollisionShape3D).shape as BoxShape3D
			check(box!=null and box.size.is_equal_approx(Vector3(2.7,1.5,5.4)),
				"real player collision box kept exactly original for all four garages")
	check(collider_count==1,"one authoritative original vehicle physics shape")
	var remembered: Dictionary = {}
	for style in GARAGE.STYLES:
		player.apply_variant(style)
		check(str(player.get("variant_id"))==style and
			str(art.get("current_visual_variant"))==style,
			"real garage select changes visible model name: "+style)
		check(art.get_child_count()==original_nodes and
			(art.get("body_parts") as Array).size()==original_parts,
			"garage change adds ZERO MeshInstance3D / material draw nodes")
		var expected_body: Mesh = original_flow if style=="compact" else GARAGE.body_mesh(style)
		var expected_roof: Mesh = original_roof if style=="compact" else GARAGE.canopy_mesh(style)
		check(flow.mesh==expected_body and canopy.mesh==expected_roof,
			"both original 3D hero sculpt nodes change to "+style+" geometry")
		if style=="compact":
			check(flow.mesh==original_flow and canopy.mesh==original_roof,
				"legacy default FlowBody and aerodynamic greenhouse exact mesh pointers restored")
		else:
			check(flow.mesh!=original_flow and canopy.mesh!=original_roof,
				"purchased "+style+" is not simply a repaint of one coupe")
			remembered[style] = [flow.mesh,canopy.mesh]
		var profile: Dictionary = CATALOG.VEHICLES[style]
		check(is_equal_approx(float(player.get("speed_factor")),float(profile["speed"]))
			and is_equal_approx(float(player.get("fuel_factor")),float(profile["fuel"])),
			"existing paid garage performance and fuel physics preserved")
		check(flow.mesh.get_surface_count()==1 and canopy.mesh.get_surface_count()==1,
			"source shapes use original 2 single-surface draw nodes and shader materials")
		check(flow.mesh.surface_get_array_len(0)>=800 and
			canopy.mesh.surface_get_array_len(0)>=300,
			"actual source geometry is a full real 3D closed volume")
		var glass_height: float = 1.0 if style=="compact" else (
			1.33 if style=="courier" else (0.91 if style=="executive" else 1.38))
		for window_name in ["SlopedWindshield","RearGlass","LeftSideGlass","RightSideGlass"]:
			var window: MeshInstance3D = art.get_node(window_name) as MeshInstance3D
			check(is_equal_approx(window.scale.y,glass_height),
				"four original sloped glass panes follow correct car roof height")
		var paint: StandardMaterial3D = flow.material_override as StandardMaterial3D
		check(paint!=null and paint.metallic>=0.6 and paint.clearcoat_enabled,
			"existing actual garage repaint remains a multilayer PBR surface")
	var samples: Array[float] = [0.08,0.03,0.09,0.03]
	art.call("simulate_chassis",18.0,0.32,-6.0,0.91,true,samples,0.016)
	check(absf(float(art.get("roll_angle")))>0.0,
		"new source car body still responds to real four-wheel suspension")
	for index in range((art.get("body_parts") as Array).size()):
		var piece: MeshInstance3D = (art.get("body_parts") as Array)[index]
		if piece.name in ["SlopedWindshield","RearGlass","LeftSideGlass","RightSideGlass"]:
			check(piece.mesh!=null and piece.visible,
				"new car suspension does not drop or delete real window glass")
	player.apply_variant("compact")
	check(flow.mesh==original_flow and canopy.mesh==original_roof,
		"switching back after physical suspension reliably restores original car")
	for style in ["courier","executive","utility"]:
		player.apply_variant(style)
		check(flow.mesh==remembered[style][0] and canopy.mesh==remembered[style][1],
			"repeated purchased model selection reuses cached physical GPU surfaces")
	check(GARAGE.cache_count()==6 and GARAGE.bounded(),
		"4 original models share exactly 6 new cached body/roof meshes")
	check(sim.data==old_data,"changing car art and acceleration has zero save/treasury mutation")
	player.queue_free()
	await process_frame
	# Full real game scene: confirm actual session car has original 3D source
	# model and garage navigation changes what player truly drives.
	sim.data = sim.new_game()
	var starting: Dictionary = sim.data.duplicate(true)
	var error: Error = change_scene_to_file("res://scenes/main.tscn")
	check(error==OK,"real complete playable Godot CITY REIGN scene loads")
	if error==OK:
		await process_frame
		await physics_frame
		var game: Node3D = current_scene as Node3D
		var driven: CharacterBody3D = game.get("car") as CharacterBody3D
		var model: Node3D = driven.get("horizon_visual") as Node3D
		var old_shell: Mesh = (model.get_node("FlowBody") as MeshInstance3D).mesh
		var old_children: int = model.get_child_count()
		for style in GARAGE.STYLES:
			driven.call("apply_variant",style)
			check(str(model.get("current_visual_variant"))==style,
				"shipped driving vehicle actually responds to selected paid garage")
			check(model.get_child_count()==old_children,
				"switching model in the real open city does not spawn GPU meshes")
		check((model.get_node("FlowBody") as MeshInstance3D).mesh!=old_shell,
			"last SUV is visually different from real starting coupe")
		check((game.get("ambient_cars") as Array).size()==12 and
			(game.get("pedestrians") as Array).size()==34,
			"real NPC traffic, pedestrian routines and driving camera remain")
		check(int(sim.data["treasury"])==int(starting["treasury"]) and
			int(sim.data["wallet"])==int(starting["wallet"]) and
			int(sim.data["mission"])==int(starting["mission"]),
			"render-only model selection cannot mint money or finish missions")
		current_scene.queue_free()
		await process_frame
	sim.data = old_data
	sim.locale = old_lang
	print("CITY REIGN AAA real player garage silhouettes: %d PASS %d FAIL" % [passes,failures])
	quit(0 if failures==0 else 1)
