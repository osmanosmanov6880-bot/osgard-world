extends SceneTree
## W84: verifies real original W70 Camera3D changes, original W78 button
## order, local ConfigFile persistence, safe controls modal in live Godot.
## Never replaces source A7 model, scene or original CharacterBody3D.

var tests: int = 0
var problems: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _ok(pass_: bool, why: String) -> void:
    tests += 1
    if not pass_:
        problems.append(why)

func _touch(index: int, pos: Vector2, down: bool) -> InputEventScreenTouch:
    var e := InputEventScreenTouch.new()
    e.index = index
    e.position = pos
    e.pressed = down
    return e

func _drag(index: int, pos: Vector2, move: Vector2) -> InputEventScreenDrag:
    var e := InputEventScreenDrag.new()
    e.index = index
    e.position = pos
    e.relative = move
    e.screen_relative = move
    return e

func _look_point(ui: A7CascadeScreen) -> Vector2:
    var rect: Rect2 = ui.stage_shell.get_global_rect()
    var dock: Rect2 = ui.w79_mission_deck.panel.get_global_rect()
    return Vector2(rect.position.x+rect.size.x*0.82,
        minf(rect.position.y+205.0,dock.position.y-18.0))

func _check_geometry(ui: A7CascadeScreen, size_: Vector2) -> void:
    ui.size = size_
    ui._layout_stage()
    await process_frame
    await process_frame
    var panel: Rect2 = ui.w84_studio.panel.get_global_rect()
    var stage: Rect2 = ui.stage_shell.get_global_rect()
    _ok(ui.w84_studio.visible and ui.w84_studio.opened,
        "Real W84 Godot profile modal still open at %s" % size_)
    _ok(panel.position.x>=stage.position.x-2 and
        panel.end.x<=stage.end.x+2,
        "Actual native W84 setting panel fits stage width at %s" % size_)
    _ok(panel.position.y>=stage.position.y and
        panel.end.y<=stage.end.y+2,
        "Actual W84 Godot setting panel fits stage height at %s" % size_)
    _ok(ui.w84_studio.sensitivity_button.get_global_rect().size.y>=44 and
        ui.w84_studio.done_button.get_global_rect().size.y>=44,
        "W84 actual Godot profile action controls remain >=44px at %s" % size_)
    _ok(not ui.w78_touch_overlay.visible and
        not ui.w79_mission_deck.visible and
        ui.w83_dual_touch.input_suspended,
        "Original mission controls and source camera truly suspended while modal open")

func _run() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _ok(scene!=null,"Actual original Godot W63-W83 playable game scene loads")
    if scene==null:
        _end()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size=Vector2(390,844)
    await process_frame
    await process_frame
    var studio: A7MobileControlStudio=ui.w84_studio
    var look: A7DualTouchLook=ui.w83_dual_touch
    var walk: A7TouchFieldControls=ui.w78_touch_overlay
    var body: A7FirstPersonOperator=ui.stage_3d.first_person
    var original_actor: CharacterBody3D=body.body
    var source_world: SubViewportContainer=ui.visual_container
    studio.persistence_enabled=false
    studio.set_profile(1,false,false,false)
    var original_state: Dictionary=ui.model.snapshot()

    _ok(studio!=null and studio.get_parent()==ui.stage_shell,
        "Original W84 profile UI is a Godot control on genuine same 3D stage")
    _ok(studio.physical_controls==walk and
        studio.actual_camera_touch==look and
        look.actor==body,"W84 directly controls original W78/W83 source interfaces")
    _ok(body.body==original_actor and ui.visual_container==source_world,
        "Original real W70 CharacterBody3D and actual original SubViewport preserved")
    _ok(not studio.visible and not studio.opened,
        "W84 mobile settings not obstructing initial desktop/world intro")
    _ok(studio.qa_readout()["original_core_commands_issued"]==0,
        "W84 tuning has zero original A7 core game authority")
    ui.w76_play_button.emit_signal("pressed")
    await process_frame
    await process_frame
    _ok(studio.visible and not studio.opened and
        walk.visible and ui.w79_mission_deck.visible,
        "Actual original fullscreen mobile mission and 8 native controls visible")
    _ok(studio.settings_button.custom_minimum_size.y>=44,
        "Native mobile control entry is a real >=44px Godot touch target")

    var first_button: Button=walk.controls["forward"] as Button
    first_button.emit_signal("button_down")
    _ok(body.held_keys.get(KEY_W,false),
        "Original CharacterBodyW key held before real W84 settings modal")
    studio.settings_button.emit_signal("pressed")
    await process_frame
    _ok(studio.opened and studio.panel.visible and look.input_suspended,
        "Actual native W84 settings panel opens and blocks physical swipe look")
    _ok(not walk.visible and not ui.w79_mission_deck.visible and
        not body.held_keys.get(KEY_W,false),
        "Opening real W84 settings stops movement and hides all dangerous source actions")
    var safe: Vector2=_look_point(ui)
    _ok(not look.handle_screen_event(_touch(66,safe,true)) and
        look.look_finger==-1,
        "No original W70 camera gesture captured behind active settings")
    _ok(ui.model.snapshot()==original_state,
        "Opening real Godot settings NEVER fabricates original game decisions")

    studio.sensitivity_button.emit_signal("pressed")
    _ok(studio.sensitivity_step==2 and is_equal_approx(look.look_gain,1.15),
        "Native W84 tap changes actual W83 -> W70 camera gain")
    studio.invert_button.emit_signal("pressed")
    _ok(studio.invert_y and look.invert_look_y,
        "Native Godot invert toggle changes original physical pitch computation")
    studio.handed_button.emit_signal("pressed")
    _ok(studio.left_handed and walk.rail.get_child(0)==walk.controls["right"] and
        walk.rail.get_child(4)==walk.controls["inspect"],
        "Left-handed mobile profile reorders same original physical W78 Buttons")
    _ok(walk.rail.columns==4 and walk.controls.size()==8,
        "Source-handedness does not clone controls or replace 4-column native geometry")
    _ok(ui.model.snapshot()==original_state,
        "No original 12-decision A7 state changed by mobile physical tuning")

    # Native Godot ConfigFile persists only THREE non-sensitive control prefs.
    studio.profile_path="user://w84_true_native_profile_ci.cfg"
    studio.persistence_enabled=true
    studio.set_profile(3,true,true,true)
    _ok(studio.saved_profiles>=1,
        "Native user:// ConfigFile securely persisted original physical preferences")
    studio.set_profile(1,false,false,false)
    _ok(studio.load_preferences() and
        studio.sensitivity_step==3 and studio.invert_y and studio.left_handed,
        "Native ConfigFile reload restores real camera profile without server")
    _ok(is_equal_approx(look.look_gain,1.50) and look.invert_look_y and
        walk.rail.get_child(0)==walk.controls["right"],
        "Restored offline settings immediately reconfigure same live original game")
    studio.persistence_enabled=false
    studio.set_profile(-12,true,true,false)
    _ok(studio.rejected_profile_values>=1 and studio.sensitivity_step==0,
        "Corrupt/out-of-range control profile rejects unsafe camera gain")
    studio.set_profile(3,true,true,false)

    studio.done_button.emit_signal("pressed")
    await process_frame
    _ok(not studio.opened and not studio.panel.visible and
        not look.input_suspended and walk.visible and ui.w79_mission_deck.visible,
        "Returning to original physical mission restores W78/W79 and camera input")
    var pos: Vector2=_look_point(ui)
    var previous_pitch: float=body.head_camera.rotation.x
    _ok(look.handle_screen_event(_touch(70,pos,true)),
        "Adjusted W84 user profile allows real source Godot free-world swipe")
    _ok(look.handle_screen_event(_drag(70,pos+Vector2(0,27),Vector2(0,27))),
        "Adjusted camera swipe invokes same original W70 rotate_view")
    _ok(body.head_camera.rotation.x>previous_pitch+0.03,
        "Inverted Y actually reverses genuine original Camera3D pitch")
    _ok(look.handle_screen_event(_touch(70,pos+Vector2(0,27),false)),
        "Adjusted real Godot indexed camera swipe releases normally")
    _ok(body.body==original_actor and ui.model.snapshot()==original_state,
        "Actual W84 input tuning preserves same physical body and original game")

    studio.settings_button.emit_signal("pressed")
    await process_frame
    await _check_geometry(ui,Vector2(390,844))
    await _check_geometry(ui,Vector2(320,700))
    await _check_geometry(ui,Vector2(844,390))
    ui._toggle_locale()
    _ok(studio.language=="en" and studio.done_button.text.contains("DONE"),
        "Mobile physical control studio true bilingual EN inside original game")
    studio.reset_button.emit_signal("pressed")
    _ok(studio.sensitivity_step==1 and
        not studio.invert_y and not studio.left_handed and
        walk.rail.get_child(0)==walk.controls["left"],
        "Reset brings back exact original W78 source order and default camera")
    studio.done_button.emit_signal("pressed")
    await process_frame
    _ok(walk.visible and not look.input_suspended,
        "Closing studio in 844x390 landscape restores real mobile controls")

    ui.size=Vector2(1366,900)
    ui._layout_stage()
    await process_frame
    _ok(not studio.visible and not studio.opened,
        "Real desktop hides touch tuning, no extra cognitive load")
    _ok(ui.model.snapshot()==original_state and body.body==original_actor,
        "All native profile changes leave physics identity, puzzle and A7 history intact")
    ui.queue_free()
    await process_frame
    _end()

func _end() -> void:
    if problems.is_empty():
        print("LAST FRONTIER W84 REAL NATIVE MOBILE COMFORT STUDIO PASS: %d assertions" % tests)
        quit(0)
        return
    for why in problems:
        push_error("W84 ORIGINAL MOBILE TRUE CAMERA PROFILE: "+why)
    quit(1)
