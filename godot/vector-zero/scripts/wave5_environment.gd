extends Node3D
## Wave 5: independently authored GLB environment, tiled PBR floor and living machinery.
var game: Node3D
var rotors: Array[Node3D] = []
var warning_light: OmniLight3D
var time: float = 0.0
var decals: Node3D

func configure(origin: Node3D) -> void:
    game = origin

func _ready() -> void:
    _load_asset("coolant_skid", "CoolantSkidWest", Vector3(-11.8, 0.0, 1.2), 0.18)
    _load_asset("coolant_skid", "CoolantSkidEast", Vector3(11.8, 0.0, 1.2), -0.23)
    _load_asset("containment_vault", "ArmouredSafetyVault", Vector3(8.3, 0.0, -7.95), 0.0)
    _load_asset("service_gantry", "OverheadRoboticGantry", Vector3(0.0, 11.7, -5.9), 0.0)
    _apply_surface("MainDeck", 0.83, 0.43, Vector3(5.0, 4.0, 1.0))
    _apply_surface("RearWall", 0.81, 0.50, Vector3(5.0, 2.0, 1.0))
    _apply_surface("LeftWall", 0.81, 0.49, Vector3(4.0, 2.0, 1.0))
    _apply_surface("RightWall", 0.81, 0.49, Vector3(4.0, 2.0, 1.0))
    _build_rotors()
    warning_light = OmniLight3D.new()
    warning_light.name = "DynamicContainmentBeacon"
    warning_light.light_color = Color(1.0, 0.39, 0.17)
    warning_light.omni_range = 10.0
    warning_light.position = Vector3(0, 10.4, -3.8)
    add_child(warning_light)

func _load_asset(name: String, node_name: String, pos: Vector3, turn: float) -> void:
    var tier: String = "web" if OS.has_feature("web") else "ultra"
    var path: String = "res://assets/wave5/%s_%s.glb" % [name, tier]
    var packed: PackedScene = load(path) as PackedScene
    if packed == null:
        push_error("Missing Wave 5 environment model: " + path)
        return
    var model: Node3D = packed.instantiate() as Node3D
    model.name = node_name
    model.position = pos
    model.rotation.y = turn
    add_child(model)

func _apply_surface(node_name: String, metal: float, rough: float, uv_scale: Vector3) -> void:
    var mesh: MeshInstance3D = game.get_node_or_null(node_name) as MeshInstance3D
    if mesh == null:
        return
    var mat := StandardMaterial3D.new()
    mat.albedo_texture = load("res://assets/wave5/surfaces/panel_albedo.png")
    mat.metallic = metal
    mat.roughness = rough
    mat.roughness_texture = load("res://assets/wave5/surfaces/panel_roughness.png")
    mat.normal_enabled = true
    mat.normal_texture = load("res://assets/wave5/surfaces/panel_normal.png")
    mat.normal_scale = 0.65
    mat.uv1_scale = uv_scale
    mesh.material_override = mat

func _build_rotors() -> void:
    for i in range(2):
        var rotor := Node3D.new()
        rotor.name = "VentilationRotor_%d" % i
        rotor.position = Vector3(-11.85 if i == 0 else 11.85, 3.1, 2.15)
        for blade_index in range(7):
            var blade := MeshInstance3D.new()
            blade.name = "TitaniumImpeller"
            var cube := BoxMesh.new()
            cube.size = Vector3(0.14, 0.08, 0.9)
            blade.mesh = cube
            blade.position = Vector3(sin(float(blade_index) * TAU / 7.0) * 0.41, 0.0, cos(float(blade_index) * TAU / 7.0) * 0.41)
            blade.rotation.y = float(blade_index) * TAU / 7.0
            var mat := StandardMaterial3D.new()
            mat.albedo_color = Color(0.71, 0.76, 0.76)
            mat.metallic = 0.82
            mat.roughness = 0.23
            blade.material_override = mat
            rotor.add_child(blade)
        add_child(rotor)
        rotors.append(rotor)

func _process(delta: float) -> void:
    time += delta
    for i in range(rotors.size()):
        rotors[i].rotate_y(delta * (2.5 + 0.25 * float(i)))
    if warning_light != null:
        warning_light.light_energy = 0.7 + 0.55 * (0.5 + 0.5 * sin(time * 2.9))