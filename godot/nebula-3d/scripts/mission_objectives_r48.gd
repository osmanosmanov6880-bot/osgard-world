extends Node3D
## R48: three ACTUAL, deterministic objective mechanics for existing
## campaign missions. This node never writes saves or awards currency:
## world.gd remains the only authority for mission success/failure.
const SUPPORTED := ["scan", "escort", "evacuation"]
const SCAN_DWELL: float = 2.1
const EVAC_DWELL: float = 2.2
const SCAN_RADIUS: float = 37.0
const EVAC_RADIUS: float = 40.0
const ESCORT_RADIUS: float = 165.0
const ESCORT_SPEED: float = 20.0

var mission_type: String = ""
var active: bool = false
var stage: int = 0
var dwell: float = 0.0
var destination: Vector3 = Vector3.ZERO
var goal_points: Array[Vector3] = []
var marker_nodes: Array[Node3D] = []
var escort_health: float = 200.0
var escort_max_health: float = 200.0
var moving_convoy: Node3D
var convoy_started: bool = false

func _finish(color: Color, glow: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.metallic = 0.58
    material.roughness = 0.32
    if glow > 0.0:
        material.emission_enabled = true
        material.emission = color
        material.emission_energy_multiplier = glow
    return material

func _piece(parent: Node3D, name_part: String, mesh: Mesh,
        point: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name_part
    node.mesh = mesh
    node.position = point
    node.material_override = material
    parent.add_child(node)
    return node

func _box(size: Vector3) -> BoxMesh:
    var box := BoxMesh.new()
    box.size = size
    return box

func _make_marker(point: Vector3, tag: String, tint: Color) -> Node3D:
    var marker := Node3D.new()
    marker.name = tag
    marker.position = point
    add_child(marker)
    var sphere := SphereMesh.new()
    sphere.radius = 3.0
    sphere.height = 6.0
    _piece(marker, "R48_RealSignalCore", sphere, Vector3.ZERO,
        _finish(tint, 1.5))
    var ring := TorusMesh.new()
    ring.inner_radius = 7.5
    ring.outer_radius = 7.9
    ring.rings = 32
    ring.ring_segments = 7
    _piece(marker, "R48_RealSurveyRing", ring, Vector3(0, -1.2, 0),
        _finish(tint, 1.0))
    marker_nodes.append(marker)
    return marker

func _clear_previous() -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    marker_nodes.clear()
    goal_points.clear()
    moving_convoy = null
    mission_type = ""
    active = false
    stage = 0
    dwell = 0.0
    convoy_started = false
    escort_health = escort_max_health
    position = Vector3.ZERO

func configure(kind: String, target: Vector3) -> void:
    _clear_previous()
    if not SUPPORTED.has(kind):
        return
    name = "R48_Active_%s_Objective" % kind
    mission_type = kind
    destination = target
    active = true
    if kind == "scan":
        # Three separate points: the player must approach AND hold each.
        goal_points = [
            target + Vector3(-78, 28, -44),
            target + Vector3(23, 41, 87),
            target + Vector3(104, 33, -21),
        ]
        for i in goal_points.size():
            _make_marker(goal_points[i], "R48_RealScanProbe_%d" % i,
                Color(0.19, 0.83, 0.92))
    elif kind == "evacuation":
        # This is a real pick-up -> safe-drop two-stage flight, not a
        # waypoint renamed to "evacuation".
        goal_points = [
            target + Vector3(-102, 32, 78),
            target + Vector3(96, 38, -82),
        ]
        _make_marker(goal_points[0], "R48_RealRescuePickup",
            Color(1.0, 0.65, 0.30))
        _make_marker(goal_points[1], "R48_RealShelterDropoff",
            Color(0.21, 0.91, 0.66))
    elif kind == "escort":
        goal_points = [target + Vector3(0, 52, 0)]
        global_position = target + Vector3(-212, 52, -106)
        moving_convoy = Node3D.new()
        moving_convoy.name = "R48_RealVulnerableCivilianConvoy"
        add_child(moving_convoy)
        _piece(moving_convoy, "R48_VisibleCivilianHull",
            _box(Vector3(8.5, 2.3, 17.0)), Vector3.ZERO,
            _finish(Color(0.20, 0.39, 0.48)))
        _piece(moving_convoy, "R48_VisibleCivilianWing",
            _box(Vector3(16.0, 0.38, 4.1)), Vector3(0, -0.2, -1.3),
            _finish(Color(0.23, 0.49, 0.59)))
        for side in [-1.0, 1.0]:
            _piece(moving_convoy, "R48_RealEscortEngine_%s" % str(side),
                _box(Vector3(1.5, 1.1, 4.0)),
                Vector3(side * 5.4, -0.45, 5.1),
                _finish(Color(0.22, 0.78, 0.86), 1.2))
        _piece(moving_convoy, "R48_CivilianDistressAntenna",
            _box(Vector3(0.32, 3.0, 0.32)), Vector3(0, 2.2, -2),
            _finish(Color(1.0, 0.75, 0.33), 1.2))

func objective_position() -> Vector3:
    if mission_type == "escort":
        return global_position if active else destination
    if stage < goal_points.size():
        return goal_points[stage]
    return destination

func is_active_convoy() -> bool:
    return active and mission_type == "escort" and is_instance_valid(moving_convoy)

func take_damage(amount: float) -> void:
    # Called by the actual R15 enemy laser and contact damage, never a
    # fake progress timer. Clamp invalid / negative inputs.
    if is_active_convoy() and is_finite(amount) and amount > 0.0:
        escort_health = maxf(0.0, escort_health - amount)

func status_line() -> String:
    if mission_type == "scan":
        return "СКАНИРОВАНИЕ %d / 3 · УДЕРЖИВАЙ ДИСТАНЦИЮ: %.0f%%" % [
            mini(stage, 3), 100.0 * clampf(dwell / SCAN_DWELL, 0.0, 1.0)]
    if mission_type == "evacuation":
        return ("ПОДБЕРИ ЭКИПАЖ · ЗАВИСНИ У МАЯКА: %.0f%%" if stage == 0 else
            "ДОСТАВЬ ЛЮДЕЙ В УКРЫТИЕ · СТОЯНКА: %.0f%%") % [
            100.0 * clampf(dwell / EVAC_DWELL, 0.0, 1.0)]
    if mission_type == "escort":
        return "ЗАЩИТИ КОНВОЙ · ПРОЧНОСТЬ %d%% · ДЕРЖИСЬ РЯДОМ" % [
            roundi(100.0 * escort_health / escort_max_health)]
    return ""

func step(delta: float, pilot: Vector3) -> String:
    if not active:
        return "inactive"
    var dt: float = clampf(delta, 0.0, 0.25)
    if mission_type == "scan" or mission_type == "evacuation":
        var within: bool = pilot.distance_to(objective_position()) < (
            SCAN_RADIUS if mission_type == "scan" else EVAC_RADIUS)
        if within:
            dwell += dt
        else:
            dwell = maxf(0.0, dwell - dt)
        var hold: float = SCAN_DWELL if mission_type == "scan" else EVAC_DWELL
        if dwell >= hold:
            if stage < marker_nodes.size():
                marker_nodes[stage].visible = false
            stage += 1
            dwell = 0.0
            if stage >= goal_points.size():
                active = false
                return "success"
        return "running"
    if mission_type == "escort":
        if escort_health <= 0.0:
            active = false
            return "failed"
        if pilot.distance_to(global_position) < ESCORT_RADIUS:
            convoy_started = true
            global_position = global_position.move_toward(
                goal_points[0], ESCORT_SPEED * dt)
        if global_position.distance_to(goal_points[0]) <= 7.0:
            active = false
            return "success"
        return "running"
    return "inactive"
