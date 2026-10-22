extends SceneTree
var errors: int = 0
func _init() -> void:
    call_deferred("_test")
func _check(test: bool, name: String) -> void:
    if not test:
        errors += 1
        push_error("WAVE5 FAIL: " + name)
    else:
        print("WAVE5 PASS: ", name)
func _test() -> void:
    var game := (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var assets := game.get_node_or_null("Wave5DetailedEnvironment") as Node3D
    _check(assets != null, "modular environment present")
    if assets != null:
        for n in ["CoolantSkidWest","CoolantSkidEast","ArmouredSafetyVault","OverheadRoboticGantry","VentilationRotor_0"]:
            _check(assets.get_node_or_null(n) != null, "3D environment object " + n)
    var deck := game.get_node_or_null("MainDeck") as MeshInstance3D
    _check(deck != null and deck.material_override is StandardMaterial3D, "tiled real PBR deck")
    var env: WorldEnvironment = game.get_node_or_null("CinematicEnvironment") as WorldEnvironment
    _check(env != null, "cinematic WorldEnvironment")
    var meter: CanvasLayer = game.get_node_or_null("Wave5PerformanceProfiler") as CanvasLayer
    _check(meter != null, "local hardware telemetry exists")
    if meter != null:
        var r: Dictionary = meter.report()
        _check(r.has("adapter") and r.has("p95_frame_ms") and r.has("fps_1pct_low_estimate"), "hardware report structure")
        _check(not meter.export_report().is_empty(), "F10 saves a JSON file")
    var wave4: Node3D = game.get_node_or_null("MagnetAssembly/Wave4CNCMagnet") as Node3D
    _check(wave4 != null, "previous wave physics/magnet preserved")
    game.queue_free()
    print("WAVE5 SMOKE: ", "PASS" if errors == 0 else "FAIL", " errors=", errors)
    quit(0 if errors == 0 else 1)