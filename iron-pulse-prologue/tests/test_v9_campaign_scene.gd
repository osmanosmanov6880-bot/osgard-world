extends SceneTree
## Native three-operation playable Main.gd campaign UI and checkpoint acceptance.
var checks: int = 0
var problems: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _check(value: bool, label: String) -> void:
    checks += 1
    if not value:
        problems.append(label)
func _completed(scenario: String,priority: String) -> IPCrisisEngine:
    var sim := IPCrisisEngine.new()
    sim.reset(scenario)
    sim.scan_core()
    sim.choose_priority(priority)
    sim.repair_coolant()
    sim.cycle_bus(1)
    sim.tick(25.0)
    sim.cycle_bus(1)
    sim.cycle_bus(1)
    sim.activate_override()
    sim.escape()
    return sim

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null, "Full Godot game scene imports")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.campaign_button is Button and game.campaign_button.text.contains("КАМПАНИЯ"),
        "Actual main menu offers an explicit RU trilogy campaign button")
    _check(not game.campaign.active, "Original standalone selection is unchanged")
    _check(game.session.scenario_id == "blackout", "Historical solo GRID mission remains default")
    game._toggle_language()
    _check(game.campaign_button.text.contains("CAMPAIGN"), "Campaign entry is localized EN")
    game._toggle_language()
    game._start_campaign()
    _check(game.started and game.campaign.active and game.campaign.index == 0,
        "Real campaign button launches GRID as a playable operation")
    _check(game.selected_scenario == "blackout" and not game.intro_panel.visible,
        "Player enters actual first-person mission, not a static map")
    game.session = _completed("blackout","crew")
    _check(game.session.won, "Actual engine GRID mission can be completed")
    game._show_end()
    _check(game.campaign.records.size() == 1 and game.campaign.awaiting_advance(),
        "Victory screen now records genuine first chapter and enables next")
    _check(game.end_button.text.contains("СЛЕДУЮЩАЯ"), "RU end screen provides a functional chapter transition")
    game._end_action()
    _check(game.started and game.selected_scenario == "thermal" and game.campaign.index == 1,
        "Real end button advances to the actual HEAT playable mission")
    _check(not game.session.core_scanned and game.session.elapsed == 0.0,
        "New mission starts from a real untouched scanner objective")
    _check(game.campaign.modifier_applied,
        "Genuine previous choice transfers an opening condition to HEAT")
    _check(game.session.heat > 72.0 and game.session.crew_health >= 100.0,
        "Prior crew priority imposes a real heat penalty and crew support")
    var before_retry_heat: float = game.session.heat
    game._restart()
    _check(is_equal_approx(game.session.heat,before_retry_heat),
        "Retry grants exactly the same modifier, never stacks its bonus")
    var save_path: String = "user://iron_pulse_v9_campaign_scene_ci.json"
    game.checkpoint_path = save_path
    game.checkpoint_store.clear(save_path)
    _check(game.checkpoint_store.save(game._checkpoint_payload(),save_path),
        "True active second chapter plus previous result saved to user's offline slot")
    game.campaign.begin()
    game.session.reset("blackout")
    game.selected_scenario = "blackout"
    _check(game._continue_checkpoint(), "Previous V6 Continue entrypoint restores new V9 campaign data")
    _check(game.campaign.index == 1 and game.campaign.records.size() == 1 and game.campaign.modifier_applied,
        "Campaign stage, history and already-applied modifier roundtrip")
    _check(game.session.scenario_id == "thermal" and game.session.heat > 72.0,
        "Restored real engine keeps actual heat inherited from chapter 1")
    _check(game.checkpoint_store.clear(save_path), "No test campaign state leaked into actual user saves")
    game.session = _completed("thermal","core")
    _check(game.session.won, "Second playable emergency has a real engine victory")
    game._show_end()
    _check(game.campaign.records.size() == 2 and game.end_button.text.contains("СЛЕДУЮЩАЯ"),
        "HEAT victory unlocks AIR and serializes two mission results")
    game._end_action()
    _check(game.selected_scenario == "breach" and game.campaign.index == 2 and not game.session.finished(),
        "Third chapter AIR loads as genuine independent playable mission")
    game.session = _completed("breach","crew")
    game._show_end()
    _check(game.campaign.completed() and game.campaign.records.size() == 3,
        "Third true engine evacuation closes the full three-chapter campaign")
    _check(game.end_stats.text.contains("ФИНАЛ") and game.end_button.text.contains("ПЕРЕИГРАТЬ"),
        "Final localized after-action dossier is visible and gives replay control")
    game._end_action()
    _check(game.campaign.active and game.campaign.index == 0 and game.campaign.records.is_empty(),
        "Replay starts a genuine clean trilogy instead of a fourth phantom mission")
    _check(game.selected_scenario == "blackout" and not game.session.core_scanned,
        "Existing original main controls remain playable after trilogy replay")
    game.queue_free()
    await process_frame
    _finish()
func _finish() -> void:
    if problems.is_empty():
        print("IRON PULSE V9 THREE-ACT SCENE PASS: %d native playable checks" % checks)
        quit(0)
    else:
        for problem in problems:
            push_error("V9 THREE-ACT FAIL: "+problem)
        quit(1)
