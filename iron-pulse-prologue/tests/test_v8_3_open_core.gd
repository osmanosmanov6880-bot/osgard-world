extends SceneTree
## V8.3: source-bound open reactor core cinematic quality regression.
var checks: int = 0
var failures: Array[String] = []

func _initialize() -> void:
    call_deferred("_run")

func _check(ok: bool, label: String) -> void:
    checks += 1
    if not ok:
        failures.append(label)

func _run() -> void:
    var packed: PackedScene = load("res://Main.tscn")
    _check(packed != null, "Actual Godot main scene still imports")
    if packed == null:
        _finish()
        return
    var game = packed.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var vault: IPReactorAtrium = game.reactor_atrium
    var machinery: Node3D = vault.shield_housing
    _check(machinery != null and machinery.name == "TwelveMeterContainmentAssembly",
        "Real original containment machine survives cinematic art refinement")
    _check(vault.readout().get("open_core_inspection") is bool and vault.readout()["open_core_inspection"],
        "Physical camera-facing reactor inspection throat is truly opened")
    for index in [4,5,6]:
        _check(machinery.get_node_or_null("ReactorHeatShield_%02d" % index) == null,
            "Near-side opaque vertical pillar removed from actual 3D sightline: "+str(index))
    for index in [0,1,2,3,7,8,9]:
        var remaining: Node3D = machinery.get_node_or_null("ReactorHeatShield_%02d" % index)
        _check(remaining != null and remaining.get_node_or_null("ArmouredVerticalCassette") is MeshInstance3D,
            "Seven side/back structural armour cassettes remain actual geometry: "+str(index))
    for index in [5,6,7]:
        _check(machinery.get_node_or_null("CustomUV_ArmourCassette_%02d" % index) == null,
            "Near-facing decorative plating does not hide energy core: "+str(index))
    _check(machinery.get_node_or_null("CustomUV_ArmourCassette_00") is MeshInstance3D,
        "Original bespoke UV metallic panelling survives on the rear frame")
    _check(vault.readout()["monumental_geometry"] >= 130,
        "Cinematic aperture does not hollow the 3D reactor into an empty mockup")
    _check(vault.readout()["instanced_fasteners"] == 216,
        "216 GPU-instanced armour fasteners survive geometry refinement")
    _check(game.reactor_core is MeshInstance3D and game.reactor_core.material_override == vault.core_plasma_material,
        "Bright plasma shader is installed on original animated Godot reactor sphere")
    var shader_code: String = vault.core_plasma_material.shader.code
    _check(shader_code.contains("white_hot") and shader_code.contains("EMISSION"),
        "Shader has real vivid ionized filaments rather than just flat blue albedo")
    _check(vault.director_camera != null and vault.director_camera.is_inside_tree(),
        "Camera is a physical 3D node inside the same game world")
    var gaze: Vector3 = (game.reactor_core.global_position-vault.director_camera.global_position).normalized()
    _check((-vault.director_camera.global_transform.basis.z).dot(gaze)>0.995,
        "Security camera still targets now-uncovered moving plasma sphere")
    vault.update_alarm("thermal",94.0,70.0,8.0,false)
    _check(float(vault.core_plasma_material.get_shader_parameter("thermal_bias")) >= 0.99,
        "Thermal scenario genuinely affects visible emissive plasma palette")
    vault.update_alarm("breach",50.0,20.0,8.0,true)
    var paused_phase: float = float(vault.core_plasma_material.get_shader_parameter("motion_clock"))
    vault.update_alarm("breach",50.0,20.0,35.0,true)
    _check(is_equal_approx(paused_phase,float(vault.core_plasma_material.get_shader_parameter("motion_clock"))),
        "Reduced-motion option still freezes vivid plasma simulation")
    game._select_scenario("breach")
    game.start_run()
    game.player.position = Vector3(-3.0,1.1,-15.5)
    game._interact()
    _check(game.session.core_scanned and game.story.latest_key == "scan",
        "Original playable medical/engineering emergency loop is still operational")
    _check(game.terminals.size() == 6 and game.relay_terminals.size() == 3,
        "Main six systems and three rescue consoles retained without moving")
    game.queue_free()
    await process_frame
    _finish()

func _finish() -> void:
    if failures.is_empty():
        print("IRON PULSE V8.3 OPEN CORE PASS: %d real geometry and gameplay checks" % checks)
        quit(0)
    else:
        for issue in failures:
            push_error("V8.3 ART REVEAL FAIL: "+issue)
        quit(1)
