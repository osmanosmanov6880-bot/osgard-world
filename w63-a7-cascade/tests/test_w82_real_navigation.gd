extends SceneTree
## W82 genuine mobile navigation: source-only, no teleport/choose.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    checks += 1
    if not ok:
        failures.append(message)

func _run() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _check(scene != null,"Original real A7 Godot Main.tscn must load")
    if scene == null:
        _end()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size = Vector2(390,844)
    await process_frame
    await process_frame
    var body: A7FirstPersonOperator = ui.stage_3d.first_person
    var mission: A7SpatialMission = ui.stage_3d.spatial_mission
    var equipment: A7FieldOperations = ui.stage_3d.field_operations
    var initial_game: Dictionary = ui.model.snapshot()
    var hud: A7MissionNavCockpit = ui.w82_nav_cockpit
    _check(hud != null and not hud.visible,
        "Navigation cockpit hidden until original physical mission starts")
    _check(hud.physical_operator == body and
        hud.original_mission == mission and hud.original_equipment == equipment,
        "HUD reads same original source objects; never owns replacement mechanics")
    ui.w76_play_button.emit_signal("pressed")
    await process_frame
    await process_frame
    hud._paint()
    _check(hud.visible and ui.w80_full_bleed.active,
        "Actual Godot full-bleed first person mounts readable navigation")
    _check(mission.phase==0 and hud.goal_kind=="core",
        "Real W71 reactor phase correctly selects original physical core station")
    _check(hud.goal_distance_m > 3.2 and not hud.physical_near,
        "Original live player starts genuinely too far from 3.2m core console")
    _check(hud.bearing_label.text.length()>0 and
        absf(hud.bearing_degrees)>0.01,
        "True Camera3D heading resolves source position into a directional cue")
    _check(hud.qa_readout()["real_player_body_id"] ==
        body.body.get_instance_id(),
        "True W70 CharacterBody3D instance identity displayed, no dummy player")
    _check(hud.qa_readout()["native_mouse_ignores_real_world_inputs"],
        "Source-only cockpit never intercepts native G/E, thumb or 3D clicks")
    _check(ui.model.snapshot()==initial_game and
        int(hud.qa_readout()["source_original_phase"])==0,
        "Drawing mission directions makes ZERO core decisions")
    var far_distance: float = hud.goal_distance_m
    body.body.position=Vector3(5.50,1.33,2.90)
    hud._paint()
    _check(hud.goal_distance_m < far_distance and hud.physical_near,
        "HUD reads actual native body proximity, never synthetic target distances")
    _check(hud.proximity_transitions >= 1,
        "Live source-triggered proximity status changed only at physical radius")
    _check(hud.status_label.text.contains("НАСТРОЙТЕ"),
        "True nearby unsolved equipment shows actual physical valve prompt")
    _check(ui.model.snapshot()==initial_game,
        "Physical HUD sampling does not advance original incident core")

    var target: int = equipment.valve_target
    for i in range(target):
        (ui.w79_mission_deck.slots[1] as Button).emit_signal("pressed")
    hud._paint()
    _check(equipment.valve_solved and hud.status_label.text.contains("E"),
        "Only genuinely calibrated original W72 valve earns in-world E prompt")
    (ui.w78_touch_overlay.controls["inspect"] as Button).emit_signal("pressed")
    await process_frame
    hud._paint()
    _check(mission.phase==1 and hud.goal_kind=="decisions",
        "Original actual E inspection transitions to source-led phase 1 decisions")
    _check(hud.goal_distance_m < 0.0 and not hud.physical_near,
        "Game decision phase does not pretend machine proximity is required")
    _check(ui.model.snapshot()==initial_game,
        "All real equipment/puzzle transitions preserve undecided core history")

    ui._toggle_locale()
    hud._paint()
    _check(hud.title_label.text.contains("DECISIONS") and
        hud.status_label.text.contains("ACTIONS LEFT"),
        "Both original localized mission and real navigation source use EN")
    for dimensions in [Vector2(320,700),Vector2(390,844),Vector2(844,390)]:
        ui.size=dimensions
        ui._layout_stage()
        await process_frame
        var stage: Rect2=ui.stage_shell.get_global_rect()
        var rect: Rect2=hud.frame.get_global_rect()
        var mission_rect: Rect2=ui.w79_mission_deck.panel.get_global_rect()
        _check(rect.position.x >= stage.position.x-2 and
            rect.end.x <= stage.end.x+2 and rect.end.y < mission_rect.position.y,
            "Readable original HUD inside and above mission buttons at %s" % dimensions)
        _check(ui.w82_nav_cockpit.visible and
            ui.w80_full_bleed.qa_readout()["original_real_3d_subviewport_unchanged"],
            "True original native SubViewport and nav survive actual orientation changes")
    ui.size=Vector2(1366,900)
    ui._layout_stage()
    await process_frame
    _check(hud.visible and not ui.w78_touch_overlay.visible,
        "Wide desktop HUD is readable without showing phone thumb grid")
    var source_before_exit: Dictionary = ui.model.snapshot()
    ui.w80_full_bleed.exit_button.emit_signal("pressed")
    await process_frame
    _check(not hud.visible and not ui.w80_full_bleed.active,
        "Real MENU removes in-world cockpit and restores existing source UI")
    _check(ui.model.snapshot()==source_before_exit,
        "Exiting fullscreen cannot create, undo or fabricate original decisions")
    _check(hud.qa_readout()["never_mutates_original_gameplay"] and
        not hud.qa_readout()["physical_phone_hardware_verified"],
        "Software HUD never claims phone test or action authority")
    ui.queue_free()
    await process_frame
    _end()

func _end() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W82 REAL WORLD MISSION COMPASS AND REACHABILITY PASS: %d source checks" % checks)
        quit(0)
        return
    for why in failures:
        push_error("W82 ORIGINAL GODOT NAV: "+why)
    quit(1)
