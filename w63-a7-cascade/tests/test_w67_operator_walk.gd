extends SceneTree
## W67 actual physics, camera, WASD/touch context and original puzzle proof.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool, note: String) -> void:
    checks += 1
    if not value:
        failures.append(note)

func _run() -> void:
    var game: PackedScene = load("res://Main.tscn") as PackedScene
    _check(game != null, "Original Godot playable project exists")
    if game == null:
        _finish()
        return
    var ui: A7CascadeScreen = game.instantiate() as A7CascadeScreen
    _check(ui != null, "Original native Godot UI instantiates")
    if ui == null:
        _finish()
        return
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    _check(stage != null, "Existing W66 true 3D reactor remains")
    if stage == null:
        _finish()
        return
    var player: A7OperatorRig = stage.operator_rig
    _check(player != null, "Actual CharacterBody3D rig created inside Godot 3D")
    if player == null:
        _finish()
        return
    var initial: Dictionary = player.qa_readout()
    _check(initial["schema"] == "A7_W67_ACTUAL_NATIVE_OPERATOR_WALK_V1", "Physics readout schema")
    _check(bool(initial["actual_character_body"]), "Actual Godot CharacterBody3D, not static UI mock")
    _check(bool(initial["actual_collision_capsule"]), "Actual native CapsuleShape3D collision")
    _check(bool(initial["actual_first_person_camera"]), "Actual Godot Camera3D attached to operator")
    _check(stage.walk_colliders.size() == 5, "Five real 3D physics boundaries exist")
    _check(stage.find_child("A7PhysicalWalkableFloor", true, false) is StaticBody3D,
        "Original level has collision-enabled 3D floor")
    _check(not stage.walk_mode and not player.active, "Original default cinematic UI unchanged")
    _check(stage.camera.current, "Original W64/W66 cinematic camera active by default")
    _check(ui.walk_button != null and ui.walk_action_button != null,
        "Native optional first-person and context interaction buttons")
    _check(ui.walk_direction_buttons.size() == 4, "Four actual hold-to-move touch buttons")
    _check(ui.model.snapshot()["history"].is_empty(), "No automated fake actions")

    ui.walk_button.emit_signal("pressed")
    _check(stage.walk_mode and player.active, "Native walking toggle activates actual physics rig")
    _check(player.camera_eyes.current, "Real first-person camera receives active render")
    _check(not stage.camera.current, "Original cinematic camera yields to operator")
    _check(not ui.walk_action_button.disabled, "Context console becomes accessible")

    var old_x: float = player.position.x
    ui.walk_direction_buttons["left"].emit_signal("button_down")
    await create_timer(1.35).timeout
    ui.walk_direction_buttons["left"].emit_signal("button_up")
    await process_frame
    _check(player.position.x < old_x - 3.0, "Actual physics walked over 3m into coolant sector")
    _check(player.qa_readout()["sector"] == "coolant", "Left physical bay identified")
    _check(player.context_action() == "PUMP", "Physical coolant console offers real PUMP action")
    _check(float(player.qa_readout()["travel_metres"]) > 3.0, "True movement distance recorded")
    _check(int(player.qa_readout()["movement_frames"]) > 0, "Physics frames advanced")

    ui.walk_action_button.emit_signal("pressed")
    _check(int(ui.model.snapshot()["metrics"]["heat"]) == 42,
        "Physical E/console uses original W63 rule, not a parallel fake model")
    _check(int(ui.model.snapshot()["history"].size()) == 1, "Exactly one original action recorded")
    _check(ui.sound_bus.last_cue == "action", "W65 original sound remains tied to action")
    _check(is_equal_approx(stage.heat, 0.42), "W66 rendered reactor actually reacts to console")
    _check(stage.premium_art.cooling_fraction > 0.55,
        "W66 coolant bay linked to actual resource effect")

    player.reset_operator()
    ui.walk_direction_buttons["right"].emit_signal("button_down")
    await create_timer(1.35).timeout
    ui.walk_direction_buttons["right"].emit_signal("button_up")
    _check(player.position.x > 3.0, "Actual physics walked into pressure sector")
    _check(player.qa_readout()["sector"] == "pressure", "Right physical bay identified")
    _check(player.context_action() == "SEAL", "Pressure bay offers different authentic action")
    ui.walk_action_button.emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 1, "Second physical console completes real incident")
    _check(ui.model.snapshot()["history"].size() == 2, "Only two genuine decisions this shift")
    _check(ui.narrative_title.text.contains("ТЕПЛОВОЙ"),
        "Real W65 chapter follows actual physical-console consequences")

    var before_yaw: float = player.rotation.y
    player.look_by(12,0)
    _check(not is_equal_approx(player.rotation.y,before_yaw),
        "Real first-person viewpoint yaw changes")
    ui.motion_button.emit_signal("pressed")
    _check(stage.reduced_motion and player.active,
        "Reduced decorative motion does not disable actual player locomotion")
    ui.quality_button.emit_signal("pressed")
    _check(stage.mode == "eco" and player.camera_eyes.current,
        "Low-quality GPU mode retains actual first-person gameplay")

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en", "Original bilingual interface works in walk mode")
    _check(ui.walk_button.text.contains("CINEMATIC"), "EN first-person exit text is accessible")
    _check(ui.walk_status.text.contains("PRESSURE"), "EN physical sector is readable")
    for width in [320,390,1366]:
        ui.size = Vector2(width,800)
        ui._layout_stage()
        await process_frame
        _check(ui.model.snapshot()["shift"] == 1, "Resizing cannot alter gameplay")
        _check(stage.operator_rig.camera_eyes.current, "Actual player camera remains active at width %d" % width)

    ui.walk_button.emit_signal("pressed")
    _check(not stage.walk_mode and not player.active, "Walking is an optional reversible mode")
    _check(stage.camera.current, "Fixed cinematic camera restored")
    _check(player.move_intent == Vector2.ZERO, "No stuck movement after leaving walk mode")
    _check(ui.walk_action_button.disabled, "Physical console inactive outside walk mode")
    var before_commands: int = ui.model.snapshot()["history"].size()
    ui.walk_action_button.emit_signal("pressed")
    _check(ui.model.snapshot()["history"].size() == before_commands,
        "Inactive physical console cannot mutate the original game")

    ui.restart_button.emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 0, "Original W63 game restart still available")
    _check(is_equal_approx(player.position.x,0.0), "Original operator recentered at restart")
    var solution: Array[String] = [
        "PUMP", "SCAN", "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for command in solution:
        ui.action_buttons[command].emit_signal("pressed")
    _check(ui.model.snapshot()["status"] == "won", "Original six-cycle victory still achievable")
    _check(ui.narrative_title.text.contains("STABILIZED"),
        "Original EN cinematic ending still reflects real game")
    _check(ui.model.snapshot()["history"].size() == 12, "No extra actions created by walk mode")
    _check(not bool(player.qa_readout()["gameplay_rules_mutated"]), "Operator cannot change core rules")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W67 REAL FIRST PERSON PHYSICS + TWO CONSOLE BAYS PASS: %d assertions" % checks)
        quit(0)
        return
    for issue in failures:
        push_error("W67 PHYSICS / REAL GAME FAILED: " + issue)
    quit(1)
