extends SceneTree
## W64 native REAL Godot 4.4.1 3D geometry, game/UI integration and regression.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(condition: bool, label: String) -> void:
    checks += 1
    if not condition:
        failures.append(label)

func _run() -> void:
    var resource: PackedScene = load("res://Main.tscn") as PackedScene
    _check(resource != null, "Original independent playable Godot scene exists")
    if resource == null:
        _finish()
        return
    var ui: A7CascadeScreen = resource.instantiate() as A7CascadeScreen
    _check(ui != null, "Actual native game interface instantiated")
    if ui == null:
        _finish()
        return
    root.add_child(ui)
    await process_frame
    await process_frame

    _check(ui.model.snapshot()["schema"] == "A7_CASCADE_LOCAL_SINGLE_PLAYER_V1",
        "Deterministic six-cycle W63 original game model retained")
    _check(ui.stage_shell != null and ui.visual_container != null and
        ui.sub_viewport != null, "Genuine Godot 3D viewport mounted in game UI")
    var stage: A7CinematicStage = ui.stage_3d
    _check(stage != null, "Original 3D stage object exists")
    if stage == null:
        _finish()
        return
    var qa: Dictionary = stage.qa_readout()
    _check(bool(qa["actual_native_3d"]), "Real Godot native Camera3D and MeshInstance3D")
    _check(int(qa["real_meshes"]) >= 75, "Substantial procedural geometry, not 2D canvas fake")
    _check(int(qa["real_lights"]) == 3, "Three genuine dynamic Godot lights")
    _check(stage.camera != null and stage.camera.current, "Actual Camera3D active")
    _check(stage.rotor != null and stage.rotor.get_child_count() == 9,
        "Native rotating turbine plus eight authored blades")
    _check(stage.find_child("EngineRoomFloor", true, false) is MeshInstance3D,
        "True procedural floor mesh")
    _check(stage.find_child("ReactorPressureHousing", true, false) is MeshInstance3D,
        "True reactor geometry")
    _check(stage.find_child("CoreGlassInnerTube", true, false) is MeshInstance3D,
        "Reactive energy tube mesh")
    _check(stage.find_child("RearContainmentDoor", true, false) is MeshInstance3D,
        "Reactive bulkhead geometry")
    _check(stage.coolant_tubes.size() == 4, "Coolant conduits are actual rendered geometry")
    _check(stage.warning_beacons.size() == 4, "Four actual status beacons")
    _check(stage.hero_details.get_child_count() == 36, "36 optional native HERO details")
    _check(int(qa["snapshots"]) >= 1, "Actual model state drives native 3D world")
    _check(is_equal_approx(float(qa["heat"]), 0.62), "Scene reads real initial heat")
    _check(is_equal_approx(float(qa["energy"]), 0.85), "Scene reads real initial energy")
    _check(not bool(qa["physical_equipment_connected"]), "Pure fictional game")
    _check(not bool(qa["consumer_gpu_certified"]), "Headless test cannot claim consumer GPU")

    var original_camera_position: Vector3 = stage.camera.position
    _check(ui.camera_buttons.size() == 3, "Actual camera control buttons rendered")
    ui.camera_buttons[1].emit_signal("pressed")
    _check(stage.camera_index == 1, "Camera button selects front view")
    _check(stage.camera.position != original_camera_position, "Front view actually moves Camera3D")
    ui.camera_buttons[2].emit_signal("pressed")
    _check(stage.camera_index == 2, "Camera button selects side view")
    ui.camera_buttons[0].emit_signal("pressed")
    _check(stage.camera_index == 0, "Wide hero view returns to original camera")

    _check(stage.hero_details.visible, "Full native geometry visible initially")
    ui.quality_button.emit_signal("pressed")
    _check(stage.mode == "eco" and not stage.hero_details.visible, "ECO removes expensive 3D details")
    _check(ui.visual_container.stretch_shrink == 2, "ECO changes real viewport resolution")
    ui.quality_button.emit_signal("pressed")
    _check(stage.mode == "hero" and stage.hero_details.visible, "HERO restores geometry")
    _check(ui.visual_container.stretch_shrink == 1, "HERO restores real render resolution")

    var before_rotation: float = stage.rotor.rotation.y
    await create_timer(0.14).timeout
    _check(not is_equal_approx(stage.rotor.rotation.y, before_rotation),
        "Actual 3D rotor animates while motion is enabled")
    ui.motion_button.emit_signal("pressed")
    _check(stage.reduced_motion, "Reduced motion preference reaches actual stage")
    before_rotation = stage.rotor.rotation.y
    await create_timer(0.14).timeout
    _check(is_equal_approx(stage.rotor.rotation.y, before_rotation),
        "Reduced-motion fully stops synthetic mechanical movement")
    ui.motion_button.emit_signal("pressed")
    _check(not stage.reduced_motion, "Player can re-enable motion")

    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(int(ui.model.snapshot()["metrics"]["heat"]) == 42, "Real action changes original game heat")
    _check(is_equal_approx(stage.heat, 0.42), "Real 3D reactor emission reacts to action")
    _check(stage.recent_action == "PUMP", "Valid player action generates actual 3D pulse")
    _check(stage.pulse > 0.0, "3D visual pulse has positive dynamic energy")
    _check(is_equal_approx(stage.energy_gauge.scale.y, 0.79),
        "Real 3D power gauge reflects energy cost")
    var old_seal: float = stage.seal_gauge.scale.y
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 1, "Original deterministic incident actually advances")
    _check(stage.snapshot_count >= 3, "Native stage received and applied all current game snapshots")
    _check(stage.seal_gauge.scale.y < old_seal, "Real 3D seal gauge reflects incident impact")

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en", "Language changes without resetting current game")
    _check(ui.cinema_caption.text.contains("TRUE NATIVE 3D"), "3D heading switches to English")
    _check(ui.camera_buttons[0].text.contains("WIDE"), "Camera captions have EN localization")
    _check(ui.motion_button.text.contains("ON"), "Accessibility motion state has EN text")
    _check(ui.model.snapshot()["shift"] == 1, "Locale cannot modify gameplay")
    ui.language_button.emit_signal("pressed")
    _check(ui.cinema_caption.text.contains("3D-КАМЕРА"), "3D heading restored to Russian")

    for width in [320, 390, 768, 1366]:
        ui.size = Vector2(width, 800)
        ui._layout_stage()
        await process_frame
        if width < 640:
            _check(ui.stage_shell.custom_minimum_size.y <= 305,
                "Phone retains reachable controls under 3D hero %d" % width)
        else:
            _check(ui.stage_shell.custom_minimum_size.y >= 350,
                "Desktop/tablet cinematic stage occupies real area %d" % width)
        _check(ui.model.snapshot()["shift"] == 1, "Resizing cannot advance the game %d" % width)
        _check(ui.stage_3d.camera.current, "Camera persists after viewport resize %d" % width)

    ui.restart_button.emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 0, "Genuine game restart works after 3D state changes")
    _check(is_equal_approx(stage.heat, 0.62), "Native 3D state correctly resets with game")
    var winning_actions: Array[String] = [
        "PUMP", "SCAN", "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for action in winning_actions:
        ui.action_buttons[action].emit_signal("pressed")
        _check(stage.current_status == str(ui.model.snapshot()["status"]),
            "3D stage and game status agree after " + action)
    _check(ui.model.snapshot()["status"] == "won", "Original W63 win remains reachable with 3D")
    _check(stage.current_status == "won", "Visuals show true successful game terminal state")
    _check(is_equal_approx(stage.energy, 0.32), "Winning power gauge matches game mechanics")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W64 REAL NATIVE 3D CINEMATIC GAME PASS: %d assertions" % checks)
        quit(0)
    else:
        for problem in failures:
            push_error("W64 ACTUAL 3D QA FAILED: " + problem)
        quit(1)
