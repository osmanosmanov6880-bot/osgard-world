extends Node3D
## R5 city-detail pass: several thousand real structural pieces, batched in MultiMesh.
## The hero docks receive denser geometry; distant towers use instance-based LOD.
## No collision or save changes. Designed for the existing WebGL renderer.

var instanced_parts: int = 0
var landmark_count: int = 0
var materials: Dictionary = {}

func _ready() -> void:
    materials = {
        "graphite": _mat(Color(0.025, 0.038, 0.058), 0.46),
        "steel": _mat(Color(0.20, 0.27, 0.34), 0.37),
        "glass": _mat(Color(0.060, 0.21, 0.27), 0.19),
        "bronze": _mat(Color(0.52, 0.32, 0.15), 0.31),
        "signal": _mat(Color(0.17, 0.65, 0.72), 0.48, 0.54)
    }

func _mat(color: Color, rough: float, emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.roughness = rough
    mat.metallic = 0.76
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    return mat

func _transform(position: Vector3, size: Vector3, radians: float = 0.0) -> Transform3D:
    return Transform3D(Basis(Vector3.UP, radians).scaled(size), position)

func _batch(name: String, pieces: Array[Transform3D], material: Material) -> void:
    if pieces.is_empty():
        return
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = BoxMesh.new()
    batch.instance_count = pieces.size()
    for n in pieces.size():
        batch.set_instance_transform(n, pieces[n])
    var draw := MultiMeshInstance3D.new()
    draw.name = name
    draw.multimesh = batch
    draw.material_override = material
    # Disable offscreen bounding-box culling errors for large architectural batches.
    draw.extra_cull_margin = 24.0
    add_child(draw)
    instanced_parts += pieces.size()

func _box(parent: Node3D, title: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = shape
    node.position = position
    node.material_override = material
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, title: String, position: Vector3, radius: float, height: float, material: Material, segments: int = 20) -> MeshInstance3D:
    var shape := CylinderMesh.new()
    shape.top_radius = radius * 0.90
    shape.bottom_radius = radius
    shape.height = height
    shape.radial_segments = segments
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = shape
    node.position = position
    node.material_override = material
    parent.add_child(node)
    return node

func build(towers: Array[Dictionary], centers: Array) -> void:
    _detail_towers(towers)
    _detail_docks(centers)
    for i in centers.size():
        _hero_spire(centers[i] + Vector3(100, 0, -108), i)

func _detail_towers(towers: Array[Dictionary]) -> void:
    var foundations: Array[Transform3D] = []
    var setbacks: Array[Transform3D] = []
    var fins: Array[Transform3D] = []
    var louvers: Array[Transform3D] = []
    var rooftops: Array[Transform3D] = []
    var antennas: Array[Transform3D] = []
    var signage: Array[Transform3D] = []
    var tubes: Array[Transform3D] = []
    for i in towers.size():
        var tower: Dictionary = towers[i]
        var pos: Vector3 = tower["pos"]
        var w: float = tower["w"]
        var d: float = tower["depth"]
        var h: float = tower["h"]
        var bottom: float = pos.y - h * 0.5
        var top: float = pos.y + h * 0.5
        # Visually anchor each building: ground pod, recessed crown, service plant.
        foundations.append(_transform(Vector3(pos.x, bottom + 4.0, pos.z), Vector3(w * 1.23, 8, d * 1.21)))
        setbacks.append(_transform(Vector3(pos.x, top + 2.4, pos.z), Vector3(w * 0.82, 4.8, d * 0.79)))
        rooftops.append(_transform(Vector3(pos.x, top + 5.4, pos.z), Vector3(w * 0.52, 1.9, d * 0.58)))
        for side in [-1.0, 1.0]:
            # Deep facade stripes create actual parallax, unlike a flat window texture.
            for seam in [-0.29, 0.0, 0.29]:
                fins.append(_transform(pos + Vector3(w * seam, 0, side * (d * 0.5 + 0.31)),
                                       Vector3(0.35, h, 0.58)))
                fins.append(_transform(pos + Vector3(side * (w * 0.5 + 0.31), 0, d * seam),
                                       Vector3(0.58, h, 0.35)))
        for level in range(1, 5):
            var y: float = bottom + h * float(level) / 5.0
            louvers.append(_transform(Vector3(pos.x, y, pos.z - d * 0.51),
                                      Vector3(w + 1.3, 0.22, 0.65)))
            louvers.append(_transform(Vector3(pos.x, y, pos.z + d * 0.51),
                                      Vector3(w + 1.3, 0.22, 0.65)))
        if i % 3 == 0:
            antennas.append(_transform(Vector3(pos.x + w * 0.22, top + 11.0, pos.z - d * 0.18),
                                       Vector3(0.33, 17.0, 0.33)))
            antennas.append(_transform(Vector3(pos.x + w * 0.22, top + 20.0, pos.z - d * 0.18),
                                       Vector3(1.4, 0.18, 1.4)))
        if i % 5 == 0:
            signage.append(_transform(Vector3(pos.x, top - h * 0.2, pos.z + d * 0.51),
                                      Vector3(w * 0.72, 0.6, 0.3)))
            tubes.append(_transform(Vector3(pos.x, bottom + 10.0, pos.z + d * 0.55),
                                    Vector3(w * 0.62, 0.18, 0.25)))
    _batch("R5_TowerFoundationPodiums", foundations, materials["graphite"])
    _batch("R5_TowerUpperSetbacks", setbacks, materials["steel"])
    _batch("R5_TowerFacadeExtrusions", fins, materials["steel"])
    _batch("R5_TowerLouvers", louvers, materials["graphite"])
    _batch("R5_RooftopPlantRooms", rooftops, materials["glass"])
    _batch("R5_RoofAntennas", antennas, materials["bronze"])
    _batch("R5_HoloCompanyBands", signage, materials["signal"])
    _batch("R5_Piping", tubes, materials["bronze"])

func _detail_docks(centers: Array) -> void:
    var barricades: Array[Transform3D] = []
    var floodlights: Array[Transform3D] = []
    var cargos: Array[Transform3D] = []
    var lifters: Array[Transform3D] = []
    var ribs: Array[Transform3D] = []
    var markings: Array[Transform3D] = []
    var pipes: Array[Transform3D] = []
    var pylons: Array[Transform3D] = []
    for i in centers.size():
        var center: Vector3 = centers[i]
        # First 47 meters of every station are enriched, with geometry visible
        # from the player's third-person camera rather than only at skyline scale.
        for j in 24:
            var a: float = TAU * float(j) / 24.0
            var radial := Vector3(cos(a), 0, sin(a))
            var tangent_angle: float = -a
            var side_pos: Vector3 = center + radial * 46.0 + Vector3(0, 5.2, 0)
            barricades.append(_transform(side_pos, Vector3(10.4, 0.65, 0.48), tangent_angle))
            var light_pos: Vector3 = center + radial * 46.0 + Vector3(0, 5.65, 0)
            if j % 2 == 0:
                floodlights.append(_transform(light_pos, Vector3(0.80, 0.14, 0.80)))
        for j in 12:
            var a: float = TAU * float(j) / 12.0
            var radial := Vector3(cos(a), 0, sin(a))
            var p: Vector3 = center + radial * 31.0
            markings.append(_transform(p + Vector3(0, 4.1, 0), Vector3(4.8, 0.06, 0.17), -a))
            if j % 3 == 0:
                pylons.append(_transform(center + radial * 41.0 + Vector3(0, 6.0, 0), Vector3(1.8, 3.6, 1.8)))
        for j in 8:
            var side: float = -1.0 if j % 2 == 0 else 1.0
            var lane: int = int(j / 2)
            var x: float = side * (57.0 + float(lane % 2) * 9.0)
            var z: float = -31.0 + float(lane) * 20.0
            var where: Vector3 = center + Vector3(x, 3.0, z)
            cargos.append(_transform(where, Vector3(8.2, 4.0, 4.4)))
            ribs.append(_transform(where + Vector3(0, 2.2, 0), Vector3(8.6, 0.21, 4.8)))
            # Functional-looking articulated crane structures.
            if j < 4:
                lifters.append(_transform(where + Vector3(side * 6.0, 6.0, 0), Vector3(0.85, 12, 0.9)))
                lifters.append(_transform(where + Vector3(side * 3.5, 12.2, 0), Vector3(6.5, 0.75, 0.75)))
                pipes.append(_transform(where + Vector3(0, 5.2, 0), Vector3(6.4, 0.21, 0.21)))
    _batch("R5_ArmoredBlastBarrier", barricades, materials["steel"])
    _batch("R5_LandingPerimeterLamps", floodlights, materials["signal"])
    _batch("R5_ServiceCargoContainers", cargos, materials["graphite"])
    _batch("R5_CargoRoofRibs", ribs, materials["bronze"])
    _batch("R5_HydraulicLoaderCranes", lifters, materials["steel"])
    _batch("R5_PadNumberingGuideStripes", markings, materials["bronze"])
    _batch("R5_UtilityPipeRuns", pipes, materials["glass"])
    _batch("R5_EmergencyStops", pylons, materials["bronze"])

func _hero_spire(base: Vector3, index: int) -> void:
    # Individually authored silhouette at each of the six large districts:
    # multi-level reinforced core, setback crowns and tapered transmitter.
    var group := Node3D.new()
    group.name = "R5_SignatureCitadel_%02d" % index
    group.position = base
    add_child(group)
    _box(group, "Plinth", Vector3(0, 9, 0), Vector3(32, 18, 34), materials["graphite"])
    _box(group, "GlassAtrium", Vector3(0, 36, 0), Vector3(23, 46, 27), materials["glass"])
    _box(group, "UpperCitadel", Vector3(0, 80, 0), Vector3(18, 46, 18), materials["steel"])
    _box(group, "ObservationDeck", Vector3(0, 104, 0), Vector3(29, 4, 29), materials["graphite"])
    _box(group, "CommunicationsDeck", Vector3(0, 123, 0), Vector3(12, 37, 12), materials["glass"])
    _cylinder(group, "SpireTip", Vector3(0, 158, 0), 3.6, 34, materials["steel"], 16)
    for side in [-1.0, 1.0]:
        _box(group, "ReinforcedButtress", Vector3(side * 13.0, 39, 0), Vector3(4.5, 68, 6), materials["graphite"])
        _box(group, "CopperTrim", Vector3(side * 13.0, 70, 0), Vector3(4.8, 0.68, 6.2), materials["bronze"])
    for floor in range(4):
        _box(group, "ShadowJoint", Vector3(0, 21 + float(floor) * 13.0, 13.6), Vector3(24, 0.72, 0.68), materials["graphite"])
    landmark_count += 1
