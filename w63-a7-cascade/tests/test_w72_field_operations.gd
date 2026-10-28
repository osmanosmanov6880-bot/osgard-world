extends SceneTree
## W72: three real spatial manipulation mechanics, deterministic source-bound
## physical 3D state, unchanged actual A7CascadeCore six-cycle win/loss.
## Legacy W71 mission must remain valid when advanced mode isn't enabled.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, note: String) -> void:
    checks += 1
    if not ok:
        failures.append(note)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    _check(scene != null, "Original real 3D Godot A7 scene still imports")
    if scene == null:
        _finish()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    var player: A7FirstPersonOperator = stage.first_person
    var mission: A7SpatialMission = stage.spatial_mission
    var field: A7FieldOperations = stage.field_operations
    _check(stage != null and player != null and mission != null and field != null,
        "Existing original 3D world, player, spatial mission and new mechanics all exist")
    if field == null:
        _finish()
        return
    var proof: Dictionary = field.qa_readout()
    _check(proof["schema"] == "LAST_FRONTIER_W72_THREE_ORIGINAL_PHYSICAL_FIELD_MECHANICS_V1",
        "Independent authored real 3D three-mechanic acceptance schema")
    _check(int(proof["real_world_meshes"]) >= 23,
        "Twenty-three original separate real 3D mechanical meshes exist")
    _check(proof["real_3d_valve_rotor"],
        "Genuine 8-detent Godot Node3D valve with rotating hardware")
    _check(proof["real_3d_relay_switches"] == 3,
        "Actual three independent movable industrial relay switches")
    _check(proof["real_3d_sync_circuits"] == 3,
        "Actual three genuine Godot toroidal synchronization contacts")
    _check(proof["true_world_3d_labels"],
        "Readout is native world-space Label3D, not an HTML overlay")
    _check(proof["native_real_lights"] == 2,
        "Original physical reactor/relay lights mounted")
    _check(not proof["active"] and not field.active_visuals.visible,
        "W70/W71 default game has no extra cognitive clutter")
    _check(not proof["gameplay_authority"],
        "Field ops can never control original A7CascadeCore actions")
    _check(not proof["actual_machine_network_connected"],
        "Actual industrial equipment never connected")
    _check(not proof["human_aaa_art_approval"],
        "Engineering pass never becomes false AAA art signoff")
    _check(ui.field_start_button != null and ui.field_buttons.size() == 8,
        "Native interface has an explicit advanced mission and 8 mechanic buttons")
    _check(ui.field_label != null and not ui.field_label.visible,
        "Existing W71 HUD remains uncluttered by default")

    var original: Dictionary = ui.model.snapshot()
    # Preserve legacy W71 mode after adding advanced puzzle.
    ui.mission_button.emit_signal("pressed")
    _check(mission.active and not mission.extended_mode and not field.enabled,
        "Original W71 normal path starts without any added hard-mode requirements")
    ui.pilot_button.emit_signal("pressed")
    player.body.position = Vector3(4.10, 1.33, 2.14)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 1 and ui.model.snapshot() == original,
        "Original W71 close-reactor inspection works without valve puzzle")
    ui.restart_button.emit_signal("pressed")
    _check(not mission.active and not field.enabled and mission.phase == 0,
        "Reset restores true normal-game baseline, not fake hard-mode state")
    _check((ui.model.snapshot()["history"] as Array).is_empty(),
        "Legacy mode check leaves original A7 shift intact")

    # Extended mode requires genuine proximity for every actuator.
    ui.field_start_button.emit_signal("pressed")
    _check(mission.active and mission.extended_mode and field.enabled,
        "Extended mission opt-in activates physical mechanisms")
    _check(field.active_visuals.visible,
        "Two real 3D machine stations become visible when intentionally enabled")
    _check(ui.field_valve_controls.visible and
        not ui.field_relay_controls.visible and
        not ui.field_sync_controls.visible,
        "Premium native panel shows only currently relevant valve controls")
    _check(field.valve_target == 6 and field.valve_index == 0,
        "Valve target is derived from actual original heat 62 and pressure 48")
    _check(field.true_game_metrics["heat"] == 62 and
        field.true_game_metrics["energy"] == 85,
        "Independent field target reads actual A7 rules engine state")
    _check(field.instructions("ru").contains("6") and
        field.instructions("en").contains("CORE"),
        "Actual interactive target is readable in RU/EN")
    var before_game: Dictionary = ui.model.snapshot()
    player.body.position = A7FirstPersonOperator.START_POSITION
    _check(not field.rotate_valve(1, player),
        "Physical dial doesn't work remotely when player is not at reactor")
    _check(field.rejected_far_uses >= 1,
        "Actual rejected distant action leaves safety audit trace")
    _check(not mission.inspect_physical("CORE", before_game, player),
        "Spoofed reactor E cannot bypass physical target or actual valve")
    player.body.position = Vector3(4.10, 1.33, 2.14)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 0,
        "Nearby physical E is still forbidden until dial is actually calibrated")
    _check(ui.pilot_status_label.text.contains("НАСТРОЙКУ"),
        "Native Russian accessibility explains unsolved mechanic")
    var first_angle: float = field.rotating_dial.rotation.y
    (ui.field_buttons["valve_plus"] as Button).emit_signal("pressed")
    _check(field.valve_index == 1 and not field.valve_solved,
        "Actual visible thermal dial uses detent 1 of 8 and remains unsolved")
    _check(field.rotating_dial.rotation.y > first_angle + 0.60,
        "Original 3D wheel actually rotates, not just status text")
    _check(ui.field_focused_devices.has("thermal") and ui.field_focus_events == 1,
        "A genuine near-console action starts a contextual real Camera3D focus")
    await create_timer(0.40).timeout
    _check(absf(player.body.rotation.y - PI) > 0.5,
        "Real actor camera turns from its forward relay view toward the reactor console")
    _check(ui.model.snapshot() == before_game,
        "Mechanical calibration does not secretly issue A7 PUMP/SCAN choices")
    for i in range(5):
        (ui.field_buttons["valve_plus"] as Button).emit_signal("pressed")
    _check(field.valve_index == 6 and field.valve_solved,
        "Six real user actuations align original thermal calibration target")
    _check(field.dial_color.emission == A7FieldOperations.GREEN,
        "Actual 3D pointer changes surface light only on correct alignment")
    _check(field.physical_uses == 6,
        "Only near-console accepted physical manipulation counted")
    (ui.field_buttons["valve_plus"] as Button).emit_signal("pressed")
    _check(not field.valve_solved and field.valve_index == 7,
        "Turning past the target invalidates actual mechanical alignment")
    (ui.field_buttons["valve_minus"] as Button).emit_signal("pressed")
    _check(field.valve_solved and field.valve_index == 6,
        "Backwards real wheel operation restores exact calibration")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 1,
        "Only real solved core thermal dial plus authenticated E unlocks mission")
    _check(not ui.field_valve_controls.visible,
        "Valves no longer clutter mission decision phase")
    _check(ui.model.snapshot() == before_game,
        "After physical valve solution, original 6-cycle reactor metrics unchanged")

    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(mission.phase == 1 and field.stage == 1,
        "One original action does not bypass two-decision shift")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    var after_shift: Dictionary = ui.model.snapshot()
    _check(mission.phase == 2 and field.stage == 2,
        "Exactly two original A7 actions unlock relay matrix")
    _check(field.relay_target >= 1 and field.relay_target <= 7,
        "Genuine three-switch relay target derived from first incident metrics")
    _check(field.relay_target != -1 and not field.relay_solved,
        "Relay task starts intentionally unsolved")
    _check(ui.field_relay_controls.visible and
        not ui.field_valve_controls.visible and
        not ui.field_sync_controls.visible,
        "Context UI now shows ONLY current relay interaction")

    player.body.position = Vector3(4.10,1.33,2.14)
    _check(not field.toggle_relay(0,player),
        "Can't physically toggle distant power relay while standing at core")
    _check(not mission.inspect_physical("RELAY",after_shift,player),
        "Forged relay inspection from core is rejected by world distance")
    player.body.position = Vector3(8.0,1.33,20.0)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 2,
        "Arriving at actual second station does not auto-solve relay routing")
    var first_relay: int = field.relay_mask
    (ui.field_buttons["relay_0"] as Button).emit_signal("pressed")
    _check(field.relay_mask == (first_relay ^ 1),
        "Relay rocker toggles actual independent binary electrical route")
    _check(absf(field.relay_switches[0].rotation.z) > 0.4,
        "First relay switch physically changes 3D mesh angle")
    # Return to neutral before solving exact target bits.
    (ui.field_buttons["relay_0"] as Button).emit_signal("pressed")
    for i in range(3):
        if (field.relay_target & (1 << i)) != 0:
            (ui.field_buttons["relay_%d" % i] as Button).emit_signal("pressed")
    _check(field.relay_mask == field.relay_target and field.relay_solved,
        "Independent authentic three-rocker circuit matrix correctly solved")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 3,
        "Only genuinely wired relay and nearby E unlock containment")
    _check(not ui.field_relay_controls.visible,
        "Completed relay controls disappear in low-cognitive-load UI")
    _check(ui.model.snapshot()["history"].size() == 2,
        "Relay sequence never fabricates original incident game decisions")

    # Original full deterministic route must still be required and winnable.
    var continuation: Array[String] = [
        "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for choice in continuation:
        ui.action_buttons[choice].emit_signal("pressed")
        _check(field.physical_uses >= 8,
            "Mission mechanics never silently revert previous physical actions")
    _check(str(ui.model.snapshot()["status"]) == "won",
        "Original W63 full six-cycle victory unchanged in extended mode")
    _check((ui.model.snapshot()["history"] as Array).size() == 12,
        "Original 12 real decisions remain mandatory")
    _check(mission.phase == 4 and field.stage == 4,
        "Real game win unlocks independent final containment synchronization")
    _check(field.sync_order.size() == 3 and field.sync_order[0] != field.sync_order[1] and
        field.sync_order[1] != field.sync_order[2] and field.sync_order[0] != field.sync_order[2],
        "Final mission challenge has a unique 3-contact sequence derived from real outcome")
    _check(ui.field_sync_controls.visible,
        "Native UI shows only actual final in-world synchronization mechanic")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 4,
        "Winning A7 game alone cannot skip final physical pulse sequence")
    player.body.position = Vector3(4.10,1.33,2.14)
    _check(not field.sync_connector(field.sync_order[0],null,ui.model.snapshot()),
        "Spoofed sync input cannot be accepted without physical operator")
    var wrong: int = (field.sync_order[0]+1) % 3
    (ui.field_buttons["sync_%d" % wrong] as Button).emit_signal("pressed")
    _check(field.sync_step == 0 and field.sync_mistakes == 1,
        "Wrong physical order resets sequence and records an authentic mistake")
    for index in field.sync_order:
        (ui.field_buttons["sync_%d" % index] as Button).emit_signal("pressed")
    _check(field.sync_step == 3 and field.sync_solved,
        "Only three correct authenticated physical contact presses unlock sync")
    _check(field.sync_colors[field.sync_order[0]].emission == A7FieldOperations.GREEN,
        "True native 3D torus geometry indicates completed contact sequence")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 5 and mission.qa_readout()["completed"],
        "Advanced mission completes only real win + three mechanics + physical final E")
    _check(mission.progress_events == 5,
        "Exactly five ordered genuine story objectives — no hidden stage skipping")
    _check(field.qa_readout()["physical_uses"] >= 12,
        "Real operator actually manipulated many distinct machine parts")
    _check(not field.qa_readout()["gameplay_authority"],
        "Field engine remains strictly subordinate to unchanged A7CascadeCore")

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en" and
        ui.field_start_button.text.contains("MODE"),
        "English context-sensitive premium mission controls")
    _check(field.instructions("en").contains("SECURED"),
        "English in-world final field completion message")
    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "ru" and
        field.instructions("ru").contains("СТАБИЛИЗИРОВАН"),
        "Russian final field completion readable")
    ui.quality_button.emit_signal("pressed")
    _check(field.quality == "eco" and
        is_equal_approx(field.fixture_lights[0].light_energy, 0.3),
        "Native real station lighting respects ECO power")
    ui.quality_button.emit_signal("pressed")
    _check(field.quality == "hero" and
        is_equal_approx(field.fixture_lights[0].light_energy, 1.3),
        "Native real station lighting restored with HERO")
    ui.motion_button.emit_signal("pressed")
    _check(field.reduced_motion,
        "Accessible reduced-motion retains mechanically controlled puzzle")
    ui.motion_button.emit_signal("pressed")
    for width in [320,390,768,1366]:
        ui.size = Vector2(width,800)
        ui._layout_stage()
        await process_frame
        _check(field.core_label.visible == (width >= 640),
            "Native in-world field telemetry hides on %dpx mobile HUD" % width)
        _check(ui.field_buttons.size() == 8 and ui.field_help != null,
            "Every actual physical mechanism remains accessible at %dpx" % width)
        _check(ui.model.snapshot()["status"] == "won",
            "Responsive layout never manufactures a different outcome at %dpx" % width)

    ui.restart_button.emit_signal("pressed")
    _check(not mission.active and not mission.extended_mode and not field.enabled,
        "Original reset clears all extra advanced mission gates and 3D props")
    _check(not field.active_visuals.visible and
        ui.model.snapshot()["history"].size() == 0,
        "No historical lock left after reset; old original game remains playable")
    ui.mission_button.emit_signal("pressed")
    _check(mission.active and not mission.extended_mode,
        "Player can replay original straightforward W71 mode after advanced challenge")
    player.body.position = Vector3(4.10,1.33,2.14)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 1,
        "Previous normal gameplay still allows E without advanced calibration")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W72 TRUE THREE PHYSICAL INDUSTRIAL PUZZLES PASS: %d assertions" % checks)
        quit(0)
        return
    for message in failures:
        push_error("W72 GENUINE NATIVE FIELD OPS: " + message)
    quit(1)
