extends Node3D
class_name IPCinematicStage
## IRON PULSE: BLACKOUT — purely visual, original procedural production dressing.
## No external meshes or textures and no interaction with the gameplay engine.

const AZURE := Color(0.055, 0.43, 0.59)
const GOLD := Color(0.96, 0.43, 0.13)
const GLOW := Color(0.28, 0.78, 0.86)

var hero_details: Node3D
var warning_material: StandardMaterial3D
var warning_lights: Array[OmniLight3D] = []
var _quality: String = "hero"
var _mesh_instances: int = 0
var _detail_objects: int = 0
var _safety_signs: int = 0

func _material(color: Color, metallic: float = 0.75, emissive: bool = false) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = metallic
    material.roughness = 0.39
    if emissive:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = 1.26
    return material

func _box(parent: Node3D, name_string: String, center: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name_string
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = center
    node.material_override = material
    parent.add_child(node)
    _detail_objects += 1
    return node

func _torus(parent: Node3D, name_string: String, center: Vector3, outer: float, material: Material, tilt: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name_string
    var mesh := TorusMesh.new()
    mesh.inner_radius = outer - 0.10
    mesh.outer_radius = outer
    mesh.rings = 40
    mesh.ring_segments = 14
    node.mesh = mesh
    node.position = center
    node.rotation_degrees = tilt
    node.material_override = material
    parent.add_child(node)
    _detail_objects += 1
    return node

func _instances(parent: Node3D, title: String, size: Vector3, positions: Array[Vector3], material: Material) -> void:
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    var mesh := BoxMesh.new()
    mesh.size = size
    multi.mesh = mesh
    multi.instance_count = positions.size()
    for i in range(positions.size()):
        multi.set_instance_transform(i, Transform3D(Basis(), positions[i]))
    var node := MultiMeshInstance3D.new()
    node.name = title
    node.multimesh = multi
    node.material_override = material
    parent.add_child(node)
    _mesh_instances += positions.size()

func _sign(parent: Node3D, name_string: String, words: String, point: Vector3, color: Color, size: int = 45) -> void:
    var sign := Label3D.new()
    sign.name = name_string
    sign.text = words
    sign.position = point
    sign.font_size = size
    sign.pixel_size = 0.0022
    sign.modulate = color
    parent.add_child(sign)
    _safety_signs += 1

func _ready() -> void:
    name = "IRON_PULSE_CinematicArchitecture"
    hero_details = Node3D.new()
    hero_details.name = "HeroStructuralDetail"
    add_child(hero_details)

    var graphite: StandardMaterial3D = _material(Color(0.072, 0.095, 0.123))
    var brushed: StandardMaterial3D = _material(Color(0.16, 0.22, 0.25))
    var recessed: StandardMaterial3D = _material(Color(0.021, 0.038, 0.054), 0.20)
    var copper: StandardMaterial3D = _material(Color(0.40, 0.19, 0.11))
    var cyan: StandardMaterial3D = _material(GLOW, 0.15, true)
    var amber: StandardMaterial3D = _material(GOLD, 0.10, true)
    warning_material = _material(Color(0.77, 0.16, 0.13), 0.12, true)

    # Architectural rhythm: bulkheads, side paneling, cable trenches and trim.
    for index in range(11):
        var depth: float = 1.3 - float(index) * 6.0
        for side in [-1.0, 1.0]:
            var x: float = side * 5.65
            _box(hero_details, "Rib_%d_%d" % [index, int(side)], Vector3(x, 2.85, depth), Vector3(0.24, 5.2, 0.34), brushed)
            _box(hero_details, "WallInlay_%d_%d" % [index, int(side)], Vector3(side*6.64, 2.8, depth-2.5), Vector3(0.07, 3.4, 3.9), recessed)
            _box(hero_details, "ServiceTrench_%d_%d" % [index, int(side)], Vector3(side*4.7, 0.025, depth-2.3), Vector3(0.60,0.035,4.8), graphite)
            _box(hero_details, "FiberDuct_%d_%d" % [index, int(side)], Vector3(side*6.3, 4.94, depth-2.3), Vector3(0.17, 0.18,4.65), copper)
        _box(hero_details, "Arch_%d" % index, Vector3(0, 5.22, depth), Vector3(11.8,0.25,0.33), brushed)
        _box(hero_details, "RoofRecess_%d" % index, Vector3(0, 5.88, depth-2.6), Vector3(8.7,0.07,4.8), recessed)
        _box(self, "OverheadPulse_%d" % index, Vector3(0, 5.71, depth), Vector3(7.8,0.045,0.08), cyan)

    # Repeated steel decking and fasteners use two actual MultiMesh draw groups.
    var bolts: Array[Vector3] = []
    var walkway: Array[Vector3] = []
    for section in range(28):
        var depth: float = 1.2 - float(section) * 2.27
        walkway.append(Vector3(-2.4,0.025,depth))
        walkway.append(Vector3(2.4,0.025,depth))
        for side in [-1.0,1.0]:
            for row in [0.55, 2.1, 3.65, 4.8]:
                bolts.append(Vector3(side*5.45, row, depth))
    _instances(hero_details, "MachinedWallFasteners", Vector3(0.085,0.085,0.075), bolts, copper)
    _instances(hero_details, "DeckSeamMarkers", Vector3(0.24,0.04,0.70), walkway, brushed)

    # Reactor containment ring: large-scale silhouettes around the existing core.
    var ring_center := Vector3(0,3.0,-20.5)
    _torus(hero_details, "ContainmentHorizon01", ring_center, 4.75, brushed, Vector3(90.0,0,0))
    _torus(hero_details, "ContainmentHorizon02", ring_center, 5.17, copper, Vector3(90.0,0,0))
    _torus(hero_details, "ContainmentPerimeter", ring_center, 5.55, cyan, Vector3(90.0,0,0))
    for i in range(8):
        var a: float = TAU * float(i) / 8.0
        var p := ring_center + Vector3(cos(a)*5.35,sin(a)*2.38,0.0)
        _box(hero_details, "ContainmentLock_%d" % i, p, Vector3(0.44,0.56,0.83), graphite)
    _box(hero_details, "ReactorTitlePanel", Vector3(0,5.42,-16.8), Vector3(4.8,0.65,0.14), graphite)
    _sign(hero_details,"ReactorCallsign","A7 // CORE CONTAINMENT",Vector3(0,5.43,-16.67),GLOW,49)
    _sign(self,"EmergencySector","SECTOR 07  /  EVACUATION",Vector3(0,4.15,-52.7),GLOW,58)
    _sign(self,"WarningSector","AUTHORIZED PERSONNEL ONLY",Vector3(0,3.58,-52.7),GOLD,35)

    for z in [-12.0,-31.0,-49.0]:
        for side in [-1.0,1.0]:
            _box(self,"AlertHousing",Vector3(side*6.68,3.9,z),Vector3(0.19,0.77,0.34),graphite)
            _box(self,"AlertLuminousStrip",Vector3(side*6.52,3.9,z),Vector3(0.09,0.63,0.25),warning_material)
    for z in [-17.0,-46.0]:
        var warning := OmniLight3D.new()
        warning.name = "LowFrequencyHazardLight"
        warning.position = Vector3(0,4.95,z)
        warning.light_color = GOLD
        warning.light_energy = 0.22
        warning.omni_range = 8.5
        warning.shadow_enabled = false
        add_child(warning)
        warning_lights.append(warning)
    set_quality("hero")

func set_quality(value: String) -> void:
    _quality = "eco" if value == "eco" else "hero"
    if hero_details != null:
        hero_details.visible = _quality == "hero"
    for light in warning_lights:
        light.visible = _quality == "hero"

func update_danger(heat: float, oxygen: float, elapsed: float, reduced_motion: bool) -> void:
    var alert: float = maxf(clampf((heat-67.0)/32.0,0.0,1.0),clampf((40.0-oxygen)/40.0,0.0,1.0))
    var breathing: float = 0.75 if reduced_motion else 0.65 + 0.25*sin(elapsed*1.7)
    if warning_material != null:
        warning_material.emission_energy_multiplier = 1.05 + 1.6*alert*breathing
    for light in warning_lights:
        light.light_energy = 0.18+0.78*alert*breathing

func readout() -> Dictionary:
    return {"quality":_quality,"instanced_detail_count":_mesh_instances,
        "architectural_objects":_detail_objects,"safety_signs":_safety_signs,
        "hazard_lights":warning_lights.size(),"hero_visible":hero_details.visible}
