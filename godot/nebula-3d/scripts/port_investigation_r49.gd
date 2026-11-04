extends Node3D
## R49 / Mission 11: genuine non-combat investigation.
## Three visible terminals each require a held manual interaction in range.
## Weapon discharge trips the silent-operation alarm. This controller never
## awards CR/XP, changes ownership, or writes save files.
const ACCESS_RADIUS: float = 37.0
const ACCESS_HOLD: float = 2.0
const TERMINAL_OFFSETS = [
    Vector3(-86.0, 0.0, -43.0),
    Vector3(27.0, 0.0, 94.0),
    Vector3(102.0, 0.0, -64.0),
]
const EVIDENCE = [
    "ЖУРНАЛ ПОРТА: ДОСТУП ПОДМЕНЁН",
    "СЛЕД СИГНАЛА: УЗЕЛ УПРАВЛЕНИЯ АВРОРЫ",
    "ПОДПИСЬ «ЭХО»: ДАННЫЕ СОХРАНЕНЫ",
]

var active: bool = false
var alarm: bool = false
var stage: int = 0
var hold_time: float = 0.0
var destination: Vector3 = Vector3.ZERO
var terminals: Array[Node3D] = []
var terminal_points: Array[Vector3] = []
var evidence_found: Array[String] = []
var last_event: String = ""
var event_count: int = 0

func _material(tint: Color, emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = 0.78
    mat.roughness = 0.27
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = tint
        mat.emission_energy_multiplier = emission
    return mat

func _box(size: Vector3) -> BoxMesh:
    var mesh := BoxMesh.new()
    mesh.size = size
    return mesh

func _piece(parent: Node3D, label: String, mesh: Mesh,
        offset: Vector3, material: Material) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = label
    item.mesh = mesh
    item.position = offset
    item.material_override = material
    parent.add_child(item)
    return item

func _build_terminal(index: int, point: Vector3) -> Node3D:
    var station := Node3D.new()
    station.name = "R49_InteractivePortTerminal_%d" % index
    add_child(station)
    station.global_position = point
    _piece(station, "R49_PhysicalTerminalStand",
        _box(Vector3(4.4, 5.0, 3.0)), Vector3.ZERO,
        _material(Color(0.14, 0.25, 0.34)))
    _piece(station, "R49_LiveEvidenceScreen",
        _box(Vector3(6.0, 3.4, 0.28)), Vector3(0, 4.1, -1.45),
        _material(Color(0.14, 0.81, 0.88), 1.6))
    _piece(station, "R49_AccessConsole",
        _box(Vector3(4.1, 0.55, 2.3)), Vector3(0, 1.4, -2.0),
        _material(Color(0.34, 0.55, 0.65), 0.35))
    var ring := TorusMesh.new()
    ring.inner_radius = ACCESS_RADIUS - 1.0
    ring.outer_radius = ACCESS_RADIUS
    ring.rings = 40
    ring.ring_segments = 6
    _piece(station, "R49_InteractionRangeRing", ring,
        Vector3(0, -6.0, 0), _material(Color(0.26, 0.70, 0.87), 0.75))
    return station

func configure(port: Vector3) -> void:
    for old_node in get_children():
        remove_child(old_node)
        old_node.queue_free()
    terminals.clear()
    terminal_points.clear()
    evidence_found.clear()
    destination = port
    stage = 0
    hold_time = 0.0
    event_count = 0
    last_event = ""
    alarm = false
    active = true
    name = "R49_RealSilentPortInvestigation"
    for i in TERMINAL_OFFSETS.size():
        var point: Vector3 = port + TERMINAL_OFFSETS[i]
        terminal_points.append(point)
        var station := _build_terminal(i, point)
        station.visible = i == 0
        terminals.append(station)

func objective_position() -> Vector3:
    if stage < terminal_points.size():
        return terminal_points[stage]
    return destination

func can_interact(pilot: Vector3) -> bool:
    return active and stage < terminal_points.size() and (
        pilot.distance_to(objective_position()) <= ACCESS_RADIUS)

func report_weapon_discharge() -> void:
    if active:
        alarm = true

func status_line() -> String:
    if alarm:
        return "ТРЕВОГА В ПОРТУ · ОПЕРАЦИЯ РАСКРЫТА"
    if not active:
        return "РАССЛЕДОВАНИЕ ЗАВЕРШЕНО"
    return "ТЕРМИНАЛ %d/3 · ЗАЖМИ T / ВВОД · %d%%" % [
        stage + 1, roundi(100.0 * clampf(hold_time / ACCESS_HOLD, 0.0, 1.0))]

func step(delta: float, pilot: Vector3, interacting: bool) -> String:
    if not active:
        return "inactive"
    if alarm:
        active = false
        return "failed"
    var dt: float = clampf(delta, 0.0, 0.25)
    if can_interact(pilot) and interacting:
        hold_time += dt
    else:
        # Letting go or leaving range interrupts a live terminal handshake.
        hold_time = maxf(0.0, hold_time - 2.0 * dt)
    if hold_time < ACCESS_HOLD:
        return "running"
    terminals[stage].visible = false
    evidence_found.append(EVIDENCE[stage])
    last_event = EVIDENCE[stage]
    event_count += 1
    stage += 1
    hold_time = 0.0
    if stage == terminal_points.size():
        active = false
        return "success"
    terminals[stage].visible = true
    return "event"
