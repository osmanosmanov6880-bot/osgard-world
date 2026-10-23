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
    game.save_path = "user://wave6_safe_smoke.json"
    root.add_child(game)
    await process_frame
    var director: Node3D = game.get_node_or_null("Wave6ArtDirector") as Node3D
    _check(director != null, "independent high-density city infrastructure")
    if director != null:
        _check(director.get_node_or_null("CivicSkyway") != null, "structural metro bridge")
        _check(director.get_node_or_null("CivicSkyway/ElevatedPromenade") != null, "large playable-city silhouette mesh")
        _check(director.get_node_or_null("SculptedCivicHall_00") != null, "distinct civic architecture")
        _check(director.get_node_or_null("AnimatedMetroShuttle_00") != null, "an animated physical commuter tram")
    var ground: MeshInstance3D = game.get_node_or_null("LivingCity/CitySurface") as MeshInstance3D
    _check(ground != null and ground.material_override is StandardMaterial3D, "independent realistic city paving")
    if ground != null and ground.material_override is StandardMaterial3D:
        var material := ground.material_override as StandardMaterial3D
        _check(material.normal_enabled and material.normal_texture != null, "surface micro-normal imported")
        _check(material.roughness_texture != null and material.metallic_texture != null, "independent roughness and metalness")
    _check(game.production_rate == 2.0 and game.district_count == 0, "economy and builds preserved")
    var bench: Node = game.get_node_or_null("Wave6HardwareBenchmark")
    _check(bench != null and not bool(bench.get("enabled")), "native GPU benchmark is opt-in")
    game.queue_free()
    await process_frame
    var save_file := ProjectSettings.globalize_path("user://wave6_safe_smoke.json")
    if FileAccess.file_exists(save_file):
        DirAccess.remove_absolute(save_file)
    print("OSGARD_WAVE6_EMPIRE_SMOKE: ", "PASS" if errors == 0 else "FAIL")
    quit(0 if errors == 0 else 1)