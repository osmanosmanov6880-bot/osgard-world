extends SceneTree
## W80 actual Godot source-bound full-viewport stage ownership test.
## The single real SubViewport and original CharacterBody3D MUST survive
## reparenting; no generated screenshots, teleports or fake action results.

var assertions: int = 0
var defects: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, why: String) -> void:
    assertions += 1
    if not ok:
        defects.append(why)

func _run() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _check(scene != null,"Original real Godot 4.4.1 game scene must exist")
    if scene == null:
        _finish()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    ui.size=Vector2(390,844)
    await process_frame
    await process_frame
    ui._layout_stage()
    var overlay: A7FullBleedViewport=ui.w80_full_bleed
    var original_live_stage: Control=ui.stage_shell
    var original_real_world: A7CinematicStage=ui.stage_3d
    var original_physics_body: CharacterBody3D=ui.stage_3d.first_person.body
    var original_subviewport_id: int=ui.visual_container.get_instance_id()
    var original_parent: Node=original_live_stage.get_parent()
    var initial_source: Dictionary=ui.model.snapshot()
    _check(overlay!=null and not overlay.active and not overlay.visible,
        "Original game begins as existing full controls, no fake full-screen")
    _check(overlay.original_parent==original_parent and
        overlay.original_instance_id==original_live_stage.get_instance_id(),
        "Original Godot Control preserved and indexed before any screen move")
    _check(overlay.exit_button is Button and overlay.language_button is Button,
        "Real native touchscreen exit and language controls, not HTML fake")
    _check(overlay.qa_readout()["real_original_screenshot_proxies_created"]==0,
        "Full view renders actual original SubViewport, never screenshot")
    _check(original_live_stage.get_parent()==original_parent,
        "Original cinematic stage has not been reparented prematurely")

    ui.w76_play_button.emit_signal("pressed")
    await process_frame
    await process_frame
    _check(ui.w76_immersive and overlay.active and overlay.visible,
        "Play Now actually promotes original live Godot 3D viewport to full bleed")
    _check(original_live_stage.get_parent()==overlay,
        "Same native Control is now under overlay root, not rebuilt")
    _check(ui.stage_3d==original_real_world and
        ui.stage_3d.first_person.body==original_physics_body,
        "Real original 3D camera and CharacterBody3D node identity is preserved")
    _check(ui.visual_container.get_instance_id()==original_subviewport_id,
        "Exactly same real original 3D subviewport container, no replacement world")
    _check(overlay.qa_readout()["genuinely_reparented_original_live_stage"] and
        overlay.qa_readout()["original_real_3d_subviewport_unchanged"],
        "Genuine original source identity and Godot 3D SubViewport preserved")
    _check(overlay.qa_readout()["native_stage_area_fraction"]>=0.94,
        "Viewport physically covers at least 94 percent of original device canvas")
    _check(ui.w78_touch_overlay.visible and ui.w79_mission_deck.visible,
        "Full screen keeps original real movement and complete mission touch controls")
    _check(ui.w79_mission_deck.current_mode=="valve" and
        ui.w79_mission_deck.slots.size()==5,
        "Context-decision original source mission remains usable in enlarged stage")
    _check(ui.model.snapshot()==initial_source,
        "Full-screen UI entrance does not secretly choose game decisions")
    _check(overlay.real_reparent_events==1 and overlay.reversible_returns==0,
        "Exactly one true native full-screen reparent, no invalid extra transitions")

    overlay.language_button.emit_signal("pressed")
    _check(ui.locale=="en" and overlay.exit_button.text=="MENU" and
        overlay.language_button.text=="RU",
        "True in-game mobile language control switches actual original UI")
    _check(ui.model.snapshot()==initial_source,
        "Changing native full-screen language cannot affect original A7 game logic")

    # Native source equipment action remains physical and real inside
    # reparented true 3D world. QA places the real body beside console only.
    var equipment: A7FieldOperations=original_real_world.field_operations
    original_physics_body.position=Vector3(5.50,1.33,2.90)
    for i in range(6):
        (ui.w79_mission_deck.slots[1] as Button).emit_signal("pressed")
    _check(equipment.valve_solved and equipment.valve_index==6,
        "Original thermal valve genuinely solved through source touch in full bleed")
    (ui.w78_touch_overlay.controls["inspect"] as Button).emit_signal("pressed")
    _check(original_real_world.spatial_mission.phase==1 and
        ui.w79_mission_deck.current_mode=="decisions",
        "Real original physical E opens phase1 while screen is fully cinematic")
    (ui.w79_mission_deck.slots[0] as Button).emit_signal("pressed")
    _check(ui.model.snapshot()["history"].size()==1,
        "A real original A7 decision is accepted while stage covers screen")
    var partial_snapshot: Dictionary=ui.model.snapshot()

    overlay.exit_button.emit_signal("pressed")
    await process_frame
    _check(not overlay.active and not overlay.visible and not ui.w76_immersive,
        "Visible native MENU genuinely exits full-bleed viewport")
    _check(original_live_stage.get_parent()==original_parent,
        "Exact same real 3D stage is returned to original parent")
    _check(ui.stage_3d==original_real_world and
        ui.visual_container.get_instance_id()==original_subviewport_id,
        "Original physics, 3D render and live game never reset while exiting")
    _check(ui.model.snapshot()==partial_snapshot,
        "All previous real A7 actions survive reversible native layout")
    _check(not ui.w79_mission_deck.visible and
        not ui.w78_touch_overlay.visible,
        "Leaving full-screen intentionally hides mobile controls from normal layout")
    _check(overlay.reversible_returns==1,
        "Exactly one reparent back to original safe layout")
    _check(original_live_stage.get_index()==overlay.original_child_index,
        "Restored 3D stage stays at same original place in cinema-first layout")

    ui.w76_focus_button.emit_signal("pressed")
    await process_frame
    _check(overlay.active and overlay.real_reparent_events==2,
        "Original native Tab-like button can re-enter cinematic layer without resetting")
    _check(ui.model.snapshot()==partial_snapshot,
        "Original game decisions persist through a second fullscreen transition")
    ui.size=Vector2(320,700)
    ui._layout_stage()
    await process_frame
    _check(overlay.qa_readout()["native_stage_area_fraction"]>=0.94,
        "Even real 320px source window has truly full 3D coverage")
    _check(ui.w79_mission_deck.visible and
        ui.w78_touch_overlay.visible,
        "Narrow mobile stage retains both real world-input touch rows")
    ui._toggle_motion()
    _check(ui.reduced_motion and overlay.active,
        "Full-screen transition remains compatible with reduced-motion option")
    ui._toggle_quality()
    _check(ui.quality=="eco" and overlay.active,
        "ECO remains real original Godot render budget even in full-screen")
    ui._toggle_quality()
    ui.size=Vector2(1366,900)
    ui._layout_stage()
    await process_frame
    _check(overlay.active and
        overlay.qa_readout()["native_stage_area_fraction"]>=0.94,
        "Original 1366 desktop full-screen Godot engine fills viewport too")
    _check(not ui.w78_touch_overlay.visible and
        not ui.w79_mission_deck.visible,
        "Desktop does not inherit mobile touch-clutter from fullscreen view")

    var esc := InputEventKey.new()
    esc.keycode=KEY_ESCAPE
    esc.pressed=true
    ui._unhandled_key_input(esc)
    _check(not overlay.active and overlay.reversible_returns==2,
        "Real original Escape route restores desktop source UI, no trapped player")
    _check(ui.model.snapshot()==partial_snapshot,
        "Escape from full-screen changes no real equipment or game state")
    _check(overlay.qa_readout()["uses_generated_images"]==false,
        "No image generation or fake screenshots used to claim native 3D")
    _check(overlay.qa_readout()["production_aaa_art_approved"]==false,
        "World-building engineering does not invent AAA artist certification")
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if defects.is_empty():
        print("LAST FRONTIER W80 TRUE ORIGINAL FULL-BLEED GODOT GAME PASS: %d assertions" % assertions)
        quit(0)
        return
    for reason in defects:
        push_error("W80 NATIVE ORIGINAL REAL FULLSCREEN: "+reason)
    quit(1)
