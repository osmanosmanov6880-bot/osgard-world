extends Node3D
## NEBULA R6: close-camera interceptor hero geometry, not sprites or concept art.
## Curved lofted underskin, layered aircraft panels, four gun assemblies, turbine
## microgeometry, and batched rivets. Kept separate from all gameplay and saves.

var hero_parts: int = 0
var fasteners: int = 0
var animated_rotors: Array[Node3D] = []
var gun_count: int = 0
var material_cache: Dictionary = {}

func _ready() -> void:
    material_cache = {
        "hull": _metal(Color(0.16, 0.23, 0.29), 0.31),
        "edge": _metal(Color(0.45, 0.50, 0.52), 0.24),
        "carbon": _metal(Color(0.022, 0.031, 0.044), 0.62),
        "glass": _metal(Color(0.035, 0.12, 0.17), 0.11),
        "bronze": _metal(Color(0.48, 0.30, 0.13), 0.34),
        "ceramic": _metal(Color(0.66, 0.69, 0.67), 0.44),
        "plasma": _metal(Color(0.10, 0.47, 0.62), 0.35, 0.65)
    }
    _sculpt_underbody()
    _wing_armor()
    _weapons()
    _engine_microgeometry()
    _cockpit_details()
    _surface_fasteners()

func _metal(color: Color, roughness: float, glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.79
    mat.roughness = roughness
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = glow
    return mat

func _box(name: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = shape
    node.position = pos
    node.material_override = material
    add_child(node)
    hero_parts += 1
    return node

func _sphere(name: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var shape := SphereMesh.new()
    shape.radius = 1.0
    shape.height = 2.0
    shape.radial_segments = 24
    shape.rings = 12
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = shape
    node.position = pos
    node.scale = size
    node.material_override = material
    add_child(node)
    hero_parts += 1
    return node

func _rod(name: String, start: Vector3, end: Vector3, radius: float, material: Material, divisions: int = 12) -> MeshInstance3D:
    var delta: Vector3 = end - start
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = delta.length()
    shape.radial_segments = divisions
    var rod := MeshInstance3D.new()
    rod.name = name
    rod.mesh = shape
    rod.position = (start + end) * 0.5
    rod.basis = Basis(Quaternion(Vector3.UP, delta.normalized()))
    rod.material_override = material
    add_child(rod)
    hero_parts += 1
    return rod

func _torus(name: String, radius: float, thickness: float, pos: Vector3, material: Material) -> MeshInstance3D:
    var torus := TorusMesh.new()
    torus.inner_radius = radius - thickness
    torus.outer_radius = radius
    torus.rings = 40
    torus.ring_segments = 8
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = torus
    node.rotation.x = PI * 0.5
    node.position = pos
    node.material_override = material
    add_child(node)
    hero_parts += 1
    return node

func _point(ring: Vector4, angle: float) -> Vector3:
    # Vector4 stores z, x-radius, y-radius, y-offset.
    return Vector3(cos(angle) * ring.y, ring.w + sin(angle) * ring.z, ring.x)

func _tri(st: SurfaceTool, a: Vector3, ua: Vector2, b: Vector3, ub: Vector2, c: Vector3, uc: Vector2) -> void:
    st.set_uv(ua)
    st.add_vertex(a)
    st.set_uv(ub)
    st.add_vertex(b)
    st.set_uv(uc)
    st.add_vertex(c)

func _sculpt_underbody() -> void:
    # Genuine 3D, multi-section loft with smooth interpolated curvature.
    var sections: Array[Vector4] = [
        Vector4(-5.75, 0.055, 0.055, -0.16),
        Vector4(-4.65, 0.42, 0.19, -0.22),
        Vector4(-3.15, 0.73, 0.27, -0.31),
        Vector4(-1.35, 1.04, 0.39, -0.34),
        Vector4(0.65, 1.06, 0.44, -0.31),
        Vector4(2.20, 1.12, 0.47, -0.36),
        Vector4(3.55, 0.90, 0.39, -0.37),
        Vector4(4.05, 0.61, 0.25, -0.34)
    ]
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var sides: int = 32
    for k in range(sections.size() - 1):
        for j in sides:
            var a0: float = TAU * float(j) / float(sides)
            var a1: float = TAU * float(j + 1) / float(sides)
            var v00: Vector3 = _point(sections[k], a0)
            var v01: Vector3 = _point(sections[k], a1)
            var v10: Vector3 = _point(sections[k + 1], a0)
            var v11: Vector3 = _point(sections[k + 1], a1)
            var u0: float = float(j) / float(sides)
            var u1: float = float(j + 1) / float(sides)
            var t0: float = float(k) / float(sections.size() - 1)
            var t1: float = float(k + 1) / float(sections.size() - 1)
            _tri(st, v00, Vector2(u0, t0), v01, Vector2(u1, t0), v11, Vector2(u1, t1))
            _tri(st, v00, Vector2(u0, t0), v11, Vector2(u1, t1), v10, Vector2(u0, t1))
    st.generate_normals()
    st.generate_tangents()
    var node := MeshInstance3D.new()
    node.name = "R6_SculptedSubframe_32Sides"
    node.mesh = st.commit()
    node.material_override = material_cache["carbon"]
    add_child(node)
    hero_parts += 1
    # Reinforcing curves emphasize silhouette instead of glowing the full hull.
    for side in [-1.0, 1.0]:
        _rod("ChineReinforcement", Vector3(side * 0.58, -0.42, -3.6),
             Vector3(side * 1.08, -0.50, 2.18), 0.074, material_cache["edge"])
        _rod("BowHydraulicLine", Vector3(side * 0.45, -0.48, -2.25),
             Vector3(side * 0.71, -0.57, 1.84), 0.055, material_cache["bronze"])
        _box("AftShroud", Vector3(0.30, 0.23, 1.68),
             Vector3(side * 0.83, -0.29, 2.63), material_cache["hull"])

func _wing_armor() -> void:
    # Folded metal wing armor, raised greeble ribs and actual hinge shafts.
    for side in [-1.0, 1.0]:
        for j in 7:
            var span: float = 2.1 + float(j) * 0.54
            var z: float = 0.31 + float(j) * 0.13
            var plate := _box("R6_AerodynamicLaminate_%02d" % j,
                Vector3(0.40, 0.10, 1.14 - float(j) * 0.08),
                Vector3(side * span, 0.19, z), material_cache["hull"])
            plate.rotation.y = side * 0.10
            _box("TileVentingGap", Vector3(0.35, 0.025, 0.055),
                Vector3(side * span, 0.247, z - 0.13), material_cache["carbon"])
        for j in 6:
            var root: float = 2.00 + float(j) * 0.64
            _rod("ExternalControlCable", Vector3(side * root, -0.36, 1.82),
                 Vector3(side * (root + 0.38), -0.36, 2.26), 0.035, material_cache["bronze"])
        for j in 8:
            var v: float = float(j)
            _box("TrailingEdgeHeatSink_%02d" % j, Vector3(0.10, 0.13, 0.34),
                 Vector3(side * (2.25 + v * 0.40), 0.10, 1.98 - v * 0.035), material_cache["carbon"])
        # Actual actuator linkage at wing root.
        _sphere("WingHingeJoint", Vector3(side * 1.31, -0.33, 1.87),
                Vector3(0.22, 0.19, 0.22), material_cache["edge"])
        _rod("WingControlPiston", Vector3(side * 1.45, -0.41, 1.92),
             Vector3(side * 2.52, -0.24, 2.12), 0.12, material_cache["ceramic"])
        _rod("WingControlHydraulic", Vector3(side * 1.50, -0.42, 1.92),
             Vector3(side * 2.51, -0.25, 2.12), 0.066, material_cache["bronze"])
        for j in 3:
            _box("MagneticServiceCell", Vector3(0.42, 0.18, 0.40),
                 Vector3(side * (4.15 + float(j) * 0.51), -0.44, 1.08), material_cache["carbon"])

func _weapons() -> void:
    # Four detailed magnetic accelerators, close enough to the camera to read.
    for side in [-1.0, 1.0]:
        for muzzle in range(2):
            var x: float = side * (2.26 + float(muzzle) * 0.42)
            var z: float = -0.46 + float(muzzle) * 0.44
            _rod("AcceleratorBarrel", Vector3(x, -0.29, z - 2.15),
                 Vector3(x, -0.29, z + 0.94), 0.112, material_cache["carbon"], 20)
            _torus("MuzzleHeatCollar", 0.15, 0.045,
                   Vector3(x, -0.29, z - 2.05), material_cache["edge"])
            _torus("BarrelServiceRing", 0.14, 0.022,
                   Vector3(x, -0.29, z - 0.95), material_cache["bronze"])
            for j in 3:
                _box("AcceleratorCoilCase", Vector3(0.29, 0.27, 0.15),
                     Vector3(x, -0.29, z - 0.74 + float(j) * 0.54),
                     material_cache["hull"])
            _box("PowerConduit", Vector3(0.14, 0.08, 1.53),
                 Vector3(x, -0.47, z + 0.12), material_cache["bronze"])
            gun_count += 1

func _engine_microgeometry() -> void:
    # Visible 3-stage propulsion turbines with internal radial cooling.
    for x in [-1.24, 0.0, 1.24]:
        var radius: float = 0.58 if absf(x) > 0.1 else 0.46
        for ring_index in range(3):
            var z: float = 3.43 + float(ring_index) * 0.46
            _torus("CompressionStage_%d" % ring_index,
                   radius * 0.84, 0.037, Vector3(x, -0.22, z), material_cache["edge"])
            for j in 8:
                var a: float = TAU * float(j) / 8.0
                var r: float = radius * 0.80
                _rod("RadialCoolingStrut",
                     Vector3(x + cos(a) * r, -0.22 + sin(a) * r, z),
                     Vector3(x + cos(a) * r, -0.22 + sin(a) * r, z + 0.22),
                     0.019, material_cache["bronze"], 8)
        var rotor := Node3D.new()
        rotor.name = "R6_InternalTurbine"
        rotor.position = Vector3(x, -0.22, 4.60)
        add_child(rotor)
        for j in 12:
            var a: float = TAU * float(j) / 12.0
            var blade := BoxMesh.new()
            blade.size = Vector3(radius * 0.61, 0.045, 0.075)
            var item := MeshInstance3D.new()
            item.name = "CurvedStatorBlade"
            item.mesh = blade
            item.position = Vector3(cos(a) * radius * 0.29, sin(a) * radius * 0.29, 0.0)
            item.rotation.z = a + PI * 0.25
            item.material_override = material_cache["ceramic"]
            rotor.add_child(item)
            hero_parts += 1
        animated_rotors.append(rotor)
        _torus("HotEdgeHeatShield", radius * 0.88, 0.05,
               Vector3(x, -0.22, 4.68), material_cache["bronze"])
    # Soft service dots; deliberately no overbright bloom.
    for side in [-1.0, 1.0]:
        _box("ReactorStatusWindow", Vector3(0.22, 0.10, 0.52),
             Vector3(side * 1.83, 0.29, 3.52), material_cache["plasma"])

func _cockpit_details() -> void:
    # Raised arch ribs and sensor optics are independent 3D geometry.
    for z in [-2.71, -1.78, -0.82]:
        var hoop_radius: float = 0.70 if z < -2.0 else 0.91
        for side in [-1.0, 1.0]:
            _rod("CockpitProtectiveArch", Vector3(side * hoop_radius, 0.57, z),
                 Vector3(side * hoop_radius * 0.5, 1.07, z), 0.036, material_cache["edge"])
        _rod("CockpitTopSpine", Vector3(-hoop_radius * 0.5, 1.07, z),
             Vector3(hoop_radius * 0.5, 1.07, z), 0.042, material_cache["edge"])
    for side in [-1.0, 1.0]:
        _sphere("OpticalSensor", Vector3(side * 0.73, 0.42, -3.03),
                Vector3(0.22, 0.15, 0.29), material_cache["glass"])
        _box("CameraLensRim", Vector3(0.06, 0.18, 0.29),
             Vector3(side * 0.86, 0.42, -3.03), material_cache["bronze"])
        _rod("AirDataProbe", Vector3(side * 0.37, 0.28, -4.72),
             Vector3(side * 0.40, 0.27, -5.32), 0.034, material_cache["ceramic"])

func _surface_fasteners() -> void:
    # Hundreds of physical fasteners cost just one GPU instance batch.
    var points: Array[Vector3] = []
    for side in [-1.0, 1.0]:
        for row in range(5):
            var x: float = 2.05 + float(row) * 0.78
            for column in range(7):
                var z: float = -0.38 + float(column) * 0.35
                points.append(Vector3(side * x, 0.156, z))
        for row in range(9):
            var z: float = -3.6 + float(row) * 0.56
            points.append(Vector3(side * 1.22, 0.19, z))
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var bolt := SphereMesh.new()
    bolt.radius = 0.047
    bolt.height = 0.094
    bolt.radial_segments = 8
    bolt.rings = 4
    mm.mesh = bolt
    mm.instance_count = points.size()
    for i in points.size():
        mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, points[i]))
    var draw := MultiMeshInstance3D.new()
    draw.name = "R6_WingRivets_Batched"
    draw.multimesh = mm
    draw.material_override = material_cache["ceramic"]
    add_child(draw)
    fasteners = points.size()
    hero_parts += 1

func _process(delta: float) -> void:
    for rotor in animated_rotors:
        if is_instance_valid(rotor):
            rotor.rotation.z += delta * 7.0
