extends Node3D
## R9 animated high-detail mechanical subassemblies on the playable interceptor.
## Hinged landing gear, moving flight surfaces, compressor shutters and struts.
## The existing CharacterBody3D physics/save system is not modified.

const SurfaceLibraryR9Script = preload("res://scripts/surface_library_r9.gd")

var gear_count: int = 0
var control_surfaces: int = 0
var compressor_shutters: int = 0
var hinges: Array[Node3D] = []
var flaps: Array[Node3D] = []
var shutters: Array[Node3D] = []
var spacecraft: CharacterBody3D
var deploy_progress: float = 0.0
var animation_time: float = 0.0

var titanium: StandardMaterial3D
var carbon: StandardMaterial3D
var ceramic: StandardMaterial3D
var copper: StandardMaterial3D
var dark_glass: StandardMaterial3D

func _ready() -> void:
    spacecraft = get_parent().get_parent().get_parent() as CharacterBody3D
    titanium = SurfaceLibraryR9Script.coat(_mat(Color(0.70, 0.74, 0.76), 0.83, 0.38), 1)
    carbon = SurfaceLibraryR9Script.coat(_mat(Color(0.13, 0.17, 0.22), 0.48, 0.59), 0)
    ceramic = SurfaceLibraryR9Script.coat(_mat(Color(0.79, 0.80, 0.77), 0.36, 0.45), 3)
    copper = _mat(Color(0.72, 0.48, 0.25), 0.90, 0.33)
    dark_glass = _mat(Color(0.09, 0.16, 0.20), 0.17, 0.08)
    _landing_gear()
    _animated_elevons()
    _engine_iris()

func _mat(tint: Color, metal: float, rough: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = metal
    mat.roughness = rough
    return mat

func _box(parent: Node3D, title: String, pos: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = title
    node.position = pos
    node.mesh = mesh
    node.material_override = material
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, title: String, pos: Vector3, radius: float,
        height: float, material: Material, sides: int = 20) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = sides
    var node := MeshInstance3D.new()
    node.name = title
    node.mesh = mesh
    node.position = pos
    node.material_override = material
    parent.add_child(node)
    return node

func _link(parent: Node3D, title: String, start: Vector3, finish: Vector3,
        radius: float, material: Material) -> MeshInstance3D:
    var vector: Vector3 = finish - start
    var strut := _cylinder(parent, title, (start + finish) * 0.5, radius,
                        vector.length(), material, 16)
    strut.basis = Basis(Quaternion(Vector3.UP, vector.normalized()))
    return strut

func _landing_gear() -> void:
    for index in 3:
        var x: float = -2.25 if index == 0 else 2.25 if index == 1 else 0.0
        var z: float = 1.68 if index < 2 else -3.65
        var pivot := Node3D.new()
        pivot.name = "R9_HydraulicLandingLeg_%d" % index
        pivot.position = Vector3(x, -0.40, z)
        add_child(pivot)
        _box(pivot, "DorsalPivotShield", Vector3(0, 0.08, 0),
             Vector3(0.60, 0.48, 0.81), carbon)
        _cylinder(pivot, "HingeBearing", Vector3(0, -0.20, 0), 0.22, 0.50, copper)
        _link(pivot, "TelescopicTitaniumStrut", Vector3(0, -0.1, 0),
              Vector3(0, -1.54, 0.21), 0.16, titanium)
        _link(pivot, "ExposedChromePiston", Vector3(0, -0.72, 0.06),
              Vector3(0, -1.90, 0.48), 0.09, ceramic)
        _box(pivot, "ShockAbsorberSleeve", Vector3(0, -1.45, 0.22),
             Vector3(0.53, 0.68, 0.47), carbon)
        for side in [-1.0, 1.0]:
            _link(pivot, "DiagonalTorqueBrace", Vector3(0, -0.18, 0.0),
                  Vector3(side * 0.31, -1.53, 0.52), 0.052, copper)
            _box(pivot, "RetractableLandingPad", Vector3(side * 0.37, -2.12, 0.58),
                 Vector3(0.66, 0.21, 1.07), titanium)
            _box(pivot, "CeramicFootWearPlate", Vector3(side * 0.37, -2.26, 0.60),
                 Vector3(0.60, 0.07, 0.94), ceramic)
        hinges.append(pivot)
        gear_count += 1

func _animated_elevons() -> void:
    # Two primary elevons plus four thinner flight-control surfaces.
    for side in [-1.0, 1.0]:
        for section in 3:
            var outer: float = 2.3 + float(section) * 1.05
            var panel := Node3D.new()
            panel.name = "R9_ActuatedElevon_%d_%d" % [int(side), section]
            panel.position = Vector3(side * outer, -0.06, 2.03 - float(section) * 0.11)
            add_child(panel)
            _box(panel, "DarkCompositeFlap", Vector3(0, 0, 0.22),
                 Vector3(1.10, 0.15, 0.75), carbon)
            _box(panel, "CeramicTrailingStrip", Vector3(0, 0.02, 0.59),
                 Vector3(1.06, 0.045, 0.10), ceramic)
            for rod in [-1.0, 1.0]:
                _link(panel, "AlloyFlapActuator", Vector3(rod * 0.33, -0.12, -0.18),
                      Vector3(rod * 0.33, -0.13, 0.48), 0.048, copper)
            flaps.append(panel)
            control_surfaces += 1

func _engine_iris() -> void:
    for x in [-1.24, 0.0, 1.24]:
        var nozzle := Node3D.new()
        nozzle.name = "R9_EngineIris_%02d" % shutters.size()
        nozzle.position = Vector3(x, -0.22, 4.51)
        add_child(nozzle)
        var radius: float = 0.49 if absf(x) > 0.1 else 0.38
        for j in 12:
            var angle: float = TAU * float(j) / 12.0
            var shutter := Node3D.new()
            shutter.name = "R9_CeramicTurbineShutter"
            shutter.position = Vector3(cos(angle) * radius, sin(angle) * radius, 0.0)
            shutter.rotation.z = angle
            nozzle.add_child(shutter)
            _box(shutter, "SuperalloySegment", Vector3(0.0, 0, 0),
                Vector3(0.20, 0.086, 0.46), titanium)
            _box(shutter, "CopperCoolingStripe", Vector3(0.0, 0.055, 0.08),
                Vector3(0.19, 0.024, 0.22), copper)
        shutters.append(nozzle)
        compressor_shutters += 12

func _process(delta: float) -> void:
    animation_time += delta
    if not is_instance_valid(spacecraft):
        return
    var gear_requested: bool = spacecraft.global_position.y < 9.0 and spacecraft.velocity.length() < 13.0
    deploy_progress = move_toward(deploy_progress, 1.0 if gear_requested else 0.0, delta * 2.5)
    for j in hinges.size():
        var gear: Node3D = hinges[j]
        if is_instance_valid(gear):
            gear.rotation.x = -1.36 * (1.0 - deploy_progress)
            gear.rotation.z = (0.11 if j == 0 else -0.11 if j == 1 else 0.0) * deploy_progress
    var steer: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var pitch: float = float(Input.is_key_pressed(KEY_DOWN)) - float(Input.is_key_pressed(KEY_UP))
    for j in flaps.size():
        var elevon: Node3D = flaps[j]
        if is_instance_valid(elevon):
            var side: float = -1.0 if j < 3 else 1.0
            var target: float = clampf(pitch * 0.17 + side * steer * 0.12, -0.25, 0.25)
            elevon.rotation.x = lerpf(elevon.rotation.x, target, minf(delta * 4.2, 1.0))
    var acceleration_factor: float = clampf(spacecraft.velocity.length() / 60.0, 0.0, 1.0)
    for nozzle in shutters:
        if is_instance_valid(nozzle):
            nozzle.rotation.z += delta * (0.8 + acceleration_factor * 2.8)
