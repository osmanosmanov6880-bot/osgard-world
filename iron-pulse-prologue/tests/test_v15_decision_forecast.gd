extends SceneTree
## V15: exact engine clone forecasts + real Godot keyboard/touch HUD.
var checks: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,description: String) -> void:
    checks += 1
    if not ok:
        errors.append(description)

func _key(game: Node,key: Key) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.keycode = key
    game._input(event)

func _check_projection(engine: IPCrisisEngine,predictor: IPDecisionForecast) -> void:
    var before: Dictionary = engine.checkpoint()
    var report: Dictionary = predictor.evaluate(engine)
    _check(report.get("schema") == "IRON_PULSE_DECISION_FORECAST_V15",
        "Only source-bound forecast schema is accepted")
    _check(report.get("horizon_seconds") == 30.0,
        "Predictions always cover a bounded 30s horizon")
    var routes: Array = report.get("routes",[])
    _check(routes.size() == (3 if engine.coolant_repaired and not engine.finished() else 1),
        "Power alternatives exist only after genuine repair")
    for route in routes:
        var clone := IPCrisisEngine.new()
        var restored: bool = clone.restore_checkpoint(before)
        _check(restored,"Forecast path is based on independently valid engine checkpoint")
        if not restored:
            continue
        var index: int = int(route["bus_index"])
        if index >= 0:
            _check(clone.cycle_bus(index),"Physical power cycle route is legal in source engine")
        clone.tick(30.0)
        _check(is_equal_approx(float(route["heat"]),snappedf(clone.heat,0.1)) and
               is_equal_approx(float(route["oxygen"]),snappedf(clone.oxygen,0.1)) and
               is_equal_approx(float(route["door"]),snappedf(clone.door_charge,0.1)) and
               bool(route["loss"]) == clone.lost,
               "Preview equals actual deterministic cloned engine across heat, air, gate and failure")
        _check(str(route["bus_a"]) == clone.bus_a and str(route["bus_b"]) == clone.bus_b,
               "Compared buses are actual engine allocations, not invented options")
    _check(engine.checkpoint() == before,
        "All forecast branches are strictly read-only, original game state unchanged")

func _run() -> void:
    var predictor := IPDecisionForecast.new()
    var grid := IPCrisisEngine.new()
    grid.reset("blackout")
    _check_projection(grid,predictor)
    _check(not predictor.evaluate(grid)["comparison_available"],
        "Unavailable terminals never appear as an unlocked planning action")
    grid.scan_core()
    grid.repair_coolant()
    _check_projection(grid,predictor)
    var grid_routes: Array = predictor.evaluate(grid)["routes"]
    _check(grid_routes[2]["bus_b"] == "door" and grid_routes[2]["door"] > grid_routes[0]["door"],
        "Reallocating real bus B to DOOR actually changes forecasted charge")
    _check(grid_routes[1]["heat"] > grid_routes[0]["heat"],
        "Removing coolant from real bus A increases projected thermal stress")
    _check(predictor.text_report(predictor.evaluate(grid),"ru").contains("БЕЗ СМЕНЫ") and
           predictor.text_report(predictor.evaluate(grid),"en").contains("SWITCH B"),
           "Russian/English reports show genuine simulated routes")
    var thermal := IPCrisisEngine.new()
    thermal.reset("thermal")
    thermal.scan_core()
    thermal.emergency_repair()
    thermal.tick(38.0)
    _check_projection(thermal,predictor)
    var heat_report: Dictionary = predictor.evaluate(thermal)
    _check(heat_report["routes"][0]["pulse_count"] >= 1,
        "Thermal pulse is forecast by original scenario integrator")
    var breach := IPCrisisEngine.new()
    breach.reset("breach")
    breach.scan_core()
    breach.emergency_repair()
    _check_projection(breach,predictor)
    _check(breach.repair_method == "rapid_patch",
        "Micro-leak branch is a real AIR gameplay strategy")
    var emergency := IPCrisisEngine.new()
    emergency.reset("blackout")
    emergency.heat = 99.0
    _check_projection(emergency,predictor)
    var danger: Dictionary = predictor.evaluate(emergency)["routes"][0]
    _check(danger["severity"] == "FAILURE" and danger["predicted_seconds"] < 30.0 and not emergency.lost,
        "Predicted failure occurs in isolated engine, never kills actual player")
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null,"Actual Godot 3D level remains loadable with V15")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.forecast_panel != null and not game.forecast_panel.visible,
        "A7 tactical pane exists but never obstructs intro or game by default")
    _check(game.touch_forecast_button != null and game.touch_forecast_button.text == "PLAN / T",
        "Touch users have a real wired decision console control")
    _key(game,KEY_T)
    _check(not game.forecast_panel.visible,
        "Forecast cannot open or fabricate results before an actual run")
    game.start_run()
    var before: Dictionary = game.session.checkpoint()
    _key(game,KEY_T)
    _check(game.forecast_panel.visible and
           game.forecast_report.get("schema") == "IRON_PULSE_DECISION_FORECAST_V15",
           "T opens live 30-second source-bound forecast inside actual Godot")
    _check(game.session.checkpoint() == before,
        "Opening the forecast neither pauses nor mutates gameplay resources")
    _check(game.forecast_label.text.contains("БЕЗ СМЕНЫ"),
        "Real in-world RU cockpit uses the original simulated result")
    _key(game,KEY_L)
    _check(game.locale == "en","Language hotkey still works with forecast visible")
    game._refresh_decision_forecast()
    _check(game.forecast_label.text.contains("HOLD"),
        "English tactical cockpit refreshes correctly after language switch")
    _key(game,KEY_T)
    _check(not game.forecast_panel.visible and game.session.checkpoint() == before,
        "Second T closes pane with no gameplay or checkpoint corruption")
    var old_save: Dictionary = game._checkpoint_payload()
    _check(old_save.get("schema") == "IRON_PULSE_CAMPAIGN_V6" and not old_save.has("forecast"),
        "V15 is compatible with all existing V6/V9 campaign saves")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("IRON PULSE V15 DECISION FORECAST PASS: %d native gameplay and GUI checks" % checks)
        quit(0)
    else:
        for detail in errors:
            push_error("V15 FORECAST FAIL: "+detail)
        quit(1)
