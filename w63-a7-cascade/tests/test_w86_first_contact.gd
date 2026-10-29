extends SceneTree
## W86: real FIRST CONTACT onboarding must reflect actual original physics,
## source camera, field guide and W73 checkpoint. Never fake a victory or
## use a screenshot proxy for original Godot 3D.

var assertions: int = 0
var failures: Array[String] = []

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures.append(label)

func _inside(item: Rect2, stage: Rect2) -> bool:
    return (item.size.x>=45 and item.size.y>=17 and
        item.position.x>=stage.position.x-2 and
        item.position.y>=stage.position.y-2 and
        item.end.x<=stage.end.x+2 and item.end.y<=stage.end.y+2)

func _not_overlapping(a: Control,b: Control) -> bool:
    return not a.get_global_rect().intersects(b.get_global_rect())

func _check_view(ui: A7CascadeScreen, width: int, height: int) -> void:
    ui.size = Vector2(width,height)
    ui._layout_stage()
    await process_frame
    await process_frame
    var c: A7FirstRunCoach=ui.w86_coach
    var stage: Rect2=ui.stage_shell.get_global_rect()
    _check(_inside(c.panel.get_global_rect(),stage),
        "W86 genuine Godot first-run panel fits original %dx%d 3D stage" %
        [width,height])
    _check(_inside(c.action_button.get_global_rect(),stage) and
        c.action_button.get_global_rect().size.y>=44.0,
        "W86 native SKIP/REPLAY click target >=44px inside original stage")
    _check(_inside(c.hint.get_global_rect(),stage) and
        _inside(c.headline.get_global_rect(),stage),
        "Genuine source onboarding text not cut off beyond actual stage")
    _check(_not_overlapping(c.panel,ui.w82_nav_cockpit.frame) and
        _not_overlapping(c.panel,ui.w80_full_bleed.exit_button),
        "W86 instructional panel does not obstruct W82 real compass or W80 MENU")
    _check(_not_overlapping(c.action_button,
        ui.w85_field_guide.entry_button) and
        _not_overlapping(c.action_button,ui.w84_studio.settings_button),
        "W86 only clickable control does not overlap original W84/W85 native controls")
    if width==844:
        _check(_not_overlapping(c.panel,ui.w79_mission_deck.panel),
            "Landscape W86 instructions must not cover original source choices")
    if width==320:
        _check(_not_overlapping(c.panel,ui.w85_field_guide.entry_button),
            "320px first-contact card cannot cover W85 HELP in its real narrow position")

func _run() -> void:
    var packed: PackedScene=load("res://Main.tscn") as PackedScene
    _check(packed!=null,"Genuine playable original W85.3 Godot game can be loaded")
    if packed==null:
        _end()
        return
    var ui: A7CascadeScreen=packed.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size=Vector2(390,844)
    await process_frame
    await process_frame

    var c: A7FirstRunCoach=ui.w86_coach
    var body: A7FirstPersonOperator=ui.stage_3d.first_person
    var guide: A7MissionFieldGuide=ui.w85_field_guide
    var touch: A7TouchFieldControls=ui.w78_touch_overlay
    var camera: A7DualTouchLook=ui.w83_dual_touch
    var equip: A7FieldOperations=ui.stage_3d.field_operations
    var mission: A7SpatialMission=ui.stage_3d.spatial_mission
    var dock: A7MobileMissionDeck=ui.w79_mission_deck
    var original_body: CharacterBody3D=body.body
    var source_scene: SubViewportContainer=ui.visual_container
    c.persistence_enabled=false
    c.skipped=false
    c.completed=false
    c.lesson_step=0
    c.completed_proofs.clear()

    _check(c!=null and c.get_parent()==ui.stage_shell and
        c.original_stage==ui.stage_shell,
        "W86 actual source-native first contact lives on original 3D stage")
    _check(c.operator==body and c.camera_touch==camera and
        c.physical_touch==touch and c.field_guide==guide and
        c.equipment==equip and c.mission==mission and c.checkpoint==ui.checkpoint,
        "W86 reads only the original actual W70/W83/W85/W72/W73 source")
    _check(not c.visible and c.lesson_step==0 and
        c.original_game_commands_issued==0 and
        ui.model.snapshot()["history"].is_empty(),
        "First contact does not pre-solve mission or display outside original game")
    _check(c.LESSON_TOTAL==7 and c.completed_proofs.size()==0,
        "Seven authentic player-proven milestones, not simulated UI progress")

    ui.w76_play_button.emit_signal("pressed")
    await process_frame
    await process_frame
    _check(c.visible and c.source_eligible and c.source_session_started and
        not c.skipped and not c.completed and c.lesson_step==0,
        "Actual PLAY NOW creates opt-in source first-contact prompt")
    _check(c.qa_readout()["real_original_body_id"]==original_body.get_instance_id()
        and body.piloting and mission.active and ui.w76_immersive,
        "Source tutorial preserves actual original piloting physics and extended mission")
    _check(c.hint.text.contains("0.25") and c.action_button.text=="ПРОПУСК",
        "RU W86 source text describes actual walk and honest player skip")
    c.observe_source()
    _check(c.lesson_step==0,
        "No fake onboarding progress without original physical movement")

    (touch.controls["forward"] as Button).emit_signal("button_down")
    _check(body.held_keys.get(KEY_W,false),
        "Tutorial W78 original native touch really holds W70 CharacterBody3D W")
    for i in range(100):
        await physics_frame
    (touch.controls["forward"] as Button).emit_signal("button_up")
    c.observe_source()
    _check(body.move_distance-c.source_started_distance>=0.25 and
        c.lesson_step==1 and c.completed_proofs.size()==1,
        "Actual W70 physics moved >=0.25m before true first lesson completion")
    _check(c.completed_proofs[0]=="W70_PHYSICAL_DISTANCE" and
        not body.held_keys.get(KEY_W,false),
        "Genuine motion accepted and original W key physically released")
    var before_look: int=body.mouse_look_events
    var before_yaw: float=body.body.rotation.y
    body.rotate_view(Vector2(29.0,7.0))
    c.observe_source()
    _check(body.mouse_look_events>before_look and
        absf(body.body.rotation.y-before_yaw)>0.02 and c.lesson_step==2,
        "Actual original 3D source camera yaw rotation unlocks look lesson")
    _check(c.completed_proofs[1]=="W70_REAL_CAMERA_ROTATION" and
        ui.model.snapshot()["history"].is_empty(),
        "Original camera lesson cannot fabricate incident choices")
    guide.entry_button.emit_signal("pressed")
    await process_frame
    _check(guide.opened and not c.visible and
        camera.input_suspended and not touch.visible,
        "Original W85 field guide safely hides source coach and blocks movement")
    c.observe_source()
    _check(c.lesson_step==3 and
        c.completed_proofs[2]=="W85_GENUINE_GUIDE_USER_OPEN",
        "Tutorial counts real W85 native guide open, not fictional completion")
    guide.close_button.emit_signal("pressed")
    await process_frame
    _check(c.visible and not camera.input_suspended and touch.visible,
        "Original game safely restores real motion when guide closes")
    c.observe_source()
    _check(c.lesson_step==3,
        "Cannot declare reactor proximity without original CharacterBody close")

    # This is a NATIVE isolated source unit test: original movement/collision
    # is independently proved above and by W77/W83. Only the test fixture
    # places the source player near a real machine to isolate equipment.
    body.body.position=Vector3(5.50,1.33,2.90)
    await physics_frame
    c.observe_source()
    _check(body.body.position.distance_to(body.inspection_console_core)<3.20
        and c.lesson_step==4,
        "Original W70 real body under strict 3.2m reactor gate advances lesson")
    _check(c.completed_proofs[3]=="W70_SOURCE_CORE_PROXIMITY",
        "No marker-based fake equipment proximity granted")
    var turns: int=equip.valve_target
    _check(turns>0 and not equip.valve_solved,
        "Original physical valve still requires authentic W72 detent operations")
    for i in range(turns):
        (dock.slots[1] as Button).emit_signal("pressed")
    c.observe_source()
    _check(equip.valve_solved and c.lesson_step==5 and
        c.completed_proofs[4]=="W72_SOURCE_CALIBRATED_VALVE",
        "Actual W72 valve completed through original native Godot controls")
    (touch.controls["inspect"] as Button).emit_signal("pressed")
    c.observe_source()
    _check(mission.phase==1 and c.lesson_step==6 and
        c.completed_proofs[5]=="W71_PHYSICAL_E_GATE_INSPECTION",
        "Authentic W71 source proximity/E inspection proves sixth lesson")
    _check(ui.model.snapshot()["history"].is_empty(),
        "W86 original core A7 history still empty; no fabricated decisions")
    var saved: int=ui.checkpoint.saves
    (dock.save_button as Button).emit_signal("pressed")
    c.observe_source()
    _check(ui.checkpoint.saves>saved and c.completed and
        c.lesson_step==c.LESSON_TOTAL,
        "Actual original W73 on-disk accepted checkpoint completes onboarding")
    _check(c.completed_proofs.size()==7 and
        c.completed_proofs[6]=="W73_ACTUAL_LOCAL_CHECKPOINT" and
        c.successful_lessons==7,
        "All seven proof events backed by existing source-game components")
    _check(c.original_game_commands_issued==0 and
        ui.model.snapshot()["history"].is_empty() and
        body.body==original_body and ui.visual_container==source_scene,
        "No alternate world, no gameplay command or synthetic original victory")

    # Privacy/offline data: stores only bounded finished/skipped flags.
    c.preference_path="user://w86_original_training_native_CI.cfg"
    c.persistence_enabled=true
    _check(c.save_preferences() and c.successful_saves>=1,
        "Real first-run preference persists safely through native ConfigFile")
    c.replay_training()
    _check(c.lesson_step==0 and not c.skipped and not c.completed
        and c.explicit_replays==1 and c.completed_proofs.is_empty(),
        "User explicitly can REPLAY tutorial without resetting original game")
    c.completed=false
    c.skipped=false
    _check(c.load_preferences() and c.successful_loads>=1 and
        not c.completed and not c.skipped,
        "Original native preference loads real replay mode")
    c.action_button.emit_signal("pressed")
    _check(c.skipped and not c.completed and c.explicit_skips==1,
        "Genuine player SKIP hides instructions without modifying game")
    c.skipped=false
    _check(c.load_preferences() and c.skipped,
        "Native source skip preference restored offline")
    c.action_button.emit_signal("pressed")
    _check(not c.skipped and not c.completed and
        c.explicit_replays==2 and c.lesson_step==0,
        "REPLAY after SKIP requires explicit original input again")
    var invalid := ConfigFile.new()
    invalid.set_value("onboarding","version",99)
    invalid.set_value("onboarding","finished",true)
    invalid.set_value("onboarding","skipped",true)
    invalid.save(c.preference_path)
    _check(not c.load_preferences() and c.invalid_preferences>=1,
        "Unknown preference version refused without unsafe source mutation")

    # RU/EN, real source portrait, narrow phone, landscape and desktop.
    ui._toggle_locale()
    _check(c.localized_language=="en" and
        c.hint.text.contains("walk") and c.action_button.text=="SKIP",
        "Actual original Godot W86 fully bilingual, not text on an image")
    await _check_view(ui,390,844)
    await _check_view(ui,320,700)
    await _check_view(ui,844,390)
    await _check_view(ui,1366,900)
    ui._w76_toggle_immersive()
    await process_frame
    _check(not c.visible and not c.source_eligible and
        not camera.input_suspended,
        "Exiting original source gameplay hides guide and leaves camera safe")
    ui.queue_free()
    await process_frame
    _end()

func _initialize() -> void:
    call_deferred("_run")

func _end() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W86 FIRST CONTACT SOURCE PROVEN SEVEN-STEP GODOT PASS: %d assertions" % assertions)
        quit(0)
        return
    for f in failures:
        push_error("W86 ORIGINAL REAL GAME ONBOARDING: "+f)
    quit(1)
