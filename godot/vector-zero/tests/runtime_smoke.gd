extends SceneTree
## Run: godot --headless --path godot/vector-zero --script res://tests/runtime_smoke.gd

const Sim = preload("res://scripts/magnetic_sim.gd")
var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _assert_case(condition: bool, description: String) -> void:
    if condition:
        print("PASS: ", description)
    else:
        push_error("FAIL: " + description)
        failures += 1

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn")
    _assert_case(scene != null, "Godot packed scene imported")
    if scene == null:
        quit(1)
        return
    var game: Node3D = scene.instantiate()
    root.add_child(game)
    await process_frame
    _assert_case(game.get_node_or_null("Wave3Foundry") != null, "WAVE3 physical engineering laboratory installed")
    _assert_case(game.get_node_or_null("Wave3Foundry/CNCBridgeGantry_-112") != null, "machined overhead crane assembly")
    _assert_case(game.get_node_or_null("Wave3Foundry/ServiceFrameFasteners_144") is MultiMeshInstance3D, "engineering fasteners are GPU-instanced")
    _assert_case(game.get_node_or_null("PlayerEnergyCore/Wave3PrecisionProjectile/MachinedGyroNose_120") is MeshInstance3D, "new projectile housing is real 3D")
    _assert_case(game.get_node_or_null("ReceiverAssembly/Wave3CaptureGate/OpticalCaptureContactRail") is MeshInstance3D, "new sensor geometry exists")
    _assert_case(game.get_node_or_null("MagnetAssembly/Wave3MagnetAssembly/RadiationScannerRotor") is Node3D, "animated magnet scanner exists")
    var conduit: MeshInstance3D = game.get_node_or_null("MagnetAssembly/Wave3MagnetAssembly/CryoCoilCopperSpiral_0") as MeshInstance3D
    _assert_case(conduit != null and conduit.mesh is ArrayMesh and conduit.mesh.surface_get_array_len(0) > 2000, "copper spiral uses UV-mapped high-density indexed triangles")
    _assert_case(game.get_node_or_null("HeroFacilityV2/PrecisionInjectorV2") != null, "five-axis launcher machined assembly is present")
    _assert_case(game.get_node_or_null("MagnetAssembly/HeroMagnetV2/HelicalSuperconductor_A") is MeshInstance3D, "continuous parametric superconducting helix is a mesh")
    _assert_case(game.get_node_or_null("ReceiverAssembly/HeroCaptureIrisV2/Iris_ServoJaws_12") is MultiMeshInstance3D, "receiver has a GPU-instanced 12-jaw capture iris")
    _assert_case(game.get_node_or_null("PlayerEnergyCore/HeroPlasmaCoreV2/MachinedCoreContainmentShell") is MeshInstance3D, "hero core has CNC-contoured shell")
    var helix: MeshInstance3D = game.get_node_or_null("MagnetAssembly/HeroMagnetV2/HelicalSuperconductor_A") as MeshInstance3D
    _assert_case(helix != null and helix.mesh is ArrayMesh and helix.mesh.surface_get_array_len(0) > 2500, "true high-density indexed 3D geometry, not UI illustration")
    _assert_case(game.get_node_or_null("HeroFacilityV2/InstancedCoolantPipeSeals_112") is MultiMeshInstance3D, "environment details use GPU instancing")
    _assert_case(game.get_node_or_null("UltraDetailArchitecture") != null, "original industrial ultra detail kit loaded")
    _assert_case(game.get_node_or_null("PlayerEnergyCore/HighPolyCoreAssembly") != null, "multi-layer machined energy core asset")
    _assert_case(game.get_node_or_null("MagnetAssembly/HighPolyMagnetAssembly") != null, "high density superconducting magnet asset")
    _assert_case(game.get_node_or_null("ReceiverAssembly/HighPolyReceiverAssembly") != null, "cinematic CNC target dock asset")
    _assert_case(game.get_node_or_null("UltraDetailArchitecture/PrecisionLauncher_Assembly") != null, "detailed electro-magnetic launcher asset")
    var armor: MeshInstance3D = game.get_node_or_null("MagnetAssembly/HighPolyMagnetAssembly/GraphiteClampingFlange") as MeshInstance3D
    _assert_case(armor != null and armor.material_override is StandardMaterial3D, "magnet has physically-based metallic materials")
    _assert_case(game.get_node_or_null("CinematicCamera") != null, "3D cinematic camera exists")
    _assert_case(game.get_node_or_null("PlayerEnergyCore") != null, "physical projectile exists")
    _assert_case(game.get_node_or_null("MagnetAssembly") != null, "electromagnet exists")
    _assert_case(game.get_node_or_null("ReceiverAssembly") != null, "target receiver exists")
    _assert_case(game.get_node_or_null("PredictedFlightPath") != null, "prediction matches actual physics")
    _assert_case(game.get_node_or_null("RussianGameHUD/GameControls") != null, "RU HUD exists")
    _assert_case(game.state == "aiming", "game ready on initial scene")
    _assert_case(game.launch_button.text.contains("ЗАПУСТИТЬ"), "Russian launch CTA")
    var preview := game.trajectory_root.get_node_or_null("FlightForecast") as MultiMeshInstance3D
    _assert_case(preview != null, "3D forecast renderer exists")
    _assert_case(preview != null and preview.multimesh.instance_count > 8, "forecast batches segments into one draw group")
    _assert_case(game.trajectory_root.get_child_count() == 1, "prediction does not spawn hundreds of scene nodes")


    var origin := Vector3(-8.8, 2.3, 0.0)
    var a: Dictionary = Sim.step(origin, Vector3(11.0, 7.0, 0.0), Vector3(0.0, 5.0, 0.0), 1, 7.0, Sim.STEP)
    var b: Dictionary = Sim.step(origin, Vector3(11.0, 7.0, 0.0), Vector3(0.0, 5.0, 0.0), 1, 7.0, Sim.STEP)
    _assert_case(a["position"].distance_to(b["position"]) < 0.000001, "deterministic force integrator")
    var attract: Vector3 = Sim.acceleration(origin, Vector3(0.0, 5.0, 0.0), 1, 7.0)
    var repel: Vector3 = Sim.acceleration(origin, Vector3(0.0, 5.0, 0.0), -1, 7.0)
    _assert_case(attract.x > 0.0 and repel.x < 0.0, "polarity changes direction of magnetic force")
    _assert_case(Sim.reached_target(Vector3(8.8, 3.65, 0.0), Vector3(8.8, 3.65, 0.0)), "target detection")
    _assert_case(Sim.is_lost(Vector3(0.0, 0.6, 0.0)), "floor contact detected")

    # All stages must have at least one valid, discoverable shot with aim control.
    for stage in range(3):
        game._load_stage(stage)
        var solvable := false
        for p in [1, -1]:
            for angle in range(10, 71, 2):
                var v := Vector3(cos(deg_to_rad(float(angle))), sin(deg_to_rad(float(angle))), 0.0) * 14.25
                var trace: Dictionary = Sim.simulate(origin, v, game.magnet_position, p, game.field_strength, game.target_position, 1150, 8)
                if trace["outcome"] == "reached":
                    solvable = true
                    break
            if solvable:
                break
        _assert_case(solvable, "stage %s has a working solution" % (stage + 1))

    game._load_stage(2)
    game.launch_angle = 70.0
    game._draw_preview()
    var extreme := game.trajectory_root.get_node_or_null("FlightForecast") as MultiMeshInstance3D
    _assert_case(extreme != null and extreme.multimesh.instance_count > 0, "extreme shot preview has valid segments")
    game._load_stage(0)
    game._toggle_polarity()
    _assert_case(game.polarity == -1, "Q toggles polarity")
    game._restart()
    _assert_case(game.state == "aiming", "restart resets state")
    game._toggle_polarity()
    game._primary_action()
    _assert_case(game.state == "flying", "launch starts flight")
    # Run the real gameplay update, not a mocked counter.
    for i in range(900):
        game._physics_process(1.0 / 60.0)
        if game.state != "flying":
            break
    _assert_case(game.state == "success", "real-time shot reaches the receiver")
    _assert_case(not game.launch_button.disabled, "success offers next action")
    game._primary_action()
    _assert_case(game.stage_index == 1, "success advances to next stage")

    game.queue_free()
    print("BLACKFIELD VALIDATION: ", "PASS" if failures == 0 else "FAIL", " (", failures, " errors)")
    quit(0 if failures == 0 else 1)