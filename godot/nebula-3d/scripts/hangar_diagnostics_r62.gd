extends Node3D
## R62: real 3D diagnostic gantry in Aurora Zero, not UI art or screenshot.
## One unshadowed work lamp + bounded low-poly meshes; optional on mobile.
const HULL_SPANS := {
    "ship_scout": 5.6, "ship_interceptor": 7.2, "ship_guardian": 8.9
}
const MODES := ["overview", "cockpit", "engines", "underside"]

var selected_hull: String = "ship_scout"
var active_mode: String = "overview"
var compact: bool = false
var gantry_root: Node3D
var scan_beam: MeshInstance3D
var work_light: SpotLight3D
var guide_rims: Array[MeshInstance3D] = []
var detail_nodes: Array[MeshInstance3D] = []
var phase: float = 0.0

func _ready() -> void:
    name = "R62_ActualMechanicalInspectionGantry"
    _construct()
    set_process(true)

func _material(tint: Color, glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.73 if glow <= 0.0 else 0.18
    mat.roughness = 0.36 if glow <= 0.0 else 0.25
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = glow
    return mat

func _box(part_name: String, dims: Vector3, at: Vector3,
        mat: Material, optional: bool = false) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dims
    var instance := MeshInstance3D.new()
    instance.name = part_name
    instance.mesh = mesh
    instance.position = at
    instance.material_override = mat
    gantry_root.add_child(instance)
    if optional:
        detail_nodes.append(instance)
    return instance

func _construct() -> void:
    gantry_root = Node3D.new()
    gantry_root.name = "R62_ActualMechanicalArch"
    add_child(gantry_root)
    var armor := _material(Color(0.17, 0.23, 0.29))
    var steel := _material(Color(0.38, 0.45, 0.49))
    var cyan := _material(Color(0.10, 0.72, 0.91), 1.60)
    var amber := _material(Color(0.98, 0.56, 0.22), 1.30)
    # Service rails remain entirely outside the real aircraft wing envelope.
    for side in [-1.0, 1.0]:
        _box("R62_RealGantryPillar_%s" % str(side),
            Vector3(0.65, 10.0, 0.78), Vector3(side * 11.1, 2.4, 1.5),
            armor)
        _box("R62_GantryVerticalStrip_%s" % str(side),
            Vector3(0.12, 7.4, 0.13), Vector3(side * 10.62, 1.7, 1.0),
            cyan, true)
        _box("R62_RealCalibrationFoot_%s" % str(side),
            Vector3(1.3, 0.32, 1.8), Vector3(side * 11.1, -2.43, 1.5),
            steel)
        for index in range(4):
            var z: float = -6.0 + float(index) * 4.0
            var guide := _box("R62_IlluminatedGroundGuide_%s_%d" %
                [str(side), index], Vector3(0.18, 0.035, 2.30),
                Vector3(side * 9.7, -2.47, z), cyan, true)
            guide_rims.append(guide)
    # Actual low-clearance floor crossrails bound the docking/inspection pad.
    # Four more structural meshes make the calibration scale legible from
    # the underside angle without resorting to floating 2D overlays.
    for index in range(4):
        var z: float = -7.0 + float(index) * 4.6
        _box("R62_SpanCalibrationCrossrail_%02d" % index,
            Vector3(19.2, 0.075, 0.13),
            Vector3(0.0, -2.44, z), steel, true)
    _box("R62_TrueOverheadServiceTruss", Vector3(23.2, 0.74, 0.96),
        Vector3(0.0, 7.25, 1.5), armor)
    _box("R62_InspectionTrussSignal", Vector3(4.4, 0.22, 0.46),
        Vector3(0.0, 6.82, 1.0), amber, true)
    scan_beam = _box("R62_MovingRealOpticalScanBar",
        Vector3(16.0, 0.08, 0.16), Vector3(0, 5.6, -5.0), cyan)
    scan_beam.visible = false
    work_light = SpotLight3D.new()
    work_light.name = "R62_TrueInspectionWorklight"
    work_light.position = Vector3(5.8, 9.6, -2.5)
    work_light.rotation_degrees = Vector3(-74.0, 15.0, 0.0)
    work_light.spot_range = 22.0
    work_light.spot_angle = 43.0
    work_light.shadow_enabled = false
    work_light.light_color = Color(0.64, 0.87, 1.0)
    work_light.light_energy = 1.3
    add_child(work_light)
    set_hull(selected_hull)
    set_mode(active_mode)
    set_quality_tier(1 if compact else 0)

func set_hull(hull_id: String) -> void:
    selected_hull = (hull_id if HULL_SPANS.has(hull_id) else "ship_scout")
    var span: float = float(HULL_SPANS[selected_hull])
    if is_instance_valid(scan_beam):
        var geom := scan_beam.mesh as BoxMesh
        geom.size = Vector3(span * 1.92, 0.08, 0.16)

func set_mode(mode: String) -> bool:
    if not MODES.has(mode):
        return false
    active_mode = mode
    if is_instance_valid(scan_beam):
        scan_beam.visible = mode != "overview" and not compact
    if is_instance_valid(work_light):
        work_light.light_color = (
            Color(0.97, 0.67, 0.40) if mode == "engines"
            else Color(0.62, 0.85, 1.0))
        work_light.light_energy = (
            1.15 if compact else 2.15 if mode != "overview" else 1.3)
    return true

func set_quality_tier(tier: int) -> void:
    compact = tier > 0
    for node in detail_nodes:
        if is_instance_valid(node):
            node.visible = not compact
    if is_instance_valid(scan_beam):
        scan_beam.visible = not compact and active_mode != "overview"
    if is_instance_valid(work_light):
        work_light.visible = not compact

func physical_mesh_count() -> int:
    if not is_instance_valid(gantry_root):
        return 0
    return gantry_root.find_children("*", "MeshInstance3D", true, false).size()

func _process(delta: float) -> void:
    if not visible or not is_instance_valid(scan_beam):
        return
    phase += minf(maxf(delta, 0.0), 0.05)
    if scan_beam.visible:
        scan_beam.position.z = -4.2 + sin(phase * 0.68) * 4.1
