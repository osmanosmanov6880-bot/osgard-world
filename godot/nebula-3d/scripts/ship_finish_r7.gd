extends Node3D
## R7 player hero finishing pass: physical radiator ribs, serial markings,
## self-shadowing cannon shrouds, machined hatches and riveted alloy.
## GPU instancing prevents thousands of independent mesh draw calls.

var finish_instances: int = 0
var optical_sensors: int = 0
var decal_count: int = 0
var panel_material: StandardMaterial3D
var carbon: StandardMaterial3D
var bronze: StandardMaterial3D
var optic: StandardMaterial3D
var porcelain: StandardMaterial3D

func _ready() -> void:
    panel_material = _create_painted_alloy()
    carbon = _metal(Color(0.027, 0.034, 0.051), 0.54)
    bronze = _metal(Color(0.61, 0.41, 0.21), 0.28)
    optic = _metal(Color(0.13, 0.48, 0.59), 0.13)
    porcelain = _metal(Color(0.64, 0.69, 0.67), 0.32)
    _build_panels()
    _engine_heat_shielding()
    _canopy_details()
    _ship_insignia()

func _metal(color: Color, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.82
    mat.roughness = roughness
    return mat

func _create_painted_alloy() -> StandardMaterial3D:
    var image := Image.create(256, 256, false, Image.FORMAT_RGB8)
    var normals := Image.create(256, 256, false, Image.FORMAT_RGB8)
    for y in 256:
        for x in 256:
            var split: bool = x % 64 <= 1 or y % 32 == 0
            var grain: float = sin(float(x) * 0.91 + sin(float(y) * 0.13)) * 0.04
            var variation: float = 0.86 + float((int(x / 64) + int(y / 32)) % 4) * 0.024
            var color := Color(0.53, 0.58, 0.60) * (variation + grain)
            if split:
                color = Color(0.11, 0.14, 0.16)
            elif (x + y * 3) % 83 < 2:
                color = color.darkened(0.12)
            image.set_pixel(x, y, color)
            normals.set_pixel(x, y, Color(0.5 + 0.023 * sin(float(x) * 0.91),
                0.5 + 0.020 * sin(float(y) * 0.78), 1.0))
    image.generate_mipmaps()
    normals.generate_mipmaps()
    var mat := _metal(Color(0.74, 0.82, 0.88), 0.40)
    mat.albedo_texture = ImageTexture.create_from_image(image)
    mat.normal_enabled = true
    mat.normal_texture = ImageTexture.create_from_image(normals)
    mat.normal_scale = 0.28
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return mat

func _box(label: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var obj := MeshInstance3D.new()
    obj.name = label
    obj.mesh = mesh
    obj.position = pos
    obj.material_override = material
    add_child(obj)
    return obj

func _rod(label: String, a: Vector3, b: Vector3, radius: float, material: Material) -> MeshInstance3D:
    var displacement: Vector3 = b - a
    var mesh := CylinderMesh.new()
    mesh.height = displacement.length()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.radial_segments = 12
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = mesh
    part.position = (a + b) * 0.5
    part.basis = Basis(Quaternion(Vector3.UP, displacement.normalized()))
    part.material_override = material
    add_child(part)
    return part

func _batch(label: String, positions: Array[Transform3D], material: Material) -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = BoxMesh.new()
    mm.instance_count = positions.size()
    for i in positions.size():
        mm.set_instance_transform(i, positions[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = mm
    node.material_override = material
    add_child(node)
    finish_instances += positions.size()

func _build_panels() -> void:
    var steel_tiles: Array[Transform3D] = []
    var inset_louvers: Array[Transform3D] = []
    var fastening_blocks: Array[Transform3D] = []
    var polished_inlays: Array[Transform3D] = []
    for side in [-1.0, 1.0]:
        for span in range(7):
            var x: float = 2.12 + float(span) * 0.49
            for depth in range(7):
                var z: float = 0.12 + float(depth) * 0.255
                # Do not occlude the existing R6 external wing detailing.
                var tile := Transform3D(Basis.IDENTITY.scaled(Vector3(0.39, 0.033, 0.18)),
                    Vector3(side * x, 0.20, z))
                steel_tiles.append(tile)
                if depth == 0 or depth == 6:
                    fastening_blocks.append(Transform3D(
                        Basis.IDENTITY.scaled(Vector3(0.065, 0.03, 0.065)),
                        Vector3(side * x, 0.247, z)))
        for depth in range(14):
            var z: float = 0.75 + float(depth) * 0.22
            inset_louvers.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.13, 0.18, 0.08)),
                Vector3(side * 0.91, 0.62, z)))
        for depth in range(5):
            polished_inlays.append(Transform3D(
                Basis.IDENTITY.scaled(Vector3(0.54, 0.044, 0.055)),
                Vector3(side * 3.2, 0.26, 0.20 + float(depth) * 0.47)))
    _batch("R7_MultiLayerCeramicWingTiles", steel_tiles, panel_material)
    _batch("R7_PrecisionRivetBlocks", fastening_blocks, porcelain)
    _batch("R7_ReactorVentilationLouvers", inset_louvers, carbon)
    _batch("R7_WingMachinedLines", polished_inlays, bronze)

func _engine_heat_shielding() -> void:
    var blades: Array[Transform3D] = []
    var bolts: Array[Transform3D] = []
    for engine_x in [-1.24, 0.0, 1.24]:
        var radius: float = 0.58 if absf(engine_x) > 0.1 else 0.46
        for ring in range(4):
            for segment in range(12):
                var angle: float = TAU * float(segment) / 12.0
                var x: float = engine_x + cos(angle) * radius * 1.03
                var y: float = -0.22 + sin(angle) * radius * 1.03
                var z: float = 2.43 + float(ring) * 0.47
                var scale := Vector3(0.12, 0.09, 0.30)
                blades.append(Transform3D(Basis(Vector3.FORWARD, angle).scaled(scale),
                    Vector3(x, y, z)))
        for side in [-1.0, 1.0]:
            for n in range(6):
                bolts.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.07, 0.06, 0.07)),
                    Vector3(engine_x + side * radius * 1.09, -0.22, 2.43 + float(n) * 0.37)))
    _batch("R7_ThrusterCoolingBlades", blades, carbon)
    _batch("R7_EngineHousingBolts", bolts, porcelain)

func _canopy_details() -> void:
    for side in [-1.0, 1.0]:
        _rod("LongitudinalCanopyWaterSeal",
             Vector3(side * 0.70, 0.49, -2.63), Vector3(side * 0.79, 0.44, -0.78),
             0.042, carbon)
        for k in range(5):
            var z: float = -2.51 + float(k) * 0.35
            _rod("CockpitStructuralCrossmember",
                 Vector3(side * 0.56, 1.04, z), Vector3(side * 0.78, 0.52, z),
                 0.026, bronze)
        _box("ForwardElectroOpticHousing", Vector3(0.28, 0.22, 0.51),
            Vector3(side * 0.96, 0.31, -3.31), carbon)
        var lens := SphereMesh.new()
        lens.radius = 0.11
        lens.height = 0.22
        lens.radial_segments = 20
        lens.rings = 10
        var eye := MeshInstance3D.new()
        eye.name = "R7_HighResolutionNavigationOptic"
        eye.mesh = lens
        eye.position = Vector3(side * 0.96, 0.33, -3.62)
        eye.material_override = optic
        add_child(eye)
        optical_sensors += 1
    for k in 6:
        _box("VentralEquipmentAccessHatch",
            Vector3(0.38, 0.042, 0.38), Vector3(0, -0.78, -2.0 + float(k) * 0.59),
            panel_material)

func _ship_insignia() -> void:
    for side in [-1.0, 1.0]:
        var label := Label3D.new()
        label.name = "R7_WingSerial"
        label.text = "OSGARD  /  NX-07"
        label.font_size = 72
        label.pixel_size = 0.0032
        label.modulate = Color(0.75, 0.77, 0.66)
        label.rotation.x = -PI * 0.5
        label.rotation.y = PI if side < 0.0 else 0.0
        label.position = Vector3(side * 3.9, 0.29, 1.45)
        add_child(label)
        decal_count += 1
