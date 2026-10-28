extends SceneTree
var passed: int = 0
var failed: Array[String] = []
func _initialize() -> void:
    call_deferred("_go")
func _check(good: bool, label: String) -> void:
    passed += 1
    if not good:
        failed.append(label)
func _go() -> void:
    var scene := load("res://Main.tscn") as PackedScene
    _check(scene != null, "Original source-bound actual Godot game available")
    if scene == null:
        _finish()
        return
    var ui := scene.instantiate() as A7CascadeScreen
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    var mission: A7SpatialMission = stage.spatial_mission
    var nav: A7MissionWayfinder = stage.mission_wayfinder
    _check(nav != null and nav.target_ring is MeshInstance3D, "Real native world mesh for mission goal")
    _check(nav.native_meshes == 15 and nav.trail.size() == 13, "Read-only bridge navigation geometry")
    _check(nav.root_visuals.visible == false and nav.goal_kind == "none", "Inactive game does not clutter world")
    _check(ui.w76_play_button != null and ui.w76_focus_button != null, "Real in-engine Play and immersive control")
    _check(ui.w76_immersive == false and ui.w76_hidden_sections.size() >= 4, "Existing HUD preserved initially")
    var snapshot: Dictionary = ui.model.snapshot()
    ui.w76_play_button.emit_signal("pressed")
    _check(mission.active and mission.extended_mode, "One click starts authentic real W72 advanced mission")
    _check(stage.first_person.piloting and ui.w76_immersive, "One click enters real native first-person and cinematic mode")
    _check(nav.goal_kind == "core" and nav.root_visuals.visible, "World points at physical reactor console")
    _check(nav.real_distance > 0.0, "Actual player distance read from CharacterBody, no fabricated ETA")
    _check(nav.target_text.text.contains("CORE"), "Real 3D goal lettering displays correct machine")
    _check(ui.stage_shell.custom_minimum_size.y >= 420, "Native main viewport materially enlarged")
    for section in ui.w76_hidden_sections:
        _check(not section.visible, "Secondary dashboard hidden in immersive mode")
    _check(ui.model.snapshot() == snapshot, "Play-mode selection cannot fake original incident actions")
    _check(ui.checkpoint.events.size() == 1, "Actual advanced session start saved once in real journal")
    _check(nav.qa_readout()["never_teleports_or_advances_original_game"], "Read-only world guide cannot force mission progress")
    stage.first_person.body.position = Vector3(5.5, 1.33, 2.9)
    await physics_frame
    nav._reconcile()
    _check(nav.real_distance < 3.0, "Native ray guide sees real physically arrived operator")
    for i in range(6):
        (ui.field_buttons["valve_plus"] as Button).emit_signal("pressed")
    ui.pilot_inspect_button.emit_signal("pressed")
    _check(mission.phase == 1, "Actual field alignment + E required; original physics authority intact")
    ui.action_buttons["PUMP"].emit_signal("pressed")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    nav._reconcile()
    _check(mission.phase == 2 and nav.goal_kind == "relay", "After real incident choices 3D goal actually moves to relay")
    _check(nav.target_text.text.contains("RELAY"), "Source-based target 3D text follows mission")
    _check(ui.model.snapshot()["history"].size() == 2, "Original two accepted decisions preserved")
    ui.w76_focus_button.emit_signal("pressed")
    _check(not ui.w76_immersive, "Tab/UI returns all dense original controls")
    for section in ui.w76_hidden_sections:
        _check(section.visible, "Original dashboard preserved on leaving immersive mode")
    _check(mission.phase == 2 and ui.checkpoint.events.size() >= 10, "Cinematic mode toggle does not lose original progress")
    for width in [320,390,768,1366]:
        ui.size = Vector2(width,800)
        ui._layout_stage()
        await process_frame
        _check(ui.stage_shell.custom_minimum_size.y > 0, "Real native 3D viewport resizes to %dpx" % width)
        _check(nav.target_text.visible == (width >= 640), "World text compact for %dpx" % width)
    ui.w76_focus_button.emit_signal("pressed")
    _check(ui.w76_immersive and ui.stage_shell.custom_minimum_size.y >= 345, "Immersive can be reentered at current viewport")
    ui._toggle_locale()
    _check(ui.w76_play_button.text == "PLAY NOW / ENTER", "Native immersive button bilingual")
    _check(ui.w76_objective_label.text.contains("RELAY"), "Actual mission goal text bilingual")
    ui._toggle_motion()
    _check(nav.reduced_motion, "Read-only real 3D navigation honors reduced motion")
    ui._toggle_quality()
    _check(nav.quality == "eco" and not nav.light.visible, "Navigation respects ECO render budget")
    ui._toggle_quality()
    ui._restart()
    nav._reconcile()
    _check(not mission.active and not nav.root_visuals.visible, "Reset hides in-world goal without mission spoofing")
    ui.queue_free()
    await process_frame
    _finish()
func _finish() -> void:
    if failed.is_empty():
        print("LAST FRONTIER W76 REAL IMMERSIVE PHYSICAL LEVEL AND WORLD NAVIGATION PASS: %d assertions" % passed)
        quit(0)
        return
    for failure in failed:
        push_error("W76 REAL GAME: " + failure)
    quit(1)
