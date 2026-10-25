extends Node3D
class_name OSGARDRig
## Procedurally modelled, original native Godot 3D teaching rig.
## Rotor and hatch follow the read-only simulation state; they cannot
## bypass the service interlock. Compatibility renderer, HERO/ECO budgets.

var rotor: Node3D
var hatch_hinge: Node3D
var camera: Camera3D
var signal_lights: Array[MeshInstance3D] = []
var hero_geometry: Array[Node3D] = []
var _previous_view: int = -1
var _previous_quality: String = ""
# True Godot MultiMesh: ten status segments in ONE draw batch. Color follows
# read-only simulator data, never commands the simulated mechanism.
var live_signal_bar: MultiMeshInstance3D
var _signal_last_signature: String = ""


func _ready() -> void:
    _construct_rig()

func _surface(base: Color, metal: float = 0.0, rough: float = 0.55, glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = base
    mat.metallic = metal
    mat.roughness = rough
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = base
        mat.emission_energy_multiplier = glow
    return mat

func _mesh_box(parent: Node3D, label: String, size: Vector3, position: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    node.name = label
    node.mesh = mesh
    node.material_override = material
    node.position = position
    parent.add_child(node)
    return node

func _mesh_cylinder(parent: Node3D, label: String, radius: float, length: float, position: Vector3, material: Material, sideways: bool = false) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = length
    mesh.radial_segments = 20
    node.mesh = mesh
    node.name = label
    node.material_override = material
    node.position = position
    if sideways:
        node.rotation_degrees = Vector3(90.0, 0.0, 0.0)
    parent.add_child(node)
    return node

func _construct_rig() -> void:
    var environment := WorldEnvironment.new()
    environment.name = "StudioAtmosphere"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("07121b")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("7f9bb0")
    env.ambient_light_energy = 0.32
    environment.environment = env
    add_child(environment)

    var steel := _surface(Color("43545f"), 0.78, 0.38)
    var steel_dark := _surface(Color("162a34"), 0.73, 0.46)
    var copper := _surface(Color("bb8561"), 0.83, 0.33)
    var brass := _surface(Color("dbab6e"), 0.70, 0.28)
    var floor_mat := _surface(Color("111f29"), 0.22, 0.84)
    var cyan := _surface(Color("4dd8cf"), 0.16, 0.32, 1.7)

    _mesh_box(self, "LaboratoryFloor", Vector3(15.0, 0.22, 11.0), Vector3(0, -0.17, 0), floor_mat)
    _mesh_box(self, "RearInspectionWall", Vector3(15.0, 7.0, 0.28), Vector3(0, 3.2, -3.55), steel_dark)
    _mesh_box(self, "GroundTestPlatform", Vector3(5.4, 0.27, 3.2), Vector3(0, 0.26, 0.0), steel)
    _mesh_box(self, "TestBedGoldenInlay", Vector3(5.1, 0.06, 2.98), Vector3(0, 0.42, 0), copper)
    _mesh_box(self, "RotorCradle", Vector3(3.3, 0.45, 2.1), Vector3(0, 0.78, -0.05), steel_dark)
    _mesh_box(self, "TopDiagnosticBar", Vector3(5.2, 0.18, 0.22), Vector3(0, 3.80, 0.2), brass)

    for x in [-2.45, 2.45]:
        _mesh_box(self, "StructuralTruss", Vector3(0.17, 3.2, 0.25), Vector3(x, 2.22, 0.10), copper)
        _mesh_box(self, "RearStabilizer", Vector3(0.27, 1.35, 2.2), Vector3(x, 0.96, -0.2), steel)
    for x in [-5.0, 5.0]:
        _mesh_box(self, "OuterWallLuminaire", Vector3(0.14, 4.0, 0.15), Vector3(x, 2.0, -3.25), cyan)
    _mesh_box(self, "RearServiceConduit", Vector3(10.8, 0.08, 0.10), Vector3(0, 5.2, -3.2), copper)

    var body := Node3D.new()
    body.name = "InertialRotorAssembly"
    body.position = Vector3(0.0, 1.55, 0)
    add_child(body)
    rotor = Node3D.new()
    rotor.name = "RotatingCore"
    body.add_child(rotor)
    _mesh_cylinder(rotor, "AlloyAxle", 0.29, 3.0, Vector3.ZERO, steel, true)
    _mesh_cylinder(rotor, "ServiceRotorHub", 0.73, 0.38, Vector3(0, 0, 0.1), brass, true)
    for i in range(8):
        var blade := _mesh_box(rotor, "RotorBlade_%02d" % i, Vector3(0.25, 1.23, 0.13), Vector3(0, 0, 0.12), copper)
        blade.position = Vector3(sin(float(i) * TAU / 8.0) * 0.76, cos(float(i) * TAU / 8.0) * 0.76, 0.12)
        blade.rotation.z = -float(i) * TAU / 8.0
    _mesh_cylinder(body, "BearingLeft", 0.57, 0.36, Vector3(-1.25, 0, 0), steel_dark)
    _mesh_cylinder(body, "BearingRight", 0.57, 0.36, Vector3(1.25, 0, 0), steel_dark)

    hatch_hinge = Node3D.new()
    hatch_hinge.name = "SimulatedSafetyHatchHinge"
    hatch_hinge.position = Vector3(-2.35, 1.05, 1.0)
    add_child(hatch_hinge)
    _mesh_box(hatch_hinge, "InterlockedCopperEdge", Vector3(4.75, 0.12, 0.18), Vector3(2.37, 0, 0.0), brass)
    _mesh_box(hatch_hinge, "HatchShield", Vector3(4.78, 2.22, 0.18), Vector3(2.37, 1.10, 0), _surface(Color(0.20, 0.36, 0.40, 0.52), 0.08, 0.22))
    _mesh_box(hatch_hinge, "HatchGlassRim", Vector3(4.62, 0.10, 0.28), Vector3(2.37, 2.20, 0), copper)
    for x in [0.15, 4.57]:
        _mesh_box(hatch_hinge, "HatchRim", Vector3(0.11, 2.18, 0.26), Vector3(x, 1.10, 0), copper)

    for i in range(3):
        var indicator := _mesh_cylinder(self, "LiveDiagnostic_%d" % (i + 1), 0.18, 0.10, Vector3(-1.2 + i * 1.2, 3.5, 0.41), _surface(Color("287077"), 0.10, 0.24, 1.5), true)
        signal_lights.append(indicator)
    _create_live_signal_bar()
    for i in range(12):
        var detail := _mesh_box(self, "HERO_ShadowFree_Fin_%d" % i, Vector3(0.09, 1.15, 0.19), Vector3(-4.8 + float(i) * 0.85, 1.7, -3.23), copper)
        detail.visible = true
        detail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        hero_geometry.append(detail)

    var key := DirectionalLight3D.new()
    key.name = "MainSoftIndustrialKey"
    key.rotation_degrees = Vector3(-43.0, -28.0, 0.0)
    key.light_color = Color("cde2e1")
    key.light_energy = 1.20
    key.shadow_enabled = false
    add_child(key)
    var warm := OmniLight3D.new()
    warm.name = "CopperServiceFill"
    warm.position = Vector3(3.5, 4.5, 5.5)
    warm.light_color = Color("ffc08b")
    warm.light_energy = 1.5
    warm.omni_range = 12.0
    warm.shadow_enabled = false
    add_child(warm)
    camera = Camera3D.new()
    camera.name = "OperatorInspectionCamera"
    camera.fov = 54.0
    camera.current = true
    add_child(camera)
    set_view(0)

func _create_live_signal_bar() -> void:
    var material := _surface(Color.WHITE, 0.14, 0.42)
    material.vertex_color_use_as_albedo = true
    var segment := BoxMesh.new()
    segment.size = Vector3(0.18, 0.18, 0.11)
    var mesh_batch := MultiMesh.new()
    mesh_batch.transform_format = MultiMesh.TRANSFORM_3D
    mesh_batch.use_colors = true
    mesh_batch.mesh = segment
    mesh_batch.instance_count = 10
    for i in range(10):
        mesh_batch.set_instance_transform(i, Transform3D(Basis(), Vector3(-1.20 + float(i) * 0.265, 3.96, 0.45)))
        mesh_batch.set_instance_color(i, Color("263a42"))
    live_signal_bar = MultiMeshInstance3D.new()
    live_signal_bar.name = "ActualSignalStabilityTenSegments"
    live_signal_bar.multimesh = mesh_batch
    live_signal_bar.material_override = material
    live_signal_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(live_signal_bar)

func signal_qa_readout() -> Dictionary:
    return {
        "uses_single_real_multimesh": live_signal_bar != null,
        "segments": live_signal_bar.multimesh.instance_count if live_signal_bar != null else 0,
        "shadow_casters": 0,
        "last_state": _signal_last_signature,
        "visual_only": true
    }

func set_view(index: int) -> void:
    if camera == null or index == _previous_view:
        return
    _previous_view = index
    if index == 2:
        camera.position = Vector3(-3.35, 2.65, 5.0)
    elif index == 1:
        camera.position = Vector3(4.5, 3.0, 5.2)
    else:
        camera.position = Vector3(6.4, 4.15, 8.5)
    camera.look_at(Vector3(0, 1.60, 0), Vector3.UP)

func set_quality(mode: String) -> void:
    if _previous_quality == mode:
        return
    _previous_quality = mode
    for detail in hero_geometry:
        detail.visible = mode == "hero"

func apply_simulation(state: Dictionary) -> void:
    if rotor == null or hatch_hinge == null:
        return
    rotor.rotation.z = float(state.get("rotor_angle", 0.0))
    hatch_hinge.rotation.z = -float(state.get("hatch", 0.0)) * 1.10
    set_view(int(state.get("view", 0)))
    set_quality(str(state.get("quality", "hero")))
    var case_id := int(state.get("fault", -1))
    var danger := bool(state.get("incident_triggered", false)) or bool(state.get("last_error", false))
    for i in range(signal_lights.size()):
        var indicator := signal_lights[i]
        var mat: StandardMaterial3D = indicator.material_override as StandardMaterial3D
        if i == case_id and danger:
            mat.albedo_color = Color("f2a15a")
            mat.emission = Color("f2a15a")
        elif i == case_id:
            mat.albedo_color = Color("5ce0d2")
            mat.emission = Color("5ce0d2")
        else:
            mat.albedo_color = Color("335861")
            mat.emission = Color("335861")
    if live_signal_bar == null:
        return
    var calibration: Dictionary = state.get("calibration", {})
    var progress: int = clampi(int(calibration.get("hold_percent", 0)), 0, 100)
    var incident: bool = bool(state.get("incident_triggered", false))
    var is_error: bool = bool(state.get("last_error", false))
    var complete: bool = bool(state.get("complete", false))
    var signature := "%d_%d_%d_%d_%d" % [case_id, progress, int(incident), int(is_error), int(complete)]
    if signature == _signal_last_signature:
        return
    _signal_last_signature = signature
    var lit: int = clampi(ceili(float(progress) / 10.0), 0, 10)
    for i in range(10):
        var tone := Color("263a42")
        if i < lit:
            tone = Color("77dfce") if not incident else Color("ecaa70")
        if is_error and i < lit:
            tone = Color("f29a86")
        if complete:
            tone = Color("77dfce")
        live_signal_bar.multimesh.set_instance_color(i, tone)
