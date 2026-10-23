extends SceneTree
var failures: int = 0
func _init() -> void:
    call_deferred("_run")
func _test(ok: bool, msg: String) -> void:
    if ok:
        print("WAVE9 EMPIRE PASS: ",msg)
    else:
        failures += 1
        push_error("WAVE9 EMPIRE FAIL: "+msg)
func _run() -> void:
    var scene := load("res://scenes/main.tscn") as PackedScene
    _test(scene != null,"actual Godot city game")
    if scene == null:
        quit(1)
        return
    var game := scene.instantiate() as Node3D
    game.save_path = "user://wave9_city_smoke.json"
    root.add_child(game)
    await process_frame
    var a := game.get_node_or_null("Wave9CoastalCity") as Node3D
    _test(a != null,"Wave9 coastal expansion instantiated")
    if a != null:
        var terraced := a.get_node_or_null("Wave9TerracedWaterfront") as Node3D
        _test(terraced != null,"physical harbor terrace")
        if terraced != null:
            var deck := terraced.get_node_or_null("GPUBatchedWaterfrontDeck") as MultiMeshInstance3D
            _test(deck != null and deck.multimesh != null and deck.multimesh.instance_count >= 50,"GPU waterfront tile batching")
            var piles := terraced.get_node_or_null("GPUDeepWaterFoundations") as MultiMeshInstance3D
            _test(piles != null and piles.multimesh != null and piles.multimesh.instance_count >= 24,"anchored physical seawall")
        var park := a.get_node_or_null("Wave9BiodiverseParkBelt/GPUCanopyFoliage") as MultiMeshInstance3D
        _test(park != null and park.multimesh != null and park.multimesh.instance_count >= 75,"landscape is real GPU instanced geometry")
        _test(a.get_node_or_null("Wave9CivicObservatory/PanoramicObservationGlazing") is MeshInstance3D,"unique civic architecture")
        _test(a.get_node_or_null("Wave9WatersideServiceRail/ShoreShuttle_00") != null,"animated transit retained")
    _test(game.production_rate >= 2.0 and game.core_level >= 1,"time economy unaffected")
    _test(game.get_node_or_null("Wave7Region/ContinentalTerrain") != null,"previous coastline intact")
    _test(game.get_node_or_null("Wave6HardwareBenchmark") != null,"hardware benchmark preserved")
    game.queue_free()
    await process_frame
    print("OSGARD_WAVE9_EMPIRE_SMOKE:","PASS" if failures==0 else "FAIL")
    quit(0 if failures==0 else 1)
