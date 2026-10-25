extends Node3D
## R135 W7. Quiet industrial studio: physically grounded matte surfaces and
## two batched floor grids. Purely visual; no simulated machinery is moved.
## ECO avoids costly reflections or hot emissive surfaces.
var grid_instances: int = 0
var grid_draw_batches: int = 0
var detail_instances: int = 0
var detail_draw_batches: int = 0
var single_mesh_nodes: int = 0
var quality: int = 0
var stripe_material: StandardMaterial3D
var copper_material: StandardMaterial3D
var fastener_material: StandardMaterial3D

func configure() -> void:
    var stage_mat: StandardMaterial3D = _surface(Color(0.085, 0.098, 0.115), 0.20, 0.83)
    var wall_mat: StandardMaterial3D = _surface(Color(0.065, 0.078, 0.094), 0.12, 0.90)
    var frame_mat: StandardMaterial3D = _surface(Color(0.14, 0.17, 0.19), 0.40, 0.62)
    stripe_material = _surface(Color(0.20, 0.28, 0.31), 0.38, 0.74)
    copper_material = _surface(Color(0.48, 0.24, 0.115), 0.42, 0.57, true)
    fastener_material = _surface(Color(0.31, 0.35, 0.39), 0.66, 0.42)

    _box("MatteIndustrialFloor", Vector3(0, -0.20, 4.90), Vector3(22, 0.29, 14), stage_mat)
    _box("RearStudioCyclorama", Vector3(0, 2.4, -3.1), Vector3(22, 5.0, 0.22), wall_mat)
    _box("StructuralPillarLeft", Vector3(-10.25, 2.0, -2.9), Vector3(0.36, 4.0, 0.44), frame_mat)
    _box("StructuralPillarRight", Vector3(10.25, 2.0, -2.9), Vector3(0.36, 4.0, 0.44), frame_mat)
    _box("UpperStudioTruss", Vector3(0, 4.28, -2.9), Vector3(20.7, 0.18, 0.38), frame_mat)
    _box("LowVisibilitySafetyBandFront", Vector3(0, -0.029, 11.60), Vector3(21.0, 0.013, 0.045), copper_material)
    _box("LowVisibilitySafetyBandRear", Vector3(0, -0.029, -1.75), Vector3(21.0, 0.013, 0.045), copper_material)

    var x_positions: Array[Vector3] = []
    for x in range(-10, 11, 2):
        x_positions.append(Vector3(float(x), -0.044, 4.9))
    _batch("MatteFloorGridX", Vector3(0.018, 0.008, 13), x_positions, stripe_material)

    var z_positions: Array[Vector3] = []
    for z in range(-1, 13, 2):
        z_positions.append(Vector3(0, -0.044, float(z)))
    _batch("MatteFloorGridZ", Vector3(20.5, 0.008, 0.018), z_positions, stripe_material)

    # W15: quiet industrial set dressing in THREE extra instanced batches.
    # Details sit BEHIND the rig or almost flush with the deck; no collisions,
    # no new shadow casters and no opaque element in an inspection sightline.
    var rear_fasteners: Array[Vector3] = []
    for row in [1.0, 3.4]:
        for x in range(-9, 10, 2):
            rear_fasteners.append(Vector3(float(x), float(row), -2.96))
    _batch("W15RearWallFasteners", Vector3(0.12, 0.12, 0.035), rear_fasteners, fastener_material, true)

    var deck_fasteners: Array[Vector3] = []
    for z in [9.0, 10.5]:
        for x in range(-8, 9, 2):
            deck_fasteners.append(Vector3(float(x), -0.038, float(z)))
    _batch("W15DeckFasteners", Vector3(0.075, 0.012, 0.075), deck_fasteners, fastener_material, true)

    var boundary_marks: Array[Vector3] = []
    for x in range(-8, 9, 2):
        boundary_marks.append(Vector3(float(x), -0.035, 11.35))
    _batch("W15DeckBoundaryMarks", Vector3(0.32, 0.009, 0.032), boundary_marks, copper_material, true)
    set_quality(0)

func _surface(color: Color, metal: float, rough: float, illuminated: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = rough
    if illuminated:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 0.15
    return mat

func _box(label: String, center: Vector3, extents: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    instance.name = label
    var mesh := BoxMesh.new()
    mesh.size = extents
    instance.mesh = mesh
    instance.material_override = material
    instance.position = center
    add_child(instance)
    single_mesh_nodes += 1

func _batch(label: String, extents: Vector3, coordinates: Array[Vector3], material: Material, detail: bool = false) -> void:
    var box := BoxMesh.new()
    box.size = extents
    var group := MultiMesh.new()
    group.transform_format = MultiMesh.TRANSFORM_3D
    group.mesh = box
    group.instance_count = coordinates.size()
    for i in range(coordinates.size()):
        group.set_instance_transform(i, Transform3D(Basis(), coordinates[i]))
    var instance := MultiMeshInstance3D.new()
    instance.name = label
    instance.multimesh = group
    instance.material_override = material
    add_child(instance)
    if detail:
        detail_instances += coordinates.size()
        detail_draw_batches += 1
    else:
        grid_instances += coordinates.size()
        grid_draw_batches += 1

func set_quality(new_quality: int) -> void:
    quality = clampi(new_quality, 0, 2)
    if stripe_material != null:
        stripe_material.albedo_color = Color(0.17, 0.24, 0.27) if quality == 0 else Color(0.23, 0.30, 0.33)
    if copper_material != null:
        copper_material.emission_energy_multiplier = 0.12 if quality == 0 else 0.35
    if fastener_material != null:
        fastener_material.roughness = 0.68 if quality == 0 else 0.42
        fastener_material.metallic = 0.38 if quality == 0 else 0.66

func render_budget() -> Dictionary:
    return {
        "grid_instances": grid_instances,
        "grid_draw_batches": grid_draw_batches,
        "detail_draw_batches": detail_draw_batches,
        "detail_instances": detail_instances,
        "fastener_roughness": fastener_material.roughness if fastener_material != null else -1.0,
        "single_mesh_nodes": single_mesh_nodes,
        "stage_quality": quality,
        "accent_emission": copper_material.emission_energy_multiplier if copper_material != null else 0.0,
        "visual_only": true
    }
