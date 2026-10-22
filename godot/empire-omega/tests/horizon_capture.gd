extends SceneTree
## Captures actual Godot-rendered frames for independent visual acceptance.
## This script must run with xvfb-run + graphics, NOT --headless.
var failed := false

func _initialize() -> void:
	call_deferred("_capture")

func _capture() -> void:
	var file_path: String = "res://scenes/main.tscn"
	var result: Error = change_scene_to_file(file_path)
	if result != OK:
		push_error("Cannot load actual game scene for visual QA")
		quit(2)
		return
	for i in range(90):
		await process_frame
	var destination: String = OS.get_environment("GITHUB_WORKSPACE")
	if destination == "":
		destination = ProjectSettings.globalize_path("user://")
	else:
		destination += "/screenshots"
	DirAccess.make_dir_recursive_absolute(destination)
	for dimensions in [Vector2i(1600,900),Vector2i(1366,768)]:
		DisplayServer.window_set_size(dimensions)
		for tick in range(24):
			await process_frame
		await RenderingServer.frame_post_draw
		var viewport: Viewport = root.get_viewport()
		var photo: Image = viewport.get_texture().get_image()
		if photo.is_empty():
			push_error("Godot viewport image is empty: "+str(dimensions))
			failed = true
			continue
		var total_luma := 0.0
		for row in range(12):
			for col in range(20):
				var pixel: Color = photo.get_pixel(clampi((col*photo.get_width())/20,0,photo.get_width()-1),clampi((row*photo.get_height())/12,0,photo.get_height()-1))
				total_luma += pixel.r*0.2126 + pixel.g*0.7152 + pixel.b*0.0722
		var mean: float = total_luma/240.0
		if mean < 0.055:
			push_error("Rendered game is too dark: "+str(mean))
			failed = true
		var file_name: String = destination.path_join("omega_%dx%d.png" % [dimensions.x,dimensions.y])
		var saved: Error = photo.save_png(file_name)
		if saved != OK:
			push_error("Cannot save Godot screenshot: "+file_name)
			failed = true
		print("HORIZON VISUAL FRAME: %dx%d, avg brightness %.3f, saved %s" % [dimensions.x,dimensions.y,mean,file_name])
	quit(1 if failed else 0)
