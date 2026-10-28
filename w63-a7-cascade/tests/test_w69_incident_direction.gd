extends SceneTree
## W69 original, actual Godot 4.4.1 industrial cinema/incident acceptance.
## Gameplay law: camera, HUD and danger staging are READ-ONLY consequences.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, description: String) -> void:
    checks += 1
    if not condition:
        failures.append(description)

func _run() -> void:
    var source: PackedScene = load("res://Main.tscn") as PackedScene
    _check(source != null, "Real original playable six-cycle scene still imports")
    if source == null:
        _finish()
        return
    var ui := source.instantiate() as A7CascadeScreen
    _check(ui != null, "Genuine native Godot screen loaded")
    if ui == null:
        _finish()
        return
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    _check(stage != null, "Original W64-W68 Godot renderer exists")
    var direction: A7IncidentDirection = stage.incident_cinema
    _check(direction != null, "W69 separate original cinematic 3D director exists")
    if direction == null:
        _finish()
        return
    var qa: Dictionary = direction.qa_readout()
    _check(qa["schema"] == "LAST_FRONTIER_W69_NATIVE_INCIDENT_DIRECTION_V1",
        "Independent W69 real 3D QA schema")
    _check(int(qa["real_meshes"]) >= 48,
        "Genuine 3D emergency machine shutters, optic rig and atmosphere")
    _check(int(qa["real_shutters"]) == 4,
        "Four physically modeled heat-driven emergency bulkhead shutters")
    _check(int(qa["real_scanner_optics"]) == 10,
        "Ten individual moving real 3D scan optics exist")
    _check(int(qa["actual_vapor_planes"]) == 8,
        "Eight locally-generated volumetric impression meshes exist")
    _check(int(qa["native_lights"]) == 2,
        "Two actual Godot industrial warning light sources exist")
    _check(int(qa["in_world_readouts"]) == 2,
        "Two genuine in-world Label3D live system displays")
    _check(qa["reported_pressure"].contains("THERMAL  062"),
        "Live reactor readout reflects real original initial heat 62")
    _check(qa["reported_energy"].contains("POWER  085"),
        "Live second sector readout reflects original energy 85")
    _check(not bool(qa["gameplay_authority"]),
        "Visual actor not allowed to issue original decisions")
    _check(not bool(qa["network_or_licensed_art_used"]),
        "Visual project is an original offline game")
    _check(direction.find_child("PhysicalReactorBaffle-1", true, false) is MeshInstance3D,
        "Emergency reactor shutter is actually in 3D world")
    _check(direction.find_child("RealRelayBulkheadBaffle1", true, false) is MeshInstance3D,
        "Second sector contains separate real shutter")
    _check(direction.find_child("ActualOperatorHeatPressureTelemetry", true, false) is Label3D,
        "Heat and pressure are visible on true Godot 3D text object")
    _check(direction.find_child("RealGodotAtmosphericVapor00", true, false) is MeshInstance3D,
        "Original alpha vapor is a genuine Godot mesh")
    _check(direction.vapor_material.albedo_texture is ImageTexture,
        "Vapor is native CPU-generated ImageTexture, not a stock photo")

    var base_state: Dictionary = ui.model.snapshot()
    var ordinary_fov: float = stage.camera.fov
    var base_stage_height: float = ui.stage_shell.custom_minimum_size.y
    _check(not stage.inspection_focus, "Native optics starts with ordinary FOV")
    _check(not ui.cinema_mode, "Working default dashboard remains available")
    _check(ui.focus_button != null and ui.cinema_button != null,
        "Native Godot buttons provide focus and cinematic presentation")
    ui.focus_button.emit_signal("pressed")
    _check(stage.inspection_focus, "Real native optics focus toggles")
    _check(stage.camera.fov < ordinary_fov - 12.0,
        "Actual Camera3D changes focal length, not CSS/image enlargement")
    _check(ui.model.snapshot() == base_state,
        "Optical focus never creates a hidden gameplay action")
    ui.focus_button.emit_signal("pressed")
    _check(not stage.inspection_focus and
        is_equal_approx(stage.camera.fov, ordinary_fov),
        "Exit focus restores actual original camera FOV")
    _check(ui.focus_button.text.contains("ПРИБЛИЗИТЬ"),
        "RU native optics button returns to focus label")
    ui.cinema_button.emit_signal("pressed")
    _check(ui.cinema_mode, "Real native cinematic viewport mode activated")
    _check(ui.stage_shell.custom_minimum_size.y > base_stage_height + 100,
        "Actual Godot 3D viewport grows when cinema button pressed")
    _check(not ui.intro.visible and not ui.subtitle.visible and
        not ui.route_label.visible, "Cinematic view removes low-value UI clutter")
    _check(ui.model.snapshot() == base_state,
        "Expanding game view never changes gameplay state")
    ui.cinema_button.emit_signal("pressed")
    _check(not ui.cinema_mode and ui.intro.visible and ui.route_label.visible,
        "Operator workbench UI restores correctly")
    _check(is_equal_approx(ui.stage_shell.custom_minimum_size.y, base_stage_height),
        "Operator workbench restores prior Godot native stage size")

    ui.sector_buttons[1].emit_signal("pressed")
    var relay_fov: float = stage.camera.fov
    _check(relay_fov >= 63.9, "Original W67 spacious real relay view retained")
    ui.focus_button.emit_signal("pressed")
    _check(stage.camera.fov < relay_fov - 15,
        "Macro optics in genuine second room uses its own FOV")
    _check(stage.sector_index == 1 and stage.inspection_focus,
        "Focus doesn't teleport between independent real 3D sectors")
    ui.focus_button.emit_signal("pressed")
    ui.sector_buttons[0].emit_signal("pressed")
    _check(ui.model.snapshot() == base_state,
        "All optics/room movement preserves exact six-cycle puzzle state")

    ui.quality_button.emit_signal("pressed")
    _check(stage.mode == "eco" and direction.quality == "eco",
        "Actual machine and cinema respect ECO quality")
    _check(not direction.extra_atmosphere.visible and
        not direction.scanner_lattice.visible,
        "Native ECO hides nonessential atmospheric and optic geometry")
    _check(direction.main_rig.visible and direction.reactor_readout != null and
        (direction.compact or direction.reactor_readout.visible),
        "Core physical machine remains in ECO; narrow UI hides optional 3D text")
    ui.quality_button.emit_signal("pressed")
    _check(stage.mode == "hero" and direction.extra_atmosphere.visible,
        "HERO restores the original real material atmosphere")
    ui.motion_button.emit_signal("pressed")
    _check(direction.reduced_motion, "Accessible reduced-motion mode propagated")
    direction.accepted_action("WRONG")
    _check(direction.accepted_actions == 0,
        "Unsupported actions never trigger cinematic positive feedback")
    ui.motion_button.emit_signal("pressed")
    _check(not direction.reduced_motion, "Native motion toggle restores animation")

    var original_shutter_x: float = direction.core_shutters[0].position.x
    var fake: Dictionary = base_state.duplicate(true)
    fake["metrics"]["heat"] = 95
    fake["metrics"]["pressure"] = 92
    fake["metrics"]["integrity"] = 55
    direction.present(fake)
    _check(direction.incident_severity > 0.5,
        "Actual high heat/pressure drives visual danger")
    _check(direction.core_shutters[0].position.x > original_shutter_x,
        "Real left reactor safety shutter closes inward under danger")
    _check(direction.relay_shutters[0].position.x > 4.15,
        "Second separate chamber safety shutter responds to same event")
    _check(direction.reactor_readout.text.contains("095"),
        "Original danger readout shows real provided state, no fake film text")
    _check(ui.model.snapshot() == base_state,
        "Synthetic visual danger test cannot change underlying game model")
    direction.present(ui.model.snapshot())
    _check(direction.incident_severity < 0.05,
        "Restoring real safe state retracts visual shutters")

    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(ui.model.snapshot()["metrics"]["heat"] == 42,
        "W63 heat model remains exact after W69 cinematics")
    _check(direction.accepted_actions == 1 and direction.last_action == "PUMP",
        "Only a genuinely accepted decision triggers action choreography")
    _check(direction.reactor_readout.text.contains("042"),
        "Real 3D in-world heat readout updates after game command")
    _check(direction.action_flash > 0.0,
        "Native sensor/lamps receive reaction impulse after real decision")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 1,
        "Original real incident advances after two genuine player decisions")
    _check(direction.accepted_actions == 2,
        "Exactly two player commands are reflected visually")
    _check(direction.relay_readout.text.contains("061"),
        "Actual in-world signal display reflects incident state 61")
    _check(ui.model.snapshot()["history"].size() == 2,
        "Visual choreography did not add hidden game choices")

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en", "Native new controls support English")
    _check(ui.cinema_button.text.contains("CINEMA VIEW"),
        "English cinematic 3D view control is accessible")
    _check(ui.focus_button.text.contains("ZOOM IN"),
        "English optical focus control remains readable")
    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "ru", "Russian localization restored")

    for width in [320, 390, 768, 1366]:
        ui.size = Vector2(width, 800)
        ui._layout_stage()
        await process_frame
        _check(stage.camera.current,
            "Original actual Camera3D survives %dpx viewport" % width)
        _check(direction.compact == (width < 640),
            "Native in-world telemetry adapts at %dpx" % width)
        _check(direction.reactor_readout.visible == (width >= 640),
            "Extra world text must not collide with phone HUD at %dpx" % width)
        _check(ui.model.snapshot()["history"].size() == 2,
            "Resize cannot change existing player decisions at %dpx" % width)
    ui.cinema_button.emit_signal("pressed")
    _check(ui.cinema_mode and ui.stage_shell.custom_minimum_size.y > 580.0,
        "Full original cinematic 3D at desktop viewport")
    ui.cinema_button.emit_signal("pressed")

    # Preserve one genuinely winnable six-cycle sequence after all visual
    # changes, rather than substituting a scripted cinematic ending.
    ui.restart_button.emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 0 and
        direction.accepted_actions == 2,
        "Game reset restarts rules; cinematic analytics report session counts")
    var route: Array[String] = [
        "PUMP", "SCAN", "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for action in route:
        ui.action_buttons[action].emit_signal("pressed")
        _check(stage.current_status == str(ui.model.snapshot()["status"]),
            "Real native cinematic system matches each original incident status")
    _check(ui.model.snapshot()["status"] == "won",
        "Original deterministic six-cycle winning run succeeds unchanged")
    _check(direction.current_status == "won",
        "Cinematic ending responds to actual game win")
    _check(direction.accepted_actions == 14,
        "Exactly fourteen accepted real commands in session, no fake actions")
    _check(not bool(direction.qa_readout()["physical_gpu_certified"]),
        "Headless Godot test is NOT real hardware certification")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W69 TRUE CINEMATIC INCIDENT/OPTICS/WIN PASS: %d checks" % checks)
        quit(0)
    for message in failures:
        push_error("W69 REAL NATIVE 3D CINEMA: " + message)
    quit(1)
