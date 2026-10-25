extends SceneTree
## W22 native QA: real case-selection controls, safe state interlocks,
## persistence via the unchanged W14 schema and derived game-only mastery.

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("W22 CASE SELECT FAILED: " + message)
    quit(1)


func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    if packed == null:
        _fail("Actual W19 Godot game missing")
        return
    var scene: Node = packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    var rig: Node = scene.get("controller") as Node
    var guide: Control = scene.get("premium_intro") as Control
    if rig == null or guide == null:
        _fail("Real simulator or course missing")
        return
    scene.call("_set_locale", "ru")
    var buttons: Array = guide.get("case_selection_buttons")
    var mastery: Label = guide.get("case_mastery_label") as Label
    if buttons.size() != 3 or mastery == null:
        _fail("Three original Godot replay buttons/mastery readout not connected")
        return
    for i in range(3):
        var b: Button = buttons[i] as Button
        if b == null or b.focus_mode != Control.FOCUS_ALL or b.name != ("ReplayFault_%d" % (i + 1)):
            _fail("Missing keyboard/touch accessible genuine fault replay button")
            return
    if not str(mastery.text).contains("МАСТЕРСТВО"):
        _fail("Visible Russian per-case mastery readout missing")
        return
    var before: Dictionary = rig.call("summary")
    var attempt_before: int = int(before.get("case_attempts", [0, 0, 0])[2])
    if bool(rig.call("start_selected_challenge", -1)) or bool(rig.call("start_selected_challenge", 3)):
        _fail("Invalid fault index should not silently start some other mission")
        return
    if int(rig.call("summary").get("case_attempts", [0, 0, 0])[2]) != attempt_before:
        _fail("Invalid case request changed persisted attempts")
        return

    scene.call("_start_mission")
    if bool(rig.call("start_selected_challenge", 2)):
        _fail("Active maintenance training was bypassed by new replay")
        return
    # Original W13 mission must remain completable before manually targeting
    # another fault: stops, real hatch travel, full seal and safe restart.
    scene.call("_toggle_motion")
    scene.call("_toggle_hatch")
    for tick in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    scene.call("_toggle_hatch")
    for tick in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    scene.call("_toggle_motion")
    if not bool(rig.call("summary").get("mission_completed", false)):
        _fail("Existing real safety-first mission did not complete")
        return
    # Selecting a case must use the actual click signal, not just a fake state.
    (buttons[2] as Button).pressed.emit()
    var state: Dictionary = rig.call("summary")
    if int(state.get("challenge_fault_index", -1)) != 2 or not bool(state.get("challenge_active", false)):
        _fail("Case 3 real button did not start SERVICE INTERLOCK scenario")
        return
    if int(state.get("case_attempts", [0, 0, 0])[2]) != attempt_before + 1:
        _fail("Actual case attempt not tracked through existing W14 save")
        return
    var view_before: int = int(state.get("challenge_target_view", -1))
    if view_before != 1:
        _fail("New selected fault must use genuine Service Deck inspection view")
        return
    for b in buttons:
        if not (b as Button).disabled:
            _fail("Cannot select different fault while real challenge runs")
            return
    # A fabricated pressed signal must also fail in controller, even bypassing
    # Godot button disabled state.
    (buttons[0] as Button).pressed.emit()
    if int(rig.call("summary").get("challenge_fault_index", -1)) != 2:
        _fail("UI forged selection bypassed live challenge interlock")
        return
    # Five real simulator checkpoints, no shortcuts.
    scene.call("_toggle_motion")
    if int(rig.call("summary").get("challenge_step", -1)) != 1:
        _fail("Case 3 stop-drive checkpoint not connected")
        return
    scene.call("_toggle_hatch")
    if int(rig.call("summary").get("challenge_step", -1)) != 2:
        _fail("Case 3 open-hatch checkpoint not connected")
        return
    for tick in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    scene.call("_apply_view", 1)
    scene.call("_scan_component")
    if int(rig.call("summary").get("challenge_step", -1)) != 3:
        _fail("Case 3 actual camera scan not accepted")
        return
    scene.call("_toggle_hatch")
    for tick in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    scene.call("_toggle_motion")
    state = rig.call("summary")
    if not bool(state.get("challenge_completed", false)) or bool(state.get("challenge_active", true)):
        _fail("Real selected case did not complete safely")
        return
    if int(state.get("case_best_scores", [0, 0, 0])[2]) <= 0:
        _fail("Existing local score was not persisted for chosen case")
        return
    var badges: Dictionary = rig.call("mastery_report")
    if not bool(badges.get("simulation_only", false)) or int(badges.get("mastery_threshold", 0)) != 100:
        _fail("Mastery must be derived from virtual game score and labelled simulation")
        return
    var original_attempt: int = int(state.get("case_attempts", [0, 0, 0])[2])
    # Reopen real scene after W14 record save to test durable targeted history.
    scene.queue_free()
    await process_frame
    var new_scene: Node = packed.instantiate()
    root.add_child(new_scene)
    await process_frame
    await process_frame
    var reloaded: Node = new_scene.get("controller") as Node
    var restored: Dictionary = reloaded.call("summary")
    if int(restored.get("case_attempts", [0, 0, 0])[2]) != original_attempt:
        _fail("W14 records changed after real targeted replay and reload")
        return
    if int(restored.get("record_schema_version", 0)) != 2:
        _fail("W22 accidentally changed W14 save schema")
        return
    if not (restored.get("case_proficient_flags", []) is Array):
        _fail("Real restart did not derive game proficiency from saved score")
        return
    print("W22 TARGETED REPLAY PASS: 3 clickable faults, interlocks, selected real diagnostics, stable W14 saves, mastery")
    new_scene.queue_free()
    quit(0)
