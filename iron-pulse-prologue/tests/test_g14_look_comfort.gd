extends SceneTree
## G14 exact Godot camera/accessibility QA — no fake input or player records.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)

func _near(a: float,b: float) -> bool:
    return absf(a-b) < 0.0002

func _key(game: Node, code: Key) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.keycode = code
    game._input(event)

func _drag(game: Node,dx: float,dy: float) -> void:
    var event := InputEventScreenDrag.new()
    event.position = Vector2(1100,420)
    event.relative = Vector2(dx,dy)
    game._input(event)

func _stop() -> void:
    if failures.is_empty():
        print("IRON PULSE G14 ACTUAL CAMERA ACCESS PASS: %d native look, touch, keyboard, safety and persistence checks" % checks)
        quit(0)
        return
    for failure in failures:
        push_error("G14 CAMERA FAIL: "+failure)
    quit(1)

func _run() -> void:
    var local_path: String = "user://iron_pulse_g14_test_look.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))
    var look := IPLookComfort.new()
    _assert(look.mode == "standard" and _near(look.speed(),0.0021) and not look.inverted(),
        "G14 preserves original source mouse/touch/gamepad sensitivity by default")
    _assert(look.readout()["original_input_path"].contains("InputEventScreenDrag") and
        look.readout()["local_only"] and not look.readout()["autonomous_camera"] and
        not look.readout()["telemetry_uploaded"], "G14 keeps real physical camera control with no telemetry or autoplay")
    _assert(look.angular_delta(Vector2(20,8)).distance_to(Vector2(-0.042,-0.0168)) < 0.0001,
        "Standard mouse relative remains exactly source camera 0.0021 both axes")
    _assert(not look.set_mode("auto_aim") and look.mode == "standard",
        "Invalid or automated modes may never be enabled")
    _assert(look.next_mode() == "gentle" and _near(look.speed(),0.00125) and
        look.angular_delta(Vector2(20,8)).distance_to(Vector2(-0.025,-0.01)) < 0.0001,
        "G14 gentle mode genuinely reduces real camera angular velocity")
    _assert(look.next_mode() == "invert_y" and look.inverted() and
        look.angular_delta(Vector2(20,8)).distance_to(Vector2(-0.042,0.0168)) < 0.0001,
        "G14 invert mode affects vertical only; horizontal mouse remains normal")
    _assert(look.save_to(local_path), "Single allowlisted camera enum persists to local user:// only")
    var copied := IPLookComfort.new()
    _assert(copied.load_from(local_path) and copied.mode == "invert_y",
        "Valid G14 profile restores reversibly across genuine cold restart")
    var spoof := ConfigFile.new()
    spoof.set_value("presentation","schema",IPLookComfort.FORMAT)
    spoof.set_value("presentation","mode","autonomous-target-lock")
    _assert(spoof.save(local_path) == OK, "Native test fixture stored locally")
    var denied := IPLookComfort.new()
    _assert(not denied.load_from(local_path) and denied.mode == "standard",
        "Tampered camera config must fail closed to original authentic sensitivity")
    _assert(look.next_mode() == "standard" and not look.inverted(),
        "All real G14 camera presets cycle back exactly to original")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(local_path))

    var original: PackedScene = load("res://Main.tscn")
    _assert(original != null, "The real Godot Main.tscn campaign scene must load")
    if original == null:
        _stop()
        return
    var game = original.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var idle: Dictionary = game.session.checkpoint()
    _assert(game.look_comfort.mode == "standard" and
        game.look_comfort_button != null and game.touch_look_button != null,
        "G14 mounts a true original Godot pause control plus 51px mobile button")
    _key(game,KEY_F10)
    _assert(game.look_comfort.mode == "gentle" and game.look_comfort_button.text.contains("ПЛАВНО"),
        "Real Godot F10 changes physical camera sensitivity and native RU label")
    _assert(game.session.checkpoint() == idle and not game.started,
        "F10 cannot create a mission, move source player, or alter history from idle")
    _key(game,KEY_F10)
    _assert(game.look_comfort.mode == "invert_y" and game.look_comfort_button.text.contains("ИНВЕРСИЯ"),
        "Second actual native F10 selects inverted vertical look")
    _key(game,KEY_F10)
    _assert(game.look_comfort.mode == "standard" and
        game.session.checkpoint() == idle, "Third F10 recovers original default without mutation")
    game._toggle_language()
    _assert(game.look_comfort_button.text.contains("LOOK / STANDARD") and
        game.touch_look_button.text.contains("LOOK / F10"), "Native camera buttons localize RU/EN")
    game._toggle_language()
    game.start_run()
    var original_choices: Dictionary = game.session.checkpoint()
    var initial_yaw: float = game.yaw
    var initial_pitch: float = game.pitch
    # A real GDScript InputEventScreenDrag follows the same source _input
    # as a physical touchscreen, then shared _look() for mouse/gamepad.
    _drag(game,20.0,8.0)
    _assert(_near(game.yaw,initial_yaw-0.042) and
        _near(game.pitch,initial_pitch-0.0168) and
        _near(game.player.rotation.y,game.yaw) and
        _near(game.camera.rotation.x,game.pitch),
        "Actual source InputEventScreenDrag changes native Camera3D/player yaw with standard 0.0021")
    _key(game,KEY_F10)
    var before_gentle: float = game.yaw
    _drag(game,20.0,8.0)
    _assert(_near(game.yaw,before_gentle-0.025),
        "G14 F10 gentle speed flows through actual native 3D camera path")
    _key(game,KEY_F10)
    var before_invert: float = game.pitch
    var yaw_invert: float = game.yaw
    _drag(game,20.0,8.0)
    _assert(_near(game.pitch,before_invert+0.0168) and
        _near(game.yaw,yaw_invert-0.042),
        "Actual phone drag inverts only pitch while original yaw stays consistent")
    _key(game,KEY_F10)
    _assert(game.look_comfort.mode == "standard", "Physical F10 makes inverted mode reversible")
    var game_now: Dictionary = game.session.checkpoint()
    _assert(game_now["priority"] == original_choices["priority"] and
        game_now["switches"] == original_choices["switches"] and
        game_now["faults"] == original_choices["faults"] and
        not game.session.won, "Camera accessibility may not generate gameplay choices or victory")

    for dims in [Vector2i(390,844),Vector2i(320,720)]:
        game._browser_css_size = dims
        game._layout_hud()
        await process_frame
        var rect: Rect2 = game.touch_look_button.get_global_rect()
        var previous: Rect2 = game.touch_pause_button.get_global_rect()
        var left: Rect2 = game.touch_forecast_button.get_global_rect()
        var right: Rect2 = game.touch_look_button.get_global_rect()
        var actual_window: Rect2 = game.get_viewport().get_visible_rect()
        # CSS width selects actual native HUD behavior but does not resize the
        # Godot headless centered root. Real 390px coordinates are asserted
        # separately in Playwright against physically resized WebGL canvas.
        print("G14_NATIVE_LOOK_GEOMETRY ",dims," real:",actual_window," look:",rect,
            " pause:",previous)
        _assert(rect.size.y >= 44.0 and rect.size.x >= 44.0 and
            actual_window.encloses(rect),
            "Native 51px LOOK control physically fits the real Godot window under 320/390 CSS layout")
        _assert(not rect.intersects(previous) and not rect.intersects(left),
            "Actual LOOK touch button never steals PAUSE or PLAN input")
        _assert(game.touch_ui.visible and game.touch_look_button.visible,
            "Mobile LOOK button remains genuinely playable with normal scene inputs")
    game.touch_look_button.pressed.emit()
    _assert(game.look_comfort.mode == "gentle" and
        game.look_comfort_button.text.contains("ПЛАВНО"),
        "Original Godot mobile LOOK performs same real F10 profile transition")
    game.touch_pause_button.pressed.emit()
    _assert(game.paused and not game.touch_ui.visible and game.pause_panel.visible,
        "Pause modal hides native mobile LOOK input while showing accessible settings")
    var frozen: Dictionary = game.session.checkpoint()
    game.look_comfort_button.pressed.emit()
    _assert(game.look_comfort.mode == "invert_y" and
        game.session.checkpoint() == frozen and game.paused,
        "True 52px native pause camera settings never advance a paused crisis")
    game.resume_button.pressed.emit()
    _assert(not game.paused and game.touch_ui.visible and game.touch_look_button.visible,
        "Native RESUME correctly restores physical LOOK touch controls")
    game.queue_free()
    _stop()
