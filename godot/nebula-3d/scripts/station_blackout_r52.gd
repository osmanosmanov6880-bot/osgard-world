extends Node3D
## NEBULA R52 / mission 14: power-station blackout rescue.
## Real switches, a vulnerable reactor and a one-use physical capacitor.
## The campaign world (never this controller) owns rewards and persistent saves.

const RELAY_HOLD: float = 1.75
const RELAY_RADIUS: float = 36.0
const GRID_MAX: float = 130.0
const GRID_DRAIN_PER_SECOND: float = 0.35
const GRID_DEFENSE_SECONDS: float = 95.0
const STABILIZATION_SECONDS: float = 14.0
const STABILIZATION_RADIUS: float = 78.0
const CAPACITOR_HOLD: float = 2.0
const CAPACITOR_RADIUS: float = 30.0
const CAPACITOR_RECOVERY: float = 40.0

var active: bool = false
var stage: int = 0
var hold_time: float = 0.0
var stabilization: float = 0.0
var grid_health: float = GRID_MAX
var defense_remaining: float = GRID_DEFENSE_SECONDS
var capacitor_hold: float = 0.0
var capacitor_used: bool = false
var focus_on_capacitor: bool = false
var reactor_online: bool = false
var completed_once: bool = false
var last_event: String = ""
var relay_positions: Array[Vector3] = []
var capacitor_position: Vector3 = Vector3.ZERO
var relays: Array[Node3D] = []
var reactor: Node3D
var capacitor: Node3D
var actual_damage_hits: int = 0
var capacitor_events: int = 0

func _glow(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.78
    mat.roughness = 0.24
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 1.9
    return mat

func _box(parent: Node3D, name: String, size: Vector3,
        offset: Vector3, color: Color) -> void:
    var part := MeshInstance3D.new()
    part.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.material_override = _glow(color)
    part.position = offset
    parent.add_child(part)

func _station(name: String, point: Vector3, color: Color,
        large: bool = false) -> Node3D:
    var station := Node3D.new()
    station.name = name
    add_child(station)
    station.global_position = point
    var scale_size: float = 2.5 if large else 1.0
    _box(station, "R52_PhysicalAlloyConsole",
        Vector3(6.0, 7.0, 6.0) * scale_size,
        Vector3.ZERO, Color(0.14, 0.22, 0.30))
    _box(station, "R52_ActivePowerDisplay",
        Vector3(5.5, 3.0, 0.4) * scale_size,
        Vector3(0.0, 4.4 * scale_size, -3.0 * scale_size), color)
    var ring := MeshInstance3D.new()
    ring.name = "R52_ActualInteractionPerimeter"
    var circle := TorusMesh.new()
    circle.inner_radius = 12.5 if large else RELAY_RADIUS - 1.4
    circle.outer_radius = 13.5 if large else RELAY_RADIUS
    circle.rings = 32
    circle.ring_segments = 8
    ring.mesh = circle
    ring.material_override = _glow(color)
    ring.position = Vector3(0.0, -4.6, 0.0)
    station.add_child(ring)
    return station

func configure(center: Vector3) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    active = true
    stage = 0
    hold_time = 0.0
    stabilization = 0.0
    grid_health = GRID_MAX
    defense_remaining = GRID_DEFENSE_SECONDS
    capacitor_hold = 0.0
    capacitor_used = false
    focus_on_capacitor = false
    reactor_online = false
    completed_once = false
    last_event = ""
    actual_damage_hits = 0
    capacitor_events = 0
    relays.clear()
    relay_positions = [
        center + Vector3(-110.0, 13.0, 65.0),
        center + Vector3(105.0, 14.0, 42.0),
    ]
    for i in 2:
        var node := _station("R52_RealPhysicalCircuitBreaker_%d" % (i + 1),
            relay_positions[i], Color(0.11, 0.83, 0.95))
        node.visible = i == 0
        relays.append(node)
    reactor = _station("R52_RealDestructiblePowerCore",
        center + Vector3(0.0, 16.0, -58.0),
        Color(1.0, 0.53, 0.18), true)
    reactor.visible = false
    capacitor_position = reactor.global_position + Vector3(102.0, 5.0, -69.0)
    capacitor = _station("R52_OneUseBackupCapacitor",
        capacitor_position, Color(0.38, 1.0, 0.64))
    capacitor.visible = false

func objective_position() -> Vector3:
    if stage < 2 and stage >= 0:
        return relay_positions[stage]
    if stage == 2 and focus_on_capacitor and can_repair():
        return capacitor_position
    if is_instance_valid(reactor):
        return reactor.global_position
    return Vector3.ZERO

func is_live_reactor() -> bool:
    return active and stage == 2 and reactor_online and grid_health > 0.0

func can_repair() -> bool:
    return is_live_reactor() and not capacitor_used and grid_health < GRID_MAX

func select_capacitor(enabled: bool) -> bool:
    if not is_live_reactor() or capacitor_used:
        focus_on_capacitor = false
        return false
    focus_on_capacitor = enabled
    return true

func can_hold(pilot: Vector3) -> bool:
    if not active:
        return false
    if stage < 2:
        return pilot.distance_to(relay_positions[stage]) <= RELAY_RADIUS
    return can_repair() and pilot.distance_to(capacitor_position) <= CAPACITOR_RADIUS

func take_damage(amount: float) -> void:
    if not is_live_reactor() or amount <= 0.0:
        return
    grid_health = maxf(0.0, grid_health - amount)
    actual_damage_hits += 1

func status_line() -> String:
    if not active:
        return "СТАНЦИЯ ВЫВЕДЕНА ИЗ АВАРИЙНОГО РЕЖИМА"
    if stage < 2:
        return "РЕЛЕ %d/2 · УДЕРЖИВАЙ ВВОД %d%%" % [
            stage + 1, roundi(100.0 * clampf(hold_time / RELAY_HOLD, 0.0, 1.0))]
    if focus_on_capacitor and can_repair():
        return "РЕЗЕРВНЫЙ ЭЛЕМЕНТ %d%% · ЗАРЯД %d%%" % [
            roundi(100.0 * clampf(capacitor_hold / CAPACITOR_HOLD, 0.0, 1.0)),
            roundi(100.0 * grid_health / GRID_MAX)]
    return "СТАБИЛИЗАЦИЯ %d%% · ЗАРЯД %d%% · ВРЕМЯ %d С" % [
        roundi(100.0 * clampf(stabilization / STABILIZATION_SECONDS, 0.0, 1.0)),
        roundi(100.0 * grid_health / GRID_MAX), ceili(defense_remaining)]

func step(delta: float, pilot: Vector3, pressing: bool) -> String:
    if not active:
        return "inactive"
    var dt: float = clampf(delta, 0.0, 0.25)
    if stage < 2:
        hold_time = hold_time + dt if can_hold(pilot) and pressing else (
            maxf(0.0, hold_time - 2.0 * dt))
        if hold_time < RELAY_HOLD:
            return "running"
        hold_time = 0.0
        relays[stage].visible = false
        stage += 1
        if stage < 2:
            relays[stage].visible = true
            last_event = "ПЕРВОЕ РЕЛЕ ЗАПУЩЕНО · НАЙДИ ВТОРОЕ"
        else:
            reactor_online = true
            reactor.visible = true
            capacitor.visible = true
            last_event = "РЕАКТОР ЗАПУЩЕН · ОСТАНЬСЯ РЯДОМ И ЗАЩИЩАЙ ЕГО"
        return "event"
    defense_remaining = maxf(0.0, defense_remaining - dt)
    grid_health = maxf(0.0, grid_health - GRID_DRAIN_PER_SECOND * dt)
    if defense_remaining <= 0.0 or grid_health <= 0.0:
        active = false
        last_event = ("ЭНЕРГИЯ СТАНЦИИ ИСЧЕРПАНА" if grid_health <= 0.0
            else "ВРЕМЯ СТАБИЛИЗАЦИИ ИСТЕКЛО")
        return "failed"
    if can_repair() and pilot.distance_to(capacitor_position) <= CAPACITOR_RADIUS and pressing:
        capacitor_hold += dt
        if capacitor_hold >= CAPACITOR_HOLD:
            grid_health = minf(GRID_MAX, grid_health + CAPACITOR_RECOVERY)
            capacitor_used = true
            focus_on_capacitor = false
            capacitor.visible = false
            capacitor_hold = 0.0
            capacitor_events += 1
            last_event = "РЕЗЕРВНЫЙ ЭЛЕМЕНТ ПОДКЛЮЧЁН · +40 ЭНЕРГИИ"
            return "event"
    else:
        capacitor_hold = maxf(0.0, capacitor_hold - dt * 2.0)
    if pilot.distance_to(reactor.global_position) <= STABILIZATION_RADIUS:
        stabilization += dt
    else:
        stabilization = maxf(0.0, stabilization - dt * 0.8)
    if stabilization >= STABILIZATION_SECONDS:
        completed_once = true
        active = false
        stage = 3
        last_event = "СТАНЦИЯ ВОССТАНОВЛЕНА · ЭКИПАЖ СПАСЁН"
        return "success"
    return "running"
