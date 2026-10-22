extends SceneTree
## Genuine Godot GL frame with the real player controlling the actual race car.
func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		push_error("Game scene unavailable")
		quit(2)
		return
	for i in range(80): await process_frame
	var game: Node = current_scene
	var car: CharacterBody3D = game.get("car") as CharacterBody3D
	var player: CharacterBody3D = game.get("player") as CharacterBody3D
	if car == null or player == null:
		push_error("Real car/citizen not loaded")
		quit(2)
		return
	car.global_position = Vector3(-156.0,1.2,-104.0)
	car.rotation.y = -PI*0.5
	player.global_position = car.global_position+Vector3(3,0,0)
	game.set("cam_yaw",car.rotation.y)
	game.set("cam_pitch",0.23)
	game.call("_enter_or_exit_vehicle")
	if not bool(game.get("driving")):
		push_error("Could not enter actual car")
		quit(2)
		return
	var size := Vector2i(1600,900)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = size
	root.size = size
	DisplayServer.window_set_size(size)
	Input.action_press("move_forward")
	for i in range(84): await physics_frame
	Input.action_release("move_forward")
	for i in range(8): await process_frame
	var hud: Node = game.get("hud") as Node
	if hud != null and hud.get("toast_panel") != null:
		(hud.get("toast_panel") as Control).visible = false
	await RenderingServer.frame_post_draw
	var photo: Image = root.get_viewport().get_texture().get_image()
	if photo.is_empty() or photo.get_size()!=size or absf(float(car.get("speed")))<2.5:
		push_error("Real driving scene did not render or vehicle did not move")
		quit(2)
		return
	var target: String = OS.get_environment("GITHUB_WORKSPACE")
	if target == "": target = ProjectSettings.globalize_path("user://")
	else: target += "/screenshots"
	DirAccess.make_dir_recursive_absolute(target)
	var filename: String = target.path_join("omega_horizon_r3_driving_1600x900.png")
	if photo.save_png(filename)!=OK:
		push_error("Screenshot save failed")
		quit(2)
		return
	print("REAL HORIZON DRIVING FRAME: speed=%.2f lateral=%.2f path=%s" % [float(car.get("speed")),float(car.get("lateral_speed")),filename])
	quit(0)
