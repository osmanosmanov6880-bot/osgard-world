extends Node3D
## R4: PBR-inspired procedural set dressing, designed to stay within GL Compatibility limits.
## Non-invasive add-on: gameplay, save format and mission coordinates remain unchanged.

var elapsed: float = 0.0
var beacons: Array[Node3D] = []

func _metal(color: Color, rough: float = 0.32, emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.83
    mat.roughness = rough
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    return mat

func _box(parent: Node3D, name: String, position: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = mesh
    node.position = position
    node.material_override = material
    parent.add_child(node)
    return node

func _batch(name: String, positions: Array[Transform3D], material: Material, color: Color) -> void:
    if positions.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = BoxMesh.new()
    mm.instance_count = positions.size()
    for i in positions.size():
        mm.set_instance_transform(i, positions[i])
    var node := MultiMeshInstance3D.new()
    node.name = name
    node.multimesh = mm
    node.material_override = material
    add_child(node)

func build(towers: Array[Dictionary], centers: Array) -> void:
    var steel := _metal(Color(0.13, 0.19, 0.26), 0.41)
    var black := _metal(Color(0.025, 0.037, 0.060), 0.55)
    var warm := _metal(Color(0.73, 0.49, 0.23), 0.35, 0.65)
    var glass := _metal(Color(0.09, 0.24, 0.32), 0.13)
    var fins: Array[Transform3D] = []
    var panels: Array[Transform3D] = []
    var ledges: Array[Transform3D] = []
    for t in towers:
        var center: Vector3 = t["pos"]
        var w: float = t["w"]
        var h: float = t["h"]
        var d: float = t["depth"]
        for level in range(1, 5):
            var y: float = center.y - h * 0.5 + h * float(level) / 5.0
            ledges.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w + 1.35, 0.32, d + 1.35)), Vector3(center.x, y, center.z)))
        for side in [-1.0, 1.0]:
            fins.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.42, h, 0.9)), center + Vector3(side * w * 0.34, 0.0, -d * 0.505)))
            fins.append(Transform3D(Basis.IDENTITY.scaled(Vector3(0.42, h, 0.9)), center + Vector3(side * w * 0.34, 0.0, d * 0.505)))
            panels.append(Transform3D(Basis.IDENTITY.scaled(Vector3(w * 0.66, h * 0.22, 0.16)), center + Vector3(0, h * 0.24, side * (d * 0.5 + 0.18))))
    _batch("R4_ArchitecturalRibs", fins, steel, Color.WHITE)
    _batch("R4_ShadowGlass", panels, glass, Color.WHITE)
    _batch("R4_FloorSlabs", ledges, black, Color.WHITE)
    for index in centers.size():
        var origin: Vector3 = centers[index]
        var hub := Node3D.new()
        hub.name = "R4_StationDressing_%02d" % index
        hub.position = origin
        add_child(hub)
        for j in 8:
            var a: float = TAU * float(j) / 8.0
            var direction := Vector3(cos(a), 0, sin(a))
            var deck := _box(hub, "RadialPlatform", direction * 32.0 + Vector3(0, 4.2, 0), Vector3(15.0, 0.38, 9.0), steel)
            deck.rotation.y = -a
            var stripe := _box(hub, "LandingGuidance", direction * 32.0 + Vector3(0, 4.47, 0), Vector3(10.0, 0.045, 0.22), warm)
            stripe.rotation.y = -a
        for side in [-1.0, 1.0]:
            var gantry := _box(hub, "ServiceGantry", Vector3(side * 55.0, 16.0, 0), Vector3(2.2, 24.0, 3.6), black)
            _box(gantry, "MaintenanceLamp", Vector3(0, 0.48, -0.55), Vector3(0.3, 0.15, 0.4), warm)
        var beacon := Node3D.new()
        beacon.position = Vector3(0, 9.0, 0)
        hub.add_child(beacon)
        var core := _box(beacon, "NavigationCore", Vector3.ZERO, Vector3(1.6, 4.5, 1.6), glass)
        _box(core, "BeaconStripe", Vector3(0, 0.5, -0.55), Vector3(0.9, 0.18, 0.15), warm)
        beacons.append(beacon)

func _process(delta: float) -> void:
    elapsed += delta
    for beacon in beacons:
        if is_instance_valid(beacon):
            beacon.rotation.y += delta * 0.16
