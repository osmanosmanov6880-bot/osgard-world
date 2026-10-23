extends RefCounted
## Original static visual instances are kept in scene (hidden) to preserve named tests.
## Equivalent meshes/materials under SAME parent become one MultiMesh draw group.
## Parent transforms stay dynamic; we never merge across parents or into core meshes.

static func _key(visual: MeshInstance3D) -> String:
    if visual.mesh == null or visual.material_override == null or not visual.visible:
        return ""
    if visual.get_child_count() > 0:
        return ""
    var mesh: Mesh = visual.mesh
    var shape: String = ""
    if mesh is BoxMesh:
        shape = "box|%s" % str((mesh as BoxMesh).size)
    elif mesh is CylinderMesh:
        var m := mesh as CylinderMesh
        shape = "cyl|%s|%s|%s|%d" % [m.top_radius,m.bottom_radius,m.height,m.radial_segments]
    elif mesh is SphereMesh:
        var m := mesh as SphereMesh
        shape = "sphere|%s|%s|%d|%d" % [m.radius,m.height,m.radial_segments,m.rings]
    elif mesh is TorusMesh:
        var m := mesh as TorusMesh
        shape = "torus|%s|%s|%d|%d" % [m.inner_radius,m.outer_radius,m.rings,m.ring_segments]
    else:
        return ""
    return "%s|material:%s|shadow:%d|layers:%d" % [shape,visual.material_override.get_instance_id(),visual.cast_shadow,visual.layers]

static func _visit(node: Node3D, metrics: Dictionary) -> void:
    if not node.visible:
        return
    var groups: Dictionary = {}
    for c in node.get_children():
        if c is MeshInstance3D:
            var visual := c as MeshInstance3D
            var key: String = _key(visual)
            if key != "":
                if not groups.has(key):
                    groups[key] = []
                (groups[key] as Array).append(visual)
    for key in groups:
        var visuals: Array = groups[key]
        if visuals.size() < 3:
            continue
        var first := visuals[0] as MeshInstance3D
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = first.mesh
        mm.instance_count = visuals.size()
        for idx in range(visuals.size()):
            var child: MeshInstance3D = visuals[idx] as MeshInstance3D
            mm.set_instance_transform(idx, child.transform)
            child.visible = false
        var grouped := MultiMeshInstance3D.new()
        grouped.name = "Wave5_StaticMeshBatch_%03d" % int(metrics["batches"])
        grouped.multimesh = mm
        grouped.material_override = first.material_override
        grouped.cast_shadow = first.cast_shadow
        grouped.layers = first.layers
        node.add_child(grouped)
        metrics["batches"] = int(metrics["batches"]) + 1
        metrics["instances"] = int(metrics["instances"]) + visuals.size()
    # Recurse only into actual authored subassemblies; never into GPU batches.
    for c in node.get_children():
        if (c is Node3D) and not (c is MultiMeshInstance3D) and not (c is MeshInstance3D):
            _visit(c as Node3D, metrics)

static func optimize(root: Node3D) -> Dictionary:
    var metrics: Dictionary = {"batches":0,"instances":0}
    _visit(root, metrics)
    print("OSGARD_WAVE5_STATIC_BATCHES: ", JSON.stringify(metrics))
    return metrics