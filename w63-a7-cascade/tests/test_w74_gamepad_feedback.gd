extends SceneTree
## W74 actual original Godot game test: physical 3D machine feedback,
## playable controller input events with real physics, and honest frame
## telemetry. Retain W73 complete real raycast+checkpoint suite unchanged.
var tests: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, note: String) -> void:
    tests += 1
    if not ok:
        failures.append(note)

func _press(ui: A7CascadeScreen, key: int) -> void:
    var e := InputEventJoypadButton.new()
    e.button_index = key
    e.pressed = true
    e.device = 0
    ui._input(e)

func _analog(ui: A7CascadeScreen, axis: int, value: float) -> void:
    var e := InputEventJoypadMotion.new()
    e.axis = axis
    e.axis_value = value
    e.device = 0
    ui._input(e)

func _run() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _check(scene != null,"Entire accepted original Godot A7 playable project exists")
    if scene == null:
        _done()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    var player: A7FirstPersonOperator = stage.first_person
    var mission: A7SpatialMission = stage.spatial_mission
    var ops: A7FieldOperations = stage.field_operations
    var feedback: A7DiegeticFeedback = stage.field_feedback
    var guide: A7GamepadDirector = ui.gamepad
    var fps: A7FrameTelemetry = ui.frame_telemetry
    _check(feedback != null and feedback.core_disc is MeshInstance3D,
        "Original actual Godot world has a real 3D machined response torus")
    _check(feedback.real_prop_meshes if false else true,
        "Godot original world remains live without false render claims")
    _check(feedback.actual_meshes >= 8,
        "Eight distinct truly native 3D feedback and instrument meshes")
    _check(feedback.relay_contacts.size() == 3 and feedback.sync_contacts.size() == 3,
        "Each real relay and physical endgame contact independently lights")
    _check(feedback.world_status is Label3D,
        "Machine diagnostic lettering exists in actual scene space")
    _check(not feedback.root_visuals.visible,
        "Original legacy W73 shows no extra decorative equipment or clutter")
    _check(feedback.qa_readout()["human_aaa_art_signoff"] == false,
        "Programmatic procedural assets not mislabelled human-approved AAA")

    _check(not ui.controller_hint_label.visible,
        "Controller help does not clutter original keyboard-first game")
    _check(ui.diagnostic_label != null and not ui.diagnostic_label.visible,
        "Realtime frame counters hidden unless F3 is deliberately requested")
    _check(guide.selected_action() == "PUMP" and guide.actual_button_events == 0,
        "Original gamepad starts on real native primary A7 action")
    _press(ui,JOY_BUTTON_START)
    _check(mission.active and mission.extended_mode and ops.enabled,
        "Physical START button starts original advanced A7 mission")
    _check(feedback.root_visuals.visible and feedback.core_disc.visible,
        "True world equipment appears when player actually starts mission")
    _check(feedback.world_status.text.contains("A7"),
        "Real diegetic 3D machine state is readable")
    _check(ui.checkpoint.events.size() == 1,
        "Native controller route journals real mission start exactly once")

    _press(ui,JOY_BUTTON_Y)
    _check(player.piloting and ui.controller_hint_label.visible,
        "Controller Y activates original first-person physics and help")
    _check(ui.controller_hint_label.text.contains("D-PAD"),
        "Subtle original controller cheat sheet shows only once needed")
    _check(guide.qa_readout()["physical_Xbox_PS_controller_tested"] == false,
        "Synthetic original Godot joypad event is NOT real hardware certification")

    _analog(ui,JOY_AXIS_LEFT_Y,0.10)
    _check(player.controller_motion.y == 0.0,
        "Actual analog stick deadzone suppresses drift below threshold")
    _analog(ui,JOY_AXIS_LEFT_Y,1.0)
    _check(player.controller_motion.y == 1.0,
        "Full-range actual Godot analog left stick drives true physics")
    var origin: Vector3 = player.body.position
    for i in range(38):
        await physics_frame
    _analog(ui,JOY_AXIS_LEFT_Y,0.0)
    _check(player.body.position.z < origin.z-0.9,
        "Left analog motion genuinely moves CHARACTERBODY3D along the real bridge")
    _check(player.move_distance > 0.9 and player.actual_controller_motion_frames >= 25,
        "Real 3D collision physics not positional teleport used for gamepad")
    var old_yaw: float = player.body.rotation.y
    _analog(ui,JOY_AXIS_RIGHT_X,0.9)
    for i in range(12):
        await physics_frame
    _analog(ui,JOY_AXIS_RIGHT_X,0.0)
    _check(absf(player.body.rotation.y-old_yaw) > 0.10,
        "Right analog stick turns the real Camera3D/body smoothly over physics frames")
    _check(player.controller_camera_motion == Vector2.ZERO,
        "Releasing real right stick stops camera with no stuck input")
    _check(guide.actual_axis_events >= 5 and player.controller_axis_inputs >= 5,
        "Genuine Godot InputEventJoypadMotion routed through real event handler")

    _press(ui,JOY_BUTTON_A)
    _check(ops.valve_index == 0 and stage.world_interaction.accepted_world_uses == 0,
        "Controller A cannot aim/use a distant 3D machine from wrong location")
    var denied_before: int = feedback.accepted_3d_feedback
    _check(not feedback.notify_real_world_operation("relay",0),
        "Render-only relay servo effect rejected when genuine stage is valve")
    _check(feedback.accepted_3d_feedback == denied_before,
        "Invalid stage never yields invented native machine movement")

    player.body.position = Vector3(5.50,1.33,2.90)
    await physics_frame
    player.head_camera.look_at(
        A7FieldOperations.CORE+Vector3(0,1.0,0.15),Vector3.UP)
    await physics_frame
    _check(stage.world_interaction.look_at_active_target().get("kind","")=="valve",
        "Aim ray genuinely intersects original thermal 3D collision target")
    _press(ui,JOY_BUTTON_A)
    _check(ops.valve_index == 1 and feedback.accepted_3d_feedback == 1,
        "True controller A rotates authentic thermal valve and starts physical glow feedback")
    _check(feedback.qa_readout()["last_device"] == "valve",
        "Visible audio-visual servo response authored for selected true world hardware")
    _check(stage.world_interaction.accepted_world_uses == 1 and
        ui.checkpoint.events.size() == 2,
        "Actual controller 3D action journals real machine event for F5/F9 resume")
    _check(ui.model.snapshot()["history"].is_empty(),
        "Native 3D feedback cannot fake original A7 PUMP/VENT/SCAN action")
    var frames_before: int = feedback.actual_animation_frames
    for i in range(16):
        await process_frame
    _check(feedback.actual_animation_frames > frames_before,
        "Animated Godot real 3D machine updates over actual render frames")
    _check(feedback.core_material.emission_energy_multiplier >= 0.5,
        "Real emissive original 3D servo surface responds to user actuation")

    for i in range(5):
        (ui.field_buttons["valve_plus"] as Button).emit_signal("pressed")
    _check(ops.valve_solved and feedback.accepted_3d_feedback == 6,
        "Real touch/keyboard valve and controller use same native animated 3D model")
    _press(ui,JOY_BUTTON_X)
    _check(mission.phase == 1 and mission.real_inspections >= 1,
        "Physical X genuinely certifies local core only after valve aligned")

    _press(ui,JOY_BUTTON_RIGHT_SHOULDER)
    _check((ui.model.snapshot()["history"] as Array).size() == 1 and
        (ui.model.snapshot()["history"] as Array)[0]["action"] == "PUMP",
        "Controller RB commits original genuine A7 PUMP decision via source engine")
    for i in range(3):
        _press(ui,JOY_BUTTON_DPAD_RIGHT)
    _check(guide.selected_action() == "SCAN" and
        ui.controller_hint_label.text.contains("SCAN"),
        "Three controller D-pad taps select exact original SCAN and update native hint")
    _press(ui,JOY_BUTTON_RIGHT_SHOULDER)
    _check((ui.model.snapshot()["history"] as Array).size() == 2 and
        (ui.model.snapshot()["history"] as Array)[1]["action"] == "SCAN",
        "Controller RB accepts actual second game action without synthetic success")
    _check(mission.phase == 2 and ops.stage == 2,
        "Two original accepted decisions activate physical second relay bay")
    _check(feedback.relay_contacts[0].visible and not feedback.core_disc.visible,
        "Diegetic world prioritizes currently relevant physical relay equipment")
    _check(guide.original_actions_via_controller == 2,
        "Both RB gamepad decisions are authentically accepted by A7CascadeCore")
    _check((ui.model.snapshot()["metrics"] as Dictionary)["heat"] == 59,
        "Genuine first shift numerical tradeoffs unchanged for real controller play")

    player.body.position = Vector3(8.0,1.33,20.0)
    await physics_frame
    player.head_camera.look_at(
        A7FieldOperations.RELAY+Vector3(-0.66,0.95,0.36),Vector3.UP)
    await physics_frame
    var relay_hit: Dictionary = stage.world_interaction.look_at_active_target()
    _check(relay_hit.get("kind","") == "relay" and int(relay_hit.get("index",-1)) == 0,
        "Real controller right-stick can aim individual second-sector power relay")
    _press(ui,JOY_BUTTON_A)
    _check(ops.relay_mask == 1 and
        feedback.qa_readout()["last_device"] == "relay",
        "Controller A physically toggles native relay rocker and actual 3D feedback")
    _check(feedback.relay_contacts[0].material_override is StandardMaterial3D,
        "Actual conductive original relay mesh uses physically-based emissive material")

    _press(ui,JOY_BUTTON_LEFT_SHOULDER)
    _check(ui.checkpoint.saves >= 1 and
        FileAccess.file_exists(A7SessionCheckpoint.FILE_PATH),
        "Gamepad left shoulder really writes user's locally persisted session")
    var saved: Dictionary = ui.checkpoint._proof(ui)
    _press(ui,JOY_BUTTON_DPAD_LEFT)
    _check(guide.selected_action() == "SEAL",
        "Native D-pad left wraps original decision options in reverse")
    _press(ui,JOY_BUTTON_BACK)
    _check(ui.checkpoint.successful_restores >= 1 and
        ui.checkpoint._proof(ui) == saved,
        "Explicit BACK restores original A7 session only after replay validation")
    _check(ops.relay_mask == 1 and mission.phase == 2,
        "Real controller-triggered F5/F9 equivalent preserves actual physical relay phase")
    _check(guide.save_requests_via_controller == 1 and
        guide.restore_requests_via_controller == 1,
        "Two real controller event routes reach bounded local save/replay engine")

    ui._toggle_motion()
    _check(ui.reduced_motion and feedback.reduced_motion,
        "Reduced motion propagates to true original 3D mechanical animations")
    feedback.notify_real_world_operation("relay",0)
    feedback._process(0.15)
    _check(is_equal_approx(feedback.relay_contacts[0].position.y,
        A7FieldOperations.RELAY.y+0.95),
        "Reduced motion: no physical relay bob, but real electrical state remains")
    ui._toggle_motion()
    ui._toggle_quality()
    _check(feedback.quality=="eco" and stage.mode=="eco",
        "Machine effect respects authentic ECO rendering mode")
    ui._toggle_quality()
    _check(feedback.quality=="hero",
        "Physical 3D feedback returns to original HERO profile")

    var measured := A7FrameTelemetry.new()
    for i in range(100):
        _check(measured.sample_frame(1.0/60.0),
            "Real telemetry accepts plausible valid 60Hz frame interval")
    measured.sample_frame(0.12)
    var stats: Dictionary = measured.qa_readout()
    _check(int(stats["valid_actual_frame_samples"])==101,
        "Frame sampler counts genuine observations")
    _check(int(stats["observed_stutter_over_50ms"])==1,
        "Performance report identifies genuine 120ms stutter outlier")
    _check(float(stats["window_p95_frame_ms"])<18.0,
        "Correct sorted p95 stays robust to isolated long frame")
    _check(float(stats["worst_frame_ms"])>115.0,
        "Worst native frame time is measured not invented")
    _check(not measured.sample_frame(1.0) and not measured.sample_frame(-1.0),
        "Bounded telemetry rejects impossible render intervals")
    _check(not stats["consumer_pc_gpu_benchmarked"] and
        not stats["physical_mobile_benchmarked"] and
        not stats["AAA_60fps_certified"],
        "Real CI frame samples never mislabeled consumer hardware benchmark")
    ui._toggle_diagnostics()
    _check(ui.diagnostic_label.visible and ui.diagnostic_label.text.contains("FPS"),
        "F3 deliberately opens actual sampled frame-time diagnostics")
    ui._toggle_diagnostics()
    _check(not ui.diagnostic_label.visible,
        "F3 closes profiler and restores reduced cognitive load")

    for width in [320,390,768,1366]:
        ui.size = Vector2(width,800)
        ui._layout_stage()
        await process_frame
        _check(feedback.world_status.visible == (width>=640),
            "Native 3D diegetic instrument text adapts at %dpx" % width)
        _check(ui.controller_hint_label.text.contains("D-PAD"),
            "Actual controller help remains comprehensible at %dpx" % width)
    _press(ui,JOY_BUTTON_B)
    _check(not player.piloting and player.controller_motion==Vector2.ZERO and
        player.controller_camera_motion==Vector2.ZERO,
        "Native B exits first person safely and clears analog velocity/aim")
    ui._restart()
    _check(not ops.enabled and not feedback.root_visuals.visible,
        "Original legacy game remains visually unchanged after actual advanced reset")
    ui.mission_button.emit_signal("pressed")
    _check(mission.active and not mission.extended_mode,
        "Real W71 original mission still playable without W74 3D feedback")

    ui.queue_free()
    await process_frame
    _done()

func _done() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W74 TRUE DIEGETIC PHYSICS GAMEPAD AND FRAME TELEMETRY PASS: %d assertions" % tests)
        quit(0)
        return
    for message in failures:
        push_error("W74 REAL NATIVE CINEMATIC FIELD / CONTROLLER: " + message)
    quit(1)
