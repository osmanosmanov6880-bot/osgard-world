extends SceneTree
## R6 REAL native screenshot in a visible Godot window, never a concept rendering.
## Windows artifact captures actual Godot PBR scanned assets and original coupe.
const VEHICLE = preload("res://scripts/horizon_vehicle_art.gd")
const PHOTO = preload("res://scripts/horizon_photoreal_r6.gd")

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("R6 physical screenshot requires real renderer; headless capture forbidden")
		quit(2)
		return
	var dimensions := Vector2i(1600,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = dimensions
	root.size = dimensions
	DisplayServer.window_set_size(dimensions)
	var scene := Node3D.new()
	root.add_child(scene)
	var env := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("4c646b")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d8e7ee")
	settings.ambient_light_energy = 1.0
	settings.reflected_light_source = Environment.REFLECTION_SOURCE_BG
	settings.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = settings
	scene.add_child(env)
	var materials := PHOTO.new()
	scene.add_child(materials)
	var asphalt: StandardMaterial3D = materials._surface("asphalt_05",2.0,.65)
	var concrete: StandardMaterial3D = materials._surface("concrete_floor_02",2.1,.42)
	var plaster: StandardMaterial3D = materials._surface("painted_plaster_wall",2.2,.35)
	if asphalt == null or concrete == null or plaster == null:
		push_error("Cannot take R6 photoscan screenshot: real CC0 PBR maps absent")
		quit(2)
		return
	var ground := MeshInstance3D.new()
	ground.name = "REAL_SCANNED_ASPHALT_2K"
	var plane := PlaneMesh.new()
	plane.size = Vector2(90,90)
	ground.mesh = plane
	ground.position.y = -.84
	ground.material_override = asphalt
	scene.add_child(ground)
	for side in [-1,1]:
		var pavement := MeshInstance3D.new()
		pavement.name = "CC0_Curb_Stone"
		var deck := BoxMesh.new()
		deck.size = Vector3(2.2,.21,38.0)
		pavement.mesh = deck
		pavement.position = Vector3(float(side)*12.4,-.73,-13.0)
		pavement.material_override = concrete
		scene.add_child(pavement)
	for pillar in range(6):
		var facade := MeshInstance3D.new()
		facade.name = "CC0_EXTERIOR_PLASTER"
		var cube := BoxMesh.new()
		cube.size = Vector3(2.4,8.0,2.0)
		facade.mesh = cube
		facade.position = Vector3(float(pillar-3)*6.0,3.12,-23.0)
		facade.material_override = plaster
		scene.add_child(facade)
	var car: Node3D = VEHICLE.new()
	scene.add_child(car)
	car.set_paint(Color("dc704b"))
	car.rotate_y(-.25)
	var body: MeshInstance3D = car.get_node_or_null("FlowBody") as MeshInstance3D
	if body != null:
		var finish: StandardMaterial3D = body.material_override as StandardMaterial3D
		if finish != null:
			finish.clearcoat_enabled = true
			finish.clearcoat = .84
			finish.clearcoat_roughness = .10
	var sun := DirectionalLight3D.new()
	sun.light_color = Color("ffe4c4")
	sun.light_energy = 1.60
	sun.rotation_degrees = Vector3(-43,18,-17)
	sun.shadow_enabled = true
	scene.add_child(sun)
	var rim := DirectionalLight3D.new()
	rim.light_color = Color("9cc8f4")
	rim.light_energy = .50
	rim.rotation_degrees = Vector3(-31,-120,0)
	scene.add_child(rim)
	var cam := Camera3D.new()
	cam.position = Vector3(6.6,3.0,-9.5)
	cam.fov = 43
	cam.current = true
	scene.add_child(cam)
	cam.look_at(Vector3(0,-.07,0.1),Vector3.UP)
	for frame in range(85):
		await process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = root.get_viewport().get_texture().get_image()
	if picture.is_empty() or picture.get_size() != dimensions:
		push_error("R6 Godot photo-material frame was empty or wrong dimensions")
		quit(2)
		return
	var folder: String = OS.get_environment("GITHUB_WORKSPACE")
	if folder=="":
		folder = ProjectSettings.globalize_path("user://")
	else:
		folder += "/screenshots"
	DirAccess.make_dir_recursive_absolute(folder)
	var filename: String = folder.path_join("omega_r6_godot_photo_pbr_showroom_1600x900.png")
	if picture.save_png(filename)!=OK:
		push_error("R6 physical Godot screenshot write failure")
		quit(2)
		return
	print("REAL GODOT R6 SCREENSHOT: "+filename)
	print("NOTE: Mesa/Xvfb image is not a physical GPU performance result.")
	quit(0)
