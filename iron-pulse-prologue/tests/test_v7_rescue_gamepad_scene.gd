extends SceneTree
## Actual Godot 3D relay geometry, native E/gamepad controls and persistent state.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _joy(game: Node, button: JoyButton) -> void:
    var event := InputEventJoypadButton.new()
    event.button_index = button
    event.pressed = true
    game._input(event)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "The real Godot scene still loads")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.relay_terminals.size() == 3, "Three real relay stations exist in the native 3D scene")
    for info in game.relay_terminals:
        var node: Node3D = info["node"]
        _check(node != null and node.get_node_or_null("OptionalRelayName") is Label3D,
            "Relay has physically authored sign and interactive scene node")
        _check(info["indicator"] is MeshInstance3D, "Each rescue station has real 3D status light")
    _check(game.world_sectors.current_sector(game.relay_terminals[0]["position"].z) == "reactor",
        "Medical relay sits in the reactor gallery")
    _check(game.world_sectors.current_sector(game.relay_terminals[1]["position"].z) == "service",
        "Heat suppressor sits in the service spine")
    _check(game.world_sectors.current_sector(game.relay_terminals[2]["position"].z) == "evacuation",
        "Uplink sits in the evacuation lock")
    _check(game.session.relays_activated.is_empty() and game._relay_ready_material != null,
        "All three resources start unspent and genuinely lit")

    game._select_scenario("thermal")
    game.start_run()
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned, "Actual physical scanner unlocks the optional rescue network")

    game.player.position = Vector3(-4.2,1.1,-23.0)
    game._interact()
    _check(game.session.relays_activated == ["medbay"] and game.story.latest_key == "relay_medbay",
        "Real E at physical medical station performs game action and authored radio beat")
    _check(game.relay_terminals[0]["indicator"].material_override == game._relay_done_material,
        "Activated medical relay visually changes 3D status")

    game.player.position = Vector3(4.2,1.1,-39.5)
    _joy(game,JOY_BUTTON_A)
    _check(game.session.relays_activated == ["medbay","quench"],
        "Actual Godot-mapped gamepad A event interacts with second physical relay")
    _check(game.session.thermal_shield and game.story.latest_key == "relay_quench",
        "Second real relay changes ongoing thermal game behavior and story")
    _check(game.allocation_label.text.contains("2/2"), "Rescue limit appears in localized HUD")
    _check(game.relay_terminals[1]["indicator"].material_override == game._relay_done_material,
        "Second console visually records successful rescue strategy")

    game.player.position = Vector3(-4.2,1.1,-53.0)
    var previous_faults: int = game.session.faults
    game._interact()
    _check(game.session.relays_activated.size() == 2 and game.session.faults == previous_faults+1,
        "Third physical station is correctly denied after two choices")
    _check(game.story.latest_key == "relay_budget",
        "MARA explicitly explains locked third intervention")

    _joy(game,JOY_BUTTON_DPAD_DOWN)
    _check(game.session.priority_id == "core" and game.story.latest_key == "priority_core",
        "Mapped controller D-pad can make same consequential choice as keyboard/touch")
    _joy(game,JOY_BUTTON_B)
    _check(game.journal_panel.visible and game.paused, "Gamepad B opens real offline dialogue journal")
    _joy(game,JOY_BUTTON_B)
    _check(not game.journal_panel.visible and not game.paused, "Gamepad B closes journal and resumes world")
    _joy(game,JOY_BUTTON_START)
    _check(game.paused and game.pause_panel.visible, "Gamepad START pauses simulation")
    _joy(game,JOY_BUTTON_START)
    _check(not game.paused and not game.pause_panel.visible, "Gamepad START resumes the same game")

    var slot: String = "user://iron_pulse_v7_relay_scene_ci.json"
    game.checkpoint_path = slot
    game.checkpoint_store.clear(slot)
    _check(game.checkpoint_store.save(game._checkpoint_payload(),slot),
        "Two chosen relays, moral decision and player position are written to genuine offline save")
    game.session.reset("breach")
    game.story.reset("breach")
    game.selected_scenario = "breach"
    game.player.position = Vector3(0,1.1,2.0)
    _check(game._continue_checkpoint(), "Real V6 Continue entrypoint restores richer V7 checkpoint")
    _check(game.session.scenario_id == "thermal" and game.session.relays_activated == ["medbay","quench"],
        "Loading correctly recovers scenario and exactly two previously used relays")
    _check(game.session.thermal_shield and game.session.priority_id == "core",
        "Loading preserves thermal resistance and consequential moral choice")
    _check(game.relay_terminals[0]["indicator"].material_override == game._relay_done_material,
        "Reloading restores physical status of activated rescue stations")
    _check(game.checkpoint_store.clear(slot), "Native test save cleaned after acceptance")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V7 PHYSICAL GAMEPAD PASS: %d native scene checks" % checks)
        quit(0)
    else:
        for problem in failures:
            push_error("V7 NATIVE GAMEPAD FAIL: "+problem)
        quit(1)
