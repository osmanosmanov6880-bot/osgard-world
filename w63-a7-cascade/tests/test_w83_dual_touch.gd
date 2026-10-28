extends SceneTree
## W83: real Godot indexed multi-finger input and original 3D camera + W78
## CharacterBody walking. Source authority, equipment, checkpoint immutable.

var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, message: String) -> void:
    assertions += 1
    if not ok:
        failures.append(message)

func _touch(index: int, at: Vector2, pressed: bool) -> InputEventScreenTouch:
    var event := InputEventScreenTouch.new()
    event.index = index
    event.position = at
    event.pressed = pressed
    return event

func _drag(index: int, at: Vector2, move: Vector2) -> InputEventScreenDrag:
    var event := InputEventScreenDrag.new()
    event.index = index
    event.position = at
    event.relative = move
    event.screen_relative = move
    return event

func _look_point(ui: A7CascadeScreen) -> Vector2:
    var rect: Rect2 = ui.stage_shell.get_global_rect()
    var dock: Rect2 = ui.w79_mission_deck.panel.get_global_rect()
    return Vector2(rect.position.x+rect.size.x*0.83,
        minf(dock.position.y-17.0,rect.position.y+205.0))

func _run() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _check(scene != null,"Original Godot 4.4.1 physical W63 scene exists")
    if scene==null:
        _end()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size=Vector2(390,844)
    await process_frame
    await process_frame
    var look: A7DualTouchLook = ui.w83_dual_touch
    var walk: A7TouchFieldControls = ui.w78_touch_overlay
    var actor: A7FirstPersonOperator = ui.stage_3d.first_person
    var stage: Control = ui.stage_shell
    var original_body: CharacterBody3D = actor.body
    var real_viewport: SubViewportContainer = ui.visual_container
    var original_game: Dictionary = ui.model.snapshot()
    _check(look != null and look.get_parent()==stage and
        look.stage==stage,"W83 native layer mounted on existing real Godot viewport")
    _check(look.actor==actor and look.touch_controls==walk and
        look.mission_deck==ui.w79_mission_deck and
        look.navigation==ui.w82_nav_cockpit,
        "All gesture safety exclusions point to original mission UI objects")
    _check(not look.visible and look.look_finger==-1,
        "No mobile gesture interception before genuine fullscreen mission starts")
    ui.w76_play_button.emit_signal("pressed")
    await process_frame
    await process_frame
    _check(ui.w76_immersive and ui.w80_full_bleed.active and
        look.visible and walk.visible,"Real original full-bleed Godot mobile mission has physical swipe zone")
    _check(actor.body==original_body and
        ui.visual_container==real_viewport and
        look.qa_readout()["original_source_characterbody_preserved"],
        "Same CharacterBody3D, same SubViewport, no fake/rebuilt world")
    _check(look.hint_label.mouse_filter==Control.MOUSE_FILTER_IGNORE and
        look.mouse_filter==Control.MOUSE_FILTER_IGNORE,
        "Actual in-world hint is fully click-through, never blocks G/E or raycasts")
    var point: Vector2=_look_point(ui)
    _check(look.can_capture_at(point),
        "Native source world right-side free view region accepts a swipe")
    var excluded: Array[Control]=[
        ui.w79_mission_deck.panel,walk.rail,
        ui.w82_nav_cockpit.frame,ui.w80_full_bleed.toolbar]
    for node in excluded:
        var rect: Rect2=node.get_global_rect()
        _check(not look.can_capture_at(rect.get_center()),
            "Original real interactive UI %s never hijacked by swipe aiming" % node.name)
        _check(not look.handle_screen_event(_touch(33,rect.get_center(),true)),
            "True indexed start over %s remains available for native click" % node.name)
    var before: Vector3=actor.body.global_position
    (walk.controls["forward"] as Button).emit_signal("button_down")
    _check(actor.held_keys.get(KEY_W,false),
        "Original source W78 held W drives W70 physical body in same mission")
    _check(look.handle_screen_event(_touch(4,point,true)) and
        look.look_finger==4,"Second independent ScreenTouch index captures only camera")
    _check(not look.handle_screen_event(_touch(5,point+Vector2(6,0),true))
        and look.look_finger==4 and look.rejected_extra_fingers>0,
        "Extra fingers do not steal active look index or fake first-person inputs")
    var yaw: float=actor.body.rotation.y
    var pitch: float=actor.head_camera.rotation.x
    _check(not look.handle_screen_event(_drag(5,point+Vector2(30,0),Vector2(30,0))),
        "Unclaimed finger cannot rotate original camera")
    _check(look.handle_screen_event(_drag(4,point+Vector2(70,-23),Vector2(70,-23))),
        "Native ScreenDrag with matching finger changes original physical camera")
    _check(absf(actor.body.rotation.y-yaw)>0.08 and
        absf(actor.head_camera.rotation.x-pitch)>0.015,
        "Original W70 body yaw and eye pitch genuinely rotate, not a 2D picture")
    _check(look.real_camera_rotations==1 and look.physical_look_drags==1,
        "Single source camera gesture counts exactly one actual rotation")
    for i in range(32):
        await physics_frame
    _check(actor.body.global_position.distance_to(before)>0.6,
        "First finger still moves physical character while second finger aims")
    _check(actor.move_distance>0.6 and walk.live_touch_motion_frames>0,
        "Real Godot move_and_slide physics and W78 motion frames not simulated")
    _check(look.handle_screen_event(_drag(4,point+Vector2(200,0),Vector2(200,0)))
        and look.clamped_motion_frames>=1,
        "Outlier touchscreen delta bounded to prevent camera spin")
    var after_pan: float=actor.body.rotation.y
    _check(look.handle_screen_event(_touch(4,point,false)) and
        look.look_finger==-1,"Look finger release ends actual indexed capture")
    _check(not look.handle_screen_event(_drag(4,point,Vector2(50,20))),
        "No camera motion after finger release")
    _check(is_equal_approx(after_pan,actor.body.rotation.y),
        "Released finger cannot continue rotating camera")
    (walk.controls["forward"] as Button).emit_signal("button_up")
    _check(not actor.held_keys.get(KEY_W,false) and
        walk.held_directions.is_empty(),
        "Physical walk key is released independently of camera look")
    _check(ui.model.snapshot()==original_game and
        ui.stage_3d.spatial_mission.phase==0,
        "Two-finger aiming/walking NEVER creates a core choice or puzzle victory")

    # Real focus-loss guard on original Godot notification, not timer magic.
    (walk.controls["back"] as Button).emit_signal("button_down")
    _check(actor.held_keys.get(KEY_S,false),"W78 original held movement primed")
    _check(look.handle_screen_event(_touch(11,point,true)),
        "Another real indexed finger captured before focus loss")
    ui._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
    _check(look.look_finger==-1 and look.cancelled_captures>=1,
        "Native OS focus loss atomically cancels captured swipe")
    _check(not actor.held_keys.get(KEY_S,false) and
        walk.held_directions.is_empty() and walk.held_look==0,
        "OS focus loss atomically clears all real CharacterBody held movement")
    _check(ui.model.snapshot()==original_game,
        "Focus loss never changes original A7 decisions or grants victory")

    for dim in [Vector2(320,700),Vector2(844,390)]:
        ui.size=dim
        ui._layout_stage()
        await process_frame
        await process_frame
        var safe: Vector2=_look_point(ui)
        _check(look.visible and look.can_capture_at(safe),
            "Genuine %s responsive original Godot camera view accepts swipe" % dim)
        _check(look.handle_screen_event(_touch(18,safe,true)),
            "Genuine %s indexed touch captured in physical free view" % dim)
        _check(look.handle_screen_event(_drag(18,safe+Vector2(25,6),
            Vector2(25,6))),"True indexed native look physically turns at %s" % dim)
        _check(look.handle_screen_event(_touch(18,safe,false)),
            "Native source finger releases normally after %s" % dim)
        _check(ui.model.snapshot()==original_game,
            "Responsive multi-touch look does not change W63 gameplay at %s" % dim)
    ui.size=Vector2(390,844)
    ui._layout_stage()
    await process_frame
    point=_look_point(ui)
    _check(look.handle_screen_event(_touch(25,point,true)),
        "A live look finger is captured before leaving immersive")
    var state_before_exit: Dictionary=ui.model.snapshot()
    ui.w80_full_bleed.exit_button.emit_signal("pressed")
    await process_frame
    _check(not ui.w76_immersive and not look.visible and look.look_finger==-1,
        "Actual MENU exit releases gesture and fully restores original panels")
    _check(ui.model.snapshot()==state_before_exit and
        not look.qa_readout()["physical_touch_hardware_approved"],
        "No source decisions changed and no bogus physical phone approval")
    _check(look.qa_readout()["no_autoplay_or_fake_game_decisions"],
        "W83 two-finger look retains source-only camera responsibility")
    ui.queue_free()
    await process_frame
    _end()

func _end() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W83 REAL INDEXED TWO-FINGER GODOT CAMERA AND PHYSICS PASS: %d assertions" % assertions)
        quit(0)
        return
    for issue in failures:
        push_error("W83 GENUINE ORIGINAL TWO-FINGER SOURCE: "+issue)
    quit(1)
