extends SceneTree
## W45 real screenshot editorial regression: no duplicate "01 / 01" and
## selected native camera indicated by Button toggle styling, not missing glyphs.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_w45_camera_editorial.cfg"
var assertions: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_inspect")

func _check(condition: bool, reason: String) -> void:
    assertions += 1
    if not condition:
        errors.append(reason)

func _inspect() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _check(scene != null, "Real Godot scene loaded")
    if scene == null:
        _finish()
        return
    var ui: OSGARDMain = scene.instantiate() as OSGARDMain
    _check(ui != null, "Real native Godot operator Control exists")
    if ui == null:
        _finish()
        return
    ui.core = Core.new(SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame
    _check(ui.view_btns.size() == 3, "Three actual camera Button controls")
    _check(ui.lang_btn.text == "RU" or ui.lang_btn.text == "EN", "Language code has no unsupported glyph")
    for index in range(3):
        var button: Button = ui.view_btns[index]
        _check(button.toggle_mode, "Camera %d is real pressed-state toggle" % index)
        _check(not button.text.contains("  /  0"), "No duplicated camera index %d" % index)
        _check(not button.text.contains("●"), "No font-missing Unicode bullet camera %d" % index)
    ui.core.set_view(2)
    ui._refresh()
    _check(ui.view_btns[2].button_pressed, "Camera 3 selected state visible")
    _check(not ui.view_btns[0].button_pressed, "Camera 1 no longer selected")
    ui.core.set_view(1)
    ui._refresh()
    _check(ui.view_btns[1].button_pressed and not ui.view_btns[2].button_pressed, "Native camera toggles reflect actual view")
    _check(ui.mission_btns.size() == 6, "Six original gameplay missions retained")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("W45 EDITORIAL CAMERA UX PASS: %d real Godot checks" % assertions)
        quit(0)
    else:
        for reason in errors:
            push_error("W45 CAMERA UI FAILED: " + reason)
        quit(1)
