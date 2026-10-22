extends Node3D
## NEBULA R10: AEGIS sculpted megadock. Imported 33k triangle hero asset,
## physically grounded collision bodies, near/far LOD and animated loading arms.
## Mission save schema / player physics remain unchanged.

const HeroPortR10Scene = preload("res://assets/models/aegis_megadock_r10.gltf")
const SurfaceLibraryR9Script = preload("res://scripts/surface_library_r9.gd")
const QUALITY_RANGES := [900.0, 610.0, 340.0]

var megadock_count: int = 0
var modeled_triangles: int = 0
var loading_arms: int = 0
var instanced_details: int = 0
var quality_mode: int = 0
var capital_bridges: Array[Node3D] = []
var imports: Array[Node3D] = []
var proxies: Array[MeshInstance3D] = []
var clock: float = 0.0
var steel: StandardMaterial3D
var carbon: StandardMaterial3D
var warm: StandardMaterial3D

func _ready() -> void:
    steel = SurfaceLibraryR9Script.coat(_mat(Color(0.72, 0.76, 0.81), 0.82, 0.34), 1)
    carbon = SurfaceLibraryR9Script.coat(_mat(Color(0.20, 0.24, 0.28), 0.58, 0.58), 0)
    warm = _mat(Color(0.63, 0.39, 0.17), 0.78, 0.42)
    warm.emission_enabled = true
    warm.emission = Color(0.50, 0.25, 0.08)
    warm.emission_energy_multiplier = 0.32

func _mat(color: Color, metal: float, rough: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metal
    material.roughness = rough
    return material

func _box(parent: Node3D, title: String, position: Vector3, size: Vector3,
        material: Material) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var part := MeshInstance3D.new()
    part.name = title
    part.mesh = shape
    part.material_override = material
    part.position = position
    parent.add_child(part)
    return part

func _solid_box(parent: Node3D, name: String, position: Vector3, size: Vector3) -> void:
    var body := StaticBody3D.new()
    body.name = name
    body.position = position
    parent.add_child(body)
    var shape := BoxShape3D.new()
    shape.size = size
    var collider := CollisionShape3D.new()
    collider.shape = shape
    body.add_child(collider)

func _beam(parent: Node3D, name: String, a: Vector3, b: Vector3,
        radius: float, material: Material) -> MeshInstance3D:
    var delta: Vector3 = b - a
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = delta.length()
    shape.radial_segments = 16
    var tube := MeshInstance3D.new()
    tube.name = name
    tube.mesh = shape
    tube.position = (a + b) * 0.5
    tube.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))
    tube.material_override = material
    parent.add_child(tube)
    return tube

func _batched(name: String, parts: Array[Transform3D], material: Material) -> void:
    if parts.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = BoxMesh.new()
    mm.instance_count = parts.size()
    for index in parts.size():
        mm.set_instance_transform(index, parts[index])
    var instance := MultiMeshInstance3D.new()
    instance.name = name
    instance.multimesh = mm
    instance.material_override = material
    instance.extra_cull_margin = 22.0
    add_child(instance)
    instanced_details += parts.size()

func _make_gate(centre: Vector3, district: int) -> void:
    var port := Node3D.new()
    port.name = "R10_AegisPort_%02d" % district
    port.position = centre + Vector3(0, 0, -185)
    add_child(port)
    var imported: Node3D = HeroPortR10Scene.instantiate()
    imported.name = "R10_ImportedHeroMegadock"
    port.add_child(imported)
    imports.append(imported)
    var count_here: int = 0
    for draw in imported.find_children("*", "MeshInstance3D", true, false):
        if draw.mesh == null:
            continue
        for surface in draw.mesh.get_surface_count():
            count_here += int(draw.mesh.surface_get_array_index_len(surface) / 3)
            var original := draw.mesh.surface_get_material(surface) as StandardMaterial3D
            if original == null or original.emission_enabled:
                continue
            var name: String = original.resource_name.to_lower()
            if "glass" in name or "optical" in name:
                continue
            var profile: int = SurfaceLibraryR9Script.get_profile(original)
            draw.set_surface_override_material(surface, SurfaceLibraryR9Script.coat(original, profile))
        draw.visibility_range_end = QUALITY_RANGES[quality_mode]
        draw.visibility_range_end_margin = 125.0
    modeled_triangles += count_here
    # High flight corridor stays open below the structural skybridge.
    for side in [-1.0, 1.0]:
        _solid_box(port, "R10_TowerFlightCollision_%d" % int(side),
                   Vector3(side * 73.0, 63, 0), Vector3(34, 126, 34))
    _solid_box(port, "R10_OverheadBridgeCollision",
               Vector3(0, 90, 0), Vector3(138, 11, 26))
    var reduced := _mat(Color(0.19, 0.24, 0.28), 0.84, 0.43)
    for side in [-1.0, 1.0]:
        var low := _box(port, "R10_FarTowerProxy",
                       Vector3(side * 73, 61, 0), Vector3(31, 122, 30), reduced)
        proxies.append(low)
        _make_loader(port, side, district)
    var skyspan := _box(port, "R10_FarSkybridgeProxy",
                       Vector3(0, 92, 0), Vector3(142, 12, 26), reduced)
    proxies.append(skyspan)
    var service := Label3D.new()
    service.name = "R10_EngravedPortSign"
    service.text = "OSGARD   /   AEGIS PORT  %02d" % (district + 1)
    service.font_size = 84
    service.pixel_size = 0.008
    service.modulate = Color(0.89, 0.76, 0.54)
    service.position = Vector3(0, 79.5, 13.9)
    port.add_child(service)
    if district == 0:
        var lamp := OmniLight3D.new()
        lamp.name = "R10_WarmMaintenanceFill"
        lamp.position = Vector3(0, 81, 16)
        lamp.light_color = Color(1.0, 0.71, 0.40)
        lamp.light_energy = 0.41
        lamp.omni_range = 32
        lamp.shadow_enabled = false
        port.add_child(lamp)
    megadock_count += 1

func _make_loader(port: Node3D, side: float, district: int) -> void:
    var pivot := Node3D.new()
    pivot.name = "R10_MovingCargoArm_%d" % int(side)
    pivot.position = Vector3(side * 57, 35, 21)
    port.add_child(pivot)
    _box(pivot, "MainHydraulicPivot", Vector3.ZERO, Vector3(4.8, 4.8, 4.8), carbon)
    _beam(pivot, "PrimaryAlloyBoom", Vector3(0, 0, 0),
          Vector3(-side * 12, -11, 8), 0.76, steel)
    _beam(pivot, "ExposedChromeHydraulic",
          Vector3(-side * 2, -2, 1), Vector3(-side * 11, -9.8, 7.4), 0.35, warm)
    _box(pivot, "CargoPressureClamp", Vector3(-side * 12, -11.5, 8),
         Vector3(3.6, 3.0, 6.8), carbon)
    for slide in [-1.0, 1.0]:
        _box(pivot, "PairedClampJaw", Vector3(-side * 12, -13.5, 8 + slide * 2.7),
             Vector3(2.7, 3.2, 0.65), steel)
    capital_bridges.append(pivot)
    loading_arms += 1

func build(centres: Array) -> void:
    var hazard: Array[Transform3D] = []
    var service: Array[Transform3D] = []
    var worklamp: Array[Transform3D] = []
    for i in centres.size():
        var centre: Vector3 = centres[i]
        _make_gate(centre, i)
        var base: Vector3 = centre + Vector3(0, 0, -185)
        for side in [-1.0, 1.0]:
            for j in 26:
                var z: float = 31.0 + float(j) * 2.7
                hazard.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.9, 0.065, 1.5)),
                              base + Vector3(side * 48, 0.17, z)))
                for level in 4:
                    var x: float = side * (60.0 + float(level) * 4.0)
                    service.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.30, 0.30, 2.6)),
                               base + Vector3(x, 9.0 + float(level) * 14.0, 24.0 + float(j) * 2.7)))
                if j % 3 == 0:
                    worklamp.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.8, 0.13, 0.37)),
                               base + Vector3(side * 50.0, 2.1, z)))
    _batched("R10_BatchedTaxiwayMarkings", hazard, warm)
    _batched("R10_BatchedTowerDuctwork", service, carbon)
    _batched("R10_BatchedPracticalLuminaires", worklamp, warm)
    set_quality(0)

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    var limit: float = QUALITY_RANGES[quality_mode]
    for imported in imports:
        if is_instance_valid(imported):
            for draw in imported.find_children("*", "MeshInstance3D", true, false):
                draw.visibility_range_end = limit
                draw.visibility_range_end_margin = 120.0
    for proxy in proxies:
        if is_instance_valid(proxy):
            proxy.visibility_range_begin = limit - 95.0
            proxy.visibility_range_begin_margin = 115.0

func _process(delta: float) -> void:
    clock += delta
    for j in capital_bridges.size():
        var arm: Node3D = capital_bridges[j]
        if is_instance_valid(arm):
            arm.rotation.y = 0.12 * sin(clock * 0.23 + float(j) * 0.81)
            arm.rotation.x = 0.07 * sin(clock * 0.17 + float(j) * 0.55)
