extends SceneTree
## W67 independent true two-zone native Godot 4.4.1 gameplay/art acceptance.
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    assertions += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var asset: PackedScene = load("res://Main.tscn") as PackedScene
    _check(asset != null, "Original W65 genuine playable main scene exists")
    if asset == null:
        _finish()
        return
    var ui: A7CascadeScreen = asset.instantiate() as A7CascadeScreen
    _check(ui != null, "A7 real playable Godot Control class exists")
    if ui == null:
        _finish()
        return
    root.add_child(ui)
    await process_frame
    await process_frame
    var stage: A7CinematicStage = ui.stage_3d
    _check(stage != null, "Original cinema scene still exists")
    if stage == null:
        _finish()
        return
    var world: A7IndustrialCathedral = stage.cathedral
    _check(world != null, "Real W67 3D environment is mounted")
    if world == null:
        _finish()
        return
    var geo: Dictionary = world.qa_readout()
    _check(int(geo["native_meshes"]) >= 260,
        "New cathedral adds at least 260 true authored Godot 3D meshes")
    _check(int(geo["tall_reactor_tiers"]) == 3,
        "Three elevated multi-storey reactor housing tiers")
    _check(int(geo["physical_catwalk_modules"]) == 14,
        "Fourteen separate real spatial inspection catwalk modules")
    _check(int(geo["real_relay_machines"]) == 3,
        "Second relay room has three full height capacitor machines")
    _check(bool(geo["has_two_spatially_separate_wings"]),
        "Original core and secondary room are distinct Node3D wings")
    _check(bool(geo["real_native_3d_signs"]),
        "Actual in-world Label3D typography for both real sectors")
    _check(stage.find_child("CORE_CATHEDRAL_MONUMENTAL_CHAMBER", true, false) is Node3D,
        "Tall original core cathedral exists in genuine Godot scene")
    _check(stage.find_child("REAL_SPATIAL_INSPECTION_CATWALK", true, false) is Node3D,
        "Navigable inspection bridge is physically modeled")
    _check(stage.find_child("SECOND_FULLY_MODELED_RELAY_SECTOR", true, false) is Node3D,
        "Physically separate relay room scene exists")
    _check(stage.find_child("RelayFoundation", true, false) is MeshInstance3D,
        "Relay floor is a real 3D mesh, not a UI image")
    _check(stage.find_child("RelayBackWall", true, false) is MeshInstance3D,
        "Relay room architecture is actual 3D geometry")
    _check(stage.find_child("CapacitorStack0", true, false) is MeshInstance3D,
        "Relay capacitor is a real industrial geometry mesh")
    _check(not bool(geo["physical_equipment_connected"]),
        "Only fictional mechanical game systems are represented")
    _check(not bool(geo["user_gpu_certified"]),
        "Headless rendering is not a consumer GPU certification")

    var old_puzzle: Dictionary = ui.model.snapshot()
    var original_pos: Vector3 = stage.camera.position
    _check(ui.sector_buttons.size() == 2, "Two real sector buttons")
    _check(ui.route_buttons.size() == 2, "Guided inspection forward/back buttons")
    _check(stage.guide_progress == 0.0 and stage.sector_index == 0,
        "Original playable run starts at first reactor chamber")
    _check(ui.route_buttons[0].disabled, "Cannot walk backward off the first deck module")
    ui.sector_buttons[1].emit_signal("pressed")
    _check(stage.sector_index == 1, "Actual relay sector became current camera target")
    _check(is_equal_approx(stage.guide_progress, 1.0),
        "True 3D camera moved to far relay gallery")
    _check(stage.camera.position.distance_to(original_pos) > 10.0,
        "The second sector is genuinely far from the original core")
    _check(stage.camera.fov >= 63.9,
        "Relay hero view backs away to frame all three real machine stacks")
    _check(not ui.route_buttons[0].disabled and ui.route_buttons[1].disabled,
        "Read-only navigation buttons reflect 3D deck boundaries")
    _check(ui.model.snapshot() == old_puzzle,
        "Entering second zone does not alter any original game decisions")
    for i in range(10):
        ui.route_buttons[0].emit_signal("pressed")
    _check(is_equal_approx(stage.guide_progress, 0.0),
        "Walking backward clamps safely at the real core zone")
    _check(ui.model.snapshot() == old_puzzle,
        "Ten camera movements must not invent ten gameplay actions")
    for i in range(5):
        ui.route_buttons[1].emit_signal("pressed")
    _check(is_equal_approx(stage.guide_progress, 1.0),
        "Five real guided walking steps cover the full catwalk")
    _check(stage.sector_index == 1,
        "Guided spatial walk reaches relay sector 02")
    _check(stage.qa_readout()["cathedral_two_real_sectors"],
        "Real second sector evidence exposed through native QA")
    ui.sector_buttons[0].emit_signal("pressed")
    _check(stage.camera_index == 0, "Return to hero reactor camera")
    _check(stage.sector_index == 0 and stage.guide_progress == 0.0,
        "Core sector button returns to the original first zone")

    _check(world.high_detail.visible, "HERO includes optional cathedral assets")
    ui.quality_button.emit_signal("pressed")
    _check(not world.high_detail.visible and stage.mode == "eco",
        "ECO hides heavy cathedral detail rather than deleting the game")
    _check(world.relay_sector.visible and world.main_arch.visible and world.bridge.visible,
        "Both important real locations and route still exist in ECO")
    ui.quality_button.emit_signal("pressed")
    _check(world.high_detail.visible and stage.mode == "hero",
        "HERO restores optional environmental detail")
    _check(ui.model.snapshot() == old_puzzle,
        "Changing quality never changes original game simulation")

    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(ui.model.snapshot()["metrics"]["heat"] == 42,
        "Original gameplay action still changes the real underlying model")
    _check(is_equal_approx(world.energy, 0.79),
        "True relay room energy materials react to accepted game command")
    _check(world.danger >= 0.0 and world.danger <= 1.0,
        "Visual hazard severity remains bounded")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(int(ui.model.snapshot()["shift"]) == 1,
        "Original game correctly proceeds to next incident")
    _check(is_equal_approx(world.signal_quality, 0.61),
        "Original real signal incident is represented by visual gallery")

    ui.language_button.emit_signal("pressed")
    _check(ui.locale == "en", "Native new two-zone feature supports English")
    _check(ui.sector_buttons[0].text.contains("REACTOR"), "English core route label")
    _check(ui.sector_buttons[1].text.contains("RELAY"), "English power gallery label")
    _check(ui.route_buttons[1].text.contains("FORWARD"), "English accessible walk caption")
    ui.language_button.emit_signal("pressed")
    _check(ui.sector_buttons[0].text.contains("РЕАКТОР"), "Russian core route label")
    _check(ui.sector_buttons[1].text.contains("РЕЛЕЙНЫЙ"), "Russian gallery route label")

    for w in [320, 390, 768, 1366]:
        ui.size = Vector2(w, 800)
        ui._layout_stage()
        await process_frame
        _check(stage.camera.current, "Genuine camera remains active at %dpx" % w)
        _check(ui.route_buttons.size() == 2, "Guided route controls survive %dpx" % w)
        _check(world.compact_view == (w < 640),
            "World-space captions adapt to phone layout at %dpx" % w)
        _check(world.sector_signs[0].visible == (w >= 640),
            "Overlapping 3D sign must hide on narrow mobile view %dpx" % w)
        _check(int(ui.model.snapshot()["shift"]) == 1,
            "No accidental gameplay mutation on %dpx viewport resize" % w)

    _check(ui.model.snapshot()["history"].size() == 2,
        "Only the two actual player machine actions count")
    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W67 REAL TWO-ZONE INDUSTRIAL CINEMA PASS: %d checks" % assertions)
        quit(0)
    else:
        for err in failures:
            push_error("W67 3D ART/GAME QA: " + err)
        quit(1)
