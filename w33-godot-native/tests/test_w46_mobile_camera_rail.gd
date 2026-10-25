extends SceneTree
## W46 actual Godot mobile cockpit: 3 reachable camera actions share
## a single line at 390px and 320px, with bilingual full descriptions
## still visible in the hero HUD and as screen reader tooltips.
const Core = preload("res://scripts/OSGARDCore.gd")
const TEST_SAVE = "user://osgard_w46_camera_rail_native.cfg"
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_inspect")

func _check(valid: bool, msg: String) -> void:
    assertions += 1
    if not valid:
        failures.append(msg)

func _inspect() -> void:
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    _check(packed != null, "Real Godot scene must load")
    if packed == null:
        _done()
        return
    var game: OSGARDMain = packed.instantiate() as OSGARDMain
    _check(game != null, "Real game operator scene must instantiate")
    if game == null:
        _done()
        return
    game.core = Core.new(TEST_SAVE)
    game.core.clear_data()
    root.add_child(game)
    await process_frame
    await process_frame
    for width in [390, 320]:
        game.size = Vector2(width, 844)
        game._layout_stage_for_screen()
        game._refresh()
        await process_frame
        await process_frame
        for i in range(3):
            var button: Button = game.view_btns[i]
            _check(button.text == "%02d" % (i + 1), "Phone camera %d has concise visible index at width %d" % [i, width])
            _check(button.tooltip_text == game._t("view%d" % i), "Phone camera %d retains complete localized tooltip" % i)
            _check(button.custom_minimum_size.x < 99.0, "Phone camera %d has small touch-safe horizontal footprint" % i)
            _check(button.custom_minimum_size.y >= 44.0, "Phone camera %d maintains minimum touch target height" % i)
        var left: Rect2 = game.view_btns[0].get_global_rect()
        var middle: Rect2 = game.view_btns[1].get_global_rect()
        var right: Rect2 = game.view_btns[2].get_global_rect()
        _check(absf(left.position.y - middle.position.y) < 6.0 and absf(middle.position.y - right.position.y) < 6.0,
            "All phone camera buttons stay on one native Godot row at width %d" % width)
        _check(left.position.x < middle.position.x and middle.position.x < right.position.x,
            "Phone camera controls retain LTR user order at width %d" % width)
        _check(right.end.x - left.position.x <= float(width) - 40.0,
            "Phone rail fits the viewport without horizontal clipping at width %d" % width)
    game.core.set_view(2)
    game._refresh()
    _check(game.view_btns[2].button_pressed, "Phone camera 03 selected in true Godot UI")
    _check(game.stage_kicker.text.contains(game._t("view2")), "In-scene kicker identifies selected mobile camera")
    game.core.set_setting("locale", "en")
    game._refresh()
    _check(game.stage_kicker.text.contains(game._t("view2")), "Phone camera description localizes to English")
    game.size = Vector2(1366, 768)
    game._layout_stage_for_screen()
    game._refresh()
    await process_frame
    await process_frame
    _check(game.view_btns[2].text == game._t("view2"), "Desktop restores full camera labels")
    _check(game.view_btns[2].custom_minimum_size.x >= 175.0, "Desktop restores normal luxury controls")
    _check(game.view_btns[2].button_pressed, "Desktop preserves true selected camera")
    _check(game.mission_btns.size() == 6 and game.dial_a != null and game.dial_b != null, "Six cases and both physical calibrators preserved")
    game.core.clear_data()
    game.queue_free()
    await process_frame
    _done()

func _done() -> void:
    if failures.is_empty():
        print("OSGARD W46 NATIVE MOBILE CAMERA RAIL PASS: %d checks" % assertions)
        quit(0)
    else:
        for reason in failures:
            push_error("W46 MOBILE CAMERA RAIL FAILED: " + reason)
        quit(1)
