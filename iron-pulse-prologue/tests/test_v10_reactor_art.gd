extends SceneTree
## V10 real source-bound cinematography regression: the original giant cyan
## roof beam is replaced with believable far-wall industrial fixtures, and
## containment halo safety loops become solid machine metal.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool,label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var source: PackedScene = load("res://Main.tscn")
    _check(source != null,"Same original playable Godot scene still imports")
    if source == null:
        _finish()
        return
    var game = source.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var vault: IPReactorAtrium = game.reactor_atrium
    var art: IPCinematicStage = game.art_stage
    var info: Dictionary = vault.readout()
    _check(int(info.get("filmic_roof_lights",0))==6 and int(info.get("continuous_emissive_roof_beams",-1))==0,
        "New art pass explicitly replaces all six old 8.7m cyan camera-axis beams")
    _check(float(info.get("far_wall_fixture_depth",0.0))>16.8,
        "Real new fixtures are mounted to far retaining wall, not floating on camera sightline")
    _check(int(info.get("machined_steel_thermal_hoops",0))==3,
        "Three thermal containment hoops are genuine load-bearing steel instead of cyan neon")
    _check(int(info.get("discrete_amber_latch_details",0))==6,
        "Original small warning latch components replace full neon rings")
    _check(int(info.get("real_lights",0))==5 and int(info.get("diegetic_signs",0))==3,
        "No extra expensive lamps or missing real industrial signage")
    for index in range(6):
        var strip: MeshInstance3D = vault.get_node_or_null("PermanentShell/VaultFarCeilingLight_%d" % index) as MeshInstance3D
        var recess: MeshInstance3D = vault.get_node_or_null("PermanentShell/VaultCeilingFixtureRecess_%d" % index) as MeshInstance3D
        _check(strip != null and recess != null,
            "Each roof light is now a real recessed industrial fixture at index "+str(index))
        if strip != null:
            _check(strip.position.x > 16.8 and (strip.mesh as BoxMesh).size.x < 0.30,
                "Roof luminaire physically shortened from 8.7m camera beam to compact far-wall sconce")
            _check((strip.mesh as BoxMesh).size.z > 1.0,
                "Directional luminaire remains large enough to imply genuine industrial lighting")
        if recess != null:
            _check(recess.position.x > strip.position.x,
                "Original lamp sits in physically authored recessed housing")
    var containment: Node3D = vault.shield_housing
    for height in [-3.9,0.0,3.9]:
        var ident: int = int(height*10)
        var hoop: MeshInstance3D = containment.get_node_or_null("PlasmaContainmentTrim_%d" % ident) as MeshInstance3D
        _check(hoop != null and hoop.mesh is TorusMesh,
            "Original precise containment thermal hoop still exists: "+str(ident))
        _check(hoop.material_override == vault._steel and not (hoop.material_override as StandardMaterial3D).emission_enabled,
            "Full-width hoop is real restrained steel rather than a flat cyan bar")
        for side in [-1,1]:
            var latch: MeshInstance3D = containment.get_node_or_null("SafetyLatch_%d_%d" % [ident,side]) as MeshInstance3D
            _check(latch != null and latch.material_override == vault._warning,
                "Real discrete warning latch supplies legible safety state at both sides")
    var perim: MeshInstance3D = art.hero_details.get_node_or_null("ContainmentPerimeter") as MeshInstance3D
    _check(perim != null and perim.mesh is TorusMesh,
        "Original architectural external containment perimeter remains")
    _check(not (perim.material_override as StandardMaterial3D).emission_enabled,
        "Exterior structural ring no longer overwhelms core with 360-degree cyan emissive line")
    _check(vault._lights.size()==5 and vault._lights[1].light_energy >= 2.4,
        "Existing real key light preserves readable metal after removal of decorative bars")
    _check(vault.readout()["pbr_texture_maps"]==3 and game.reactor_core.material_override==vault.core_plasma_material,
        "Original surface PBR maps and heat-driven live reactor plasma are fully intact")
    _check(game.cascade_world.stations.size()==4 and game.terminals.size()==6 and game.relay_terminals.size()==3,
        "V9 physical mission and both original action layers remain playable")
    game._select_scenario("thermal")
    game.start_run()
    var old_pos: Vector3 = game.player.position
    var before: Dictionary = game.session.checkpoint()
    var key := InputEventKey.new()
    key.pressed = true
    key.keycode = KEY_C
    game._input(key)
    _check(game.cinematic_view and game.get_viewport().get_camera_3d()==vault.director_camera,
        "Real Godot A7 camera views the redesigned reactor, not a separate render")
    game._input(key)
    _check(not game.cinematic_view and game.get_viewport().get_camera_3d()==game.camera,
        "Original first-person camera and HUD recover after new art inspection")
    _check(game.player.position==old_pos and game.session.checkpoint()==before,
        "AAA-art changes never rewrite real mission resources or save state")
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key=="scan",
        "Actual game, scanner and MARA radio still work in redesigned scene")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V10 CINEMATIC ART PASS: %d real Godot checks" % checks)
        quit(0)
    else:
        for item in failures:
            push_error("V10 ART FAIL: "+item)
        quit(1)
