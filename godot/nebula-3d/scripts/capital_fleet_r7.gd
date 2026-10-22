extends Node3D
const SurfaceLibraryR9Script = preload("res://scripts/surface_library_r9.gd")
## NEBULA R7: monumental capital fleet. Authored hull lofts, armor sections,
## turret systems, mechanical fins, cooling vents and real mesh instancing.
## One shared PBR-like texture set for all six ships; GL Compatibility safe.

var carrier_count: int = 0
var turret_count: int = 0
var armor_instances: int = 0
var engine_count: int = 0
var hull_mesh: ArrayMesh
var hull_material: StandardMaterial3D
var dark: StandardMaterial3D
var alloy: StandardMaterial3D
var copper: StandardMaterial3D
var glass: StandardMaterial3D
var plasma: StandardMaterial3D

func _ready() -> void:
    hull_material = _create_hull_pbr()
    # Retain the existing 512px ship colors, upgrade specularity and
    # occlusion with the shared packed material maps.
    var hull_orm: Dictionary = SurfaceLibraryR9Script.maps(2)
    hull_material.ao_enabled = true
    hull_material.ao_texture = hull_orm["orm"]
    hull_material.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    hull_material.roughness = 1.0
    hull_material.roughness_texture = hull_orm["orm"]
    hull_material.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
    hull_material.metallic = 1.0
    hull_material.metallic_texture = hull_orm["orm"]
    hull_material.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
    dark = _mat(Color(0.024, 0.035, 0.045), 0.48)
    alloy = _mat(Color(0.38, 0.43, 0.46), 0.31)
    copper = _mat(Color(0.58, 0.36, 0.17), 0.39)
    glass = _mat(Color(0.048, 0.18, 0.25), 0.15)
    plasma = _mat(Color(0.13, 0.55, 0.71), 0.42, 0.73)
    hull_mesh = _loft_hull()

func _mat(tint: Color, rough: float, emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.81
    mat.roughness = rough
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = emission
    return mat

func _create_hull_pbr() -> StandardMaterial3D:
    # 512px tri-layer painted alloy texture: plating, wear, and tangent normal.
    # Built ONCE for the whole fleet; no network dependencies or placeholder art.
    var albedo := Image.create(512, 512, false, Image.FORMAT_RGB8)
    var normal := Image.create(512, 512, false, Image.FORMAT_RGB8)
    for y in 512:
        for x in 512:
            var seam: bool = x % 64 < 2 or y % 64 < 2
            var vent: bool = x % 64 >= 53 and y % 64 >= 8 and y % 64 <= 53 and x % 4 == 0
            var scratch: float = sin(float(x) * 0.79 + sin(float(y) * 0.063)) * 0.034
            var panel: float = 0.77 + float((int(x / 64) * 19 + int(y / 64) * 31) % 9) * 0.025
            var shade := Color(0.42, 0.49, 0.52) * (panel + scratch)
            if seam:
                shade = Color(0.029, 0.039, 0.048)
            elif vent:
                shade = Color(0.11, 0.15, 0.17)
            elif y % 64 == 5:
                shade = Color(0.37, 0.28, 0.13)
            albedo.set_pixel(x, y, shade)
            var perturb: float = (0.06 if seam else 0.018)
            normal.set_pixel(x, y, Color(0.5 + perturb * sin(float(x) * 0.83),
                    0.5 + perturb * sin(float(y) * 0.34), 1.0))
    albedo.generate_mipmaps()
    normal.generate_mipmaps()
    var mat := _mat(Color(0.77, 0.84, 0.91), 0.39)
    mat.albedo_texture = ImageTexture.create_from_image(albedo)
    mat.normal_enabled = true
    mat.normal_texture = ImageTexture.create_from_image(normal)
    mat.normal_scale = 0.26
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return mat

func _cross(s: Vector4, angle: float) -> Vector3:
    # s = (z, horizontal halfwidth, vertical halfheight, vertical offset).
    return Vector3(cos(angle) * s.y, s.w + sin(angle) * s.z, s.x)

func _tri(st: SurfaceTool, a: Vector3, uv_a: Vector2, b: Vector3, uv_b: Vector2, c: Vector3, uv_c: Vector2) -> void:
    st.set_uv(uv_a)
    st.add_vertex(a)
    st.set_uv(uv_b)
    st.add_vertex(b)
    st.set_uv(uv_c)
    st.add_vertex(c)

func _loft_hull() -> ArrayMesh:
    # Massive 118-meter carrier with a real continuous 32-sided multi-chine mesh.
    var slices: Array[Vector4] = [
        Vector4(-64.0, 0.6, 0.5, 1.5),
        Vector4(-55.0, 5.0, 2.5, 1.0),
        Vector4(-41.0, 13.2, 5.2, 0.5),
        Vector4(-23.0, 19.0, 6.8, 0.0),
        Vector4(-3.0, 20.5, 8.6, 0.0),
        Vector4(19.0, 23.0, 9.0, -0.5),
        Vector4(38.0, 20.4, 8.1, -0.5),
        Vector4(51.0, 15.0, 5.8, 0.0),
        Vector4(57.0, 9.5, 4.8, 0.0)
    ]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sides: int = 32
    for k in range(slices.size() - 1):
        for j in sides:
            var a0: float = TAU * float(j) / float(sides)
            var a1: float = TAU * float(j + 1) / float(sides)
            var p00: Vector3 = _cross(slices[k], a0)
            var p01: Vector3 = _cross(slices[k], a1)
            var p10: Vector3 = _cross(slices[k + 1], a0)
            var p11: Vector3 = _cross(slices[k + 1], a1)
            var u0: float = float(j) / float(sides) * 6.0
            var u1: float = float(j + 1) / float(sides) * 6.0
            var v0: float = float(k) / float(slices.size() - 1) * 9.0
            var v1: float = float(k + 1) / float(slices.size() - 1) * 9.0
            _tri(st, p00, Vector2(u0, v0), p01, Vector2(u1, v0), p11, Vector2(u1, v1))
            _tri(st, p00, Vector2(u0, v0), p11, Vector2(u1, v1), p10, Vector2(u0, v1))
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

func _box(parent: Node3D, label: String, size: Vector3, position: Vector3, mat: Material) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var mesh := MeshInstance3D.new()
    mesh.name = label
    mesh.mesh = shape
    mesh.position = position
    mesh.material_override = mat
    parent.add_child(mesh)
    return mesh

func _cylinder(parent: Node3D, label: String, radius: float, height: float, pos: Vector3, mat: Material, segments: int = 20) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = segments
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = shape
    node.position = pos
    node.material_override = mat
    parent.add_child(node)
    return node

func _torus(parent: Node3D, label: String, radius: float, thickness: float, pos: Vector3, mat: Material) -> MeshInstance3D:
    var shape := TorusMesh.new()
    shape.inner_radius = radius - thickness
    shape.outer_radius = radius
    shape.rings = 40
    shape.ring_segments = 8
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = shape
    node.rotation.x = PI * 0.5
    node.position = pos
    node.material_override = mat
    parent.add_child(node)
    return node

func _beam(parent: Node3D, label: String, start: Vector3, finish: Vector3, width: float, mat: Material) -> void:
    var delta: Vector3 = finish - start
    var node := _cylinder(parent, label, width, delta.length(), (start + finish) * 0.5, mat, 12)
    node.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))

func _batch(parent: Node3D, label: String, parts: Array[Transform3D], mat: Material) -> void:
    if parts.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = BoxMesh.new()
    mm.instance_count = parts.size()
    for i in parts.size():
        mm.set_instance_transform(i, parts[i])
    var draw := MultiMeshInstance3D.new()
    draw.name = label
    draw.multimesh = mm
    draw.material_override = mat
    parent.add_child(draw)
    armor_instances += parts.size()

func _armor(boat: Node3D) -> void:
    # Recessed repeating armor / vented shoulder grid, one draw per material.
    var side_louvers: Array[Transform3D] = []
    var deck_plates: Array[Transform3D] = []
    var rivet_bands: Array[Transform3D] = []
    var warm_stripes: Array[Transform3D] = []
    for side in [-1.0, 1.0]:
        for j in 28:
            var z: float = -35.0 + float(j) * 2.9
            var half_width: float = 18.2 if z < 29.0 else 13.0
            side_louvers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.8, 0.26, 1.6)),
                 Vector3(side * half_width, 3.2, z)))
            if j % 2 == 0:
                warm_stripes.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.18, 0.18, 1.2)),
                     Vector3(side * (half_width + 0.52), 3.33, z)))
        for j in 24:
            var z: float = -39.0 + float(j) * 3.4
            var width: float = 14.2 if z < 25.0 else 9.5
            deck_plates.append(Transform3D(Basis.IDENTITY.scaled(Vector3(width, 0.2, 1.36)),
                 Vector3(side * (width * 0.52), 8.15, z)))
        for x in range(1, 12):
            for j in range(18):
                var z: float = -32.0 + float(j) * 3.6
                rivet_bands.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.17, 0.16, 0.17)),
                     Vector3(side * float(x) * 1.4, 8.35, z)))
    _batch(boat, "R7_ArmoredSideLouvers", side_louvers, dark)
    _batch(boat, "R7_MachinedUpperArmor", deck_plates, hull_material)
    _batch(boat, "R7_BatchedDeckFasteners", rivet_bands, alloy)
    _batch(boat, "R7_EdgeWarmIndicators", warm_stripes, copper)

func _turrets(boat: Node3D) -> void:
    for side in [-1.0, 1.0]:
        for slot in range(3):
            var x: float = side * (8.5 + float(slot % 2) * 7.0)
            var z: float = -23.0 + float(slot) * 28.0
            var mount := Node3D.new()
            mount.name = "R7_RailgunBattery"
            mount.position = Vector3(x, 8.6, z)
            boat.add_child(mount)
            _cylinder(mount, "ArmoredTurretBase", 2.1, 1.2, Vector3.ZERO, dark, 24)
            _cylinder(mount, "ElectromagneticCoilHousing", 1.55, 1.8, Vector3(0, 1.2, 0), alloy, 24)
            for tube in [-0.6, 0.6]:
                _beam(mount, "FullLengthMagneticBarrel",
                    Vector3(tube, 1.55, -8.6), Vector3(tube, 1.55, 1.4), 0.21, dark)
                _box(mount, "BarrelCeramicCoupler", Vector3(0.8, 0.54, 0.42),
                    Vector3(tube, 1.55, -3.1), copper)
                _torus(mount, "MuzzleRetentionRing", 0.31, 0.08,
                    Vector3(tube, 1.55, -8.15), alloy)
            turret_count += 1

func _engines(boat: Node3D) -> void:
    for x in [-13.0, -4.5, 4.5, 13.0]:
        var drive := _cylinder(boat, "R7_ExternalDriveHousing", 3.0, 13.0,
                              Vector3(x, -0.5, 52.0), dark, 28)
        drive.rotation.x = PI * 0.5
        var core := _cylinder(boat, "R7_InternalIonChamber", 1.65, 0.7,
                             Vector3(x, -0.5, 59.0), plasma, 28)
        core.rotation.x = PI * 0.5
        for z in [46.0, 50.0, 54.0, 58.0]:
            _torus(boat, "R7_RadiatorClamp", 3.25, 0.19,
                   Vector3(x, -0.5, z), alloy)
        for side in [-1.0, 1.0]:
            _box(boat, "R7_ReactorHeatShield",
                 Vector3(0.5, 5.0, 6.4),
                 Vector3(x + side * 3.4, -0.4, 51.3), hull_material)
        engine_count += 1

func _carriers_bridge(boat: Node3D) -> void:
    _box(boat, "ArmoredBridgeBase", Vector3(12.5, 5.8, 23.0), Vector3(0, 9.2, -5.0), dark)
    _box(boat, "CommandObservationGlazing", Vector3(10.9, 4.0, 9.8), Vector3(0, 12.4, -13.0), glass)
    _box(boat, "BridgeUpperCanopy", Vector3(15.2, 1.3, 15.0), Vector3(0, 14.6, -7.5), hull_material)
    for side in [-1.0, 1.0]:
        _box(boat, "BridgeObliqueCheek", Vector3(3.2, 2.6, 6.0),
             Vector3(side * 7.8, 10.8, -14.2), alloy)
        _beam(boat, "SensorMastSpar", Vector3(side * 5.0, 13.6, 3.0),
              Vector3(side * 6.2, 25.0, 4.0), 0.35, alloy)
        _box(boat, "RadarHead", Vector3(3.4, 1.2, 1.0),
             Vector3(side * 6.2, 24.5, 4.0), copper)
        for j in 10:
            _box(boat, "RadiatorChamber", Vector3(0.6, 0.25, 1.4),
                Vector3(side * 10.0, 8.6, 2.0 + float(j) * 3.2), dark)
    for j in 5:
        _box(boat, "CommandSpineRail", Vector3(0.6, 0.6, 3.8),
            Vector3(0, 16.0, -15.0 + float(j) * 5.1), copper)

func _build_carrier(root: Node3D) -> void:
    var hull := MeshInstance3D.new()
    hull.name = "Lofted118mCarrierHull"
    hull.mesh = hull_mesh
    hull.material_override = hull_material
    root.add_child(hull)
    _armor(root)
    _turrets(root)
    _engines(root)
    _carriers_bridge(root)
    # Physical hull; ships remain stationary dockyard landmarks, not moving physics hazards.
    var static_body := StaticBody3D.new()
    static_body.name = "CarrierHullCollision"
    static_body.position = Vector3(0, 0, 0)
    root.add_child(static_body)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(38.0, 17.0, 108.0)
    collider.shape = shape
    static_body.add_child(collider)

func build(centers: Array) -> void:
    for i in centers.size():
        var carrier := Node3D.new()
        carrier.name = "R7_CapitalCarrier_%02d" % i
        var side: float = -1.0 if i % 2 == 0 else 1.0
        carrier.position = centers[i] + Vector3(side * 116.0, 65.0 + float(i % 3) * 5.0, -158.0)
        carrier.rotation.y = side * 0.19
        add_child(carrier)
        _build_carrier(carrier)
        carrier_count += 1
