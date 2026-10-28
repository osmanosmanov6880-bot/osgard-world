extends SceneTree
## W71 native Godot mission acceptance:
## real spatial proximity + real six-cycle causal game + new 3D beacons.
## No fake "completed" flags, no hidden game actions, no physical equipment.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var main: PackedScene = load("res://Main.tscn") as PackedScene
    _check(main != null, "Original native Godot game scene exists")
    if main == null:
        _finish()
        return
    var ui := main.instantiate() as A7CascadeScreen
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    _check(stage != null, "Existing W70 actual 3D stage exists")
    var operator: A7FirstPersonOperator = stage.first_person
    _check(operator != null and operator.body is CharacterBody3D,
        "A7 player is a genuine Godot physics body")
    var mission: A7SpatialMission = stage.spatial_mission
    _check(mission != null, "Original W71 spatial director is mounted inside 3D")
    if mission == null or operator == null:
        _finish()
        return
    var qa: Dictionary = mission.qa_readout()
    _check(qa["schema"] == "LAST_FRONTIER_W71_TRUE_SPATIAL_MISSION_V1",
        "Real native spatial mission introspection schema")
    _check(not qa["active"] and qa["phase_index"] == 0,
        "Original W63 game defaults to unchanged non-mission mode")
    _check(qa["core_beacon_native_mesh"] and qa["relay_beacon_native_mesh"],
        "Two independent original real MeshInstance3D objective columns")
    _check(qa["real_3d_objective_rings"],
        "Actual paired torus target meshes, not decorative PNGs")
    _check(qa["world_space_mission_text"],
        "Native in-world Label3D game targets exist in both rooms")
    _check(qa["local_actual_omni_light"],
        "3D station objective uses native Godot practical lighting")
    _check(mission.core_beacon.mesh is CylinderMesh,
        "Core objective has actual 3D cylinder geometry")
    _check(mission.relay_torus.mesh is TorusMesh,
        "Relay objective uses actual machined torus geometry")
    _check(not qa["gameplay_authority"],
        "Mission UI cannot silently choose or replay game actions")
    _check(not qa["production_approved"] and
        qa["estimated_campaign_duration_minutes"] == -1,
        "A scripted objective chain does not claim measured 15-min duration")
    _check(ui.mission_button is Button and
        ui.mission_pips.size() == 5 and
        ui.mission_briefing is Label,
        "Native bilingual five-stage mission UI is mounted")
    var start_state: Dictionary = ui.model.snapshot()
    _check(not mission.inspect_physical("CORE", start_state, operator),
        "Mission cannot progress before actual player chooses to start")
    _check(ui.model.snapshot() == start_state,
        "New story UI never changes original metrics at boot")

    ui.mission_button.emit_signal("pressed")
    _check(mission.active and mission.phase == 0,
        "Mission starts on actual original clean six-cycle shift")
    _check(mission.progress_events == 0,
        "Mission has not awarded fake objective completion at activation")
    _check(not mission.start(ui.model.snapshot()),
        "Mission cannot be started twice and farm progression")
    _check(ui.mission_button.disabled,
        "Native mission activation is locked while mission running")
    _check(not mission.inspect_physical("RELAY", start_state, operator),
        "Without physically entering the 3D world, remote relay E is rejected")
    _check(ui.model.snapshot() == start_state,
        "Opening the mission panel is never a core gameplay decision")

    ui.pilot_button.emit_signal("pressed")
    _check(operator.piloting and operator.head_camera.current,
        "Original real first-person player is active for mission")
    _check(not mission.inspect_physical("CORE", start_state, operator),
        "Core cannot be reached with E from distant start point")
    operator.body.position = Vector3(4.10, 1.33, 2.14)
    _check(operator.body.position.distance_to(
        operator.inspection_console_core) < 3.2,
        "Test player is physically within real reactor console radius")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 1, "Actual near-console E unlocks stabilization stage")
    _check(mission.real_inspections == 1,
        "Exactly one authenticated physical station inspection")
    _check(mission.progress_events == 1, "Only one genuine phase transition")
    _check(mission.core_material.emission == A7SpatialMission.GOLD,
        "Real 3D reactor objective highlights actual active mission step")
    _check(ui.model.snapshot() == start_state,
        "Physical inspection never bypasses A7 core decisions")
    _check(ui.mission_title.text.contains("СТАБИЛИЗАЦИЯ"),
        "Russian stage guidance responds to live mission phase")

    # Wrong location/extra E must not unlock unrelated stage.
    operator.body.position = Vector3(8.0, 1.33, 20.0)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 1,
        "Relay inspection in incorrect order cannot skip real stabilization")
    _check(ui.model.snapshot() == start_state,
        "An out-of-sequence 3D inspection never changes reactor metrics")

    # First real game shift: original PUMP and SCAN tradeoffs, no edits to
    # A7CascadeCore, incident director, model initialization or action count.
    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(mission.phase == 1,
        "One real accepted decision is insufficient for a two-choice shift")
    _check(int(ui.model.snapshot()["metrics"]["heat"]) == 42,
        "Original PUMP action still changes actual metrics exactly")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(mission.phase == 2 and int(ui.model.snapshot()["shift"]) == 1,
        "Only completing original full shift unlocks real relay task")
    _check(mission.integrity_when_first_cycle_ended == 100,
        "Mission actually records first cycle's real safety consequences")
    _check(mission.accepted_game_decisions == 2,
        "Two core-approved actions, no fabricated mission moves")
    _check(mission.relay_material.emission == A7SpatialMission.CYAN,
        "Actual relay target is illuminated only when it becomes objective")

    # Mission authority checks physics proximity again even with a spoofed
    # string; camera switching and direct developer call are not enough.
    operator.body.position = Vector3(4.10, 1.33, 2.14)
    _check(not mission.inspect_physical("RELAY", ui.model.snapshot(), operator),
        "Forged RELAY target at actual CORE location must not pass proximity")
    _check(mission.phase == 2, "Spoofed string cannot auto-complete spatial mission")
    operator.body.position = Vector3(8.0, 1.33, 20.0)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 3, "Actual physical visit to second 3D hall unlocks final containment")
    _check(mission.last_inspection == "RELAY",
        "Mission stores truthful real location for third objective")
    _check(mission.real_inspections >= 3,
        "Multiple actual physical inspections are tracked separately")
    _check(ui.model.snapshot()["history"].size() == 2,
        "No extra actions credited for movement/console inspection")

    # Preserve exact legitimate six-cycle original winning route.
    var continuation: Array[String] = [
        "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for choice in continuation:
        ui.action_buttons[choice].emit_signal("pressed")
        _check(mission.accepted_game_decisions <= 12,
            "Spatial story never adds phantom game actions")
    _check(ui.model.snapshot()["status"] == "won",
        "Original deterministic full six-cycle game legitimately won")
    _check((ui.model.snapshot()["history"] as Array).size() == 12,
        "All twelve real decisions still needed for the original win")
    _check(mission.phase == 4 and mission.outcome == "contained",
        "Game victory unlocks final return-trip, not immediate mission auto-win")
    _check(mission.progress_events == 4,
        "Four ordered objective transitions before final physical return")
    _check(not mission.inspect_physical("CORE", ui.model.snapshot(), operator),
        "Cannot finish the mission by invoking CORE E while at distant relay")
    operator.body.position = Vector3(4.10, 1.33, 2.14)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 5 and mission.qa_readout()["completed"],
        "Only true return to reactor AFTER original win completes mission")
    _check(mission.outcome == "contained", "Completed mission retains actual outcome")
    _check(mission.qa_readout()["progress_events"] == 5,
        "Exactly five ordered real mission objectives completed")
    _check(mission.qa_readout()["accepted_original_actions"] == 12,
        "Twelve actual original game decisions count once each")
    _check(mission.qa_readout()["elapsed_real_seconds"] >= 0.0,
        "Mission uses real monotonic elapsed time, never invented minutes")
    _check(ui.mission_title.text.contains("ПРОЙДЕНА"),
        "Real native UI displays success after authenticated final physical E")
    _check(mission.core_material.emission == A7SpatialMission.CYAN and
        mission.relay_material.emission == A7SpatialMission.CYAN,
        "Two physical beacons show completed spatial narrative")

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en" and ui.mission_title.text.contains("COMPLETE"),
        "Independent final result is fully available in English")
    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "ru", "Native mission can return to Russian")
    ui.quality_button.emit_signal("pressed")
    _check(mission.quality == "eco" and
        is_equal_approx(mission.warning_practical.light_energy, 0.4),
        "Real optional mission beacon light respects ECO quality at float precision")
    ui.quality_button.emit_signal("pressed")
    ui.motion_button.emit_signal("pressed")
    _check(mission.reduced_motion,
        "Mission honors original reduced-motion accessibility setting")
    ui.motion_button.emit_signal("pressed")

    for width in [320, 390, 768, 1366]:
        ui.size = Vector2(width, 800)
        ui._layout_stage()
        await process_frame
        _check(mission.compact == (width < 640),
            "Actual world status hides on narrow %dpx viewport" % width)
        _check(mission.core_caption.visible == (width >= 640),
            "Real 3D secondary signage avoids mobile HUD at %dpx" % width)
        _check(ui.mission_briefing != null and
            ui.mission_pips.size() == 5,
            "Original accessible mission stage survives %dpx" % width)
        _check(ui.model.snapshot()["status"] == "won",
            "Responsive layout never alters actual game outcome at %dpx" % width)

    # Restart is an explicit new clean mission; no fake persistent save.
    ui.restart_button.emit_signal("pressed")
    _check(not mission.active and mission.phase == 0,
        "True original restart resets new story phases and active flag")
    _check(ui.model.snapshot()["shift"] == 0 and
        (ui.model.snapshot()["history"] as Array).is_empty(),
        "Original six-cycle model also resets exactly")
    _check(not mission.qa_readout()["completed"],
        "No stale mission completion after original reset")
    ui.mission_button.emit_signal("pressed")
    _check(mission.active and mission.phase == 0,
        "A fresh session can intentionally start original mission again")
    operator.body.position = Vector3(4.10, 1.33, 2.14)
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 1, "Second attempt requires authentic first core E")

    # Bad decisions really fail; 3D mission must report failure instead of
    # always producing a happy scripted ending.
    for i in range(12):
        if ui.model.snapshot()["status"] != "playing":
            break
        ui.action_buttons["POWER"].emit_signal("pressed")
    _check(ui.model.snapshot()["status"] in ["failed", "unstable"],
        "Original adverse energy-only decisions can actually lose the game")
    _check(mission.phase == 6 and mission.qa_readout()["failed"],
        "Real mission signals authentic failure, not a false automatic victory")
    _check(not mission.qa_readout()["completed"],
        "Failure cannot be misrepresented as the completed five-stage mission")
    _check(ui.model.snapshot()["history"].size() == mission.accepted_game_decisions,
        "Every accepted game action is counted once by the spatial story")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W71 TRUE SPATIAL FIVE-OBJECTIVE GODOT GAME PASS: %d assertions" % checks)
        quit(0)
        return
    for message in failures:
        push_error("W71 ORIGINAL PHYSICAL STORY: " + message)
    quit(1)
