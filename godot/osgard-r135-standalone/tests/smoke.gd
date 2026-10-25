extends SceneTree
## Fails closed: a parser error, missing GLB, or dead control breaks the build.
func _initialize() -> void:
    call_deferred("_run")

func _fail(message: String) -> void:
    push_error("R135 SMOKE FAILED: " + message)
    quit(1)

func _run() -> void:
    var packed: Resource = load("res://Main.tscn")
    if not (packed is PackedScene):
        _fail("Main.tscn did not import")
        return
    var instance: Node = (packed as PackedScene).instantiate()
    if instance == null:
        _fail("Main.tscn did not instantiate")
        return
    root.add_child(instance)
    await process_frame
    await process_frame
    var rig: Node = instance.get_node_or_null("R135ServiceSpine")
    if rig == null:
        _fail("R135ServiceSpine controller missing")
        return
    var fill: Node = instance.get_node_or_null("R135_ReadableInspectionFill_NoShadows")
    if not (fill is OmniLight3D) or float(fill.get("light_energy")) < 3.5 or bool(fill.get("shadow_enabled")):
        _fail("W11 readable ECO fill must be strong and must never cast costly shadows")
        return
    var studio: Node = instance.get_node_or_null("R135StudioEnvironment")
    if studio == null:
        _fail("W7 premium batched stage missing")
        return
    var stage_budget: Dictionary = studio.call("render_budget")
    if int(stage_budget.get("grid_draw_batches", -1)) != 2 or int(stage_budget.get("grid_instances", -1)) != 18:
        _fail("W7 floor must use two draw batches for all 18 grid strips")
        return
    if int(stage_budget.get("single_mesh_nodes", 99)) > 8 or not bool(stage_budget.get("visual_only", false)):
        _fail("W7 premium environment exceeds simple geometry budget")
        return
    var first: Dictionary = rig.call("summary")
    if int(first.get("loading_failures", 0)) != 0 or int(first.get("load_count", 0)) < 1:
        _fail("ECO mesh did not load: " + str(first))
        return
    if not str(first.get("loaded","")).ends_with("service_spine_eco.glb"):
        _fail("ECO boot preset not selected")
        return
    instance.call("_toggle_quality")
    await process_frame
    var second: Dictionary = rig.call("summary")
    if int(second.get("loading_failures", 0)) != 0:
        _fail("HERO mesh failed: " + str(second))
        return
    if not str(second.get("loaded","")).ends_with("service_spine_hero.glb"):
        _fail("HERO preset did not load")
        return
    instance.call("_toggle_motion")
    if bool(rig.call("summary").get("motion_enabled", true)):
        _fail("Pause control did not stop mechanism")
        return
    instance.call("_toggle_hatch")
    if int(rig.call("summary").get("inspect_count", 0)) < 1:
        _fail("Hatch action did not register")
        return
    instance.call("_toggle_quality")
    await process_frame
    var final: Dictionary = rig.call("summary")
    if int(final.get("loading_failures", 0)) != 0 or int(final.get("load_count", 0)) < 3:
        _fail("HERO-ECO-HERO switching failed: " + str(final))
        return
    # A player must be able to complete a deterministic, four-action mission.
    # Out-of-order input changes the rig but MUST NOT unlock fake mission progress.
    instance.call("_start_mission")
    var opened: Dictionary = rig.call("summary")
    if not bool(opened.get("mission_active", false)) or int(opened.get("mission_step", -1)) != 0:
        _fail("Mission did not reset correctly")
        return
    instance.call("_toggle_motion") # Wrong order: pause before opening hatch.
    if int(rig.call("summary").get("mission_step", -1)) != 0:
        _fail("Out-of-order pause advanced the mission")
        return
    instance.call("_toggle_motion") # Resume before beginning the correct sequence.
    instance.call("_toggle_hatch")
    if int(rig.call("summary").get("mission_step", -1)) != 1:
        _fail("Opening the hatch did not clear the first checkpoint")
        return
    instance.call("_toggle_motion")
    if int(rig.call("summary").get("mission_step", -1)) != 2:
        _fail("Pausing the drive did not clear the second checkpoint")
        return
    instance.call("_toggle_hatch")
    if int(rig.call("summary").get("mission_step", -1)) != 3:
        _fail("Closing the hatch did not clear the third checkpoint")
        return
    instance.call("_toggle_motion")
    var complete: Dictionary = rig.call("summary")
    if not bool(complete.get("mission_completed", false)) or int(complete.get("mission_step", 0)) != 4:
        _fail("Full four-step mission did not complete: " + str(complete))
        return
    if not bool(complete.get("motion_enabled", false)) or float(rig.get("lid_target")) > 0.5:
        _fail("Mission completed with unsafe simulated state")
        return
    instance.call("_next_view")
    if int(instance.get("view_index")) != 1:
        _fail("NEXT VIEW did not select the service deck")
        return
    instance.call("_next_view")
    if int(instance.get("view_index")) != 2:
        _fail("NEXT VIEW did not select the optical head")
        return
    instance.call("_reset_view")
    if int(instance.get("view_index")) != 0:
        _fail("RESET VIEW did not return to overview")
        return
    var operator_controls: Node = instance.get_node_or_null("R135ResponsiveOperatorHUD/OperatorControls")
    if operator_controls == null:
        _fail("Responsive mission controls missing")
        return
    # W4 advanced diagnostics, all five ordered steps plus real hatch movement.
    instance.call("_start_challenge")
    var begin: Dictionary = rig.call("summary")
    if not bool(begin.get("challenge_active", false)) or int(begin.get("challenge_step", -1)) != 0:
        _fail("Advanced challenge did not initialize")
        return
    if int(begin.get("challenge_target_view", -1)) != 2:
        _fail("Optical target expected on first diagnostic attempt")
        return
    instance.call("_toggle_hatch") # Safety interlock: cannot open while moving.
    var blocked: Dictionary = rig.call("summary")
    if float(blocked.get("lid_target", 9)) != 0.0 or int(blocked.get("challenge_errors", -1)) != 1:
        _fail("Interlock failed to reject unsafe moving hatch")
        return
    instance.call("_toggle_motion") # Stop
    if int(rig.call("summary").get("challenge_step", -1)) != 1:
        _fail("Diagnostic stop drive checkpoint missed")
        return
    instance.call("_toggle_hatch") # Open
    if int(rig.call("summary").get("challenge_step", -1)) != 2:
        _fail("Diagnostic open hatch checkpoint missed")
        return
    instance.call("_scan_component") # Premature opening: reject.
    if int(rig.call("summary").get("challenge_step", -1)) != 2:
        _fail("Scan incorrectly accepted while hatch moving")
        return
    for tick in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    if float(rig.call("summary").get("lid_progress", 0)) < 0.95:
        _fail("Hatch did not reach fully open during diagnostic sequence")
        return
    instance.call("_apply_view", 1)
    instance.call("_scan_component") # Wrong camera target.
    if int(rig.call("summary").get("challenge_step", -1)) != 2:
        _fail("Wrong camera accepted as a diagnostic scan")
        return
    instance.call("_apply_view", 2)
    instance.call("_scan_component") # Correct optical fault target.
    if int(rig.call("summary").get("challenge_step", -1)) != 3:
        _fail("Correct optical scan did not clear the fault")
        return
    instance.call("_toggle_hatch") # Close
    if int(rig.call("summary").get("challenge_step", -1)) != 4:
        _fail("Diagnostic hatch closing checkpoint missed")
        return
    instance.call("_toggle_motion") # Attempt unsafe restart while lid still closing.
    if bool(rig.call("summary").get("motion_enabled", true)):
        _fail("Diagnostic drive restarted before hatch fully closed")
        return
    for tick in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    if float(rig.call("summary").get("lid_progress", 9)) > 0.05:
        _fail("Hatch did not seal after diagnostic action")
        return
    instance.call("_toggle_motion") # Resume only when sealed.
    var complete_challenge: Dictionary = rig.call("summary")
    if not bool(complete_challenge.get("challenge_completed", false)) or int(complete_challenge.get("challenge_step", 0)) != 5:
        _fail("Five-stage diagnostic challenge did not complete")
        return
    if int(complete_challenge.get("challenge_score", 0)) <= 0 or int(complete_challenge.get("challenge_best_score", 0)) <= 0:
        _fail("Diagnostic score or persistent record was not recorded")
        return
    if int(complete_challenge.get("challenge_errors", 0)) < 3:
        _fail("Deliberate safety, premature scan and wrong-view penalties were not counted")
        return
    instance.call("_start_challenge")
    if int(rig.call("summary").get("challenge_fault_index", -1)) != 1:
        _fail("A new challenge did not cycle to cooling fault scenario")
        return
    var controls: Node = operator_controls.get_child(0)
    if controls.get_child_count() != 8:
        _fail("Expected eight real operator buttons for both gameplay modes")
        return
    # W5: three in-world indicators, one linked to actual moving optical head.
    var indicators: Node = rig.get_node_or_null("R135SimulatedFaultIndicators")
    rig.call("set_reduced_motion", true)
    if indicators == null or not bool(indicators.get("reduced_motion")):
        _fail("W7 accessibility setting did not reach active fault renderer")
        return
    rig.call("set_reduced_motion", false)
    if indicators == null or indicators.get_child_count() != 2:
        _fail("W5 world fault indicator scene is missing")
        return
    instance.call("_apply_view", 2)
    var portrait_distance: float = float(instance.get("camera_effective_distance"))
    instance.call("_apply_view", 0)
    if portrait_distance < 5.5:
        _fail("W5 optical framing is inside the rig")
        return
    if int(rig.call("summary").get("fault_marker_count", -1)) != 3:
        _fail("W5 must expose three 3D fault markers")
        return
    var optic_marker: Node = rig.get_node_or_null("R135_BridgeDrive_16s_Cycle_SIMULATION/Vertical_Optical_Service_Head/SimulatedFault_OPTICAL_01")
    if optic_marker == null:
        _fail("Optical visual target is not parented to the moving optical head")
        return
    # Exercise cooling and service diagnostics too (W4 browser smoke covered
    # optical only). Every scenario must be playable through 5 actual actions.
    for expected_fault in [1, 2]:
        var fault_state: Dictionary = rig.call("summary")
        if int(fault_state.get("challenge_fault_index", -1)) != expected_fault:
            _fail("Expected W5 scenario index %d: %s" % [expected_fault, str(fault_state)])
            return
        var target: int = 3 if expected_fault == 1 else 1
        if int(fault_state.get("challenge_target_view", -1)) != target:
            _fail("Incorrect camera target in W5 scenario")
            return
        rig.call("set_motion", false)
        rig.call("toggle_access_lid")
        for tick in range(125):
            rig.call("_physics_process", 1.0 / 60.0)
        if int(rig.call("summary").get("fault_marker_active_index", -1)) != expected_fault:
            _fail("W5 target indicator did not follow the scenario")
            return
        rig.call("scan_diagnostic", target)
        rig.call("_physics_process", 1.0 / 60.0)
        if int(rig.call("summary").get("challenge_step", -1)) != 3 or str(rig.call("summary").get("fault_visual_state")) != "inspected":
            _fail("W5 fault scan or 3D inspection indicator failed")
            return
        rig.call("toggle_access_lid")
        for tick in range(125):
            rig.call("_physics_process", 1.0 / 60.0)
        rig.call("set_motion", true)
        var done: Dictionary = rig.call("summary")
        if not bool(done.get("challenge_completed", false)) or int(done.get("challenge_step", -1)) != 5:
            _fail("W5 advanced scenario failed: " + str(done))
            return
        if expected_fault == 1:
            instance.call("_start_challenge")
    var completed_learning: Dictionary = rig.call("summary")
    if int(completed_learning.get("cleared_case_count", -1)) != 3:
        _fail("W9 lesson progress must record three distinct simulated cases")
        return
    if int(completed_learning.get("challenge_error_penalty", -1)) != 12 * int(completed_learning.get("challenge_errors", -2)):
        _fail("W9 diagnosis penalty explanation must match recorded errors")
        return
    if not str(completed_learning.get("challenge_evidence", "")).contains("(SIM)"):
        _fail("W9 evidence must explicitly be marked simulation-only")
        return
    print("R135 SMOKE PASS: original 3D, three lessons, diagnostic scoring, safety interlocks, camera scan, 8 buttons")
    quit(0)
