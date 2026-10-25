extends SceneTree
## W35 original cinematic art acceptance in the real Godot 4.4.1 engine.
## This is intentionally a structural and interactivity test, not a claim of
## photorealism or physical device certification.
const Core = preload("res://scripts/OSGARDCore.gd")
const SAVE = "user://osgard_w35_obsidian_only_test.cfg"
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_inspect")

func _assert_true(value: bool, label: String) -> void:
    assertions += 1
    if not value:
        failures.append(label)

func _inspect() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _assert_true(scene != null, "W35 true Godot scene must load")
    if scene == null:
        _finish()
        return
    var ui: OSGARDMain = scene.instantiate() as OSGARDMain
    _assert_true(ui != null, "W35 UI remains a real Godot Control")
    if ui == null:
        _finish()
        return
    ui.core = Core.new(SAVE)
    ui.core.clear_data()
    root.add_child(ui)
    await process_frame
    await process_frame
    _assert_true(ui.stage_shell != null, "Actual cinematic hero shell exists")
    _assert_true(ui.stage_title != null and ui.stage_readout != null, "Accessible in-scene simulated telemetry exists")
    _assert_true(ui.stage_title.text.find("OBSIDIAN") >= 0, "Obsidian branding belongs to the rendered interface")
    _assert_true(ui.scene_3d != null and ui.scene_3d.obsidian_stage != null, "Original procedural filmic complex exists")
    if ui.scene_3d == null or ui.scene_3d.obsidian_stage == null:
        ui.core.clear_data()
        ui.queue_free()
        _finish()
        return
    var complex: Node3D = ui.scene_3d.obsidian_stage
    _assert_true(complex.has_node("MonolithicRearBasalt"), "Physical architecture is modelled in real 3D")
    _assert_true(complex.has_node("A7PrecisionRing_0_00"), "True reactor ring machined components exist")
    _assert_true(complex.has_node("CoreBlackOpticalHousing"), "Optical core uses native materials")
    _assert_true(complex.has_node("A7MainHeader"), "Reactor A7 physical identity exists")
    var art: Dictionary = ui.scene_3d.cinematic_qa_readout()
    _assert_true(art.get("art_direction") == "OSGARD_OBSIDIAN_PROTOCOL_W35", "Named original visual release is traceable")
    _assert_true(int(art.get("structures", 0)) >= 60, "A7 is a full architectural set, not a box screenshot")
    _assert_true(int(art.get("hero_details", 0)) >= 75, "Original HERO detail nodes built")
    _assert_true(int(art.get("visible_hero_details", 0)) >= 75, "HERO initially displays detail geometry")
    _assert_true(art.get("key_shadow_enabled") == true, "Cinema quality initially enables shadowing")
    _assert_true(art.get("photorealistic_aaa_certified") == false, "Never claim software structure is AAA-certified")
    _assert_true(ui.mission_btns.size() == 6, "All six existing real mission controls preserved")
    _assert_true(ui.view_btns.size() == 3, "All three operator cameras preserved")
    ui.size = Vector2(1280, 800)
    ui._layout_stage_for_screen()
    _assert_true(ui.stage_shell.custom_minimum_size.y >= 500, "Desktop filmic stage owns most of the fold")
    ui.size = Vector2(390, 844)
    ui._layout_stage_for_screen()
    _assert_true(ui.stage_shell.custom_minimum_size.y <= 300, "Phone retains usable reachable controls")
    ui.core.set_setting("quality", "eco")
    ui._layout_stage_for_screen()
    ui.scene_3d.set_quality("eco")
    art = ui.scene_3d.cinematic_qa_readout()
    _assert_true(art.get("hero_vs_eco") == "eco", "Native ECO performance mode applied")
    _assert_true(int(art.get("visible_hero_details", -1)) == 0, "ECO really disables decorative draw calls")
    _assert_true(art.get("key_shadow_enabled") == false, "ECO really disables expensive shadows")
    ui.scene_3d.set_quality("hero")
    art = ui.scene_3d.cinematic_qa_readout()
    _assert_true(int(art.get("visible_hero_details", 0)) >= 75, "Real HERO material detail can be restored")
    ui.scene_3d.apply_simulation({"rotor_angle": 0.12, "view": 2, "quality": "hero", "drive_on": false, "incident_triggered": true, "last_error": false})
    art = ui.scene_3d.cinematic_qa_readout()
    _assert_true(art.get("alarm") == true and art.get("running") == false, "Amber visual safety state is bound only to simulated gameplay")
    ui.scene_3d.apply_simulation({"rotor_angle": 0.25, "view": 1, "quality": "hero", "drive_on": true, "incident_triggered": false, "last_error": false})
    art = ui.scene_3d.cinematic_qa_readout()
    _assert_true(art.get("alarm") == false and art.get("running") == true, "Successful recovery changes true visual state")
    ui.core.clear_data()
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("W35 OBSIDIAN CINEMATIC SOURCE PASS: %d assertions on original 3D architecture, safety-driven lights, 3 cameras, responsive UI, and ECO" % assertions)
        quit(0)
    else:
        for failure in failures:
            push_error("W35 FAILED: " + failure)
        quit(1)
