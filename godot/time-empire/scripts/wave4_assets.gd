extends RefCounted
## GLB PBR asset import with differentiated native Forward+ / Web budgets.

static func load_hero(name: String) -> Node3D:
    var tier: String = "web" if OS.has_feature("web") else "ultra"
    var path: String = "res://assets/wave4/%s_%s.glb" % [name, tier]
    var resource: Resource = load(path)
    if resource == null or not resource is PackedScene:
        push_error("Missing imported CHRONOS GLB asset: " + path)
        return Node3D.new()
    return (resource as PackedScene).instantiate() as Node3D

static func decorate(city: Node3D, core: Node3D) -> void:
    var reactor: Node3D = load_hero("chronos_reactor")
    reactor.name = "Wave4ChronoReactor"
    core.add_child(reactor)

    var architecture := Node3D.new()
    architecture.name = "Wave4AuthoredLandmarks"
    city.add_child(architecture)

    var tower_a: Node3D = load_hero("civic_spire")
    tower_a.name = "SpireWestPBR"
    tower_a.position = Vector3(-18.0, 0.55, 14.0)
    tower_a.rotate_y(-0.26)
    architecture.add_child(tower_a)

    var tower_b: Node3D = load_hero("civic_spire")
    tower_b.name = "SpireEastPBR"
    tower_b.position = Vector3(17.0, 0.55, -15.0)
    tower_b.rotate_y(0.47)
    tower_b.scale = Vector3(0.89, 0.82, 0.89)
    architecture.add_child(tower_b)

static func triangle_count(n: Node) -> int:
    var triangles: int = 0
    if n is MeshInstance3D:
        var m: Mesh = (n as MeshInstance3D).mesh
        if m != null:
            for surf in range(m.get_surface_count()):
                var indices: int = m.surface_get_array_index_len(surf)
                triangles += int(indices / 3) if indices > 0 else int(m.surface_get_array_len(surf) / 3)
    for child in n.get_children():
        triangles += triangle_count(child)
    return triangles