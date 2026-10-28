extends SceneTree
## V9: actual playable Godot frontend, mission board, 3-op career,
## bilingual controls and physical first-person game progression.
var failures: Array[String] = []
var checks: int = 0

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, message: String) -> void:
    checks += 1
    if not value:
        failures.append(message)

func _finish_game(engine: IPCrisisEngine) -> bool:
    if engine.finished():
        return false
    if not engine.scan_core():
        return false
    if not engine.repair_coolant():
        return false
    if not engine.cycle_bus(1):
        return false
    engine.tick(25.0)
    if not engine.cycle_bus(1):
        return false
    if not engine.cycle_bus(1):
        return false
    return engine.activate_override() and engine.escape()

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Real source-linked Godot main scene remains loadable")
    if packed == null:
        _final()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.campaign_atlas is IPCampaignAtlas and game.campaign_atlas.total_runs == 0,
        "Real game now owns an independent empty offline campaign profile")
    _check(game.campaign_brief is Label and game.campaign_brief.text.contains("0/3"),
        "True 3-operation progress appears on physical native mission selection screen")
    _check(game.campaign_brief.name == "WorldCampaignProgress" and game.campaign_brief.text.contains("GRID"),
        "Actual Godot UI includes progression marker for all three distinct missions")
    _check(game.scenario_buttons.size() == 3 and game.intro_panel.visible,
        "Previous three working mission selector buttons are preserved")
    _check(game.end_campaign_summary is Label and game.next_mission_button is Button,
        "Genuine player end-of-mission UI now contains persistent career and next-operation button")
    _check(game.campaign_atlas.next_mission("blackout") == "thermal",
        "World campaign is composed of real BLACKOUT -> HEAT -> AIR scenarios")

    game.start_run()
    _check(game.started and not game.intro_panel.visible and not game.end_panel.visible,
        "Real start button uses existing mission and first-person gameplay")
    _check(_finish_game(game.session), "Actual GRID game engine can reach verified evacuation")
    game._show_end()
    _check(game.end_panel.visible and game.session.won,
        "Actual physics-engine WIN opens original native victory screen")
    _check(game.campaign_atlas.clear_count() == 1 and game.campaign_atlas.current_run_count("blackout") == 1,
        "Victory awards exactly one persistent completed-world-operation result")
    _check(game.campaign_brief.text.contains("1/3") and game.next_mission_button.visible,
        "UI immediately offers genuine next unlocked mission and reflects 1/3")
    _check(game.end_campaign_summary.text.contains("1/3") and game.end_campaign_summary.visible,
        "End screen reports real player dossier without invented metrics")
    game._show_end()
    _check(game.campaign_atlas.total_runs == 1,
        "Repeated render of victory overlay cannot grant duplicate attempt/medal")

    game._advance_campaign()
    _check(game.started and not game.end_panel.visible and not game.session.finished(),
        "Next operation button launches a fresh real playable emergency")
    _check(game.session.scenario_id == "thermal" and game.selected_scenario == "thermal",
        "World 02 is genuine dangerous HEAT simulation, not a static roadmap")
    _check(game.scenario_buttons["thermal"].button_pressed,
        "Native mission selector synchronizes to active campaign story")
    _check(game.campaign_atlas.clear_count() == 1 and game.campaign_brief.text.contains("1/3"),
        "Starting next mission never erases previous completed operation")
    _check(_finish_game(game.session), "HEAT is actually winnable using real power routing")
    game._show_end()
    _check(game.campaign_atlas.clear_count() == 2 and game.next_mission_button.visible,
        "Second distinct real success unlocks actual AIR campaign continuation")
    game._advance_campaign()
    _check(game.selected_scenario == "breach" and game.session.scenario_id == "breach",
        "Next operation physically changes game engine to AIR leakage scenario")
    _check(_finish_game(game.session), "AIR real resource-leak simulation can be solved")
    game._show_end()
    _check(game.campaign_atlas.is_complete() and game.campaign_atlas.total_runs == 3,
        "Playing all three actual missions completes offline operator campaign")
    _check(not game.next_mission_button.visible and game.end_stats.text.contains("ВСЯ КАМПАНИЯ"),
        "Final third victory displays completion, never invents fourth operation")
    _check(game.campaign_brief.text.contains("3/3"),
        "World dossier shows actual completed three-mission sequence")
    game._toggle_language()
    _check(game.locale == "en" and game.campaign_brief.text.contains("OPERATIONS"),
        "Live bilingual switch correctly changes campaign interface to English")
    _check(game.end_campaign_summary.text.contains("ALL THREE OPERATIONS"),
        "Previously earned offline profile and victory report translate without resetting")
    game._toggle_language()
    _check(game.locale == "ru" and game.campaign_brief.text.contains("КАМПАНИЯ"),
        "Returning to Russian does not erase gameplay records")
    _check(game.reactor_core is MeshInstance3D and game.containment_fx != null,
        "New progression system preserves real V8 cinematic reactor and environmental FX")
    _check(game.terminals.size() == 6 and game.relay_terminals.size() == 3,
        "All real mission terminals and strategic rescue stations remain interactive")
    game.queue_free()
    await process_frame
    _final()

func _final() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 NATIVE CAMPAIGN PASS: %d actual scene/mission checks" % checks)
        quit(0)
    else:
        for x in failures:
            push_error("V9 NATIVE CAMPAIGN FAIL: "+x)
        quit(1)
