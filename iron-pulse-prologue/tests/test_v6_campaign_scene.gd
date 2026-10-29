extends SceneTree
## V6 tests the ACTUAL playable 3D scene: choice keys, radio HUD, journal and continue.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures.append(description)

func _key(game: Node, code: Key) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.keycode = code
    game._input(event)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Actual main Godot scene imports")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.story is IPStoryDirector and game.checkpoint_store is IPCheckpointStore,
        "Gameplay contains real authored radio and offline checkpoint classes")
    _check(game.radio_panel is PanelContainer and game.journal_panel is PanelContainer,
        "Real in-game subtitles and transcript overlays are Controls, not fake HTML")
    _check(game.priority_panel is PanelContainer and game.crew_priority_button is Button and game.core_priority_button is Button,
        "Player choice uses real Godot buttons for controller and touch")
    _check(game.continue_button is Button and not game.continue_button.visible,
        "No phantom checkpoint appears in the isolated headless test")
    _check(game.story.latest_key == "arrival_blackout", "Original opening dialogue is staged from actual game")
    game._select_scenario("thermal")
    _check(game.story.latest_key == "arrival_thermal", "Scenario selection changes real radio introduction")
    game.start_run()
    game._refresh_hud()
    _check(game.started and game.radio_panel.visible and game.radio_dialogue.text.contains("МАРА"),
        "Playing shows in-world radio transmission with visible RU subtitles")
    _check(not game.priority_panel.visible, "Cannot choose crew/core before scanning the reactor")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key == "scan",
        "Real physical scanner triggers authored plot and choice dilemma")
    _check(game.priority_panel.visible, "Player gets actual two-action control after scanning")
    _key(game,KEY_1)
    _check(game.session.priority_id == "crew" and game.story.latest_key == "priority_crew",
        "Actual keyboard 1 chooses crew and drives persistent authored narrative")
    _check(game.session.elapsed >= 7.99 and game.session.heat > 72.0,
        "Moral choice changes actual deterministic physical state")
    _check(not game.priority_panel.visible, "One-time irreversible decision controls disappear")
    _key(game,KEY_J)
    _check(game.journal_panel.visible and game.paused, "Actual J key opens archived radio transcript and pauses world")
    _check(game.journal_text.text.contains("МАРА") and game.journal_text.text.contains("экипаж"),
        "Transcript retains the narrative's own dialogue")
    _key(game,KEY_ESCAPE)
    _check(not game.journal_panel.visible and not game.paused, "Escape resumes from radio journal")
    game._toggle_language()
    _check(game.locale == "en" and game.radio_dialogue.text.contains("MARA"),
        "Radio and dialogue transcript update to full English localization")
    _check(game.journal_text.text.contains("MARA"), "Archive itself translates without losing story state")

    var slot: String = "user://iron_pulse_v6_scene_ci_test.json"
    game.checkpoint_path = slot
    game.checkpoint_store.clear(slot)
    var intended: Dictionary = game._checkpoint_payload()
    _check(intended["engine"]["priority"] == "crew", "Exact in-game save includes active player's meaningful choice")
    _check(game.checkpoint_store.save(intended,slot), "Scene state can be saved offline to an isolated test slot")
    game.session.reset("breach")
    game.story.reset("breach")
    game.selected_scenario = "breach"
    game.player.position = Vector3(0,1.1,2.0)
    _check(game._continue_checkpoint(), "Real Continue handler reads and validates offline game+story payload")
    _check(game.session.scenario_id == "thermal" and game.story.scenario == "thermal",
        "Continue recovered both actual gameplay and radio scenario")
    _check(game.session.priority_id == "crew" and game.story.latest_key == "priority_crew",
        "Real Continue recovers irreversible player choice and story consequence")
    _check(game.locale == "en" and absf(game.player.position.z+15.5)<0.1,
        "Continue restores localization and physical 3D position")
    _check(not game.intro_panel.visible and game.started, "Continue resumes gameplay rather than just loading a menu")
    _check(game.story.journal.size() >= 3, "Narrative history survives actual disk roundtrip")
    var tampered: Dictionary = intended.duplicate(true)
    tampered["story"]["scenario"] = "breach"
    _check(game.checkpoint_store.save(tampered,slot), "Can create a malicious cross-scenario QA fixture")
    _check(not game._continue_checkpoint(), "Corrupted cross-scenario save cannot enter the world")
    _check(game.session.scenario_id == "thermal", "Rejected save never partially changes the active run")
    _check(game.checkpoint_store.clear(slot), "QA fixture deleted after test")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V6 REAL CAMPAIGN PASS: %d Godot scene assertions" % checks)
        quit(0)
    else:
        for problem in failures:
            push_error("V6 CAMPAIGN FAIL: " + problem)
        quit(1)
