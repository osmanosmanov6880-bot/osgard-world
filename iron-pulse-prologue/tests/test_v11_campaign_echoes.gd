extends SceneTree
## V11 native authored radio, 3D world-state consequences, physical dossier.
var checks: int = 0
var failed: Array[String] = []
func _initialize() -> void:
    call_deferred("_run")
func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failed.append(label)
func _winner(scenario: String,priority: String) -> IPCrisisEngine:
    var e := IPCrisisEngine.new()
    e.reset(scenario)
    e.scan_core()
    e.choose_priority(priority)
    e.repair_coolant()
    e.cycle_bus(1)
    e.tick(25.0)
    e.cycle_bus(1)
    e.cycle_bus(1)
    e.activate_override()
    e.escape()
    return e
func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null,"Original scene still imports")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var wall: IPCampaignEchoes = game.campaign_echoes
    _check(wall != null and wall.name == "A7_CampaignMemoryWall",
        "Actual chapter result sculpture is part of reactor gallery")
    _check(wall.readout()["physical_wall"] and wall.readout()["panel_count"] == 3,
        "Three permanent 3D physical plaques correspond to three playable emergencies")
    _check(not wall.readout()["visible"] and wall.readout()["verified_victories"] == 0,
        "Standalone users see no fabricated campaign trophy")
    _check(wall.record_plate.global_position.x < -5.0 and wall.record_plate.global_position.z > -9.0,
        "In-world memory panel is placed off the existing player path")
    var story := IPStoryDirector.new()
    story.reset("thermal")
    _check(story.on_campaign_carryover("crew") and story.latest_key == "carry_crew",
        "MARA has authored crew-priority consequence on next chapter")
    _check(story.latest("en")["text"].contains("Last shift") and story.latest("ru")["text"].contains("Предыдущая"),
        "Carryover narration is authored in both English and Russian")
    _check(not story.on_campaign_carryover("crew"), "Radio consequence cannot spam identical lines")
    var stored: Dictionary = story.checkpoint()
    var story_again := IPStoryDirector.new()
    _check(story_again.restore(stored) and story_again.latest_key == "carry_crew",
        "Original V6 local story checkpoint can restore newly authored beat")
    game._start_campaign()
    _check(wall.readout()["visible"] and wall.readout()["verified_victories"] == 0,
        "Physical memory wall becomes available only for opt-in campaign")
    _check(str(wall.readout()["entries"][0]).contains("В ПРОЦЕССЕ"),
        "First operation appears in progress, not falsely completed")
    game.session = _winner("blackout","crew")
    _check(game.session.won,"Real GRID win can trigger in-world memory")
    game._show_end()
    _check(wall.readout()["verified_victories"] == 1,
        "First engine evacuation creates one, not three, 3D achievement plaques")
    _check(str(wall.readout()["entries"][0]).contains("CREW"),
        "Physical artifact identifies actual past crew-first decision")
    _check(str(wall.readout()["entries"][1]).contains("ЗАКРЫТО"),
        "Locked HEAT is not misrepresented as completed")
    game._end_action()
    _check(game.story.latest_key == "carry_crew",
        "At start of actual HEAT game MARA audibly announces real prior-choice cost")
    _check(wall.readout()["verified_victories"] == 1 and str(wall.readout()["entries"][1]).contains("В ПРОЦЕССЕ"),
        "HEAT becomes physically active, GRID result retained")
    _check(game.session.heat > 72.0,
        "Story of previous GRID heat penalty corresponds to REAL reactor heat")
    game.session = _winner("thermal","core")
    game._show_end()
    game._end_action()
    _check(game.story.latest_key == "carry_core" and game.session.scenario_id == "breach",
        "AIR chapter receives authored core-first transmission from genuine prior result")
    _check(wall.readout()["verified_victories"] == 2,
        "Two physical certificates now show two distinct verified engine outcomes")
    game._toggle_language()
    _check(wall.readout()["locale"] == "en" and str(wall.readout()["entries"][2]).contains("ACTIVE"),
        "World-space memory art follows existing RU/EN language toggle")
    game.session = _winner("breach","crew")
    game._show_end()
    _check(wall.readout()["verified_victories"] == 3 and wall.readout()["ending"] == "THREE MISSIONS COMPLETE",
        "Final triple evacuation transforms all three original industrial plaques")
    _check(str(wall.readout()["entries"][2]).contains("CREW"),
        "Final plaque is grounded in third original scenario's actual player choice")
    game.queue_free()
    await process_frame
    _finish()
func _finish() -> void:
    if failed.is_empty():
        print("IRON PULSE V11 CONSEQUENCES PASS: %d native audio/story/art checks" % checks)
        quit(0)
    else:
        for issue in failed:
            push_error("V11 CONSEQUENCE FAIL: "+issue)
        quit(1)
