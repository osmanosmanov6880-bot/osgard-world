extends Node
## Captures the REAL playable city from main.tscn, not a hand-built showroom.
## Autoloads are present because capture is via regular Godot game launch.
var game
var capture_folder: String = ""
var count: int = 0

func initialize(root_node) -> void:
	game = root_node
	call_deferred("_capture")

func _capture() -> void:
	if DisplayServer.get_name()=="headless":
		push_error("R7 needs visible Godot renderer; refusing headless screenshot")
		get_tree().quit(2)
		return
	if game == null or game.world == null or game.car == null or game.camera == null:
		push_error("R7 actual playable scene is incomplete")
		get_tree().quit(2)
		return
	var dims := Vector2i(1600,900)
	get_tree().root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	get_tree().root.content_scale_size = dims
	get_tree().root.size = dims
	DisplayServer.window_set_size(dims)
	# Do not mutate the user's configuration file or career. This run is CI-only.
	GameSettings.graphics = "cinematic"
	game._apply_preferences()
	game._apply_weather()
	game.set_physics_process(false)
	game.set_process(false)
	game.car.set_physics_process(false)
	game.car.global_position = Vector3(-132.0,.96,-102.0)
	game.car.rotation.y = -.22
	game.player.visible = false
	for person in game.pedestrians:
		person.visible = false
	for traffic in game.ambient_cars:
		traffic.visible = false
	game.hud.visible = false
	var r7: Node = game.world.get_node_or_null("HorizonArchitectureR7")
	if r7 == null:
		push_error("R7 camera found no actual architecture in playable scene")
		get_tree().quit(2)
		return
	game.world.update_chunks(Vector3(-130.0,0,-130.0),"cinematic")
	game.world.update_daynight(14.0)
	r7.call("set_profile","cinematic")
	var folder: String = OS.get_environment("GITHUB_WORKSPACE")
	if folder=="":
		folder = ProjectSettings.globalize_path("user://")
	else:
		folder += "/screenshots"
	DirAccess.make_dir_recursive_absolute(folder)
	capture_folder = folder
	game.camera.current = true
	game.camera.near = .08
	game.camera.far = 550.0
	# Composition A: car in human-scale city hall avenue.
	await _frame("omega_r7_real_cityhall_driving_1600x900.png",
		Vector3(-115.0,5.1,-86.0),Vector3(-132.0,3.5,-119.0),58.0,72)
	# Composition B: close vehicle foreground with genuine building facade.
	await _frame("omega_r7_real_coupe_urban_1600x900.png",
		Vector3(-123.0,3.0,-91.0),Vector3(-134.0,2.0,-108.0),52.0,56)
	var details: Dictionary = r7.call("diagnostic")
	var r6: Node = game.world.get_node_or_null("HorizonPhotorealR6")
	var metrics := {
		"release":"R7","captured_by":"real Godot main.tscn with actual GameState autoloads",
		"scenes_captured":count,"r7_architecture":details,
		"r6_photoreal":r6.call("diagnostic") if r6 != null else {},
		"adapter":RenderingServer.get_video_adapter_name(),
		"renderer":RenderingServer.get_current_rendering_method(),
		"physical_gpu_benchmark":false,
		"note":"Mesa/Xvfb evidence of actual scene; not a Windows Vulkan high-end GPU measurement"
	}
	var output: String = folder.path_join("omega_r7_real_game_capture.json")
	var file: FileAccess = FileAccess.open(output,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(metrics,"  "))
		file.close()
	print("R7 REAL GAME RENDER DONE: ",JSON.stringify(metrics))
	get_tree().quit(0 if count==2 and file!=null else 1)

func _frame(label: String, position: Vector3, focus: Vector3, fov: float, settle: int) -> void:
	game.camera.global_position = position
	game.camera.look_at(focus,Vector3.UP)
	game.camera.fov = fov
	for i in range(settle):
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var picture: Image = get_viewport().get_texture().get_image()
	if picture.is_empty() or picture.get_size() != Vector2i(1600,900):
		push_error("R7 actual game frame is blank or wrong resolution: "+label)
		return
	var target: String = capture_folder.path_join(label)
	if picture.save_png(target)==OK:
		count += 1
		print("R7 REAL GODOT GAME FRAME: ",target)
	else:
		push_error("Could not save native R7 frame: "+target)
