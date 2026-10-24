extends Node3D
## R22 real-time NX-08 propulsion finishing. Physical 3D nozzle geometry,
## tapered translucent plumes and a single non-shadow practical light.
## This code is a child of the R8 imported glTF and R14 sculpted ship.
const MaterialFabricR12Script = preload("res://scripts/material_fabric_r12.gd")

var ship: CharacterBody3D
var plume_count: int = 0
var nozzle_parts: int = 0
var flame_nodes: Array[MeshInstance3D] = []
var heat_light: OmniLight3D
var glow_core: StandardMaterial3D
var glow_shell: StandardMaterial3D
var time: float = 0.0

func _solid(color: Color, rough: float, metallic: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = rough
    return mat

func _jet_material(color: Color, alpha: float, emission: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    mat.cull_mode = BaseMaterial3D.CULL_DISABLED
    mat.albedo_color = Color(color.r,color.g,color.b,alpha)
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = emission
    return mat

func _nozzle(root: Node3D, label: String, pos: Vector3,
        r: float, length: float, mat: Material) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = r * 0.83
    mesh.bottom_radius = r * 1.12
    mesh.height = length
    mesh.radial_segments = 24
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = mesh
    draw.material_override = mat
    draw.rotation.x = PI * 0.5
    draw.position = pos
    root.add_child(draw)
    nozzle_parts += 1

func _flame(root: Node3D, label: String, pos: Vector3,
        r: float, length: float, mat: StandardMaterial3D) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = r * 0.08
    mesh.bottom_radius = r
    mesh.height = length
    mesh.radial_segments = 24
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = mesh
    draw.material_override = mat
    draw.position = pos
    draw.rotation.x = PI * 0.5
    root.add_child(draw)
    flame_nodes.append(draw)
    plume_count += 1
    return draw

func _ready() -> void:
    ship = get_parent().get_parent().get_parent() as CharacterBody3D
    var brushed: StandardMaterial3D = MaterialFabricR12Script.get_material(0)
    var alloy := _solid(Color(0.06,0.095,0.13),0.48,0.90)
    var copper := _solid(Color(0.47,0.28,0.12),0.36,0.83)
    glow_core = _jet_material(Color(0.60,0.87,1.0),0.56,0.58)
    glow_shell = _jet_material(Color(0.18,0.44,0.92),0.22,0.22)
    for index in 3:
        var x: float = float(index - 1) * 1.58
        var root := Node3D.new()
        root.name = "R22_CinematicPropulsion_%02d" % index
        root.position = Vector3(x,-0.27,4.5)
        add_child(root)
        _nozzle(root,"R22_MachinedCowl",Vector3.ZERO,0.72,0.91,brushed)
        _nozzle(root,"R22_DarkRecess",Vector3(0,0,0.44),0.50,0.22,alloy)
        _nozzle(root,"R22_CopperHeatShield",Vector3(0,0,0.63),0.59,0.18,copper)
        _flame(root,"R22_IonCore",Vector3(0,0,1.67),0.35,2.30,glow_core)
        _flame(root,"R22_ExhaustHalo",Vector3(0,0,2.20),0.57,3.8,glow_shell)
    heat_light = OmniLight3D.new()
    heat_light.name = "R22_NearShipExhaustLight"
    heat_light.light_color = Color(0.43,0.72,1.0)
    heat_light.light_energy = 0.18
    heat_light.omni_range = 8.0
    heat_light.shadow_enabled = false
    heat_light.position = Vector3(0,-0.37,5.5)
    add_child(heat_light)

func _process(delta: float) -> void:
    if not is_instance_valid(ship):
        return
    time += delta
    var throttle: float = clampf(ship.thruster_power,0.0,1.0)
    var speed: float = clampf(ship.velocity.length() / ship.AFTERBURNER_SPEED,0.0,1.0)
    var force: float = 0.28 + throttle * 1.4 + speed * 0.35
    for flame in flame_nodes:
        if not is_instance_valid(flame):
            continue
        var shell: bool = "Halo" in flame.name
        flame.scale.z = (0.40 if shell else 0.65) + force * (
            0.60 if shell else 0.72) + sin(time*26.0) * 0.045
        flame.visible = force > 0.25 and not (shell and speed < 0.12)
    if is_instance_valid(heat_light):
        heat_light.light_energy = 0.10 + minf(0.52,force*0.28)
