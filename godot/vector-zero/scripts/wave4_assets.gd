extends RefCounted
## Wave 4 authored GLB assets: 2 PBR LODs for each hero assembly.
## PC defaults to 100k triangle magnet, Web auto-selects its 22k LOD.
## GLB meshes are generated deterministically by scripts/build_osgard_wave4_assets.py.

static func load_hero(name: String) -> Node3D:
    var tier: String = "web" if OS.has_feature("web") else "ultra"
    var path: String = "res://assets/wave4/%s_%s.glb" % [name, tier]
    var resource: Resource = load(path)
    if resource == null or not resource is PackedScene:
        push_error("Missing imported PBR GLB: " + path)
        return Node3D.new()
    return (resource as PackedScene).instantiate() as Node3D

static func decorate(magnet: Node3D, receiver: Node3D) -> void:
    var magnet_model: Node3D = load_hero("blackfield_magnet")
    magnet_model.name = "Wave4CNCMagnet"
    magnet.add_child(magnet_model)

    # New PBR machinery replaces previous overlapping placeholder cages.
    for legacy_name in ["HighPolyMagnetAssembly", "HeroMagnetV2", "Wave3MagnetAssembly"]:
        var old_node: Node3D = magnet.get_node_or_null(legacy_name) as Node3D
        if old_node != null:
            old_node.visible = false
    magnet_model.position.z = 0.65

    var receiver_model: Node3D = load_hero("blackfield_receiver")
    receiver_model.name = "Wave4CaptureIris"
    receiver.add_child(receiver_model)

    for legacy_name in ["HighPolyReceiverAssembly", "HeroCaptureIrisV2", "Wave3CaptureGate"]:
        var old_node: Node3D = receiver.get_node_or_null(legacy_name) as Node3D
        if old_node != null:
            old_node.visible = false
    receiver_model.position.z = 0.38

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