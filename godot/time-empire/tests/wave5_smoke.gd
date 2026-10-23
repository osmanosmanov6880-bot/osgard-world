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
    game.save_path = "user://osgard_wave5_test_dont_override_save.json"
    root.add_child(game)
    await process_frame
    var assets: Node3D = game.get_node_or_null("Wave5DetailedEnvironment") as Node3D
    _check(assets != null, "modular city environment present")
    if assets != null:
        for n in ["ArcologyNorthernCrown","ArcologySouthernCrown","MetroInterchange","SolarResearchFarm","IndependentReactorPulse"]:
            _check(assets.get_node_or_null(n) != null, "3D city asset " + n)
    var deck: MeshInstance3D = game.get_node_or_null("LivingCity/CitySurface") as MeshInstance3D
    _check(deck != null and deck.material_override is StandardMaterial3D, "tileable PBR city ground")
    var environment: WorldEnvironment = game.get_node_or_null("ChronosAtmosphere") as WorldEnvironment
    _check(environment != null, "cinematic environment exists")
    var meter: CanvasLayer = game.get_node_or_null("Wave5PerformanceProfiler") as CanvasLayer
    _check(meter != null and meter.report().has("adapter"), "hardware telemetry exists")
    _check(game.production_rate == 2.0 and game.district_count == 0, "economy and save state preserved")
    if meter != null:
        _check(not meter.export_report().is_empty(), "local JSON hardware export")
    game.queue_free()
    await process_frame
    if FileAccess.file_exists("user://osgard_wave5_test_dont_override_save.json"):
        DirAccess.remove_absolute(ProjectSettings.globalize_path("user://osgard_wave5_test_dont_override_save.json"))
    print("WAVE5 SMOKE: ", "PASS" if errors == 0 else "FAIL", " errors=", errors)
    quit(0 if errors == 0 else 1)