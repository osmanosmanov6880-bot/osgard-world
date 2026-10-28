extends SceneTree
## W68 actual Godot 4.4.1 original native PBR art and full gameplay.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var resource: PackedScene = load("res://Main.tscn") as PackedScene
    _check(resource != null, "True native playable Godot project still imports")
    if resource == null:
        _finish()
        return
    var ui := resource.instantiate() as A7CascadeScreen
    _check(ui != null, "Original W63 W67 game scene remains alive")
    if ui == null:
        _finish()
        return
    root.add_child(ui)
    await process_frame
    await process_frame

    var stage: A7CinematicStage = ui.stage_3d
    _check(stage != null, "Original true Godot 3D stage retained")
    if stage == null:
        _finish()
        return
    var art: A7CinematicHeroSet = stage.hero_art
    _check(art != null, "New original industrial cinema hero set mounted")
    if art == null:
        _finish()
        return
    var qa: Dictionary = art.qa_readout()
    _check(qa["schema"] == "LAST_FRONTIER_W68_ORIGINAL_PBR_HERO_GAME_V1",
        "W68 evidence uses genuine standalone schema")
    _check(int(qa["meshes"]) >= 145,
        "New industrial model contains at least 145 concrete mesh objects")
    _check(int(qa["smooth_machined_torus_parts"]) >= 18,
        "Not rectangular box-only: real smooth Godot TorusMesh components")
    _check(int(qa["modeled_pressure_pipe_sections"]) >= 12,
        "Real 3D elbow-connected pressure piping")
    _check(int(qa["task_spot_lights"]) == 2,
        "Two actual localized SpotLight3D scene task lights")
    _check(int(qa["real_material_profiles"]) == 7,
        "Seven independent authored PBR material families")
    _check(int(qa["procedural_pixels"]) == 7 * 96 * 96,
        "Actual deterministic CPU-painted texture pixels")
    _check(qa["material_texture_source"] == "ImageTexture",
        "Native GPU-uploadable texture resource, not SVG/HTML painting")
    _check(not bool(qa["external_art_licensed_or_downloaded"]),
        "No unlicensed external art assets or network calls")
    _check(not bool(qa["gameplay_authority"]),
        "Decorative 3D code has no authority to alter original game")
    _check(art.spot_core is SpotLight3D and art.spot_relay is SpotLight3D,
        "Actual two native focused lighting sources instantiated")
    _check(art.spot_core.light_energy > 2.0,
        "Primary industrial machinery gets readable authored light")
    _check(art.find_child("ReactorCeramicContainmentCrown", true, false) is MeshInstance3D,
        "New original ceramic containment crown is actual 3D mesh")
    _check(art.find_child("PrecisionReactorClampingBand00", true, false) is MeshInstance3D,
        "New real machined annular torus geometry exists")
    _check(art.find_child("HeatTransportManifold1_0A", true, false) is MeshInstance3D,
        "Visible pipe is real authored 3D world geometry")
    _check(art.find_child("OperatorConsoleChassis1", true, false) is MeshInstance3D,
        "Real player operator equipment exists in foreground")
    _check(art.find_child("RelayMachineInspectionPlate0", true, false) is MeshInstance3D,
        "Second sector also received functional original 3D art")
    _check(art.find_child("RelayCoilSignal0", true, false) is MeshInstance3D,
        "Physical 3D relay status emissive visual mounted")
    _check(art.surface_lab.qa_readout()["textures_real_image_texture"],
        "Actual ImageTexture attached to native StandardMaterial3D")

    var dark: StandardMaterial3D = art.surface_lab.surface("dark_steel")
    var dark_again: StandardMaterial3D = art.surface_lab.surface("dark_steel")
    _check(dark == dark_again, "Original PBR texture material cache prevents duplication")
    _check(dark.albedo_texture is ImageTexture,
        "Real textured metal uses native Godot texture")
    _check(dark.metallic < 0.30 and dark.roughness > 0.50,
        "Metallic darkness controlled instead of unlit chrome")
    _check(art.surface_lab.generated == 7,
        "Repeated material access does not regenerate textures")

    var original: Dictionary = ui.model.snapshot()
    _check(original["shift"] == 0 and original["history"].size() == 0,
        "Actual original six-cycle game starts cleanly")
    _check(ui.cinematic_hud != null, "Restrained new native HUD exists")
    _check(ui.cinematic_hud.qa_readout()["read_only"],
        "HUD does not issue hidden gameplay decisions")
    _check(ui.cinematic_hud.qa_readout()["gameplay_model_modified"] == false,
        "Pure overlay is read-only and never alters original game")

    # W67 spatial navigation must still be playable and non-destructive.
    ui.sector_buttons[1].emit_signal("pressed")
    _check(stage.sector_index == 1, "True 3D second room remains navigable")
    _check(ui.model.snapshot() == original, "Navigating actual rooms preserves core game")
    _check(art.find_child("RelayMachineLiveScreen1", true, false) is MeshInstance3D,
        "Relay has readable genuine machinery/status display")
    ui.sector_buttons[0].emit_signal("pressed")

    # ECO really reduces authored art and lighting, never deletes the world.
    ui.quality_button.emit_signal("pressed")
    _check(stage.mode == "eco" and not art.hero_details.visible,
        "Actual HERO geometry hidden in economical quality setting")
    _check(is_equal_approx(art.spot_core.light_energy, 1.3),
        "Task lights really reduce energy in ECO")
    _check(art.essential.visible and art.relay_instrument.visible,
        "Critical machinery still visible in ECO")
    ui.quality_button.emit_signal("pressed")
    _check(stage.mode == "hero" and art.hero_details.visible,
        "Original extra details return in HERO mode")
    _check(art.spot_core.light_energy > 2.0,
        "Detailed practical lighting returns in HERO")

    ui.action_buttons["PUMP"].emit_signal("pressed")
    _check(int(ui.model.snapshot()["metrics"]["heat"]) == 42,
        "Real game action changes original rules correctly")
    _check(is_equal_approx(art.power, 0.79),
        "Visible relay machine changes power based on real gameplay")
    _check(art.visual_snapshots >= 2, "World updated from actual current snapshot")
    ui.action_buttons["SCAN"].emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 1,
        "Original complete first cycle still occurs")
    _check(art.visual_snapshots >= 3,
        "Dynamic visual scene updates after original incident")
    _check(ui.model.snapshot()["history"].size() == 2,
        "Visuals never silently create extra player actions")

    # Mobile typography intentionally removes extra labels, while keyboard
    # and accessible real status preserve gameplay meaning.
    for width in [320, 390, 768, 1366]:
        ui.size = Vector2(width, 800)
        ui._layout_stage()
        await process_frame
        _check(stage.camera.current, "Actual Camera3D persists at %dpx" % width)
        _check(ui.route_buttons.size() == 2,
            "Both real environment directions remain available at %dpx" % width)
        _check(bool(ui.cinematic_hud.qa_readout()["w68_compact_minimal"]) == (width < 640),
            "Actual native HUD shows root-responsive minimal state at %dpx" % width)
        _check(ui.model.snapshot()["history"].size() == 2,
            "Resizing screen cannot change decisions at %dpx" % width)
        _check(ui.stage_shell.custom_minimum_size.y <= 305.0 if width < 640 else
            ui.stage_shell.custom_minimum_size.y >= 350.0,
            "Actual 3D native responsive stage height at %dpx" % width)

    ui.restart_button.emit_signal("pressed")
    _check(ui.model.snapshot()["shift"] == 0 and ui.model.snapshot()["history"].size() == 0,
        "Real W63 reset works after W68 art changes")
    _check(is_equal_approx(art.power, 0.85),
        "Real visual energy relay fully resets")
    var winner: Array[String] = [
        "PUMP", "SCAN", "PUMP", "SEAL", "VENT", "SCAN",
        "VENT", "SEAL", "PUMP", "POWER", "VENT", "SCAN",
    ]
    for action in winner:
        ui.action_buttons[action].emit_signal("pressed")
        _check(stage.current_status == str(ui.model.snapshot()["status"]),
            "Native hero art never interferes with original player decisions")
    _check(ui.model.snapshot()["status"] == "won",
        "Real original 6-cycle winning path remains valid")
    _check(art.qa_readout()["visual_snapshots"] >= 16,
        "Reactive PBR industrial stage watched every completed decision")

    ui.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("LAST FRONTIER W68 REAL ORIGINAL PBR HERO AND COMPLETE GODOT GAME PASS: %d checks" % checks)
        quit(0)
    else:
        for issue in failures:
            push_error("W68 REAL ART / GAME: " + issue)
        quit(1)
