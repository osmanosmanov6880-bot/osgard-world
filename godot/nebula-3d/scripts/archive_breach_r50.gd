extends Node3D
## R50 / Mission 12: playable evidence-extraction and defense.
## Two distinct physical key fragments unlock a vulnerable archive core.
## The final transfer needs a sustained manual hold while hostile drones
## attack the real server. Rewards and saves remain world.gd-only.

const TERMINAL_RADIUS: float = 38.0
const KEY_HOLD: float = 1.75
const DOWNLOAD_HOLD: float = 5.0
const SERVER_CAPACITY: float = 160.0
## R50 second-round gameplay: a one-use emergency cell restores real
## reactor integrity, at the cost of abandoning the download position.
const REPAIR_RADIUS: float = 29.0
const REPAIR_HOLD: float = 2.0
const REPAIR_AMOUNT: float = 45.0
const REPAIR_OFFSET: Vector3 = Vector3(86.0, 5.0, -44.0)
const STATIONS = [
    Vector3(-88.0, 15.0, -50.0),
    Vector3(70.0, 27.0, 37.0),
    Vector3(0.0, 40.0, 106.0),
]
const EVIDENCE = [
    "КЛЮЧ «ЭХО» 1/2 · ВЫДЕЛЕН ИЗ СИГНАЛА",
    "КЛЮЧ «ЭХО» 2/2 · ПРИМЕНЁН К АРХИВУ",
    "ЗАПИСЬ КУРАТОРА ИЗВЛЕЧЕНА",
]

var active: bool = false
var stage: int = 0
var hold_time: float = 0.0
var security_health: float = SERVER_CAPACITY
var combat_started: bool = false
var nodes: Array[Node3D] = []
var points: Array[Vector3] = []
var evidence: Array[String] = []
var last_event: String = ""
var completed_once: bool = false
var anchor: Vector3 = Vector3.ZERO
var repair_node: Node3D
var repair_point: Vector3 = Vector3.ZERO
var repair_hold_time: float = 0.0
var repair_used: bool = false
var focus_on_repair: bool = false
var repair_events: int = 0


func _material(tint: Color, energy: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.74
    mat.roughness = 0.32
    if energy > 0:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = energy
    return mat

func _box(dimensions: Vector3) -> BoxMesh:
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    return mesh

func _part(owner: Node3D, label: String, mesh: Mesh,
        offset: Vector3, material: Material) -> void:
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = mesh
    instance.position = offset
    instance.material_override = material
    owner.add_child(instance)

func _create_station(index: int, point: Vector3) -> Node3D:
    var console := Node3D.new()
    console.name = "R50_ActiveArchiveStation_%d" % index
    add_child(console)
    console.global_position = point
    var color := Color(1.0, 0.63, 0.26) if index == 2 else Color(0.22, 0.81, 0.94)
    _part(console, "R50_SteelConsole",
        _box(Vector3(5.2, 5.6, 4.0)), Vector3.ZERO,
        _material(Color(0.12, 0.23, 0.30)))
    _part(console, "R50_LiveKeyScreen",
        _box(Vector3(6.3, 3.5, 0.25)), Vector3(0, 4.1, -1.8),
        _material(color, 1.8))
    _part(console, "R50_InteractingControlSurface",
        _box(Vector3(5.0, 0.45, 2.4)), Vector3(0, 1.5, -2.1),
        _material(Color(0.31, 0.55, 0.61), 0.4))
    var ring := TorusMesh.new()
    ring.inner_radius = TERMINAL_RADIUS - 0.8
    ring.outer_radius = TERMINAL_RADIUS
    ring.rings = 32
    ring.ring_segments = 7
    _part(console, "R50_RealArchiveAccessRadius", ring,
        Vector3(0, -5.7, 0), _material(color, 0.65))
    if index == 2:
        _part(console, "R50_DestructibleArchiveReactor",
            _box(Vector3(12.0, 9.0, 7.5)),
            Vector3(0.0, 2.8, 10.0), _material(Color(0.62, 0.35, 0.27), 0.4))
    return console

func configure(location: Vector3) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    nodes.clear()
    points.clear()
    evidence.clear()
    last_event = ""
    hold_time = 0.0
    security_health = SERVER_CAPACITY
    active = true
    stage = 0
    combat_started = false
    completed_once = false
    repair_hold_time = 0.0
    repair_used = false
    focus_on_repair = false
    repair_events = 0
    repair_node = null
    anchor = location
    for offset in STATIONS:
        points.append(location + offset)
    # Enemy drones will genuinely chase and attack this server location.
    global_position = points[2]
    name = "R50_VulnerableEncryptedArchive"
    for i in points.size():
        var station: Node3D = _create_station(i, points[i])
        station.visible = i == 0
        nodes.append(station)
    repair_point = points[2] + REPAIR_OFFSET
    repair_node = _create_station(3, repair_point)
    repair_node.name = "R50_OneUseEmergencyPowerCell"
    repair_node.visible = false

func objective_position() -> Vector3:
    if stage == 2 and focus_on_repair and can_repair():
        return repair_point
    if stage < points.size():
        return points[stage]
    return points[2] if not points.is_empty() else anchor

func can_interact(pilot: Vector3) -> bool:
    # The navigation preference can never spoof the physical main terminal.
    return active and stage < points.size() and pilot.distance_to(
        points[stage]) <= TERMINAL_RADIUS

func can_repair() -> bool:
    return active and stage == 2 and combat_started and not repair_used and (
        security_health > 0.0 and security_health < SERVER_CAPACITY)

func can_repair_here(pilot: Vector3) -> bool:
    return can_repair() and pilot.distance_to(repair_point) <= REPAIR_RADIUS

func set_repair_navigation(enabled: bool) -> bool:
    if not active or stage != 2 or repair_used:
        focus_on_repair = false
        return false
    focus_on_repair = enabled
    return true

func is_active_server() -> bool:
    return active and stage == 2 and combat_started

func take_damage(amount: float) -> void:
    if is_active_server() and is_finite(amount) and amount > 0.0:
        security_health = maxf(0.0, security_health - amount)

func status_line() -> String:
    if not active:
        return "АРХИВ ЗАКРЫТ · ВЫЛЕТ ЗАВЕРШЁН"
    if stage < 2:
        return "КЛЮЧ %d/2 · УДЕРЖИВАЙ ВВОД · %d%%" % [
            stage + 1, roundi(100.0 * clampf(hold_time / KEY_HOLD, 0.0, 1.0))]
    if focus_on_repair and not repair_used:
        return "АВАРИЙНЫЙ ЭЛЕМЕНТ · УДЕРЖИВАЙ %d%% · АРХИВ %d%%" % [
            roundi(100.0 * clampf(repair_hold_time / REPAIR_HOLD, 0.0, 1.0)),
            roundi(100.0 * security_health / SERVER_CAPACITY)]
    return "ЗАГРУЗКА %d%% · АРХИВ %d%% · %s" % [
        roundi(100.0 * clampf(hold_time / DOWNLOAD_HOLD, 0.0, 1.0)),
        roundi(100.0 * security_health / SERVER_CAPACITY),
        "РЕМОНТ ДОСТУПЕН" if can_repair() else "ЗАЩИЩАЙ СЕРВЕР"]

func step(delta: float, pilot: Vector3, pressing: bool) -> String:
    if not active:
        return "inactive"
    if security_health <= 0.0:
        active = false
        return "failed"
    var dt: float = clampf(delta, 0.0, 0.25)
    if can_repair_here(pilot) and pressing:
        repair_hold_time += dt
        if repair_hold_time >= REPAIR_HOLD:
            security_health = minf(SERVER_CAPACITY, security_health + REPAIR_AMOUNT)
            repair_used = true
            repair_hold_time = 0.0
            repair_events += 1
            focus_on_repair = false
            if is_instance_valid(repair_node):
                repair_node.visible = false
            last_event = "АРХИВ · +45 ПРОЧНОСТИ · ЭЛЕМЕНТ ИСПОЛЬЗОВАН"
            return "event"
    else:
        repair_hold_time = maxf(0.0, repair_hold_time - 2.0 * dt)
    if can_interact(pilot) and pressing:
        hold_time += dt
    else:
        hold_time = maxf(0.0, hold_time - 2.0 * dt)
    var needed: float = DOWNLOAD_HOLD if stage == 2 else KEY_HOLD
    if hold_time < needed:
        return "running"
    if stage < nodes.size():
        nodes[stage].visible = false
    evidence.append(EVIDENCE[stage])
    last_event = EVIDENCE[stage]
    stage += 1
    hold_time = 0.0
    if stage >= points.size():
        active = false
        completed_once = true
        return "success"
    nodes[stage].visible = true
    if stage == 2:
        combat_started = true
        if is_instance_valid(repair_node):
            repair_node.visible = true
    return "event"
