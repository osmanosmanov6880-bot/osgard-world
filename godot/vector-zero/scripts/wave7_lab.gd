extends Node3D
## BLACKFIELD WAVE 7 / custom indexed precision hardware, cinematic lighting.
## Gameplay collider, magnetic integrator and saved puzzle state are untouched.

var game: Node3D
var web: bool = false
var elapsed: float = 0.0
var copper_mat: StandardMaterial3D
var graphite_mat: StandardMaterial3D
var ceramic_mat: StandardMaterial3D
var amber_mat: StandardMaterial3D
var pulse_mat: StandardMaterial3D
var induction: Node3D
var reactor_lights: Array[OmniLight3D] = []
var servo_roots: Array[Node3D] = []
var helix_triangles: int = 0

func configure(origin: Node3D) -> void:
    game = origin

func _ready() -> void:
    web = OS.has_feature("web") or RenderingServer.get_current_rendering_method() != "forward_plus"
    copper_mat = _mat(Color(0.68, 0.38, 0.19), 0.93, 0.25)
    graphite_mat = _mat(Color(0.085, 0.13, 0.17), 0.81, 0.35)
    ceramic_mat = _mat(Color(0.58, 0.66, 0.70), 0.33, 0.31)
    amber_mat = _mat(Color(0.93, 0.61, 0.27), 0.34, 0.30, 1.05)
    pulse_mat = _mat(Color(0.28, 0.76, 0.98), 0.22, 0.18, 1.25)
    _cinematic_lighting()
    _precision_inductor()
    _service_consoles()
    _reactive_power_gantry()
    _lighting_glyphs()
    print("OSGARD_WAVE7_BLACKFIELD: ", JSON.stringify({"helix_triangles":helix_triangles,"service_subassemblies":2,"web_lod":web}))

func _mat(tint: Color, metal: float, rough: float, emissive: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = tint
    material.metallic = metal
    material.roughness = rough
    material.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
    material.metallic_specular = 0.65
    if emissive > 0.0:
        material.emission_enabled = true
        material.emission = tint
        material.emission_energy_multiplier = emissive
    return material

func _box(parent: Node3D, label: String, size: Vector3, origin: Vector3, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var cube := BoxMesh.new()
    cube.size = size
    node.mesh = cube
    node.position = origin
    node.material_override = mat
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, label: String, radius: float, height: float, origin: Vector3, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = height
    cylinder.radial_segments = 14 if web else 32
    node.mesh = cylinder
    node.position = origin
    node.material_override = mat
    parent.add_child(node)
    return node

func _torus(parent: Node3D, label: String, radius: float, section: float, origin: Vector3, mat: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius
    mesh.outer_radius = radius + section
    mesh.rings = 30 if web else 72
    mesh.ring_segments = 8 if web else 16
    node.mesh = mesh
    node.position = origin
    node.material_override = mat
    parent.add_child(node)
    return node

func _helix_sample(turn_progress: float, around: float, major: float, length: float, radius: float, turns: float, offset: float) -> Vector3:
    var phase: float = turn_progress * turns * TAU + offset
    var axis := Vector3(-sin(phase) * major * turns * TAU, length, cos(phase) * major * turns * TAU).normalized()
    var radial := Vector3(cos(phase), 0.0, sin(phase))
    var binormal: Vector3 = axis.cross(radial).normalized()
    var center := Vector3(cos(phase) * major, -length * 0.5 + turn_progress * length, sin(phase) * major)
    return center + radial * (cos(around) * radius) + binormal * (sin(around) * radius)

func _indexed_induction_helix(label: String, major: float, length: float, coil_turns: float, phase: float, material: Material) -> MeshInstance3D:
    var longitudinal: int = 128 if web else 350
    var radial_segments: int = 7 if web else 14
    var verts := PackedVector3Array()
    var normals := PackedVector3Array()
    var uv := PackedVector2Array()
    var idx := PackedInt32Array()
    for i in range(longitudinal + 1):
        var u: float = float(i) / float(longitudinal)
        var angle: float = u * coil_turns * TAU + phase
        var side := Vector3(cos(angle), 0.0, sin(angle))
        var tangent := Vector3(-sin(angle) * major * coil_turns * TAU, length, cos(angle) * major * coil_turns * TAU).normalized()
        var binormal: Vector3 = tangent.cross(side).normalized()
        for j in range(radial_segments + 1):
            var v: float = float(j) / float(radial_segments)
            var theta := v * TAU
            var direction: Vector3 = (side * cos(theta) + binormal * sin(theta)).normalized()
            var p: Vector3 = _helix_sample(u, theta, major, length, 0.09 if web else 0.095, coil_turns, phase)
            verts.append(p)
            normals.append(direction)
            uv.append(Vector2(u * coil_turns, v))
    for i in range(longitudinal):
        for j in range(radial_segments):
            var first: int = i * (radial_segments + 1) + j
            var second: int = first + radial_segments + 1
            idx.append_array(PackedInt32Array([first, second, first + 1, first + 1, second, second + 1]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = verts
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_INDEX] = idx
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = mesh
    part.material_override = material
    part.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    helix_triangles += idx.size() / 3
    return part

func _precision_inductor() -> void:
    var magnet: Node3D = game.get_node_or_null("MagnetAssembly") as Node3D
    if magnet == null:
        return
    induction = Node3D.new()
    induction.name = "Wave7PrecisionInductor"
    magnet.add_child(induction)
    var double_helix := Node3D.new()
    double_helix.name = "DuplexInductionWindings"
    induction.add_child(double_helix)
    double_helix.add_child(_indexed_induction_helix("CNCContinuousCopperA", 1.72, 4.05, 8.5, 0.0, copper_mat))
    double_helix.add_child(_indexed_induction_helix("CNCContinuousCopperB", 1.87, 4.05, 8.5, PI, copper_mat))
    for y in [-2.35, -1.22, 1.25, 2.35]:
        _torus(induction, "CeramicInsulationBearing", 1.94, 0.12, Vector3(0.0, y, 0.0), ceramic_mat)
    for k in range(10):
        var azimuth: float = float(k) * TAU / 10.0
        var anchor := Vector3(cos(azimuth) * 2.20, 0.0, sin(azimuth) * 2.20)
        _box(induction, "TitaniumMagnetClamper", Vector3(0.17, 4.25, 0.33), anchor, graphite_mat).rotation.y = -azimuth
        for y in [-2.08, 2.08]:
            _box(induction, "InductorLockingShoe", Vector3(0.45, 0.20, 0.43), anchor + Vector3(0, y, 0), ceramic_mat)
    var rotor := Node3D.new()
    rotor.name = "Wave7FluxRotor"
    induction.add_child(rotor)
    _torus(rotor, "EmissiveArcCollector", 2.49, 0.045, Vector3(0.0, 0.0, 0.0), pulse_mat)
    _torus(rotor, "OuterRadialFluxHousing", 2.58, 0.115, Vector3(0.0, 0.0, 0.0), graphite_mat)
    servo_roots.append(rotor)

func _service_consoles() -> void:
    # Four physical service bays provide strong, readable foreground silhouettes.
    for side in [-1, 1]:
        var bay := Node3D.new()
        bay.name = "HydraulicServiceBay_West" if side < 0 else "HydraulicServiceBay_East"
        bay.position = Vector3(float(side) * 11.5, 0.0, -3.85)
        add_child(bay)
        _box(bay, "DieCastLowerChassis", Vector3(2.5, 2.1, 3.0), Vector3(0, 1.05, 0), graphite_mat)
        _box(bay, "CNCOuterMantle", Vector3(2.35, 1.3, 0.18), Vector3(0, 2.55, 1.52), ceramic_mat)
        for n in range(6):
            var px: float = -0.85 + float(n % 3) * 0.86
            var py: float = 1.25 + float(n / 3) * 0.56
            _box(bay, "MachinedIntakeVane", Vector3(0.52, 0.06, 0.65), Vector3(px, py, 1.65), graphite_mat)
        for p in [-0.63, 0.63]:
            _cylinder(bay, "HighPressureThermalPipe", 0.16, 3.45, Vector3(p, 3.9, 0.55), copper_mat)
            _cylinder(bay, "PressureJunction", 0.27, 0.21, Vector3(p, 5.48, 0.55), ceramic_mat)
        _box(bay, "WarmDiagnosticMonitor", Vector3(1.72, 0.55, 0.10), Vector3(0.0, 2.6, 1.66), amber_mat)
        _box(bay, "DieCastCanopy", Vector3(2.8, 0.22, 3.3), Vector3(0, 5.88, 0.0), graphite_mat)

func _reactive_power_gantry() -> void:
    var mezzanine := Node3D.new()
    mezzanine.name = "OverheadPowerSpine"
    add_child(mezzanine)
    _box(mezzanine, "StructuralBelt", Vector3(22.8, 0.62, 1.22), Vector3(0, 11.65, -3.6), graphite_mat)
    _box(mezzanine, "CopperMainBusBar", Vector3(20.6, 0.25, 0.32), Vector3(0, 10.99, -3.03), copper_mat)
    for n in range(-5, 6):
        var x: float = float(n) * 2.0
        _box(mezzanine, "StainlessTrussCrossbar", Vector3(0.18, 1.75, 1.7), Vector3(x, 11.60, -3.56), ceramic_mat)
        if n % 2 == 0:
            var assembly := Node3D.new()
            assembly.name = "ArticulatedHighVoltageInsulator_%02d" % (n + 6)
            assembly.position = Vector3(x, 10.43, -2.8)
            mezzanine.add_child(assembly)
            _cylinder(assembly, "PowerCoupler", 0.16, 0.50, Vector3.ZERO, ceramic_mat)
            _torus(assembly, "PowerWarning", 0.29, 0.065, Vector3(0.0, -0.28, 0.0), amber_mat)
    var softlight := SpotLight3D.new()
    softlight.name = "CopperSpineBounce"
    softlight.position = Vector3(4.5, 11.4, 5.5)
    softlight.light_color = Color(1.0, 0.72, 0.47)
    softlight.light_energy = 1.45
    softlight.spot_range = 16.0
    softlight.spot_angle = 62.0
    softlight.shadow_enabled = not web
    mezzanine.add_child(softlight)
    softlight.look_at(Vector3(3.5, 4.2, -2.0))

func _cinematic_lighting() -> void:
    var world: WorldEnvironment = game.get_node_or_null("CinematicEnvironment") as WorldEnvironment
    if world != null and world.environment != null:
        var env := world.environment
        env.adjustment_enabled = true
        env.adjustment_contrast = 1.065
        env.adjustment_saturation = 0.98
        env.fog_density = 0.0026
        env.glow_intensity = 0.20
    for side in [-1.0, 1.0]:
        var local_light := OmniLight3D.new()
        local_light.name = "Wave7CinematicRim"
        local_light.position = Vector3(6.6 * side, 8.2, 2.8)
        local_light.omni_range = 12.0
        local_light.light_energy = 0.85
        local_light.light_color = Color(1.0, 0.68, 0.46)
        add_child(local_light)
        reactor_lights.append(local_light)

func _lighting_glyphs() -> void:
    var pat := _mat(Color(0.79, 0.61, 0.29), 0.20, 0.48)
    for x in [-7.7, -4.3, 0.0, 4.3, 7.7]:
        _box(self, "FloorSafetyChevrons", Vector3(0.45, 0.012, 0.16), Vector3(x, 0.022, 5.78), pat)
    # Camera-readable labeling lives on the 3D gantry, not the gameplay HUD.
    var nameplate := Label3D.new()
    nameplate.name = "ServiceIdentification"
    nameplate.text = "F A C I L I T Y    0 7  /  H I G H  V O L T A G E"
    nameplate.font_size = 48
    nameplate.pixel_size = 0.0035
    nameplate.position = Vector3(0, 12.02, -2.85)
    nameplate.modulate = Color(0.95, 0.82, 0.58)
    nameplate.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    add_child(nameplate)

func _process(delta: float) -> void:
    elapsed += minf(delta, 0.20)
    for rotor in servo_roots:
        rotor.rotate_y(delta * 0.25 * float(int(game.get("polarity"))))
    for i in range(reactor_lights.size()):
        reactor_lights[i].light_energy = 0.77 + 0.12 * sin(elapsed * 0.65 + float(i) * 1.31)
    if pulse_mat != null:
        pulse_mat.emission = Color(0.30, 0.76, 1.0) if int(game.get("polarity")) > 0 else Color(1.0, 0.51, 0.23)
