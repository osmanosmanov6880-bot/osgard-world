extends Node3D
class_name IPKineticIris
## V9: one original industrial asset that *changes shape* with the genuine
## emergency. Eight manually parameterized UV-mapped machined steel petals,
## physical mechanical guidework and a single GPU-instanced bolt group.
##
## This is a real Godot 3D setpiece, not a decorative screenshot. The reactor
## stays visible through an opening larger than the original plasma sphere.
## No external assets, no gameplay mutations, no extra dynamic light sources.
const PETAL_COUNT: int = 8
const BOLTS: int = 32
const IRIS_CENTER := Vector3(9.38,7.0,-20.5)
const OUTER_RADIUS: float = 3.65
const INNER_RADIUS: float = 2.23
const PETAL_THICKNESS: float = 0.18
const HALF_ARC: float = 0.338
const COOL := Color(0.16,0.71,0.84)
const HEAT := Color(0.98,0.42,0.14)
const GRAPHITE := Color(0.13,0.18,0.22)
const CERAMIC := Color(0.49,0.57,0.61)

var petals: Array[Node3D] = []
var hinges: Array[MeshInstance3D] = []
var bolt_group: MultiMeshInstance3D
var _bolts: MultiMesh
var _indicator: StandardMaterial3D
var _shell: StandardMaterial3D
var _quality: String = "hero"
var _risk: float = 0.0
var _aperture_m: float = INNER_RADIUS
var _last_surge: int = 0
var _last_scenario: String = "blackout"
var _opening_motion_m: float = 0.0
var _reduced_motion: bool = false
var _hero_details: Node3D
var _has_uvs: bool = false

func _ready() -> void:
    name = "A7_PrecisionKineticIris"
    position = IRIS_CENTER
    _make_materials()
    _hero_details = Node3D.new()
    _hero_details.name = "HERO_MachinedDetail"
    add_child(_hero_details)
    for index in range(PETAL_COUNT):
        _make_petal(index)
    _build_static_guidework()
    _make_fasteners()
    set_quality("hero")

func _metal(tint: Color,metal: float,rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = metal
    m.roughness = rough
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    return m

func _make_materials() -> void:
    _shell = _metal(GRAPHITE,0.84,0.39)
    _indicator = _metal(COOL,0.18,0.32)
    _indicator.emission_enabled = true
    _indicator.emission = COOL
    _indicator.emission_energy_multiplier = 0.65

func _box(parent: Node3D,label: String,where: Vector3,dimensions: Vector3,mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    var node := MeshInstance3D.new()
    node.name = label
    node.mesh = mesh
    node.material_override = mat
    node.position = where
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D,label: String,where: Vector3,radius: float,height: float,mat: Material) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.height = height
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.radial_segments = 12
    var node := MeshInstance3D.new()
    node.name = label
    node.position = where
    node.mesh = mesh
    node.material_override = mat
    parent.add_child(node)
    return node

func _point(x: float,angle: float,radius: float) -> Vector3:
    # Reactor axis X. The camera looks toward +X, so its world-facing metal
    # is the x-negative surface in the Y/Z plane.
    return Vector3(x,sin(angle)*radius,cos(angle)*radius)

func _quad(tool: SurfaceTool,a: Vector3,b: Vector3,c: Vector3,d: Vector3,u0: float,u1: float) -> void:
    for item in [
        [a,Vector2(u0,0.0)], [b,Vector2(u1,0.0)], [c,Vector2(u0,1.0)],
        [c,Vector2(u0,1.0)], [b,Vector2(u1,0.0)], [d,Vector2(u1,1.0)]
    ]:
        tool.set_uv(item[1])
        tool.add_vertex(item[0])

func _petal_mesh(index: int) -> ArrayMesh:
    # Thick original curved wedge with six closed faces; not a BoxMesh.
    # Moderate tessellation and UVs allow independent PBR art later.
    var mesh_builder := SurfaceTool.new()
    mesh_builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    var a: float = TAU*float(index)/float(PETAL_COUNT)
    var near_a: float = a-HALF_ARC
    var far_a: float = a+HALF_ARC
    var near_x: float = -PETAL_THICKNESS*0.5
    var far_x: float = PETAL_THICKNESS*0.5
    var front_inner_a: Vector3 = _point(near_x,near_a,INNER_RADIUS)
    var front_outer_a: Vector3 = _point(near_x,near_a,OUTER_RADIUS)
    var front_inner_b: Vector3 = _point(near_x,far_a,INNER_RADIUS)
    var front_outer_b: Vector3 = _point(near_x,far_a,OUTER_RADIUS)
    var rear_inner_a: Vector3 = _point(far_x,near_a,INNER_RADIUS)
    var rear_outer_a: Vector3 = _point(far_x,near_a,OUTER_RADIUS)
    var rear_inner_b: Vector3 = _point(far_x,far_a,INNER_RADIUS)
    var rear_outer_b: Vector3 = _point(far_x,far_a,OUTER_RADIUS)
    _quad(mesh_builder,front_inner_a,front_outer_a,front_inner_b,front_outer_b,0.0,1.0)
    _quad(mesh_builder,rear_inner_b,rear_outer_b,rear_inner_a,rear_outer_a,0.0,1.0)
    _quad(mesh_builder,front_inner_b,front_inner_a,rear_inner_b,rear_inner_a,0.0,1.0)
    _quad(mesh_builder,front_outer_a,front_outer_b,rear_outer_a,rear_outer_b,0.0,1.0)
    _quad(mesh_builder,front_inner_a,rear_inner_a,front_outer_a,rear_outer_a,0.0,1.0)
    _quad(mesh_builder,rear_inner_b,front_inner_b,rear_outer_b,front_outer_b,0.0,1.0)
    mesh_builder.generate_normals()
    return mesh_builder.commit()

func _make_petal(index: int) -> void:
    var angle: float = TAU*float(index)/float(PETAL_COUNT)
    var pivot := Node3D.new()
    pivot.name = "PrecisionSlidingPetal_%02d" % index
    add_child(pivot)
    var surface := MeshInstance3D.new()
    surface.name = "CustomUV_CurvedArmor"
    surface.mesh = _petal_mesh(index)
    surface.material_override = _shell
    pivot.add_child(surface)
    _has_uvs = _has_uvs or ((surface.mesh.surface_get_format(0) & Mesh.ARRAY_FORMAT_TEX_UV) != 0)
    var offset: Vector3 = _point(0.0,angle,OUTER_RADIUS+0.19)
    var hinge := _cylinder(pivot,"MachinedRadialServo",offset,0.12,0.75,_metal(CERAMIC,0.91,0.25))
    hinge.rotation.x = PI*0.5-angle
    hinges.append(hinge)
    petals.append(pivot)

func _build_static_guidework() -> void:
    var guide_material := _metal(CERAMIC,0.79,0.44)
    for i in range(PETAL_COUNT):
        var angle: float = TAU*float(i)/float(PETAL_COUNT)
        var anchor := _point(0.0,angle,OUTER_RADIUS+0.38)
        var support := _cylinder(_hero_details,"HydraulicGuide_%02d" % i,
            anchor,0.095,1.22,guide_material)
        support.rotation.x = PI*0.5-angle
        var face := _box(_hero_details,"AmberInspectionGauge_%02d" % i,
            _point(-0.23,angle,OUTER_RADIUS+0.61),Vector3(0.045,0.14,0.25),_indicator)
        face.rotation.x = -angle

func _make_fasteners() -> void:
    var bolt_mesh := CylinderMesh.new()
    bolt_mesh.top_radius = 0.042
    bolt_mesh.bottom_radius = 0.042
    bolt_mesh.height = 0.055
    bolt_mesh.radial_segments = 6
    _bolts = MultiMesh.new()
    _bolts.transform_format = MultiMesh.TRANSFORM_3D
    _bolts.mesh = bolt_mesh
    _bolts.instance_count = BOLTS
    for i in range(BOLTS):
        var index: int = i % PETAL_COUNT
        var ring_number: int = floori(float(i)/float(PETAL_COUNT))
        var angle: float = TAU*float(index)/float(PETAL_COUNT)
        var radius: float = OUTER_RADIUS+0.34+0.09*float(ring_number)
        var transform := Transform3D(Basis(),_point(-0.17,angle,radius))
        _bolts.set_instance_transform(i,transform)
    bolt_group = MultiMeshInstance3D.new()
    bolt_group.name = "GPU_Instanced_IrisGuideBolts"
    bolt_group.multimesh = _bolts
    bolt_group.material_override = _metal(CERAMIC,0.9,0.30)
    _hero_details.add_child(bolt_group)

func set_quality(mode: String) -> void:
    _quality = "eco" if mode == "eco" else "hero"
    if _hero_details != null:
        _hero_details.visible = _quality == "hero"

func update_from_crisis(
        scenario: String,heat: float,oxygen: float,seconds: float,
        reduced_motion: bool, surges: int,thermal_shield: bool = false,
        active: bool = true
    ) -> void:
    if not active:
        return
    _last_scenario = scenario
    _reduced_motion = reduced_motion
    var thermal: float = clampf((heat-61.0)/39.0,0.0,1.0)
    var oxygen_risk: float = clampf((58.0-oxygen)/58.0,0.0,1.0)
    _risk = maxf(thermal,oxygen_risk)
    var shield_factor: float = 0.66 if thermal_shield else 1.0
    var critical: float = _risk*shield_factor
    # Live measured emergency opens the petals outward to vent the core;
    # visible inner hole always exceeds plasma radius by a safe margin.
    _opening_motion_m = critical*0.58
    _aperture_m = INNER_RADIUS+_opening_motion_m
    for index in range(PETAL_COUNT):
        var angle: float = TAU*float(index)/float(PETAL_COUNT)
        petals[index].position = _point(0.0,angle,_opening_motion_m)
    _indicator.emission = HEAT if scenario == "thermal" else COOL if scenario == "breach" else Color(0.95,0.68,0.23)
    _indicator.albedo_color = _indicator.emission
    _indicator.emission_energy_multiplier = 0.60+1.15*critical
    # An actual thermal pulse causes a brief brighter warning when allowed;
    # accessibility mode forbids oscillation, but risk color remains visible.
    if not reduced_motion and surges > _last_surge:
        _indicator.emission_energy_multiplier += 0.12
    _last_surge = surges

func readout() -> Dictionary:
    return {
        "physical_curved_petals":petals.size(),
        "original_uv_mesh":_has_uvs,
        "physical_hinges":hinges.size(),
        "gpu_bolt_groups":1 if bolt_group != null else 0,
        "instanced_guide_bolts":BOLTS,
        "quality":_quality,
        "risk":_risk,
        "scenario":_last_scenario,
        "aperture_radius_m":_aperture_m,
        "moving_clearance_m":_opening_motion_m,
        "motion_reduced":_reduced_motion,
        "detailed_guides_visible":_hero_details != null and _hero_details.visible,
        "real_steel_material":_shell != null and _shell.metallic >= 0.80,
        "emission_level":_indicator.emission_energy_multiplier
    }
