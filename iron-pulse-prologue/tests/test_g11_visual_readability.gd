extends SceneTree
## IRON PULSE G11 — real Godot presentation/readability regressions.
## This uses the source Godot scene and crisis engine, not a screenshot mock.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(ok: bool,why: String) -> void:
    checks += 1
    if not ok:
        failures.append(why)

func _input_key(game: Node,key: Key) -> void:
    var e := InputEventKey.new()
    e.keycode = key
    e.pressed = true
    game._input(e)

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE G11 READABILITY PASS: %d real Godot engine, in-world signage, accessibility and save checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("G11 READABILITY FAIL: " + failure)
        quit(1)

func _run() -> void:
    var profile := IPVisionProfile.new()
    var path: String = "user://iron_pulse_g11_ci_fixture.cfg"
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
    _assert(profile.mode == "standard" and not profile.high_contrast(),
        "G11 standard layout remains the default for prior players")
    _assert(profile.readout()["presentation_only"] and
        not profile.readout()["gameplay_mutated"] and
        not profile.readout()["telemetry_uploaded"],"Pure preferences cannot falsify the game")
    _assert(not profile.set_mode("magic_win") and profile.mode == "standard",
        "Source must reject unsafe/unknown vision modes")
    _assert(profile.text_scale(true) == 1.0 and
        profile.emphasis_tier(48.0,93.0) == "stable" and
        profile.emphasis_tier(73.0,88.0) == "watch" and
        profile.emphasis_tier(94.0,20.0) == "critical",
        "Real heat/air thresholds must be deterministic and not color-only")
    _assert(profile.hazard_words("critical","ru").contains("ОПАСНОСТЬ") and
        profile.hazard_words("critical","en").contains("CRITICAL"),
        "Risk must have actual localized words, not just red/blue light")
    _assert(profile.cycle() == "contrast" and profile.high_contrast(),
        "Contrast must be an explicit reversible real-player action")
    _assert(profile.cycle() == "large" and profile.text_scale(false) > 1.10 and
        profile.text_scale(true) < profile.text_scale(false),
        "Large mode must increase legibility without overflowing compact mobile")
    _assert(profile.save_to(path),"Only the visual mode should be persisted locally")
    var loaded := IPVisionProfile.new()
    _assert(loaded.load_from(path) and loaded.mode == "large",
        "Native visual preference settings must survive app restarts")
    var broken := ConfigFile.new()
    broken.set_value("presentation","schema",IPVisionProfile.FORMAT)
    broken.set_value("presentation","vision_mode","finish_all_missions")
    broken.save(path)
    var reject := IPVisionProfile.new()
    _assert(not reject.load_from(path) and reject.mode == "standard",
        "Forged settings must not unlock/alter gameplay or presentation")
    DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

    var architecture := IPObsidianArchitecture.new()
    root.add_child(architecture)
    await process_frame
    var baseline = architecture.readout()
    _assert(baseline["g11_status_labels"] == 3 and
        baseline["g11_color_independent_warning"] and
        baseline["g11_status_tier"] == "stable",
        "G11 embeds three actual diegetic word-based safety labels in 3D")
    architecture.update_hazard("thermal",92.0,82.0,14.0,false)
    _assert(architecture.readout()["g11_status_tier"] == "critical" and
        architecture.readout()["g11_risk_words"][0].contains("ОПАСНОСТЬ"),
        "G11 real in-world safety warning must follow actual crisis heat")
    architecture.set_locale("en")
    architecture.set_accessibility(true)
    var readable = architecture.readout()
    _assert(readable["g11_high_contrast"] and
        readable["g11_risk_words"][1].contains("CRITICAL") and
        architecture.risk_status_labels[1].outline_size >= 12,
        "Physical 3D text must remain readable independently of color in RU/EN")
    architecture.set_quality("eco")
    _assert(architecture.critical_layer.visible and architecture.risk_status_labels[0].visible,
        "Energy-saving ECO must preserve critical safety words")
    architecture.set_accessibility(false)
    architecture.update_hazard("breach",45.0,91.0,22.0,true)
    _assert(architecture.readout()["g11_status_tier"] == "stable" and
        architecture.readout()["g11_risk_words"][0].contains("NORMAL"),
        "Reduced motion and hazards reset without fake alarms")
    architecture.queue_free()
    await process_frame

    var main: PackedScene = load("res://Main.tscn")
    _assert(main != null,"Actual original Main.tscn must parse, load and run")
    if main == null:
        _finish()
        return
    var game = main.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _assert(game.vision.mode == "standard" and game.vision_button != null and
        game.touch_vision_button != null,
        "G11 actually mounts pause-menu and touchscreen vision controls")
    var before: Dictionary = game.session.checkpoint()
    var old_font: int = game.objective_label.get_theme_font_size("font_size")
    _input_key(game,KEY_F6)
    _assert(game.vision.mode == "contrast" and
        game.header_panel.get_theme_stylebox("panel").border_width_left >= 2,
        "Physical F6 must upgrade Godot HUD borders and backgrounds")
    _assert(game.session.checkpoint() == before,
        "High contrast cannot change or advance simulation")
    _input_key(game,KEY_F6)
    var new_font: int = game.objective_label.get_theme_font_size("font_size")
    _assert(game.vision.mode == "large" and new_font > old_font,
        "Second F6 must increase actual rendered native font sizes")
    _assert(game.vision_button.text.contains("КРУПНЫЙ"),
        "Pause visual preference button must reflect the Russian mode")
    _assert(game.obsidian_world.readout()["g11_high_contrast"] is bool and
        game.obsidian_world.readout()["g11_high_contrast"],
        "HUD preference must also change physical 3D in-world sign outlines")
    game._toggle_language()
    _assert(game.vision_button.text.contains("LARGE TEXT") and
        game.obsidian_world.readout()["g11_risk_words"][0].contains("NORMAL"),
        "G11 mode and 3D safety words must stay localized after EN switch")
    _input_key(game,KEY_F6)
    _assert(game.vision.mode == "standard" and
        game.header_panel.get_theme_stylebox("panel").border_width_left == 1,
        "Third F6 restores original Godot visual baseline")
    game.start_run()
    var game_before: Dictionary = game.session.checkpoint()
    game._pause_toggle()
    game._gamepad_button(JOY_BUTTON_Y)
    _assert(game.vision.mode == "contrast" and game.paused,
        "Gamepad Y changes readability during pause without ending game")
    game._pause_toggle()
    _assert(game.session.checkpoint() == game_before and not game.paused,
        "Pause visibility switch never spends fictional reactor mission time")
    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
    await process_frame
    _assert(game.touch_ui.visible and game.touch_vision_button.visible and
        game.touch_vision_button.get_rect().size.y >= 44,
        "Actual responsive 390px touchscreen must expose 44px VIEW button")
    game.touch_vision_button.pressed.emit()
    _assert(game.vision.mode == "large" and
        game.objective_label.get_theme_font_size("font_size") >= 16,
        "Real native mobile VIEW button enlarges original HUD text")
    var mobile: Dictionary = game.vision.readout(true)
    _assert(float(mobile["text_scale"]) <= 1.09 and
        not mobile["account_ids_collected"] and not mobile["device_identifiers_collected"],
        "Compact legibility has bounded scale without tracking")
    game._browser_css_size = Vector2i(320,720)
    game._layout_hud()
    await process_frame
    _assert(game.touch_vision_button.get_rect().size.y >= 44 and
        game.touch_vision_button.get_rect().position.x >= 0 and
        game.touch_vision_button.get_rect().end.x <= 320.0,
        "Real 320px viewport does not clip the in-game visual control")
    var after_mobile: Dictionary = game.session.checkpoint()
    _assert(after_mobile["switches"] == game_before["switches"] and
        after_mobile["faults"] == game_before["faults"] and
        after_mobile["core_scanned"] == game_before["core_scanned"] and
        after_mobile["priority"] == game_before["priority"] and
        after_mobile["relays_activated"] == game_before["relays_activated"],
        "Readability never performs player actions; genuine gameplay time may advance after resume")
    # Regression from exact-source Chromium: mobile gameplay controls used
    # to intercept real pause-menu graphics buttons, including V18 AUTO.
    game._browser_css_size = Vector2i(390,844)
    game._layout_hud()
    game._pause_toggle()
    _assert(game.paused and game.pause_panel.visible and not game.touch_ui.visible,
        "True pause must hide overlaid mobile gameplay controls")
    game._resume()
    _assert(not game.paused and not game.pause_panel.visible and game.touch_ui.visible,
        "Actual RESUME restores native mobile movement buttons")
    game.queue_free()
    _finish()
