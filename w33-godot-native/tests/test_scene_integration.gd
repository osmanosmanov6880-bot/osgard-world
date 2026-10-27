extends SceneTree
const Core = preload("res://scripts/OSGARDCore.gd")
const TEST_SAVE = "user://osgard_w32_scene_only_test.cfg"
## Actual scene smoke on Godot, not on Chromium or generated screenshots.
## Execute: godot --headless --path godot --script res://tests/test_scene_integration.gd

func _initialize() -> void:
    call_deferred("_check_scene")

func _fail(error: String) -> void:
    push_error("W32 GODOT 3D/UI FAILED: " + error)
    quit(1)

func _check_scene() -> void:
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    if packed == null:
        _fail("Main.tscn missing")
        return
    var game: OSGARDMain = packed.instantiate() as OSGARDMain
    if game == null:
        _fail("Main.tscn not an actual Godot Control")
        return
    game.core = Core.new(TEST_SAVE)
    game.core.clear_data()
    root.add_child(game)
    await process_frame
    await process_frame
    if game.mission_btns.size() != 6:
        _fail("Six mission buttons not wired")
        return
    if game.view_btns.size() != 3:
        _fail("Three native 3D camera controls not available")
        return
    if game.scene_3d == null or game.scene_3d.rotor == null or game.scene_3d.hatch_hinge == null:
        _fail("Procedural rotor and interlocked hatch geometry missing")
        return
    if game.scene_3d.hero_geometry.size() != 12:
        _fail("HERO extra geometry not generated")
        return
    if game.core.snapshot()["schema"] != "OSGARD_FIELDLAB_R135_W32_SIM":
        _fail("Actual native simulation instance not attached to interface")
        return
    if game.slider_a.focus_mode != Control.FOCUS_ALL or game.slider_b.focus_mode != Control.FOCUS_ALL:
        _fail("Native calibration sliders inaccessible to keyboard")
        return
    game._toggle_quality()
    await process_frame
    if str(game.core.settings["quality"]) != "eco":
        _fail("ECO settings button did not change actual model")
        return
    for detail in game.scene_3d.hero_geometry:
        if (detail as Node3D).visible:
            _fail("ECO must hide decorative source geometry")
            return
    game._toggle_quality()
    game._toggle_language()
    if game.core.settings["locale"] != "en":
        _fail("English UI toggle did not reach underlying core")
        return
    game.core.clear_data()
    print("W32 NATIVE UI/3D PASS: six real buttons, three cameras, rotor, hatch, HERO/ECO, keyboard access, RU/EN")
    game.queue_free()
    quit(0)
