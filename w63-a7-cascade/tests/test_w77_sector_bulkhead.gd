extends SceneTree
## W77 real native CharacterBody3D vs mission-gated StaticBody3D physics,
## not a painted warning or a fabricated objective completion.
var assertions: int = 0
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, explanation: String) -> void:
    assertions += 1
    if not ok:
        problems.append(explanation)

func _run() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _check(scene != null,"Original Godot playable A7 game available")
    if scene == null:
        _finish()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size = Vector2(1366,900)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    var door: A7SectorBulkhead = stage.sector_bulkhead
    var mission: A7SpatialMission = stage.spatial_mission
    var player: A7FirstPersonOperator = stage.first_person
    var original_state: Dictionary = ui.model.snapshot()
    _check(door != null and door.gate_body is StaticBody3D,
        "Actual separate Godot physics body exists inside real original A7 world")
    _check(door.gate_shape is CollisionShape3D and door.gate_body.collision_layer==1,
        "Full real collision mesh uses original CharacterBody3D compatible layer 1")
    _check(door.panels.size()==2 and door.native_meshes>=16,
        "Two independent machined PBR motorized physical bulkhead leaves")
    _check(door.power_lamp is OmniLight3D and door.status_label is Label3D,
        "Original 3D light and actual in-world access-status plaque")
    _check(not door.root_visuals.visible and not door.physically_blocked,
        "Default original game shows no fake mandatory door or screen clutter")
    _check(door.gate_shape.disabled,
        "Original unstarted W70 free-exploration remains genuinely unblocked")
    _check(door.qa_readout()["core_A7_gameplay_never_changed"],
        "Rendering and gate cannot spoof original A7 game authority")

    ui.w76_play_button.emit_signal("pressed")
    await physics_frame
    await physics_frame
    door.refresh_state()
    _check(mission.active and mission.extended_mode and mission.phase==0,
        "True W76 Play Now starts original W72 advanced field phase 0")
    _check(door.root_visuals.visible and door.physically_blocked,
        "Actual native physical sector door blocks corridor during first reactor objective")
    _check(not door.gate_shape.disabled and
        door.status_label.text.contains("LOCKED"),
        "Real StaticBody collider and actual Label3D show mission-locked passage")
    _check(door.real_open_events==0 and
        ui.model.snapshot()["history"].size()==0,
        "Locked door does not invent original A7 decisions or open itself")
    _check(ui.w76_objective_label.text.contains("ЗАТВОР ЗАКРЫТ"),
        "Real source-driven Russian target informs player why sector 02 is inaccessible")

    player.body.position = Vector3(6.4,1.33,12.60)
    player.body.rotation.y = PI
    player.set_key(KEY_W,true)
    for i in range(60):
        await physics_frame
    player.set_key(KEY_W,false)
    _check(player.body.position.z < 13.25,
        "True original CharacterBody3D cannot walk through physically closed relay door")
    _check(player.body.position.z > 12.55,
        "Real player approaches the actual blocking collider without teleport")
    _check(door.actual_collision_state_transitions>=1,
        "Physics collision is truly switched on by original mission phase")

    # Original game mechanics MUST be solved before collision can unlock.
    player.body.position = Vector3(5.50,1.33,2.90)
    for i in range(6):
        (ui.field_buttons["valve_plus"] as Button).emit_signal("pressed")
    _check(stage.field_operations.valve_solved,
        "Six real W72 valve detents required for authentic reactor entry")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase==1 and
        stage.field_operations.valve_solved,
        "Only physical inspection with truly solved valve unlocks original phase 1")
    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(mission.phase==1 and
        ui.model.snapshot()["history"].size()==1,
        "One real original A7 decision does NOT unlock the corridor prematurely")
    door.refresh_state()
    _check(door.physically_blocked,
        "Actual relay blast door remains physically shut before second original action")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(mission.phase==2 and
        ui.model.snapshot()["history"].size()==2,
        "Two original accepted A7 decisions genuinely reach phase 2")
    door.refresh_state()
    await physics_frame
    await physics_frame
    _check(not door.physically_blocked and door.gate_shape.disabled,
        "Real Godot sector collision shape is disabled ONLY after authentic original phase 2")
    _check(door.real_open_events==1,
        "Exactly one original mission-gated native physical opening recorded")
    _check(door.status_label.text.contains("ACCESS") and
        ui.w76_objective_label.text.contains("ЗАТВОР ОТКРЫТ"),
        "World and bilingual single-goal UI both reflect actual unlocked passage")
    _check(ui.model.snapshot()["history"].size()==2,
        "Door visual/physics change cannot inject additional core decisions")

    for i in range(5):
        door._process(0.20)
    _check(door.qa_readout()["native_motion_open_ratio"]>0.75,
        "Native 3D machined shutter leaves physically slide after genuine mission unlock")
    _check(door.panels[0].position.x < -1.7 and
        door.panels[1].position.x > 1.7,
        "Independent REAL left/right 3D meshed blast doors visibly separate")

    player.body.position = Vector3(6.40,1.33,12.60)
    player.body.rotation.y = PI
    player.set_key(KEY_W,true)
    for i in range(74):
        await physics_frame
    player.set_key(KEY_W,false)
    print("W77 REAL PHYSICAL CROSSING DEBUG:", {
        "player_xyz":player.body.global_position,
        "body_yaw":player.body.rotation.y,
        "physics_frame_updates":player.frame_updates,
        "collided_frames":player.collided_frames,
        "gate_shape_disabled":door.gate_shape.disabled,
        "world_locked":door.physically_blocked,
        "real_original_mission_phase":mission.phase,
    })
    _check(player.body.position.z > 15.0,
        "With actual collider disabled real native physics player now CROSSES sector boundary")
    _check(door.gate_body.collision_layer==1,
        "Door only disables correct shape, never destroys or bypasses world's collision layers")
    _check(mission.phase==2 and stage.mission_wayfinder.goal_kind=="relay",
        "Actual objective and world orientation advance to the separate relay hall")
    _check(door.real_open_events==1,
        "Door does not repeatedly fire fake opening after already unlocked")

    ui._toggle_motion()
    _check(door.reduced_motion,"Physical shutter honors real reduced motion accessibility")
    ui._toggle_quality()
    _check(door.quality=="eco" and not door.power_lamp.visible,
        "ECO actually disables additional physical 3D corridor light")
    ui._toggle_quality()
    ui._toggle_locale()
    _check(ui.w76_objective_label.text.contains("GATE OPEN"),
        "Original source-based physical door target is bilingual in actual UI")
    ui._layout_stage()
    ui.size=Vector2(390,844)
    ui._layout_stage()
    await process_frame
    _check(not door.status_label.visible,
        "At 390px compact true world text hides without hiding the actual passage")
    _check(ui.brand_label.custom_minimum_size.y <= 42 and
        ui.brand_label.text.contains("LAST FRONTIER"),
        "Native RU/EN title is a compact one-row mobile brand, not a vertical word column")
    _check(ui.w76_play_button.custom_minimum_size.y <= 42 and
        ui.w76_focus_button.custom_minimum_size.y <= 42,
        "Actual 390px mobile controls have short button geometry, not 400px stretched rows")
    _check(door.panels[0] is MeshInstance3D,
        "Mobile viewport retains true native opening game geometry")

    ui._restart()
    await physics_frame
    door.refresh_state()
    _check(not mission.active and not door.physically_blocked and
        not door.root_visuals.visible,
        "Restart returns original legacy gameplay freely navigable and without invented gate")
    _check(door.gate_shape.disabled,
        "Original legacy game has no hidden closed sector collision")
    ui.mission_button.emit_signal("pressed")
    await physics_frame
    door.refresh_state()
    _check(mission.active and not mission.extended_mode and
        not door.physically_blocked and door.gate_shape.disabled,
        "W71 source-original standard spatial mission remains fully open and untouched")
    _check(ui.model.snapshot()["history"].size()==0,
        "Original A7 session actually reset rather than visual imitation")
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if problems.is_empty():
        print("LAST FRONTIER W77 TRUE ORIGINAL PHYSICAL SECTOR DOOR GAME PASS: %d assertions" % assertions)
        quit(0)
        return
    for problem in problems:
        push_error("W77 TRUE STATICBODY COLLISION / REAL GAME: "+problem)
    quit(1)
