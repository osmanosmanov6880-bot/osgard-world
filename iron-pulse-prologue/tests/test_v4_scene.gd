extends SceneTree
## Verify the real scene, native buttons, physical repair terminal and language changes.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Playable Godot 4.4.1 scene imports")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.scenario_buttons.size() == 3, "Exactly three real scenario picker buttons exist")
    _check(game.selected_scenario == "blackout" and game.session.scenario_id == "blackout", "Original BLACKOUT remains default")
    _check(game.intro_panel.visible, "Players can select a scenario before starting")
    _check(game.scenario_brief.text.find("ОТКЛЮЧЕНИЕ") >= 0, "Russian baseline scenario briefing is visible")
    _check((game.scenario_buttons["blackout"] as Button).button_pressed, "Selected scenario button reflects initial game state")
    game._select_scenario("thermal")
    _check(game.session.scenario_id == "thermal" and game.session.heat == 72.0, "Selecting HEAT changes actual deterministic hazard")
    _check((game.scenario_buttons["thermal"] as Button).button_pressed, "HEAT selection visually updates native buttons")
    _check(game.scenario_brief.text.find("КАСКАД") >= 0, "HEAT emergency instructions appear in RU")
    game._select_scenario("breach")
    _check(game.session.scenario_id == "breach" and game.session.oxygen == 68.0, "Selecting AIR changes actual oxygen reserves")
    _check(game.scenario_brief.text.find("РАЗГЕРМЕТИЗАЦИЯ") >= 0, "AIR scenario informs the player about a leak")
    game._toggle_language()
    _check(game.locale == "en" and game.scenario_brief.text.find("OXYGEN BREACH") >= 0,
        "Scenario briefing localizes to English without replacing active game")
    _check((game.scenario_buttons["breach"] as Button).button_pressed, "Language toggle preserves selection")
    game._toggle_language()
    game._select_scenario("thermal")
    game.start_run()
    _check(game.started and game.session.scenario_id == "thermal", "Start carries selected scenario into real game")
    _check(game.objective_label.text.find("Просканировать") >= 0, "Scene begins at real scanner objective")
    game._select_scenario("breach")
    _check(game.session.scenario_id == "thermal", "Cannot secretly change difficulty after mission starts")
    game.session.scan_core()
    game._refresh_hud()
    _check(game.objective_label.text.find("Стабилизировать") >= 0,
        "Mission objectives differ from original BLACKOUT after scanning HEAT")
    game.player.position = Vector3(3.0,1.1,-28.0)
    var keyboard_q := InputEventKey.new()
    keyboard_q.pressed = true
    keyboard_q.keycode = KEY_Q
    game._input(keyboard_q)
    _check(game.session.coolant_repaired and game.session.repair_method == "rapid_purge",
        "Q keyboard action reaches the actual physical repair terminal and consumes oxygen")
    _check(game.session.crew_health == 90.0 and game.session.oxygen == 70.0,
        "Fast choice has visible resource consequences inside active game")
    _check(game.terminals.size() == 6, "All original six 3D stations remain intact")
    var fast_button_found: bool = false
    for control in game.touch_ui.get_children():
        if control is Button and control.text == "FAST / Q":
            fast_button_found = true
    _check(fast_button_found, "Phone has a real alternate repair action button")
    game._restart()
    _check(game.session.scenario_id == "thermal" and game.session.repair_method == "",
        "Restart preserves chosen mission but clears previous solution")
    _check(game.session.objective_id() == "scan", "Restart truly returns to scanner")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V4 REAL SCENE PASS: %d native checks" % checks)
        quit(0)
    else:
        for problem in failures:
            push_error("V4 REAL SCENE FAIL: " + problem)
        quit(1)
