extends SceneTree
## G12 source-native original control and motor accessibility acceptance.
## Synthetic key events exercise real Godot input; not a physical device stamp.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,reason: String) -> void:
    checks += 1
    if not ok:
        failures.append(reason)

func _key(game: Node,key: Key) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.keycode = key
    game._input(event)

func _pressed(key: Key,down: bool) -> void:
    var event := InputEventKey.new()
    event.pressed = down
    event.keycode = key
    Input.parse_input_event(event)

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G12 ACTUAL INPUT COMFORT PASS: %d real Godot keyboard, pause, arrow and sprint safeguards" % checks)
        quit(0)
        return
    for problem in failures:
        push_error("G12 INPUT FAIL: "+problem)
    quit(1)

func _run() -> void:
    var pref := IPControlComfort.new()
    var path: String = "user://iron_pulse_g12_test_profile.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    _assert(pref.mode == "wasd_hold" and not pref.sprint_latched,
        "Original keyboard default must be source-compatible WASD + hold SHIFT")
    _assert(pref.readout()["local_only"] and not pref.readout()["telemetry_uploaded"] and
        not pref.readout()["automated_player_actions"],
        "G12 cannot simulate player input or export private identifiers")
    _assert(not pref.set_mode("instant_victory") and pref.mode == "wasd_hold",
        "Unknown profile cannot grant progress or mutate source")
    _assert(pref.axes(Vector2(1,0),Vector2(0,-1),Vector2.ZERO,Vector2.ZERO) == Vector2(1,0),
        "Classic source key mapping stays WASD")
    _assert(pref.cycle() == "arrows_hold" and
        pref.axes(Vector2(1,0),Vector2(0,-1),Vector2.ZERO,Vector2.ZERO) == Vector2(0,-1),
        "Arrow preset genuinely changes selected physical keyboard")
    _assert(pref.axes(Vector2(1,0),Vector2(0,-1),Vector2(1,0),Vector2.ZERO) ==
        Vector2(1,-1).normalized(),
        "Touch movement remains available in keyboard accessibility mode")
    _assert(pref.cycle() == "arrows_toggle" and
        pref.handle_shift_pressed(true) and pref.sprint_latched and
        pref.sprinting(false), "Pressing SHIFT once really toggles sprint")
    _assert(pref.handle_shift_pressed(true) and not pref.sprint_latched and
        not pref.sprinting(false), "Pressing SHIFT twice releases sprint")
    _assert(not pref.handle_shift_pressed(false) and not pref.sprint_latched,
        "Inactive game, pause or dialog can never toggle sprint")
    _assert(pref.handle_shift_pressed(true) and pref.sprint_latched,
        "Second solo sprint test must start a latched sprint")
    _assert(pref.save_to(path),"G12 control enum must persist only locally")
    var loaded := IPControlComfort.new()
    _assert(loaded.load_from(path) and loaded.mode == "arrows_toggle" and
        not loaded.sprint_latched, "Reopening a local setting cannot restore a dangerous latched sprint")
    var config := ConfigFile.new()
    config.set_value("presentation","schema",IPControlComfort.FORMAT)
    config.set_value("presentation","mode","fake_win")
    config.save(path)
    var bad := IPControlComfort.new()
    _assert(not bad.load_from(path) and bad.mode == "wasd_hold",
        "Malformed local preferences reject unsafe presets and fall back safely")
    pref.on_stop()
    _assert(not pref.sprint_latched and pref.cycle() == "wasd_hold",
        "Pause/finish must release any toggled sprint; preset cycle remains reversible")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    var scene: PackedScene = load("res://Main.tscn")
    _assert(scene != null,"G12 must still import the actual unchanged three-act Godot game")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.control_comfort.mode == "wasd_hold" and
        game.control_comfort_button != null and game.touch_pause_button != null,
        "Game must mount real optional controls menu and native mobile pause entry")
    var initial: Dictionary = game.session.checkpoint()
    _key(game,KEY_F7)
    _assert(game.control_comfort.mode == "arrows_hold" and
        game.session.checkpoint() == initial,
        "F7 changes actual keyboard scheme but cannot start or alter any mission")
    _assert(game.control_comfort_button.text.contains("СТРЕЛКИ"),
        "Original pause menu shows localized arrow controls")
    _key(game,KEY_F7)
    _assert(game.control_comfort.mode == "arrows_toggle",
        "F7 changes source input into motor-accessible toggle-sprint mode")
    game._toggle_language()
    _assert(game.control_comfort_button.text.contains("SHIFT TOGGLE"),
        "English input scheme must be explained in actual Godot controls")
    game.start_run()
    var started: Dictionary = game.session.checkpoint()
    _key(game,KEY_SHIFT)
    _assert(game.control_comfort.sprint_latched and
        game.control_comfort.sprinting(false), "Real Godot SHIFT dispatch latches sprint when requested")
    _key(game,KEY_SHIFT)
    _assert(not game.control_comfort.sprint_latched and game.session.switches == started["switches"],
        "SHIFT reset never cycles power buses or gameplay decisions")
    _key(game,KEY_F7)
    _assert(game.control_comfort.mode == "wasd_hold" and
        not game.control_comfort.sprint_latched,
        "Return to standard scheme resets one-hand sprint state")

    _key(game,KEY_F7)
    var before_pos: Vector3 = game.player.global_position
    _pressed(KEY_UP,true)
    for _i in 12:
        await physics_frame
    _pressed(KEY_UP,false)
    var moved: Vector3 = game.player.global_position
    _assert(moved.distance_to(before_pos) > 0.06,
        "Actual physical ArrowUp key MUST move the real CharacterBody3D in arrow mode")
    _assert(game.session.scenario_id == "blackout" and not game.session.core_scanned
        and game.session.faults == started["faults"],
        "New physical movement cannot grant fictional mission progress")

    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
    await process_frame
    _assert(game.touch_pause_button.get_rect().size.y >= 44 and
        game.touch_pause_button.get_rect().end.x <= 390.0,
        "Real mobile PAUSE button must be 44px+ and fully visible at 390px")
    game.touch_pause_button.pressed.emit()
    _assert(game.paused and game.pause_panel.visible and not game.touch_ui.visible,
        "Actual mobile PAUSE must freeze game and expose unobstructed menu")
    var paused_state: Dictionary = game.session.checkpoint()
    game._physics_process(1.0)
    _assert(game.session.checkpoint() == paused_state,
        "Paused operator input options cannot consume simulation time")
    game._gamepad_button(JOY_BUTTON_X)
    _assert(game.control_comfort.mode == "arrows_toggle" and game.paused,
        "Actual mapped gamepad X changes keyboard preset only from pause")
    game.resume_button.pressed.emit()
    _assert(not game.paused and not game.pause_panel.visible and game.touch_ui.visible,
        "Native mobile resume restores touch controls and original mission")
    game._browser_css_size = Vector2i(320,720)
    game._layout_hud()
    await process_frame
    var touch_rect: Rect2 = game.touch_pause_button.get_rect()
    var view_rect: Rect2 = game.touch_vision_button.get_rect()
    var guide_rect: Rect2 = game.touch_guide_button.get_rect()
    _assert(touch_rect.size.y >= 44 and touch_rect.end.x <= 320.0 and
        not touch_rect.intersects(view_rect) and not touch_rect.intersects(guide_rect),
        "320px touch PAUSE does not overlap G11 VIEW or existing GUIDE controls")
    _assert(game.vision.mode == "standard" and
        game.session.switches == started["switches"] and game.session.faults == started["faults"],
        "G12 leaves G11 visuals, real choice/bus decisions and mission intact")
    game.queue_free()
    _finish()
