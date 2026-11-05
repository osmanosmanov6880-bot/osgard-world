extends Node3D
## R51 / Mission 13: real moving courier, stealth tailing and timed radio evidence.
## No rewards, ownership, saves or mission progression are written here.
## The world controller owns success, failure and all persistent changes.

const CONTACT_RADIUS: float = 245.0
const SAFE_MIN: float = 65.0
const SAFE_MAX: float = 185.0
const LOSS_RADIUS: float = 290.0
const MAX_SIGNAL_LOSS: float = 8.0
const COURIER_SPEED: float = 24.0
const TRACE_PER_FRAGMENT: float = 2.5
const PULSE_COOLDOWN: float = 1.25
const TRACK_POINTS = [
    Vector3(-170.0, 20.0, -110.0),
    Vector3(-60.0, 28.0, -345.0),
    Vector3(160.0, 18.0, -445.0),
    Vector3(325.0, 16.0, -590.0),
]
const EVIDENCE = [
    "ПЕРЕХВАТ 1/3 · ПОДДЕЛЬНЫЕ ПРОПУСКА",
    "ПЕРЕХВАТ 2/3 · СЕКРЕТНЫЙ МАРШРУТ",
    "ПЕРЕХВАТ 3/3 · ПОЗЫВНОЙ КУРАТОРА",
]

var active: bool = false
var completed_once: bool = false
var contact_established: bool = false
var alarm: bool = false
var stage: int = 0
var next_waypoint: int = 1
var trace_seconds: float = 0.0
var exposure: float = 0.0
var signal_loss: float = 0.0
var pulse_cooldown: float = 0.0
var anchor: Vector3 = Vector3.ZERO
var courier: Node3D
var route: Array[Vector3] = []
var signal_posts: Array[Node3D] = []
var evidence: Array[String] = []
var last_event: String = ""

func _material(color: Color, glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.73
    mat.roughness = 0.31
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = glow
    return mat

func _box(dims: Vector3) -> BoxMesh:
    var b := BoxMesh.new()
    b.size = dims
    return b

func _part(parent: Node3D, label: String, mesh: Mesh,
        relative: Vector3, mat: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = label
    item.mesh = mesh
    item.position = relative
    item.material_override = mat
    parent.add_child(item)
    return item

func _build_courier() -> Node3D:
    var craft := Node3D.new()
    craft.name = "R51_RealMovingStealthCourier"
    add_child(craft)
    craft.global_position = route[0]
    _part(craft, "R51_CourierCargoHull", _box(Vector3(6.0, 2.5, 13.5)),
        Vector3.ZERO, _material(Color(0.13, 0.29, 0.36)))
    _part(craft, "R51_CourierLongWings", _box(Vector3(16.0, 0.28, 3.1)),
        Vector3(0, -0.5, 1.1), _material(Color(0.24, 0.42, 0.47)))
    _part(craft, "R51_CourierSensorAntenna", _box(Vector3(0.36, 4.0, 0.36)),
        Vector3(0, 3.0, -2.0), _material(Color(0.93, 0.63, 0.24), 1.5))
    for side in [-1.0, 1.0]:
        _part(craft, "R51_CourierEngine_%s" % str(side),
            _box(Vector3(1.4, 1.1, 3.3)),
            Vector3(side * 5.2, -0.35, 5.3),
            _material(Color(0.13, 0.72, 0.84), 1.3))
    return craft

func _build_post(number: int, at: Vector3) -> Node3D:
    var node := Node3D.new()
    node.name = "R51_RealRadioEvidenceCheckpoint_%d" % number
    add_child(node)
    node.global_position = at
    var ring := TorusMesh.new()
    ring.inner_radius = 13.5
    ring.outer_radius = 14.0
    ring.rings = 32
    ring.ring_segments = 8
    _part(node, "R51_RealCheckpointRing", ring, Vector3.ZERO,
        _material(Color(0.19, 0.75, 0.85), 1.3))
    var core := SphereMesh.new()
    core.radius = 1.8
    core.height = 3.6
    _part(node, "R51_RealEncryptedSignalSource", core, Vector3(0, 2.8, 0),
        _material(Color(1.0, 0.69, 0.34), 1.1))
    return node

func configure(point: Vector3) -> void:
    for old in get_children():
        remove_child(old)
        old.queue_free()
    route.clear()
    signal_posts.clear()
    evidence.clear()
    anchor = point
    route.append(point)
    for offset in TRACK_POINTS:
        route.append(point + offset)
    active = true
    completed_once = false
    contact_established = false
    alarm = false
    stage = 0
    next_waypoint = 1
    trace_seconds = 0.0
    exposure = 0.0
    signal_loss = 0.0
    pulse_cooldown = 0.0
    last_event = ""
    name = "R51_CourierStealthEvidenceMission"
    courier = _build_courier()
    for i in 3:
        var post := _build_post(i, route[i + 1])
        post.visible = i == 0
        signal_posts.append(post)

func objective_position() -> Vector3:
    if not is_instance_valid(courier):
        return anchor
    var heading: Vector3 = route[mini(next_waypoint, route.size() - 1)] - courier.global_position
    if heading.length_squared() < 1.0:
        heading = route[route.size() - 1] - route[0]
    return courier.global_position - heading.normalized() * 112.0

func _near_checkpoint() -> bool:
    return is_instance_valid(courier) and stage < 3 and next_waypoint == stage + 1 and (
        courier.global_position.distance_to(route[next_waypoint]) <= 2.5)

func can_capture(pilot: Vector3) -> bool:
    if not active or not contact_established or not _near_checkpoint():
        return false
    var range_now: float = pilot.distance_to(courier.global_position)
    return range_now >= SAFE_MIN and range_now <= SAFE_MAX and (
        trace_seconds >= TRACE_PER_FRAGMENT * float(stage + 1)) and pulse_cooldown <= 0.0

func capture_feedback() -> String:
    if not active: return "ОПЕРАЦИЯ ЗАКРЫТА"
    if not contact_established: return "СНАЧАЛА НАЙДИ КУРЬЕРА"
    if pulse_cooldown > 0.0: return "РАДИОМОДУЛЬ ПЕРЕЗАРЯЖАЕТСЯ"
    if not _near_checkpoint(): return "ДОЖДИСЬ СИГНАЛА У КОНТРОЛЬНОЙ ТОЧКИ"
    if trace_seconds < TRACE_PER_FRAGMENT * float(stage + 1):
        return "НЕ ХВАТАЕТ ВРЕМЕНИ СЛЕЖЕНИЯ"
    return "ДЕРЖИ ДИСТАНЦИЮ 65–185 М"

func request_capture(pilot: Vector3) -> bool:
    if not can_capture(pilot):
        return false
    evidence.append(EVIDENCE[stage])
    last_event = EVIDENCE[stage]
    signal_posts[stage].visible = false
    stage += 1
    next_waypoint = stage + 1
    pulse_cooldown = PULSE_COOLDOWN
    if stage < signal_posts.size():
        signal_posts[stage].visible = true
    return true

func report_weapon_discharge() -> void:
    if active:
        alarm = true

func status_line() -> String:
    if not active:
        return "СЛЕЖЕНИЕ ЗАВЕРШЕНО"
    if not contact_established:
        return "НАЙДИ КУРЬЕРА · ДЕРЖИСЬ НА ДИСТАНЦИИ"
    if stage == 3:
        return "ДОКАЗАТЕЛЬСТВА 3/3 · СОПРОВОЖДАЙ ДО ВЫХОДА"
    return "РАДИО %d/3 · ДИСТАНЦИЯ %d М · ПОДОЗРЕНИЕ %d%%" % [
        stage, roundi(courier.global_position.distance_to(
            get_meta("pilot_position", courier.global_position))),
        roundi(exposure)]

func step(delta: float, pilot: Vector3) -> String:
    if not active:
        return "inactive"
    if not is_instance_valid(courier):
        active = false
        return "failed"
    set_meta("pilot_position", pilot)
    var dt: float = clampf(delta, 0.0, 0.25)
    pulse_cooldown = maxf(0.0, pulse_cooldown - dt)
    if alarm:
        active = false
        return "failed"
    var distance: float = courier.global_position.distance_to(pilot)
    if not contact_established:
        if distance <= CONTACT_RADIUS:
            contact_established = true
        return "running"
    if distance < SAFE_MIN:
        exposure = minf(100.0, exposure + 28.0 * dt)
    elif distance <= SAFE_MAX:
        exposure = maxf(0.0, exposure - 10.0 * dt)
        trace_seconds += dt
    if distance > LOSS_RADIUS:
        signal_loss += dt
    else:
        signal_loss = maxf(0.0, signal_loss - 1.5 * dt)
    if exposure >= 100.0 or signal_loss >= MAX_SIGNAL_LOSS:
        active = false
        return "failed"
    var waypoint: Vector3 = route[next_waypoint]
    if courier.global_position.distance_to(waypoint) > 0.3:
        var previous: Vector3 = courier.global_position
        courier.global_position = previous.move_toward(waypoint, COURIER_SPEED * dt)
        var heading: Vector3 = courier.global_position - previous
        if heading.length_squared() > 0.001:
            courier.look_at(courier.global_position + heading, Vector3.UP)
    if stage == 3 and courier.global_position.distance_to(route[4]) <= 2.5 and (
            distance <= LOSS_RADIUS) and evidence.size() == 3:
        active = false
        completed_once = true
        return "success"
    return "running"
