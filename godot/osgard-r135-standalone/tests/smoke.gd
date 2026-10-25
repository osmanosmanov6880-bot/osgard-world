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
    if int(stage_budget.get("detail_draw_batches", -1)) != 3 or int(stage_budget.get("detail_instances", -1)) != 47:
        _fail("W15 industrial rivets and safety marks must be batched and bounded")
        return
    for path in ["W15RearWallFasteners", "W15DeckFasteners", "W15DeckBoundaryMarks"]:
        var detail_node: Node = studio.get_node_or_null(path)
        if not (detail_node is MultiMeshInstance3D):
            _fail("W15 premium service-stage detail not instanced: " + path)
            return
    if float(stage_budget.get("fastener_roughness", -1.0)) < 0.65:
        _fail("W15 ECO finish must remain matte and mobile-friendly")
        return
    if studio.get_node_or_null("W18OverheadServiceRail") == null or int(stage_budget.get("single_mesh_nodes", -1)) != 8:
        _fail("W18 portrait industrial wall/overhead architecture should be visible with only 8 single meshes")
        return
    if int(stage_budget.get("single_mesh_nodes", 99)) > 8 or not bool(stage_budget.get("visual_only", false)):
        _fail("W7 premium environment exceeds simple geometry budget")
        return
    var language_control: Button = instance.get("language_button") as Button
    if language_control == null or language_control.name != "SwitchLanguage":
        _fail("W17 language control missing")
        return
    var operator_buttons: Array = instance.get("action_buttons")
    if operator_buttons.size() != 8:
        _fail("W17 localization must preserve eight operator controls")
        return
    instance.call("_set_locale", "ru")
    if str(instance.get("ui_locale")) != "ru" or operator_buttons[0].text != "НАЧАТЬ":
        _fail("W17 Russian control switch failed")
        return
    if str(instance.call("_translated", "VIEW OVERVIEW")) != "РАКУРС ОБЗОР":
        _fail("W17 locale dictionary damaged composite camera labels")
        return
    var translated_line: String = str(instance.call("_translated",
        "PRESS START MISSION | OPTICAL ALIGNMENT | EDGE OFFSET +0.7 (SIM)"))
    if translated_line.contains("PRESS START") or translated_line.contains("OPTICAL ALIGNMENT") or translated_line.contains("EDGE OFFSET"):
        _fail("W17 visible initial feedback or fault names leaked English")
        return
    if not translated_line.contains("НАЧНИ ОБУЧЕНИЕ") or not translated_line.contains("СМЕЩЕНИЕ КРАЯ"):
        _fail("W17 Russian learning instructions must carry the actual meaning")
        return
    var safety: Label = instance.get("safety_notice") as Label
    if safety == null or not safety.text.contains("проверки отсутствия энергии"):
        _fail("W17 Russian energy isolation warning missing")
        return
    instance.call("_set_locale", "en")
    if operator_buttons[0].text != "START MISSION" or not safety.text.contains("SIMULATION ONLY"):
        _fail("W17 restored English controls/notice failed")
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
    var hero_stage: Dictionary = studio.call("render_budget")
    if int(hero_stage.get("stage_quality", -1)) != 2 or float(hero_stage.get("fastener_roughness", 1.0)) > 0.48:
        _fail("W15 HERO material finish was not applied to the actual stage")
        return
    if float(hero_stage.get("accent_emission", -1.0)) <= float(stage_budget.get("accent_emission", 99.0)):
        _fail("W15 ECO/HERO accent budget did not change")
        return
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
    # W13: the tutorial MUST NOT teach opening a running machine.
    # Verify the actual service hatch travel and universal interlocks, not
    # just a mission-step counter or a descriptive UI label.
    instance.call("_start_mission")
    var started: Dictionary = rig.call("summary")
    if not bool(started.get("mission_active", false)) or int(started.get("mission_step", -1)) != 0:
        _fail("W13 mission did not reset to safety-first stop-drive step")
        return
    if float(started.get("lid_progress", 9.0)) > 0.05 or not bool(started.get("motion_enabled", false)):
        _fail("W13 scenario reset must close the simulated hatch before motor runs")
        return
    instance.call("_toggle_hatch") # Unsafe order: hatch before stopping motor.
    var blocked_hatch: Dictionary = rig.call("summary")
    if int(blocked_hatch.get("mission_step", -1)) != 0 or float(blocked_hatch.get("lid_target", 9)) > 0.05:
        _fail("W13 tutorial incorrectly permitted opening moving machinery")
        return
    if not str(blocked_hatch.get("mission_feedback", "")).contains("SAFETY INTERLOCK"):
        _fail("W13 unsafe input must explain why it was rejected")
        return
    instance.call("_toggle_motion") # Stop drive FIRST.
    if int(rig.call("summary").get("mission_step", -1)) != 1 or bool(rig.call("summary").get("motion_enabled", true)):
        _fail("W13 pause-before-hatch checkpoint failed")
        return
    instance.call("_toggle_hatch") # Safe open.
    if int(rig.call("summary").get("mission_step", -1)) != 2:
        _fail("W13 hatch-opening checkpoint failed")
        return
    for tick in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    if float(rig.call("summary").get("lid_progress", 0)) < 0.95:
        _fail("W13 service hatch did not physically open")
        return
    instance.call("_toggle_motion") # Unsafe restart must fail.
    if bool(rig.call("summary").get("motion_enabled", true)) or int(rig.call("summary").get("mission_step", -1)) != 2:
        _fail("W13 tutorial restarted while hatch was open")
        return
    instance.call("_toggle_hatch") # Close safely.
    if int(rig.call("summary").get("mission_step", -1)) != 3:
        _fail("W13 hatch-closing checkpoint failed")
        return
    instance.call("_toggle_motion") # Unsafe restart while lid is still closing.
    if bool(rig.call("summary").get("motion_enabled", true)):
        _fail("W13 tutorial drive restarted before hatch fully sealed")
        return
    for tick in range(125):
        rig.call("_physics_process", 1.0 / 60.0)
    if float(rig.call("summary").get("lid_progress", 9)) > 0.05:
        _fail("W13 simulated hatch did not reach fully sealed state")
        return
    instance.call("_toggle_motion")
    var complete: Dictionary = rig.call("summary")
    if not bool(complete.get("mission_completed", false)) or int(complete.get("mission_step", 0)) != 4:
        _fail("W13 safety-first service training failed: " + str(complete))
        return
    if not bool(complete.get("motion_enabled", false)) or float(rig.get("lid_target")) > 0.05:
        _fail("W13 lesson completed with unsafe simulated state")
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
    # W14: case-specific progress persisted, without inventing legacy history.
    if int(completed_learning.get("record_schema_version", 0)) != 2:
        _fail("W14 progress schema must be version 2")
        return
    var attempts: Array = completed_learning.get("case_attempts", [])
    var scores: Array = completed_learning.get("case_best_scores", [])
    var seconds: Array = completed_learning.get("case_best_seconds", [])
    var mistakes: Array = completed_learning.get("case_total_mistakes", [])
    if attempts.size() != 3 or scores.size() != 3 or seconds.size() != 3 or mistakes.size() != 3:
        _fail("W14 progress must track exactly three independent faults")
        return
    for i in range(3):
        if int(attempts[i]) < 1 or int(scores[i]) <= 0 or float(seconds[i]) <= 0.0:
            _fail("W14 independent case progress was not recorded: " + str(completed_learning))
            return
    if int(mistakes[0]) < 3 or not bool(completed_learning.get("local_record_save_ok", false)):
        _fail("W14 unsafe scenario errors were not saved")
        return
    var full_record := ConfigFile.new()
    if full_record.load("user://r135_challenge_record.cfg") != OK:
        _fail("W14 actual progress file missing after completing all three faults")
        return
    if int(full_record.get_value("progress", "schema_version", 0)) != 2:
        _fail("W14 actual file not migrated to schema v2")
        return
    var restored: Node = preload("res://R135ServiceDirector.gd").new()
    restored.call("_load_challenge_record")
    for i in range(3):
        if int(restored.get("case_attempts")[i]) != int(attempts[i]) or int(restored.get("case_best_scores")[i]) != int(scores[i]):
            _fail("W14 persisted per-fault data changed after a genuine reload")
            return
    restored.free()
    # Independent legacy test: schema v1 only had best_score + cleared_cases.
    var legacy := ConfigFile.new()
    legacy.set_value("progress", "best_score", 95)
    legacy.set_value("progress", "cleared_cases", [true, false, true])
    if legacy.save("user://r135_challenge_record.cfg") != OK:
        _fail("W14 cannot write isolated legacy migration fixture")
        return
    var migrated: Node = preload("res://R135ServiceDirector.gd").new()
    migrated.call("_load_challenge_record")
    var migrated_attempts: Array = migrated.get("case_attempts")
    var migrated_cleared: Array = migrated.get("cleared_cases")
    if int(migrated.get("challenge_best_score")) != 95 or migrated_cleared != [true, false, true]:
        _fail("W14 legacy best score/case flags changed during migration")
        return
    if migrated_attempts != [0, 0, 0]:
        _fail("W14 invented per-fault attempts in legacy save")
        return
    migrated.free()
    # Corrupted local numeric arrays must clamp/recover, never inject fake
    # attempts/scores or throw while opening the simulation.
    var corrupt := ConfigFile.new()
    corrupt.set_value("progress", "best_score", "INVALID")
    corrupt.set_value("progress", "cleared_cases", "NOT_AN_ARRAY")
    corrupt.set_value("progress", "case_attempts", ["bad", -8, 9999999])
    corrupt.set_value("progress", "case_best_scores", [10000, -5, 32])
    corrupt.set_value("progress", "case_best_seconds", [-40.0, 3.5, "invalid"])
    corrupt.set_value("progress", "case_total_mistakes", [0, 9999999999, "bad"])
    if corrupt.save("user://r135_challenge_record.cfg") != OK:
        _fail("W14 could not create a malformed local record fixture")
        return
    var cleaned: Node = preload("res://R135ServiceDirector.gd").new()
    cleaned.call("_load_challenge_record")
    if int(cleaned.get("challenge_best_score")) != 0 or cleaned.get("case_attempts") != [0, 0, 1000000]:
        _fail("W14 malformed attempt scores were not sanitized")
        return
    if cleaned.get("case_best_scores") != [150, 0, 32] or cleaned.get("case_total_mistakes") != [0, 1000000, 0]:
        _fail("W14 out-of-range scores or mistakes were not clamped")
        return
    if cleaned.get("case_best_seconds") != [-1.0, 3.5, -1.0]:
        _fail("W14 bad finish times did not preserve unknown sentinel")
        return
    cleaned.free()
    if full_record.save("user://r135_challenge_record.cfg") != OK:
        _fail("W14 could not restore real progress after migration fixture")
        return
    print("R135 W14 SMOKE PASS: original 3D, three lessons, diagnostic scoring, safety interlocks, camera scan, 8 buttons")
    quit(0)
