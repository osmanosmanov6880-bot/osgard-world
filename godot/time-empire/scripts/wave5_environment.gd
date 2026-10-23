extends Node3D
## Wave 5: landmark silhouettes, transit infrastructure, PBR roads, animated energy.
var game: Node3D
var antennae: Array[Node3D] = []
var station_beacon: OmniLight3D
var elapsed: float = 0.0
var reactor_halo: Node3D

func configure(parent_game: Node3D) -> void:
    game = parent_game

func _ready() -> void:
    _instance("arcology_cluster", "ArcologyNorthernCrown", Vector3(-19.8, 0.5, -12.8), 0.38)
    _instance("arcology_cluster", "ArcologySouthernCrown", Vector3(19.5, 0.5, 11.0), -0.41)
    _instance("transit_concourse", "MetroInterchange", Vector3(0.0, 0.42, -22.2), 0.06)
    _instance("solar_substation", "SolarResearchFarm", Vector3(-22.0, 0.40, 3.4), 0.4)
    _set_material("LivingCity/CitySurface", 0.61, 0.52, Vector3(9, 9, 1))
    _set_material("LivingCity/CityFoundation", 0.71, 0.49, Vector3(6, 4, 1))
    _construct_reactor_finials()
    station_beacon = OmniLight3D.new()
    station_beacon.name = "AnimatedMetroBeacon"
    station_beacon.position = Vector3(0.0, 5.5, -22.0)
    station_beacon.light_color = Color(0.53, 0.9, 1.0)
    station_beacon.omni_range = 10.0
    add_child(station_beacon)

func _instance(asset: String, name_of_node: String, place: Vector3, yaw: float) -> void:
    var tier := "web" if OS.has_feature("web") else "ultra"
    var path: String = "res://assets/wave5/%s_%s.glb" % [asset, tier]
    var packed := load(path) as PackedScene
    if packed == null:
        push_error("Unable to import Wave 5 city asset: " + path)
        return
    var model := packed.instantiate() as Node3D
    model.name = name_of_node
    model.position = place
    model.rotation.y = yaw
    add_child(model)

func _set_material(location: String, metal: float, rough: float, uv_scale: Vector3) -> void:
    var target: MeshInstance3D = game.get_node_or_null(location) as MeshInstance3D
    if target == null:
        return
    var material := StandardMaterial3D.new()
    material.albedo_texture = load("res://assets/wave5/surfaces/panel_albedo.png")
    material.metallic = metal
    material.roughness = rough
    material.roughness_texture = load("res://assets/wave5/surfaces/panel_roughness.png")
    material.normal_enabled = true
    material.normal_texture = load("res://assets/wave5/surfaces/panel_normal.png")
    material.normal_scale = 0.52
    material.uv1_scale = uv_scale
    target.material_override = material

func _construct_reactor_finials() -> void:
    reactor_halo = Node3D.new()
    reactor_halo.name = "IndependentReactorPulse"
    reactor_halo.position = Vector3(0, 6.5, 0)
    add_child(reactor_halo)
    for i in range(3):
        var mount := Node3D.new()
        mount.name = "FloatingInstrumentRing_%d" % i
        mount.rotation_degrees = Vector3(20.0 + i * 19.0, 45.0 * i, 0.0)
        var torus := TorusMesh.new()
        torus.inner_radius = 3.35 + i * 0.22
        torus.outer_radius = torus.inner_radius + 0.09
        torus.rings = 60 if not OS.has_feature("web") else 24
        torus.ring_segments = 12
        var mesh := MeshInstance3D.new()
        mesh.mesh = torus
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color(0.55, 0.67, 0.71)
        mat.metallic = 0.89
        mat.roughness = 0.23
        mount.add_child(mesh)
        reactor_halo.add_child(mount)
        antennae.append(mount)

func _process(delta: float) -> void:
    elapsed += delta
    for i in range(antennae.size()):
        antennae[i].rotate_y(delta * (0.13 + 0.06 * i))
        antennae[i].rotate_x(delta * 0.025 * (1.0 + i))
    if station_beacon != null:
        station_beacon.light_energy = 1.1 + 0.5 * sin(elapsed * 3.0)