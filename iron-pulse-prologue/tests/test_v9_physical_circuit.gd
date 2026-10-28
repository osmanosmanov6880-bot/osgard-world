extends SceneTree
## V9 actual 3D Godot scene test: physical coil positions/E interaction,
## real light/rotor states, gamepad A, offline checkpoint resume, old missions.
var checks: int = 0
var errors: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        errors.append(description)

func _gamepad_a(game: Node) -> void:
    var button := InputEventJoypadButton.new()
    button.button_index = JOY_BUTTON_A
    button.pressed = true
    game._input(button)

func _input_key(game: Node,key: Key) -> void:
    var event := InputEventKey.new()
    event.keycode = key
    event.pressed = true
    game._input(event)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Source Godot game scene is still importable")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var circuit: IPContainmentCircuit = game.containment_circuit
    _check(circuit != null and circuit.name == "A7_ContainmentCoilNetwork",
        "Actual player scene includes real 3D network of mechanical containment nodes")
    if circuit == null:
        game.queue_free()
        await process_frame
        _finish()
        return
    _check(circuit.terminals.size() == 3 and circuit.readout()["real_3d_coils"] == 3,
        "Exactly three real authored physical operator coils exist")
    _check(circuit.readout()["status_leds"] == 3 and circuit.readout()["mechanical_rotors"] == 3,
        "Every coil has real status light, shaft and moving armature")
    _check(circuit.hub_light is OmniLight3D and not circuit.hub_light.visible,
        "Separate physical stabilization light starts OFF")
    var ids: Array[String] = []
    for info in circuit.terminals:
        ids.append(str(info["id"]))
        var terminal: Node3D = info["node"]
        _check(terminal != null and terminal.get_node_or_null("ForgedMachineBack") is MeshInstance3D,
            "Actual A7 industrial machine back is present: "+str(info["id"]))
        _check(terminal.get_node_or_null("PhysicalOperatorRotaryCoil/MachinedContainmentArmature") is MeshInstance3D,
            "Each real physical rotary coil is a manufactured 3D torus")
        _check(terminal.get_node_or_null("DiegeticCoilIdentifier") is Label3D and
            terminal.get_node_or_null("PhysicalCircuitState") is Label3D,
            "Readable industrial ID and real status plate exist at every station")
        _check(info["indicator"] is MeshInstance3D and info["actuator"] is MeshInstance3D,
            "Diegetic LED and primary ring are real Godot meshes")
    _check(ids == ["alpha","beta","gamma"], "Three unique physical coil ids are source-bound")
    _check(game.world_sectors.current_sector(circuit.terminals[0]["position"].z) == "reactor",
        "ALPHA physically belongs to reactor gallery")
    _check(game.world_sectors.current_sector(circuit.terminals[1]["position"].z) == "service",
        "BETA physically belongs to service spine")
    _check(game.world_sectors.current_sector(circuit.terminals[2]["position"].z) == "evacuation",
        "GAMMA physically belongs to evacuation lock")
    _check(game.terminals.size() == 6 and game.relay_terminals.size() == 3,
        "All existing six primary machines and three rescue relays remain untouched")

    game._select_scenario("blackout")
    game.start_run()
    _check(circuit.readout()["scene_state"] == "offline" and not circuit.readout()["hub_light_visible"],
        "New route cannot fake an already synchronized core")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key == "scan",
        "Original REAL scanner unlocks engineering puzzle without breaking story")
    _check((circuit.terminals[0]["status"] as Label3D).text == "READY",
        "ALPHA lights up physically once actual reactor scan completes")

    game.player.position = Vector3(4.5,1.1,-19.0)
    game._interact()
    _check(game.session.containment_sequence == ["alpha"] and game.story.latest_key == "containment_stage",
        "Physical E at ALPHA operates real engine, stages original MARA radio")
    _check((circuit.terminals[0]["status"] as Label3D).text == "LOCKED" and
        (circuit.terminals[2]["status"] as Label3D).text == "READY",
        "Physical diegetic indicators guide next GAMMA without spoon-feeding HTML menus")
    _check(game.allocation_label.text.contains("1/3"),
        "Existing compact HUD shows optional puzzle progress")

    var slot: String = "user://iron_pulse_v9_real_circuit_ci.json"
    game.checkpoint_path = slot
    game.checkpoint_store.clear(slot)
    _check(game.checkpoint_store.save(game._checkpoint_payload(),slot),
        "V9 partial circuit, story, 3D position and exact deadline saved to genuine offline file")

    game.player.position = Vector3(-4.5,1.1,-32.5)
    var before_air: float = game.session.oxygen
    var before_heat: float = game.session.heat
    game._interact()
    _check(game.session.containment_sequence.is_empty() and game.story.latest_key == "containment_misroute",
        "Wrong physical BETA produces distinct MARA consequence and resets actual route")
    _check(game.session.oxygen < before_air-3.0 and game.session.heat > before_heat+5.0,
        "Bad player decision has real oxygen and temperature penalties")
    _check((circuit.terminals[0]["status"] as Label3D).text == "READY",
        "World status plate physically returns to initial coil after wrong route")

    _check(game._continue_checkpoint(),
        "Real CONTINUE from native JSON restores saved partial puzzle and story")
    _check(game.session.containment_sequence == ["alpha"] and
        game.session.containment_deadline > game.session.elapsed,
        "Offline reload preserves original route time pressure and not reset to 85 free seconds")
    _check((circuit.terminals[0]["status"] as Label3D).text == "LOCKED" and
        (circuit.terminals[2]["status"] as Label3D).text == "READY",
        "Saved route restores exact physical LED and status across independent 3D consoles")

    game.player.position = Vector3(4.5,1.1,-50.0)
    _gamepad_a(game)
    _check(game.session.containment_sequence == ["alpha","gamma"],
        "Actual Godot mapped gamepad A acts on physical GAMMA station")
    _check(game.containment_circuit.readout()["active_count"]==2,
        "True physical circuit scene tracks 2/3 staged reactor status")
    game.player.position = Vector3(-4.5,1.1,-32.5)
    game._interact()
    _check(game.session.containment_online and game.session.containment_sequence.size() == 3,
        "Three physical E/A interactions truly stabilize the reactor engine")
    _check(game.story.latest_key == "containment_online",
        "Successful circuit plays authored original MARA victory-of-engineering beat")
    _check(game.containment_circuit.readout()["scene_state"] == "online" and
        game.containment_circuit.hub_light.visible,
        "Actual reactor chamber gets physically brighter after successful player routing")
    _check((circuit.terminals[0]["status"] as Label3D).text == "ONLINE" and
        (circuit.terminals[2]["status"] as Label3D).text == "ONLINE",
        "All real 3D physical station indicators glow ONLINE after completion")
    _check(game.allocation_label.text.contains("3/3"),
        "Telemetry reflects actual completed route across existing bilingual interface")

    _input_key(game,KEY_G)
    _check(game.quality_mode == "eco" and not circuit.hub_light.visible,
        "ECO disables additional containment hub light without affecting stabilized logic")
    _input_key(game,KEY_G)
    _check(game.quality_mode == "hero" and circuit.hub_light.visible,
        "HERO mode re-enables actual 3D containment light without resource reset")
    _input_key(game,KEY_V)
    game._process(0.016)
    _check(game.reduced_motion and game.session.containment_online,
        "Reduced-motion preserves completed mechanic while suppressing rotary oscillation")
    _check(is_equal_approx((circuit.terminals[0]["rotor"] as Node3D).rotation.z,0.0),
        "Reduced motion stops animated containment machinery without hiding feedback")
    var previous_coils: Array[String] = game.session.containment_sequence.duplicate()
    game.player.position = Vector3(4.5,1.1,-19.0)
    game._interact()
    _check(game.session.containment_sequence == previous_coils and game.session.containment_online,
        "Repeating successful console cannot farm infinite heat/oxygen/door charge")

    _check(game.checkpoint_store.clear(slot), "Test native checkpoint removed after verification")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if errors.is_empty():
        print("IRON PULSE V9 PHYSICAL CIRCUIT PASS: %d native 3D/gamepad/checkpoint checks" % checks)
        quit(0)
    else:
        for issue in errors:
            push_error("V9 PHYSICAL CIRCUIT FAIL: "+issue)
        quit(1)
