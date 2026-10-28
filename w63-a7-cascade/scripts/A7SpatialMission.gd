extends Node3D
class_name A7SpatialMission
## W71: actual optional playable spatial narrative on original W70 physics.
## It does NOT replace, copy or alter A7CascadeCore. All decision authority
## remains the original 6-cycle puzzle. No timers that simulate a 15-min demo.

signal progress_changed(phase: int)

const PHASES := [
    "inspect_core",
    "stabilize_core",
    "inspect_relay",
    "contain_cascade",
    "return_core",
    "complete",
    "failed",
]
const CYAN := Color("78d9e0")
const GOLD := Color("ecc188")
const ALERT := Color("f07570")
const OFF := Color("576574")
const MARKER_CORE := Vector3(4.10, 2.63, 2.14)
const MARKER_RELAY := Vector3(8.0, 2.82, 20.0)
const MISSION_RU := [
    "01 / ОСМОТР РЕАКТОРА",
    "02 / СТАБИЛИЗАЦИЯ: ДВА РЕШЕНИЯ",
    "03 / ПРОВЕРКА РЕЛЕЙНОГО ЗАЛА",
    "04 / УДЕРЖИТЕ ШЕСТЬ АВАРИЙНЫХ ЦИКЛОВ",
    "05 / ВЕРНИТЕСЬ К РЕАКТОРУ",
    "МИССИЯ ПРОЙДЕНА / КОНТУР СТАБИЛЕН",
    "МИССИЯ ПРОВАЛЕНА / ОБЪЕКТ НЕ УДЕРЖАН",
]
const MISSION_EN := [
    "01 / INSPECT THE REACTOR",
    "02 / STABILIZE: TWO REAL DECISIONS",
    "03 / INSPECT THE POWER RELAY",
    "04 / SURVIVE ALL SIX INCIDENT CYCLES",
    "05 / RETURN TO THE REACTOR",
    "MISSION COMPLETE / CONTAINMENT STABLE",
    "MISSION FAILED / CONTAINMENT LOST",
]
const DETAILS_RU := [
    "Войдите в режим оператора (P). Дойдите до реакторного пульта и нажмите E.",
    "Примите два решения кнопками 1–5. Каждое действие меняет реальные параметры игры.",
    "Идите по освещённому мосту в сектор 02. Найдите релейный пульт и нажмите E.",
    "Сохраните объект в течение оставшихся циклов. Выбор действия влияет на финал.",
    "Система удержана. Вернитесь в сектор 01 и осмотрите реактор (E).",
    "Операция завершена. Победа подтверждена ядром A7, а не графическим эффектом.",
    "Перезапустите смену и заново выберите порядок решений.",
]
const DETAILS_EN := [
    "Enter physical operator mode (P). Reach the reactor console and press E.",
    "Make two real decisions using keys 1–5; each alters the actual game metrics.",
    "Walk the lit bridge into sector 02; reach the relay console and press E.",
    "Contain the remaining cycles. Your choices determine the final result.",
    "Containment held. Return to sector 01 and inspect the reactor (E).",
    "Operation confirmed by the actual A7 game engine, not a scripted graphic.",
    "Restart the shift and try a different sequence of decisions.",
]

var active: bool = false
var extended_mode: bool = false
var field_ops: A7FieldOperations
var phase: int = 0
var progress_events: int = 0
var accepted_game_decisions: int = 0
var real_inspections: int = 0
var last_inspection: String = ""
var last_action: String = ""
var baseline_event_count: int = 0
var started_ms: int = 0
var final_ms: int = 0
var outcome: String = ""
var integrity_when_first_cycle_ended: int = -1
var recent_heat: int = 62
var recent_pressure: int = 48
var recent_energy: int = 85
var native_markers: Node3D
var core_beacon: MeshInstance3D
var relay_beacon: MeshInstance3D
var core_torus: MeshInstance3D
var relay_torus: MeshInstance3D
var core_caption: Label3D
var relay_caption: Label3D
var core_material: StandardMaterial3D
var relay_material: StandardMaterial3D
var core_ring_material: StandardMaterial3D
var relay_ring_material: StandardMaterial3D
var warning_practical: OmniLight3D
var compact: bool = false
var quality: String = "hero"
var reduced_motion: bool = false
var phase_elapsed: float = 0.0
var rendered_phase_ticks: int = 0

func _beacon_material(tint: Color) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = 0.05
    m.roughness = 0.47
    m.emission_enabled = true
    m.emission = tint
    m.emission_energy_multiplier = 1.25
    return m

func _pillar(name_: String, where: Vector3, material: Material) -> MeshInstance3D:
    var m := CylinderMesh.new()
    m.top_radius = 0.08
    m.bottom_radius = 0.14
    m.height = 1.04
    m.radial_segments = 18
    var item := MeshInstance3D.new()
    item.name = name_
    item.mesh = m
    item.material_override = material
    item.position = where
    native_markers.add_child(item)
    return item

func _ring(name_: String, where: Vector3, material: Material) -> MeshInstance3D:
    var mesh := TorusMesh.new()
    mesh.inner_radius = 0.29
    mesh.outer_radius = 0.40
    mesh.rings = 36
    mesh.ring_segments = 12
    var object := MeshInstance3D.new()
    object.name = name_
    object.mesh = mesh
    object.position = where
    object.material_override = material
    native_markers.add_child(object)
    return object

func _caption(name_: String, at: Vector3) -> Label3D:
    var caption := Label3D.new()
    caption.name = name_
    caption.position = at
    caption.font_size = 44
    caption.pixel_size = 0.003
    caption.modulate = GOLD
    caption.no_depth_test = false
    native_markers.add_child(caption)
    return caption

func build() -> void:
    name = "W71OriginalFiveStageSpatialIncidentMission"
    native_markers = Node3D.new()
    native_markers.name = "OriginalPhysical3DMissionBeacons"
    add_child(native_markers)
    core_material = _beacon_material(OFF)
    relay_material = _beacon_material(OFF)
    core_ring_material = _beacon_material(OFF)
    relay_ring_material = _beacon_material(OFF)
    core_beacon = _pillar("RealReactorMissionColumn", MARKER_CORE, core_material)
    relay_beacon = _pillar("RealPowerRelayMissionColumn", MARKER_RELAY, relay_material)
    core_torus = _ring("ActualReactorObjectiveTorus",
        MARKER_CORE + Vector3(0, 0.65, 0), core_ring_material)
    relay_torus = _ring("ActualRelayObjectiveTorus",
        MARKER_RELAY + Vector3(0, 0.65, 0), relay_ring_material)
    core_caption = _caption("ReactorPhysicalObjectiveSign",
        MARKER_CORE + Vector3(0, 1.30, 0))
    relay_caption = _caption("RelayPhysicalObjectiveSign",
        MARKER_RELAY + Vector3(0, 1.30, 0))
    warning_practical = OmniLight3D.new()
    warning_practical.name = "LocalGameMissionBeaconLight"
    warning_practical.position = MARKER_CORE + Vector3(0, 0.7, 0)
    warning_practical.light_color = GOLD
    warning_practical.light_energy = 0.0
    warning_practical.omni_range = 4.1
    warning_practical.shadow_enabled = false
    native_markers.add_child(warning_practical)
    _draw_3d_status()
    set_process(true)

# Existing W71 mission remains unchanged by default.
# An explicit independent extended start opts into three physical puzzles.
func start_extended(actual_game_state: Dictionary,
        original_field_ops: A7FieldOperations) -> bool:
    if original_field_ops == null or not start(actual_game_state):
        return false
    extended_mode = true
    field_ops = original_field_ops
    field_ops.start(actual_game_state)
    return true

func start(actual_game_state: Dictionary) -> bool:
    if (active or int(actual_game_state.get("shift", -1)) != 0
            or (actual_game_state.get("history", []) as Array).size() != 0
            or str(actual_game_state.get("status", "")) != "playing"):
        return false
    active = true
    extended_mode = false
    field_ops = null
    phase = 0
    started_ms = Time.get_ticks_msec()
    final_ms = 0
    outcome = ""
    progress_events = 0
    accepted_game_decisions = 0
    real_inspections = 0
    integrity_when_first_cycle_ended = -1
    baseline_event_count = 0
    _draw_3d_status()
    progress_changed.emit(phase)
    return true

func reset() -> void:
    if field_ops != null:
        field_ops.reset()
    field_ops = null
    extended_mode = false
    active = false
    phase = 0
    progress_events = 0
    accepted_game_decisions = 0
    real_inspections = 0
    last_inspection = ""
    last_action = ""
    integrity_when_first_cycle_ended = -1
    outcome = ""
    started_ms = 0
    final_ms = 0
    baseline_event_count = 0
    _draw_3d_status()
    progress_changed.emit(phase)

func _advance(next_phase: int) -> void:
    if phase == next_phase:
        return
    phase = clampi(next_phase, 0, PHASES.size() - 1)
    progress_events += 1
    phase_elapsed = 0.0
    if phase in [5, 6]:
        final_ms = Time.get_ticks_msec()
    _draw_3d_status()
    progress_changed.emit(phase)

func inspect_physical(target: String, game_state: Dictionary,
        operator: A7FirstPersonOperator) -> bool:
    if not active or operator == null or not operator.piloting or operator.body == null:
        return false
    if not ["CORE", "RELAY"].has(target):
        return false
    # Verify physics proximity AGAIN at the mission authority boundary.
    # Merely spoofing a string, switching camera or pressing E at a distance
    # cannot advance actual spatial objectives.
    var physical_target: Vector3 = (operator.inspection_console_core
        if target == "CORE" else operator.inspection_console_relay)
    var allowed_distance: float = 3.2 if target == "CORE" else 4.0
    if operator.body.position.distance_to(physical_target) >= allowed_distance:
        return false
    # W72 extended world interactions must be physically solved BEFORE E
    # can certify a spatial objective. Legacy W71 (extended=false) is exact.
    if extended_mode and (field_ops == null or not field_ops.gate(target, phase)):
        return false
    last_inspection = target
    real_inspections += 1
    if phase == 0 and target == "CORE":
        _advance(1)
        return true
    if phase == 2 and target == "RELAY" and int(game_state["shift"]) >= 1:
        _advance(3)
        return true
    if phase == 4 and target == "CORE" and str(game_state["status"]) == "won":
        outcome = "contained"
        _advance(5)
        return true
    return false

func accepted_game_action(action: String, before: Dictionary,
        after: Dictionary) -> void:
    if not active:
        return
    # Called ONLY after A7CascadeCore.choose(action) returned true.
    accepted_game_decisions += 1
    last_action = action
    recent_heat = int((after["metrics"] as Dictionary)["heat"])
    recent_pressure = int((after["metrics"] as Dictionary)["pressure"])
    recent_energy = int((after["metrics"] as Dictionary)["energy"])
    if phase == 1 and int(before["shift"]) == 0 and int(after["shift"]) >= 1:
        integrity_when_first_cycle_ended = int((after["metrics"] as Dictionary)["integrity"])
        _advance(2)
    elif phase == 3 and str(after["status"]) == "won":
        outcome = "contained"
        _advance(4)
    elif str(after["status"]) in ["failed", "unstable"]:
        outcome = str(after["status"])
        _advance(6)
    elif str(after["status"]) == "won" and phase < 3:
        # The mission is optional, but completion can't be faked by choosing
        # game actions while skipping both spatial station objectives.
        outcome = "missed_station"
        _advance(6)

func observe_game_state(state: Dictionary) -> void:
    if not active or phase in [5, 6]:
        return
    recent_heat = int((state.get("metrics", {}) as Dictionary).get("heat", 62))
    recent_pressure = int((state.get("metrics", {}) as Dictionary).get("pressure", 48))
    recent_energy = int((state.get("metrics", {}) as Dictionary).get("energy", 85))
    if str(state["status"]) in ["failed", "unstable"]:
        outcome = str(state["status"])
        _advance(6)
    elif str(state["status"]) == "won":
        if phase == 3:
            outcome = "contained"
            _advance(4)
        elif phase < 3:
            outcome = "missed_station"
            _advance(6)

func title(locale: String) -> String:
    if not active:
        return "МИССИЯ A7 / НЕ НАЧАТА" if locale == "ru" else "MISSION A7 / NOT STARTED"
    return str(MISSION_RU[phase] if locale == "ru" else MISSION_EN[phase])

func briefing(locale: String) -> String:
    if not active:
        return ("Начните новую операцию, затем войдите в режим первого лица."
            if locale == "ru" else
            "Begin a new operation, then enter first-person operator mode.")
    return str(DETAILS_RU[phase] if locale == "ru" else DETAILS_EN[phase])

func _set_glow(material: StandardMaterial3D, tint: Color, glow: float) -> void:
    if material == null:
        return
    material.albedo_color = tint
    material.emission = tint
    material.emission_energy_multiplier = glow

func _draw_3d_status() -> void:
    if native_markers == null:
        return
    var core_target: bool = active and phase in [0, 1, 4]
    var relay_target: bool = active and phase in [2, 3]
    if phase in [5, 6]:
        core_target = true
        relay_target = true
    var core_tint: Color = GOLD if core_target else OFF
    var relay_tint: Color = CYAN if relay_target else OFF
    if phase == 6:
        core_tint = ALERT
        relay_tint = ALERT
    elif phase == 5:
        core_tint = CYAN
        relay_tint = CYAN
    _set_glow(core_material, core_tint, 2.1 if core_target else 0.35)
    _set_glow(relay_material, relay_tint, 2.1 if relay_target else 0.35)
    _set_glow(core_ring_material, core_tint, 1.5 if core_target else 0.25)
    _set_glow(relay_ring_material, relay_tint, 1.5 if relay_target else 0.25)
    core_caption.text = ("A7 / %02d / CORE" % mini(phase + 1, 5)) if active else "A7 / CORE"
    relay_caption.text = ("A7 / %02d / RELAY" % mini(phase + 1, 5)) if active else "A7 / RELAY"
    warning_practical.position = (
        MARKER_RELAY + Vector3(0, 0.7, 0)
        if relay_target and not core_target else
        MARKER_CORE + Vector3(0, 0.7, 0))
    warning_practical.light_color = ALERT if phase == 6 else CYAN if relay_target else GOLD
    warning_practical.light_energy = 0.0 if not active else (
        0.4 if quality == "eco" else 1.2)

func set_compact_view(enabled: bool) -> void:
    compact = enabled
    if core_caption != null:
        core_caption.visible = not compact
        relay_caption.visible = not compact

func set_quality(mode: String) -> void:
    quality = "eco" if mode == "eco" else "hero"
    if warning_practical != null:
        warning_practical.light_energy = (
            (0.4 if quality == "eco" else 1.2) if active else 0.0)

func set_reduced_motion(enabled: bool) -> void:
    reduced_motion = enabled
    if enabled and core_torus != null:
        core_torus.rotation.y = 0
        relay_torus.rotation.y = 0

func _process(delta: float) -> void:
    if not active or phase in [5, 6]:
        return
    phase_elapsed += delta
    if not reduced_motion:
        core_torus.rotation.y += delta * 0.13
        relay_torus.rotation.y -= delta * 0.17
        rendered_phase_ticks += 1

func qa_readout() -> Dictionary:
    var elapsed: float = 0.0
    if started_ms > 0:
        var until_ms: int = final_ms if final_ms > 0 else Time.get_ticks_msec()
        elapsed = maxf(0.0, float(until_ms - started_ms) / 1000.0)
    return {
        "schema": "LAST_FRONTIER_W71_TRUE_SPATIAL_MISSION_V1",
        "active": active,
        "extended_mode": extended_mode,
        "world_mechanics_connected": field_ops != null,
        "phase_index": phase,
        "phase": str(PHASES[phase]),
        "completed": active and phase == 5,
        "failed": active and phase == 6,
        "outcome": outcome,
        "progress_events": progress_events,
        "real_inspections": real_inspections,
        "accepted_original_actions": accepted_game_decisions,
        "first_cycle_integrity": integrity_when_first_cycle_ended,
        "core_beacon_native_mesh": core_beacon is MeshInstance3D,
        "relay_beacon_native_mesh": relay_beacon is MeshInstance3D,
        "real_3d_objective_rings": core_torus is MeshInstance3D and relay_torus is MeshInstance3D,
        "world_space_mission_text": core_caption is Label3D and relay_caption is Label3D,
        "local_actual_omni_light": warning_practical is OmniLight3D,
        "compact": compact,
        "quality": quality,
        "elapsed_real_seconds": elapsed,
        "estimated_campaign_duration_minutes": -1,
        "gameplay_authority": false,
        "outside_network_access": false,
        "production_approved": false,
    }
