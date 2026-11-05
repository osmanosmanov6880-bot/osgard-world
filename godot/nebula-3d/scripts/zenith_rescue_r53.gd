extends Node3D
## R53: three distinct manual antennas, a real moving survivor pod, combat extraction.
## World owns all persistent rewards and save writes.

const SCAN_COUNT: int = 3
const SCAN_HOLD: float = 1.6
const SCAN_RADIUS: float = 34.0
const ESCORT_RADIUS: float = 132.0
const POD_SPEED: float = 18.0
const POD_MAX_HEALTH: float = 90.0
const RESCUE_TIME: float = 125.0
const DOCK_RADIUS: float = 36.0
const DOCK_HOLD: float = 2.4
const EXIT_POD_RADIUS: float = 9.0

var active: bool = false
var stage: int = 0
var scans_done: int = 0
var hold_time: float = 0.0
var input_armed: bool = true
var pod_health: float = POD_MAX_HEALTH
var time_remaining: float = RESCUE_TIME
var completed_once: bool = false
var actual_damage_hits: int = 0
var travel_meters: float = 0.0
var last_event: String = ""
var scan_positions: Array[Vector3] = []
var antennae: Array[Node3D] = []
var pod_spawn: Vector3 = Vector3.ZERO
var dock_position: Vector3 = Vector3.ZERO
var rescue_pod: Node3D
var docking_terminal: Node3D

func _material(tint: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.74
    mat.roughness = 0.29
    mat.emission_enabled = true
    mat.emission = tint
    mat.emission_energy_multiplier = 1.8
    return mat

func _part(parent: Node3D, label: String,
        dimensions: Vector3, offset: Vector3, tint: Color) -> void:
    var piece := MeshInstance3D.new()
    piece.name = label
    var geometry := BoxMesh.new()
    geometry.size = dimensions
    piece.mesh = geometry
    piece.material_override = _material(tint)
    piece.position = offset
    parent.add_child(piece)

func _marker(label: String, location: Vector3, tint: Color,
        wide: bool = false) -> Node3D:
    var node := Node3D.new()
    node.name = label
    add_child(node)
    node.global_position = location
    var factor: float = 1.7 if wide else 1.0
    _part(node, "R53_RealAlloyBeacon",
        Vector3(5.0, 6.0, 5.0) * factor, Vector3.ZERO,
        Color(0.13, 0.21, 0.30))
    _part(node, "R53_RealSignalLens",
        Vector3(3.2, 2.8, 0.7) * factor,
        Vector3(0, 3.6 * factor, -2.8 * factor), tint)
    var ring := MeshInstance3D.new()
    ring.name = "R53_PhysicalCapturePerimeter"
    var torus := TorusMesh.new()
    torus.inner_radius = 11.0 if wide else SCAN_RADIUS - 1.6
    torus.outer_radius = 12.0 if wide else SCAN_RADIUS
    torus.rings = 32
    torus.ring_segments = 8
    ring.mesh = torus
    ring.position = Vector3(0, -3.0 * factor, 0)
    ring.material_override = _material(tint)
    node.add_child(ring)
    return node

func configure(center: Vector3) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    active = true
    stage = 0
    scans_done = 0
    hold_time = 0.0
    input_armed = true
    pod_health = POD_MAX_HEALTH
    time_remaining = RESCUE_TIME
    completed_once = false
    actual_damage_hits = 0
    travel_meters = 0.0
    last_event = ""
    antennae.clear()
    scan_positions = [
        center + Vector3(-102.0, 14.0, -83.0),
        center + Vector3(82.0, 20.0, -128.0),
        center + Vector3(135.0, 16.0, 51.0),
    ]
    for i in SCAN_COUNT:
        var antenna := _marker("R53_RealTriangulationAntenna_%d" % (i + 1),
            scan_positions[i], Color(0.12, 0.86, 0.97))
        antenna.visible = i == 0
        antennae.append(antenna)
    pod_spawn = center + Vector3(-20.0, 21.0, 98.0)
    dock_position = center + Vector3(205.0, 27.0, -98.0)
    rescue_pod = _marker("R53_RealMovingZenithEscapePod", pod_spawn,
        Color(0.28, 1.0, 0.67), true)
    _part(rescue_pod, "R53_ArmoredSurvivorCabin",
        Vector3(11.0, 5.5, 16.0), Vector3(0, 0.5, 0),
        Color(0.35, 0.68, 0.85))
    rescue_pod.visible = false
    docking_terminal = _marker("R53_RealManualExtractionDock", dock_position,
        Color(1.0, 0.67, 0.31))
    docking_terminal.visible = false

func objective_position() -> Vector3:
    if stage == 0 and scans_done < SCAN_COUNT:
        return scan_positions[scans_done]
    if stage == 1 and is_instance_valid(rescue_pod):
        return rescue_pod.global_position
    return dock_position

func is_escort_active() -> bool:
    return active and (stage == 1 or stage == 2) and pod_health > 0.0

func raiders_block_extraction(alive_count: int) -> bool:
    return stage == 2 and alive_count > 0

func take_damage(amount: float) -> void:
    if not is_escort_active() or amount <= 0.0:
        return
    pod_health = maxf(0.0, pod_health - amount)
    actual_damage_hits += 1

func status_line(raiders: int = 0) -> String:
    if not active:
        return "ПОЛЁТ ЗАВЕРШЁН"
    if stage == 0:
        return "ПЕЛЕНГ %d/3 · ВВОД %d%%" % [
            scans_done + 1,
            roundi(100.0 * clampf(hold_time / SCAN_HOLD, 0.0, 1.0))]
    if stage == 1:
        var remaining_distance: int = roundi(
            rescue_pod.global_position.distance_to(dock_position))
        return "КАПСУЛА %d%% · ДОК %d М · %d С" % [
            roundi(100.0 * pod_health / POD_MAX_HEALTH),
            remaining_distance, ceili(time_remaining)]
    return "ПОДАВИТЕЛЕЙ %d · ЭВАКУАЦИЯ %d%% · %d С" % [
        raiders, roundi(100.0 * clampf(hold_time / DOCK_HOLD, 0.0, 1.0)),
        ceili(time_remaining)]

func step(delta: float, pilot: Vector3, pressing: bool,
        live_raiders: int = 0) -> String:
    if not active:
        return "inactive"
    var dt: float = clampf(delta, 0.0, 0.25)
    if not pressing:
        input_armed = true
    if stage == 0:
        var nearby: bool = pilot.distance_to(
            scan_positions[scans_done]) <= SCAN_RADIUS
        hold_time = (hold_time + dt if nearby and pressing and input_armed
            else maxf(0.0, hold_time - dt * 2.0))
        if hold_time < SCAN_HOLD:
            return "running"
        antennae[scans_done].visible = false
        scans_done += 1
        hold_time = 0.0
        input_armed = false
        if scans_done < SCAN_COUNT:
            antennae[scans_done].visible = true
            last_event = "ПЕЛЕНГ %d/3 ПОЛУЧЕН · ПЕРЕЙДИ К СЛЕДУЮЩЕЙ АНТЕННЕ" % scans_done
        else:
            stage = 1
            rescue_pod.visible = true
            docking_terminal.visible = true
            last_event = "КООРДИНАТЫ «ЗЕНИТА» НАЙДЕНЫ · СОПРОВОЖДАЙ КАПСУЛУ"
        return "event"
    time_remaining = maxf(0.0, time_remaining - dt)
    if pod_health <= 0.0 or time_remaining <= 0.0:
        active = false
        last_event = ("КАПСУЛА «ЗЕНИТА» УНИЧТОЖЕНА" if pod_health <= 0.0
            else "ОКНО ЭВАКУАЦИИ ЗАКРЫЛОСЬ")
        return "failed"
    if stage == 1:
        if pilot.distance_to(rescue_pod.global_position) <= ESCORT_RADIUS:
            var before: Vector3 = rescue_pod.global_position
            rescue_pod.global_position = before.move_toward(
                dock_position, POD_SPEED * dt)
            travel_meters += before.distance_to(rescue_pod.global_position)
        if rescue_pod.global_position.distance_to(dock_position) <= EXIT_POD_RADIUS:
            rescue_pod.global_position = dock_position
            stage = 2
            hold_time = 0.0
            input_armed = false
            last_event = "КАПСУЛА В ДОКЕ · УСТРАНИ ПОДАВИТЕЛИ И ВЫВЕДИ ЭКИПАЖ"
            return "event"
        return "running"
    if stage == 2:
        var can_extract: bool = live_raiders == 0 and (
            pilot.distance_to(dock_position) <= DOCK_RADIUS) and input_armed
        hold_time = (hold_time + dt if can_extract and pressing
            else maxf(0.0, hold_time - dt * 3.0))
        if hold_time >= DOCK_HOLD:
            active = false
            stage = 3
            completed_once = true
            last_event = "ЭКИПАЖ «ЗЕНИТА» СПАСЁН · ДАННЫЕ ВОССТАНОВЛЕНЫ"
            return "success"
    return "running"
