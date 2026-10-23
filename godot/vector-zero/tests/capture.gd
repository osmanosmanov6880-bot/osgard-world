extends SceneTree
## Produce a genuine Godot renderer screenshot for the review gate.
## Requires an actual display/GPU context (e.g. xvfb-run + Mesa in CI).

func _init() -> void:
    call_deferred("_capture")

func _capture() -> void:
    root.size = Vector2i(1600, 900)
    var packed: PackedScene = load("res://scenes/main.tscn")
    if packed == null:
        push_error("Cannot load VECTOR ZERO Godot scene for screenshot")
        quit(1)
        return
    var game: Node3D = packed.instantiate()
    root.add_child(game)
    for i in range(30):
        await process_frame
    await RenderingServer.frame_post_draw
    var picture: Image = root.get_texture().get_image()
    if picture.is_empty() or picture.get_width() < 800 or picture.get_height() < 450:
        push_error("Godot renderer produced no full-resolution screenshot")
        quit(1)
        return
    var folder := ProjectSettings.globalize_path("res://screenshots-ci")
    var dir_error: Error = DirAccess.make_dir_recursive_absolute(folder)
    if dir_error != OK:
        push_error("Cannot create visual QA screenshot folder")
        quit(1)
        return
    var file := folder.path_join("vector-zero-blackfield-native.png")
    var result: Error = picture.save_png(file)
    if result != OK:
        push_error("Godot screenshot PNG save failed")
        quit(1)
        return
    print("VISUAL_QA_SCREENSHOT: ", file, " ", picture.get_width(), "x", picture.get_height())
    # Native portrait viewport verification. Capture must use the real game
    # HUD after its resize callback, not a composited mockup.
    root.size = Vector2i(390, 844)
    for frame in range(18):
        await process_frame
    await RenderingServer.frame_post_draw
    var portrait: Image = root.get_texture().get_image()
    if portrait.is_empty() or portrait.get_width() != 390 or portrait.get_height() != 844:
        push_error("Mobile render resolution mismatch")
        quit(1)
        return
    var mobile_file: String = folder.path_join("vector-zero-blackfield-mobile.png")
    if portrait.save_png(mobile_file) != OK:
        push_error("Godot mobile viewport screenshot save failed")
        quit(1)
        return
    print("VISUAL_QA_MOBILE: ", mobile_file, " 390x844")
    game.queue_free()
    quit(0)