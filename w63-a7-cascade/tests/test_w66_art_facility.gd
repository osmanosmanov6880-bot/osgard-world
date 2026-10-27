extends SceneTree
## W66 independent Godot 4.4.1 original art kit and visual consequence QA.
var assertions: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _assert(condition: bool, label: String) -> void:
    assertions += 1
    if not condition:
        failures.append(label)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn") as PackedScene
    _assert(packed != null, "Original runnable Godot scene is loadable")
    if packed == null:
        _finish()
        return
    var ui: A7CascadeScreen = packed.instantiate() as A7CascadeScreen
    _assert(ui != null, "Original native playable game scene instantiated")
    if ui == null:
        _finish()
        return
    root.add_child(ui)
    await process_frame
    await process_frame

    var stage: A7CinematicStage = ui.stage_3d
    _assert(stage != null, "Actual W64 original Godot 3D world retained")
    if stage == null:
        _finish()
        return
    var art: A7ArtKit = stage.premium_art
    _assert(art != null, "New W66 dedicated original 3D art system is mounted")
    if art == null:
        _finish()
        return

    var initial: Dictionary = art.qa_readout()
    _assert(initial["schema"] == "A7_W66_TRUE_PROCEDURAL_CINEMATIC_ART_V1",
        "New original procedural art contract")
    _assert(int(initial["actual_meshes"]) >= 110, "Substantial extra 3D architecture and detail")
    _assert(int(initial["base_meshes"]) >= 55, "Real visible base art exists even in ECO")
    _assert(int(initial["extra_hero_meshes"]) == 48, "48 additional HERO quality mesh details")
    _assert(int(initial["coolant_bay_reactive_tubes"]) == 5, "Five physical coolant manifolds")
    _assert(int(initial["pressure_bay_reactive_shutters"]) == 5, "Five physical movable shutters")
    _assert(int(initial["safety_beacons"]) == 4, "Four luminous physical safety fixtures")
    _assert(int(initial["real_reactive_updates"]) > 0, "Art reacts to actual game snapshots")
    _assert(bool(initial["original_assets_only"]) and not bool(initial["network_requests"]),
        "No downloaded art or external services")
    _assert(not bool(initial["physically_certified"]), "Headless software QA is not real GPU certification")

    var stage_quality: Dictionary = stage.qa_readout()
    _assert(int(stage_quality["real_lights"]) == 3, "Original native Godot real dynamic lights retained")
    _assert(int(stage_quality["real_meshes_with_art"]) >= 190, "Full actual procedural 3D scene")
    _assert(stage.key_light.light_energy > 2.50, "Higher visibility scene lighting is configured")
    _assert(stage.find_child("CoolantWingStatusScreen", true, false) is MeshInstance3D,
        "Coolant service wing has actual geometry")
    _assert(stage.find_child("PressureWingStatusScreen", true, false) is MeshInstance3D,
        "Pressure service wing has actual geometry")

    var hull: MeshInstance3D = stage.find_child("ReactorPressureHousing", true, false) as MeshInstance3D
    _assert(hull != null, "Original reactor pressure housing survives")
    if hull != null:
        var finish: StandardMaterial3D = hull.material_override as StandardMaterial3D
        _assert(finish != null, "New translucent reactor hull has actual PBR material")
        if finish != null:
            _assert(finish.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA,
                "Inner luminous core is not hidden inside an opaque fake shell")
            _assert(finish.albedo_color.a < 0.28,
                "Reactor core remains visibly readable through the housing")

    _assert(art.high_detail.visible, "Premium HERO detail visibly enabled")
    ui.quality_button.emit_signal("pressed")
    _assert(stage.mode == "eco" and art.current_quality == "eco", "Quality toggle reaches both 3D layers")
    _assert(not art.high_detail.visible, "Actual extra geometry hidden in ECO")
    _assert(ui.visual_container.stretch_shrink == 2, "Actual GPU viewport half-resolution in ECO")
    ui.quality_button.emit_signal("pressed")
    _assert(art.high_detail.visible and stage.mode == "hero", "Original detailed world restores")

    var before: Dictionary = ui.model.snapshot()
    var cooling_before: float = art.cooling_fraction
    ui.action_buttons["PUMP"].emit_signal("pressed")
    _assert(int(ui.model.snapshot()["metrics"]["heat"]) == 42,
        "Original W63 deterministic heat rule remains unchanged")
    _assert(art.cooling_fraction > cooling_before, "Actual coolant bay emission tracks heat reduction")
    _assert(is_equal_approx(art.cooling_fraction, 0.58),
        "Coolant values are derived from real simulation, not decor loops")
    _assert(int(ui.model.snapshot()["actions_left"]) == 1, "No extra fake decisions introduced")
    _assert(ui.sound_bus.last_cue == "action", "W65 original procedural cue still follows player decision")
    _assert(int(ui.model.snapshot()["metrics"]["pressure"]) > int(before["metrics"]["pressure"]),
        "Original action tradeoff also changes pressure")

    ui.action_buttons["SCAN"].emit_signal("pressed")
    _assert(ui.model.snapshot()["shift"] == 1, "Real incident advances unchanged")
    _assert(art.reactive_updates >= 3, "New reactor art receives every game state update")
    _assert(is_equal_approx(art.pressure_fraction, 0.62),
        "New physical shutters read actual pressure after incident")
    _assert(ui.narrative_title.text.contains("ТЕПЛОВОЙ"),
        "Original W65 story remains tied to the resulting incident")

    for width in [320, 390, 768, 1366]:
        ui.size = Vector2(width, 800)
        ui._layout_stage()
        await process_frame
        _assert(ui.stage_3d.camera.current, "Actual 3D remains rendered at width %d" % width)
        if width < 640:
            _assert(ui.stage_shell.custom_minimum_size.y <= 305,
                "Premium scene remains accessible on phone at width %d" % width)
        _assert(ui.model.snapshot()["shift"] == 1,
            "Responsiveness cannot change game rules at width %d" % width)

    ui.restart_button.emit_signal("pressed")
    _assert(ui.model.snapshot()["shift"] == 0 and ui.model.snapshot()["status"] == "playing",
        "Original deterministic restart remains correct")
    var winning_actions: Array[String] = [
        "PUMP", "SCAN", "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for step in winning_actions:
        ui.action_buttons[step].emit_signal("pressed")
        _assert(stage.current_status == str(ui.model.snapshot()["status"]),
            "New visual layer cannot disconnect from actual game status")
    _assert(ui.model.snapshot()["status"] == "won", "True original 12-move victory remains accessible")
    _assert(ui.narrative_title.text.contains("КОМПЛЕКС"),
        "Original localized W65 winning chapter still appears")
    _assert(art.qa_readout()["real_reactive_updates"] >= 14,
        "Art receives all real gameplay updates during winning route")
    _assert(ui.model.snapshot()["history"].size() == 12, "No extra invisible actions")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W66 ART FACILITY TRUE GODOT 3D AND COMPLETE GAME PASS: %d assertions" % assertions)
        quit(0)
        return
    for issue in failures:
        push_error("W66 VISUAL GAME CONTRACT FAILED: " + issue)
    quit(1)
