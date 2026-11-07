extends Node3D
## R64: three genuine MeshInstance3D inspection lights with separate materials.
## Shared by the REAL player aircraft and the separate Godot garage viewport.
const ServiceR64 = preload("res://scripts/airframe_service_r64.gd")
const CHANNELS := ["engine", "controls", "plating"]
var current_hull: String = "ship_scout"
var current_row: Dictionary = ServiceR64.fresh()
var lenses: Dictionary = {}
var bezels: Dictionary = {}
var status_materials: Dictionary = {}
var actual_updates: int = 0

func _ready() -> void:
    name = "R64_ActualAirframeDiagnosticBeacons"
    _build()
    set_hull(current_hull)
    set_condition(current_row)

func _create_box(part_name: String, size: Vector3,
        offset: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = part_name
    node.mesh = mesh
    node.position = offset
    node.material_override = mat
    node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(node)
    return node

func _build() -> void:
    var metal := StandardMaterial3D.new()
    metal.albedo_color = Color(0.11, 0.16, 0.20)
    metal.metallic = 0.80
    metal.roughness = 0.32
    for index in CHANNELS.size():
        var system_id: String = CHANNELS[index]
        var z: float = -2.4 + float(index) * 1.38
        bezels[system_id] = _create_box("R64_RealSensorBezel_" + system_id,
            Vector3(0.38, 0.045, 0.56), Vector3(0, 1.02, z), metal)
        var lens_mat := StandardMaterial3D.new()
        lens_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        lens_mat.emission_enabled = true
        lens_mat.emission_energy_multiplier = 1.25
        lens_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        status_materials[system_id] = lens_mat
        lenses[system_id] = _create_box("R64_TrueIntegrityLight_" + system_id,
            Vector3(0.24, 0.060, 0.38), Vector3(0, 1.075, z), lens_mat)

func set_hull(hull_id: String) -> void:
    current_hull = hull_id if ServiceR64.valid_hull(hull_id) else "ship_scout"
    var span: float = (0.78 if current_hull == "ship_scout" else
        0.93 if current_hull == "ship_interceptor" else 1.12)
    for system_id in CHANNELS:
        var index: int = CHANNELS.find(system_id)
        var x: float = span * (float(index) - 1.0)
        var bezel: MeshInstance3D = bezels.get(system_id)
        var lamp: MeshInstance3D = lenses.get(system_id)
        if is_instance_valid(bezel):
            bezel.position.x = x
        if is_instance_valid(lamp):
            lamp.position.x = x

func set_condition(input: Variant) -> void:
    current_row = ServiceR64.safe_row(input)
    for system_id in CHANNELS:
        var value: int = int(current_row[system_id])
        var tint: Color = (Color(0.13, 0.92, 0.70) if value >= 75 else
            Color(1.0, 0.64, 0.24) if value >= 45 else
            Color(1.0, 0.20, 0.24))
        var mat: StandardMaterial3D = status_materials.get(system_id)
        if is_instance_valid(mat):
            mat.albedo_color = tint
            mat.emission = tint
    actual_updates += 1

func real_mesh_count() -> int:
    return find_children("*", "MeshInstance3D", true, false).size()
