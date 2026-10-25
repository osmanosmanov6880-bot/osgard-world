extends SceneTree
## Native integration acceptance: luxury knob is an actual simulated input,
## never independent real machine control. Keyboard/touch/mouse are not decorative.
const Core = preload("res://scripts/OSGARDCore.gd")
const TEST_SAVE = "user://osgard_w36_dials_test_only.cfg"
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _expect(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures.append(label)

func _tick(game: OSGARDMain, count: int) -> void:
    for i in range(count):
        game.core.tick(0.1)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    _expect(packed != null, "Real Main.tscn exists")
    if packed == null:
        _finish()
        return
    var game: OSGARDMain = packed.instantiate() as OSGARDMain
    _expect(game != null, "Real interface is a Godot Control")
    if game == null:
        _finish()
        return
    game.core = Core.new(TEST_SAVE)
    game.core.clear_data()
    root.add_child(game)
    await process_frame
    await process_frame
    _expect(game.dial_a != null and game.dial_b != null, "Two actual machined control instances")
    if game.dial_a == null or game.dial_b == null:
        game.queue_free()
        _finish()
        return
    _expect(game.dial_a.visual_contract().get("simulation_only") == true, "Dials are not industrial controllers")
    _expect(game.dial_a.channel == "A" and game.dial_b.channel == "B", "Independent virtual channels")
    _expect(not game.dial_a.active and not game.dial_b.active, "Unsafe calibration locked at boot")
    game.dial_a.request_value(99)
    _expect(int(game.core.snapshot()["puzzle"]["a"]) != 99, "No bypass before a selected case")
    _expect(game.core.begin_case(0), "Real virtual mission started")
    _expect(game.core.toggle_engine(), "Drive stopped safely")
    _tick(game, 14)
    _expect(game.core.toggle_hatch(), "Original safety interlock opens hatch after stop")
    _tick(game, 11)
    _expect(game.core.set_view(2), "Correct inspection camera selected")
    game._refresh()
    _expect(game.dial_a.active and game.dial_b.active, "Physical deck enabled only with inspection permission")
    game.dial_a.request_value(68)
    game.dial_b.request_value(44)
    _expect(int(game.core.snapshot()["puzzle"]["a"]) == 68, "Dial A drives actual original simulation value")
    _expect(int(game.core.snapshot()["puzzle"]["b"]) == 44, "Dial B independently drives actual simulation value")
    _expect(int(game.slider_a.value) == 68 and int(game.slider_b.value) == 44, "Accessible keyboard sliders mirror dial values")
    var move := InputEventKey.new()
    move.keycode = KEY_RIGHT
    move.pressed = true
    game.dial_a._gui_input(move)
    _expect(int(game.core.snapshot()["puzzle"]["a"]) == 69, "Real keyboard event turns physical dial")
    game.dial_a.request_value(68)
    _tick(game, 6)
    _expect(game.core.scan(), "Calibrated signal truly accepted by safety-first simulator")
    game._refresh()
    _expect(not game.dial_a.active and not game.dial_b.active, "Dials locked after completed scan stage")
    game.dial_a.request_value(1)
    _expect(int(game.core.snapshot()["puzzle"]["a"]) == 68, "Locked physical dial cannot bypass validated scan")
    var visual: Dictionary = game.dial_a.visual_contract()
    _expect(visual.get("art_direction") == "OSGARD_W36_MACHINED_DIAL", "Unique premium physical control exists")
    _expect(visual.get("independent_safety_bypass") == false, "Visual enhancement retains original safety core")
    _expect(game.mission_btns.size() == 6, "Six preserved actual mission controls")
    game.core.clear_data()
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("OSGARD W36 NATIVE PHYSICAL DIAL PASS: %d real assertions on dual input, keyboard, interlocks and original mission" % assertions)
        quit(0)
    else:
        for message in failures:
            push_error("W36 FAILED: " + message)
        push_error("W36 FAILURE %d of %d" % [failures.size(), assertions])
        quit(1)
