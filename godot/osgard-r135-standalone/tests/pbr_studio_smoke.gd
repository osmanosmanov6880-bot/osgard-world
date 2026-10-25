extends SceneTree
## W23 tests the actual, preserved imported 1024px PBR textures in native Godot.
## HERO is art only. ECO keeps exact W19 draw and physics budgets.

func _initialize() -> void:
    call_deferred("_run")


func _fail(message: String) -> void:
    push_error("W23 REAL PBR FAILED: " + message)
    quit(1)


func _run() -> void:
    var scene: PackedScene = load("res://Main.tscn") as PackedScene
    if scene == null:
        _fail("Actual original Godot simulator scene missing")
        return
    var game: Node = scene.instantiate()
    root.add_child(game)
    await process_frame
    await process_frame
    var studio: Node3D = game.get("studio") as Node3D
    var director: Node = game.get("controller") as Node
    if studio == null or director == null:
        _fail("Stage and genuine R135 service simulation must be present")
        return
    var eco: Dictionary = studio.call("render_budget")
    if int(eco.get("grid_draw_batches", -1)) != 2 or int(eco.get("grid_instances", -1)) != 18:
        _fail("ECO must retain original two floor batches")
        return
    if int(eco.get("luxury_draw_batches", -1)) != 5 or int(eco.get("luxury_instances", -1)) != 41:
        _fail("Original W19 set dressing counts changed")
        return
    if int(eco.get("single_mesh_nodes", -1)) != 8:
        _fail("ECO gained expensive single-mesh shadow casters")
        return
    if int(eco.get("hero_extra_instanced_batches", -1)) != 0 or bool(eco.get("hero_pbr_active", true)):
        _fail("Mobile ECO must not allocate HERO microgeometry and PBR shading")
        return
    for path in ["HeroOverheadCableTrays","HeroRearCabinetMetalBorders","HeroCopperServiceConduits"]:
        var mesh: Node = studio.get_node_or_null(path)
        if not (mesh is MultiMeshInstance3D) or (mesh as MultiMeshInstance3D).visible:
            _fail("HERO detail must be instanced and hidden before quality upgrade: " + path)
            return
        if (mesh as MultiMeshInstance3D).cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF:
            _fail("HERO decorative architecture must not cast dynamic shadows")
            return
    game.call("_toggle_quality")
    await process_frame
    var hero: Dictionary = studio.call("render_budget")
    if int(hero.get("stage_quality", -1)) != 2 or int(hero.get("real_pbr_source_sets", 0)) != 4:
        _fail("HERO did not load four real original PBR material families")
        return
    if int(hero.get("real_pbr_maps", -1)) != 12 or int(hero.get("real_pbr_load_failures", -1)) != 0:
        _fail("HERO original albedo/normal/ORM textures missing")
        return
    if not bool(hero.get("hero_pbr_active", false)):
        _fail("HERO source texture BRDF not active")
        return
    if int(hero.get("hero_extra_instanced_batches", -1)) != 3 or int(hero.get("hero_extra_instances", -1)) != 20:
        _fail("W23 HERO set dressing must be exactly 3 GPU batches/20 parts")
        return
    if int(hero.get("hero_extra_casters", -1)) != 0:
        _fail("HERO additional detail must not introduce real-time shadow cost")
        return
    var surfaces: Array = studio.get("pbr_targets")
    if surfaces.size() != 4:
        _fail("No real PBR materials attached to studio boxes")
        return
    for mat in surfaces:
        var surface: StandardMaterial3D = mat as StandardMaterial3D
        if surface == null or surface.albedo_texture == null or surface.normal_texture == null:
            _fail("A studio wall/floor/copper mesh is missing true imported PBR maps")
            return
        if not surface.normal_enabled or not surface.ao_enabled or surface.roughness_texture == null or surface.metallic_texture == null:
            _fail("Source ORM channel separation or normal mapping not configured")
            return
        if surface.ao_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_RED \
                or surface.roughness_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_GREEN \
                or surface.metallic_texture_channel != BaseMaterial3D.TEXTURE_CHANNEL_BLUE:
            _fail("Real glTF-style original ORM maps must use R AO, G roughness, B metal")
            return
        if not surface.uv1_triplanar:
            _fail("Tiled studio box textures must avoid stretched UVs in HERO")
            return
    for node in studio.get("hero_only_nodes"):
        if not (node as MultiMeshInstance3D).visible:
            _fail("HERO detail was constructed but never shown in the actual scene")
            return
    if not str(director.call("summary").get("loaded", "")).ends_with("service_spine_hero.glb"):
        _fail("Real HERO GLB did not switch when enabling expensive PBR")
        return
    game.call("_toggle_quality")
    await process_frame
    var restored: Dictionary = studio.call("render_budget")
    if int(restored.get("stage_quality", -1)) != 0 or int(restored.get("hero_extra_instanced_batches", -1)) != 0:
        _fail("ECO did not restore cheaper architectural draw budget")
        return
    for mat in surfaces:
        var surface: StandardMaterial3D = mat as StandardMaterial3D
        if surface.normal_enabled or surface.albedo_texture != null or surface.ao_enabled:
            _fail("ECO still performs expensive HERO PBR texture lookups")
            return
    for node in studio.get("hero_only_nodes"):
        if (node as MultiMeshInstance3D).visible:
            _fail("ECO failed to hide HERO microgeometry")
            return
    if not str(director.call("summary").get("loaded", "")).ends_with("service_spine_eco.glb"):
        _fail("Original source ECO GLB not restored")
        return
    print("W23 REAL PBR PASS: 12 original maps, 4 materials, 3 HERO GPU batches, ECO exact W19 budget, two source GLBs")
    game.queue_free()
    quit(0)
