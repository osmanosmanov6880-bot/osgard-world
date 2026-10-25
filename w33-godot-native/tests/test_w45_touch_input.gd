extends SceneTree
## Real native GDScript UI integration. Touch is delivered to the actual
## control event handler; production safety interlock remains OSGARDCore.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_w45_native_screen_touch.cfg"
var passed: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_inspect")

func _check(ok: bool, label: String) -> void:
    passed += 1
    if not ok:
        failed.append(label)

func _finger_tap(dial: OSGARDLuxuryDial, value: int) -> void:
    var theta: float = deg_to_rad(135.0 + 270.0 * float(value) / 100.0)
    var event := InputEventScreenTouch.new()
    event.pressed = true
    event.position = dial._knob_center() + Vector2(cos(theta), sin(theta)) * 29.0
    dial._gui_input(event)
    var lift := InputEventScreenTouch.new()
    lift.pressed = false
    lift.position = event.position
    dial._gui_input(lift)

func _inspect() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null, "Native Godot scene imported")
    if scene == null:
        _finish()
        return
    var ui: OSGARDMain = scene.instantiate() as OSGARDMain
    _check(ui != null, "Real native operator controller instantiated")
    if ui == null:
        _finish()
        return
    ui.core = Core.new(SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame
    _check(ui.dial_a != null and ui.dial_b != null, "Both independently controlled physical dials exist")
    _check(not ui.dial_a.active and not ui.dial_b.active, "Both native dials locked at boot")
    _finger_tap(ui.dial_a, 98)
    _check(int(ui.core.snapshot()["puzzle"]["a"]) != 98, "ScreenTouch does not bypass initial safety interlock")
    _check(ui.core.begin_case(0), "Mission started without accessing test-only methods")
    _check(ui.core.toggle_engine(), "Core drive stopped")
    for i in range(14):
        ui.core.tick(0.1)
    _check(ui.core.toggle_hatch(), "Original safety hatch opened")
    for i in range(11):
        ui.core.tick(0.1)
    _check(ui.core.set_view(2), "Correct original inspection view")
    ui._refresh()
    _check(ui.dial_a.active and ui.dial_b.active, "Native real touch only enabled for inspected station")
    _finger_tap(ui.dial_a, 68)
    _finger_tap(ui.dial_b, 44)
    var snap: Dictionary = ui.core.snapshot()
    _check(absf(float(snap["puzzle"]["a"]) - 68.0) <= 2.0, "Finger A goes through original calibration")
    _check(absf(float(snap["puzzle"]["b"]) - 44.0) <= 2.0, "Finger B goes through independent calibration")
    _check(int(ui.slider_a.value) == int(snap["puzzle"]["a"]), "Accessible HSlider A reflects real touch")
    _check(int(ui.slider_b.value) == int(snap["puzzle"]["b"]), "Accessible HSlider B reflects real touch")
    _check(int(snap["errors"]) == 0, "No unsafe bypass or errors during valid calibration")
    _check(ui.scene_3d != null and ui.mission_btns.size() == 6, "All six original missions and 3D chamber retained")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failed.is_empty():
        print("W45 ACTUAL NATIVE GODOT SCREENTOUCH PASS: %d checks" % passed)
        quit(0)
    else:
        for issue in failed:
            push_error("W45 TOUCH FAILED: " + issue)
        quit(1)
