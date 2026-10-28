extends SceneTree
## IRON PULSE V9: spatial hazard simulation + costly, persistent field choices.
## Source-driven gameplay, no scene screenshot approximation.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(value: bool,label: String) -> void:
    checks += 1
    if not value:
        failures.append(label)

func _run() -> void:
    var fields := IPContainmentRun.new()
    root.add_child(fields)
    await process_frame
    _check(fields.interaction_points.size() == 3,
        "Three actual world-placed safety consoles with real mesh objects")
    _check(fields.readout()["physical_arches"] == 3 and fields.seals.is_empty(),
        "Three danger arches are visible while all safety seals are unused")
    for i in range(3):
        var item: Dictionary = fields.interaction_points[i]
        var model: Node3D = item["node"]
        _check(model.get_node_or_null("PermanentConsoleBody") is MeshInstance3D,
            "An actual industrial seal control is in the Godot world: "+str(i))
        _check((item["arch"] as Node3D).visible,
            "Physical hazard arch is visible: "+str(i))
    _check(fields.zone_for_position(Vector3(0,1.1,-22.5)) == "reactor",
        "Real reactor danger uses player's true world position")
    _check(fields.zone_for_position(Vector3(0,1.1,-41.0)) == "service",
        "Service hazard has a distinct physical zone")
    _check(fields.zone_for_position(Vector3(0,1.1,-52.1)) == "evacuation",
        "Evacuation sector has distinct danger geography")
    _check(fields.zone_for_position(Vector3(0,1.1,2.0)) == "",
        "The real mission starting position is a safe briefing area")
    _check(fields.zone_for_position(Vector3(14,1.1,-22.5)) == "",
        "A distant camera in the atrium is not mistakenly treated as the player")

    var engine := IPCrisisEngine.new()
    engine.reset("thermal")
    _check(fields.step(4.0,Vector3(0,1.1,-22.5),engine) == "",
        "Hazard exposure cannot run on the intro screen before core scan")
    _check(is_equal_approx(fields.suit_integrity,100.0),
        "Starting suit integrity is untouched during briefing")
    engine.scan_core()
    engine.heat = 96.0
    var first_entry: String = fields.step(1.0,Vector3(0,1.1,-22.5),engine)
    _check(first_entry == "field_enter_reactor" and fields.suit_integrity < 98.0,
        "Entering REAL hot space triggers MARA cue and measurable suit damage")
    var after_entry: float = fields.suit_integrity
    _check(fields.step(1.0,Vector3(0,1.1,-22.5),engine) == "" and fields.suit_integrity < after_entry,
        "Staying in dangerous space causes continuing loss without spamming radio")

    var oxygen_before: float = engine.oxygen
    var elapsed_before: float = engine.elapsed
    _check(fields.activate_seal("reactor",engine), "Player may isolate the first physically risky section")
    _check(fields.seals == ["reactor"] and engine.last_event == "field_seal_reactor",
        "Safety seal is a persistent, localized gameplay decision")
    _check(engine.elapsed >= elapsed_before+6.99 and engine.oxygen < oxygen_before-4.0,
        "One seal really spends seven seconds of rescue time and six oxygen")
    _check(fields.risk_for("reactor","thermal",96,70) == 0.0,
        "Physical reactor hazard stops harming suit after successful isolation")
    var intact: float = fields.suit_integrity
    fields.step(1.0,Vector3(0,1.1,-22.5),engine)
    _check(is_equal_approx(intact,fields.suit_integrity),
        "Hardened reactor zone ceases to deal hidden player damage")
    _check(fields.interaction_points[0]["indicator"].material_override == fields._sealed_material,
        "Actual 3D console turns into sealed green safety state")

    engine.heat = 75.0
    _check(fields.activate_seal("service",engine), "A second distant safety corridor can be authorized")
    _check(fields.seals == ["reactor","service"] and fields.seals.size()==IPContainmentRun.MAX_SEALS,
        "Two-of-three physical safety channels enforce a consequential route choice")
    var third_attempt: int = engine.faults
    _check(not fields.activate_seal("evacuation",engine) and engine.faults == third_attempt+1,
        "Third safety seal is permanently unavailable and consumes no bonus")
    _check(fields.risk_for("evacuation","thermal",95,60) > 0.35,
        "Third evacuation route remains hazardous if player saved the first two")
    _check(not fields.activate_seal("reactor",engine), "No unlimited reactivation rewards")

    var saved: Dictionary = fields.checkpoint()
    var restored := IPContainmentRun.new()
    _check(restored.restore(saved), "Exact original field choices survive reliable checkpoint restore")
    _check(restored.seals == ["reactor","service"] and restored.suit_integrity == fields.suit_integrity,
        "Saved suit exposure and two purchased safety seals round-trip accurately")
    var tamper: Dictionary = saved.duplicate(true)
    tamper["seals"] = ["reactor","service","evacuation"]
    _check(not restored.restore(tamper) and restored.seals.size() == 2,
        "Forged third seal is rejected before partially mutating active state")
    tamper = saved.duplicate(true)
    tamper["seals"] = ["reactor","reactor"]
    _check(not restored.restore(tamper), "Duplicate free seal reward injection is blocked")
    tamper = saved.duplicate(true)
    tamper["suit"] = 105.0
    _check(not restored.restore(tamper), "Out-of-range suit integrity cannot enter valid offline save")
    tamper = saved.duplicate(true)
    tamper["suit"] = -1.0
    _check(not restored.restore(tamper), "Negative suit cannot be loaded to bypass failure")
    _check(restored.restore({}) and restored.seals.is_empty() and restored.suit_integrity == 100.0,
        "Existing V6/V7/V8.6 checkpoint without V9 fields restores as untouched suit")

    var collapse := IPContainmentRun.new()
    var lost := IPCrisisEngine.new()
    lost.reset("thermal")
    lost.scan_core()
    lost.heat = 96.0
    var final_event: String = ""
    for t in range(100):
        final_event = collapse.step(1.0,Vector3(0,1.1,-41.0),lost)
        if final_event == "suit_failure":
            break
    _check(final_event == "suit_failure" and collapse.suit_integrity <= 0.0,
        "Stationary operator in dangerous physical corridor can actually lose")
    _check(lost.fail_suit_integrity() and lost.lost and lost.last_event == "suit_failure",
        "Suit rupture genuinely ends the existing emergency mission, not a cosmetic label")
    _check(not lost.fail_suit_integrity() and lost.grade() == "UNRATED",
        "Suit-failure event cannot be falsely retriggered for rewards")

    var story := IPStoryDirector.new()
    story.reset("thermal")
    _check(story.on_game_event("field_enter_reactor","") and story.latest_key == "field_enter_reactor",
        "MARA authors real first environmental encounter")
    _check(story.on_game_event("field_seal_service","") and story.latest("ru")["text"].contains("изолирован"),
        "A player's successful safety choice receives contextual RU narrative")
    _check(story.on_game_event("field_budget","") and story.latest("en")["text"].contains("two"),
        "Lack of third seal is explained in English, not just a denied click")
    _check(story.on_game_event("suit_failure","") and story.latest_key == "suit_failure",
        "Real operator loss has a proper authored third-act consequence")
    fields.queue_free()
    restored.free()
    collapse.free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V9 SPATIAL CONTAINMENT PASS: %d deterministic gameplay/save checks" % checks)
        quit(0)
    else:
        for issue in failures:
            push_error("V9 SPATIAL FAIL: "+issue)
        quit(1)
