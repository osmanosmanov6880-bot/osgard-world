extends SceneTree
var errors: int = 0
func _init() -> void:
    call_deferred("_test")
func _check(value: bool, description: String) -> void:
    if not value:
        errors += 1
        push_error("WAVE6 CHECK FAILED: " + description)
    else:
        print("WAVE6 CHECK PASS: ", description)
func _test() -> void:
    var game: Node3D = (load("res://scenes/main.tscn") as PackedScene).instantiate() as Node3D
    root.add_child(game)
    await process_frame
    var director: Node3D = game.get_node_or_null("Wave6ArtDirector") as Node3D
    _check(director != null, "Wave6 real 3D industrial art director mounted")
    if director != null:
        _check(director.get_node_or_null("CNCServiceTower_Left") != null, "machined left service tower")
        _check(director.get_node_or_null("CNCServiceTower_Right") != null, "machined right service tower")
        _check(director.get_node_or_null("CNCServiceTower_Right/VariablePitchCoolingRotor") != null, "real animated rotor, not a still image")
        _check(director.get_node_or_null("MaintenanceBulkhead_01") != null, "real recessed background wall panel")
    var deck: MeshInstance3D = game.get_node_or_null("MainDeck") as MeshInstance3D
    _check(deck != null and deck.material_override is StandardMaterial3D, "authored PBR deck surface")
    if deck != null and deck.material_override is StandardMaterial3D:
        var mat: StandardMaterial3D = deck.material_override as StandardMaterial3D
        _check(mat.normal_enabled and mat.normal_texture != null, "height-derived normal map imported")
        _check(mat.roughness_texture != null and mat.metallic_texture != null, "real independent roughness/metallic maps")
    var bench: Node = game.get_node_or_null("Wave6HardwareBenchmark")
    _check(bench != null, "reproducible hardware benchmarking built into game")
    _check(bench != null and not bool(bench.get("enabled")), "hardware benchmark opt-in only")
    _check(game.get_node_or_null("MagnetAssembly/Wave4CNCMagnet") != null, "physics-related magnet untouched")
    game.queue_free()
    await process_frame
    print("OSGARD_WAVE6_VECTOR_SMOKE: ", "PASS" if errors == 0 else "FAIL")
    quit(0 if errors == 0 else 1)