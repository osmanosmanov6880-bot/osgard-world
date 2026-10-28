extends SceneTree
## V16: REAL engine evidence + in-game hazard cockpit, RU/EN and old-save QA.
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool,message: String) -> void:
    assertions += 1
    if not condition:
        failures.append(message)

func _key(game: Node,key: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = key
    event.pressed = true
    game._input(event)

func _real_win(scenario: String) -> IPCrisisEngine:
    var e := IPCrisisEngine.new()
    e.reset(scenario)
    e.scan_core()
    e.choose_priority("crew")
    e.repair_coolant()
    e.cycle_bus(1)
    e.tick(25.0)
    e.cycle_bus(1)
    e.cycle_bus(1)
    e.activate_override()
    e.escape()
    return e

func _run() -> void:
    var radar := IPThreatRadar.new()
    var report_engine := IPAfterActionReview.new()
    var grid := IPCrisisEngine.new()
    grid.reset("blackout")
    var original_grid: Dictionary = grid.checkpoint()
    var initial: Dictionary = radar.snapshot(grid)
    _check(initial["schema"] == "IRON_PULSE_THREAT_RADAR_V16", "Native hazard schema is fixed")
    _check(initial["tier"] == "STABLE" and initial["reason"] == "nominal",
        "Opening GRID hazard level reflects actual healthy source state")
    _check(radar.cockpit_text(initial,"ru").contains("НОРМА") and
           radar.cockpit_text(initial,"en").contains("NOMINAL"),
           "Bilingual real cockpit status reads the exact initial engine")
    _check(grid.checkpoint() == original_grid,"Threat reading never mutates original gameplay")

    grid.heat = 94.0
    _check(radar.snapshot(grid)["tier"] == "CRITICAL" and radar.snapshot(grid)["reason"] == "thermal",
        "A real 94C core shows critical thermal status")
    grid.heat = 48.0
    grid.oxygen = 22.0
    _check(radar.snapshot(grid)["reason"] == "oxygen" and radar.snapshot(grid)["tier"] == "CRITICAL",
        "A real 22 percent reserve displays critical oxygen")
    grid.oxygen = 93.0
    grid.bus_a = "door"
    _check(radar.snapshot(grid)["reason"] == "coolant" and radar.snapshot(grid)["tier"] == "WATCH",
        "Power allocation to DOOR correctly warns about unpowered coolant")

    var heat := IPCrisisEngine.new()
    heat.reset("thermal")
    heat.elapsed = 29.0
    var pulse: Dictionary = radar.snapshot(heat)
    _check(pulse["reason"] == "pulse" and is_equal_approx(float(pulse["thermal_pulse_in_s"]),16.0),
        "Thermal pulse countdown is derived from real source next_pulse_at")
    var breach := IPCrisisEngine.new()
    breach.reset("breach")
    _check(radar.snapshot(breach)["reason"] == "unsealed",
        "AIR briefing truthfully detects the unsealed breach")
    breach.scan_core()
    breach.emergency_repair()
    var micro: Dictionary = radar.snapshot(breach)
    _check(micro["microleak"] and micro["reason"] == "microleak",
        "Real rapid patch shows residual leak instead of claiming full repair")

    var no_result: Dictionary = report_engine.review(breach)
    _check(no_result.is_empty(),"Black box cannot counterfeit a completed operation")
    var winner: IPCrisisEngine = _real_win("blackout")
    _check(winner.won and not winner.lost, "Finished run originates in actual source engine mechanics")
    var before_win: Dictionary = winner.checkpoint()
    var completed: Dictionary = report_engine.review(winner)
    _check(completed.get("schema") == "IRON_PULSE_AFTER_ACTION_V16" and completed["outcome"] == "VICTORY",
        "Source-bound success review is available only after genuine evacuation")
    _check(completed["heat"] == snappedf(winner.heat,0.1) and
           completed["oxygen"] == snappedf(winner.oxygen,0.1) and
           completed["faults"] == winner.faults and completed["grade"] == winner.grade(),
           "Every displayed measurement and grade equals engine recorded result")
    _check(completed["history"] is Array and completed["history"].has("crew_evacuated") and
           not completed["history_has_timestamps"],
           "Event log is real ordered history and never fabricates timestamps")
    _check(report_engine.localized(completed,"ru").contains("ЧЁРНЫЙ ЯЩИК") and
           report_engine.localized(completed,"en").contains("ORDER ONLY"),
           "Black box has honest RU/EN evidence captions")
    _check(winner.checkpoint() == before_win,"After-action report never mutates original victory")
    var campaign := IPCampaignFlow.new()
    campaign.begin()
    _check(campaign.record_victory(winner), "Campaign credits one true source-engine win")
    var in_campaign: Dictionary = report_engine.review(winner,campaign)
    _check(in_campaign["campaign_confirmed_victories"] == 1 and
           in_campaign["campaign"] and in_campaign["outcome"] == "VICTORY",
           "Black box shows exactly one actual chapter, never imaginary completed campaign")

    var overheated := IPCrisisEngine.new()
    overheated.reset("thermal")
    overheated.heat = 99.0
    overheated.tick(10.0)
    _check(overheated.lost and not overheated.won,"Native simulation produced an actual thermal loss")
    var heat_failure: Dictionary = report_engine.review(overheated)
    _check(heat_failure["outcome"] == "FAILURE" and
           heat_failure["reason"] == "reactor_overheat" and heat_failure["focus"] == "cooling",
           "After-action failure identifies actual physics cause and specific lesson")
    _check(heat_failure["grade"] == "UNRATED",
           "The failed run never invents a positive victory grade")
    var oxygen_failure := IPCrisisEngine.new()
    oxygen_failure.reset("breach")
    oxygen_failure.bus_b = "door"
    oxygen_failure.tick(100.0)
    _check(oxygen_failure.lost and
           report_engine.review(oxygen_failure)["reason"] == "life_support_lost",
           "A real AIR life-support failure receives the correct evidence-based classification")
    var early := IPCrisisEngine.new()
    early.reset("blackout")
    early.time_left = 0.05
    early.tick(1.0)
    _check(early.lost and report_engine.review(early)["reason"] == "time_expired",
        "Native expired GRID timer triggers a real clock-based debrief")

    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null,"Original 3D scene remains loadable")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.threat_label != null and game.threat_label.text.contains("НОРМА"),
        "On-screen native threat data exists and starts with real initial values")
    _check(game.debrief_panel != null and not game.debrief_panel.visible and
           game.debrief_button.custom_minimum_size.y >= 44.0,
           "Black box is hidden until a real result and has an accessible touch CTA")
    _key(game,KEY_B)
    _check(not game.debrief_panel.visible and game.black_box_report.is_empty(),
        "B cannot open invented reports before an operation")
    game.start_run()
    var before: Dictionary = game.session.checkpoint()
    _key(game,KEY_B)
    _check(not game.debrief_panel.visible and game.session.checkpoint() == before,
        "B cannot pause or alter an unfinished game")
    game.session.scan_core()
    game.session.choose_priority("crew")
    game.session.repair_coolant()
    game.session.cycle_bus(1)
    game.session.tick(25.0)
    game.session.cycle_bus(1)
    game.session.cycle_bus(1)
    game.session.activate_override()
    game.session.escape()
    _check(game.session.won,"Native game test finished with real original reactor rules")
    game._show_end()
    _check(game.end_panel.visible and not game.black_box_report.is_empty(),
        "Actual game victory creates real report and visible final CTA")
    var saved: Dictionary = game.session.checkpoint()
    _key(game,KEY_B)
    _check(game.debrief_panel.visible and
           game.debrief_label.text.contains("ЧЁРНЫЙ ЯЩИК"),
        "Physical B key opens bilingual after-action evidence inside the Godot scene")
    _check(game.session.checkpoint() == saved,
        "Reading after-action evidence never modifies the finished mission")
    _key(game,KEY_L)
    _check(game.locale == "en" and game.debrief_label.text.contains("BLACK BOX") and
           game.debrief_close_button.text.contains("CLOSE"),
        "Existing language toggle localizes the already-open real report")
    _key(game,KEY_ESCAPE)
    _check(not game.debrief_panel.visible and game.end_panel.visible,
        "Escape returns to original completion screen instead of changing campaign")
    game.debrief_button.pressed.emit()
    _check(game.debrief_panel.visible and
           game.debrief_close_button.custom_minimum_size.y >= 44.0,
        "Touch-capable finish button opens report with 44px+ close target")
    game.debrief_close_button.pressed.emit()
    _check(not game.debrief_panel.visible,
        "On-screen close control hides native report")
    game._restart()
    _check(game.black_box_report.is_empty() and not game.debrief_panel.visible and
           not game.session.finished(),
        "Restart clears visual report while preserving real gameplay")
    var legacy: Dictionary = game._checkpoint_payload()
    _check(legacy.get("schema") == "IRON_PULSE_CAMPAIGN_V6" and
           not legacy.has("black_box") and not legacy.has("threat_radar"),
        "Existing V6/V9 validated checkpoint layout remains byte-format compatible")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V16 BLACK BOX HAZARD PASS: %d real engine + UI checks" % assertions)
        quit(0)
        return
    for issue in failures:
        push_error("V16 NATIVE FAIL: "+issue)
    quit(1)
