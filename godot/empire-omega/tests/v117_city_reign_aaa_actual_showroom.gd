extends SceneTree
## CITY REIGN A11 acceptance of an ORIGINAL FULL 3D vehicle preview,
## no photo, fake artwork, manipulated save or new physics collisions.
const STUDIO = preload("res://scripts/city_reign_hero_showroom.gd")
const PROFILES = preload("res://scripts/city_reign_player_vehicle_profiles.gd")
const CATALOG = preload("res://scripts/vehicle_catalog.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,reason: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN REAL SHOWROOM FAIL: "+reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	var config: Node = root.get_node_or_null("GameSettings")
	check(state!=null and config!=null,"original GameState and saved local graphics exist")
	if state==null or config==null:
		quit(2)
		return
	var old_data: Dictionary = state.data.duplicate(true)
	var old_lang: String = str(state.locale)
	var old_graphics: String = str(config.get("graphics"))
	var starting: Dictionary = state.data.duplicate(true)
	# Pure low-mode test: not a single new offscreen render or collision.
	var low: VBoxContainer = STUDIO.new()
	root.add_child(low)
	low.call("build","en",false,false,"compact")
	check(low.get("renderer")==null and low.graphics_are_bounded(),
		"low tier never allocates another GPU SubViewport")
	check(low.preview_vehicle("utility") and low.get("renderer")==null,
		"low mode can identify the product but never allocates a 3D preview")
	check(not low.preview_vehicle("unsupported") and
		str(low.get("current_vehicle"))=="utility",
		"invalid asset cannot create source render or alter inspected model")
	low.queue_free()
	await process_frame
	# Genuine lazy native PHONE: zero GPU frame until real interactive press.
	var phone: VBoxContainer = STUDIO.new()
	root.add_child(phone)
	phone.call("build","ru",true,true,"compact")
	check(phone.get("renderer")==null,"320px portrait starts with ZERO extra GPU allocations")
	var open: Button = phone.find_child("CityReignShowroomOpen",true,false) as Button
	check(open!=null and not open.disabled and open.custom_minimum_size.y>=46.0,
		"phone showroom has actual keyboard/touch accessible 3D activation")
	check(phone.preview_vehicle("courier"),
		"player may preview LOCKED real car WITHOUT purchasing it")
	await process_frame
	var viewport: SubViewport = phone.get("renderer") as SubViewport
	check(viewport!=null and phone.graphics_are_bounded(),
		"one exact original 3D scene allocates only after phone interaction")
	if viewport!=null:
		check(viewport.size.x<=STUDIO.MOBILE_SIZE.x and
			viewport.size.y<=STUDIO.MOBILE_SIZE.y,
			"true mobile WebGL GPU surface bounded to 340x184")
		check(viewport.get_world_3d()!=null and
			viewport.render_target_update_mode!=SubViewport.UPDATE_ALWAYS,
			"preview uses real own World3D and demand-driven one-shot GPU rendering")
	var physical: Node3D = phone.get("original_car") as Node3D
	var rack: Node3D = phone.get("spin") as Node3D
	check(physical!=null and rack!=null,
		"preview is the ORIGINAL driveable HORIZON vehicle hierarchy")
	if physical!=null:
		var body: MeshInstance3D = physical.get_node_or_null("FlowBody") as MeshInstance3D
		var roof: MeshInstance3D = physical.get_node_or_null("AerodynamicGreenhouse") as MeshInstance3D
		check(body!=null and body.mesh==PROFILES.body_mesh("courier") and
			roof!=null and roof.mesh==PROFILES.canopy_mesh("courier"),
			"actual 3D courier follows exact SAME physical profile as player garage")
		check(physical.find_children("*","CollisionShape3D",true,false).is_empty(),
			"unbought viewer is visual only, no physics body that could break traffic")
		check((physical.get("wheel_rigs") as Array).size()==4,
			"original real shared 4-wheel sculpt physically forms shown car")
	var first_rotation: float = rack.rotation.y if rack!=null else 0.0
	phone.rotate_model(1)
	check(rack!=null and is_equal_approx(rack.rotation.y,first_rotation+STUDIO.ROTATE_STEP),
		"real 15-degree orbit moves original Godot Node3D, not CSS mock image")
	phone.rotate_model(-1)
	check(rack!=null and is_equal_approx(rack.rotation.y,first_rotation),
		"original turntable rotates reversibly by accessible buttons")
	var first_view: SubViewport = phone.get("renderer") as SubViewport
	for id in CATALOG.ORDER:
		check(phone.preview_vehicle(id) and phone.get("renderer")==first_view,
			"repeated preview of "+id+" does not create a second GPU viewport")
		check(str(physical.get("current_visual_variant"))==id,
			"real showroom source mesh switches to "+id+" original payable garage class")
	check(PROFILES.cache_count()<=PROFILES.MAX_CACHED_NEW_MESHES,
		"all four original variants globally share exactly six cached hero meshes")
	check(state.data==starting,
		"unowned 3D vehicle inspection has absolutely zero wallet/save effects")
	phone.queue_free()
	await process_frame
	# Real full game: UI button press goes to ONE actual original car preview,
	# never to authoritative purchase/ownership or engine driving state.
	state.data=state.new_game()
	config.set("graphics","standard")
	var safe_state: Dictionary = state.data.duplicate(true)
	var error: Error = change_scene_to_file("res://scenes/main.tscn")
	check(error==OK,"original real interactive open-world Godot scene loads")
	if error!=OK:
		state.data=old_data
		state.locale=old_lang
		config.set("graphics",old_graphics)
		quit(1)
		return
	await process_frame
	await physics_frame
	var world: Node3D = current_scene as Node3D
	var hud: CanvasLayer = world.get("hud") as CanvasLayer
	check(hud!=null,"new showroom integrated with ACTUAL source in-game city HUD")
	if hud!=null:
		hud.call("_redraw_strategy")
		await process_frame
		var actual: VBoxContainer = hud.find_child("CityReignSourceCarShowroom",true,false) as VBoxContainer
		var original_grid: GridContainer = hud.find_child("CityReignAAAOriginalGarageGallery",true,false) as GridContainer
		check(actual!=null and original_grid!=null and original_grid.get_child_count()==4,
			"true original four vehicle cards and native 3D showroom coexist")
		if actual!=null:
			check(actual.graphics_are_bounded(),"desktop authentic game allows at most one bounded 3D preview")
			for id in CATALOG.ORDER:
				var show: Button = hud.find_child("CityReignGaragePreview_"+id,true,false) as Button
				check(show!=null and not show.disabled and show.custom_minimum_size.y>=46.0,
					"real 4 car previews remain touch/keyboard enabled even if model not purchased")
				if show!=null:
					show.pressed.emit()
					check(str(actual.get("current_vehicle"))==id,
						"real Godot button inspects "+id+" without buying it")
			check(actual.get("renderer")!=null,
				"actual HUD 3D showroom has genuine Godot source camera and render")
		# A sustained low tier must explicitly drop 3D viewer creation.
		config.set("graphics","low")
		hud.call("_redraw_strategy")
		await process_frame
		var disabled: VBoxContainer = hud.find_child("CityReignSourceCarShowroom",true,false) as VBoxContainer
		check(disabled!=null and disabled.get("renderer")==null,
			"real HUD LOW quality never starts studio preview")
		var low_button: Button = hud.find_child("CityReignGaragePreview_utility",true,false) as Button
		check(low_button!=null and low_button.disabled,
			"real LOW mode visibly disables expensive inspection without breaking purchase")
	check((world.get("ambient_cars") as Array).size()==12 and
		(world.get("pedestrians") as Array).size()==34,
		"actual world streets, real traffic and pedestrian actors still exist")
	check(int(state.data["wallet"])==int(safe_state["wallet"]) and
		int(state.data["treasury"])==int(safe_state["treasury"]) and
		int(state.data["mission"])==int(safe_state["mission"]) and
		state.data["vehicle_owned"]==safe_state["vehicle_owned"],
		"independent preview never purchases an unowned vehicle or advances campaigns")
	current_scene.queue_free()
	await process_frame
	state.data=old_data
	state.locale=old_lang
	config.set("graphics",old_graphics)
	print("CITY REIGN AAA actual authored car showroom: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
