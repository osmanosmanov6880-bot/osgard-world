extends SceneTree
## W53 / Real native input-event regression for the W47 mobile accessibility
## defect: scroll remained at 0 when mission0 was below the phone viewport.
## This intentionally tests actual Godot Control + ScrollContainer objects.
## Chromium W53 CDP touch remains the separately required end-to-end proof.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_w53_native_mobile_swipe.cfg"
var count: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, name: String) -> void:
    count += 1
    if not ok:
        failures.append(name)

func _finger(ui: OSGARDMain, pressed: bool, x: float, y: float, index: int = 2) -> void:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.pressed = pressed
    event.position = Vector2(x, y)
    ui._input(event)

func _drag(ui: OSGARDMain, x: float, y: float, delta_y: float, index: int = 2) -> void:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = Vector2(x, y)
    event.relative = Vector2(0.0, delta_y)
    ui._input(event)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    _check(packed != null, "Actual original Godot scene imports")
    if packed == null:
        _done()
        return
    var ui: OSGARDMain = packed.instantiate() as OSGARDMain
    _check(ui != null, "Actual Godot operator scene runs")
    if ui == null:
        _done()
        return
    ui.core = Core.new(SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame

    ui.size = Vector2(390, 844)
    ui._layout_stage_for_screen()
    ui._refresh()
    await process_frame
    await process_frame

    _check(ui.scroll != null, "Real Godot ScrollContainer exists")
    _check(ui.mission_btns.size() == 6, "All six original mission buttons exist")
    var bar: VScrollBar = ui.scroll.get_v_scroll_bar()
    _check(bar != null, "Real vertical scrollbar exists")
    var mission_y: float = ui.mission_btns[0].get_global_rect().get_center().y
    _check(mission_y > 844.0, "Mission 0 really begins outside phone viewport")
    _check(bar.max_value > bar.page + 200.0, "Native phone content actually scrolls")
    var original_mission: int = int(ui.core.snapshot()["mission"])
    var original_view: int = int(ui.core.snapshot()["view"])
    ui.scroll.scroll_vertical = 0
    _finger(ui, true, 349.0, 610.0)
    _check(int(ui.get("_edge_touch_index")) == 2, "Right-edge finger captured in native input lane")
    for n in range(14):
        _drag(ui, 349.0, 610.0 - float(n + 1) * 26.0, -26.0)
    await process_frame
    _check(ui.scroll.scroll_vertical >= 200, "Real ScrollContainer advances from actual native ScreenDrag deltas")
    _check(int(ui.core.snapshot()["mission"]) == original_mission, "Scrolling never starts a mission")
    _check(int(ui.core.snapshot()["view"]) == original_view, "Scrolling never changes camera")
    _finger(ui, false, 349.0, 246.0)
    _check(int(ui.get("_edge_touch_index")) == -1, "Touch release clears scroll gesture capture")

    ui.scroll.scroll_vertical = 0
    _finger(ui, true, 180.0, 650.0)
    _drag(ui, 180.0, 400.0, -250.0)
    _finger(ui, false, 180.0, 400.0)
    _check(ui.scroll.scroll_vertical == 0, "Center touch is not hijacked from physical knobs/buttons")

    ui.size = Vector2(1366, 768)
    ui._layout_stage_for_screen()
    await process_frame
    ui.scroll.scroll_vertical = 0
    _finger(ui, true, 1280.0, 610.0)
    _drag(ui, 1280.0, 410.0, -200.0)
    _finger(ui, false, 1280.0, 410.0)
    _check(ui.scroll.scroll_vertical == 0, "Desktop scrolling is not changed by phone-only handler")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _done()

func _done() -> void:
    if failures.is_empty():
        print("OSGARD W53 REAL GODOT NATIVE EDGE TOUCH SCROLL PASS: %d checks" % count)
        quit(0)
    else:
        for reason in failures:
            push_error("W53 MOBILE NATIVE SCROLL FAILED: " + reason)
        quit(1)
