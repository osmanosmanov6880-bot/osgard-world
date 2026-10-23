extends Node3D
## Wave 6 CHRONOS — premium modular city surfaces, silhouettes and subtle traffic.
## All objects are authored in game scene, independent of existing economy/save.

var game: Node3D
var shuttles: Array[Node3D] = []
var materials: Dictionary = {}
var focus_light: OmniLight3D
var elapsed: float = 0.0
var web: bool = false

func configure(origin: Node3D) -> void:
    game = origin

func _make_pbr(name: String, metal: float, rough: float, tiling: Vector3) -> StandardMaterial3D:
    var base := "res://assets/wave6/%s/" % name
    var m := StandardMaterial3D.new()
    m.albedo_texture = load(base + "albedo.png")
    m.normal_enabled = true
    m.normal_texture = load(base + "normal.png")
    m.normal_scale = 0.37
    m.metallic = metal
    m.metallic_texture = load(base + "metallic.png")
    m.roughness = rough
    m.roughness_texture = load(base + "roughness.png")
    m.uv1_triplanar = true
    m.uv1_scale = tiling
    return m

func _solid(color: Color, metal: float, rough: float, emission: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metal
    m.roughness = rough
    if emission > 0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = emission
    return m

func _box(parent: Node3D, name_of_mesh: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name_of_mesh
    var box := BoxMesh.new()
    box.size = size
    node.mesh = box
    node.position = pos
    node.material_override = material
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, name_of_mesh: String, radius: float, height: float, place: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name_of_mesh
    var cylinder := CylinderMesh.new()
    cylinder.top_radius = radius
    cylinder.bottom_radius = radius
    cylinder.height = height
    cylinder.radial_segments = 24 if not web else 10
    node.mesh = cylinder
    node.position = place
    node.material_override = material
    parent.add_child(node)
    return node

func _ready() -> void:
    web = OS.has_feature("web")
    materials["stone"] = _make_pbr("civic_stone", 0.07, 0.74, Vector3(3.5, 3.5, 3.5))
    materials["titanium"] = _make_pbr("titanium_facade", 0.79, 0.42, Vector3(3.2, 3.2, 3.2))
    materials["bronze"] = _make_pbr("bronze_concourse", 0.70, 0.45, Vector3(2.6, 2.6, 2.6))
    materials["glass"] = _solid(Color(0.17, 0.29, 0.34), 0.25, 0.16)
    materials["glow"] = _solid(Color(0.58, 0.87, 0.98), 0.10, 0.21, 1.1)
    _apply_surface("LivingCity/CitySurface", materials["stone"])
    _apply_surface("LivingCity/CityFoundation", materials["titanium"])
    _build_transit_arcade()
    _build_garden_atriums()
    _build_civic_hubs()
    _build_animated_metro()
    focus_light = OmniLight3D.new()
    focus_light.name = "ChronoSpireBounce"
    focus_light.position = Vector3(0.0, 12.4, 0.0)
    focus_light.light_color = Color(0.68, 0.84, 1.0)
    focus_light.light_energy = 1.0
    focus_light.omni_range = 24.0
    add_child(focus_light)
    var env: WorldEnvironment = game.get_node_or_null("ChronosAtmosphere") as WorldEnvironment
    if env != null:
        env.environment.reflected_light_source = Environment.REFLECTION_SOURCE_SKY

func _apply_surface(path: String, material: Material) -> void:
    var target: MeshInstance3D = game.get_node_or_null(path) as MeshInstance3D
    if target != null:
        target.material_override = material

func _build_transit_arcade() -> void:
    # Elevated line lies behind the reactor, rather than obstructing play area.
    var skyway := Node3D.new()
    skyway.name = "CivicSkyway"
    skyway.position = Vector3(0.0, 0.0, -20.0)
    add_child(skyway)
    _box(skyway, "ElevatedPromenade", Vector3(43.0, 0.26, 2.15), Vector3(0.0, 5.55, 0.0), materials["titanium"])
    _box(skyway, "TransparentSafetyRailA", Vector3(43.0, 0.13, 0.09), Vector3(0.0, 6.50, 1.0), materials["glass"])
    _box(skyway, "TransparentSafetyRailB", Vector3(43.0, 0.13, 0.09), Vector3(0.0, 6.50, -1.0), materials["glass"])
    for ix in range(-9, 10):
        var x := float(ix) * 2.22
        _box(skyway, "CivicStructuralArch", Vector3(0.16, 5.30, 1.86), Vector3(x, 2.82, 0.0), materials["stone"])
        _box(skyway, "GuardrailRiser", Vector3(0.12, 0.83, 0.16), Vector3(x, 6.04, 0.98), materials["bronze"])
        if ix % 2 == 0:
            _box(skyway, "MetroGuideIllumination", Vector3(0.38, 0.09, 0.72), Vector3(x, 5.75, -0.79), materials["glow"])

func _build_garden_atriums() -> void:
    # Human-scale greenery and seating provide material and shape contrast.
    for i in range(6):
        var phi := float(i) * TAU / 6.0 + 0.39
        var distance := 16.2
        var position := Vector3(cos(phi) * distance, 0.5, sin(phi) * distance)
        var garden := Node3D.new()
        garden.name = "VerticalGarden_%02d" % i
        garden.position = position
        add_child(garden)
        _cylinder(garden, "CastStonePlanter", 1.18, 0.52, Vector3(0, 0.2, 0), materials["stone"])
        _cylinder(garden, "CoreSupport", 0.18, 3.15, Vector3(0, 2.05, 0), materials["bronze"])
        for level in range(3):
            var canopy := MeshInstance3D.new()
            canopy.name = "GardenCanopy"
            var shape := SphereMesh.new()
            shape.radius = 0.72 if level == 0 else 0.62
            shape.height = 0.75
            shape.radial_segments = 24 if not web else 12
            shape.rings = 10 if not web else 5
            canopy.mesh = shape
            canopy.position = Vector3(0.0, 1.4 + float(level) * 0.65, 0.0)
            canopy.material_override = _solid(Color(0.19 + float(i % 3) * 0.035, 0.38, 0.31), 0.02, 0.91)
            garden.add_child(canopy)

func _build_civic_hubs() -> void:
    for i in range(2):
        var hall := Node3D.new()
        hall.name = "SculptedCivicHall_%02d" % i
        hall.position = Vector3(-19.6 if i == 0 else 19.5, 0.30, -4.8 if i == 0 else -7.4)
        add_child(hall)
        _box(hall, "MultiLayerFoundation", Vector3(5.20, 0.65, 4.40), Vector3(0, 0.35, 0), materials["bronze"])
        _box(hall, "LithicLobby", Vector3(3.60, 3.25, 2.95), Vector3(0, 2.25, 0), materials["stone"])
        _box(hall, "CurtainWall", Vector3(3.0, 2.15, 0.075), Vector3(0, 2.18, 1.55), materials["glass"])
        _box(hall, "CantileverRoof", Vector3(5.5, 0.35, 3.80), Vector3(0, 4.08, 0.0), materials["titanium"])
        for index in range(5):
            var x: float = -2.0 + float(index) * 1.0
            _box(hall, "CivicFacadeMullion", Vector3(0.085, 2.35, 0.14), Vector3(x, 2.15, 1.64), materials["bronze"])
        _box(hall, "RoofLightbox", Vector3(4.5, 0.055, 0.31), Vector3(0.0, 4.29, 1.55), materials["glow"])

func _build_animated_metro() -> void:
    for i in range(2):
        var tram := Node3D.new()
        tram.name = "AnimatedMetroShuttle_%02d" % i
        add_child(tram)
        _box(tram, "AluminiumShell", Vector3(2.35, 0.77, 0.76), Vector3.ZERO, materials["titanium"])
        _box(tram, "CockpitGlazing", Vector3(0.92, 0.36, 0.80), Vector3(0.36, 0.36, 0.0), materials["glass"])
        _box(tram, "UnderbodyEmissive", Vector3(1.86, 0.06, 0.36), Vector3(0, -0.34, 0), materials["glow"])
        shuttles.append(tram)

func _process(delta: float) -> void:
    elapsed += delta
    for index in range(shuttles.size()):
        var phase := elapsed * (0.14 + float(index) * 0.06) + float(index) * PI
        # Deterministic figure-eight traffic, physically visible in camera view.
        shuttles[index].position = Vector3(sin(phase) * 19.0, 6.3, -20.0 + sin(2.0 * phase) * 0.32)
        shuttles[index].rotation.y = 0.0 if cos(phase) > 0.0 else PI
    if focus_light != null:
        focus_light.light_energy = 0.95 + 0.13 * sin(elapsed * 0.42)