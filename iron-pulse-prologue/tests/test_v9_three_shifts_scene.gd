extends SceneTree
## V9 end-to-end native Godot UI -> physical first act -> real 3 scenario
## power-puzzle victories -> in-between file save -> final story and replay.
var checks: int = 0
var failed: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(result: bool,label: String) -> void:
    checks += 1
    if not result:
        failed.append(label)

func _solve_real_engine(game: Node, priority: String, relay: String) -> bool:
    var engine: IPCrisisEngine = game.session
    if not engine.core_scanned and not engine.scan_core():
        return false
    if priority != "" and not engine.choose_priority(priority):
        return false
    if not engine.repair_coolant():
        return false
    if relay != "" and not engine.activate_relay(relay):
        return false
    if not engine.cycle_bus(1):
        return false
    engine.tick(24.0)
    if engine.finished():
        return false
    if not engine.cycle_bus(1) or not engine.cycle_bus(1):
        return false
    return engine.activate_override() and engine.escape()

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Actual cross-platform Godot level imports")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var custom_slot: String = "user://iron_pulse_v9_three_shifts_native_ci.json"
    game.checkpoint_path = custom_slot
    game.checkpoint_store.clear(custom_slot)
    _check(game.campaign_button != null and game.campaign_button.name == "ThreeShiftsCampaignButton",
        "Real intro contains dedicated accessible three-chapter campaign button")
    _check(game.campaign_button.text.contains("КАМПАНИЯ") and game.campaign_button.focus_mode == Control.FOCUS_ALL,
        "Offline RU campaign choice is real, visible and keyboard-accessible")
    _check(game.campaign_button.visible and not game.started and not game.campaign.active,
        "Stand-alone mode remains the default; trilogy explicitly opt-in")
    _check(game.scenario_buttons.size() == 3 and game.intro_button.visible,
        "All three independent original emergencies remain selectable")
    game.campaign_button.pressed.emit()
    _check(game.campaign.active and game.started and game.session.scenario_id == "blackout",
        "Real Godot campaign button starts actual GRID shift 1")
    _check(game.story.latest_key == "campaign_chapter_1" and game.story.latest("en")["text"].contains("three shifts"),
        "Real audio/radio system begins an authored EN/RU continuous narrative")
    _check(game.campaign.stage_number() == 1 and game.subtitle_label.text.contains("1/3"),
        "Current chapter appears in playable HUD, not just internal metadata")
    _check(game.intro_panel.visible == false and game.session.objective_id() == "scan",
        "Actual player scene starts at first scanner, normal camera and controls")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key == "scan",
        "Real physical E-style scanner is still used inside campaign")

    _check(_solve_real_engine(game,"crew","medbay") and game.session.won,
        "First story chapter solvable via actual simulated power routing")
    game._show_end()
    _check(game.campaign.history.size() == 1 and game.campaign.stage_scenario() == "thermal",
        "First win unlocks new challenge without returning to disconnected menu")
    _check(game.end_panel.visible and game.end_button.text.contains("СЛЕДУЮЩАЯ"),
        "End panel becomes NEXT CHAPTER instead of old one-level restart")
    _check(game.end_stats.text.contains("ГЛАВА") and game.end_stats.text.contains("ОЧКИ"),
        "Campaign has a real cumulative game score and progress summary")
    _check(game._save_campaign_intermission() and game.checkpoint_store.load_checkpoint(custom_slot).has("campaign_v9"),
        "A real atomically written JSON checkpoint points to the upcoming stage")
    var stored: Dictionary = game.checkpoint_store.load_checkpoint(custom_slot)
    _check(stored["scenario"] == "thermal" and stored["engine"]["scenario"] == "thermal",
        "Intermission saves a future PLAYABLE scenario, never the old finished chapter")
    _check(stored["story"]["scenario"] == "thermal" and stored["campaign_v9"]["chapter"] == 1,
        "Real offline checkpoint carries next chapter radio and completed history")
    game.campaign.reset()
    game.session.reset("breach")
    game.story.reset("breach")
    game.selected_scenario = "breach"
    _check(game._continue_checkpoint() and game.campaign.active,
        "Continue button's actual loading logic restores previous chapter")
    _check(game.campaign.chapter == 1 and game.session.scenario_id == "thermal",
        "Resume opens the correct second emergency with intact campaign history")
    _check(game.campaign.history[0]["priority"] == "crew" and game.campaign.history[0]["relays"].has("medbay"),
        "Prior crew-first/medbay choices survive real filesystem restoration")
    _check(game.story.latest_key == "campaign_chapter_2",
        "Restored radio introduces consequences of the previous shift")
    _check(game.end_panel.visible == false and game.session.objective_id() == "scan",
        "Resumed intermission is PLAYABLE, not a stuck completed mission screen")
    var fresh := IPCrisisEngine.new()
    fresh.reset("thermal")
    _check(game.session.heat != fresh.heat or game.session.oxygen != fresh.oxygen,
        "Continuing from disk recreates actual inherited resource changes")
    _check(game.containment_fx != null and game.reactor_atrium != null,
        "Cinematic V8.6 reactor, pressure vents and physical gameplay remain present")

    _check(_solve_real_engine(game,"core","quench") and game.session.won,
        "Second playable HEAT scenario can be solved with thermal shielding")
    game._show_end()
    _check(game.campaign.chapter == 2 and game.campaign.history.size() == 2,
        "Second victory preserves BOTH successful operations")
    game.end_button.pressed.emit()
    _check(game.started and game.session.scenario_id == "breach" and game.campaign.stage_number() == 3,
        "Real on-screen NEXT button enters third oxygen-breach operation")
    _check(game.story.latest_key == "campaign_chapter_3" and not game.end_panel.visible,
        "Final chapter has original MARA introduction and working objective HUD")
    _check(game.player.position.distance_to(Vector3(0,1.1,2.0)) < 0.01,
        "Real player, camera and airlock reset to usable third-stage spawn")
    _check(_solve_real_engine(game,"crew","uplink") and game.session.won,
        "Third real AIR evacuation and crew rescue are earnable")
    game._show_end()
    _check(game.campaign.complete() and game.campaign.history.size() == 3,
        "Real victory screen credits all 3 chapters exactly once")
    _check(game.story.latest_key.begins_with("campaign_final_") and game.campaign.ending != "",
        "Player choices trigger a non-placeholder authored final MARA broadcast")
    _check(game.end_stats.text.contains("3/3") and game.end_stats.text.contains("ОЧКИ"),
        "Full trilogy score/finale is shown in actual 3D game's end overlay")
    _check(game.end_button.text.contains("ЗАНОВО"),
        "Final action offers full campaign replay instead of impossible fourth chapter")
    game.end_button.pressed.emit()
    _check(game.campaign.stage_number() == 1 and game.campaign.history.is_empty() and
        game.session.scenario_id == "blackout",
        "Replay resets all three chapter records, never duplicates medals")
    _check(game.session.objective_id() == "scan" and game.started,
        "Replayed campaign starts the real first operation")
    game.campaign.reset()
    game.session.reset("thermal")
    game.story.reset("thermal")
    game.selected_scenario = "thermal"
    var legacy: Dictionary = game._checkpoint_payload()
    legacy.erase("campaign_v9")
    _check(game.checkpoint_store.save(legacy,custom_slot),
        "V6-style checkpoint can still be written without new campaign fields")
    game.campaign.begin()
    _check(game._continue_checkpoint() and not game.campaign.active and game.session.scenario_id == "thermal",
        "Legacy V6/V8 single-mission saves open with NO accidental campaign migration")
    _check(game.checkpoint_store.clear(custom_slot),
        "Native three-shift QA cleans up its actual temporary local save")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failed.is_empty():
        print("IRON PULSE V9 REAL CAMPAIGN UI PASS: %d Godot scene, gameplay and resume checks" % checks)
        quit(0)
    else:
        for issue in failed:
            push_error("V9 SCENE CAMPAIGN FAIL: "+issue)
        quit(1)
