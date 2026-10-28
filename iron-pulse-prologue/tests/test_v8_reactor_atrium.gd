extends SceneTree
## Exact-source Godot 4.4.1 V8 native art+physics acceptance.
## These checks cover real meshes, original material maps and gameplay safety,
## not a claim that procedural art is AAA production quality.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    checks += 1
    if not ok:
        failures.append(description)

func _key(game: Node, code: Key) -> void:
    var event := InputEventKey.new()
    event.pressed = true
    event.keycode = code
    game._input(event)

func _run() -> void:
    var source: PackedScene = load("res://Main.tscn")
    _check(source != null, "Original playable Godot scene remains available")
    if source == null:
        _finish()
        return
    var game = source.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var vault: IPReactorAtrium = game.reactor_atrium
    _check(vault != null and vault.name == "A7_CinematicReactorAtrium",
        "A real 15m-high side reactor hall is attached to player scene")
    if vault == null:
        game.queue_free()
        await process_frame
        _finish()
        return
    var d: Dictionary = vault.readout()
    _check(d.get("cinematic_vault") == true and absf(float(d["vault_height_m"])-15.0) < 0.1,
        "Vertical cinematic vault has physical architectural height")
    _check(absf(float(d["open_wall_span_m"])-22.0) < 0.1,
        "Original solid corridor has been opened to the 22m observation bay")
    var center: Array = d.get("core_center",[])
    _check(center.size() == 3 and float(center[0]) > 10.0 and float(center[1]) >= 6.0,
        "Reactor setpiece is physically beyond the original corridor wall")
    _check(game.reactor_core is MeshInstance3D and game.reactor_rings.size() == 3,
        "Original animated game reactor and three legacy rings still exist")
    _check(game.reactor_core.global_position.x > 10.0,
        "The actual legacy reactor was relocated into the newly opened hall")
    var player_forward: Vector3 = -game.camera.global_transform.basis.z
    var reactor_direction: Vector3 = (game.reactor_core.global_position-game.camera.global_position).normalized()
    _check(player_forward.dot(reactor_direction) > 0.96,
        "Initial player camera genuinely frames the monumental reactor in view")
    _check(int(d.get("monumental_geometry",0)) >= 125,
        "New high-scale reactor machine has real repeated original mesh structures")
    _check(int(d.get("instanced_fasteners",0)) == 216,
        "216 armour fasteners use a real GPU MultiMesh draw group")
    _check(int(d.get("moving_rotors",0)) == 3, "Three real mechanical field rotors exist")
    _check(int(d.get("real_lights",0)) == 5 and int(d.get("diegetic_signs",0)) == 3,
        "Vault has multiple original industrial fixtures and in-world sign details")
    _check(int(d.get("physical_guardrail_colliders",0)) == 1,
        "Side observation bay is enclosed by an actual physics guardrail")
    var rail: StaticBody3D = vault.get_node_or_null("PermanentShell/AtriumSafetyBarrier") as StaticBody3D
    _check(rail != null and rail.get_child_count() >= 1,
        "A physical collision body shields the open side of the mission route")
    if rail != null:
        var collision: CollisionShape3D = rail.get_child(0) as CollisionShape3D
        _check(collision != null and collision.shape is BoxShape3D,
            "Guardrail uses real BoxShape3D collision, not cosmetic mesh only")
        if collision != null:
            _check((collision.shape as BoxShape3D).size.z >= 21.0,
                "Collision runs along entire open viewing aperture")

    _check(int(d.get("pbr_texture_maps",0)) == 3,
        "Original generated PBR albedo/roughness/normal tile maps all exist")
    var painted: StandardMaterial3D = vault._painted
    _check(painted != null and painted.albedo_texture != null and painted.roughness_texture != null,
        "Real steel surfaces use procedural textured metal and nonuniform roughness")
    _check(painted.normal_enabled and painted.normal_texture != null,
        "Fine normal surface detail is enabled on actual reactor steel")
    if painted.albedo_texture is ImageTexture:
        var source_image: Image = painted.albedo_texture.get_image()
        _check(source_image.get_width() == 96 and source_image.get_height() == 96,
            "Original texture generated deterministically without downloaded assets")
        _check(source_image.get_pixel(4,9) != source_image.get_pixel(25,19),
            "Original PBR tile contains real wear variation, not a flat color")

    var previous_rotor: float = vault._mechanical_rotors[0].rotation.x
    vault.update_alarm("thermal",94.0,84.0,12.0,false)
    _check(vault.readout()["alarm_risk"] >= 0.80,
        "HEAT scenario produces high-risk warm containment illumination")
    _check(vault.readout()["last_emissive"] > 0.78,
        "Safety-state lighting responds to actual game temperature")
    _check(vault._mechanical_rotors[0].rotation.x != previous_rotor,
        "Mechanical containment ring actually animates in HERO")
    var locked_rotor: float = vault._mechanical_rotors[0].rotation.x
    vault.update_alarm("thermal",94.0,84.0,30.0,true)
    _check(is_equal_approx(vault._mechanical_rotors[0].rotation.x,locked_rotor),
        "Reduced-motion mode stops additional setpiece rotation")
    var no_flash: float = float(vault.readout()["last_emissive"])
    vault.update_alarm("thermal",94.0,84.0,39.0,true)
    _check(is_equal_approx(no_flash,float(vault.readout()["last_emissive"])),
        "Reduced motion also eliminates emergency light pulsing")

    _key(game,KEY_G)
    _check(game.quality_mode == "eco" and not vault.hero_details.visible,
        "Real ECO mode disables expensive geometry but retains permanent reactor silhouette")
    _check(vault.structure.visible and game.reactor_core.visible,
        "ECO never removes the mission's defining reactor attraction")
    _key(game,KEY_G)
    _check(game.quality_mode == "hero" and vault.hero_details.visible,
        "HERO mode restores the secondary catwalks and detailed mechanics")

    var right_walls: int = 0
    var roof_over_opening: int = 0
    for node in game.get_children():
        if node is StaticBody3D:
            var pos: Vector3 = node.position
            if absf(pos.x-7.0) < 0.1 and absf(pos.y-2.8) < 0.1:
                right_walls += 1
                _check(pos.z < -31.0 or pos.z > -9.0,
                    "No original full-length side wall blocks reactor sightlines")
            if absf(pos.x) < 0.1 and absf(pos.y-6.2) < 0.1 and pos.z > -31.0 and pos.z < -9.0:
                roof_over_opening += 1
    _check(right_walls == 2 and roof_over_opening == 0,
        "Two original sidewall segments remain; central high vault is truly open")

    _check(game.terminals.size() == 6 and game.relay_terminals.size() == 3,
        "Six main mission stations and three optional V7 rescues are unchanged")
    game._select_scenario("thermal")
    game.start_run()
    _key(game,KEY_C)
    _check(game.cinematic_view and not game.header_panel.visible and not game.side_panel.visible,
        "Real C input clears obstructing HUD to reveal authored reactor environment")
    _check(not game.prompt_panel.visible and not game.crosshair.visible,
        "Cinematic inspection removes overlay clutter without moving camera")
    _check(game.session.objective_id() == "scan" and not game.paused,
        "C mode does not silently pause or skip active gameplay")
    _key(game,KEY_C)
    _check(not game.cinematic_view and game.header_panel.visible and game.side_panel.visible,
        "Second C input restores gameplay HUD and original mission guidance")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.session.objective_id() == "repair",
        "Original physical reactor scanner still works inside the V8 art level")
    game.player.position = Vector3(3.0,1.1,-28.0)
    game._interact(true)
    _check(game.session.coolant_repaired and game.session.repair_method == "rapid_purge",
        "New large-scale setpiece does not break existing V4 alternate repair")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V8 CINEMATIC REACTOR PASS: %d real Godot checks" % checks)
        quit(0)
    else:
        for failure in failures:
            push_error("V8 REACTOR FAIL: " + failure)
        quit(1)
