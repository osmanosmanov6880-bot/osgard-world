extends RefCounted
## CHRONOS CITY WAVE 3 / Procedurally sculpted engineering, believable megastructures.
## Geometry is made of actual indexed meshes and shared PBR resources.
## No external art dependencies. Native and GL Compatibility use the same topology.

static var mats: Dictionary = {}
static var micro: ImageTexture
const METAL := Color(0.55, 0.62, 0.65)
const TITAN := Color(0.15, 0.25, 0.31)
const BRONZE := Color(0.68, 0.46, 0.31)
const GLASS := Color(0.22, 0.45, 0.52)
const GOLD := Color(0.97, 0.77, 0.48)
const GREEN := Color(0.19, 0.41, 0.32)
const AQUA := Color(0.26, 0.79, 0.88)

static func build(city: Node3D, core: Node3D, traffic: Array[Node3D]) -> void:
    _setup()
    var root := Node3D.new()
    root.name = "Wave3Metropolis"
    city.add_child(root)
    _chrono_plant(core)
    _civic_gatehouses(root)
    _facade_pass(root, city)
    _landscape(root)
    _shuttle_design(traffic)

static func decorate_district(district: Node3D, index: int) -> void:
    _setup()
    var sub := Node3D.new()
    sub.name = "Wave3UtilityDistrict_%02d" % index
    district.add_child(sub)
    _lathe(sub, "RefinedPowerMainfold", PackedVector2Array([
        Vector2(0.75, 0.75), Vector2(1.43, 0.78), Vector2(1.61, 0.96),
        Vector2(1.60, 1.14), Vector2(1.38, 1.27), Vector2(1.27, 3.51),
        Vector2(1.45, 3.67), Vector2(1.48, 3.81), Vector2(0.92, 3.90)
    ]), "metal")
    for t in range(6):
        var angle := TAU * float(t) / 6.0
        var p := Node3D.new()
        p.name = "RadialSector_%02d" % t
        p.rotation.y = angle
        sub.add_child(p)
        _box(p, "HeatExchanger", Vector3(0, 2.9, 1.42), Vector3(0.20, 3.02, 0.14), "titan")
        _box(p, "GlazedGenerationCore", Vector3(0, 3.0, 1.55), Vector3(0.13, 2.16, 0.09), "glass")
        _box(p, "LinearPhotodiode", Vector3(0, 4.4, 1.52), Vector3(0.20, 0.20, 0.10), "aqua")
        _box(p, "SolarWing", Vector3(0, 4.75, 1.90), Vector3(1.1, 0.095, 0.70), "metal")
    var bolts: Array[Transform3D] = []
    for i in range(48):
        var angle := TAU * float(i) / 48.0
        bolts.append(Transform3D(Basis().scaled(Vector3(0.072, 0.10, 0.072)), Vector3(cos(angle) * 1.47, 1.07, sin(angle) * 1.47)))
    var bolt := CylinderMesh.new()
    bolt.top_radius = 0.7
    bolt.bottom_radius = 0.7
    bolt.height = 1.0
    bolt.radial_segments = 8
    _batch(sub, "CNCFoundationBolts48", bolt, bolts, "bronze")

static func _setup() -> void:
    if not mats.is_empty():
        return
    var img := Image.create(192, 192, false, Image.FORMAT_RGBA8)
    for y in range(192):
        for x in range(192):
            var scratch := sin(float(x) * 1.62) * 0.026 + sin(float(x) * 0.15) * 0.014
            var ripple := sin(float(y * 21 + x * 7) * 0.31) * 0.009
            img.set_pixel(x, y, Color(0.50 + scratch, 0.50 + ripple, 0.994, 1))
    micro = ImageTexture.create_from_image(img)
    mats["metal"] = _material(METAL, 0.86, 0.30, false)
    mats["titan"] = _material(TITAN, 0.76, 0.37, false)
    mats["bronze"] = _material(BRONZE, 0.83, 0.27, false)
    mats["glass"] = _material(GLASS, 0.33, 0.23, false)
    mats["aqua"] = _material(AQUA, 0.14, 0.23, true)
    mats["gold"] = _material(GOLD, 0.24, 0.25, true)
    mats["green"] = _material(GREEN, 0.02, 0.86, false)

static func _material(color: Color, metallic: float, roughness: float, glowing: bool) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    if metallic > 0.7:
        mat.normal_enabled = true
        mat.normal_texture = micro
        mat.normal_scale = 0.28
        mat.uv1_triplanar = true
    if glowing:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 0.72
    return mat

static func _node(parent: Node3D, name: String, shape: Mesh, material_key: String, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = shape
    node.material_override = mats[material_key]
    node.position = position
    parent.add_child(node)
    return node

static func _box(parent: Node3D, name: String, pos: Vector3, dimensions: Vector3, material_key: String) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = dimensions
    return _node(parent, name, shape, material_key, pos)

static func _sphere(parent: Node3D, name: String, pos: Vector3, radius: float, material_key: String) -> MeshInstance3D:
    var shape := SphereMesh.new()
    shape.radius = radius
    shape.height = radius * 2.0
    shape.radial_segments = 28
    shape.rings = 14
    return _node(parent, name, shape, material_key, pos)

static func _lathe_shape(profile: PackedVector2Array, sides: int = 80) -> ArrayMesh:
    var v := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var ind := PackedInt32Array()
    for i in range(profile.size()):
        var p := profile[i]
        var prev := profile[maxi(i - 1, 0)]
        var nxt := profile[mini(i + 1, profile.size() - 1)]
        var forward := (nxt - prev).normalized()
        var n := Vector2(forward.y, -forward.x)
        for j in range(sides + 1):
            var a := TAU * float(j) / float(sides)
            v.append(Vector3(cos(a) * p.x, p.y, sin(a) * p.x))
            normals.append(Vector3(cos(a) * n.x, n.y, sin(a) * n.x).normalized())
            uv.append(Vector2(float(j) / float(sides), float(i) / float(profile.size() - 1)))
    for i in range(profile.size() - 1):
        for j in range(sides):
            var k := i * (sides + 1) + j
            var m := k + sides + 1
            ind.append_array(PackedInt32Array([k, m, k + 1, m, m + 1, k + 1]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = v
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_INDEX] = ind
    var shape := ArrayMesh.new()
    shape.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return shape

static func _lathe(parent: Node3D, name: String, profile: PackedVector2Array, material_key: String, at: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _node(parent, name, _lathe_shape(profile), material_key, at)

static func _tube_shape(points: PackedVector3Array, radius: float, sides: int = 12) -> ArrayMesh:
    var v := PackedVector3Array()
    var norms := PackedVector3Array()
    var uv := PackedVector2Array()
    var idx := PackedInt32Array()
    for i in range(points.size()):
        var tangent := (points[mini(points.size() - 1, i + 1)] - points[maxi(0, i - 1)]).normalized()
        if tangent.length_squared() < 0.001:
            tangent = Vector3.UP
        var guide := Vector3.UP if absf(tangent.dot(Vector3.UP)) < 0.9 else Vector3.FORWARD
        var lateral := tangent.cross(guide).normalized()
        var upper := tangent.cross(lateral).normalized()
        for j in range(sides + 1):
            var angle := TAU * float(j) / float(sides)
            var out := lateral * cos(angle) + upper * sin(angle)
            v.append(points[i] + out * radius)
            norms.append(out)
            uv.append(Vector2(float(j) / float(sides), float(i) / 30.0))
    for i in range(points.size() - 1):
        for j in range(sides):
            var k := i * (sides + 1) + j
            var next := k + sides + 1
            idx.append_array(PackedInt32Array([k, next, k + 1, next, next + 1, k + 1]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = v
    arrays[Mesh.ARRAY_NORMAL] = norms
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_INDEX] = idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

static func _batch(parent: Node3D, name: String, mesh: Mesh, locations: Array[Transform3D], mat_key: String) -> MultiMeshInstance3D:
    var m := MultiMesh.new()
    m.transform_format = MultiMesh.TRANSFORM_3D
    m.mesh = mesh
    m.instance_count = locations.size()
    for i in range(locations.size()):
        m.set_instance_transform(i, locations[i])
    var inst := MultiMeshInstance3D.new()
    inst.name = name
    inst.multimesh = m
    inst.material_override = mats[mat_key]
    parent.add_child(inst)
    return inst

static func _chrono_plant(reactor: Node3D) -> void:
    var plant := Node3D.new()
    plant.name = "Wave3ChronoEngine"
    reactor.add_child(plant)
    _lathe(plant, "CNCBottomReductionHousing", PackedVector2Array([
        Vector2(1.9, 0.1), Vector2(3.2, 0.1), Vector2(3.53, 0.3),
        Vector2(3.53, 0.59), Vector2(3.0, 0.83), Vector2(1.9, 0.83)
    ]), "metal")
    for y in [1.11, 2.30, 3.48]:
        _lathe(plant, "AxialFlywheelPrecisionBearing", PackedVector2Array([
            Vector2(2.48, y - 0.13), Vector2(2.85, y - 0.09), Vector2(2.98, y),
            Vector2(2.85, y + 0.09), Vector2(2.48, y + 0.13)
        ]), "bronze")
    # Thirty-two bearing spokes keep the enlarged machine readable from orbit view.
    for i in range(16):
        var theta := TAU * float(i) / 16.0
        var arm := Node3D.new()
        arm.name = "RadialHydraulicActuator_%02d" % i
        arm.rotation.y = theta
        plant.add_child(arm)
        _box(arm, "CeramicBearingStrut", Vector3(0, 1.87, 3.11), Vector3(0.22, 2.8, 0.25), "metal")
        _box(arm, "HeatTransferChannel", Vector3(0, 1.95, 3.27), Vector3(0.065, 1.95, 0.10), "glass")
        _box(arm, "InductionTelemetry", Vector3(0, 3.35, 3.26), Vector3(0.16, 0.18, 0.14), "aqua")
    var bolts: Array[Transform3D] = []
    for k in range(192):
        var angle := TAU * float(k % 64) / 64.0
        var y := 0.31 + float(k / 64) * 1.19
        bolts.append(Transform3D(Basis().scaled(Vector3(0.06, 0.11, 0.06)), Vector3(cos(angle) * 3.33, y, sin(angle) * 3.33)))
    var fastener := CylinderMesh.new()
    fastener.top_radius = 0.7
    fastener.bottom_radius = 0.7
    fastener.height = 1.0
    fastener.radial_segments = 8
    _batch(plant, "ChronoPlantFasteners192", fastener, bolts, "bronze")
    # Reinforced turbine housing is faceted rather than an emissive flat torus.
    _lathe(plant, "MachinedInductionCrown", PackedVector2Array([
        Vector2(2.7, 7.65), Vector2(3.1, 7.67), Vector2(3.43, 7.85),
        Vector2(3.43, 8.14), Vector2(3.11, 8.32), Vector2(2.74, 8.33)
    ]), "metal")
    var spar := PackedVector3Array()
    for i in range(145):
        var a := TAU * float(i) / 144.0
        spar.append(Vector3(cos(a) * 3.40, 8.18 + sin(a * 12.0) * 0.05, sin(a) * 3.40))
    _node(plant, "ChronoCrownFiberOptic", _tube_shape(spar, 0.035), "aqua")

static func _civic_gatehouses(root: Node3D) -> void:
    # Landmark entrance structures at the four ends of the illuminated boulevards.
    # They sit low, leaving a clear sightline to the central reactor.
    for i in range(4):
        var angle := float(i) * TAU / 4.0
        var site := Node3D.new()
        site.name = "CivicArrivalPort_%02d" % i
        site.position = Vector3(sin(angle) * 25.4, 0.4, cos(angle) * 25.4)
        site.rotation.y = angle
        root.add_child(site)
        _box(site, "DeepTitaniumFoundation", Vector3(0, 0.40, 0), Vector3(5.1, 0.85, 3.15), "titan")
        for side in [-1.0, 1.0]:
            _box(site, "MilledPortalPylon", Vector3(side * 2.08, 2.9, 0), Vector3(0.62, 4.6, 0.73), "metal")
            _box(site, "IntegratedTransitLumen", Vector3(side * 2.08, 3.0, 0.43), Vector3(0.09, 3.62, 0.07), "aqua")
        _box(site, "SuspendedRoof", Vector3(0, 5.18, 0), Vector3(5.2, 0.48, 1.35), "bronze")
        _box(site, "PassengerDeck", Vector3(0, 0.97, 0.65), Vector3(3.68, 0.15, 1.40), "metal")
        for x in [-1.35, 0.0, 1.35]:
            _box(site, "DockArrivalIllumination", Vector3(x, 1.09, 1.24), Vector3(0.52, 0.05, 0.08), "gold")

static func _facade_pass(root: Node3D, city: Node3D) -> void:
    # Distinct, physically recessed vertical facade details on existing landmark
    # parents. Never place unsupported roof elements at guessed heights.
    var monuments: Node3D = city.get_node_or_null("Chronos_UltraCityArchitecture")
    if monuments == null:
        return
    for i in range(12):
        var building: Node3D = monuments.get_node_or_null("SculptedLandmark_%02d" % i)
        if building == null:
            continue
        var shell := Node3D.new()
        shell.name = "Wave3EtchedGlassFacade_%02d" % i
        shell.position = Vector3(0.0, 0.0, 0.0)
        building.add_child(shell)
        var tall := 9.3 if i % 4 == 2 else 12.3 + float(i % 3) * 0.7
        var outer := 1.42 if i % 4 == 2 else 1.20
        var panels: Array[Transform3D] = []
        for row in range(16):
            var h := 0.85 + float(row) * (tall - 1.45) / 16.0
            for side in range(8):
                var a := float(side) * TAU / 8.0
                if (row + side + i) % 4 == 0:
                    continue
                var p := Vector3(cos(a) * outer, h, sin(a) * outer)
                var transform := Transform3D(Basis(Vector3.UP, a).scaled(Vector3(0.39, 0.14, 0.04)), p)
                panels.append(transform)
        for k in range(8):
            var a := float(k) * TAU / 8.0
            _box(shell, "VerticalStructuralRib", Vector3(cos(a) * outer, tall * 0.5, sin(a) * outer), Vector3(0.08, tall * 0.8, 0.08), "metal")
        # Panels are in this tower's LOCAL coordinates. Instancing at the city
        # origin would create an unwanted solid lump around the reactor.
        var marker := BoxMesh.new()
        marker.size = Vector3.ONE
        _batch(shell, "EtchedRecessedWindows", marker, panels, "glass")

static func _landscape(root: Node3D) -> void:
    # A modest set of parks and trim remains below the skyline; no giant green
    # halos or floor-filling light objects.
    var trees: Array[Transform3D] = []
    var trunk := SphereMesh.new()
    trunk.radius = 1.0
    trunk.height = 2.0
    trunk.radial_segments = 12
    trunk.rings = 7
    for i in range(64):
        var angle := TAU * float(i) / 64.0
        var radius := 26.0 if i % 3 == 0 else 23.5
        var x := cos(angle) * radius
        var z := sin(angle) * radius
        # Preserve boulevard entrances to the monumental city.
        if absf(x) < 3.2 or absf(z) < 3.2:
            continue
        trees.append(Transform3D(Basis().scaled(Vector3(0.22, 0.38 + float(i % 3) * 0.05, 0.23)), Vector3(x, 0.85, z)))
    _batch(root, "NaturalisticCivicTreeCanopies", trunk, trees, "green")

static func _shuttle_design(traffic: Array[Node3D]) -> void:
    for i in range(traffic.size()):
        var node := traffic[i]
        var chassis := Node3D.new()
        chassis.name = "Wave3SculptedTransitChassis_%02d" % i
        node.add_child(chassis)
        _lathe(chassis, "CNCPropulsionHood", PackedVector2Array([
            Vector2(0.09, -0.32), Vector2(0.19, -0.24), Vector2(0.27, -0.08),
            Vector2(0.27, 0.09), Vector2(0.23, 0.23), Vector2(0.08, 0.34)
        ]), "metal", Vector3(0, 0.12, -0.1))
        _box(chassis, "GlazedAutonomousPilot", Vector3(0, 0.31, 0.06), Vector3(0.30, 0.16, 0.54), "glass")
        _box(chassis, "RearDiffuser", Vector3(0, 0.00, 0.48), Vector3(0.31, 0.08, 0.10), "aqua")