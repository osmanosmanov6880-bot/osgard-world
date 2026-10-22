extends SceneTree
## A genuine Godot render of the original swept-surface car at full resolution.
## Only runs with a GPU-capable Xvfb GL context. No synthetic screenshot tools.
const ART = preload("res://scripts/horizon_vehicle_art.gd")

func _initialize() -> void:
	call_deferred("_render")

func _render() -> void:
	var dimensions := Vector2i(1600,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = dimensions
	root.size = dimensions
	DisplayServer.window_set_size(dimensions)
	var scene := Node3D.new()
	scene.name = "ActualGodotCarShowroom"
	root.add_child(scene)
	var background := WorldEnvironment.new()
	var settings := Environment.new()
	settings.background_mode = Environment.BG_COLOR
	settings.background_color = Color("718a9c")
	settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	settings.ambient_light_color = Color("d7e6f2")
	settings.ambient_light_energy = 1.1
	background.environment = settings
	scene.add_child(background)
	var plane := MeshInstance3D.new()
	plane.name = "ShowroomFloor"
	var floor := PlaneMesh.new()
	floor.size = Vector2(50,50)
	plane.mesh = floor
	plane.position.y = -0.89
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color("667786")
	concrete.metallic = 0.07
	concrete.roughness = 0.75
	plane.material_override = concrete
	scene.add_child(plane)
	var car: Node3D = ART.new()
	scene.add_child(car)
	car.set_paint(Color("e26b2f"))
	var sunlight := DirectionalLight3D.new()
	sunlight.name = "GoldenHourKeyLight"
	sunlight.rotation_degrees = Vector3(-47,25,-24)
	sunlight.light_color = Color("ffe2c3")
	sunlight.light_energy = 1.4
	sunlight.shadow_enabled = true
	scene.add_child(sunlight)
	var sky_fill := DirectionalLight3D.new()
	sky_fill.rotation_degrees = Vector3(-33,-120,12)
	sky_fill.light_color = Color("a4c7f3")
	sky_fill.light_energy = 0.5
	scene.add_child(sky_fill)
	var camera := Camera3D.new()
	camera.name = "ProductCloseupCamera"
	camera.position = Vector3(7.6,3.5,-9.3)
	camera.fov = 42.0
	camera.current = true
	scene.add_child(camera)
	camera.look_at(Vector3(0,-0.02,0.0))
	for i in range(110):
		await process_frame
	await RenderingServer.frame_post_draw
	var screenshot: Image = root.get_viewport().get_texture().get_image()
	if screenshot.is_empty() or screenshot.get_size() != dimensions:
		push_error("Actual Godot sports coupe frame is blank or wrong resolution")
		quit(2)
		return
	var model: MeshInstance3D = car.get_node_or_null("FlowBody") as MeshInstance3D
	if model == null or model.mesh == null or model.mesh.surface_get_array_len(0)<800:
		push_error("Showroom does not contain the approved procedural car mesh")
		quit(2)
		return
	var directory: String = OS.get_environment("GITHUB_WORKSPACE")
	if directory == "":
		directory = ProjectSettings.globalize_path("user://")
	else:
		directory += "/screenshots"
	DirAccess.make_dir_recursive_absolute(directory)
	var target: String = directory.path_join("omega_horizon_r4_sculpted_coupe_1600x900.png")
	if screenshot.save_png(target) != OK:
		push_error("Could not save original Godot showroom render")
		quit(2)
		return
	print("HORIZON R4 SHOWROOM: %d vertices, frame=%s" % [model.mesh.surface_get_array_len(0),target])
	quit(0)
