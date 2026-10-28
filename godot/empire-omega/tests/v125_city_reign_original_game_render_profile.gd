extends SceneTree
## CITY REIGN B53: actual original Godot game process and GL Compatibility
## frame captures. Must run with a real Xvfb/OpenGL display, never --headless.
## CI software-Mesa intervals are reproducible diagnostics, NOT promises of
## Windows/Vulkan/Android/iPhone frame rate or human game quality.
const VIEW: Vector2i = Vector2i(1366,768)
const FRAMES_PER_TIER: int = 90
const WARMUP_FRAMES: int = 20
var output: String = ""
var issues: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _samples(samples: Array[float]) -> Dictionary:
	if samples.is_empty():
		return {}
	var sorted: Array[float] = samples.duplicate()
	sorted.sort()
	var sum: float = 0.0
	for d in sorted:
		sum += d
	return {
		"frames":sorted.size(),
		"mean_frame_ms":snappedf(sum/float(sorted.size()),0.01),
		"median_frame_ms":snappedf(sorted[sorted.size()/2],0.01),
		"p95_frame_ms":snappedf(sorted[mini(sorted.size()-1,int(ceilf(float(sorted.size())*0.95))-1)],0.01),
		"worst_frame_ms":snappedf(sorted[-1],0.01),
		"software_ci_only":true
	}

func _frame_luma(image: Image) -> float:
	if image.is_empty():
		return -1.0
	var sum: float = 0.0
	var count: int = 0
	for y in range(12):
		for x in range(24):
			var pixel: Color = image.get_pixel(
				clampi((x*image.get_width())/24,0,image.get_width()-1),
				clampi((y*image.get_height())/12,0,image.get_height()-1))
			sum += 0.2126*pixel.r+0.7152*pixel.g+0.0722*pixel.b
			count += 1
	return sum/float(maxi(count,1))

func _run() -> void:
	output = OS.get_environment("GITHUB_WORKSPACE")
	if output == "":
		output = ProjectSettings.globalize_path("user://")
	else:
		output = output.path_join("city-reign-b53-render-evidence")
	DirAccess.make_dir_recursive_absolute(output)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_DISABLED
	root.content_scale_size = VIEW
	root.size = VIEW
	DisplayServer.window_set_size(VIEW)
	var loading: Error = change_scene_to_file("res://scenes/main.tscn")
	if loading!=OK:
		push_error("Unable to load ORIGINAL playable Godot city main scene")
		quit(2)
		return
	for i in range(85):
		await process_frame
	var game: Node3D = current_scene as Node3D
	if game == null:
		push_error("No original running gameplay node")
		quit(2)
		return
	var world: Node3D = game.get("world") as Node3D
	var car: CharacterBody3D = game.get("car") as CharacterBody3D
	if world == null or car == null:
		push_error("Expected original 3D world and drivable car")
		quit(2)
		return
	var detail: Node3D = world.get("city_reign_street_architecture") as Node3D
	var towers: Array = world.get("city_reign_tower_body_lods")
	if detail==null or towers.is_empty():
		push_error("Actual source city did not mount world edition B41-B52")
		quit(2)
		return
	var results: Dictionary = {
		"candidate":"CITY REIGN source-native B53 measured original playable scene",
		"source_scene":"res://scenes/main.tscn",
		"software_renderer":"CI Mesa/Xvfb GL Compatibility; hardware profile NOT measured",
		"actual_original_buildings":towers.size(),
		"engine":"Godot 4.4.1",
		"viewport":[VIEW.x,VIEW.y],
		"quality":[]
	}
	# The live game owns an adaptive graphics governor. A visual-only
	# WorldBuilder override is NOT a true user-selected mode: the game's
	# existing 1.1s LOD timer would overwrite it with the saved setting.
	# Pin the actual runtime controller *inside this non-shipped QA script*.
	var governor: Object = game.get("adaptive_graphics")
	if governor==null:
		push_error("Missing original live-game graphics governor")
		quit(2)
		return
	for quality in ["low","standard","cinematic"]:
		governor.call("configure",quality,false)
		game.call("_apply_visual_budget")
		world.call("update_chunks",car.global_position,quality)
		for i in range(WARMUP_FRAMES):
			await RenderingServer.frame_post_draw
		var samples: Array[float] = []
		var previous: int = Time.get_ticks_usec()
		for i in range(FRAMES_PER_TIER):
			await RenderingServer.frame_post_draw
			var now: int = Time.get_ticks_usec()
			var delta: float = float(now-previous)/1000.0
			previous = now
			if not is_finite(delta) or delta<=0.0:
				issues.append("Frame interval non-finite in "+quality)
			else:
				samples.append(delta)
		var stats: Dictionary = _samples(samples)
		if samples.size()!=FRAMES_PER_TIER:
			issues.append("Frame count inconsistent for "+quality)
		var image: Image = root.get_viewport().get_texture().get_image()
		var luma: float = _frame_luma(image)
		if image.is_empty() or image.get_size()!=VIEW:
			issues.append("Expected real 1366x768 image for "+quality)
		if luma < 0.025 or luma > 0.97:
			issues.append("Original playable 3D game screenshot too dark/bright: "+quality)
		var screenshot: String = output.path_join(
			"city_reign_original_game_"+quality+"_1366x768.png")
		if image.save_png(screenshot)!=OK:
			issues.append("Original Godot pixel save failed for "+quality)
		stats["graphics_tier"] = quality
		stats["runtime_effective_graphics"] = str(governor.call("effective_quality"))
		if stats["runtime_effective_graphics"] != quality:
			issues.append("Runtime mode drift during native render profile: "+quality)
		stats["frame_brightness"] = snappedf(luma,0.001)
		stats["capture"] = screenshot.get_file()
		stats["actual_source_street_batches"] = detail.get_child_count()
		stats["original_city_tower_instances"] = towers.size()
		stats["camera_tower_lods"] = (world.get("city_reign_tower_lod_counts") as Dictionary).duplicate(true)
		stats["measurement_kind"] = "GL software CI interval, NOT device FPS"
		(results["quality"] as Array).append(stats)
		print("CITY REIGN REAL SOFTWARE GL %s %s" % [quality,JSON.stringify(stats)])
	results["errors"] = issues
	results["real_source_player_car"] = car != null
	var report: String = output.path_join("CITY_REIGN_B53_REAL_FRAMES.json")
	var file: FileAccess = FileAccess.open(report,FileAccess.WRITE)
	if file==null:
		push_error("Cannot write original source frame report")
		quit(2)
		return
	file.store_string(JSON.stringify(results,"  ")+"\n")
	file.close()
	if not issues.is_empty():
		for problem in issues:
			push_error(problem)
	print("CITY REIGN B53 measured REAL ORIGINAL live gameplay, native GL: %d errors" %
		issues.size())
	quit(0 if issues.is_empty() else 1)
