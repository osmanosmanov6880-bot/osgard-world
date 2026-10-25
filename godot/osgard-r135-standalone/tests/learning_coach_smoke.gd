extends SceneTree
## Real Godot UI and simulation coaching acceptance; no physical device claims.
func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("W21 EXPLAINABLE COACH FAILED: " + message)
    quit(1)


func _run() -> void:
    var coach = preload("res://R135LearningCoach.gd")
    var intro: Dictionary = coach.explain({}, 0, "ru")
    if str(intro.get("status")) != "intro" or not str(intro.get("cause", "")).contains("игре"):
        _fail("Simple Russian cause on first launch missing")
        return
    if not bool(intro.get("simulation_only", false)):
        _fail("Course explanation must always be simulation-only")
        return
    for fault in range(3):
        var snapshot := {
            "challenge_active": true,
            "challenge_fault_index": fault,
            "challenge_step": 2,
            "challenge_evidence": ["EDGE OFFSET +0.7 (SIM)",
                "AIRFLOW BELOW TARGET (SIM)", "CONTACT UNSEALED (SIM)"][fault],
            "challenge_errors": 0,
            "challenge_feedback": "CHECKPOINT 2/5 CLEARED"
        }
        var ru: Dictionary = coach.explain(snapshot, 3, "ru")
        var en: Dictionary = coach.explain(snapshot, 3, "en")
        if int(ru.get("fault_index", -1)) != fault or ru.get("title") == en.get("title"):
            _fail("RU/EN coaching must distinguish all three real fault types")
            return
        if not str(ru.get("evidence", "")).contains("(SIM)") or str(ru.get("next", "")).is_empty():
            _fail("Each explanation requires actual simulation-labeled evidence and a next action")
            return
        snapshot["challenge_feedback"] = "INCORRECT VIEW — TARGET VIEW 2"
        snapshot["challenge_errors"] = 1
        var wrong: Dictionary = coach.explain(snapshot, 3, "ru")
        if str(wrong.get("status")) != "wrong_view" or not bool(wrong.get("error", false)):
            _fail("Incorrect camera viewpoint must receive the explicit reason")
            return
        snapshot["challenge_feedback"] = "WRONG ORDER — STOP THE DRIVE"
        if str(coach.explain(snapshot, 3, "ru").get("status")) != "wrong_order":
            _fail("Unsafe order needs a different explanatory cause")
            return
        snapshot["challenge_feedback"] = "WAIT FOR THE STOPPED, OPEN HATCH"
        if str(coach.explain(snapshot, 3, "en").get("status")) != "wait_for_hatch":
            _fail("Closed hatch must prevent simulated scan and explain waiting")
            return
        snapshot["challenge_active"] = false
        snapshot["challenge_completed"] = true
        if str(coach.explain(snapshot, 5, "ru").get("status")) != "completed":
            _fail("Completed actual case needs results/review instead of error")
            return

    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    if packed == null:
        _fail("Original real W19 Godot game missing")
        return
    var scene: Node = packed.instantiate()
    root.add_child(scene)
    await process_frame
    await process_frame
    var rig: Node = scene.get("controller") as Node
    var course: Control = scene.get("premium_intro") as Control
    if rig == null or course == null:
        _fail("W21 cannot find actual service rig or tutorial")
        return
    var button: Button = course.get("coach_more_button") as Button
    var details: Label = course.get("coach_detail") as Label
    var cause_label: Label = course.get("coach_summary") as Label
    if button == null or details == null or cause_label == null:
        _fail("W21 did not render real progressive disclosure controls")
        return
    if button.focus_mode != Control.FOCUS_ALL or details.visible:
        _fail("Deep explanation must be optional and keyboard-accessible")
        return
    button.pressed.emit()
    if not details.visible or not str(details.text).contains("ТОЛЬКО СИМУЛЯЦИЯ"):
        _fail("Visible deep cause not wired to the actual button: " + JSON.stringify({
            "expanded": course.get("coach_expanded"), "visible": details.visible,
            "text": details.text, "locale": scene.get("ui_locale"),
            "parent_visible": details.get_parent().visible
        }))
        return
    button.pressed.emit()
    if details.visible:
        _fail("Player cannot hide deeper explanation")
        return
    scene.call("_start_mission")
    scene.call("_toggle_hatch")  # Real simulated interlock must reject unsafe order.
    var safety: Dictionary = rig.call("summary")
    var explanation: Dictionary = coach.explain(safety, 2, "ru")
    if str(explanation.get("status")) != "interlock" or not bool(explanation.get("error")):
        _fail("Genuine unsafe hatch action did not produce the correct why explanation")
        return
    if not str((course.get("coach_detail") as Label).text).contains("блокировка") \
        and not str(cause_label.text).contains("люка"):
        _fail("Actual course failed to present simulated safety warning")
        return

    scene.call("_start_challenge")
    scene.call("_scan_component") # Real scanner before stopping is an invalid order.
    var state: Dictionary = rig.call("summary")
    if str(coach.explain(state, 3, "ru").get("status")) != "wrong_order" or int(state.get("challenge_errors", 0)) == 0:
        _fail("Real gameplay wrong-order penalty did not update explanation")
        return
    scene.call("_toggle_motion")
    scene.call("_toggle_hatch")
    for i in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    if float(rig.call("summary").get("lid_progress", 0.0)) < 0.95:
        _fail("Real simulator hatch did not fully open")
        return
    scene.call("_scan_component") # Actual camera is overview (0), not optical (2).
    state = rig.call("summary")
    var wrong_view: Dictionary = coach.explain(state, 3, "en")
    if str(wrong_view.get("status")) != "wrong_view" or not str(wrong_view.get("next")).contains("camera"):
        _fail("Real wrong-view feedback lacks causal coaching")
        return
    scene.call("_set_locale", "en")
    if not str((course.get("coach_heading") as Label).text).contains("OPTICS"):
        _fail("W21 real Godot view did not localize the fault explanation")
        return
    scene.call("_apply_view", 2)
    scene.call("_scan_component")
    if int(rig.call("summary").get("challenge_step", -1)) != 3:
        _fail("W21 explanation changes must not break genuine fault scan")
        return
    scene.call("_toggle_hatch")
    for i in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    scene.call("_toggle_motion")
    state = rig.call("summary")
    if not bool(state.get("challenge_completed", false)):
        _fail("Real diagnosed fault did not safely complete")
        return
    if str(coach.explain(state, 5, "ru").get("status")) != "completed":
        _fail("Actual successful diagnosis must have a specific review state")
        return
    print("W21 EXPLAINABLE COACH PASS: three faults, two languages, real interlock, wrong-view penalty, completion and progressive UI")
    scene.queue_free()
    quit(0)
