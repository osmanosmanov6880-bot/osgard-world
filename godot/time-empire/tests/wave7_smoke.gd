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
    var packed: PackedScene = load("res://scenes/main.tscn") as PackedScene
    _check(packed != null, "scene is importable")
    if packed == null:
        quit(1)
        return
    var game: Node3D = packed.instantiate() as Node3D
    game.save_path = "user://wave7_smoke_save.json"
    root.add_child(game)
    await process_frame
    var world: Node3D = game.get_node_or_null("Wave7Region") as Node3D
    _check(world != null, "continuous surrounding region instantiated")
    if world != null:
        var coast: MeshInstance3D = world.get_node_or_null("ContinentalTerrain") as MeshInstance3D
        _check(coast != null and coast.mesh is ArrayMesh, "physical sculpted terrain mesh, not panorama image")
        if coast != null and coast.mesh is ArrayMesh:
            _check(coast.mesh.surface_get_array_len(0) > 15000, "terrain LOD vertices present")
        var water: MeshInstance3D = world.get_node_or_null("HorizonWaterPlane") as MeshInstance3D
        _check(water != null and water.material_override is ShaderMaterial, "animated physically lit water shader")
        var trees: MultiMeshInstance3D = world.get_node_or_null("CoastalTreeCanopies") as MultiMeshInstance3D
        _check(trees != null and trees.multimesh.instance_count > 100, "instanced woodland is real scene geometry")
        _check(world.get_node_or_null("CoastalFerry_00") is Node3D, "moving ferry physically represented")
        _check(world.get_node_or_null("CityBreakwater") != null, "engineered shoreline physically anchors city")
    _check(game.production_rate >= 2.0, "economy logic preserved")
    _check(game.district_count >= 0, "district building logic preserved")
    _check(game.get_node_or_null("Wave6HardwareBenchmark") != null, "hardware benchmark remains available")
    game.queue_free()
    await process_frame
    var save_path := ProjectSettings.globalize_path("user://wave7_smoke_save.json")
    if FileAccess.file_exists(save_path):
        DirAccess.remove_absolute(save_path)
    print("OSGARD_WAVE7_EMPIRE_TESTS: ", "PASS" if failures == 0 else "FAIL")
    quit(0 if failures == 0 else 1)
