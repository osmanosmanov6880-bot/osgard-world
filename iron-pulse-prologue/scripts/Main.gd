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
        "intro": "СИГНАЛ БЕДСТВИЯ: СЕКТОР A7\n\nВ реакторном комплексе пропало питание. Люди заблокированы внутри. У вас две независимые линии питания, но три системы: охлаждение, жизнеобеспечение и аварийные двери.\n\nВыберите, чем пожертвовать на время, чтобы открыть путь к эвакуации.\n\nWASD — движение    SHIFT — бег\nМЫШЬ — обзор    E — действие\nL — язык    F — фонарь    ESC — пауза\nM — звук    V — плавная камера    G — графика    K — автонастройка    C — камера реактора    P — следующий план    F3 — диагностика\nH — показать / скрыть 3D-цель    T — прогноз энергосистемы\nГЕЙМПАД: A — действие, X — срочно, B — радио, START — пауза\n\nЭто вымышленная игра, не инструкция по эксплуатации оборудования.",
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
        "field_sink_terminal": "ТЕПЛОВОЙ ЯКОРЬ",
        "field_air_terminal": "РЕЗЕРВ ВОЗДУХА",
        "field_hint": "ПОЛЕВАЯ СТАНЦИЯ {name}  {distance} м  /  [E] ВЫБРАТЬ 1 ИЗ 2",
        "field_spent": "ПОЛЕВОЙ ПРОТОКОЛ: ВЫБОР ЗАФИКСИРОВАН",
        "field_final": "Полевой протокол: {protocol}",
        "field_none": "НЕ ИСПОЛЬЗОВАН",
        "field_sink": "ТЕПЛОВОЙ ЯКОРЬ: температура снижена ценой кислорода.",
        "field_air": "РЕЗЕРВ ВОЗДУХА: воздух восстановлен ценой нагрева и здоровья.",
        "campaign_start": "КАМПАНИЯ / ТРИ АВАРИИ",
        "campaign_next": "СЛЕДУЮЩАЯ ОПЕРАЦИЯ",
        "campaign_replay": "ПЕРЕИГРАТЬ КАМПАНИЮ",
        "campaign_progress": "ОПЕРАЦИЯ {index}/3",
        "campaign_carry": "НАСЛЕДИЕ РЕШЕНИЙ: ресурсы следующей операции изменены",
        "wayfinder_on": "3D-НАВИГАЦИЯ: ВКЛ.",
        "wayfinder_off": "3D-НАВИГАЦИЯ: ВЫКЛ.",
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
        "auto_on": "АВТОГРАФИКА: АКТИВНА / РЕАЛЬНЫЕ КАДРЫ", "auto_off": "АВТОГРАФИКА: ВЫКЛ.",
        "auto_reduce": "АВТО: ECO / НЕСТАБИЛЬНОЕ ВРЕМЯ КАДРА", "auto_recover": "АВТО: HERO / СТАБИЛЬНЫЕ КАДРЫ",
        "footer": "IRON PULSE / BLACKOUT   •   ВЫМЫШЛЕННАЯ СИМУЛЯЦИЯ   •   БЕЗ СЕТЕВЫХ ПОДКЛЮЧЕНИЙ"
    },
    "en": {
        "subtitle": "BLACKOUT  /  CHAPTER 00",
        "intro": "DISTRESS SIGNAL: SECTOR A7\n\nPower has failed across the reactor complex. Your crew is trapped. You have two independent power buses but three systems: cooling, life support and emergency doors.\n\nChoose what to deprioritize briefly to unlock the evacuation path.\n\nWASD — move    SHIFT — sprint\nMOUSE — look    E — interact\nL — language    F — flashlight    ESC — pause\nM — audio    V — reduced motion    G — graphics    K — adaptive quality    C — reactor camera    P — next shot    F3 — diagnostics\nH — show / hide 3D objective    T — power-route forecast\nGAMEPAD: A — use, X — fast, B — radio, START — pause\n\nFictional game only. Not real equipment instructions.",
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
        "field_sink_terminal": "HEAT SINK",
        "field_air_terminal": "AIR BUFFER",
        "field_hint": "FIELD STATION {name}  {distance} m  /  [E] CHOOSE ONE OF TWO",
        "field_spent": "FIELD PROTOCOL: CHOICE ALREADY LOCKED",
        "field_final": "Field protocol: {protocol}",
        "field_none": "NOT USED",
        "field_sink": "HEAT SINK: core cooler, oxygen spent.",
        "field_air": "AIR BUFFER: oxygen restored at a cost to heat and crew.",
        "campaign_start": "CAMPAIGN / THREE EMERGENCIES",
        "campaign_next": "NEXT OPERATION",
        "campaign_replay": "REPLAY CAMPAIGN",
        "campaign_progress": "OPERATION {index}/3",
        "campaign_carry": "PREVIOUS CHOICES: next operation resources have changed",
        "wayfinder_on": "3D WAYFINDING: ON",
        "wayfinder_off": "3D WAYFINDING: OFF",
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
        "auto_on": "AUTO GRAPHICS: ON / REAL FRAME MEASUREMENTS", "auto_off": "AUTO GRAPHICS: OFF",
        "auto_reduce": "AUTO: ECO / SLOW LOCAL FRAME PACING", "auto_recover": "AUTO: HERO / STABLE LOCAL FRAMES",
        "footer": "IRON PULSE / BLACKOUT   •   FICTIONAL SIMULATION   •   OFFLINE BY DESIGN"
    }
}

var session: IPCrisisEngine = IPCrisisEngine.new()
var story: IPStoryDirector = IPStoryDirector.new()
var checkpoint_store: IPCheckpointStore = IPCheckpointStore.new()
var checkpoint_path: String = IPCheckpointStore.DEFAULT_PATH
var campaign: IPCampaignFlow = IPCampaignFlow.new()
var world_launch: Dictionary = IPWorldLaunch.parse("")
var performance_audit: IPPerformanceAudit = IPPerformanceAudit.new()
var device_lab: IPDeviceLab = IPDeviceLab.new()
var _lab_preexisting_pause: bool = false
var adaptive_performance: IPAdaptivePerformance = IPAdaptivePerformance.new()
var adaptive_sampling_clock: float = 0.0
var threat_radar: IPThreatRadar = IPThreatRadar.new()
var after_action_review: IPAfterActionReview = IPAfterActionReview.new()
var operator_guide: IPOperatorGuide = IPOperatorGuide.new()
var black_box_report: Dictionary = {}
var run_archive: IPRunArchive = IPRunArchive.new()
var archive_last_save_ok: bool = false
var archive_erase_armed: bool = false
var archive_erase_failed: bool = false
var decision_forecaster: IPDecisionForecast = IPDecisionForecast.new()
var forecast_report: Dictionary = {}
var forecast_update_clock: float = 0.0
const CAMPAIGN_RECORD_PATH: String = "user://iron_pulse_campaign_progress_v9.json"
var art_stage: IPCinematicStage
var reactor_atrium: IPReactorAtrium
var containment_fx: IPContainmentFX
var wayfinder: IPWayfinding
var campaign_echoes: IPCampaignEchoes
var world_sectors: IPWorldSectors
var obsidian_world: IPObsidianArchitecture
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
var field_stations: Array[Dictionary] = []
var _field_ready_material: StandardMaterial3D
var _field_done_material: StandardMaterial3D
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
var threat_label: Label
var quality_state_label: Label
var feedback_label: Label
var interaction_label: Label
var footer_label: Label
var crosshair: Label
var intro_panel: PanelContainer
var intro_title: Label
var intro_body: Label
var intro_button: Button
var continue_button: Button
var campaign_button: Button
var archive_intro_button: Button
var archive_end_button: Button
var archive_panel: PanelContainer
var archive_label: Label
var archive_title: Label
var archive_erase_button: Button
var archive_close_button: Button
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
var auto_quality_button: Button
var end_panel: PanelContainer
var end_title: Label
var end_stats: Label
var end_button: Button
var debrief_button: Button
var debrief_panel: PanelContainer
var debrief_title: Label
var debrief_label: Label
var debrief_close_button: Button
var touch_ui: Control
var touch_shot_button: Button
var diagnostic_panel: PanelContainer
var diagnostic_label: Label
var forecast_panel: PanelContainer
var forecast_label: Label
var forecast_close_button: Button
var touch_forecast_button: Button
var touch_guide_button: Button
var touch_navigation_button: Button
var touch_device_lab_button: Button
var device_lab_panel: PanelContainer
var device_lab_label: Label
var device_lab_start_button: Button
var device_lab_export_button: Button
var device_lab_close_button: Button
var device_lab_export_note: Label
var guide_panel: PanelContainer
var guide_label: Label
var guide_next_button: Button
var guide_close_button: Button
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

func _set_player_pointer_capture(wants_capture: bool) -> void:
    # Godot mouse capture is for desktop mouselook only. In a genuine
    # touchscreen UI pointer lock can swallow physical click/tap releases
    # after the journal, pause or restart overlay is dismissed.
    if DisplayServer.get_name() == "headless":
        return
    var is_touch_screen: bool = touch_ui != null and touch_ui.visible
    Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED if wants_capture and not is_touch_screen else Input.MOUSE_MODE_VISIBLE)

func _ready() -> void:
    var initial_query: String = ""
    if OS.has_feature("web"):
        # Only read URL search; no code evaluation or remote commands.
        var browser: Variant = JavaScriptBridge.get_interface("window")
        if browser != null:
            initial_query = str(browser.location.search)
    _apply_world_launch(initial_query)
    if DisplayServer.get_name() != "headless":
        run_archive.load_archive()
    _make_environment()
    _make_complex()
    world_sectors = IPWorldSectors.new()
    add_child(world_sectors)
    # G3 source-bound materials and persistent safety cues; no scene collisions.
    obsidian_world = IPObsidianArchitecture.new()
    add_child(obsidian_world)
    obsidian_world.set_locale(locale)
    wayfinder = IPWayfinding.new()
    add_child(wayfinder)
    wayfinder.configure(terminals)
    campaign_echoes = IPCampaignEchoes.new()
    add_child(campaign_echoes)
    campaign_echoes.sync(campaign,locale)
    audio_director = IPSoundscape.new()
    add_child(audio_director)
    _make_player()
    _make_hud()
    _attach_web_state()
    _sync_web_canvas_layout()
    _refresh_hud()
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _apply_world_launch(query: String) -> void:
    # The URL chooses a legitimate mission; it cannot start or win a run.
    if started:
        return
    var parsed: Dictionary = IPWorldLaunch.parse(query)
    world_launch = parsed.duplicate(true)
    locale = str(parsed["lang"])
    selected_scenario = str(parsed["scenario"])
    campaign = IPCampaignFlow.new()
    if bool(parsed["campaign"]):
        campaign.begin()
        selected_scenario = campaign.current_scenario()
    session.reset(selected_scenario)
    story.reset(selected_scenario)
    if intro_panel != null:
        _update_scenario_picker()
        _refresh_hud()

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
    state["mouse_captured"] = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
    state["intro_visible"] = intro_panel.visible
    var scenario_rects: Dictionary = {}
    for scenario_key in scenario_buttons:
        scenario_rects[str(scenario_key)] = _hud_rect(scenario_buttons[scenario_key] as Control)
    state["scenario_button_rects"] = scenario_rects
    state["end_visible"] = end_panel.visible
    state["quality_mode"] = quality_mode
    state["adaptive_quality"] = adaptive_performance.readout(quality_mode,performance_audit.telemetry())
    state["adaptive_quality_label"] = quality_state_label.text if quality_state_label != null else ""
    state["auto_quality_button_rect"] = _hud_rect(auto_quality_button) if auto_quality_button != null else []
    state["reduced_motion"] = reduced_motion
    state["audio_muted"] = muted_audio
    state["soundscape_ready"] = audio_director != null and audio_director.ambient != null
    state["cinematic_details"] = art_stage.readout() if art_stage != null else {}
    state["reactor_atrium"] = reactor_atrium.readout() if reactor_atrium != null else {}
    state["containment_fx"] = containment_fx.readout() if containment_fx != null else {}
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
        "halo_camera_alignment":absf(normal_front.dot(director_eye))
    }
    state["cinematic_view"] = cinematic_view
    state["director_shot_index"] = reactor_atrium.director_shot_index
    state["performance_audit"] = performance_audit.telemetry()
    # G4 is read-only on the web: real _process frame deltas, no web
    # messages or JS callbacks may start, stop, forge or upload a run.
    state["g4_device_lab"] = device_lab.snapshot()
    state["g4_device_lab"]["panel_visible"] = device_lab_panel != null and device_lab_panel.visible
    state["g4_device_lab"]["start_button_rect"] = _hud_rect(device_lab_start_button) if device_lab_start_button != null else []
    state["g4_device_lab"]["export_button_rect"] = _hud_rect(device_lab_export_button) if device_lab_export_button != null else []
    state["g4_device_lab"]["close_button_rect"] = _hud_rect(device_lab_close_button) if device_lab_close_button != null else []
    state["g4_device_lab"]["touch_button_rect"] = _hud_rect(touch_device_lab_button) if touch_device_lab_button != null else []
    state["g4_device_lab"]["local_save_ok"] = device_lab.last_local_save_ok
    state["release_gate"] = performance_audit.release_gate()
    state["diagnostics_visible"] = diagnostic_panel != null and diagnostic_panel.visible
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
    state["g3_obsidian_architecture"] = obsidian_world.readout() if obsidian_world != null else {}
    state["story"] = story.diagnostic()
    state["campaign"] = campaign.diagnostic()
    state["world_launch"] = {
        "schema":IPWorldLaunch.FORMAT,
        "scenario":selected_scenario,
        "lang":locale,
        "campaign":campaign.active,
        "requested_campaign":bool(world_launch.get("campaign",false))
    }
    state["wayfinder"] = wayfinder.readout() if wayfinder != null else {}
    state["threat_radar"] = threat_radar.snapshot(session)
    state["threat_hud"] = threat_label.text if threat_label != null else ""
    state["operator_records"] = {
        "visible":archive_panel != null and archive_panel.visible,
        "count":run_archive.entries.size(),
        "readout":run_archive.readout(),
        "local_save_success":archive_last_save_ok,
        "open_intro_rect":_hud_rect(archive_intro_button) if archive_intro_button != null else [],
        "open_end_rect":_hud_rect(archive_end_button) if archive_end_button != null else [],
        "close_rect":_hud_rect(archive_close_button) if archive_close_button != null else [],
        "summary_title":archive_title.text if archive_title != null else ""
    }
    state["black_box"] = {
        "visible":debrief_panel != null and debrief_panel.visible,
        "available":not black_box_report.is_empty(),
        "report":black_box_report.duplicate(true) if debrief_panel != null and debrief_panel.visible else {},
        "open_rect":_hud_rect(debrief_button) if debrief_button != null else [],
        "close_rect":_hud_rect(debrief_close_button) if debrief_close_button != null else []
    }
    state["operator_guide"] = {
        "visible":guide_panel != null and guide_panel.visible,
        "report":operator_guide.readout(session,locale) if guide_panel != null and guide_panel.visible else {},
        "text":guide_label.text if guide_label != null and guide_panel.visible else "",
        "open_rect":_hud_rect(touch_guide_button) if touch_guide_button != null else [],
        "next_rect":_hud_rect(guide_next_button) if guide_next_button != null else [],
        "close_rect":_hud_rect(guide_close_button) if guide_close_button != null else []
    }
    state["decision_forecast"] = {
        "visible":forecast_panel != null and forecast_panel.visible,
        "report":forecast_report.duplicate(true) if forecast_panel != null and forecast_panel.visible else {},
        "close_rect":_hud_rect(forecast_close_button) if forecast_close_button != null else []
    }
    state["campaign_echoes"] = campaign_echoes.readout() if campaign_echoes != null else {}
    state["relay_3d_terminals"] = relay_terminals.size()
    var real_relays: Array = []
    for relay_info in relay_terminals:
        var spot: Vector3 = relay_info["position"]
        real_relays.append([str(relay_info["id"]),spot.x,spot.z])
    state["relay_positions"] = real_relays
    state["g2_field_protocol"] = {
        "schema":"IRON_PULSE_FIELD_PROCEDURES_G2",
        "selected":session.field_protocol,
        "selected_from_real_engine":true,
        "available":session.core_scanned and session.field_protocol == "" and not session.override_set and not session.finished(),
        "physical_station_count":field_stations.size(),
        "physical_positions":[],
        "telemetry_uploaded":false,
        "gameplay_simulated":false
    }
    var field_points: Array = []
    for station in field_stations:
        var position3d: Vector3 = station["position"]
        field_points.append([str(station["id"]),position3d.x,position3d.z])
    state["g2_field_protocol"]["physical_positions"] = field_points
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
        _box(self,Vector3(0,5.86,depth),Vector3(12,0.14,0.15),cyan)
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
    _build_field_stations()
    _build_bulkhead()
    art_stage = IPCinematicStage.new()
    add_child(art_stage)
    reactor_atrium = IPReactorAtrium.new()
    add_child(reactor_atrium)
    containment_fx = IPContainmentFX.new()
    add_child(containment_fx)
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

func _build_field_stations() -> void:
    # G2: two physically different optional stations across two sectors.
    # Both are actually reachable in the existing collidable 3D hallway.
    var locations: Array[Dictionary] = [
        {"id":"sink","key":"field_sink_terminal","point":Vector3(-4.2,1.0,-32.5)},
        {"id":"air","key":"field_air_terminal","point":Vector3(4.2,1.0,-49.0)}
    ]
    _field_ready_material = _metal(Color(0.91,0.63,0.32),0.18,true)
    _field_done_material = _metal(Color(0.19,0.76,0.63),0.18,true)
    for info in locations:
        var station := Node3D.new()
        station.name = "G2_PhysicalProtocol_" + str(info["id"])
        station.position = info["point"]
        add_child(station)
        _box(station,Vector3(0,-0.02,0),Vector3(1.65,1.66,0.52),_metal(METAL))
        _box(station,Vector3(0,0.02,0.29),Vector3(1.48,1.25,0.05),_metal(NIGHT,0.1))
        # Different industrial shapes, no external textures or fake sprites.
        for col in range(4):
            var x: float = -0.57 + float(col)*0.38
            _box(station,Vector3(x,-0.40,0.34),Vector3(0.07,0.18,0.045),_metal(STEEL))
        var indicator: MeshInstance3D = _box(
            station,Vector3(0,0.53,0.35),Vector3(1.38,0.11,0.06),_field_ready_material)
        indicator.name = "PhysicalFieldProtocolIndicator"
        var label3d := Label3D.new()
        label3d.name = "PhysicalFieldProtocolSign"
        label3d.text = "SINK" if info["id"]=="sink" else "AIR BUFFER"
        label3d.font_size = 42
        label3d.pixel_size = 0.0025
        label3d.position = Vector3(0,0.04,0.39)
        label3d.modulate = WHITE
        station.add_child(label3d)
        field_stations.append({
            "id":info["id"],"key":info["key"],
            "position":info["point"],"indicator":indicator,"node":station
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
    threat_label = _label(metrics,"",11,AMBER)
    threat_label.name = "V16_LiveFictionalHazardStatus"
    quality_state_label = _label(metrics,"",10,DIM)
    quality_state_label.name = "V18_ActualLocalGraphicsMode"
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
    _refresh_auto_quality_ui()
    _make_touch_controls()
    _make_radio_ui()
    diagnostic_panel = _panel(hud_root,Rect2(-365,295,-15,485),Rect2(1,0,1,0),Color(0.015,0.027,0.045,0.94))
    diagnostic_panel.name = "V12_RealFrameDiagnostics"
    diagnostic_label = _label(diagnostic_panel,"",12,WHITE)
    diagnostic_label.name = "ExactLocalFrameTelemetry"
    diagnostic_panel.visible = false
    forecast_panel = _panel(hud_root,Rect2(-455,296,-17,601),Rect2(1,0,1,0),Color(0.022,0.031,0.040,0.97))
    forecast_panel.name = "V15_RealCrisisDecisionWindow"
    var forecast_stack := VBoxContainer.new()
    forecast_stack.add_theme_constant_override("separation",8)
    forecast_panel.add_child(forecast_stack)
    forecast_label = _label(forecast_stack,"",13,WHITE)
    forecast_label.name = "ClonedEngine30SecondForecast"
    forecast_close_button = Button.new()
    forecast_close_button.text = "CLOSE / X"
    forecast_close_button.custom_minimum_size = Vector2(110.0,48.0)
    forecast_close_button.pressed.connect(_toggle_decision_forecast)
    forecast_stack.add_child(forecast_close_button)
    forecast_panel.visible = false
    guide_panel = _panel(hud_root,Rect2(-310,-247,310,247),Rect2(0.5,0.5,0.5,0.5),Color(0.012,0.021,0.030,0.992))
    guide_panel.name = "G1_ActualGameplayOperatorGuide"
    guide_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var guide_stack := VBoxContainer.new()
    guide_stack.add_theme_constant_override("separation",10)
    guide_panel.add_child(guide_stack)
    var guide_scroll := ScrollContainer.new()
    guide_scroll.name = "RealSourceGuidanceScroll"
    guide_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    guide_scroll.custom_minimum_size = Vector2(0,330)
    guide_stack.add_child(guide_scroll)
    guide_label = _label(guide_scroll,"",14,WHITE)
    guide_label.name = "GenuineCurrentObjectiveHelp"
    guide_next_button = Button.new()
    guide_next_button.name = "MoreAuthenticGuidance"
    guide_next_button.custom_minimum_size = Vector2(0,52)
    guide_next_button.pressed.connect(_toggle_operator_guide)
    guide_stack.add_child(guide_next_button)
    guide_close_button = Button.new()
    guide_close_button.name = "CloseOperatorGuide"
    guide_close_button.custom_minimum_size = Vector2(0,52)
    guide_close_button.pressed.connect(_close_operator_guide)
    guide_stack.add_child(guide_close_button)
    guide_panel.visible = false
    _refresh_operator_guide_locale()
    _make_device_lab_overlay()
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
    intro_panel = _panel(hud_root,Rect2(-310,-300,310,300),Rect2(0.5,0.5,0.5,0.5),Color(0.012,0.029,0.055,0.98))
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
    campaign_button = Button.new()
    campaign_button.name = "CampaignThreeEmergencies"
    campaign_button.text = _copy("campaign_start")
    campaign_button.custom_minimum_size = Vector2(0,48)
    campaign_button.pressed.connect(_start_campaign)
    start_box.add_child(campaign_button)
    archive_intro_button = Button.new()
    archive_intro_button.name = "OpenLocalOperatorRecords"
    archive_intro_button.custom_minimum_size = Vector2(0,52)
    archive_intro_button.pressed.connect(_toggle_run_archive)
    start_box.add_child(archive_intro_button)
    continue_button.visible = DisplayServer.get_name() != "headless" and not checkpoint_store.load_checkpoint(checkpoint_path).is_empty()
    _update_scenario_picker()
    pause_panel = _panel(hud_root,Rect2(-240,-150,240,150),Rect2(0.5,0.5,0.5,0.5),Color(0.012,0.029,0.055,0.98))
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
    auto_quality_button = Button.new()
    auto_quality_button.name = "V18_OptInActualFrameAdaptiveGraphics"
    auto_quality_button.custom_minimum_size = Vector2(0,52)
    auto_quality_button.add_theme_font_size_override("font_size",13)
    auto_quality_button.pressed.connect(_toggle_auto_quality)
    pause_box.add_child(auto_quality_button)
    pause_panel.visible = false
    end_panel = _panel(hud_root,Rect2(-300,-220,300,220),Rect2(0.5,0.5,0.5,0.5),Color(0.012,0.029,0.055,0.99))
    end_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var end_box := VBoxContainer.new()
    end_box.add_theme_constant_override("separation",12)
    end_panel.add_child(end_box)
    end_title = _label(end_box,"",29,CYAN)
    var end_scroll := ScrollContainer.new()
    end_scroll.name = "FinalRealGameStatsScroll"
    end_scroll.custom_minimum_size = Vector2(0,178)
    end_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    end_box.add_child(end_scroll)
    end_stats = _label(end_scroll,"",15,WHITE)
    end_button = Button.new()
    end_button.text = _copy("restart")
    end_button.custom_minimum_size = Vector2(0,55)
    end_button.pressed.connect(_end_action)
    end_box.add_child(end_button)
    debrief_button = Button.new()
    debrief_button.name = "A7_BlackBoxOpen"
    debrief_button.custom_minimum_size = Vector2(0,52)
    debrief_button.pressed.connect(_toggle_after_action)
    end_box.add_child(debrief_button)
    archive_end_button = Button.new()
    archive_end_button.name = "ReadPriorRealGameRuns"
    archive_end_button.custom_minimum_size = Vector2(0,52)
    archive_end_button.pressed.connect(_toggle_run_archive)
    end_box.add_child(archive_end_button)
    end_panel.visible = false
    # Native evidence panel. Its 3D game event history comes only from the
    # currently finished engine; the existing end screen stays mounted.
    debrief_panel = _panel(hud_root,Rect2(-315,-258,315,258),Rect2(0.5,0.5,0.5,0.5),Color(0.015,0.022,0.030,0.995))
    debrief_panel.name = "V16_GenuineEngineBlackBox"
    debrief_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var debrief_box := VBoxContainer.new()
    debrief_box.add_theme_constant_override("separation",12)
    debrief_panel.add_child(debrief_box)
    debrief_title = _label(debrief_box,"A7 / BLACK BOX",25,AMBER)
    var debrief_scroll := ScrollContainer.new()
    debrief_scroll.name = "EventEvidenceScroll"
    debrief_scroll.custom_minimum_size = Vector2(0,360)
    debrief_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    debrief_box.add_child(debrief_scroll)
    debrief_label = _label(debrief_scroll,"",13,WHITE)
    debrief_label.name = "RealEventDebriefTranscript"
    debrief_close_button = Button.new()
    debrief_close_button.name = "CloseBlackBox"
    debrief_close_button.custom_minimum_size = Vector2(0,52)
    debrief_close_button.pressed.connect(_toggle_after_action)
    debrief_box.add_child(debrief_close_button)
    debrief_panel.visible = false
    # Persistent personal attempt ledger; native Godot, no external services.
    archive_panel = _panel(hud_root,Rect2(-315,-300,315,300),Rect2(0.5,0.5,0.5,0.5),Color(0.011,0.018,0.025,0.995))
    archive_panel.name = "V17_LocalOperatorRecords"
    archive_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var records_box := VBoxContainer.new()
    records_box.add_theme_constant_override("separation",10)
    archive_panel.add_child(records_box)
    archive_title = _label(records_box,"A7 / OPERATOR RECORDS",24,CYAN)
    var records_scroll := ScrollContainer.new()
    records_scroll.name = "LocalRunsScrollableHistory"
    records_scroll.custom_minimum_size = Vector2(0,392)
    records_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    records_box.add_child(records_scroll)
    archive_label = _label(records_scroll,"",12,WHITE)
    archive_label.name = "OnlyActualLocalRunResults"
    archive_erase_button = Button.new()
    archive_erase_button.name = "TwoStepEraseLocalRuns"
    archive_erase_button.custom_minimum_size = Vector2(0,52)
    archive_erase_button.pressed.connect(_request_archive_erase)
    records_box.add_child(archive_erase_button)
    archive_close_button = Button.new()
    archive_close_button.name = "CloseLocalRuns"
    archive_close_button.custom_minimum_size = Vector2(0,52)
    archive_close_button.pressed.connect(_toggle_run_archive)
    records_box.add_child(archive_close_button)
    archive_panel.visible = false
    _refresh_after_action_locale()
    _refresh_run_archive_locale()

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
    var camera_button := _touch_button(touch_ui,"CAM / C",216,-414,94)
    camera_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    camera_button.pressed.connect(_toggle_cinematic_view)
    touch_shot_button = _touch_button(touch_ui,"SHOT / P",216,-471,94)
    touch_shot_button.action_mode = BaseButton.ACTION_MODE_BUTTON_PRESS
    touch_shot_button.pressed.connect(_cycle_director_shot)
    touch_shot_button.visible = false
    touch_forecast_button = _touch_button(touch_ui,"PLAN / T",6,-299,94)
    touch_forecast_button.pressed.connect(_toggle_decision_forecast)
    touch_guide_button = _touch_button(touch_ui,"GUIDE / ?",6,-357,94)
    touch_guide_button.add_theme_font_size_override("font_size",15)
    touch_guide_button.pressed.connect(_toggle_operator_guide)
    touch_navigation_button = _touch_button(touch_ui,"NAV / H",6,-414,94)
    touch_navigation_button.add_theme_font_size_override("font_size",15)
    touch_navigation_button.pressed.connect(_toggle_wayfinding)
    touch_device_lab_button = _touch_button(touch_ui,"LAB / F6",6,-471,94)
    touch_device_lab_button.add_theme_font_size_override("font_size",14)
    touch_device_lab_button.pressed.connect(_toggle_device_lab)

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
        if obsidian_world != null:
            obsidian_world.set_quality("eco")
        if reactor_atrium != null:
            reactor_atrium.set_quality("eco")
        if containment_fx != null:
            containment_fx.set_quality("eco")
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
    threat_label.add_theme_font_size_override("font_size",10 if narrow else 11)
    quality_state_label.add_theme_font_size_override("font_size",10 if narrow else 11)
    adaptive_performance.compact_device = narrow
    interaction_label.add_theme_font_size_override("font_size",12 if narrow else 17)
    feedback_label.add_theme_font_size_override("font_size",12 if narrow else 15)
    footer_label.add_theme_font_size_override("font_size",9 if narrow else 11)
    if device_lab_panel != null:
        var lab_half: float = minf(300.0,width*0.45)
        device_lab_panel.offset_left = -lab_half
        device_lab_panel.offset_right = lab_half
        device_lab_label.custom_minimum_size.x = lab_half*2.0-46.0
        device_lab_label.add_theme_font_size_override("font_size",11 if narrow else 13)
    if guide_panel != null:
        var help_half: float = minf(310.0,width*0.45)
        guide_panel.offset_left = -help_half
        guide_panel.offset_right = help_half
        guide_label.custom_minimum_size.x = help_half*2.0-50.0
        guide_label.add_theme_font_size_override("font_size",12 if narrow else 14)
    if forecast_panel != null:
        forecast_panel.anchor_left = 0.0 if narrow else 1.0
        forecast_panel.anchor_right = 0.0 if narrow else 1.0
        forecast_panel.offset_left = 12.0 if narrow else -455.0
        forecast_panel.offset_right = width-12.0 if narrow else -17.0
        forecast_panel.offset_top = 290.0 if narrow else 296.0
        forecast_panel.offset_bottom = 594.0 if narrow else 601.0
        forecast_label.add_theme_font_size_override("font_size",11 if narrow else 13)
    pause_panel.offset_left = -minf(240.0,width*0.45)
    pause_panel.offset_right = minf(240.0,width*0.45)
    intro_panel.offset_left = -minf(310.0,width*0.45)
    intro_panel.offset_right = minf(310.0,width*0.45)
    end_panel.offset_left = -minf(300.0,width*0.45)
    end_panel.offset_right = minf(300.0,width*0.45)
    end_stats.custom_minimum_size.x = minf(500.0,width*0.83-28.0)
    if archive_panel != null:
        var archive_half: float = minf(315.0,width*0.45)
        archive_panel.offset_left = -archive_half
        archive_panel.offset_right = archive_half
        archive_label.custom_minimum_size.x = archive_half*2.0-48.0
        archive_label.add_theme_font_size_override("font_size",11 if narrow else 12)
        archive_title.add_theme_font_size_override("font_size",18 if narrow else 24)
    if debrief_panel != null:
        var review_half: float = minf(315.0,width*0.45)
        debrief_panel.offset_left = -review_half
        debrief_panel.offset_right = review_half
        debrief_label.custom_minimum_size.x = review_half*2.0-48.0
        debrief_label.add_theme_font_size_override("font_size",11 if narrow else 13)
        debrief_title.add_theme_font_size_override("font_size",19 if narrow else 25)
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
            reactor_atrium.reset_director_shots()
    elif camera != null:
        camera.make_current()
    if touch_shot_button != null:
        touch_shot_button.visible = cinematic_view and touch_ui.visible
    if touch_forecast_button != null:
        touch_forecast_button.visible = not cinematic_view and touch_ui.visible
    if touch_guide_button != null:
        touch_guide_button.visible = not cinematic_view and touch_ui.visible
    if touch_navigation_button != null:
        touch_navigation_button.visible = not cinematic_view and touch_ui.visible
    if cinematic_view and guide_panel != null:
        guide_panel.visible = false
    if cinematic_view and forecast_panel != null:
        forecast_panel.visible = false

func _toggle_cinematic_view() -> void:
    if not started or paused or session.finished():
        return
    cinematic_view = not cinematic_view
    _apply_cinematic_view()
    if not cinematic_view:
        _refresh_radio_ui()

func _toggle_decision_forecast() -> void:
    if not started or paused or session.finished() or cinematic_view or forecast_panel == null:
        return
    forecast_panel.visible = not forecast_panel.visible
    if forecast_panel.visible:
        diagnostic_panel.visible = false
        forecast_update_clock = 0.0
        _refresh_decision_forecast()

func _refresh_decision_forecast() -> void:
    if forecast_panel == null or not forecast_panel.visible:
        return
    forecast_report = decision_forecaster.evaluate(session)
    forecast_label.text = decision_forecaster.text_report(forecast_report,locale)
    forecast_close_button.text = "CLOSE / X" if locale == "en" else "ЗАКРЫТЬ / X"

func _refresh_operator_guide_locale() -> void:
    if guide_label == null or guide_panel == null:
        return
    var details: Dictionary = operator_guide.readout(session,locale)
    guide_label.text = str(details.get("text",""))
    if guide_next_button != null:
        guide_next_button.text = "F1 / NEXT HINT" if locale == "en" else "F1 / ЕЩЁ ПОДСКАЗКА"
    if guide_close_button != null:
        guide_close_button.text = "ESC / CLOSE" if locale == "en" else "ESC / ЗАКРЫТЬ"

func _close_operator_guide() -> void:
    if guide_panel != null:
        guide_panel.visible = false
    _publish_web_state()

func _toggle_wayfinding() -> void:
    if not started or paused or session.finished() or cinematic_view or wayfinder == null:
        return
    _announce("wayfinder_on" if wayfinder.toggle() else "wayfinder_off")
    _save_checkpoint()
    _refresh_hud()
    _publish_web_state()

func _toggle_operator_guide() -> void:
    # Genuine 3D gameplay continues. No pause, auto-action, remote API,
    # simulated player success or mutation of source engine state.
    if guide_panel == null or not started or paused or session.finished() or cinematic_view:
        return
    var details: Dictionary = operator_guide.request(session,locale)
    if details.is_empty():
        return
    guide_panel.visible = true
    if forecast_panel != null:
        forecast_panel.visible = false
    if diagnostic_panel != null:
        diagnostic_panel.visible = false
    _refresh_operator_guide_locale()
    _publish_web_state()

func _clear_after_action() -> void:
    if debrief_panel != null:
        debrief_panel.visible = false
    black_box_report.clear()

func _refresh_after_action_locale() -> void:
    if debrief_button == null or debrief_title == null or debrief_label == null or debrief_close_button == null:
        return
    var english: bool = locale == "en"
    debrief_button.text = "VIEW BLACK BOX / B" if english else "ЧЁРНЫЙ ЯЩИК / B"
    debrief_title.text = "A7 / AFTER-ACTION REPORT" if english else "A7 / ОТЧЁТ ПО ОПЕРАЦИИ"
    debrief_close_button.text = "CLOSE REPORT / ESC" if english else "ЗАКРЫТЬ ОТЧЁТ / ESC"
    debrief_label.text = after_action_review.localized(black_box_report,locale)

func _toggle_after_action() -> void:
    # Review is a post-operation feature, never a free pause or cheat.
    if not started or not session.finished() or debrief_panel == null or black_box_report.is_empty():
        return
    debrief_panel.visible = not debrief_panel.visible
    if debrief_panel.visible:
        if archive_panel != null:
            archive_panel.visible = false
        forecast_panel.visible = false
        diagnostic_panel.visible = false
        _refresh_after_action_locale()
    _publish_web_state()

func _clear_operator_overlay() -> void:
    if archive_panel != null:
        archive_panel.visible = false
    archive_erase_armed = false

func _refresh_run_archive_locale() -> void:
    if archive_intro_button == null or archive_end_button == null or archive_label == null or archive_title == null:
        return
    var english: bool = locale == "en"
    archive_intro_button.text = "OPERATOR RECORDS / O" if english else "АРХИВ ОПЕРАТОРА / O"
    archive_end_button.text = archive_intro_button.text
    archive_title.text = "A7 / LOCAL OPERATOR RECORDS" if english else "A7 / ЛОКАЛЬНЫЙ АРХИВ"
    archive_label.text = run_archive.summary(locale)
    if archive_erase_failed:
        archive_label.text += "\n" + ("ERASE FAILED: original file preserved." if english else "ОШИБКА УДАЛЕНИЯ: оригинальный файл сохранён.")
    archive_close_button.text = "CLOSE RECORDS / ESC" if english else "ЗАКРЫТЬ АРХИВ / ESC"
    archive_erase_button.disabled = run_archive.entries.is_empty() and not run_archive.is_corrupt
    if archive_erase_armed:
        archive_erase_button.text = "CONFIRM DELETE ALL LOCAL RUNS" if english else "ПОДТВЕРДИТЕ УДАЛЕНИЕ ЗАПИСЕЙ"
    else:
        archive_erase_button.text = "ERASE LOCAL RUNS (2 STEPS)" if english else "СТЕРЕТЬ ЗАПИСИ (2 ШАГА)"

func _toggle_run_archive() -> void:
    # Read-only. No mid-operation pause, skip, data upload or mission mutation.
    if archive_panel == null or (started and not paused and not session.finished()):
        return
    archive_panel.visible = not archive_panel.visible
    archive_erase_armed = false
    archive_erase_failed = false
    if archive_panel.visible:
        if debrief_panel != null:
            debrief_panel.visible = false
        if diagnostic_panel != null:
            diagnostic_panel.visible = false
    _refresh_run_archive_locale()
    _publish_web_state()

func _request_archive_erase() -> void:
    if archive_panel == null or not archive_panel.visible or (run_archive.entries.is_empty() and not run_archive.is_corrupt):
        return
    if not archive_erase_armed:
        archive_erase_armed = true
        _refresh_run_archive_locale()
        return
    # Erase is explicit and scoped ONLY to V17 archive; campaign saves remain.
    if run_archive.erase():
        archive_erase_armed = false
        archive_erase_failed = false
        archive_last_save_ok = false
        _refresh_run_archive_locale()
    # If the storage operation fails, retain loaded data and require an
    # explicit extra click before any retry; never claim successful erasure.
    else:
        archive_erase_armed = false
        archive_erase_failed = true
        _refresh_run_archive_locale()
    _publish_web_state()

func _cycle_director_shot() -> void:
    if started and not paused and not session.finished() and cinematic_view:
        reactor_atrium.cycle_director_shot()

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
        _set_player_pointer_capture(not paused)
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
        "visited_sectors":visited_sectors.duplicate(),
        "campaign":campaign.checkpoint(),
        "wayfinding_enabled":wayfinder.enabled
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
    # Validate the optional V9+ campaign atomically before any game mutation.
    # Historical V6-V8.6 saves have no campaign field and must still load.
    var saved_wayfinding: Variant = payload.get("wayfinding_enabled",true)
    if typeof(saved_wayfinding) != TYPE_BOOL:
        return false
    var saved_campaign := IPCampaignFlow.new()
    if payload.has("campaign"):
        if not payload["campaign"] is Dictionary or not saved_campaign.restore(payload["campaign"]):
            return false
    if saved_campaign.active:
        if saved_campaign.current_scenario() != restored_engine.scenario_id:
            return false
        if saved_campaign.records.size() != saved_campaign.index:
            return false
    # Now, after atomic validation, restore all gameplay and authored story state.
    _clear_after_action()
    cinematic_view = false
    _apply_cinematic_view()
    forecast_panel.visible = false
    forecast_report.clear()
    session = restored_engine
    operator_guide.reset(session)
    story = restored_story
    campaign = saved_campaign
    campaign_echoes.sync(campaign,saved_locale)
    wayfinder.enabled = bool(saved_wayfinding)
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
    if obsidian_world != null:
        obsidian_world.set_quality(quality_mode)
    reactor_atrium.set_quality(quality_mode)
    containment_fx.set_quality(quality_mode)
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
        _set_player_pointer_capture(true)
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
    # Explicit solo scenario selection overrides a prior campaign deep link.
    if campaign.active:
        campaign = IPCampaignFlow.new()
        world_launch["campaign"] = false
    selected_scenario = next_scenario
    world_launch["scenario"] = next_scenario
    session.reset(next_scenario)
    story.reset(next_scenario)
    radio_ttl = 0.0
    notice_time = 0.0
    _update_scenario_picker()
    _refresh_hud()

func _start_campaign() -> void:
    if started:
        return
    campaign.begin()
    selected_scenario = campaign.current_scenario()
    _restart()

func _end_action() -> void:
    if not campaign.active or not session.won:
        _restart()
        return
    if campaign.awaiting_advance():
        if campaign.advance():
            selected_scenario = campaign.current_scenario()
            _restart()
        return
    # Three real victories produced the final campaign dossier.
    if campaign.completed():
        campaign.begin()
        selected_scenario = campaign.current_scenario()
        _restart()
        return
    _restart()

func _fast_interact() -> void:
    _interact(true)

func start_run() -> void:
    operator_guide.reset(session)
    _close_operator_guide()
    _clear_operator_overlay()
    archive_last_save_ok = false
    _clear_after_action()
    forecast_panel.visible = false
    forecast_report.clear()
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
        _set_player_pointer_capture(true)

func _restart() -> void:
    _clear_operator_overlay()
    archive_last_save_ok = false
    _clear_after_action()
    forecast_panel.visible = false
    forecast_report.clear()
    cinematic_view = false
    _apply_cinematic_view()
    session.reset(selected_scenario)
    operator_guide.reset(session)
    _close_operator_guide()
    if campaign.active and campaign.index > 0:
        campaign.modifier_applied = false
        campaign.apply_to_next(session)
    story.reset(selected_scenario)
    if campaign.active and campaign.index > 0:
        story.on_campaign_carryover(str(campaign.records[campaign.index-1]["priority"]))
    campaign_echoes.sync(campaign,locale)
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
    intro_panel.visible = false
    pause_panel.visible = false
    end_panel.visible = false
    _announce("shift_started")
    _refresh_radio_ui()
    _save_checkpoint()
    audio_director.set_active(true)
    if DisplayServer.get_name() != "headless":
        _set_player_pointer_capture(true)

func _resume() -> void:
    _clear_operator_overlay()
    paused = false
    pause_panel.visible = false
    audio_director.set_active(true)
    if DisplayServer.get_name() != "headless":
        _set_player_pointer_capture(true)

func _pause_toggle() -> void:
    if not started or session.finished():
        return
    paused = not paused
    if paused and guide_panel != null:
        guide_panel.visible = false
    if paused and forecast_panel != null:
        forecast_panel.visible = false
    pause_panel.visible = paused
    audio_director.set_active(not paused)
    if DisplayServer.get_name() != "headless":
        _set_player_pointer_capture(not paused)

func _toggle_language() -> void:
    locale = "en" if locale == "ru" else "ru"
    intro_body.text = _copy("intro")
    intro_button.text = _copy("start")
    campaign_button.text = _copy("campaign_start")
    _update_scenario_picker()
    pause_title.text = _copy("pause")
    resume_button.text = _copy("resume")
    _refresh_auto_quality_ui()
    end_button.text = _copy("campaign_next") if campaign.awaiting_advance() else _copy("campaign_replay") if campaign.completed() else _copy("restart")
    footer_label.text = _copy("footer")
    campaign_echoes.sync(campaign,locale)
    if obsidian_world != null:
        obsidian_world.set_locale(locale)
    if diagnostic_panel.visible:
        diagnostic_label.text = performance_audit.diagnostic_text(locale,session.scenario_id,campaign)
    _announce("language")
    _refresh_hud()
    _refresh_decision_forecast()
    _refresh_operator_guide_locale()
    _refresh_after_action_locale()
    _refresh_run_archive_locale()
    _refresh_device_lab_ui()
    _refresh_radio_ui()

func _apply_graphics_profile(next_mode: String) -> void:
    if next_mode not in ["hero","eco"] or next_mode == quality_mode:
        return
    quality_mode = next_mode
    art_stage.set_quality(quality_mode)
    world_sectors.set_quality(quality_mode)
    if obsidian_world != null:
        obsidian_world.set_quality(quality_mode)
    reactor_atrium.set_quality(quality_mode)
    containment_fx.set_quality(quality_mode)
    for index in range(legacy_lamps.size()):
        legacy_lamps[index].visible = quality_mode == "hero" or index % 3 == 0
    if quality_state_label != null:
        quality_state_label.text = adaptive_performance.status_line(locale,quality_mode,performance_audit.telemetry())

func _refresh_auto_quality_ui() -> void:
    if auto_quality_button == null:
        return
    var english: bool = locale == "en"
    if adaptive_performance.enabled:
        auto_quality_button.text = "K / AUTO ON · DISABLE" if english else "K / АВТО ВКЛ. · ВЫКЛ."
    else:
        auto_quality_button.text = "K / ENABLE AUTO" if english else "K / ВКЛЮЧИТЬ АВТО"
    if quality_state_label != null:
        quality_state_label.text = adaptive_performance.status_line(locale,quality_mode,performance_audit.telemetry())

func _toggle_auto_quality() -> void:
    adaptive_performance.set_enabled(not adaptive_performance.enabled)
    adaptive_sampling_clock = 0.0
    _refresh_auto_quality_ui()
    _announce("auto_on" if adaptive_performance.enabled else "auto_off")
    _publish_web_state()

func _gamepad_axis(axis_id: int) -> float:
    var joypads: Array[int] = Input.get_connected_joypads()
    if joypads.is_empty():
        return 0.0
    var reading: float = Input.get_joy_axis(joypads[0],axis_id)
    return reading if absf(reading) >= 0.18 else 0.0

func _gamepad_button(button_index: int) -> void:
    # Hardware performance/compatibility still requires real controller QA.
    # This dispatch handles Godot's mapped standard gamepad button events.
    if button_index == JOY_BUTTON_BACK:
        if guide_panel != null and guide_panel.visible:
            _close_operator_guide()
        else:
            _toggle_operator_guide()
        return
    if button_index == JOY_BUTTON_START:
        if archive_panel != null and archive_panel.visible:
            _toggle_run_archive()
            return
        if not started:
            start_run()
        else:
            _pause_toggle()
        return
    if button_index == JOY_BUTTON_B:
        if guide_panel != null and guide_panel.visible:
            _close_operator_guide()
        elif archive_panel != null and archive_panel.visible:
            _toggle_run_archive()
        elif session.finished():
            _toggle_after_action()
        else:
            _toggle_journal()
        return
    if not started or paused:
        if button_index == JOY_BUTTON_X and not started:
            _toggle_run_archive()
        return
    if session.finished():
        if button_index == JOY_BUTTON_X:
            _toggle_run_archive()
        elif button_index == JOY_BUTTON_A and not debrief_panel.visible and not archive_panel.visible:
            _end_action()
        elif button_index == JOY_BUTTON_Y:
            _toggle_after_action()
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
        JOY_BUTTON_DPAD_RIGHT:
            _cycle_director_shot()

func _input(event: InputEvent) -> void:
    if event is InputEventJoypadButton and event.pressed:
        _gamepad_button(event.button_index)
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F6:
            _toggle_device_lab()
            return
        if event.keycode == KEY_F7:
            _device_lab_toggle_record()
            return
        if device_lab_panel != null and device_lab_panel.visible:
            if event.keycode == KEY_ESCAPE:
                _close_device_lab()
            return
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
        if event.keycode == KEY_F1:
            _toggle_operator_guide()
            return
        if event.keycode == KEY_F3:
            if forecast_panel != null:
                forecast_panel.visible = false
            diagnostic_panel.visible = not diagnostic_panel.visible
            if diagnostic_panel.visible:
                diagnostic_label.text = performance_audit.diagnostic_text(locale,session.scenario_id,campaign)
            return
        if event.keycode == KEY_T:
            _toggle_decision_forecast()
            return
        if event.keycode == KEY_B:
            _toggle_after_action()
            return
        if event.keycode == KEY_O:
            _toggle_run_archive()
            return
        if event.keycode == KEY_H:
            _toggle_wayfinding()
            return
        if event.keycode == KEY_K:
            _toggle_auto_quality()
            return
        if event.keycode == KEY_G:
            # An explicit player selection always takes priority over AUTO.
            adaptive_performance.set_enabled(false)
            adaptive_sampling_clock = 0.0
            _apply_graphics_profile("eco" if quality_mode == "hero" else "hero")
            _refresh_auto_quality_ui()
            _announce("quality_eco" if quality_mode == "eco" else "quality_hero")
            return
        if event.keycode == KEY_C and started and not paused and not session.finished():
            _toggle_cinematic_view()
            return
        if event.keycode == KEY_P and cinematic_view:
            _cycle_director_shot()
            return
        if event.keycode == KEY_J:
            if cinematic_view:
                cinematic_view = false
                _apply_cinematic_view()
            _toggle_journal()
            return
        if event.keycode == KEY_ESCAPE:
            if guide_panel != null and guide_panel.visible:
                _close_operator_guide()
                return
            if archive_panel != null and archive_panel.visible:
                _toggle_run_archive()
                return
            if debrief_panel != null and debrief_panel.visible:
                _toggle_after_action()
                return
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
            if event.keycode == KEY_R and not archive_panel.visible and not debrief_panel.visible:
                _end_action()
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
            _set_player_pointer_capture(true)

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
    var gameplay_active: bool = started and not paused and not session.finished()
    performance_audit.observe(delta,gameplay_active,quality_mode)
    # Actual client-frame evidence, explicitly started by F7 or native
    # button. Pause/intro/overlay frames are never treated as gameplay.
    var viewport_size: Vector2 = get_viewport().get_visible_rect().size
    device_lab.observe(delta,gameplay_active,quality_mode,
        Vector2i(roundi(viewport_size.x),roundi(viewport_size.y)))
    if device_lab.state == "recording" and session.finished():
        device_lab.finish()
    operator_guide.observe(delta,session,gameplay_active)
    if adaptive_performance.enabled and gameplay_active and is_finite(delta) and delta > 0.0 and delta <= 0.25:
        adaptive_sampling_clock += delta
        if adaptive_sampling_clock >= 0.2:
            var sample_delta: float = minf(adaptive_sampling_clock,0.25)
            adaptive_sampling_clock = 0.0
            var compact: bool = (_browser_css_size.x > 0 and _browser_css_size.x < 650) or get_viewport().get_visible_rect().size.x < 650
            var next_quality: String = adaptive_performance.observe(sample_delta,true,quality_mode,performance_audit.telemetry(),compact)
            if next_quality != "":
                _apply_graphics_profile(next_quality)
                _announce("auto_reduce" if next_quality == "eco" else "auto_recover")
    else:
        adaptive_sampling_clock = 0.0
        if adaptive_performance.enabled:
            adaptive_performance.observe(0.0,false,quality_mode,{},adaptive_performance.compact_device)
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
    if obsidian_world != null:
        obsidian_world.update_hazard(session.scenario_id,session.heat,session.oxygen,runtime_seconds,reduced_motion)
    reactor_atrium.update_alarm(session.scenario_id,session.heat,session.oxygen,runtime_seconds,reduced_motion)
    containment_fx.update_from_crisis(
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
    wayfinder.update_goal(
        session.objective_id(),player.global_position,runtime_seconds,
        reduced_motion,quality_mode,locale,
        started and not paused and not session.finished(),cinematic_view)
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
    if forecast_panel != null and forecast_panel.visible and started and not paused and not session.finished():
        forecast_update_clock += maxf(delta,0.0)
        if forecast_update_clock >= 2.0:
            forecast_update_clock = 0.0
            _refresh_decision_forecast()
    hud_elapsed += delta
    if hud_elapsed > 0.12:
        hud_elapsed = 0.0
        _refresh_hud()
        if diagnostic_panel.visible:
            diagnostic_label.text = performance_audit.diagnostic_text(locale,session.scenario_id,campaign)
        if device_lab_panel != null and device_lab_panel.visible:
            _refresh_device_lab_ui()

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

func _nearest_field_station() -> Dictionary:
    if player == null:
        return {}
    var chosen: Dictionary = {}
    var nearest: float = 2.85
    for field in field_stations:
        var where: Vector3 = field["position"]
        var dist: float = Vector2(where.x,where.z).distance_to(Vector2(player.global_position.x,player.global_position.z))
        if dist < nearest:
            nearest = dist
            chosen = field
    return chosen

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
    var field: Dictionary = _nearest_field_station()
    if not fast and not field.is_empty():
        var main_d: float = _physical_distance(target["position"]) if not target.is_empty() else 999.0
        var relay_d: float = _physical_distance(rescue["position"]) if not rescue.is_empty() else 999.0
        if _physical_distance(field["position"]) < minf(main_d,relay_d):
            var approved: bool = session.activate_field_protocol(str(field["id"]))
            previous_event = session.last_event
            if approved:
                _story_event(session.last_event)
            _announce(session.last_event)
            _save_checkpoint()
            _refresh_hud()
            return
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
        "core_scanned", "coolant_repaired", "thermal_stabilized", "thermal_purged", "breach_sealed", "breach_patched", "bus_switched", "override_authorized", "relay_medbay", "relay_quench", "relay_uplink", "field_sink", "field_air":
            audio_director.cue("confirm")

func _show_end() -> void:
    _close_operator_guide()
    forecast_panel.visible = false
    forecast_report.clear()
    cinematic_view = false
    _apply_cinematic_view()
    if end_panel.visible:
        return
    end_panel.visible = true
    if session.won and campaign.active:
        if campaign.record_victory(session) and DisplayServer.get_name() != "headless":
            checkpoint_store.save(campaign.checkpoint(),CAMPAIGN_RECORD_PATH)
        campaign_echoes.sync(campaign,locale)
    end_button.text = _copy("campaign_next") if campaign.awaiting_advance() else _copy("campaign_replay") if campaign.completed() else _copy("restart")
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
    var protocol_tag: String = _copy("field_" + session.field_protocol + "_terminal") if session.field_protocol != "" else _copy("field_none")
    end_stats.text += "\n" + _copy("field_final").format({"protocol":protocol_tag})
    if campaign.active:
        end_stats.text += "\n\n" + campaign.summary(locale)
    black_box_report = after_action_review.review(session,campaign)
    # Headless regressions must not modify the regular player's user:// slot.
    # Native CI sets a separate temporary path when it tests persistence.
    if DisplayServer.get_name() != "headless" or run_archive.archive_path != IPRunArchive.PATH:
        archive_last_save_ok = run_archive.record_finished(session,campaign)
        end_stats.text += ("\nLOCAL RUN SAVED" if locale=="en" else "\nЛОКАЛЬНЫЙ ПРОХОД СОХРАНЁН") if archive_last_save_ok else (
            "\nLOCAL HISTORY NOT SAVED: CHECK STORAGE" if locale=="en" else "\nАРХИВ НЕ СОХРАНЁН: ПРОВЕРЬТЕ ХРАНИЛИЩЕ")
    _refresh_after_action_locale()
    _refresh_run_archive_locale()
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func _refresh_hud() -> void:
    if objective_label == null:
        return
    operator_guide.observe(0.0,session,false)
    if guide_panel != null and guide_panel.visible:
        _refresh_operator_guide_locale()
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
    if campaign.active:
        subtitle_label.text += " / " + _copy("campaign_progress").format({"index":campaign.index+1})
    _update_guidance(objective_key)
    _update_terminal_highlights(objective_key)
    telemetry_label.text = "%s  %d°C    |    %s  %d%%\n%s  %d%%    |    %s  %d%%    |    %s  %02d:%02d" % [
        _copy("heat"),int(session.heat),_copy("oxygen"),int(session.oxygen),
        _copy("crew"),int(session.crew_health),_copy("door"),int(session.door_charge),
        _copy("time"),floori(session.time_left/60.0),int(session.time_left)%60]
    allocation_label.text = "%s  /  A: %s   |   B: %s\n%s" % [
        _copy("power"),session.bus_a.to_upper(),session.bus_b.to_upper(),
        _copy("rescue_count").format({"used":session.relays_activated.size()})]
    quality_state_label.text = adaptive_performance.status_line(locale,quality_mode,performance_audit.telemetry())
    var risk: Dictionary = threat_radar.snapshot(session)
    threat_label.text = threat_radar.cockpit_text(risk,locale)
    var risk_color: Color = RED if str(risk["tier"]) in ["CRITICAL","FAILED"] else AMBER if str(risk["tier"]) == "WATCH" else CYAN
    threat_label.add_theme_color_override("font_color",risk_color)
    (vitals_meters["heat"] as ProgressBar).value = session.heat
    (vitals_meters["oxygen"] as ProgressBar).value = session.oxygen
    (vitals_meters["crew"] as ProgressBar).value = session.crew_health
    (vitals_meters["door"] as ProgressBar).value = session.door_charge
    var nearby: Dictionary = _nearest_terminal()
    var rescue: Dictionary = _nearest_relay()
    var field: Dictionary = _nearest_field_station()
    var main_dist: float = _physical_distance(nearby["position"]) if not nearby.is_empty() else 999.0
    var rescue_dist: float = _physical_distance(rescue["position"]) if not rescue.is_empty() else 999.0
    var field_dist: float = _physical_distance(field["position"]) if not field.is_empty() else 999.0
    var show_field: bool = not field.is_empty() and field_dist < minf(main_dist,rescue_dist)
    var show_rescue: bool = not rescue.is_empty() and rescue_dist < main_dist and rescue_dist <= field_dist
    if started and not session.finished() and show_field:
        var field_ready: bool = session.core_scanned and session.field_protocol == "" and not session.override_set
        var text_key: String = "field_hint" if field_ready else "field_spent"
        interaction_label.text = _copy(text_key).format({
            "name":_copy(str(field["key"])),"distance":"%.1f" % field_dist})
    elif started and not session.finished() and show_rescue:
        var relay_dist: float = _physical_distance(rescue["position"])
        var relay_ready: bool = session.core_scanned and not session.relays_activated.has(str(rescue["id"])) and session.relays_activated.size() < IPCrisisEngine.MAX_RELAYS
        var rescue_key: String = "rescue_hint" if relay_ready else "rescue_spent"
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
    for station in field_stations:
        var lamp: MeshInstance3D = station["indicator"]
        var chosen: bool = session.field_protocol == str(station["id"])
        var status_mat: StandardMaterial3D = _field_done_material if chosen else _field_ready_material
        if lamp.material_override != status_mat:
            lamp.material_override = status_mat
