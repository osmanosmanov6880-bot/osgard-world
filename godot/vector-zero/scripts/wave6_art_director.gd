extends Node3D
## Wave 6 BLACKFIELD — new camera-visible authored industrial modules and calibrated PBR.
## Node identity remains stable for QA. Gameplay colliders are deliberately untouched.

var game: Node3D
var fans: Array[Node3D] = []
var magnet_rails: Array[Node3D] = []
var alert_light: OmniLight3D
var warm_material: StandardMaterial3D
var cool_material: StandardMaterial3D
var mat_steel: StandardMaterial3D
var mat_floor: StandardMaterial3D
var mat_ceramic: StandardMaterial3D
var t: float = 0.0
var observed_polarity: int = 1
var is_web: bool = false

func configure(origin: Node3D) -> void:
    game = origin

func _pbr(name: String, rough: float, metallic: float, tiling: Vector3) -> StandardMaterial3D:
    var base := "res://assets/wave6/%s/" % name
    var material := StandardMaterial3D.new()
    material.albedo_texture = load(base + "albedo.png")
    material.normal_enabled = true
    material.normal_texture = load(base + "normal.png")
    material.normal_scale = 0.85
    material.metallic = metallic
    material.metallic_texture = load(base + "metallic.png")
    material.roughness = rough
    material.roughness_texture = load(base + "roughness.png")
    material.uv1_triplanar = true
    material.uv1_scale = tiling
    return material

func _solid(color: Color, metallic: float, rough: float, emission: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = rough
    if emission > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = emission
    return m

func _box(parent: Node3D, label: String, size: Vector3, place: Vector3, material: Material) -> MeshInstance3D:
    var box := MeshInstance3D.new()
    box.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    box.mesh = mesh
    box.position = place
    box.material_override = material
    box.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    parent.add_child(box)
    return box

func _pipe(parent: Node3D, label: String, place: Vector3, radius: float, height: float, material: Material, axis: int = 1) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    m.name = label
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 24 if not is_web else 10
    m.mesh = mesh
    m.material_override = material
    m.position = place
    if axis == 0:
        m.rotation_degrees.z = 90.0
    elif axis == 2:
        m.rotation_degrees.x = 90.0
    parent.add_child(m)
    return m

func _torus(parent: Node3D, label: String, radius: float, section: float, place: Vector3, material: Material) -> MeshInstance3D:
    var m := MeshInstance3D.new()
    m.name = label
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius
    mesh.outer_radius = radius + section
    mesh.rings = 52 if not is_web else 20
    mesh.ring_segments = 12 if not is_web else 6
    m.mesh = mesh
    m.position = place
    m.rotation_degrees.x = 90.0
    m.material_override = material
    parent.add_child(m)
    return m

func _ready() -> void:
    is_web = OS.has_feature("web")
    mat_steel = _pbr("machined_steel", 0.43, 0.85, Vector3(2.6, 2.6, 2.6))
    mat_floor = _pbr("hazard_deck", 0.53, 0.66, Vector3(2.3, 2.3, 2.3))
    mat_ceramic = _pbr("ceramic_guard", 0.38, 0.26, Vector3(1.8, 1.8, 1.8))
    warm_material = _solid(Color(1.0, 0.55, 0.23), 0.20, 0.19, 1.55)
    cool_material = _solid(Color(0.27, 0.83, 1.0), 0.24, 0.18, 1.1)
    var floor: MeshInstance3D = game.get_node_or_null("MainDeck") as MeshInstance3D
    if floor != null:
        floor.material_override = mat_floor
    var back: MeshInstance3D = game.get_node_or_null("RearWall") as MeshInstance3D
    if back != null:
        back.material_override = mat_steel
    _build_side_towers()
    _build_observation_gallery()
    _build_reactive_magnet()
    _build_ground_wayfinding()
    alert_light = OmniLight3D.new()
    alert_light.name = "ResponsiveIndustrialAreaLight"
    alert_light.position = Vector3(0.0, 10.0, -5.8)
    alert_light.light_color = Color(0.90, 0.64, 0.44)
    alert_light.omni_range = 17.0
    alert_light.light_energy = 0.85
    add_child(alert_light)

func _build_side_towers() -> void:
    var graphite := _solid(Color(0.12, 0.19, 0.24), 0.72, 0.47)
    for side in [-1, 1]:
        var assembly := Node3D.new()
        assembly.name = "CNCServiceTower_Left" if side < 0 else "CNCServiceTower_Right"
        assembly.position = Vector3(float(side) * 12.1, 0.0, -3.35)
        add_child(assembly)
        _box(assembly, "ReactorBackbone", Vector3(2.35, 9.7, 2.55), Vector3(0, 5.0, 0), mat_steel)
        _box(assembly, "MilledCeramicShield", Vector3(2.55, 3.45, 0.24), Vector3(0, 7.35, 1.4), mat_ceramic)
        _box(assembly, "ReinforcedFooting", Vector3(3.2, 0.70, 3.45), Vector3(0, 0.34, 0), graphite)
        _pipe(assembly, "MainCoolantConduit", Vector3(0.0, 5.2, 1.52), 0.25, 8.2, cool_material)
        _pipe(assembly, "PressureReturn", Vector3(-0.65, 5.2, 1.48), 0.13, 7.5, graphite)
        _pipe(assembly, "PressureFeed", Vector3(0.65, 5.2, 1.48), 0.13, 7.5, graphite)
        for y in range(2, 9):
            for x in [-0.90, 0.9]:
                _box(assembly, "HeatSink_Rib", Vector3(0.22, 0.075, 1.48), Vector3(x, float(y) + 0.17, 1.10), mat_steel)
        var rotor := Node3D.new()
        rotor.name = "VariablePitchCoolingRotor"
        rotor.position = Vector3(0.0, 5.15, 1.83)
        assembly.add_child(rotor)
        _torus(rotor, "BearingRing", 0.75, 0.14, Vector3.ZERO, graphite)
        for i in range(7):
            var blade := _box(rotor, "VariablePitchTitaniumBlade", Vector3(0.15, 0.075, 0.72), Vector3(0.0, 0.0, 0.45), mat_steel)
            blade.rotation.z = float(i) * TAU / 7.0
            blade.position = Vector3(cos(blade.rotation.z) * 0.46, sin(blade.rotation.z) * 0.46, 0.0)
        fans.append(rotor)
        # Wall conduits form visible physical depth instead of texture-only props.
        _pipe(assembly, "HorizontalBusBar", Vector3(0.0, 9.0, 0.0), 0.17, 3.2, graphite, 0)

func _build_observation_gallery() -> void:
    var iron := _solid(Color(0.39, 0.48, 0.51), 0.87, 0.28)
    for x in [-10.1, -6.1, -2.1, 2.1, 6.1, 10.1]:
        var panel := Node3D.new()
        panel.name = "MaintenanceBulkhead_%02d" % int(round(x + 11.0))
        panel.position = Vector3(x, 0, -7.68)
        add_child(panel)
        _box(panel, "SuspensionFrame", Vector3(2.1, 3.0, 0.21), Vector3(0.0, 8.85, 0.0), iron)
        _box(panel, "DiagnosticInset", Vector3(1.64, 2.5, 0.12), Vector3(0.0, 8.90, 0.14), mat_ceramic)
        _box(panel, "LowProfileLED", Vector3(1.7, 0.04, 0.09), Vector3(0.0, 7.9, 0.22), cool_material)
        for yy in [8.05, 8.9, 9.75]:
            _box(panel, "FramedReinforcement", Vector3(1.78, 0.035, 0.18), Vector3(0.0, yy, 0.20), mat_steel)

func _build_reactive_magnet() -> void:
    var magnet: Node3D = game.get_node_or_null("MagnetAssembly") as Node3D
    if magnet == null:
        return
    var ambient := Node3D.new()
    ambient.name = "Wave6ReactiveFieldHousing"
    magnet.add_child(ambient)
    for i in range(2):
        var ring := _torus(ambient, "PhotonicContainmentBand", 1.78 + i * 0.22, 0.045, Vector3(0.0, 0.0, -0.9 - i * 0.10), cool_material)
        magnet_rails.append(ring)
    for i in range(8):
        var angle: float = float(i) * TAU / 8.0
        _box(ambient, "CeramicMagneticCapacitor", Vector3(0.14, 0.25, 0.38), Vector3(cos(angle) * 2.00, sin(angle) * 2.00, -0.92), mat_ceramic)

func _build_ground_wayfinding() -> void:
    var guard := _solid(Color(0.70, 0.54, 0.24), 0.30, 0.55)
    for x in range(-10, 11, 2):
        _box(self, "DeckAmberLaneMarker", Vector3(0.65, 0.013, 0.10), Vector3(float(x), 0.0, 6.35), guard)
    for x in [-9.7, 9.7]:
        _box(self, "EquipmentCurb", Vector3(0.18, 0.08, 10.0), Vector3(x, 0.02, -1.1), guard)

func _process(delta: float) -> void:
    t += delta
    for i in range(fans.size()):
        fans[i].rotate_z(delta * (1.2 + 0.15 * float(i)))
    for ring in magnet_rails:
        ring.rotate_z(delta * 0.10)
    var sign: int = int(game.get("polarity"))
    if sign != observed_polarity:
        observed_polarity = sign
        cool_material.emission = Color(0.37, 0.81, 1.0) if sign > 0 else Color(1.0, 0.44, 0.24)
    if alert_light != null:
        alert_light.light_energy = 0.73 + 0.19 * sin(t * 1.9)