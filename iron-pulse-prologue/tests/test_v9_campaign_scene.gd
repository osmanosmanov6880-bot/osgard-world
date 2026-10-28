extends SceneTree
## V9 real native scene acceptance — menu, 3 physical operation routes,
## end-card progression, actual gameplay controls, disk checkpoint resume.
var checks: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        errors.append(label)

func _at(game: Node,location: Vector3) -> void:
    game.player.position = location

func _e(game: Node,location: Vector3) -> void:
    _at(game,location)
    game._interact()

func _play_physical_mission(game: Node) -> bool:
    _e(game,Vector3(-3.0,1.1,-15.5))
    if not game.session.core_scanned:
        return false
    _e(game,Vector3(-4.2,1.1,-23.0))
    if game.session.relays_activated != ["medbay"]:
        return false
    game._choose_priority("crew")
    _e(game,Vector3(3.0,1.1,-28.0))
    if not game.session.coolant_repaired:
        return false
    _e(game,Vector3(3.0,1.1,-36.0))
    if game.session.bus_b != "door":
        return false
    game.session.tick(24.0)
    _e(game,Vector3(3.0,1.1,-36.0))
    _e(game,Vector3(-3.0,1.1,-36.0))
    _e(game,Vector3(0.0,1.1,-46.0))
    if not game.session.override_set:
        return false
    _e(game,Vector3(0.0,1.1,-56.0))
    return game.session.won and game.end_panel.visible

func _run() -> void:
    var real_scene: PackedScene = load("res://Main.tscn")
    _check(real_scene != null, "Actual native Godot player scene loads with campaign extension")
    if real_scene == null:
        _finish()
        return
    var game = real_scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var temp: String = "user://iron_pulse_v9_scene_campaign_qa.json"
    game.checkpoint_path = temp
    game.checkpoint_store.clear(temp)
    _check(not game.campaign_enabled and game.selected_scenario=="blackout",
        "All original standalone modes remain available by default")
    _check(game.campaign_button != null and game.campaign_button.name=="ThreeActCampaignSwitch",
        "Campaign is a genuine large native Godot UI button, not a demo placeholder")
    game._toggle_campaign_mode()
    _check(game.campaign_enabled and game.selected_scenario=="blackout" and game.campaign_button.button_pressed,
        "Selecting campaign enables real GRID chapter and native selected-button state")
    _check(game.scenario_buttons["thermal"].disabled and game.scenario_buttons["breach"].disabled,
        "Campaign blocks skipping HEAT and AIR through ordinary scenario buttons")
    game._select_scenario("breach")
    _check(game.selected_scenario=="blackout","Cannot bypass chronological stage by calling legacy selector")
    _check(game.scenario_brief.text.contains("1/3"),
        "Native intro clearly displays upcoming first operation")
    game.start_run()
    _check(game.started and not game.intro_panel.visible and game.session.objective_id()=="scan",
        "Campaign starts the REAL first-person scanner objective")
    _check(_play_physical_mission(game),
        "GRID: genuine 3D E interactions plus real two-bus power/override/exit win")
    _check(game.campaign.wins()==1 and game.campaign.next_scenario()=="thermal" and not game.campaign.finished(),
        "Real exit screen unlocks exactly stage 2 with no fake progress")
    _check(game.end_button.text == game._copy("campaign_next"),
        "Victory screen offers actual next mission, not another copy of current puzzle")
    _check(game.campaign.ending_id()=="", "No epilogue before full three-mission completion")
    game._restart()
    _check(game.selected_scenario=="thermal" and game.session.scenario_id=="thermal",
        "Next chapter starts genuine HEAT crisis in actual Godot game")
    _check(game.session.crew_health < 100.0 and game.campaign.wins()==1,
        "GRID crew casualties physically carry into the next episode")

    var checkpoint: Dictionary = game._checkpoint_payload()
    _check(checkpoint["schema"]=="IRON_PULSE_CAMPAIGN_V6" and checkpoint["campaign_enabled"]==true,
        "V6 save wrapper remains format-compatible while carrying V9 campaign metadata")
    _check(game.checkpoint_store.save(checkpoint,temp),
        "Actual V9 chapter checkpoint saved by existing SHA-checked offline store")
    game.session.reset("breach")
    game.story.reset("breach")
    game.selected_scenario = "breach"
    _check(game._continue_checkpoint() and game.session.scenario_id=="thermal",
        "Real Continue button pathway restores stage 2 from local JSON on disk")
    _check(game.campaign_enabled and game.campaign.wins()==1 and game.campaign.next_scenario()=="thermal",
        "Continue preserves chronological campaign progress and recorded GRID result")
    _check(_play_physical_mission(game),
        "HEAT: full physical mission including 15s precision repair and recurring heat wave wins")
    _check(game.campaign.wins()==2 and game.campaign.next_scenario()=="breach",
        "HEAT win unlocks only AIR; earlier chapters remain in ledger")
    game._restart()
    _check(game.selected_scenario=="breach" and game.session.scenario_id=="breach",
        "Third chapter begins real oxygen-leak simulation")
    _check(game.session.oxygen < 100.0 and game.campaign.wins()==2,
        "AIR receives bounded oxygen carryover, not a decorative score number")
    _check(_play_physical_mission(game),
        "AIR: full physical seal, charge and evacuation beats work with inherited resources")
    _check(game.campaign.finished() and game.campaign.wins()==3,
        "Three physical completed emergencies finish actual integrated campaign")
    _check(game.end_button.text==game._copy("campaign_replay") and game.end_stats.text.contains("3/3"),
        "Final native game end card shows earned full campaign rank")
    _check(game.end_stats.text.contains(game.campaign.ending_text("ru")),
        "Authored branching narrative epilogue actually appears on the final game screen")
    _check(game.campaign.ending_text("en").length()>30,
        "Bilingual ending text is available to international players")

    game._restart()
    _check(game.campaign.wins()==0 and game.selected_scenario=="blackout",
        "Only explicitly choosing Replay on final end card resets campaign chronology")
    _check(game.started and not game.session.finished() and game.session.objective_id()=="scan",
        "Full replay produces a fresh interactive operation, not a dead menu")
    _check(game.checkpoint_store.clear(temp),"Test save is removed, normal user save remains untouched")
    game.queue_free()
    await process_frame

    # Previously tested V6 files have no campaign keys. Loading them must
    # still work without granting or rewriting a V9 mission.
    var legacy_game = real_scene.instantiate()
    root.add_child(legacy_game)
    await process_frame
    await process_frame
    var old: String = "user://iron_pulse_v9_legacy_scene_qa.json"
    legacy_game.checkpoint_path = old
    legacy_game.checkpoint_store.clear(old)
    legacy_game._select_scenario("thermal")
    legacy_game.start_run()
    _e(legacy_game,Vector3(-3.0,1.1,-15.5))
    var legacy: Dictionary = legacy_game._checkpoint_payload()
    legacy.erase("campaign")
    legacy.erase("campaign_enabled")
    _check(legacy_game.checkpoint_store.save(legacy,old),
        "An original schema-V6 checkpoint can still be written without V9 fields")
    legacy_game.session.reset("blackout")
    legacy_game.selected_scenario = "blackout"
    _check(legacy_game._continue_checkpoint() and legacy_game.session.scenario_id=="thermal",
        "Old V6 checkpoint resumes its original independent HEAT scenario")
    _check(not legacy_game.campaign_enabled and legacy_game.campaign.wins()==0,
        "V6 migration never forces a user into the new multi-mission campaign")
    _check(legacy_game.checkpoint_store.clear(old),"Legacy save test leaves no extra file")
    legacy_game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("IRON PULSE V9 NATIVE CAMPAIGN PASS: %d actual scene/control/save checks" % checks)
        quit(0)
    else:
        for error in errors:
            push_error("V9 SCENE FAIL: "+error)
        quit(1)
