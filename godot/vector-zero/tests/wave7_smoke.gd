extends SceneTree
var failures: int = 0

func _init() -> void:
    call_deferred("_run")

func _check(ok: bool, description: String) -> void:
    if ok:
        print("WAVE7 PASS: ", description)
    else:
        failures += 1
        push_error("WAVE7 FAIL: " + description)

func _run() -> void:
    var scene: PackedScene = load("res://scenes/main.tscn") as PackedScene
    _check(scene != null, "valid source scene")
    if scene == null:
        quit(1)
        return
    var game: Node3D = scene.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var director: Node3D = game.get_node_or_null("Wave7Lab") as Node3D
    _check(director != null, "real Wave 7 machinery present")
    var coil: MeshInstance3D = game.get_node_or_null("MagnetAssembly/Wave7PrecisionInductor/DuplexInductionWindings/CNCContinuousCopperA") as MeshInstance3D
    _check(coil != null and coil.mesh is ArrayMesh, "CNC induction winding is an indexed 3D mesh")
    if coil != null and coil.mesh is ArrayMesh:
        _check(coil.mesh.surface_get_array_len(0) > 900, "coil mesh has sufficient geometry")
        _check(coil.material_override is StandardMaterial3D, "PBR copper material applied")
    if director != null:
        _check(director.get_node_or_null("HydraulicServiceBay_West") != null, "west precision bay")
        _check(director.get_node_or_null("HydraulicServiceBay_East") != null, "east precision bay")
        _check(director.get_node_or_null("OverheadPowerSpine/StructuralBelt") is MeshInstance3D, "major architectural power spine")
        _check(director.get("helix_triangles") > 1500, "substantial geometric detail not flat illustration")
    _check(game.get_node_or_null("Wave6HardwareBenchmark") != null, "reproducible benchmarking preserved")
    _check(game.STAGES.size() == 3, "three interactive magnetic tests retained")
    _check(game.state == "aiming", "puzzle remains ready to play")
    game.queue_free()
    await process_frame
    print("OSGARD_WAVE7_VECTOR_TESTS: ", "PASS" if failures == 0 else "FAIL")
    quit(0 if failures == 0 else 1)
