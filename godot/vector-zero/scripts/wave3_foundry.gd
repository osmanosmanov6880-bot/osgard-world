extends RefCounted
## VECTOR//ZERO / WAVE 3. Original production-oriented procedural hero assets.
## Physically plausible rings, continuous coolant tubes and UV-mapped machined surfaces.
## Built without borrowed commercial game meshes; supports GL Compatibility.

static var mats: Dictionary = {}
static var bump: ImageTexture
const STEEL := Color(0.43, 0.50, 0.55)
const GUN := Color(0.13, 0.18, 0.23)
const BRONZE := Color(0.60, 0.40, 0.26)
const CERAMIC := Color(0.70, 0.77, 0.80)
const CYAN := Color(0.13, 0.67, 0.82)
const INDIGO := Color(0.47, 0.30, 0.76)

static func build(world: Node3D, core: Node3D, magnet: Node3D, receiver: Node3D) -> void:
    _setup_materials()
    var foundry := Node3D.new()
    foundry.name = "Wave3Foundry"
    world.add_child(foundry)
    _architecture(foundry)
    _cryogenic_banks(foundry)
    _control_room(foundry)
    _light_the_machinery(foundry)
    var gyroscope := Node3D.new()
    gyroscope.name = "Wave3PrecisionProjectile"
    core.add_child(gyroscope)
    _precision_projectile(gyroscope)
    var cryomagnet := Node3D.new()
    cryomagnet.name = "Wave3MagnetAssembly"
    magnet.add_child(cryomagnet)
    _cryomagnet(cryomagnet)
    var aperture := Node3D.new()
    aperture.name = "Wave3CaptureGate"
    receiver.add_child(aperture)
    _capture_gate(aperture)

static func _setup_materials() -> void:
    if not mats.is_empty():
        return
    var normal_img := Image.create(192, 192, false, Image.FORMAT_RGBA8)
    for y in range(192):
        for x in range(192):
            var groove := sin(float(x) * 0.78) * 0.031 + sin(float(x) * 3.5) * 0.012
            var micro := sin(float(y * 7 + x * 13) * 0.41) * 0.008
            normal_img.set_pixel(x, y, Color(0.5 + groove, 0.5 + micro, 0.995, 1))
    bump = ImageTexture.create_from_image(normal_img)
    mats["steel"] = _mat(STEEL, 0.87, 0.30, false)
    mats["gun"] = _mat(GUN, 0.80, 0.36, false)
    mats["bronze"] = _mat(BRONZE, 0.88, 0.27, false)
    mats["ceramic"] = _mat(CERAMIC, 0.13, 0.37, false)
    mats["cyan"] = _mat(CYAN, 0.09, 0.20, true)
    mats["indigo"] = _mat(INDIGO, 0.24, 0.26, true)
    mats["warning"] = _mat(Color(0.94, 0.62, 0.20), 0.19, 0.28, true)

static func _mat(color: Color, metal: float, rough: float, emitting: bool) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = rough
    if metal > 0.7:
        mat.normal_enabled = true
        mat.normal_texture = bump
        mat.normal_scale = 0.30
        mat.uv1_triplanar = true
    if emitting:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 0.88
    return mat

static func _node(parent: Node3D, title: String, mesh: Mesh, mat_key: String, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = mesh
    node.material_override = mats[mat_key]
    node.position = position
    parent.add_child(node)
    return node

static func _box(parent: Node3D, title: String, pos: Vector3, dims: Vector3, mat_key: String) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dims
    return _node(parent, title, mesh, mat_key, pos)

static func _lathe_mesh(profile: PackedVector2Array, divisions: int = 84) -> ArrayMesh:
    # Indexed, UV-mapped CNC profile with continuous angular vertices.
    var vert := PackedVector3Array()
    var uv := PackedVector2Array()
    var norms := PackedVector3Array()
    var idx := PackedInt32Array()
    for j in range(profile.size()):
        var center := profile[j]
        var before := profile[maxi(j - 1, 0)]
        var after := profile[mini(j + 1, profile.size() - 1)]
        var direction := (after - before).normalized()
        var out := Vector2(direction.y, -direction.x)
        for i in range(divisions + 1):
            var theta := float(i) * TAU / float(divisions)
            var x := cos(theta)
            var z := sin(theta)
            vert.append(Vector3(x * center.x, center.y, z * center.x))
            norms.append(Vector3(x * out.x, out.y, z * out.x).normalized())
            uv.append(Vector2(float(i) / float(divisions), float(j) / float(profile.size() - 1)))
    for j in range(profile.size() - 1):
        for i in range(divisions):
            var k := j * (divisions + 1) + i
            var next := k + divisions + 1
            idx.append_array(PackedInt32Array([k, next, k + 1, next, next + 1, k + 1]))
    var ar: Array = []
    ar.resize(Mesh.ARRAY_MAX)
    ar[Mesh.ARRAY_VERTEX] = vert
    ar[Mesh.ARRAY_NORMAL] = norms
    ar[Mesh.ARRAY_TEX_UV] = uv
    ar[Mesh.ARRAY_INDEX] = idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, ar)
    return mesh

static func _lathe(parent: Node3D, name: String, profile: PackedVector2Array, mat_key: String, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    return _node(parent, name, _lathe_mesh(profile), mat_key, position)

static func _tube_mesh(path: PackedVector3Array, thickness: float, sides: int = 12) -> ArrayMesh:
    var vert := PackedVector3Array()
    var uv := PackedVector2Array()
    var normals := PackedVector3Array()
    var idx := PackedInt32Array()
    for i in range(path.size()):
        var tangent := (path[mini(i + 1, path.size() - 1)] - path[maxi(i - 1, 0)]).normalized()
        if tangent.length_squared() < 0.001:
            tangent = Vector3.UP
        var guide := Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.87 else Vector3.UP
        var across := tangent.cross(guide).normalized()
        var side := tangent.cross(across).normalized()
        for j in range(sides + 1):
            var theta := TAU * float(j) / float(sides)
            var outward := across * cos(theta) + side * sin(theta)
            vert.append(path[i] + outward * thickness)
            normals.append(outward)
            uv.append(Vector2(float(j) / float(sides), float(i) / 30.0))
    for i in range(path.size() - 1):
        for j in range(sides):
            var k := i * (sides + 1) + j
            var n := k + sides + 1
            idx.append_array(PackedInt32Array([k, k + 1, n, k + 1, n + 1, n]))
    var arr: Array = []
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX] = vert
    arr[Mesh.ARRAY_NORMAL] = normals
    arr[Mesh.ARRAY_TEX_UV] = uv
    arr[Mesh.ARRAY_INDEX] = idx
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
    return result

static func _batch(parent: Node3D, title: String, mesh: Mesh, transforms: Array[Transform3D], mat_key: String) -> MultiMeshInstance3D:
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = transforms.size()
    for i in range(transforms.size()):
        multi.set_instance_transform(i, transforms[i])
    var obj := MultiMeshInstance3D.new()
    obj.name = title
    obj.multimesh = multi
    obj.material_override = mats[mat_key]
    parent.add_child(obj)
    return obj

static func _industrial_welds(parent: Node3D) -> void:
    var screw := CylinderMesh.new()
    screw.top_radius = 0.75
    screw.bottom_radius = 0.75
    screw.height = 1.0
    screw.radial_segments = 10
    var fasteners: Array[Transform3D] = []
    for px in [-12.6, -8.4, -4.2, 4.2, 8.4, 12.6]:
        for side in [-1.0, 1.0]:
            for y in [2.0, 5.0, 8.0, 11.0]:
                for dz in [-6.8, -3.9, -1.0]:
                    fasteners.append(Transform3D(Basis().scaled(Vector3(0.095, 0.19, 0.095)), Vector3(px + side * 0.13, y, dz)))
    _batch(parent, "ServiceFrameFasteners_144", screw, fasteners, "bronze")

static func _architecture(root: Node3D) -> void:
    # The exterior remains subordinate to the shot trajectory. All tall masses
    # are behind the magnetic field or on the outer perimeter.
    _industrial_welds(root)
    for x in [-11.2, -4.5, 4.5, 11.2]:
        var gantry := Node3D.new()
        gantry.name = "CNCBridgeGantry_%d" % int(x * 10.0)
        gantry.position = Vector3(x, 12.2, -3.0)
        root.add_child(gantry)
        _box(gantry, "IBeamWeb", Vector3.ZERO, Vector3(0.18, 0.86, 8.6), "gun")
        _box(gantry, "IBeamUpperFlange", Vector3(0, 0.47, 0), Vector3(0.94, 0.12, 8.6), "steel")
        _box(gantry, "IBeamLowerFlange", Vector3(0, -0.47, 0), Vector3(0.94, 0.12, 8.6), "steel")
        for offset in [-3.1, -1.55, 0.0, 1.55, 3.1]:
            _box(gantry, "WeldedCrossTie", Vector3(0, -0.2, offset), Vector3(1.1, 0.18, 0.17), "bronze")
    # Side-wall airlocks look thick and mechanical rather than giant dark slabs.
    for x in [-13.35, 13.35]:
        for z in [-5.6, 3.8]:
            var airlock := Node3D.new()
            airlock.name = "PressureLock_%d_%d" % [int(x), int(z)]
            airlock.position = Vector3(x, 3.9, z)
            airlock.rotation.y = PI * 0.5
            root.add_child(airlock)
            _box(airlock, "CeramicSealedDoor", Vector3.ZERO, Vector3(2.0, 4.5, 0.17), "gun")
            _box(airlock, "CNCInnerBulkhead", Vector3.ZERO, Vector3(1.55, 3.95, 0.22), "steel")
            _box(airlock, "SealingBrace", Vector3(0, 1.45, 0.16), Vector3(1.65, 0.17, 0.1), "bronze")
            _box(airlock, "SealingBrace", Vector3(0, -1.45, 0.16), Vector3(1.65, 0.17, 0.1), "bronze")
            for yy in [-0.8, -0.2, 0.4, 1.0]:
                _box(airlock, "PressureRib", Vector3(0, yy, 0.2), Vector3(1.46, 0.05, 0.11), "ceramic")
            _lathe(airlock, "CNCActuatorBarrel", PackedVector2Array([Vector2(0.10,-0.43), Vector2(0.27,-0.42), Vector2(0.32,-0.35), Vector2(0.32,0.34), Vector2(0.23,0.41), Vector2(0.08,0.44)]), "bronze", Vector3(0.90, 0.0, 0.3))

static func _cryogenic_banks(root: Node3D) -> void:
    # Large detailed shapes frame the arena, visible from the player's camera.
    # The four pressure vessels sit against the walls and do not touch the
    # energy-core trajectory or the receiver's interaction volume.
    for side in [-1.0, 1.0]:
        for bank_id in range(2):
            var tank := Node3D.new()
            tank.name = "CryogenicBank_%d_%d" % [int(side), bank_id]
            tank.position = Vector3(side * 12.05, 0.0, -4.4 + float(bank_id) * 7.0)
            root.add_child(tank)
            _lathe(tank, "MachinedVacuumPressureVessel", PackedVector2Array([
                Vector2(0.10, 0.35), Vector2(0.90, 0.35), Vector2(1.04, 0.48),
                Vector2(1.08, 0.82), Vector2(0.99, 1.20), Vector2(0.99, 4.54),
                Vector2(1.10, 4.97), Vector2(1.10, 5.18), Vector2(0.88, 5.40),
                Vector2(0.27, 5.49)
            ]), "steel")
            for h in [0.67, 1.90, 3.32, 4.79]:
                _lathe(tank, "CNCFluidLockCollar", PackedVector2Array([
                    Vector2(1.0, h - 0.095), Vector2(1.20, h - 0.045),
                    Vector2(1.24, h + 0.035), Vector2(1.0, h + 0.095)
                ]), "bronze")
            for s in range(12):
                var a := float(s) * TAU / 12.0
                var rib := Node3D.new()
                rib.name = "PrecisionRadialRib_%02d" % s
                rib.rotation.y = a
                tank.add_child(rib)
                _box(rib, "PressureJacketBeam", Vector3(0, 2.85, 1.05), Vector3(0.10, 3.50, 0.14), "gun")
                _box(rib, "CalibrationMarker", Vector3(0, 4.05, 1.15), Vector3(0.08, 0.24, 0.10), "cyan")
            _box(tank, "CryogenicTelemetryChassis", Vector3(0.0, 3.12, 1.22), Vector3(0.74, 0.98, 0.21), "gun")
            _box(tank, "CryogenicTelemetryPanel", Vector3(0.0, 3.12, 1.36), Vector3(0.59, 0.77, 0.04), "ceramic")
            for k in range(4):
                _box(tank, "AnalogFluidLevelScale", Vector3(-0.19 + float(k) * 0.12, 3.05, 1.40), Vector3(0.045, 0.34 + float(k % 2) * 0.17, 0.035), "warning")
            _lathe(tank, "PressureVentHead", PackedVector2Array([
                Vector2(0.14, 5.39), Vector2(0.54, 5.39), Vector2(0.58, 5.51),
                Vector2(0.50, 5.65), Vector2(0.42, 5.85), Vector2(0.15, 5.90)
            ]), "gun")

static func _light_the_machinery(root: Node3D) -> void:
    # Practical scene lighting: cool front fill and restrained warm rim lights.
    # No gratuitous light-emitting floor meshes.
    var locations := [
        Vector3(0.0, 8.4, 9.2),
        Vector3(-11.0, 7.0, 4.8),
        Vector3(11.0, 7.0, 4.8)
    ]
    for i in range(locations.size()):
        var light := OmniLight3D.new()
        light.name = "CalibratedIndustrialLight_%d" % i
        light.position = locations[i]
        light.light_color = Color(0.73, 0.85, 0.95) if i == 0 else Color(1.0, 0.74, 0.46)
        light.light_energy = 2.0 if i == 0 else 1.15
        light.omni_range = 23.0 if i == 0 else 13.0
        light.shadow_enabled = false
        root.add_child(light)

static func _control_room(root: Node3D) -> void:
    # Sensor consoles are aligned to wall, with finite physical display housings.
    for x in [-9.3, -4.8, 4.8, 9.3]:
        var panel := Node3D.new()
        panel.name = "WallSpectrometer_%d" % int(x * 10.0)
        panel.position = Vector3(x, 3.4, -6.6)
        root.add_child(panel)
        _box(panel, "HardenedDisplayFrame", Vector3.ZERO, Vector3(1.8, 1.5, 0.24), "steel")
        _box(panel, "VolumetricSpectrum", Vector3(0, 0, 0.15), Vector3(1.57, 1.27, 0.03), "gun")
        for i in range(9):
            var xx: float = -0.62 + float(i) * 0.155
            _box(panel, "SpectrumColumn", Vector3(xx, -0.34 + sin(float(i) * 0.81) * 0.12, 0.2), Vector3(0.055, 0.34 + absf(sin(float(i) * 0.81)) * 0.30, 0.03), "cyan")
        _box(panel, "CalibrationMarker", Vector3(-0.67, 0.54, 0.2), Vector3(0.16, 0.10, 0.02), "warning")

static func _precision_projectile(root: Node3D) -> void:
    # Ultra-close-up machined plating keeps the launch core's luminous equator readable.
    _lathe(root, "MachinedGyroNose_120", PackedVector2Array([Vector2(0.09, -0.64), Vector2(0.29, -0.60), Vector2(0.48, -0.54), Vector2(0.59, -0.45), Vector2(0.58, -0.38), Vector2(0.50, -0.34)]), "ceramic")
    _lathe(root, "MachinedGyroTail_120", PackedVector2Array([Vector2(0.50, 0.34), Vector2(0.58, 0.38), Vector2(0.59, 0.45), Vector2(0.48, 0.54), Vector2(0.29, 0.60), Vector2(0.09, 0.64)]), "steel")
    for side in range(8):
        var a := float(side) * TAU / 8.0
        var fin := Node3D.new()
        fin.name = "GyroCoolingFin_%02d" % side
        fin.rotation.y = a
        root.add_child(fin)
        _box(fin, "MachinedHeatExchanger", Vector3(0, 0.0, 0.60), Vector3(0.085, 0.55, 0.30), "bronze")
        _box(fin, "MicroPhotodiode", Vector3(0, 0.23, 0.82), Vector3(0.09, 0.10, 0.06), "cyan")
    var bolts: Array[Transform3D] = []
    for i in range(72):
        var theta := float(i) * TAU / 72.0
        bolts.append(Transform3D(Basis().scaled(Vector3(0.045, 0.07, 0.045)), Vector3(cos(theta) * 0.60, -0.42, sin(theta) * 0.60)))
    var little := CylinderMesh.new()
    little.top_radius = 0.78
    little.bottom_radius = 0.78
    little.height = 1.0
    little.radial_segments = 8
    _batch(root, "GyroNoseM8Fasteners_72", little, bolts, "gun")

static func _cryomagnet(root: Node3D) -> void:
    # Multiple precision profiles on the existing stator. Behind the center line
    # there is still open air, so the player can read the trajectory.
    _lathe(root, "SuperconductingCryoJacket", PackedVector2Array([
        Vector2(1.50,-2.23), Vector2(1.80,-2.20), Vector2(2.00,-2.11), Vector2(2.04,-1.92),
        Vector2(1.92,-1.79), Vector2(1.85,-1.72), Vector2(1.85,1.72), Vector2(1.92,1.79),
        Vector2(2.04,1.92), Vector2(2.00,2.11), Vector2(1.80,2.20), Vector2(1.50,2.23)
    ]), "gun")
    for h in [-1.74, 1.74]:
        _lathe(root, "CryogenicPressureCollar", PackedVector2Array([
            Vector2(1.94,h - 0.14), Vector2(2.26,h - 0.08), Vector2(2.32,h),
            Vector2(2.26,h + 0.08), Vector2(1.94,h + 0.14)
        ]), "steel")
    for strand in range(4):
        var points := PackedVector3Array()
        for i in range(241):
            var t := float(i) / 240.0
            var angle := TAU * (8.0 * t + float(strand) / 4.0)
            points.append(Vector3(2.09 * cos(angle), lerpf(-1.76, 1.76, t), 2.09 * sin(angle)))
        _node(root, "CryoCoilCopperSpiral_%d" % strand, _tube_mesh(points, 0.061, 11), "bronze")
    # Electrical slip-rings: 96 bolts, one GPU draw call.
    var transforms: Array[Transform3D] = []
    for i in range(96):
        var theta := TAU * float(i) / 96.0
        transforms.append(Transform3D(Basis().scaled(Vector3(0.09, 0.12, 0.09)), Vector3(cos(theta) * 2.13, 1.99, sin(theta) * 2.13)))
    var screw := CylinderMesh.new()
    screw.top_radius = 0.72
    screw.bottom_radius = 0.72
    screw.height = 1.0
    screw.radial_segments = 8
    _batch(root, "CryoStatorHexBolts_96", screw, transforms, "ceramic")
    # The scanner rotor is a single animatable node; no per-bolt update loop.
    var rotor := Node3D.new()
    rotor.name = "RadiationScannerRotor"
    root.add_child(rotor)
    for ring in range(2):
        var profile := PackedVector2Array()
        var level := -0.58 + float(ring) * 1.16
        profile.append_array(PackedVector2Array([
            Vector2(2.12,level - 0.055),Vector2(2.40,level - 0.028),
            Vector2(2.43,level + 0.025),Vector2(2.13,level + 0.055)
        ]))
        _lathe(rotor, "CNCActiveScannerRing_%d" % ring, profile, "cyan")
    for i in range(12):
        var a := TAU * float(i) / 12.0
        var probe := Node3D.new()
        probe.name = "RotatingProbe_%02d" % i
        probe.rotation.y = a
        rotor.add_child(probe)
        _box(probe, "TelemetryArm", Vector3(0, 0, 2.40), Vector3(0.05, 1.53, 0.09), "steel")
        _box(probe, "SignalEye", Vector3(0, 0.80, 2.43), Vector3(0.17, 0.14, 0.12), "warning")

static func _capture_gate(root: Node3D) -> void:
    # Crisp, restrained CNC components around the open catch ring.
    _lathe(root, "ReceiverServoBearing", PackedVector2Array([
        Vector2(1.14,-0.24), Vector2(1.55,-0.23), Vector2(1.74,-0.12),
        Vector2(1.80,0.0), Vector2(1.74,0.12), Vector2(1.55,0.23), Vector2(1.14,0.24)
    ]), "steel").rotation.x = PI * 0.5
    var contact := PackedVector3Array()
    for i in range(193):
        var theta := TAU * float(i) / 192.0
        contact.append(Vector3(sin(theta) * 1.11, cos(theta) * 1.11, 0.30))
    _node(root, "OpticalCaptureContactRail", _tube_mesh(contact, 0.032), "cyan")
    var bolts: Array[Transform3D] = []
    for i in range(64):
        var theta := TAU * float(i) / 64.0
        bolts.append(Transform3D(Basis().scaled(Vector3(0.08, 0.08, 0.09)), Vector3(sin(theta) * 1.59, cos(theta) * 1.59, 0.32)))
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    _batch(root, "ReceiverRadialSensorClamps_64", mesh, bolts, "gun")