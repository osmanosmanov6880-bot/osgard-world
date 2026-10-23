extends SceneTree
var failures: int = 0
func _init() -> void:
    call_deferred("_run")
func _test(ok: bool, msg: String) -> void:
    if ok:
        print("WAVE9 VECTOR PASS: ",msg)
    else:
        failures += 1
        push_error("WAVE9 VECTOR FAIL: "+msg)
func _run() -> void:
    var scene := load("res://scenes/main.tscn") as PackedScene
    _test(scene != null,"native Godot scene")
    if scene == null:
        quit(1)
        return
    var game := scene.instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var a := game.get_node_or_null("Wave9PrecisionLab") as Node3D
    _test(a != null,"Wave9 precision environment exists")
    if a != null:
        var magnet := game.get_node_or_null("MagnetAssembly/Wave9PrecisionMagneticCircuit") as Node3D
        _test(magnet != null,"CNC magnetic shield and actual copper busbar")
        if magnet != null:
            var tube := magnet.get_node_or_null("HelicalCopperBusbar") as MeshInstance3D
            _test(tube != null and tube.mesh is ArrayMesh,"conductor has custom indexed geometry")
            if tube != null and tube.mesh is ArrayMesh:
                _test(tube.mesh.surface_get_array_index_len(0)>1000,"real high-density 3D copper surface")
            var bolts := magnet.get_node_or_null("GPUForgedCrownClamps") as MultiMeshInstance3D
            _test(bolts != null and bolts.multimesh != null and bolts.multimesh.instance_count >= 48,"GPU-fastener batching")
            _test(magnet.get_node_or_null("ServoJaw_Left") != null,"independently articulated magnetic actuator")
        _test(a.get_node_or_null("Wave9HeavyEngineeringDeck/HydraulicStand_Left") != null,"machined safety equipment")
        _test(int(a.get("cable_vertices")) >= 300,"physical cable geometry")
    _test(game.STAGES.size() == 3 and game.state == "aiming","three original puzzle stages unaffected")
    _test(game.get_node_or_null("Wave6HardwareBenchmark") != null,"actual device benchmark preserved")
    game.queue_free()
    await process_frame
    print("OSGARD_WAVE9_VECTOR_SMOKE:", "PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
