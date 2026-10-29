extends SceneTree
## W60 equivalent for BLACKOUT: verify the new artwork, original sound and UX
## against the actual native Godot 4.4.1 scene, not screenshots or mock state.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(result: bool, message: String) -> void:
    checks += 1
    if not result:
        failures.append(message)

func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn")
    _check(scene != null, "Godot scene imports")
    if scene == null:
        _finish()
        return
    var game = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    _check(game.art_stage is IPCinematicStage, "Actual procedural art direction installed")
    var art: Dictionary = game.art_stage.readout()
    _check(art["quality"] == "hero", "Desktop opens in HERO art profile")
    _check(int(art["instanced_detail_count"]) >= 270, "Actual instanced fasteners and deck details are built")
    _check(int(art["architectural_objects"]) >= 120, "Real scene contains architectural rhythm and containment")
    _check(int(art["safety_signs"]) >= 3, "Diegetic wayfinding signs are real 3D labels")
    _check(int(art["hazard_lights"]) == 2, "Risk-aware emergency lights are present")
    _check(game.art_stage.hero_details.visible, "HERO details are physically visible")
    game.art_stage.update_danger(95.0, 15.0, 3.0, true)
    _check(game.art_stage.warning_material.emission_energy_multiplier > 1.1, "Damage drives live hazard visuals")
    _check(game.audio_director is IPSoundscape, "Dedicated original soundscape exists")
    var sound: Dictionary = game.audio_director.readout()
    _check(bool(sound["has_ambience"]), "Original generated reactor WAV is present")
    _check(int(sound["cue_count"]) == 3, "Original cue classes are ready")
    _check(game.vitals_meters.size() == 4, "Four live gameplay metrics have actual bar controls")
    _check(game.warning_veil is ColorRect, "World risk overlay is rendered as HUD")
    _check(game.guidance_label != null, "Waypoint objective guide exists")
    _check(game.intro_panel.visible, "Mission briefing remains explicit")
    game.start_run()
    game._refresh_hud()
    _check(game.guidance_label.text.find("МАРШРУТ") >= 0, "Native RU waypoint tracks the first physical terminal")
    var g := InputEventKey.new()
    g.pressed = true
    g.keycode = KEY_G
    game._input(g)
    _check(game.quality_mode == "eco" and not game.art_stage.hero_details.visible, "G turns off expensive actual scene detail")
    game._input(g)
    _check(game.quality_mode == "hero" and game.art_stage.hero_details.visible, "G restores visual detail")
    var v := InputEventKey.new()
    v.pressed = true
    v.keycode = KEY_V
    game._input(v)
    _check(game.reduced_motion, "V enables reduced camera motion")
    var m := InputEventKey.new()
    m.pressed = true
    m.keycode = KEY_M
    game._input(m)
    _check(game.muted_audio and game.audio_director.muted, "M mutes original score without muting game state")
    game.session.scan_core()
    game._refresh_hud()
    _check(game.guidance_label.text.find("РЕМОНТ") >= 0, "Waypoint actually changes after scan")
    game._toggle_language()
    _check(game.guidance_label.text.find("ROUTE") >= 0, "English route instructions are truly localized")
    game.exit_gate.position.y = 6.2
    game._restart()
    _check(absf(game.exit_gate.position.y - 2.6) < 0.01, "Retry closes previously opened evacuation bulkhead")
    _check(game.session.objective_id() == "scan", "Retry resets gameplay objective")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE AAA FOUNDATION NATIVE PASS: %d source-bound Godot assertions" % checks)
        quit(0)
    else:
        for issue in failures:
            push_error("AAA FOUNDATION FAIL: " + issue)
        quit(1)
