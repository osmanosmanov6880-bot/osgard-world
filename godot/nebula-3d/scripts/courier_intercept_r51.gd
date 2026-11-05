extends Node3D
## R51 / Mission 13: physically moving data courier and time-limited extraction.
## Three different actual objectives; neither reaching an old waypoint nor
## killing drones automatically completes a stage or pays any currency.

const START_RADIUS: float = 42.0
const START_HOLD: float = 1.75
const COURIER_RANGE: float = 95.0
const TRACK_HOLD: float = 4.5
const EXTRACTION_RADIUS: float = 42.0
const EXTRACT_HOLD: float = 3.0
const EXTRACTION_DEADLINE: float = 90.0
const COURIER_ANGULAR_SPEED: float = 0.25
const PURSUIT_DEADLINE: float = 105.0
const SIGNAL_DECAY_RATE: float = 1.3
const PURSUIT_TRAIL_SEGMENTS: int = 5
const LEAD_TIME_SECONDS: float = 1.5
const LEAD_MAX_DISTANCE: float = 32.0

var active: bool = false
var stage: int = 0
var hold_time: float = 0.0
var track_time: float = 0.0
var courier_phase: float = 0.0
var extraction_remaining: float = EXTRACTION_DEADLINE
var pursuit_remaining: float = PURSUIT_DEADLINE
var lost_signal_seconds: float = 0.0
var captured_fragments: int = 0
var interference_count: int = 0
var completed_once: bool = false
var last_event: String = ""
var start_position: Vector3
var courier_center: Vector3
var extraction_position: Vector3
var start_console: Node3D
var courier: Node3D
var extraction_console: Node3D
var pursuit_trail: Array[MeshInstance3D] = []
var lead_guidance_updates: int = 0

func _material(color: Color) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.65
    mat.roughness = 0.25
    mat.emission_enabled = true
    mat.emission = color
    mat.emission_energy_multiplier = 1.45
    return mat

func _part(parent: Node3D, name: String, dimensions: Vector3, offset: Vector3,
        color: Color) -> void:
    var part := MeshInstance3D.new()
    part.name = name
    var box := BoxMesh.new()
    box.size = dimensions
    part.mesh = box
    part.material_override = _material(color)
    part.position = offset
    parent.add_child(part)

func _make_station(label: String, point: Vector3, tint: Color) -> Node3D:
    var node := Node3D.new()
    node.name = label
    add_child(node)
    node.global_position = point
    _part(node, "R51_RealPhysicalStation", Vector3(5.8, 5.0, 4.4),
        Vector3.ZERO, Color(0.12, 0.26, 0.38))
    _part(node, "R51_LiveTerminalPanel", Vector3(5.7, 3.0, 0.3),
        Vector3(0, 3.5, -2.1), tint)
    var ring := TorusMesh.new()
    ring.inner_radius = START_RADIUS - 1.2
    ring.outer_radius = START_RADIUS
    ring.rings = 32
    ring.ring_segments = 8
    var access := MeshInstance3D.new()
    access.name = "R51_ProximityAccessRing"
    access.mesh = ring
    access.material_override = _material(tint)
    access.position = Vector3(0, -5.0, 0)
    node.add_child(access)
    return node

func _build_courier() -> Node3D:
    var node := Node3D.new()
    node.name = "R51_PhysicallyMovingEncryptedCourier"
    add_child(node)
    _part(node, "R51_CourierArmoredHull", Vector3(5.0, 2.0, 8.8),
        Vector3.ZERO, Color(0.25, 0.63, 0.83))
    _part(node, "R51_CourierLeftWing", Vector3(8.5, 0.3, 2.2),
        Vector3(-4.3, 0.0, 1.8), Color(0.22, 0.52, 0.61))
    _part(node, "R51_CourierRightWing", Vector3(8.5, 0.3, 2.2),
        Vector3(4.3, 0.0, 1.8), Color(0.22, 0.52, 0.61))
    _part(node, "R51_EncryptedTransmitter", Vector3(2.0, 4.2, 2.0),
        Vector3(0.0, 2.5, 0.0), Color(1.0, 0.68, 0.2))
    return node

func _courier_path_point_at(phase: float) -> Vector3:
    return courier_center + Vector3(
        cos(phase) * 72.0,
        sin(phase * 2.0) * 9.0,
        sin(phase) * 56.0)

func _courier_path_point() -> Vector3:
    return _courier_path_point_at(courier_phase)

func _setup_pursuit_trail() -> void:
    pursuit_trail.clear()
    var glow: StandardMaterial3D = _material(Color(0.14, 0.87, 0.96))
    glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    var bead := SphereMesh.new()
    bead.radius = 1.4
    bead.height = 2.8
    bead.radial_segments = 10
    bead.rings = 5
    for i in PURSUIT_TRAIL_SEGMENTS:
        var marker := MeshInstance3D.new()
        marker.name = "R51_ActualFutureSignalTrail_%d" % (i + 1)
        marker.mesh = bead
        marker.material_override = glow
        marker.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        marker.visible = false
        add_child(marker)
        pursuit_trail.append(marker)

func _update_pursuit_trail() -> void:
    var show_trail: bool = active and stage == 1
    for i in pursuit_trail.size():
        var marker: MeshInstance3D = pursuit_trail[i]
        marker.visible = show_trail
        if show_trail:
            # Short fixed-horizon path forecast, not a waypoint teleport.
            marker.global_position = _courier_path_point_at(
                courier_phase + COURIER_ANGULAR_SPEED * float(i + 1) * 0.7)

func navigation_position(pilot_position: Vector3) -> Vector3:
    # Keep real objective_position() untouched for the 95m proximity gate,
    # beacon and HUD. Autopilot receives a bounded moving-target lead only.
    var live: Vector3 = objective_position()
    if not active or stage != 1 or not is_instance_valid(courier):
        return live
    if pilot_position.distance_to(live) < COURIER_RANGE * 0.65:
        return live
    var future: Vector3 = _courier_path_point_at(courier_phase +
        COURIER_ANGULAR_SPEED * LEAD_TIME_SECONDS)
    lead_guidance_updates += 1
    return live + (future - live).limit_length(LEAD_MAX_DISTANCE)

func configure(center: Vector3) -> void:
    for child in get_children():
        remove_child(child)
        child.queue_free()
    pursuit_trail.clear()
    lead_guidance_updates = 0
    active = true
    stage = 0
    hold_time = 0.0
    track_time = 0.0
    courier_phase = 0.0
    extraction_remaining = EXTRACTION_DEADLINE
    pursuit_remaining = PURSUIT_DEADLINE
    lost_signal_seconds = 0.0
    captured_fragments = 0
    interference_count = 0
    completed_once = false
    last_event = ""
    start_position = center + Vector3(-135.0, 13.0, 66.0)
    courier_center = center + Vector3(46.0, 26.0, 32.0)
    extraction_position = center + Vector3(215.0, 11.0, -74.0)
    start_console = _make_station("R51_PhysicalReceiverA",
        start_position, Color(0.12, 0.82, 0.92))
    extraction_console = _make_station("R51_RealTimedExtractionPad",
        extraction_position, Color(1.0, 0.68, 0.18))
    courier = _build_courier()
    courier.global_position = _courier_path_point()
    courier.visible = false
    _setup_pursuit_trail()
    extraction_console.visible = false

func objective_position() -> Vector3:
    if stage == 0:
        return start_position
    if stage == 1 and is_instance_valid(courier):
        return courier.global_position
    return extraction_position

func is_extraction_active() -> bool:
    return active and stage == 2

func can_hold(pilot: Vector3) -> bool:
    if not active:
        return false
    if stage == 0:
        return pilot.distance_to(start_position) <= START_RADIUS
    if stage == 2:
        return pilot.distance_to(extraction_position) <= EXTRACTION_RADIUS
    return false

func status_line() -> String:
    if not active:
        return "СИГНАЛ ЗАКРЫТ · ВЫЛЕТ ЗАВЕРШЁН"
    if stage == 0:
        return "ПРИЁМНИК · УДЕРЖИВАЙ %d%%" % roundi(
            clampf(hold_time / START_HOLD, 0.0, 1.0) * 100.0)
    if stage == 1:
        return "ПЕРЕХВАТ %d%% · РАДИУС %d М · ОСТАЛОСЬ %d С" % [
            roundi(clampf(track_time / TRACK_HOLD, 0.0, 1.0) * 100.0),
            roundi(COURIER_RANGE), ceili(pursuit_remaining)]
    if interference_count > 0:
        return "ЭВАКУАЦИЯ %d С · УСТРАНИ ПОМЕХИ: %d ДРОНА" % [
            ceili(extraction_remaining), interference_count]
    return "ЭВАКУАЦИЯ %d С · УДЕРЖИВАЙ ВВОД %d%%" % [
        ceili(extraction_remaining),
        roundi(clampf(hold_time / EXTRACT_HOLD, 0.0, 1.0) * 100.0)]

func step(delta: float, pilot: Vector3, holding: bool,
        nearby_interferers: int = 0) -> String:
    if not active:
        return "inactive"
    var dt: float = clampf(delta, 0.0, 0.25)
    if stage == 0:
        hold_time = (hold_time + dt if can_hold(pilot) and holding
            else maxf(0.0, hold_time - 2.0 * dt))
        if hold_time < START_HOLD:
            return "running"
        hold_time = 0.0
        stage = 1
        captured_fragments = 1
        last_event = "ШИФР ПОЛУЧЕН · СЛЕДИ ЗА ЖИВЫМ КУРЬЕРОМ"
        start_console.visible = false
        courier.visible = true
        _update_pursuit_trail()
        return "event"
    if stage == 1:
        # A moving target cannot orbit forever while the pilot farms enemies.
        # The countdown uses bounded real Godot delta and is not reset by
        # briefly leaving and re-entering the acquisition radius.
        pursuit_remaining = maxf(0.0, pursuit_remaining - dt)
        if pursuit_remaining <= 0.0:
            active = false
            last_event = "КУРЬЕР УШЁЛ · ВРЕМЯ ПЕРЕХВАТА ИСТЕКЛО"
            return "failed"
        courier_phase += dt * COURIER_ANGULAR_SPEED
        courier.global_position = _courier_path_point()
        courier.rotate_y(dt * COURIER_ANGULAR_SPEED)
        _update_pursuit_trail()
        if pilot.distance_to(courier.global_position) <= COURIER_RANGE:
            track_time += dt
            lost_signal_seconds = 0.0
        else:
            track_time = maxf(0.0, track_time - dt * SIGNAL_DECAY_RATE)
            lost_signal_seconds += dt
        if track_time < TRACK_HOLD:
            return "running"
        stage = 2
        captured_fragments = 2
        extraction_remaining = EXTRACTION_DEADLINE
        track_time = 0.0
        last_event = "КУРЬЕР ПЕРЕХВАЧЕН · ЭВАКУИРУЙ ДАННЫЕ"
        courier.visible = false
        _update_pursuit_trail()
        extraction_console.visible = true
        return "event"
    if stage == 2:
        extraction_remaining = maxf(0.0, extraction_remaining - dt)
        interference_count = maxi(0, nearby_interferers)
        if extraction_remaining <= 0.0:
            active = false
            last_event = "СВЯЗЬ ПОТЕРЯНА · ВРЕМЯ ЭВАКУАЦИИ ИСТЕКЛО"
            return "failed"
        if can_hold(pilot) and holding and interference_count == 0:
            hold_time += dt
        else:
            hold_time = maxf(0.0, hold_time - 2.0 * dt)
        if hold_time >= EXTRACT_HOLD:
            stage = 3
            captured_fragments = 3
            completed_once = true
            active = false
            last_event = "ДАННЫЕ «ЭХО» ЭВАКУИРОВАНЫ"
            return "success"
    return "running"
