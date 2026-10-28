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

    # Godot WebGL may reindex the LOOK finger upon its release while first
    # walking finger remains down. Reject release over the real UI, but accept
    # physical release near the last camera finger position.
    _check(look.handle_screen_event(_touch(23,point,true)),
        "Second actual look gesture starts after prior release")
    _check(look.handle_screen_event(_drag(23,point+Vector2(33,0),
        Vector2(33,0))),"Physical camera gets another indexed real drag")
    _check(not look.handle_screen_event(
        _touch(90,walk.rail.get_global_rect().get_center(),false))
        and look.look_finger==23,
        "Unmatched release from the physical WALK UI does not release LOOK")
    _check(look.handle_screen_event(
        _touch(99,point+Vector2(33,0),false))
        and look.look_finger==-1 and look.recovered_end_by_position==1,
        "Reindexed true END near camera finger recovers correct independent release")

    # Lost browser touch-end requires a bounded genuine source recovery.
    _check(look.handle_screen_event(_touch(26,point,true)),
        "Camera can be captured again after a reindexed END")
    look.last_touch_ticks_ms = Time.get_ticks_msec()-2000
    look._process(0.016)
    _check(look.look_finger==-1 and
        look.recovered_missing_end_timeout>=1 and
        look.qa_readout()["native_watchdog_timeout_ms"]==1700,
        "Actual original Godot orphaned look pointer expires without stuck camera")
    _check(ui.model.snapshot()==original_game,
        "Release recovery and loss watchdog NEVER mutate original A7 gameplay")

    # W83.2: two physical independently indexed fingers must keep the W70
    # FIRST WALK pressed even if Godot's compatibility Button gets a spurious
    # mouse-up when the SECOND LOOK finger lifts.
    var forward_rect: Rect2=(walk.controls["forward"] as Button).get_global_rect()
    var walk_pos: Vector2=forward_rect.get_center()
    _check(not look.handle_screen_event(_touch(61,walk_pos,true)) and
        look.source_walk_fingers.size()==1 and
        actor.held_keys.get(KEY_W,false),
        "Original W78 native button source touch indexed as independently held walk")
    _check(look.handle_screen_event(_touch(62,point,true)),
        "Second real look finger works concurrently with indexed original W")
    _check(look.handle_screen_event(_drag(62,point+Vector2(26,-9),
        Vector2(26,-9))),"Second finger changes same original camera while walk held")
    actor.set_key(KEY_W,false)
    look._process(0.016)
    _check(actor.held_keys.get(KEY_W,false) and
        look.original_walk_reassert_frames>=1,
        "Spurious W78 compatibility mouse-up cannot stop actual first held finger")
    _check(look.handle_screen_event(_touch(62,point,false)),
        "Camera finger can release independently by native source identity")
    look._process(0.016)
    _check(actor.held_keys.get(KEY_W,false) and
        look.source_walk_fingers.size()==1,
        "Real W70 forward continues despite the second camera finger release")
    _check(not look.handle_screen_event(_touch(61,walk_pos,false)) and
        look.source_walk_fingers.is_empty() and
        not actor.held_keys.get(KEY_W,false),
        "Only native physical FIRST finger release stops original source W")
    _check(ui.model.snapshot()==original_game,
        "Independent true indexed W70 walking never modifies W63 gameplay")

    # Browser CDP may lose the SECOND finger END while the FIRST W78
    # movement finger remains physically held. Expiring the LOOK-only
    # watchdog MUST NOT cancel independent source-owned walking.
    _check(not look.handle_screen_event(_touch(73,walk_pos,true))
        and look.source_walk_fingers.size()==1,
        "First genuine source walking finger active before look-only watchdog")
    _check(look.handle_screen_event(_touch(74,point,true)),
        "Second separate genuine camera finger captured before orphan END")
    look.last_touch_ticks_ms=Time.get_ticks_msec()-1900
    look._process(0.016)
    _check(look.look_finger==-1 and look.source_walk_fingers.size()==1
        and actor.held_keys.get(KEY_W,false),
        "Lost SECOND finger timeout stops camera only, preserves FIRST original W70 WALK")
    _check(look.recovered_missing_end_timeout>=2 and
        ui.model.snapshot()==original_game,
        "Source-only real camera orphan recovery never edits core decisions")
    _check(not look.handle_screen_event(_touch(73,walk_pos,false))
        and look.source_walk_fingers.is_empty()
        and not actor.held_keys.get(KEY_W,false),
        "Only the FIRST physical finger end stops original movement after camera watchdog")

    # The 12s safety limit is based on actual simulated Godot time, NOT
    # slow wall-clock WebGL time. Confirm still held after many long wall
    # clock ticks when actual source frames are few; then stop after
    # 12 physical source-simulated seconds (headless deterministic test).
    _check(not look.handle_screen_event(_touch(84,walk_pos,true))
        and actor.held_keys.get(KEY_W,false),
        "Original physical W held for independent simulated-time safety test")
    look.source_walk_elapsed_seconds[84]=11.90
    look._process(0.05)
    _check(look.source_walk_fingers.has(84)
        and actor.held_keys.get(KEY_W,false),
        "Original W not prematurely released before 12 actual simulated seconds")
    look._process(0.05)
    _check(not look.source_walk_fingers.has(84)
        and not actor.held_keys.get(KEY_W,false)
        and look.expired_long_walk_holds>=1,
        "Only 12 seconds of genuine Godot simulated W movement triggers safety")
    _check(ui.model.snapshot()==original_game,
        "Simulated time-based input protection never alters original A7 gameplay")

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
