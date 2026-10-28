extends SceneTree
## W78 source-original Godot input test: actual held mouse/touch buttons
## affect live W70 CharacterBody3D, eye Camera3D, W73 physics ray and
## unchanged W72 physical tool / W71 inspection. Not phone certification.

var tests: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(pass_: bool, name_: String) -> void:
    tests += 1
    if not pass_:
        failures.append(name_)

func _down(overlay: A7TouchFieldControls, which: String) -> void:
    (overlay.controls[which] as Button).emit_signal("button_down")

func _up(overlay: A7TouchFieldControls, which: String) -> void:
    (overlay.controls[which] as Button).emit_signal("button_up")

func _tap(overlay: A7TouchFieldControls, which: String) -> void:
    (overlay.controls[which] as Button).emit_signal("pressed")

func _run() -> void:
    var packed := load("res://Main.tscn") as PackedScene
    _check(packed!=null,"Exact original playable W63/W77 Godot game")
    if packed==null:
        _finish()
        return
    var ui := packed.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size = Vector2(390,844)
    await process_frame
    await process_frame
    ui._layout_stage()
    var overlay: A7TouchFieldControls = ui.w78_touch_overlay
    var actor: A7FirstPersonOperator = ui.stage_3d.first_person
    var mission: A7SpatialMission = ui.stage_3d.spatial_mission
    var ops: A7FieldOperations = ui.stage_3d.field_operations
    _check(overlay!=null and overlay.actor==actor,
        "Original live W70 CharacterBody linked to W78 touch UI")
    _check(overlay.controls.size()==8,
        "Exactly eight actual Godot touch buttons, not HTML decoration")
    _check(overlay.get_parent()==ui.stage_shell,
        "Physical native touch controls mounted ON TOP of live original viewport")
    _check(not overlay.visible,
        "No touch clutter before physical mission")
    _check(not overlay.qa_readout()["full_physical_mobile_hardware_tested"],
        "Unit test refuses to falsely certify a real iPhone/Android")
    ui.w76_play_button.emit_signal("pressed")
    await process_frame
    _check(mission.active and mission.extended_mode and actor.piloting,
        "W76 original true play-now starts actual W72 mission and native physics")
    _check(ui.w76_immersive and overlay.visible,
        "Real mobile touch toolbar appears only in true Godot immersive 390px gameplay")
    _check(overlay.qa_readout()["compact_mobile"] and
        overlay.qa_readout()["immersive"],
        "Actual viewport context, not fabricated mobile bool")
    for name_ in overlay.controls.keys():
        _check((overlay.controls[name_] as Button).custom_minimum_size.y==48,
            "W78 actual mobile button %s uses a usable concise 48px tap target" % name_)
    var before: Vector3 = actor.body.global_position
    _down(overlay,"forward")
    _check(actor.held_keys.get(KEY_W,false),
        "Real physical forward held touch invokes original Godot WASD source")
    for i in range(36):
        await physics_frame
    _up(overlay,"forward")
    _check(not actor.held_keys.get(KEY_W,false),
        "Touch release actually clears native CharacterBody input, not merely UI")
    _check(actor.body.global_position.distance_to(before) > 0.75,
        "Holding touch arrow genuinely moves 3D character with native collision")
    _check(actor.move_distance > 0.75 and
        overlay.live_touch_motion_frames > 4,
        "Original CharacterBody move_and_slide frames counted, no teleport")
    _check(overlay.physically_stopped_keys >= 1,
        "W78 explicitly prevents dangerous stuck walking when finger lifts")
    var initial_yaw: float = actor.body.rotation.y
    _down(overlay,"look_right")
    for i in range(18):
        await process_frame
    _up(overlay,"look_right")
    _check(overlay.actual_continuous_look_frames >= 3,
        "Actual mobile camera hold changes real eye view over Godot rendered frames")
    _check(absf(actor.body.rotation.y-initial_yaw) > 0.03,
        "Native Camera3D/body orientation physically changed from touch look")
    _check(overlay.held_look==0,
        "Finger-up immediately stops camera-look drift")
    _check(ui.w77_focus_cancelled_by_actual_input >= 0,
        "Actual W77 camera cinematic interrupt retains original input priority")

    actor.body.position = Vector3(5.50,1.33,2.90)
    await physics_frame
    actor.head_camera.look_at(
        A7FieldOperations.CORE+Vector3(0,1.0,0.15),Vector3.UP)
    await physics_frame
    _check(ui.stage_3d.world_interaction.look_at_active_target().get("kind","")=="valve",
        "Original actual Camera3D RayCast3D intersects real W72 valve")
    var starting_events: int = ui.checkpoint.events.size()
    _tap(overlay,"world_use")
    _check(ops.valve_index==1 and
        ui.stage_3d.world_interaction.accepted_world_uses==1,
        "On-screen G genuinely rotates actual source-gated machine via 3D ray")
    _check(ui.checkpoint.events.size()==starting_events+1,
        "Actual mobile aimed tool journals exact original W73 session event")
    _check(overlay.world_use_requests==1,
        "Real native touch tool action counted without faking engine behavior")
    for i in range(5):
        (ui.field_buttons["valve_plus"] as Button).emit_signal("pressed")
    _check(ops.valve_solved,"Original six physical valve detents actually solved")
    _tap(overlay,"inspect")
    _check(mission.phase==1 and overlay.inspect_requests==1,
        "On-screen E only advances real source mission after physical success")
    _check(ui.model.snapshot()["history"].is_empty(),
        "Mobile UI never invents actual A7 original core actions")
    _down(overlay,"back")
    _check(actor.held_keys.get(KEY_S,false),
        "Native touch hold ready to walk backward")
    ui.w76_focus_button.emit_signal("pressed")
    _check(not overlay.visible and overlay.held_directions.is_empty() and
        not actor.held_keys.get(KEY_S,false),
        "Leaving immersive mode instantly releases ALL real held touch keys")
    _check(not ui.w76_immersive and ui.model.snapshot()["history"].is_empty(),
        "Reversible mode retains original true game state exactly")

    ui._toggle_locale()
    ui.w76_focus_button.emit_signal("pressed")
    _check(overlay.visible and overlay.localized_language=="en",
        "True original EN translation of touch help survives reentering mobile")
    _check((overlay.controls["inspect"] as Button).tooltip_text.contains("Physical"),
        "Optional touch physical inspection help is bilingual")
    ui.size=Vector2(1366,900)
    ui._layout_stage()
    _check(not overlay.visible,
        "Keyboard/gamepad desktop does not display mobile touch controls or extra cognitive load")
    ui.size=Vector2(320,700)
    ui._layout_stage()
    await process_frame
    _check(overlay.visible,
        "Even 320px live Godot viewport still shows accessible native navigation")
    _check((overlay.controls["forward"] as Button).custom_minimum_size.x<=33,
        "Actual 320px mobile has compact button targets that fit the usable world")
    ui._toggle_pilot()
    _check(not overlay.visible and not actor.piloting,
        "Exiting actual physical first-person mode hides touch input immediately")
    _check(overlay.held_directions.is_empty() and overlay.held_look==0,
        "Touch mode exit cannot leave W70 character walking or camera drifting")
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W78 TRUE ORIGINAL GODOT MOBILE TOUCH PHYSICS PASS: %d assertions" % tests)
        quit(0)
        return
    for problem in failures:
        push_error("W78 TRUE NATIVE MOBILE LIVE PLAYER: "+problem)
    quit(1)
