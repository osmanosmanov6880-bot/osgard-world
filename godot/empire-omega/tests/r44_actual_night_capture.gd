extends SceneTree
## R44 independent visual evidence: same genuine Godot driving scene in daylight
## and after 22:00. Run under xvfb-run + GL; --headless has no real pixels.
var failed := false

func _initialize() -> void:
	call_deferred("_run")

func _snapshot(world: Node3D, hour: float, target: String, size: Vector2i) -> float:
	# Global autoload names can fail to parse with standalone godot --script.
	var state_node: Node = root.get_node_or_null("GameState")
	if state_node == null:
		push_error("R44 night QA: real GameState autoload missing")
		failed = true
		return -1.0
	var state: Dictionary = state_node.get("data")
	state["day_clock"] = hour
	state_node.set("data",state)
	world.call("apply_visual_budget","cinematic")
	world.call("update_daynight",hour)
	for i in range(24):
		await process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = root.get_viewport().get_texture().get_image()
	if pixels.is_empty() or pixels.get_size()!=size:
		push_error("R44 night QA: real game framebuffer empty or wrong size")
		failed=true
		return -1.0
	var brightness := 0.0
	for y in range(12):
		for x in range(20):
			var c: Color = pixels.get_pixel(clampi((x*pixels.get_width())/20,0,pixels.get_width()-1),clampi((y*pixels.get_height())/12,0,pixels.get_height()-1))
			brightness += c.r*0.2126+c.g*0.7152+c.b*0.0722
	var mean: float = brightness/240.0
	if mean<0.035 or mean>0.92:
		push_error("R44 night QA: 3D framebuffer is black/washed out: "+str(mean))
		failed=true
	if pixels.save_png(target)!=OK:
		push_error("R44 night QA: cannot write actual framebuffer to "+target)
		failed=true
	print("R44 ACTUAL GAME FRAME: hour %.1f mean_luma %.4f path %s" % [hour,mean,target])
	return mean

func _run() -> void:
	if change_scene_to_file("res://scenes/main.tscn") != OK:
		push_error("R44 night QA: actual playable Godot scene failed to load")
		quit(2)
		return
	for i in range(90):
		await process_frame
	var game: Node = current_scene
	var world: Node3D = game.get("world") as Node3D
	var car: CharacterBody3D = game.get("car") as CharacterBody3D
	var player: CharacterBody3D = game.get("player") as CharacterBody3D
	if world==null or car==null or player==null:
		push_error("R44 night QA: real car/citizen/world missing")
		quit(2)
		return
	# A lantern-rich boulevard; no fabricated overlay or external screenshot.
	car.global_position=Vector3(0.0,1.2,8.0)
	car.rotation.y=-PI*0.5
	player.global_position=car.global_position+Vector3(3,0,0)
	game.set("cam_yaw",car.rotation.y)
	game.set("cam_pitch",0.23)
	game.call("_enter_or_exit_vehicle")
	if not bool(game.get("driving")):
		push_error("R44 night QA: cannot enter the real playable car")
		quit(2)
		return
	var size := Vector2i(1366,768)
	root.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size=size
	root.size=size
	DisplayServer.window_set_size(size)
	world.call("update_chunks",Vector3(0,0,8),"cinematic")
	var destination: String = OS.get_environment("GITHUB_WORKSPACE")
	if destination=="":
		destination=ProjectSettings.globalize_path("user://")
	else:
		destination+="/screenshots"
	DirAccess.make_dir_recursive_absolute(destination)
	var day: float = await _snapshot(world,12.0,destination.path_join("omega_r44_real_day_1366x768.png"),size)
	var night: float = await _snapshot(world,22.0,destination.path_join("omega_r44_real_night_1366x768.png"),size)
	var scenic: Node3D = world.get("horizon_scenic") as Node3D
	var active: int = int(scenic.get("active_night_lights")) if scenic!=null else 0
	if active==0:
		push_error("R44 night QA: no real streetlight illuminated in the active live game")
		failed=true
	if day<0.0 or night<0.0 or absf(day-night)<0.005 or night>=day*0.86:
		push_error("R44 night QA: actual nighttime must be visibly darker than real daylight, not identical/overexposed")
		failed=true
	print("R44 AUTHENTIC DAY/NIGHT EVIDENCE: day %.4f night %.4f active_lights %d" % [day,night,active])
	quit(1 if failed else 0)
