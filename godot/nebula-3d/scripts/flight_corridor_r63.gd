extends Node3D
## R63: three real collision-free MeshInstance3D guidance rings.
## Geometry is shared and never reallocated inside physics/update loops.
const GATE_COUNT: int = 3
const SIDES: int = 40
const RADIUS_M: float = 8.0
const RING_THICKNESS_M: float = 0.33
var gates: Array[MeshInstance3D] = []
var last_goal: Vector3 = Vector3.ZERO
var last_distance_m: float = 0.0
var updates: int = 0

func _ready() -> void:
    name = "R63_Actual3DFlightGuidanceCorridor"
    var ring_mesh: ArrayMesh = _make_ring_mesh()
    for i in range(GATE_COUNT):
        var gate := MeshInstance3D.new()
        gate.name = "R63_RealFlightGuideGate_%d" % (i + 1)
        gate.mesh = ring_mesh
        gate.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        var mat := StandardMaterial3D.new()
        mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
        mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        mat.cull_mode = BaseMaterial3D.CULL_DISABLED
        mat.albedo_color = Color(0.16, 0.84, 1.0,
            0.64 - float(i) * 0.14)
        mat.emission_enabled = true
        mat.emission = Color(0.10, 0.55, 0.78)
        mat.emission_energy_multiplier = 1.1
        gate.material_override = mat
        gate.visible = false
        add_child(gate)
        gates.append(gate)

func _make_ring_mesh() -> ArrayMesh:
    var vertices := PackedVector3Array()
    for side in range(SIDES):
        var a: float = TAU * float(side) / float(SIDES)
        var b: float = TAU * float(side + 1) / float(SIDES)
        var inner: float = RADIUS_M - RING_THICKNESS_M
        var p1 := Vector3(cos(a) * inner, sin(a) * inner, 0)
        var p2 := Vector3(cos(a) * RADIUS_M, sin(a) * RADIUS_M, 0)
        var p3 := Vector3(cos(b) * inner, sin(b) * inner, 0)
        var p4 := Vector3(cos(b) * RADIUS_M, sin(b) * RADIUS_M, 0)
        vertices.append_array(PackedVector3Array([p1, p2, p3,
            p3, p2, p4]))
    var data: Array = []
    data.resize(Mesh.ARRAY_MAX)
    data[Mesh.ARRAY_VERTEX] = vertices
    var geometry := ArrayMesh.new()
    geometry.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, data)
    return geometry

func clear_guides() -> void:
    last_goal = Vector3.ZERO
    last_distance_m = 0.0
    for gate in gates:
        gate.visible = false

func set_guidance(active: bool, ship_position: Vector3,
        objective: Vector3, quality: int = 0) -> void:
    if not active:
        clear_guides()
        return
    var diff: Vector3 = objective - ship_position
    var distance: float = diff.length()
    if not is_finite(distance) or distance < 85.0:
        clear_guides()
        return
    last_goal = objective
    last_distance_m = distance
    var direction: Vector3 = diff / distance
    var up: Vector3 = Vector3.UP if absf(
        direction.dot(Vector3.UP)) < 0.97 else Vector3.FORWARD
    var allowed: int = (1 if quality >= 2 else
        2 if quality == 1 else GATE_COUNT)
    var stride: float = minf(112.0, distance / float(GATE_COUNT + 1))
    for i in range(GATE_COUNT):
        var marker: MeshInstance3D = gates[i]
        var travelled: float = stride * float(i + 1)
        marker.visible = i < allowed and travelled < distance - 24.0
        if not marker.visible:
            continue
        marker.global_position = ship_position + direction * travelled
        marker.look_at(marker.global_position + direction, up)
    updates += 1

func visible_count() -> int:
    var count: int = 0
    for gate in gates:
        if gate.visible:
            count += 1
    return count

func has_collision_geometry() -> bool:
    return not find_children("*", "CollisionObject3D", true, false).is_empty()
