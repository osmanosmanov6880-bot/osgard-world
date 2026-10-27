extends SceneTree
## W63 real Godot 4.4.1 gameplay, UI, and deterministic balance proof.
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, message: String) -> void:
    assertions += 1
    if not condition:
        failures.append(message)

func _run() -> void:
    var c := A7CascadeCore.new()
    var original: Dictionary = c.snapshot()
    _check(original["status"] == "playing", "Initial campaign is playable")
    _check(original["shift"] == 0 and original["actions_left"] == 2, "Two real actions per cycle")
    _check(original["offline_only"] and not original["connected_to_real_equipment"], "No actual machinery connection")
    _check(original["history"].is_empty(), "No generated fake player history")
    _check(not c.choose("INJECT_UNKNOWN_COMMAND"), "Unrecognized commands cannot alter simulator")
    _check(c.snapshot()["history"].is_empty(), "Rejected commands are state-neutral")

    # Winning sequence independently found by a finite-state decision search.
    # This shows the new mechanic is solvable, not that players enjoy it.
    var solution: Array[Array] = [
        ["PUMP", "SCAN"], ["PUMP", "SEAL"],
        ["VENT", "SCAN"], ["VENT", "SEAL"],
        ["PUMP", "POWER"], ["VENT", "SCAN"],
    ]
    for shift_index in range(solution.size()):
        _check(c.snapshot()["shift"] == shift_index, "Expected current cycle %d" % shift_index)
        _check(c.snapshot()["actions_left"] == 2, "Each cycle has two genuine decisions")
        for action in solution[shift_index]:
            _check(c.choose(action), "Legitimate player decision accepted: " + action)
            _check(c.snapshot()["history"].size() <= 12, "Action history remains bounded")
        _check(c.snapshot()["shift"] == shift_index + 1, "Environmental cascade advanced exactly once")
        _check(c.snapshot()["incidents_survived"] == shift_index + 1, "Each incident is accounted for")
    _check(c.snapshot()["status"] == "won", "Six-cycle winning strategy actually wins")
    var stats: Dictionary = c.snapshot()["metrics"]
    _check(int(stats["heat"]) <= 75 and int(stats["pressure"]) <= 75, "Winning heat and pressure limits met")
    _check(int(stats["seal"]) >= 50 and int(stats["signal"]) >= 50, "Winning seal and signal limits met")
    _check(int(stats["energy"]) >= 30 and int(stats["integrity"]) >= 55, "Winning reserve and containment limits met")
    _check(c.snapshot()["history"].size() == 12, "Twelve decisions in the 6-cycle game")
    _check(not c.choose("POWER"), "Winning campaign cannot continue past final step")

    c.reset()
    _check(c.snapshot()["shift"] == 0 and c.snapshot()["status"] == "playing", "Restart resets all rounds")
    _check(c.snapshot()["history"].is_empty(), "Restart clears previous action history")
    _check(c.snapshot()["metrics"] == original["metrics"], "Restart restores exact deterministic initial conditions")
    # Unsafe strategy: permanent venting sacrifices the seal, eventually loses.
    for i in range(12):
        if c.snapshot()["status"] != "playing":
            break
        _check(c.choose("VENT"), "Vent is legitimate but has trade-offs")
    _check(c.snapshot()["status"] in ["failed", "unstable"], "One-button spam cannot guarantee success")
    _check(not c.choose("PUMP"), "Failed session cannot silently restart")

    # Independently instantiate the actual playable scene, not just a math model.
    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    _check(scene != null, "Native Godot standalone scene loads")
    if scene == null:
        _finish()
        return
    var ui: A7CascadeScreen = scene.instantiate() as A7CascadeScreen
    _check(ui != null, "Actual Control interface instantiates")
    if ui == null:
        _finish()
        return
    root.add_child(ui)
    await process_frame
    await process_frame
    _check(ui.action_buttons.size() == 5, "Five clickable real Godot actions available")
    _check(ui.metric_bars.size() == 6, "Six actual Godot metric bars available")
    _check(ui.round_pips.size() == 6, "Six real incident-cycle indicators available")
    _check(ui.find_child("AdaptiveScrollableCascade", true, false) != null,
        "Native mobile ScrollContainer exists")

    for width in [320, 390, 1366]:
        ui.size = Vector2(width, 800)
        ui._render(ui.model.snapshot())
        await process_frame
        _check(ui.brand_label.text.contains("ПОСЛЕДНИЙ РУБЕЖ"), "RU identity at %d" % width)
        _check(ui.action_buttons["PUMP"].text.contains("НАСОС"), "RU interactive action at %d" % width)
        _check(ui.footnote.text.contains("НЕ ИНСТРУКЦИЯ"), "Explicit fictional safety disclaimer at %d" % width)
        _check(ui.find_child("AdaptiveScrollableCascade", true, false) != null,
            "Scroll viewport remains present at %d" % width)

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en", "Player can switch EN without restarting or changing stats")
    _check(ui.brand_label.text.contains("LAST FRONTIER"), "English identity is real native label")
    _check(ui.action_buttons["PUMP"].text.contains("PUMP"), "English action text is real native Button")
    _check(ui.footnote.text.contains("NOT INSTRUCTIONS"), "English fictional warning remains")
    _check(ui.model.snapshot()["shift"] == 0, "Localization cannot advance a shift")

    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(ui.model.snapshot()["actions_left"] == 1, "Player Button clicks change real decision engine")
    _check(int(ui.model.snapshot()["metrics"]["heat"]) == 42, "Real pump action changes thermal state")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 1, "Second real button advances to next environmental incident")
    _check(ui.round_pips[0].color == Color("79d2c0"), "First incident indicator visibly completed")

    ui.restart_button.emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 0, "Visible restart Button genuinely resets mission")
    _check(ui.model.snapshot()["actions_left"] == 2, "Restart restores two decisions")
    _check(ui.model.snapshot()["history"].is_empty(), "Restart clears gameplay records")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W63 A7 CASCADE REAL GODOT PLAYABLE VERTICAL SLICE PASS: %d checks" % assertions)
        quit(0)
    else:
        for error in failures:
            push_error("W63 ORIGINAL GAMEPLAY FAILED: " + error)
        quit(1)
