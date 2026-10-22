extends SceneTree
## Render a real frame from the native Godot renderer for independent visual review.

func _init() -> void:
    call_deferred("_capture")

func _capture() -> void:
    root.size = Vector2i(1600, 900)
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        push_error("Cannot load CHRONOS CITY scene for visual QA")
        quit(1)
        return
    var game: Node3D = packed.instantiate()
    game.save_path = "user://osgard_chronos_capture_isolated.json"
    root.add_child(game)
    for i in range(30):
        await process_frame
    await RenderingServer.frame_post_draw
    var picture: Image = root.get_texture().get_image()
    if picture.is_empty() or picture.get_width() < 800 or picture.get_height() < 450:
        push_error("No high-resolution Godot frame generated")
        quit(1)
        return
    var folder := ProjectSettings.globalize_path("res://screenshots-ci")
    if DirAccess.make_dir_recursive_absolute(folder) != OK:
        push_error("Cannot create screenshot directory")
        quit(1)
        return
    var filename := folder.path_join("time-empire-chronos-city-native.png")
    if picture.save_png(filename) != OK:
        push_error("Cannot save native Godot screenshot")
        quit(1)
        return
    print("VISUAL_QA_SCREENSHOT: ", filename)
    game.queue_free()
    quit(0)