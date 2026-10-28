extends Node3D
## IRON PULSE: BLACKOUT — real, player-controlled 3D vertical slice in Godot 4.4.1.
## Procedural artwork and generated UI; offline and self-contained.

# Architectural shot design: on every fresh operation the real first-person
# camera introduces the open reactor megastructure, not just a dead corridor.
const REACTOR_REVEAL_YAW := -0.52
const REACTOR_REVEAL_PITCH := 0.18
const NIGHT := Color(0.020, 0.034, 0.060)
const STEEL := Color(0.162, 0.217, 0.287)
const METAL := Color(0.235, 0.300, 0.368)
const CYAN := Color(0.13, 0.83, 0.91)
const AMBER := Color(1.0, 0.53, 0.22)
const RED := Color(0.95, 0.20, 0.25)
const WHITE := Color(0.91, 0.96, 0.98)
const DIM := Color(0.58, 0.7, 0.78)

const COPY := {
    "ru": {
        "subtitle": "BLACKOUT  /  ГЛАВА 00",
        "intro": "СИГНАЛ БЕДСТВИЯ: СЕКТОР A7\n\nВ реакторном комплексе пропало питание. Люди заблокированы внутри. У вас две независимые линии питания, но три системы: охлаждение, жизнеобеспечение и аварийные двери.\n\nВыберите, чем пожертвовать на время, чтобы открыть путь к эвакуации.\n\nWASD — движение    SHIFT — бег\nМЫШЬ — обзор    E — действие\nL — язык    F — фонарь    ESC — пауза\nM — звук    V — плавная камера    G — графика    C — камера реактора\nГЕЙМПАД: A — действие, X — срочно, B — радио, START — пауза\n\nЭто вымышленная игра, не инструкция по эксплуатации оборудования.",
        "start": "НАЧАТЬ ОПЕРАЦИЮ", "resume": "ПРОДОЛЖИТЬ", "restart": "ПОВТОРИТЬ",
        "scenario_blackout": "01 / GRID", "scenario_thermal": "02 / HEAT", "scenario_breach": "03 / AIR",
        "brief_blackout": "ОТКЛЮЧЕНИЕ ПИТАНИЯ: два контура, три системы. Изучите маршрут эвакуации.",
        "brief_thermal": "ТЕПЛОВОЙ КАСКАД: опасный перегрев и повторные импульсы. E — долгий ремонт, Q — быстрый сброс ценой кислорода и здоровья.",
        "brief_breach": "РАЗГЕРМЕТИЗАЦИЯ: кислород утекает даже с LIFE. E — полная герметизация, Q — быстрая заплатка с остаточной утечкой.",
        "repair_thermal": "02 / Стабилизировать теплообменник: E — 15 с / Q — аварийный сброс",
        "repair_breach": "02 / Герметизировать утечку: E — 10 с / Q — экстренная заплатка",
        "thermal_stabilized": "Контур стабилизирован: долгий ремонт сохранил ресурсы экипажа.",
        "thermal_purged": "Срочный сброс тепла. Потерян кислород, экипаж пострадал.",
        "breach_sealed": "Утечка устранена полностью.",
        "breach_patched": "Быстрая заплатка: экипаж пострадал, осталась микроутечка.",
        "thermal_pulse": "ТЕПЛОВОЙ ИМПУЛЬС! Повторный перегрев требует контроля.",
        "choice_hint": "{name}  {distance} м  /  [E] ТЩАТЕЛЬНО   [Q] СРОЧНО",
        "result_path": "Решение: {method}  /  Сценарий: {scenario}",
        "method_deep_stabilize": "ТОЧНАЯ СТАБИЛИЗАЦИЯ", "method_rapid_purge": "АВАРИЙНЫЙ СБРОС",
        "method_full_seal": "ПОЛНАЯ ГЕРМЕТИЗАЦИЯ", "method_rapid_patch": "БЫСТРАЯ ЗАПЛАТКА",
        "method_standard": "СТАНДАРТНЫЙ РЕМОНТ",
        "scenario_title_blackout": "IRON PULSE / BLACKOUT", "scenario_title_thermal": "IRON PULSE / HEAT", "scenario_title_breach": "IRON PULSE / AIR",
        "sector_reactor": "РЕАКТОРНАЯ ГАЛЕРЕЯ", "sector_service": "ТЕХНИЧЕСКИЙ СЕКТОР", "sector_evacuation": "ЭВАКУАЦИОННЫЙ ШЛЮЗ",
        "visited_sectors": "ИССЛЕДОВАНО СЕКТОРОВ: {count}/3",
        "continue": "ПРОДОЛЖИТЬ СОХРАНЕНИЕ", "radio_journal": "РАДИОАРХИВ / J",
        "choice_crew": "1  /  ЛЮДИ", "choice_core": "2  /  ЯДРО",
        "story_choice": "МАРА ЖДЁТ ПРИКАЗА: 1 — ЭКИПАЖ / 2 — РЕАКТОР",
        "chapter_final": "АКТ {act} / РЕШЕНИЕ: {priority}",
        "rescue_hint": "СТАНЦИЯ {name}  {distance} м  /  [E] АКТИВИРОВАТЬ",
        "rescue_spent": "СТАНЦИЯ {name}  /  РЕСУРС НЕДОСТУПЕН",
        "rescue_medbay": "МЕДИЦИНСКИЙ УЗЕЛ", "rescue_quench": "ТЕПЛОВОЙ ГАСИТЕЛЬ", "rescue_uplink": "СВЯЗЬ И ЭВАКУАЦИЯ",
        "rescue_count": "СПАСАТЕЛЬНЫЕ СТАНЦИИ {used}/2",
        "rescue_final": "Станции спасения: {used}/2",
        "relay_medbay": "МЕДБЛОК: воздух и здоровье восстановлены.",
        "relay_quench": "ГАСИТЕЛЬ: тепло снижено, импульсы ослаблены.",
        "relay_uplink": "СВЯЗЬ: получено дополнительное время.",
        "relay_budget": "ЛИМИТ: доступны только две станции спасения.",
        "pause": "ПАУЗА", "victory": "ЭВАКУАЦИЯ УСПЕШНА", "failure": "МИССИЯ ПРОВАЛЕНА",
        "scan": "01  /  Просканировать реактор A7", "repair": "02  /  Восстановить охлаждение",
        "charge": "03  /  Зарядить аварийную дверь — перенаправьте одну линию на DOOR",
        "override": "04  /  Вернуть COOLANT + LIFE и разрешить аварийный выход",
        "exit": "05  /  Достичь выходного шлюза", "victory_objective": "Экипаж спасён",
        "failure_objective": "Аварийная операция завершилась неудачей",
        "heat": "ТЕМП.", "oxygen": "КИСЛОРОД", "crew": "ЭКИПАЖ", "door": "ЗАРЯД ДВЕРИ",
        "power": "ЭНЕРГОКОНТУР", "time": "ОСТАЛОСЬ", "action": "E — ВЗАИМОДЕЙСТВОВАТЬ",
        "scan_terminal": "СКАНЕР РЕАКТОРА", "repair_terminal": "РЕМОНТ ОХЛАЖДЕНИЯ",
        "bus_a_terminal": "ЛИНИЯ ПИТАНИЯ A", "bus_b_terminal": "ЛИНИЯ ПИТАНИЯ B",
        "override_terminal": "ПУЛЬТ АВАРИЙНОГО ДОПУСКА", "exit_terminal": "ВЫХОДНОЙ ШЛЮЗ",
        "shift_started": "Связь нестабильна. Найдите реакторный сканер.",
        "core_scanned": "Сбой обнаружен: контур охлаждения повреждён.",
        "coolant_repaired": "Охлаждение восстановлено. Зарядите аварийную дверь.",
        "bus_switched": "Линия перенаправлена. Следите за температурой и кислородом.",
        "surge": "СКАЧОК НАПРЯЖЕНИЯ! Температура резко повысилась.",
        "override_authorized": "Доступ разрешён! Доберитесь до выходного шлюза.",
        "crew_evacuated": "Комплекс покинут. Экипаж выжил.",
        "action_denied": "Действие отклонено. Проверьте текущую цель и питание.",
        "reactor_overheat": "КРИТИЧЕСКИЙ ПЕРЕГРЕВ. Реактор потерян.",
        "life_support_lost": "Система жизнеобеспечения отключена слишком долго.",
        "time_expired": "Время аварийной операции истекло.",
        "flashlight": "Фонарь переключён", "language": "Язык: русский",
        "hint": "Устройство: {name}  |  {distance} м  |  [E]",
        "stats": "Время: {time} с   •   Переключений: {switches}   •   Ошибок: {faults}   •   Оценка: {grade}",
        "navigate": "МАРШРУТ  {arrow}   {distance} М  /  {node}",
        "motion_reduced": "КАМЕРА: БЕЗ ПОКАЧИВАНИЯ", "motion_normal": "КАМЕРА: КИНОРЕЖИМ",
        "audio_off": "ЗВУК: ВЫКЛ.", "audio_on": "ЗВУК: ВКЛ.",
        "quality_eco": "ГРАФИКА: ECO", "quality_hero": "ГРАФИКА: HERO",
        "footer": "IRON PULSE / BLACKOUT   •   ВЫМЫШЛЕННАЯ СИМУЛЯЦИЯ   •   БЕЗ СЕТЕВЫХ ПОДКЛЮЧЕНИЙ"
    },
    "en": {
        "subtitle": "BLACKOUT  /  CHAPTER 00",
        "intro": "DISTRESS SIGNAL: SECTOR A7\n\nPower has failed across the reactor complex. Your crew is trapped. You have two independent power buses but three systems: cooling, life support and emergency doors.\n\nChoose what to deprioritize briefly to unlock the evacuation path.\n\nWASD — move    SHIFT — sprint\nMOUSE — look    E — interact\nL — language    F — flashlight    ESC — pause\nM — audio    V — reduced motion    G — graphics    C — reactor camera\nGAMEPAD: A — use, X — fast, B — radio, START — pause\n\nFictional game only. Not real equipment instructions.",
        "start": "BEGIN OPERATION", "resume": "RESUME", "restart": "RESTART",
        "scenario_blackout": "01 / GRID", "scenario_thermal": "02 / HEAT", "scenario_breach": "03 / AIR",
        "brief_blackout": "POWER GRID FAILURE: two buses, three systems. Learn the safe route.",
        "brief_thermal": "THERMAL CASCADE: dangerous heat and recurring pulses. E — careful 15s repair; Q — rapid purge with resource loss.",
        "brief_breach": "OXYGEN BREACH: air leaks even with LIFE powered. E — permanent 10s seal; Q — quick patch with a residual leak.",
        "repair_thermal": "02 / Stabilize heat exchanger: E — 15s / Q — rapid purge",
        "repair_breach": "02 / Seal oxygen breach: E — 10s / Q — rapid patch",
        "thermal_stabilized": "Core stabilized. Careful repair preserved crew resources.",
        "thermal_purged": "Emergency heat purge. Oxygen and crew condition sacrificed.",
        "breach_sealed": "Permanent seal complete: oxygen leak eliminated.",
        "breach_patched": "Rapid patch: crew injured; micro-leak remains.",
        "thermal_pulse": "THERMAL PULSE! Watch recurring temperature spikes.",
        "choice_hint": "{name}  {distance} m  /  [E] CAREFUL   [Q] FAST",
        "result_path": "Solution: {method}  /  Scenario: {scenario}",
        "method_deep_stabilize": "PRECISION STABILIZATION", "method_rapid_purge": "EMERGENCY PURGE",
        "method_full_seal": "PERMANENT SEAL", "method_rapid_patch": "RAPID PATCH",
        "method_standard": "STANDARD REPAIR",
        "scenario_title_blackout": "IRON PULSE / BLACKOUT", "scenario_title_thermal": "IRON PULSE / HEAT", "scenario_title_breach": "IRON PULSE / AIR",
        "sector_reactor": "REACTOR GALLERY", "sector_service": "SERVICE SPINE", "sector_evacuation": "EVACUATION LOCK",
        "visited_sectors": "SECTORS EXPLORED: {count}/3",
        "continue": "CONTINUE CHECKPOINT", "radio_journal": "RADIO ARCHIVE / J",
        "choice_crew": "1  /  CREW", "choice_core": "2  /  CORE",
        "story_choice": "MARA AWAITS YOUR ORDER: 1 — CREW / 2 — REACTOR",
        "chapter_final": "ACT {act} / PRIORITY: {priority}",
        "rescue_hint": "RESCUE STATION {name}  {distance} m  /  [E] ACTIVATE",
        "rescue_spent": "RESCUE STATION {name}  /  CAPACITY EXHAUSTED",
        "rescue_medbay": "MEDICAL BAY", "rescue_quench": "HEAT SUPPRESSOR", "rescue_uplink": "EVACUATION UPLINK",
        "rescue_count": "RESCUE NETWORK {used}/2",
        "rescue_final": "Rescue stations: {used}/2",
        "relay_medbay": "MEDBAY: air and crew condition restored.",
        "relay_quench": "HEAT SUPPRESSOR: cooler core, weaker pulses.",
        "relay_uplink": "UPLINK: additional evacuation time secured.",
        "relay_budget": "CAPACITY LIMIT: only two rescue stations may run.",
        "pause": "PAUSED", "victory": "EVACUATION COMPLETE", "failure": "MISSION FAILED",
        "scan": "01  /  Scan the A7 reactor core", "repair": "02  /  Restore reactor cooling",
        "charge": "03  /  Charge the bulkhead — redirect one bus to DOOR",
        "override": "04  /  Restore COOLANT + LIFE, then authorize the bulkhead",
        "exit": "05  /  Reach the evacuation airlock", "victory_objective": "Crew evacuated",
        "failure_objective": "Emergency operation failed",
        "heat": "REACTOR", "oxygen": "OXYGEN", "crew": "CREW", "door": "BULKHEAD",
        "power": "POWER ROUTING", "time": "TIME LEFT", "action": "E — INTERACT",
        "scan_terminal": "REACTOR SCANNER", "repair_terminal": "COOLANT MAINTENANCE",
        "bus_a_terminal": "POWER BUS A", "bus_b_terminal": "POWER BUS B",
        "override_terminal": "EMERGENCY AUTHORIZATION", "exit_terminal": "EVACUATION AIRLOCK",
        "shift_started": "Signal unstable. Locate the reactor scanner.",
        "core_scanned": "Fault detected: damaged coolant loop.",
        "coolant_repaired": "Cooling restored. Charge the emergency bulkhead.",
        "bus_switched": "Power reassigned. Watch reactor heat and life support.",
        "surge": "POWER SURGE! Reactor temperature rising.",
        "override_authorized": "Access approved! Reach the evacuation airlock.",
        "crew_evacuated": "You made it out. The crew survived.",
        "action_denied": "Action denied. Check objective and current power allocation.",
        "reactor_overheat": "CRITICAL OVERHEAT. Reactor lost.",
        "life_support_lost": "Life support was offline for too long.",
        "time_expired": "The emergency response window has closed.",
        "flashlight": "Flashlight toggled", "language": "Language: English",
        "hint": "Terminal: {name}  |  {distance} m  |  [E]",
        "stats": "Elapsed: {time} s   •   Switches: {switches}   •   Errors: {faults}   •   Grade: {grade}",
        "navigate": "ROUTE  {arrow}   {distance} M  /  {node}",
        "motion_reduced": "CAMERA: REDUCED MOTION", "motion_normal": "CAMERA: CINEMATIC",
        "audio_off": "AUDIO: OFF", "audio_on": "AUDIO: ON",
        "quality_eco": "GRAPHICS: ECO", "quality_hero": "GRAPHICS: HERO",
        "footer": "IRON PULSE / BLACKOUT   •   FICTIONAL SIMULATION   •   OFFLINE BY DESIGN"
    }
}

var session: IPCrisisEngine = IPCrisisEngine.new()
var story: IPStoryDirector = IPStoryDirector.new()
var checkpoint_store: IPCheckpointStore = IPCheckpointStore.new()
var checkpoint_path: String = IPCheckpointStore.DEFAULT_PATH
var art_stage: IPCinematicStage
var reactor_atrium: IPReactorAtrium
var containment_fx: IPContainmentFX
var kinetic_iris: IPKineticIris
var world_sectors: IPWorldSectors
var audio_director: IPSoundscape
var legacy_lamps: Array[OmniLight3D] = []
var reduced_motion: bool = false
var cinematic_view: bool = false
var muted_audio: bool = false
var quality_mode: String = "hero"
var walking_phase: float = 0.0
var _terminal_active_material: StandardMaterial3D
var _terminal_idle_material: StandardMaterial3D
var player: CharacterBody3D
var camera: Camera3D
var flashlight: SpotLight3D
var reactor_core: MeshInstance3D
var exit_gate: MeshInstance3D
var reactor_rings: Array[Node3D] = []
var terminals: Array[Dictionary] = []
var relay_terminals: Array[Dictionary] = []
var _relay_ready_material: StandardMaterial3D
var _relay_done_material: StandardMaterial3D
var hud_root: Control
var brand_label: Label
var subtitle_label: Label
var guidance_label: Label
var header_panel: PanelContainer
var side_panel: PanelContainer
var prompt_panel: PanelContainer
var vitals_panel: PanelContainer
var vitals_meters: Dictionary = {}
var warning_veil: ColorRect
var objective_label: Label
var telemetry_label: Label
var allocation_label: Label
var feedback_label: Label
var interaction_label: Label
var footer_label: Label
var crosshair: Label
var intro_panel: PanelContainer
var intro_title: Label
var intro_body: Label
var intro_button: Button
var continue_button: Button
var radio_panel: PanelContainer
var radio_speaker: Label
var radio_dialogue: Label
var priority_panel: PanelContainer
var crew_priority_button: Button
var core_priority_button: Button
var journal_panel: PanelContainer
var journal_text: Label
var journal_close_button: Button
var radio_ttl: float = 0.0
var checkpoint_clock: float = 0.0
var scenario_buttons: Dictionary = {}
var scenario_brief: Label
var selected_scenario: String = "blackout"
var active_sector: String = "reactor"
var visited_sectors: Array[String] = []
var pause_panel: PanelContainer
var pause_title: Label
var resume_button: Button
var end_panel: PanelContainer
var end_title: Label
var end_stats: Label
var end_button: Button
var touch_ui: Control
var touch_moves: Dictionary = {"forward":false, "back":false, "left":false, "right":false}
var started: bool = false
var paused: bool = false
var locale: String = "ru"
var yaw: float = 0.0
var pitch: float = 0.0
var hud_elapsed: float = 0.0
var notice_time: float = 0.0
var notice_key: String = "shift_started"
var previous_event: String = ""
var runtime_seconds: float = 0.0
# Read-only browser QA/accessibility mirror; never accepts game commands.
var _web_state_element: Variant = null
# The Godot project has a 1280x720 design canvas, but responsive Web builds
# must use the browser's true CSS viewport as their CONTENT size, otherwise
# on mobile a 1280px canvas is merely scaled down and 51px buttons turn tiny.
# JavaScriptBridge is read-only here: actual controls still handle all input.
var _browser_window: Variant = null
var _browser_css_size: Vector2i = Vector2i.ZERO
var _last_web_resize_check: float = -99.0

func _ready() -> void:
    session.reset()
    story.reset(session.scenario_id)
    _make_environment()
    _make_complex()
    world_sectors = IPWorldSectors.new()
    add_child(world_sectors)
    audio_director = IPSoundscape.new()
    add_child(audio_director)
    _make_player()
    _make_hud()
    _attach_web_state()
    _sync_web_canvas_layout()
    _refresh_hud()
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _attach_web_state() -> void:
    if not OS.has_feature("web"):
        return
    var document: Variant = JavaScriptBridge.get_interface("document")
    if document == null:
        return
    var element: Variant = document.getElementById("iron-pulse-native-state")
    if element == null:
        element = document.createElement("div")
        element.setAttribute("id", "iron-pulse-native-state")
        element.setAttribute("role", "status")
        element.setAttribute("aria-live", "polite")
        element.setAttribute("style", "position:fixed;top:0;left:0;width:1px;height:1px;opacity:0;overflow:hidden;pointer-events:none")
        document.body.appendChild(element)
    _web_state_element = element
    _browser_window = JavaScriptBridge.get_interface("window")

func _sync_web_canvas_layout() -> void:
    if _web_state_element == null or _browser_window == null:
        return
    # Official Godot Window.content_scale_size is the virtual-pixel base. It
    # must follow the *real* browser size for this pixel-sized native UI.
    # Window.size (physical pixels) and content_scale_size are distinct.
    var css_w: int = int(_browser_window.innerWidth)
    var css_h: int = int(_browser_window.innerHeight)
    if css_w < 280 or css_h < 300 or css_w > 12000 or css_h > 12000:
        return
    var target := Vector2i(css_w, css_h)
    if target == _browser_css_size:
        return
    _browser_css_size = target
    var window: Window = get_window()
    if window.content_scale_size != target:
        window.content_scale_size = target
    _layout_hud()

func _publish_web_state() -> void:
    if _web_state_element == null:
        return
    var state: Dictionary = session.diagnostic_snapshot()
    state["scene"] = "IRON_PULSE_BLACKOUT"
    state["started"] = started
    state["paused"] = paused
    state["locale"] = locale
    state["player_position"] = [player.global_position.x, player.global_position.y, player.global_position.z]
    state["godot_frames_drawn"] = Engine.get_frames_drawn()
    state["viewport"] = [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
    state["css_viewport"] = [_browser_css_size.x, _browser_css_size.y]
    state["window_size"] = [get_window().size.x, get_window().size.y]
    state["content_scale_size"] = [get_window().content_scale_size.x, get_window().content_scale_size.y]
    state["touch_controls_visible"] = touch_ui.visible
    state["intro_visible"] = intro_panel.visible
    var scenario_rects: Dictionary = {}
    for scenario_key in scenario_buttons:
        scenario_rects[str(scenario_key)] = _hud_rect(scenario_buttons[scenario_key] as Control)
    state["scenario_button_rects"] = scenario_rects
    state["end_visible"] = end_panel.visible
    state["quality_mode"] = quality_mode
    state["reduced_motion"] = reduced_motion
    state["audio_muted"] = muted_audio
    state["soundscape_ready"] = audio_director != null and audio_director.ambient != null
    state["cinematic_details"] = art_stage.readout() if art_stage != null else {}
    state["reactor_atrium"] = reactor_atrium.readout() if reactor_atrium != null else {}
    state["containment_fx"] = containment_fx.readout() if containment_fx != null else {}
    state["kinetic_iris"] = kinetic_iris.readout() if kinetic_iris != null else {}
    # Read-only native material/geometry facts; Chromium QA never invents art.
    var actual_core: SphereMesh = reactor_core.mesh as SphereMesh
    var support_count: int = 0
    for child in reactor_core.get_parent().get_children():
        if child is MeshInstance3D and child.name.begins_with("OpenEnergySupport_"):
            support_count += 1
    var ring_profiles: Array[float] = []
    for pivot in reactor_rings:
        var filament: MeshInstance3D = pivot.get_child(0) as MeshInstance3D
        var mesh: TorusMesh = filament.mesh as TorusMesh
        ring_profiles.append(snappedf(mesh.outer_radius-mesh.inner_radius,0.001))
    var normal_front: Vector3 = (reactor_rings[0].get_child(0).global_transform.basis * Vector3.UP).normalized()
    var director_eye: Vector3 = (reactor_atrium.director_camera.global_position-reactor_core.global_position).normalized()
    state["reactor_hero"] = {
        "core_sphere_radius":actual_core.radius,
        "support_piers":support_count,
        "ring_profiles":ring_profiles,
        "front_light_power":reactor_atrium._lights[1].light_energy,
        "legacy_neon_over_open_bay":_count_obstructing_corridor_neon(),
        "halo_camera_alignment":absf(normal_front.dot(director_eye))
    }
    state["cinematic_view"] = cinematic_view
    state["cinematic_hud_hidden"] = cinematic_view and not header_panel.visible and not side_panel.visible and not prompt_panel.visible and not crosshair.visible
    var active_camera: Camera3D = get_viewport().get_camera_3d()
    state["active_camera"] = active_camera.name if active_camera != null else ""
    if reactor_atrium != null and reactor_atrium.director_camera != null:
        var director_direction: Vector3 = (reactor_core.global_position-reactor_atrium.director_camera.global_position).normalized()
        state["director_camera_alignment"] = (-reactor_atrium.director_camera.global_transform.basis.z).dot(director_direction)
    var to_core: Vector3 = reactor_core.global_position-camera.global_position
    state["reactor_framing_alignment"] = (-camera.global_transform.basis.z).dot(to_core.normalized()) if to_core.length() > 0.001 else -1.0
    state["world_sector"] = active_sector
    state["visited_sectors"] = visited_sectors.duplicate()
    state["world_sectors"] = world_sectors.readout() if world_sectors != null else {}
    state["story"] = story.diagnostic()
    state["relay_3d_terminals"] = relay_terminals.size()
    var real_relays: Array = []
    for relay_info in relay_terminals:
        var spot: Vector3 = relay_info["position"]
        real_relays.append([str(relay_info["id"]),spot.x,spot.z])
    state["relay_positions"] = real_relays
    state["radio_visible"] = radio_panel.visible if radio_panel != null else false
    state["priority_visible"] = priority_panel.visible if priority_panel != null else false
    state["radio_speaker"] = radio_speaker.text if radio_speaker != null else ""
    state["radio_text"] = radio_dialogue.text if radio_dialogue != null else ""
    state["priority"] = session.priority_id
    state["journal_visible"] = journal_panel.visible if journal_panel != null else false
    if journal_close_button != null:
        state["journal_close_rect"] = _hud_rect(journal_close_button)
    if continue_button != null:
        state["continue_button_visible"] = continue_button.visible
    state["vitals_visible"] = vitals_panel.visible if vitals_panel != null else false
    state["hud_rects"] = {
        "header": _hud_rect(header_panel),
        "telemetry": _hud_rect(side_panel),
        "vitals": _hud_rect(vitals_panel),
        "prompt": _hud_rect(prompt_panel)
    }
    # Independent real-canvas tests must press E, not call session methods.
    # We publish physical UI rectangles only as read-only diagnostics.
    var buttons: Dictionary = {}
    if touch_ui != null:
        for control in touch_ui.get_children():
            if control is Button:
                var rect: Rect2 = control.get_global_rect()
                buttons[str(control.text)] = [rect.position.x,rect.position.y,rect.size.x,rect.size.y]
    state["touch_button_rects"] = buttons
    _web_state_element.setAttribute("data-state", JSON.stringify(state))
    _web_state_element.textContent = "IRON PULSE BLACKOUT, " + str(state["objective"])

func _hud_rect(node: Control) -> Array:
    var rect: Rect2 = node.get_global_rect()
    return [rect.position.x,rect.position.y,rect.size.x,rect.size.y]

func _copy(key: String) -> String:
    return str(COPY[locale].get(key, key))

func _metal(c: Color, metalness: float = 0.48, emissive: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = c
    mat.metallic = metalness
    mat.roughness = 0.43
    if emissive:
        mat.emission_enabled = true
        mat.emission = c
        mat.emission_energy_multiplier = 1.4
    return mat

func _make_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = NIGHT
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.34, 0.47, 0.60)
    env.ambient_light_energy = 0.75
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-50.0, 24.0, -10.0)
    key.light_color = Color(0.58, 0.70, 0.85)
    key.light_energy = 0.9
    add_child(key)

func _box(parent: Node3D, center: Vector3, dimensions: Vector3, mat: Material, solid: bool = false) -> MeshInstance3D:
    var holder: Node3D = parent
    if solid:
        var physics := StaticBody3D.new()
        physics.position = center
        parent.add_child(physics)
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = dimensions
        collision.shape = shape
        physics.add_child(collision)
        holder = physics
    var mesh_node := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    mesh_node.mesh = mesh
    mesh_node.material_override = mat
    if not solid:
        mesh_node.position = center
    holder.add_child(mesh_node)
    return mesh_node

func _count_obstructing_corridor_neon() -> int:
    # Inspect actual 3D meshes, not a hardcoded claim. A ray toward the
    # reactor must never intersect a forgotten 12m longitudinal light bar.
    var blocked: int = 0
    for node in get_children():
        if node is MeshInstance3D:
            var beam: MeshInstance3D = node as MeshInstance3D
            if beam.mesh is BoxMesh:
                var dims: Vector3 = (beam.mesh as BoxMesh).size
                if (dims.x >= 11.5 and absf(beam.position.y-5.86)<0.02 and
                        beam.position.z > IPReactorAtrium.OPENING_Z_MIN and
                        beam.position.z < IPReactorAtrium.OPENING_Z_MAX):
                    blocked += 1
    return blocked

func _make_complex() -> void:
    var concrete := _metal(Color(0.105,0.133,0.17),0.27)
    var steel := _metal(STEEL)
    var polished := _metal(METAL)
    var amber := _metal(AMBER,0.18,true)
    var cyan := _metal(CYAN,0.12,true)
    var red := _metal(RED,0.12,true)
    _box(self,Vector3(0,-0.48,-28.0),Vector3(14,0.95,74),concrete,true)
    # V8: keep a collision-safe mission corridor but open the ceiling around
    # the reactor viewing bay. Both outer roof segments remain real colliders.
    _box(self,Vector3(0,6.2,-48.0),Vector3(14,0.55,34.0),steel,true)
    _box(self,Vector3(0,6.2,0.0),Vector3(14,0.55,18.0),steel,true)
    _box(self,Vector3(-7.0,2.8,-28.0),Vector3(0.70,6.3,74),steel,true)
    # 22m opening at the right side shows an actually tall reactor hall,
    # with its own physical guardrail preventing off-path movement.
    _box(self,Vector3(7.0,2.8,-47.75),Vector3(0.70,6.3,34.5),steel,true)
    _box(self,Vector3(7.0,2.8,0.0),Vector3(0.70,6.3,18.0),steel,true)
    _box(self,Vector3(0,2.8,-65.0),Vector3(14,6.3,0.7),steel,true)
    for index in 12:
        var depth := 2.0 - float(index) * 5.5
        _box(self,Vector3(-5.8,0.045,depth),Vector3(0.18,0.09,1.6),polished)
        _box(self,Vector3(5.8,0.045,depth),Vector3(0.18,0.09,1.6),polished)
        _box(self,Vector3(-6.3,4.6,depth),Vector3(0.18,0.18,4.0),polished)
        _box(self,Vector3(6.3,4.6,depth),Vector3(0.18,0.18,4.0),polished)
        # The abandoned roof's long neon tube used to extend directly
        # toward the physical A7 camera through the 22m roof opening,
        # appearing as a giant cyan bar across the real plasma sphere.
        # Preserve the original roof lighting ONLY in closed corridors.
        if depth < IPReactorAtrium.OPENING_Z_MIN or depth > IPReactorAtrium.OPENING_Z_MAX:
            var ceiling_pulse := _box(self,Vector3(0,5.86,depth),Vector3(12,0.14,0.15),cyan)
            ceiling_pulse.name = "ClosedRoofPulse_%02d" % index
        _box(self,Vector3(0,0.055,depth),Vector3(5.8,0.04,0.07),_metal(AMBER,0.2,true))
        var lamp := OmniLight3D.new()
        lamp.position = Vector3(0,5.4,depth)
        lamp.light_color = Color(0.19,0.63,0.83) if index % 3 != 0 else AMBER
        lamp.light_energy = 1.45
        lamp.omni_range = 12.0
        lamp.shadow_enabled = false
        add_child(lamp)
        legacy_lamps.append(lamp)
    # Neutral fill spots reveal metal silhouettes beyond neon emissive strips.
    # No shadows or new external textures; ECO still limits active light count.
    for depth in [-7.0,-29.0,-51.0]:
        var fill_light := OmniLight3D.new()
        fill_light.name = "VisualReadabilityFill"
        fill_light.position = Vector3(0,3.6,depth)
        fill_light.light_color = Color(0.63,0.77,0.92)
        fill_light.light_energy = 0.80
        fill_light.omni_range = 13.5
        fill_light.shadow_enabled = false
        add_child(fill_light)
        legacy_lamps.append(fill_light)
    for index in 9:
        var z := -3.5 - float(index)*7.0
        _box(self,Vector3(-6.2,2.7,z),Vector3(0.20,4.8,0.34),polished)
        _box(self,Vector3(-6.1,2.7,z+0.5),Vector3(0.09,0.85,0.14),red)
        if z < IPReactorAtrium.OPENING_Z_MIN or z > IPReactorAtrium.OPENING_Z_MAX:
            _box(self,Vector3(6.2,2.7,z),Vector3(0.20,4.8,0.34),polished)
            _box(self,Vector3(0,5.1,z),Vector3(13,0.23,0.22),polished)
            _box(self,Vector3(6.1,2.7,z+0.5),Vector3(0.09,0.85,0.14),red)
    _build_reactor()
    _build_terminals()
    _build_rescue_relays()
    _build_bulkhead()
    art_stage = IPCinematicStage.new()
    add_child(art_stage)
    reactor_atrium = IPReactorAtrium.new()
    add_child(reactor_atrium)
    containment_fx = IPContainmentFX.new()
    add_child(containment_fx)
    kinetic_iris = IPKineticIris.new()
    add_child(kinetic_iris)
    kinetic_iris.bind_reactor_pbr(reactor_atrium._painted)
    if reactor_core != null and reactor_atrium.core_plasma_material != null:
        reactor_core.material_override = reactor_atrium.core_plasma_material
    _terminal_active_material = _metal(Color(0.20,0.95,0.72),0.12,true)
    _terminal_idle_material = _metal(Color(0.08,0.32,0.39),0.12,true)

func _build_reactor() -> void:
    var frame := Node3D.new()
    # The original moving core is now physically inside the open side atrium:
    # same animated meshes and source-bound identifiers, new cinematic scale.
    frame.name = "A7_OriginalAnimatedCore"
    frame.position = IPReactorAtrium.CORE_CENTER
    frame.scale = Vector3.ONE * 1.55
    add_child(frame)
    # The prior solid plinth cut a heavy black bar across the actual plasma
    # shot. Four narrow manufactured support piers leave the center open.
    for side_x in [-1.0,1.0]:
        for side_z in [-1.0,1.0]:
            var pier := _box(frame,Vector3(side_x*2.35,-2.45,side_z*2.15),
                Vector3(0.40,1.25,0.56),_metal(METAL))
            pier.name = "OpenEnergySupport_%d_%d" % [int(side_x),int(side_z)]
    var core_mesh := SphereMesh.new()
    # A 20% larger original reactor sphere dominates the industrial rig.
    core_mesh.radius = 1.23
    core_mesh.height = 2.46
    reactor_core = MeshInstance3D.new()
    reactor_core.mesh = core_mesh
    reactor_core.material_override = _metal(Color(0.24,0.79,1.0),0.1,true)
    frame.add_child(reactor_core)
    for i in 3:
        var pivot := Node3D.new()
        # The legacy 90-degree X roll turned a ring EDGE-ON to the physical
        # observation camera and produced an ugly giant cyan vertical streak.
        # These three authored poses form interlocking ellipses around the
        # actual 3D plasma sphere, leaving the center clearly legible.
        pivot.rotation_degrees = Vector3.ZERO
        frame.add_child(pivot)
        var ring := MeshInstance3D.new()
        ring.name = "PlasmaFramingRing_%d" % i
        var torus := TorusMesh.new()
        torus.inner_radius = 1.72 + float(i)*0.44
        torus.outer_radius = 1.78 + float(i)*0.44
        torus.rings = 40
        torus.ring_segments = 12
        ring.mesh = torus
        var ring_tint: Color = AMBER if i==1 else Color(0.13,0.63,0.72)
        var ring_material := _metal(ring_tint,0.35,true)
        ring_material.emission_energy_multiplier = 0.90 if i == 0 else 1.08
        ring.material_override = ring_material
        var ring_orientations: Array[Vector3] = [
            Vector3(0.0,0.0,90.0),
            Vector3(18.0,24.0,62.0),
            Vector3(-25.0,-25.0,117.0)
        ]
        ring.rotation_degrees = ring_orientations[i]
        pivot.add_child(ring)
        reactor_rings.append(pivot)
    for i in 6:
        var angle: float = TAU * float(i) / 6.0
        var p := Vector3(cos(angle)*3.0, sin(angle)*2.0, 0)
        _box(frame,p,Vector3(0.35,0.3,0.55),_metal(METAL))
    var halo := OmniLight3D.new()
    halo.light_color = Color(0.23,0.65,0.78)
    halo.light_energy = 2.85
    halo.omni_range = 11.5
    frame.add_child(halo)

func _build_terminals() -> void:
    var locations: Array[Dictionary] = [
        {"id":"scan","key":"scan_terminal","point":Vector3(-3.0,1.0,-15.5)},
        {"id":"repair","key":"repair_terminal","point":Vector3(3.0,1.0,-28.0)},
        {"id":"bus_a","key":"bus_a_terminal","point":Vector3(-3.0,1.0,-36.0)},
        {"id":"bus_b","key":"bus_b_terminal","point":Vector3(3.0,1.0,-36.0)},
        {"id":"override","key":"override_terminal","point":Vector3(0,1.0,-46.0)},
        {"id":"exit","key":"exit_terminal","point":Vector3(0,1.0,-56.0)}
    ]
    for info in locations:
        var pos: Vector3 = info["point"]
        var terminal := Node3D.new()
        terminal.name = "Terminal_" + str(info["id"])
        terminal.position = pos
        add_child(terminal)
        _box(terminal,Vector3.ZERO,Vector3(1.9,1.7,0.45),_metal(METAL))
        _box(terminal,Vector3(0,0,0.251),Vector3(1.61,1.25,0.06),_metal(NIGHT,0.08))
        var indicator: MeshInstance3D = _box(terminal,Vector3(0,0.48,0.29),Vector3(1.48,0.11,0.07),_metal(CYAN,0.1,true))
        _box(terminal,Vector3(0,-0.35,0.3),Vector3(1.35,0.18,0.07),_metal(AMBER,0.1,true))
        var label3d := Label3D.new()
        label3d.name = "TerminalName"
        label3d.text = str(info["id"]).to_upper().replace("_"," ")
        label3d.position = Vector3(0,0.0,0.38)
        label3d.font_size = 42
        label3d.pixel_size = 0.0025
        label3d.modulate = WHITE
        terminal.add_child(label3d)
        terminals.append({"id":info["id"],"key":info["key"],"position":pos,"indicator":indicator,"label":label3d})

func _build_rescue_relays() -> void:
    # Physically optional second puzzle system in all three existing sectors.
    # Three separate real terminal nodes, only two may actually be activated.
    var positions: Array[Dictionary] = [
        {"id":"medbay","key":"rescue_medbay","point":Vector3(-4.2,1.0,-23.0)},
        {"id":"quench","key":"rescue_quench","point":Vector3(4.2,1.0,-39.5)},
        {"id":"uplink","key":"rescue_uplink","point":Vector3(-4.2,1.0,-53.0)}
    ]
    _relay_ready_material = _metal(Color(0.97,0.66,0.30),0.13,true)
    _relay_done_material = _metal(Color(0.16,0.74,0.52),0.12,true)
    for info in positions:
        var relay := Node3D.new()
        relay.name = "RescueRelay_" + str(info["id"])
        relay.position = info["point"]
        add_child(relay)
        _box(relay,Vector3.ZERO,Vector3(1.65,1.7,0.40),_metal(METAL))
        var surface: MeshInstance3D = _box(relay,Vector3(0,0.05,0.25),Vector3(1.48,1.20,0.055),_metal(NIGHT,0.05))
        surface.name = "RelayConsoleScreen"
        var indicator: MeshInstance3D = _box(relay,Vector3(0,0.59,0.29),Vector3(1.43,0.13,0.07),_relay_ready_material)
        indicator.name = "RelayStatusLight"
        var marker := Label3D.new()
        marker.name = "OptionalRelayName"
        marker.text = str(info["id"]).to_upper()
        marker.font_size = 42
        marker.pixel_size = 0.0023
        marker.position = Vector3(0,-0.02,0.38)
        marker.modulate = WHITE
        relay.add_child(marker)
        relay_terminals.append({
            "id":info["id"],"key":info["key"],
            "position":info["point"],"indicator":indicator,
            "node":relay
        })

func _build_bulkhead() -> void:
    _box(self,Vector3(-3.5,2.7,-59.0),Vector3(2.5,5.4,1.1),_metal(METAL))
    _box(self,Vector3(3.5,2.7,-59.0),Vector3(2.5,5.4,1.1),_metal(METAL))
    _box(self,Vector3(0,5.4,-59.0),Vector3(4.5,0.7,1.1),_metal(METAL))
    exit_gate = _box(self,Vector3(0,2.6,-58.9),Vector3(3.65,4.9,0.5),_metal(RED,0.55,true))
    exit_gate.name = "EvacuationGateVisual"

func _make_player() -> void:
    player = CharacterBody3D.new()
    player.name = "Operator"
    player.position = Vector3(0,1.1,2.0)
    add_child(player)
    var collision := CollisionShape3D.new()
    var capsule := CapsuleShape3D.new()
    capsule.radius = 0.36
    capsule.height = 1.86
    collision.shape = capsule
    player.add_child(collision)
    camera = Camera3D.new()
    camera.name = "FirstPersonCamera"
    camera.position = Vector3(0,0.62,0)
    camera.fov = 76.0
    camera.current = true
    player.add_child(camera)
    flashlight = SpotLight3D.new()
    flashlight.name = "OperatorFlashlight"
    flashlight.light_color = WHITE
    flashlight.light_energy = 1.55
    flashlight.spot_range = 19.0
    flashlight.spot_angle = 30.0
    flashlight.shadow_enabled = false
    flashlight.visible = false
    camera.add_child(flashlight)
    yaw = REACTOR_REVEAL_YAW
    pitch = REACTOR_REVEAL_PITCH
    player.rotation.y = yaw
    camera.rotation.x = pitch

func _panel(parent: Control, location: Rect2, anchors: Rect2, bg: Color) -> PanelContainer:
    var panel := PanelContainer.new()
    panel.anchor_left = anchors.position.x
    panel.anchor_top = anchors.position.y
    panel.anchor_right = anchors.size.x
    panel.anchor_bottom = anchors.size.y
    panel.offset_left = location.position.x
    panel.offset_top = location.position.y
    panel.offset_right = location.size.x
    panel.offset_bottom = location.size.y
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = Color(0.20,0.47,0.57,0.80)
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 9
    style.content_margin_bottom = 9
    panel.add_theme_stylebox_override("panel",style)
    parent.add_child(panel)
    return panel

func _label(parent: Node, words: String, font_size: int, tint: Color) -> Label:
    var label := Label.new()
    label.text = words
    label.add_theme_color_override("font_color",tint)
    label.add_theme_font_size_override("font_size",font_size)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label

func _make_hud() -> void:
    var layer := CanvasLayer.new()
    layer.name = "GameplayHUD"
    layer.layer = 10
    add_child(layer)
    hud_root = Control.new()
    hud_root.name = "Interface"
    hud_root.set_anchors_preset(Control.PRESET_FULL_RECT)
    hud_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
    layer.add_child(hud_root)
    warning_veil = ColorRect.new()
    warning_veil.name = "ReactorRiskVeil"
    warning_veil.color = Color(0.68,0.08,0.11,0.0)
    warning_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
    warning_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_root.add_child(warning_veil)
    header_panel = _panel(hud_root,Rect2(17,14,544,139),Rect2(0,0,0,0),Color(0.015,0.029,0.050,0.91))
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation",1)
    header_panel.add_child(col)
    brand_label = _label(col,"IRON PULSE",29,CYAN)
    subtitle_label = _label(col,_copy("subtitle"),12,AMBER)
    objective_label = _label(col,"",17,WHITE)
    guidance_label = _label(col,"",12,AMBER)
    var side := _panel(hud_root,Rect2(17,154,366,295),Rect2(0,0,0,0),Color(0.014,0.028,0.048,0.89))
    side_panel = side
    var metrics := VBoxContainer.new()
    side.add_child(metrics)
    telemetry_label = _label(metrics,"",15,WHITE)
    allocation_label = _label(metrics,"",16,CYAN)
    vitals_panel = _panel(hud_root,Rect2(-365,17,-17,276),Rect2(1,0,1,0),Color(0.014,0.029,0.048,0.92))
    var vitals := VBoxContainer.new()
    vitals.add_theme_constant_override("separation",4)
    vitals_panel.add_child(vitals)
    _label(vitals,"A7 / SYSTEM TELEMETRY",15,AMBER)
    _make_vital_meter(vitals,"heat","01  /  REACTOR TEMP",RED)
    _make_vital_meter(vitals,"oxygen","02  /  LIFE SUPPORT",CYAN)
    _make_vital_meter(vitals,"crew","03  /  CREW CONDITION",Color(0.26,0.87,0.62))
    _make_vital_meter(vitals,"door","04  /  BULKHEAD CAPACITOR",Color(0.97,0.67,0.27))
    prompt_panel = _panel(hud_root,Rect2(17,-128,545,-62),Rect2(0,1,0,1),Color(0.015,0.029,0.048,0.90))
    var lower_col := VBoxContainer.new()
    prompt_panel.add_child(lower_col)
    interaction_label = _label(lower_col,"",17,CYAN)
    feedback_label = _label(lower_col,"",15,AMBER)
    footer_label = _label(hud_root,_copy("footer"),11,DIM)
    footer_label.anchor_left = 0.0
    footer_label.anchor_right = 1.0
    footer_label.anchor_top = 1.0
    footer_label.anchor_bottom = 1.0
    footer_label.offset_left = 22.0
    footer_label.offset_top = -43.0
    footer_label.offset_right = -20.0
    footer_label.offset_bottom = -8.0
    crosshair = _label(hud_root,"+",26,CYAN)
    crosshair.anchor_left = 0.5
    crosshair.anchor_right = 0.5
    crosshair.anchor_top = 0.5
    crosshair.anchor_bottom = 0.5
    crosshair.offset_left = -7
    crosshair.offset_top = -14
    crosshair.offset_right = 24
    crosshair.offset_bottom = 30
    _make_overlays()
    _make_touch_controls()
    _make_radio_ui()
    get_viewport().size_changed.connect(_layout_hud)
    _layout_hud()

func _make_vital_meter(parent: VBoxContainer, key: String, caption: String, tint: Color) -> void:
    _label(parent,caption,11,DIM)
    var meter := ProgressBar.new()
    meter.name = "Vital_" + key
    meter.max_value = 100.0
    meter.show_percentage = false
    meter.custom_minimum_size = Vector2(190,9)
    meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var bg := StyleBoxFlat.new()
    bg.bg_color = Color(0.06,0.12,0.18)
    meter.add_theme_stylebox_override("background",bg)
    var fill := StyleBoxFlat.new()
    fill.bg_color = tint
    meter.add_theme_stylebox_override("fill",fill)
    parent.add_child(meter)
    vitals_meters[key] = meter

func _make_overlays() -> void:
    intro_panel = _panel(hud_root,Rect2(-310,-275,310,275),Rect2(0.5,0.5,0.5,0.5),Color(0.012,0.029,0.055,0.98))
    intro_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var start_box := VBoxContainer.new()
    start_box.add_theme_constant_override("separation",8)
    intro_panel.add_child(start_box)
    intro_title = _label(start_box,"IRON PULSE / BLACKOUT",29,CYAN)
    var scenario_row := HBoxContainer.new()
    scenario_row.name = "ScenarioPicker"
    scenario_row.add_theme_constant_override("separation",6)
    start_box.add_child(scenario_row)
    for scenario_key in IPCrisisEngine.SCENARIOS:
        var choice := Button.new()
        choice.name = "Scenario_" + scenario_key
        choice.text = _copy("scenario_" + scenario_key)
        choice.custom_minimum_size = Vector2(100,42)
        choice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        choice.add_theme_font_size_override("font_size",13)
        choice.toggle_mode = true
        choice.pressed.connect(_select_scenario.bind(scenario_key))
        scenario_row.add_child(choice)
        scenario_buttons[scenario_key] = choice
    scenario_brief = _label(start_box,"",12,AMBER)
    scenario_brief.custom_minimum_size = Vector2(0,44)
    var intro_scroll := ScrollContainer.new()
    intro_scroll.name = "BriefingScroll"
    intro_scroll.custom_minimum_size = Vector2(0,192)
    intro_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    start_box.add_child(intro_scroll)
    intro_body = _label(intro_scroll,_copy("intro"),15,WHITE)
    intro_body.custom_minimum_size.x = 500.0
    intro_button = Button.new()
    intro_button.text = _copy("start")
    intro_button.custom_minimum_size = Vector2(0,50)
    intro_button.pressed.connect(start_run)
    start_box.add_child(intro_button)
    continue_button = Button.new()
    continue_button.name = "ContinueCheckpoint"
    continue_button.text = _copy("continue")
    continue_button.custom_minimum_size = Vector2(0,46)
    continue_button.pressed.connect(_continue_checkpoint)
    start_box.add_child(continue_button)
    continue_button.visible = DisplayServer.get_name() != "headless" and not checkpoint_store.load_checkpoint(checkpoint_path).is_empty()
    _update_scenario_picker()
    pause_panel = _panel(hud_root,Rect2(-240,-120,240,120),Rect2(0.5,0.5,0.5,0.5),Color(0.012,0.029,0.055,0.98))
    pause_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var pause_box := VBoxContainer.new()
    pause_box.add_theme_constant_override("separation",20)
    pause_panel.add_child(pause_box)
    pause_title = _label(pause_box,_copy("pause"),30,AMBER)
    resume_button = Button.new()
    resume_button.text = _copy("resume")
    resume_button.custom_minimum_size = Vector2(0,56)
    resume_button.pressed.connect(_resume)
    pause_box.add_child(resume_button)
    pause_panel.visible = false
    end_panel = _panel(hud_root,Rect2(-300,-160,300,160),Rect2(0.5,0.5,0.5,0.5),Color(0.012,0.029,0.055,0.99))
    end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var end_box := VBoxContainer.new()
    end_box.add_theme_constant_override("separation",22)
    end_panel.add_child(end_box)
    end_title = _label(end_box,"",29,CYAN)
    end_stats = _label(end_box,"",15,WHITE)
    end_button = Button.new()
    end_button.text = _copy("restart")
    end_button.custom_minimum_size = Vector2(0,55)
    end_button.pressed.connect(_restart)
    end_box.add_child(end_button)
    end_panel.visible = false

func _touch_button(parent: Control, text_value: String, x: float, y: float, width: float, move_key: String = "") -> Button:
    var btn := Button.new()
    btn.text = text_value
    btn.anchor_left = 0.0
    btn.anchor_right = 0.0
    btn.anchor_top = 1.0
    btn.anchor_bottom = 1.0
    btn.offset_left = x
    btn.offset_top = y
    btn.offset_right = x + width
    btn.offset_bottom = y + 51.0
    btn.add_theme_font_size_override("font_size",19)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.020,0.046,0.072,0.93)
    normal.border_color = Color(0.26,0.67,0.75,0.85)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(10)
    btn.add_theme_stylebox_override("normal",normal)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color(0.10,0.34,0.41,0.97)
    btn.add_theme_stylebox_override("pressed",pressed)
    btn.add_theme_color_override("font_color",WHITE)
    parent.add_child(btn)
    if move_key != "":
        btn.button_down.connect(func() -> void: touch_moves[move_key] = true)
        btn.button_up.connect(func() -> void: touch_moves[move_key] = false)
    return btn

func _make_touch_controls() -> void:
    touch_ui = Control.new()
    touch_ui.name = "TouchControls"
    touch_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
    touch_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hud_root.add_child(touch_ui)
    _touch_button(touch_ui,"W",66,-242,55,"forward")
    _touch_button(touch_ui,"A",6,-186,55,"left")
    _touch_button(touch_ui,"S",66,-186,55,"back")
    _touch_button(touch_ui,"D",126,-186,55,"right")
    var use := _touch_button(touch_ui,"USE / E",216,-186,94)
    use.pressed.connect(_interact)
    var look := _touch_button(touch_ui,"L / RU-EN",216,-242,94)
    look.pressed.connect(_toggle_language)
    var fast := _touch_button(touch_ui,"FAST / Q",216,-299,94)
    fast.pressed.connect(_fast_interact)
    var archive := _touch_button(touch_ui,"J / LOG",216,-357,94)
    archive.pressed.connect(_toggle_journal)

func _make_radio_ui() -> void:
    radio_panel = _panel(hud_root,Rect2(-420,-207,-18,-78),Rect2(1,1,1,1),Color(0.014,0.027,0.047,0.94))
    radio_panel.name = "MaraLiveRadio"
    var radio_box := VBoxContainer.new()
    radio_box.add_theme_constant_override("separation",4)
    radio_panel.add_child(radio_box)
    radio_speaker = _label(radio_box,"MARA / CONTROL",12,CYAN)
    radio_dialogue = _label(radio_box,"",14,WHITE)
    radio_dialogue.custom_minimum_size = Vector2(0,70)
    radio_panel.visible = false

    priority_panel = _panel(hud_root,Rect2(-420,-282,-18,-218),Rect2(1,1,1,1),Color(0.065,0.046,0.035,0.96))
    priority_panel.name = "StoryPriorityDecision"
    var priority_row := HBoxContainer.new()
    priority_row.add_theme_constant_override("separation",8)
    priority_panel.add_child(priority_row)
    crew_priority_button = Button.new()
    crew_priority_button.name = "ProtectCrew"
    crew_priority_button.text = _copy("choice_crew")
    crew_priority_button.custom_minimum_size = Vector2(0,46)
    crew_priority_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    crew_priority_button.pressed.connect(_choose_priority.bind("crew"))
    priority_row.add_child(crew_priority_button)
    core_priority_button = Button.new()
    core_priority_button.name = "StabilizeCore"
    core_priority_button.text = _copy("choice_core")
    core_priority_button.custom_minimum_size = Vector2(0,46)
    core_priority_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    core_priority_button.pressed.connect(_choose_priority.bind("core"))
    priority_row.add_child(core_priority_button)
    priority_panel.visible = false

    journal_panel = _panel(hud_root,Rect2(-300,-243,300,243),Rect2(0.5,0.5,0.5,0.5),Color(0.008,0.019,0.035,0.985))
    journal_panel.name = "RadioJournal"
    journal_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var journal_box := VBoxContainer.new()
    journal_box.add_theme_constant_override("separation",12)
    journal_panel.add_child(journal_box)
    _label(journal_box,_copy("radio_journal"),24,CYAN)
    var scroll := ScrollContainer.new()
    scroll.custom_minimum_size = Vector2(0,310)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    journal_box.add_child(scroll)
    journal_text = _label(scroll,"",14,WHITE)
    journal_text.custom_minimum_size.x = 510.0
    journal_close_button = Button.new()
    journal_close_button.text = "J / ESC"
    journal_close_button.custom_minimum_size = Vector2(0,48)
    journal_close_button.pressed.connect(_toggle_journal)
    journal_box.add_child(journal_close_button)
    journal_panel.visible = false

func _layout_hud() -> void:
    if hud_root == null:
        return
    var width: float = get_viewport().get_visible_rect().size.x
    # Browser CSS pixels are the authority for touch targets and typography.
    if _browser_css_size.x > 0:
        width = float(_browser_css_size.x)
    var narrow: bool = width < 650.0
    touch_ui.visible = width < 850.0 or DisplayServer.is_touchscreen_available()
    vitals_panel.visible = width >= 1000.0
    subtitle_label.visible = not narrow
    if narrow and quality_mode == "hero" and art_stage != null:
        quality_mode = "eco"
        art_stage.set_quality("eco")
        for i in range(legacy_lamps.size()):
            legacy_lamps[i].visible = i % 3 == 0
        if world_sectors != null:
            world_sectors.set_quality("eco")
        if reactor_atrium != null:
            reactor_atrium.set_quality("eco")
        if containment_fx != null:
            containment_fx.set_quality("eco")
        if kinetic_iris != null:
            kinetic_iris.set_quality("eco")
    # Compact non-overlapping card hierarchy; the center is reserved for 3D.
    header_panel.offset_left = 17.0 if not narrow else 12.0
    header_panel.offset_right = minf(544.0,width-16.0)
    header_panel.offset_top = 14.0
    header_panel.offset_bottom = 139.0 if not narrow else 115.0
    side_panel.offset_left = 17.0 if not narrow else 12.0
    side_panel.offset_right = minf(366.0,width-16.0)
    side_panel.offset_top = 154.0 if not narrow else 130.0
    side_panel.offset_bottom = 295.0 if not narrow else 274.0
    prompt_panel.offset_left = 17.0 if not narrow else 12.0
    prompt_panel.offset_right = minf(545.0,width-16.0)
    prompt_panel.offset_top = -128.0
    prompt_panel.offset_bottom = -62.0
    intro_body.custom_minimum_size.x = minf(500.0,width-66.0)
    intro_title.add_theme_font_size_override("font_size",20 if narrow else 29)
    intro_body.add_theme_font_size_override("font_size",13 if narrow else 15)
    brand_label.add_theme_font_size_override("font_size",20 if narrow else 27)
    objective_label.add_theme_font_size_override("font_size",15 if narrow else 17)
    guidance_label.add_theme_font_size_override("font_size",11 if narrow else 12)
    telemetry_label.add_theme_font_size_override("font_size",12 if narrow else 14)
    allocation_label.add_theme_font_size_override("font_size",12 if narrow else 14)
    interaction_label.add_theme_font_size_override("font_size",12 if narrow else 17)
    feedback_label.add_theme_font_size_override("font_size",12 if narrow else 15)
    footer_label.add_theme_font_size_override("font_size",9 if narrow else 11)
    intro_panel.offset_left = -minf(310.0,width*0.45)
    intro_panel.offset_right = minf(310.0,width*0.45)
    end_panel.offset_left = -minf(300.0,width*0.45)
    end_panel.offset_right = minf(300.0,width*0.45)
    objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    if radio_panel == null:
        return
    # Bottom right on desktop; card stack after telemetry on narrow screens.
    var radio_anchor: float = 0.0 if narrow else 1.0
    for overlay in [radio_panel,priority_panel]:
        overlay.anchor_left = radio_anchor
        overlay.anchor_right = radio_anchor
        overlay.anchor_top = radio_anchor
        overlay.anchor_bottom = radio_anchor
    if narrow:
        radio_panel.offset_left = 12.0
        radio_panel.offset_right = width-12.0
        radio_panel.offset_top = 295.0
        radio_panel.offset_bottom = 390.0
        priority_panel.offset_left = 12.0
        priority_panel.offset_right = width-12.0
        priority_panel.offset_top = 401.0
        priority_panel.offset_bottom = 464.0
    else:
        radio_panel.offset_left = -420.0
        radio_panel.offset_right = -18.0
        radio_panel.offset_top = -207.0
        radio_panel.offset_bottom = -78.0
        priority_panel.offset_left = -420.0
        priority_panel.offset_right = -18.0
        priority_panel.offset_top = -282.0
        priority_panel.offset_bottom = -218.0
    var journal_half_width: float = minf(300.0,width*0.46)
    journal_panel.offset_left = -journal_half_width
    journal_panel.offset_right = journal_half_width
    journal_text.custom_minimum_size.x = journal_half_width*2.0-58.0
    radio_dialogue.add_theme_font_size_override("font_size",12 if narrow else 14)
    _refresh_radio_ui()
    _apply_cinematic_view()

func _apply_cinematic_view() -> void:
    # One-key playable environment inspection. No movement, game timers,
    # controls or original narrative data are modified by this camera HUD mode.
    if header_panel == null:
        return
    header_panel.visible = not cinematic_view
    side_panel.visible = not cinematic_view
    prompt_panel.visible = not cinematic_view
    crosshair.visible = not cinematic_view
    footer_label.visible = not cinematic_view
    var display_width: float = float(_browser_css_size.x) if _browser_css_size.x > 0 else get_viewport().get_visible_rect().size.x
    vitals_panel.visible = not cinematic_view and display_width >= 1000.0
    if cinematic_view:
        radio_panel.visible = false
        priority_panel.visible = false
        # Switch to a physical security camera overlooking the actual 3D
        # reactor. Preserve the player body, timer, mission and checkpoints.
        if reactor_atrium != null and reactor_atrium.director_camera != null:
            reactor_atrium.director_camera.make_current()
    elif camera != null:
        camera.make_current()

func _refresh_radio_ui() -> void:
    if radio_panel == null:
        return
    var line: Dictionary = story.latest(locale)
    if not line.is_empty():
        radio_speaker.text = str(line["speaker"]) + "   /   ACT " + str(line["act"])
        radio_dialogue.text = str(line["text"])
    radio_panel.visible = started and not paused and not journal_panel.visible and not cinematic_view and radio_ttl > 0.0
    priority_panel.visible = started and not paused and not session.finished() and session.core_scanned and session.priority_id == "" and not journal_panel.visible and not cinematic_view
    crew_priority_button.text = _copy("choice_crew")
    core_priority_button.text = _copy("choice_core")
    journal_text.text = story.journal_localized(locale)
    if continue_button != null:
        continue_button.text = _copy("continue")

func _story_event(event_name: String) -> void:
    if story.on_game_event(event_name,session.priority_id):
        radio_ttl = 11.0
    _refresh_radio_ui()

func _choose_priority(choice: String) -> void:
    if not started or paused or session.finished():
        return
    if session.choose_priority(choice):
        previous_event = session.last_event
        _story_event(session.last_event)
        _announce(session.last_event)
        _save_checkpoint()
        _refresh_hud()

func _toggle_journal() -> void:
    if not started or session.finished():
        return
    if paused and not journal_panel.visible:
        return
    journal_panel.visible = not journal_panel.visible
    paused = journal_panel.visible
    pause_panel.visible = false
    audio_director.set_active(not paused)
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)
    _refresh_radio_ui()

func _checkpoint_payload() -> Dictionary:
    return {
        "schema":"IRON_PULSE_CAMPAIGN_V6",
        "engine":session.checkpoint(),
        "story":story.checkpoint(),
        "scenario":selected_scenario,
        "locale":locale,
        "quality":quality_mode,
        "reduced_motion":reduced_motion,
        "player_position":[player.position.x,player.position.y,player.position.z],
        "visited_sectors":visited_sectors.duplicate()
    }

func _save_checkpoint() -> bool:
    # A headless CI test never writes the shared user checkpoint slot.
    if DisplayServer.get_name() == "headless" or not started or session.finished():
        return false
    return checkpoint_store.save(_checkpoint_payload(),checkpoint_path)

func _continue_checkpoint() -> bool:
    var payload: Dictionary = checkpoint_store.load_checkpoint(checkpoint_path)
    if payload.get("schema") != "IRON_PULSE_CAMPAIGN_V6":
        return false
    if not payload.get("engine",null) is Dictionary or not payload.get("story",null) is Dictionary:
        return false
    var restored_engine := IPCrisisEngine.new()
    var restored_story := IPStoryDirector.new()
    if not restored_engine.restore_checkpoint(payload["engine"]):
        return false
    if not restored_story.restore(payload["story"]):
        return false
    if restored_engine.finished() or restored_engine.scenario_id != restored_story.scenario:
        return false
    if payload.get("scenario") != restored_engine.scenario_id:
        return false
    var pos: Variant = payload.get("player_position",null)
    if not pos is Array or pos.size() != 3:
        return false
    for index in 3:
        if typeof(pos[index]) not in [TYPE_INT,TYPE_FLOAT]:
            return false
    var safe_pos := Vector3(float(pos[0]),float(pos[1]),float(pos[2]))
    if absf(safe_pos.x) > 6.5 or safe_pos.y < -0.2 or safe_pos.y > 5.0 or safe_pos.z < -59.0 or safe_pos.z > 5.0:
        return false
    var saved_zones: Variant = payload.get("visited_sectors",null)
    if not saved_zones is Array or saved_zones.size() > 3:
        return false
    var checked_zones: Array[String] = []
    for zone in saved_zones:
        if not zone is String or zone not in IPWorldSectors.SECTORS or checked_zones.has(zone):
            return false
        checked_zones.append(zone)
    var saved_quality: String = str(payload.get("quality","hero"))
    if saved_quality not in ["hero","eco"]:
        return false
    var saved_locale: String = str(payload.get("locale","ru"))
    if saved_locale not in ["ru","en"] or typeof(payload.get("reduced_motion",null)) != TYPE_BOOL:
        return false
    # Now, after atomic validation, restore all gameplay and authored story state.
    cinematic_view = false
    _apply_cinematic_view()
    session = restored_engine
    story = restored_story
    selected_scenario = session.scenario_id
    locale = saved_locale
    quality_mode = saved_quality
    reduced_motion = bool(payload["reduced_motion"])
    player.position = safe_pos
    player.velocity = Vector3.ZERO
    active_sector = world_sectors.current_sector(player.global_position.z)
    visited_sectors = checked_zones
    if not visited_sectors.has(active_sector):
        visited_sectors.append(active_sector)
    art_stage.set_quality(quality_mode)
    world_sectors.set_quality(quality_mode)
    reactor_atrium.set_quality(quality_mode)
    containment_fx.set_quality(quality_mode)
    kinetic_iris.set_quality(quality_mode)
    exit_gate.position.y = 6.2 if session.override_set else 2.6
    for index in range(legacy_lamps.size()):
        legacy_lamps[index].visible = quality_mode == "hero" or index % 3 == 0
    previous_event = session.last_event
    started = true
    paused = false
    intro_panel.visible = false
    pause_panel.visible = false
    end_panel.visible = false
    radio_ttl = 11.0
    _update_scenario_picker()
    _refresh_hud()
    _refresh_radio_ui()
    audio_director.set_active(true)
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
    return true

func _update_scenario_picker() -> void:
    if scenario_brief == null:
        return
    intro_title.text = _copy("scenario_title_" + selected_scenario)
    scenario_brief.text = _copy("brief_" + selected_scenario)
    for mode_id in IPCrisisEngine.SCENARIOS:
        var button: Button = scenario_buttons[mode_id]
        button.text = _copy("scenario_" + mode_id)
        button.button_pressed = mode_id == selected_scenario

func _select_scenario(next_scenario: String) -> void:
    if started or not IPCrisisEngine.SCENARIOS.has(next_scenario):
        return
    selected_scenario = next_scenario
    session.reset(next_scenario)
    story.reset(next_scenario)
    radio_ttl = 0.0
    notice_time = 0.0
    _update_scenario_picker()
    _refresh_hud()

func _fast_interact() -> void:
    _interact(true)

func start_run() -> void:
    cinematic_view = false
    _apply_cinematic_view()
    story.reset(selected_scenario)
    radio_ttl = 12.0
    checkpoint_clock = 0.0
    started = true
    paused = false
    intro_panel.visible = false
    pause_panel.visible = false
    end_panel.visible = false
    _announce("shift_started")
    _refresh_radio_ui()
    _save_checkpoint()
    audio_director.set_active(true)
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _restart() -> void:
    cinematic_view = false
    _apply_cinematic_view()
    session.reset(selected_scenario)
    story.reset(selected_scenario)
    radio_ttl = 12.0
    checkpoint_clock = 0.0
    if DisplayServer.get_name() != "headless":
        checkpoint_store.clear(checkpoint_path)
    visited_sectors.clear()
    active_sector = "reactor"
    player.position = Vector3(0,1.1,2.0)
    player.velocity = Vector3.ZERO
    exit_gate.position = Vector3(0,2.6,-58.9)
    walking_phase = 0.0
    camera.position = Vector3(0,0.62,0)
    yaw = REACTOR_REVEAL_YAW
    pitch = REACTOR_REVEAL_PITCH
    player.rotation.y = yaw
    camera.rotation.x = pitch
    started = true
    paused = false
    end_panel.visible = false
    _announce("shift_started")
    _refresh_radio_ui()
    _save_checkpoint()
    audio_director.set_active(true)
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _resume() -> void:
    paused = false
    pause_panel.visible = false
    audio_director.set_active(true)
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _pause_toggle() -> void:
    if not started or session.finished():
        return
    paused = not paused
    pause_panel.visible = paused
    audio_director.set_active(not paused)
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE if paused else Input.MOUSE_MODE_CAPTURED)

func _toggle_language() -> void:
    locale = "en" if locale == "ru" else "ru"
    intro_body.text = _copy("intro")
    intro_button.text = _copy("start")
    _update_scenario_picker()
    pause_title.text = _copy("pause")
    resume_button.text = _copy("resume")
    end_button.text = _copy("restart")
    footer_label.text = _copy("footer")
    _announce("language")
    _refresh_hud()
    _refresh_radio_ui()

func _gamepad_axis(axis_id: int) -> float:
    var joypads: Array[int] = Input.get_connected_joypads()
    if joypads.is_empty():
        return 0.0
    var reading: float = Input.get_joy_axis(joypads[0],axis_id)
    return reading if absf(reading) >= 0.18 else 0.0

func _gamepad_button(button_index: int) -> void:
    # Hardware performance/compatibility still requires real controller QA.
    # This dispatch handles Godot's mapped standard gamepad button events.
    if button_index == JOY_BUTTON_START:
        if not started:
            start_run()
        else:
            _pause_toggle()
        return
    if button_index == JOY_BUTTON_B:
        _toggle_journal()
        return
    if not started or paused:
        return
    if session.finished():
        if button_index == JOY_BUTTON_A:
            _restart()
        return
    match button_index:
        JOY_BUTTON_A:
            _interact()
        JOY_BUTTON_X:
            _fast_interact()
        JOY_BUTTON_Y:
            flashlight.visible = not flashlight.visible
            _announce("flashlight")
        JOY_BUTTON_DPAD_UP:
            _choose_priority("crew")
        JOY_BUTTON_DPAD_DOWN:
            _choose_priority("core")

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton and event.pressed:
        _gamepad_button(event.button_index)
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_L:
            _toggle_language()
            return
        if event.keycode == KEY_M:
            muted_audio = not muted_audio
            audio_director.set_muted(muted_audio)
            _announce("audio_off" if muted_audio else "audio_on")
            return
        if event.keycode == KEY_V:
            reduced_motion = not reduced_motion
            walking_phase = 0.0
            _announce("motion_reduced" if reduced_motion else "motion_normal")
            return
        if event.keycode == KEY_G:
            quality_mode = "eco" if quality_mode == "hero" else "hero"
            art_stage.set_quality(quality_mode)
            world_sectors.set_quality(quality_mode)
            reactor_atrium.set_quality(quality_mode)
            containment_fx.set_quality(quality_mode)
            kinetic_iris.set_quality(quality_mode)
            for i in range(legacy_lamps.size()):
                legacy_lamps[i].visible = quality_mode == "hero" or i % 3 == 0
            _announce("quality_eco" if quality_mode == "eco" else "quality_hero")
            return
        if event.keycode == KEY_C and started and not paused and not session.finished():
            cinematic_view = not cinematic_view
            _apply_cinematic_view()
            if not cinematic_view:
                _refresh_radio_ui()
            return
        if event.keycode == KEY_J:
            if cinematic_view:
                cinematic_view = false
                _apply_cinematic_view()
            _toggle_journal()
            return
        if event.keycode == KEY_ESCAPE:
            if journal_panel.visible:
                _toggle_journal()
            else:
                _pause_toggle()
            return
        if not started and event.keycode in [KEY_1, KEY_2, KEY_3]:
            var choice_index: int = [KEY_1, KEY_2, KEY_3].find(event.keycode)
            _select_scenario(IPCrisisEngine.SCENARIOS[choice_index])
            return
        if event.keycode == KEY_ENTER and not started:
            start_run()
            return
        if not started or paused:
            return
        if session.finished():
            if event.keycode == KEY_R:
                _restart()
            return
        if event.keycode == KEY_1 or event.keycode == KEY_2:
            _choose_priority("crew" if event.keycode == KEY_1 else "core")
            return
        if event.keycode == KEY_E:
            _interact()
        elif event.keycode == KEY_Q:
            _interact(true)
        elif event.keycode == KEY_F:
            flashlight.visible = not flashlight.visible
            _announce("flashlight")
    if not started or paused or session.finished():
        return
    if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
        _look(event.relative)
    elif event is InputEventScreenDrag and event.position.x > get_viewport().get_visible_rect().size.x*0.53:
        _look(event.relative)
    elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
        if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and DisplayServer.get_name() != "headless":
            Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _look(motion: Vector2) -> void:
    yaw -= motion.x * 0.0021
    pitch = clampf(pitch-motion.y*0.0021,-1.27,1.27)
    player.rotation.y = yaw
    camera.rotation.x = pitch

func _physics_process(delta: float) -> void:
    if not started or paused or session.finished():
        return
    var horizontal: float = float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A))
    var vertical: float = float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W))
    horizontal += float(touch_moves["right"]) - float(touch_moves["left"]) + _gamepad_axis(JOY_AXIS_LEFT_X)
    vertical += float(touch_moves["back"]) - float(touch_moves["forward"]) + _gamepad_axis(JOY_AXIS_LEFT_Y)
    var stick := Vector2(horizontal,vertical).limit_length(1.0)
    var world_direction: Vector3 = player.global_basis * Vector3(stick.x,0,stick.y)
    var speed: float = 7.1 if Input.is_key_pressed(KEY_SHIFT) else 4.9
    var accelerate: float = 15.0 if stick.length() > 0.05 else 20.0
    player.velocity.x = move_toward(player.velocity.x,world_direction.x*speed,accelerate*delta)
    player.velocity.z = move_toward(player.velocity.z,world_direction.z*speed,accelerate*delta)
    if not player.is_on_floor():
        player.velocity.y -= 12.0*delta
    else:
        player.velocity.y = -0.05
    player.move_and_slide()
    session.tick(delta)
    if session.last_event != previous_event:
        previous_event = session.last_event
        if session.last_event != "shift_started":
            _story_event(session.last_event)
            _announce(session.last_event)
    if session.finished():
        _show_end()

func _process(delta: float) -> void:
    runtime_seconds += delta
    if OS.has_feature("web") and runtime_seconds - _last_web_resize_check >= 0.4:
        _last_web_resize_check = runtime_seconds
        _sync_web_canvas_layout()
    if started and not paused and not session.finished():
        var pad_look := Vector2(_gamepad_axis(JOY_AXIS_RIGHT_X),_gamepad_axis(JOY_AXIS_RIGHT_Y))
        if pad_look.length() >= 0.18:
            _look(pad_look*delta*690.0)
        var moving: bool = Vector2(player.velocity.x,player.velocity.z).length() > 0.65
        if moving and not reduced_motion:
            walking_phase += delta * (10.8 if Input.is_key_pressed(KEY_SHIFT) else 7.3)
        var bob: float = sin(walking_phase)*0.021 if moving and not reduced_motion else 0.0
        camera.position.y = lerpf(camera.position.y,0.62 + bob,minf(delta*9.0,1.0))
        var fov_target: float = 77.0
        if Input.is_key_pressed(KEY_SHIFT) and moving and not reduced_motion:
            fov_target = 81.5
        camera.fov = lerpf(camera.fov,fov_target,minf(delta*4.0,1.0))
    art_stage.update_danger(session.heat,session.oxygen,runtime_seconds,reduced_motion)
    world_sectors.update_hazard(session.scenario_id,session.heat,session.oxygen,reduced_motion)
    reactor_atrium.update_alarm(session.scenario_id,session.heat,session.oxygen,runtime_seconds,reduced_motion)
    containment_fx.update_from_crisis(
        session.scenario_id,session.heat,session.oxygen,runtime_seconds,
        reduced_motion,session.thermal_pulses,session.thermal_shield,
        started and not paused and not session.finished())
    kinetic_iris.update_from_crisis(
        session.scenario_id,session.heat,session.oxygen,runtime_seconds,
        reduced_motion,session.thermal_pulses,session.thermal_shield,
        started and not paused and not session.finished())
    if started and not paused and not session.finished():
        var sector: String = world_sectors.current_sector(player.global_position.z)
        if sector != active_sector:
            active_sector = sector
            if story.enter_sector(sector):
                radio_ttl = 11.0
                _refresh_radio_ui()
        if not visited_sectors.has(sector):
            visited_sectors.append(sector)
            _save_checkpoint()
    audio_director.set_tension(session.heat,session.oxygen)
    var heat_risk: float = clampf((session.heat-70.0)/30.0,0.0,1.0)
    var air_risk: float = clampf((45.0-session.oxygen)/45.0,0.0,1.0)
    warning_veil.color = Color(0.66,0.08,0.09,0.14*maxf(heat_risk,air_risk))
    if not paused:
        for i in reactor_rings.size():
            reactor_rings[i].rotation.z += (0.12 if i%2==0 else -0.19)*delta
        if reactor_core != null:
            var scale_factor: float = 1.0 + sin(runtime_seconds*2.5)*0.05
            reactor_core.scale = Vector3.ONE*scale_factor
        if exit_gate != null and session.override_set:
            exit_gate.position.y = lerpf(exit_gate.position.y,6.2,minf(delta*1.8,1.0))
    if notice_time > 0.0:
        notice_time -= delta
    if radio_ttl > 0.0 and not paused:
        radio_ttl = maxf(0.0,radio_ttl-delta)
    if started and not paused and not session.finished():
        checkpoint_clock += delta
        if checkpoint_clock >= 18.0:
            checkpoint_clock = 0.0
            _save_checkpoint()
    hud_elapsed += delta
    if hud_elapsed > 0.12:
        hud_elapsed = 0.0
        _refresh_hud()

func _nearest_terminal() -> Dictionary:
    if player == null:
        return {}
    var closest: Dictionary = {}
    var nearest: float = 3.15
    for terminal in terminals:
        var pos: Vector3 = terminal["position"]
        var a := Vector2(pos.x,pos.z)
        var b := Vector2(player.global_position.x,player.global_position.z)
        var dist: float = a.distance_to(b)
        if dist < nearest:
            nearest = dist
            closest = terminal
    return closest

func _nearest_relay() -> Dictionary:
    if player == null:
        return {}
    var chosen: Dictionary = {}
    var nearest: float = 3.0
    for relay in relay_terminals:
        var where: Vector3 = relay["position"]
        var dist: float = Vector2(where.x,where.z).distance_to(Vector2(player.global_position.x,player.global_position.z))
        if dist < nearest:
            nearest = dist
            chosen = relay
    return chosen

func _physical_distance(point: Vector3) -> float:
    return Vector2(point.x,point.z).distance_to(Vector2(player.global_position.x,player.global_position.z))

func _interact(fast: bool = false) -> void:
    if not started or paused or session.finished():
        return
    var target: Dictionary = _nearest_terminal()
    var rescue: Dictionary = _nearest_relay()
    if not rescue.is_empty() and not fast:
        var main_distance: float = _physical_distance(target["position"]) if not target.is_empty() else 999.0
        var rescue_distance: float = _physical_distance(rescue["position"])
        if rescue_distance < main_distance:
            var activated: bool = session.activate_relay(str(rescue["id"]))
            previous_event = session.last_event
            if activated:
                _story_event(session.last_event)
            elif session.relays_activated.size() >= IPCrisisEngine.MAX_RELAYS:
                _story_event("relay_budget")
            _announce(session.last_event)
            _save_checkpoint()
            _refresh_hud()
            return
    if target.is_empty():
        return
    var terminal_id: String = str(target["id"])
    if fast and terminal_id != "repair":
        return
    match terminal_id:
        "scan":
            session.scan_core()
        "repair":
            if fast:
                session.emergency_repair()
            else:
                session.repair_coolant()
        "bus_a":
            session.cycle_bus(0)
        "bus_b":
            session.cycle_bus(1)
        "override":
            session.activate_override()
        "exit":
            session.escape()
    previous_event = session.last_event
    _story_event(session.last_event)
    _announce(session.last_event)
    _save_checkpoint()
    if session.finished():
        _show_end()
    _refresh_hud()

func _announce(key: String) -> void:
    notice_key = key
    notice_time = 4.0
    if audio_director == null or not started:
        return
    match key:
        "surge", "thermal_pulse", "reactor_overheat", "life_support_lost", "time_expired":
            audio_director.cue("surge")
        "crew_evacuated":
            audio_director.cue("victory")
        "action_denied":
            audio_director.cue("denied")
        "core_scanned", "coolant_repaired", "thermal_stabilized", "thermal_purged", "breach_sealed", "breach_patched", "bus_switched", "override_authorized", "relay_medbay", "relay_quench", "relay_uplink":
            audio_director.cue("confirm")

func _show_end() -> void:
    cinematic_view = false
    _apply_cinematic_view()
    if end_panel.visible:
        return
    end_panel.visible = true
    if DisplayServer.get_name() != "headless":
        checkpoint_store.clear(checkpoint_path)
    end_title.text = _copy("victory") if session.won else _copy("failure")
    var template: String = _copy("stats")
    end_stats.text = template.format({"time":"%.0f" % session.elapsed,"switches":session.switches,"faults":session.faults,"grade":session.grade()})
    var method_key: String = "method_" + session.repair_method
    var method_name: String = _copy(method_key) if session.repair_method != "" else "-"
    end_stats.text += "\n" + _copy("result_path").format({
        "method":method_name,"scenario":_copy("scenario_" + session.scenario_id)})
    end_stats.text += "\n" + _copy("visited_sectors").format({"count":visited_sectors.size()})
    end_stats.text += "\n" + _copy("chapter_final").format({
        "act":story.act,"priority":session.priority_id if session.priority_id != "" else "-"})
    end_stats.text += "\n" + _copy("rescue_final").format({"used":session.relays_activated.size()})
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _refresh_hud() -> void:
    if objective_label == null:
        return
    var objective_key: String = session.objective_id()
    if objective_key == "victory":
        objective_key = "victory_objective"
    elif objective_key == "failure":
        objective_key = "failure_objective"
    var display_key: String = objective_key
    if objective_key == "repair" and session.scenario_id != "blackout":
        display_key = "repair_" + session.scenario_id
    objective_label.text = _copy(display_key)
    subtitle_label.text = _copy("scenario_title_" + selected_scenario)
    if started:
        subtitle_label.text += " / " + _copy("sector_" + active_sector)
    _update_guidance(objective_key)
    _update_terminal_highlights(objective_key)
    telemetry_label.text = "%s  %d°C    |    %s  %d%%\n%s  %d%%    |    %s  %d%%    |    %s  %02d:%02d" % [
        _copy("heat"),int(session.heat),_copy("oxygen"),int(session.oxygen),
        _copy("crew"),int(session.crew_health),_copy("door"),int(session.door_charge),
        _copy("time"),floori(session.time_left/60.0),int(session.time_left)%60]
    allocation_label.text = "%s  /  A: %s   |   B: %s\n%s" % [
        _copy("power"),session.bus_a.to_upper(),session.bus_b.to_upper(),
        _copy("rescue_count").format({"used":session.relays_activated.size()})]
    (vitals_meters["heat"] as ProgressBar).value = session.heat
    (vitals_meters["oxygen"] as ProgressBar).value = session.oxygen
    (vitals_meters["crew"] as ProgressBar).value = session.crew_health
    (vitals_meters["door"] as ProgressBar).value = session.door_charge
    var nearby: Dictionary = _nearest_terminal()
    var rescue: Dictionary = _nearest_relay()
    var show_rescue: bool = not rescue.is_empty()
    if show_rescue and not nearby.is_empty():
        show_rescue = _physical_distance(rescue["position"]) < _physical_distance(nearby["position"])
    if started and not session.finished() and show_rescue:
        var relay_dist: float = _physical_distance(rescue["position"])
        var available: bool = session.core_scanned and not session.relays_activated.has(str(rescue["id"])) and session.relays_activated.size() < IPCrisisEngine.MAX_RELAYS
        var rescue_key: String = "rescue_hint" if available else "rescue_spent"
        interaction_label.text = _copy(rescue_key).format({
            "name":_copy(str(rescue["key"])),"distance":"%.1f" % relay_dist})
    elif not nearby.is_empty() and started and not session.finished():
        var at: Vector3 = nearby["position"]
        var dist: float = _physical_distance(at)
        var hint_key: String = "choice_hint" if str(nearby["id"]) == "repair" and session.scenario_id != "blackout" and not session.coolant_repaired else "hint"
        interaction_label.text = _copy(hint_key).format({"name":_copy(str(nearby["key"])),"distance":"%.1f" % dist})
    else:
        interaction_label.text = _copy("action") if started and not session.finished() else ""
    feedback_label.text = _copy(notice_key) if notice_time > 0.0 else ""
    if session.heat >= 80.0 or session.oxygen < 30.0:
        telemetry_label.add_theme_color_override("font_color",RED)
    else:
        telemetry_label.add_theme_color_override("font_color",WHITE)
    # Keep operator telemetry visible in both RU and EN without font dependence.
    brand_label.text = "IRON PULSE"
    _refresh_radio_ui()
    _publish_web_state()

func _update_guidance(objective_key: String) -> void:
    if not started or session.finished():
        guidance_label.text = ""
        return
    var goal_id: String = objective_key
    if objective_key == "charge":
        goal_id = "bus_a" if player.global_position.x <= 0.0 else "bus_b"
    var target_pos: Vector3 = Vector3.ZERO
    var target_name: String = ""
    for info in terminals:
        if str(info["id"]) == goal_id:
            target_pos = info["position"]
            target_name = _copy(str(info["key"]))
            break
    if target_name == "":
        guidance_label.text = ""
        return
    var toward: Vector3 = target_pos-player.global_position
    toward.y = 0.0
    var distance: float = toward.length()
    var direction: Vector3 = toward.normalized() if distance > 0.01 else Vector3.FORWARD
    var forward: Vector3 = -player.global_transform.basis.z
    var dot_value: float = forward.dot(direction)
    var turn: float = forward.cross(direction).y
    var arrow: String = "FWD" if dot_value > 0.6 else "BACK" if dot_value < -0.6 else "LEFT" if turn > 0.0 else "RIGHT"
    guidance_label.text = _copy("navigate").format({"arrow":arrow,"distance":"%.0f" % distance,"node":target_name})

func _update_terminal_highlights(objective_key: String) -> void:
    for info in terminals:
        var key: String = str(info["id"])
        var active: bool = key == objective_key or (objective_key == "charge" and (key == "bus_a" or key == "bus_b"))
        var indicator: MeshInstance3D = info["indicator"]
        var material: StandardMaterial3D = _terminal_active_material if active else _terminal_idle_material
        if indicator.material_override != material:
            indicator.material_override = material
    for relay in relay_terminals:
        var indicator: MeshInstance3D = relay["indicator"]
        var activated: bool = session.relays_activated.has(str(relay["id"]))
        var material: StandardMaterial3D = _relay_done_material if activated else _relay_ready_material
        if indicator.material_override != material:
            indicator.material_override = material
