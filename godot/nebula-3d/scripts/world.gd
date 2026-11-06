extends Node3D
## NEBULA ASCENSION 3D: experimental standalone Godot 4 vertical slice.
## Built from procedural geometry; it does not share browser v4 save data.

const ShipScript = preload("res://scripts/ship.gd")
const DroneScript = preload("res://scripts/drone.gd")
const RadarScript = preload("res://scripts/radar.gd")
const PremiumArchitectureScript = preload("res://scripts/premium_architecture.gd")
const ArchitecturalDetailR4Script = preload("res://scripts/architectural_detail_r4.gd")
const CitySetDressingR5Script = preload("res://scripts/city_set_dressing_r5.gd")
const OrbitalDocksR6Script = preload("res://scripts/orbital_docks_r6.gd")
const SculpturalSkylineR6Script = preload("res://scripts/sculptural_skyline_r6.gd")
const CapitalFleetR7Script = preload("res://scripts/capital_fleet_r7.gd")
const OrbitalIndustryR9Script = preload("res://scripts/orbital_industry_r9.gd")
const AegisMegadockR10Script = preload("res://scripts/aegis_megadock_r10.gd")
const CityCladdingR10Script = preload("res://scripts/city_cladding_r10.gd")
const IndustrialEnvironmentR11Script = preload("res://scripts/industrial_environment_r11.gd")
const CinematicPostR11Script = preload("res://scripts/cinematic_post_r11.gd")
const PerformanceLabR11Script = preload("res://scripts/performance_lab_r11.gd")
const EngineeringCampusR12Script = preload("res://scripts/engineering_campus_r12.gd")
const CinematicLightingR12Script = preload("res://scripts/cinematic_lighting_r12.gd")
const AdaptiveQualityR12Script = preload("res://scripts/adaptive_quality_r12.gd")
const CinematicPortR14Script = preload("res://scripts/cinematic_port_r14.gd")
const AuroraScenicR22Script = preload("res://scripts/aurora_scenic_r22.gd")
const HangarStoreR15Script = preload("res://scripts/hangar_store_r15.gd")
const FleetCombatR15Script = preload("res://scripts/fleet_combat_r15.gd")
const PremiumFulfillmentR15Script = preload("res://scripts/premium_fulfillment_r15.gd")
const MobileControlsR21Script = preload("res://scripts/mobile_controls_r21.gd")
const PremiumHUDR21Script = preload("res://scripts/premium_hud_r21.gd")
const GarageHubR39Script = preload("res://scripts/garage_hub_r39.gd")
const CampaignStoryR41Script = preload("res://scripts/campaign_story_r41.gd")
const CaptainRosterR42Script = preload("res://scripts/captain_roster_r42.gd")
const PilotAcademyR54Script = preload("res://scripts/pilot_academy_r54.gd")
const HangarWorkbenchR56Script = preload("res://scripts/hangar_workbench_r56.gd")
const HangarLiveriesR59Script = preload("res://scripts/hangar_liveries_r59.gd")
const ShipWreckR60Script = preload("res://scripts/ship_wreck_r60.gd")
const PatrolContractsR57Script = preload("res://scripts/patrol_contracts_r57.gd")
const CareerPrestigeR58Script = preload("res://scripts/career_prestige_r58.gd")
const MissionObjectivesR48Script = preload("res://scripts/mission_objectives_r48.gd")
const PortInvestigationR49Script = preload("res://scripts/port_investigation_r49.gd")
const ArchiveBreachR50Script = preload("res://scripts/archive_breach_r50.gd")
const CourierInterceptR51Script = preload("res://scripts/courier_intercept_r51.gd")
const StationBlackoutR52Script = preload("res://scripts/station_blackout_r52.gd")
const SAVE_PATH = "user://nebula_3d_save.json"
const SECTOR_COLORS = [Color(0.10,0.68,0.97), Color(0.64,0.35,1.0), Color(0.98,0.73,0.40), Color(1.0,0.46,0.34), Color(0.87,0.27,0.88), Color(0.24,0.92,0.88)]
const SECTOR_NAMES = ["ПОРТ АВРОРА","НЕОНОВЫЙ КВАРТАЛ","ЦИТАДЕЛЬ","ЧЁРНЫЙ РЫНОК","РАЗЛОМ","НЕКСУС"]
const SECTOR_POSITIONS = [Vector3(0,0,0),Vector3(610,0,-330),Vector3(1070,0,330),Vector3(-500,0,670),Vector3(480,0,940),Vector3(1250,0,-730)]
const MISSIONS = [
    {"title":"ПЕРВЫЙ ПОЛЁТ","hint":"Ты пилот-наёмник. Достигни золотого маяка Авроры: город просит защиты. W — газ, кнопка — автопилот.","position":Vector3(210,18,-270),"type":"reach","reward":350},
    {"title":"НЕОНОВЫЙ КВАРТАЛ","hint":"Сначала найди гражданских у сигнала бедствия, затем доставь их в убежище. На каждой точке удерживай позицию.","position":Vector3(610,20,-330),"type":"evacuation","reward":450},
    {"title":"СИГНАЛ ПЕРЕХВАТА","hint":"Аврора под огнём: наведи прицел и уничтожь 3 дрона Хелиос. Осталось видно в HUD.","position":Vector3(1070,19,330),"type":"combat","reward":900},
    {"title":"ВОЗВРАЩЕНИЕ В ПОРТ","hint":"Вернись в порт Аврора с данными обломков: знак Хелиос связывает нападение с корпорацией.","position":Vector3(0,16,0),"type":"reach","reward":600},
    {"title":"РАЗЛОМ","hint":"Просканируй три разные точки Разлома: приблизься к голубому маркеру и удерживай расстояние до завершения записи.","position":Vector3(480,23,940),"type":"scan","reward":1300},
    {"title":"НЕКСУС","hint":"Перехвати эскадрилью Хелиос: уничтожь 5 истребителей и добудь ключ к заказчику.","position":Vector3(1250,26,-730),"type":"combat","reward":2100},
    {"title":"ПРОТОКОЛ ХЕЛИОС","hint":"Найди терминал Хелиос. Его журнал раскроет, кто оплатил нападение на Аврору.","position":Vector3(690,21,-400),"type":"reach","reward":1700},
    {"title":"ПОХИЩЕННЫЙ КОНВОЙ","hint":"Сопроводи движущийся гражданский корабль до точки эвакуации. Держись рядом и уничтожай дроны, пока они не разрушили его.","position":Vector3(-500,20,670),"type":"escort","reward":2400},
    {"title":"СЕРДЦЕ РАЗЛОМА","hint":"Доставь стабилизатор в Разлом: без него атака повторится и город не удержать.","position":Vector3(520,24,1010),"type":"reach","reward":2600},
    {"title":"ПОСЛЕДНИЙ СИГНАЛ","hint":"Останови командование Хелиос у Нексуса и предъяви доказательства заговора.","position":Vector3(1290,28,-780),"type":"combat","reward":4300},
    {"title":"ТЕНИ ПОРТА","hint":"Изучи три терминала Авроры. Удерживай T или кнопку ВВОД у каждого. Не стреляй.","position":Vector3(0,26,0),"type":"investigation","reward":3200},
    {"title":"ЗАКРЫТЫЙ АРХИВ","hint":"Найди два ключа «Эхо», затем расшифруй архив. Удерживай ВВОД и защищай сервер от атак дронов.","position":Vector3(-500,32,670),"type":"archive","reward":3800},
    {"title":"КУРЬЕР «ЭХО»","hint":"Взломай приёмник, следуй за движущимся курьером, затем устрани подавители и эвакуируй данные за 90 секунд.","position":Vector3(1230,29,-710),"type":"courier","reward":4400},
    {"title":"СТАНЦИЯ БЕЗ СВЕТА","hint":"Переключи два настоящих силовых реле. Удерживай оборону реактора, стабилизируй питание и используй резервный конденсатор только один раз.","position":Vector3(530,32,1060),"type":"blackout","reward":4900}
]

var rng := RandomNumberGenerator.new()
var ship
var chase_camera: Camera3D
var camera_distance: float = 16.0
var drones: Array[Node3D] = []
var mission_index: int = 0
var credits: int = 950
var xp: int = 0
var mission_enemies: int = 0
var mission_started: bool = false
var mission_objectives_r48
var r48_escort_enemies_spawned: bool = false
var r48_last_goal: Vector3 = Vector3.ZERO
var r49_investigation
var r50_archive
var r50_archive_wave_spawned: bool = false
var r51_courier
var r51_jammer_wave_spawned: bool = false
var r52_station
var r52_hostiles_spawned: bool = false
var r49_interact_held := false
var r49_command_button: Button
var r49_terminal_button: Button
var r50_focus_button: Button
var r50_repair_button: Button
var shot_flash: float = 0.0
var hud_mission: Label
var hud_status: Label
var hud_controls: Label
var hud_notice: Label
var notice_timer: float = 0.0
var mission_beacon: Node3D
var world_timer: float = 0.0
var radar: Control
var world_pulse: float = 0.0
var lens_mode: int = 0
var last_notice: String = ""
var world_events: int = 0
var premium_architecture
var cinematic_shake: float = 0.0
var cinematic_velocity: Vector3 = Vector3.ZERO
var hud_flight: Label
var hud_objective: Label
var hud_panel: PanelContainer
var hud_canvas: CanvasLayer
var aegis_r10
var city_cladding_r10
var industrial_r11
var cinematic_post_r11
var performance_lab_r11
var graphics_quality: int = 0
var engineering_r12
var lighting_r12
var adaptive_r12
var post_interval_r12: float = 0.0
var port_r14
var store_r15
var fleet_r15
var owned_r15: Dictionary = {"ship_scout":true}
var equipped_r15: String = "ship_scout"
var weapon_r15: String = "weapon_basic"
var rockets_r15: int = 0
var wingmen_r15: Array[String] = []
var premium_r15: Dictionary = {}
var premium_client_r15
const R16_BEAM_POOL_SIZE: int = 18
const R16_RADAR_PERIOD: float = 0.12
const R16_HUD_PERIOD: float = 0.10
# R18: six independently culled base-city meshes and six neon clusters.
# Original 360 building transforms/collisions and all missions unchanged.
const R18_CITY_LIMIT = [2500.0, 1900.0, 1400.0]
const R18_NEON_LIMIT = [1100.0, 760.0, 470.0]
var r18_city_batches: Array[MultiMeshInstance3D] = []
var r18_neon_batches: Array[MultiMeshInstance3D] = []
var r18_base_tower_instances: int = 0
var r18_city_district_chunks: int = 0
var r16_beams: Array[MeshInstance3D] = []
var r16_beam_life: Array[float] = []
var r16_beam_cursor: int = 0
var r16_beam_mesh: CylinderMesh
var r16_player_laser: Material
var r16_enemy_laser: Material
var r16_radar_clock: float = 0.0
var r16_hud_clock: float = 0.0
var r16_beam_shots: int = 0
## R21: confirmed flight corridor, occlusion-aware chase camera and approved HUD.
const R21_LAUNCH_CANDIDATES = [
    Vector3(0, 34, 100), Vector3(0, 53, 102), Vector3(0, 79, 103),
    Vector3(0, 108, 104), Vector3(0, 150, 110), Vector3(0, 215, 112)
]
var r21_towers_moved: int = 0
var r21_spawn_relocations: int = 0
var r21_safe_spawn: Vector3 = Vector3(0, 34, 100)
var r21_camera_obstructions: int = 0
var r21_touch
var r21_dashboard
var garage_hub_r39
var garage_open_r39: bool = false
var r41_last_debrief: Dictionary = {}
var selected_captain_r42: String = "ada"
var pilot_training_r54: Dictionary = {"ada":0, "kai":0, "leya":0}
var hangar_modules_r56: Dictionary = HangarWorkbenchR56Script.default_roster()
var livery_owned_r59: Dictionary = HangarLiveriesR59Script.default_owned()
var livery_equipped_r59: Dictionary = HangarLiveriesR59Script.default_equipped()
const R60_CRASH_HOLD_SEC: float = 1.6
var active_wreck_r60: Node3D
var r60_crash_pending: bool = false
var r60_crash_hold_sec: float = 0.0
var r60_crash_was_contract: bool = false
var r60_crash_count: int = 0
var r60_last_impact: Vector3 = Vector3.ZERO
var r57_selected_contract: String = ""
var r57_contract_counts: Dictionary = PatrolContractsR57Script.safe_finish_counts({})
var r57_patrol = PatrolContractsR57Script.new()
var r57_reward_committed: bool = false
var r57_last_report: String = ""
var r58_risk_tier: int = 0
var r43_pending_bounty: int = 0
var r21_objective_panel: PanelContainer
var r21_ui_font: SystemFont
var r21_mobile_enabled: bool = false
var r21_launch_protection: float = 9.0
var r47_launch_camera_time: float = 0.0
var r23_cruise_button: Button
var r23_launch_button_events: int = 0
## R22: real playable golden-hour skyline, not an image/background plate.
var aurora_scenic_r22: Node3D
## R25: Browser E2E receives sanitized read-only real Godot physics state.
## Previous releases tested only headless native flight; actual WebGL
## input may differ and SwiftShader image capture has been inconclusive.
var r25_telemetry_period: float = 0.0
var r25_telemetry_samples: int = 0
## R29: visual QA capture runs through Godot's viewport, not the slow browser compositor.
var r11_capture_enabled: bool = false
var r11_capture_busy: bool = false
var r11_capture_poll_clock: float = 0.0
var r11_capture_completed_request: int = 0
## R31: expose sanitized control geometry and actual touch state only in QA mode.
var r31_mobile_qa_enabled: bool = false
## CSS-pixel mobile layout, normalized separately from WebGL framebuffer DPI.
var r31_touch_web: bool = false
var r31_mobile_css_size: Vector2i = Vector2i.ZERO
var r31_mobile_poll_clock: float = 0.0
# R33 QA-only render throttle. The full city remains loaded and physical.
var r33_swiftshader_qa_visuals_trimmed: bool = false

func _r25_emit_browser_flight_state() -> void:
    if not OS.has_feature("web") or not is_instance_valid(ship):
        return
    r25_telemetry_samples += 1
    var gap: float = -1.0
    if mission_index < MISSIONS.size():
        gap = ship.global_position.distance_to(MISSIONS[mission_index]["position"])
    # No inventory, premium entitlement, player identity, tokens, keys or
    # other private state is exposed. This is gameplay-only QA telemetry.
    var state: Dictionary = {
        "version": "R25", "ready": true,
        "x": snappedf(ship.global_position.x, 0.01),
        "y": snappedf(ship.global_position.y, 0.01),
        "z": snappedf(ship.global_position.z, 0.01),
        "speed_mps": snappedf(ship.velocity.length(), 0.01),
        "throttle": ship.last_pilot_throttle,
        "yaw": ship.last_pilot_yaw,
        "heading": snappedf(ship.rotation.y, 0.0001),
        "flight_distance": snappedf(ship.flight_distance, 0.01),
        "mission_distance": snappedf(gap, 0.01),
        "cruise": ship.cruise_assist,
        "locked": ship.controls_locked,
        "input_mask": ship.browser_input_mask,
        "browser_window_ready": ship.browser_window != null,
        "window_mask": int(ship.browser_window.__nebulaPilotMask) if ship.browser_window != null else -1,
        "browser_input_samples": ship.browser_input_samples,
        "quality": graphics_quality,
        "samples": r25_telemetry_samples
    }
    # R51: real engine control geometry and pressed-signal count let the
    # Chromium test distinguish a missed mouse click from broken autopilot.
    # Gameplay positions only; no identifiers or user account telemetry.
    if is_instance_valid(r23_cruise_button):
        var cruise_rect: Rect2 = r23_cruise_button.get_global_rect()
        state["cruise_button_visible"] = r23_cruise_button.is_visible_in_tree()
        state["cruise_button_events"] = r23_launch_button_events
        state["cruise_button_x"] = cruise_rect.get_center().x
        state["cruise_button_y"] = cruise_rect.get_center().y
        state["cruise_view_w"] = get_viewport().get_visible_rect().size.x
        state["cruise_view_h"] = get_viewport().get_visible_rect().size.y
    if garage_open_r39 and is_instance_valid(garage_hub_r39):
        var sortie_rect: Rect2 = garage_hub_r39.launch_button.get_global_rect()
        var canvas_size: Vector2 = get_viewport().get_visible_rect().size
        if r31_touch_web and r31_mobile_css_size.x > 0.0:
            canvas_size = Vector2(r31_mobile_css_size)
        state["garage_sortie_x"] = sortie_rect.position.x + sortie_rect.size.x * 0.5
        state["garage_sortie_y"] = sortie_rect.position.y + sortie_rect.size.y * 0.5
        state["garage_view_w"] = canvas_size.x
        state["garage_view_h"] = canvas_size.y
        # R44: browser QA observes real viewport presence, not a static mockup.
        state["r44_preview_present"] = (
            is_instance_valid(garage_hub_r39.ship_preview_r44) and
            is_instance_valid(garage_hub_r39.ship_preview_r44.preview_viewport) and
            is_instance_valid(garage_hub_r39.ship_preview_r44.real_airframe))
        state["r44_preview_width"] = garage_hub_r39.preview_frame_r44.size.x
        state["r44_preview_height"] = garage_hub_r39.preview_frame_r44.size.y
    if r31_mobile_qa_enabled and is_instance_valid(r21_touch):
        # The browser test must touch the actual on-screen button, not set
        # ship velocity or inject an engine-side fake input.
        var thrust_centre: Vector2 = r21_touch.button_centres.get(
            "THRUST", Vector2.ZERO)
        var boost_centre: Vector2 = r21_touch.button_centres.get(
            "BOOST", Vector2.ZERO)
        state["touch_enabled"] = r21_touch.enabled
        state["touch_count"] = r21_touch.active_touch_count
        state["touch_throttle"] = snappedf(ship.touch_throttle, 0.01)
        state["touch_boost"] = ship.touch_boost
        state["touch_view_w"] = r21_touch.viewport_pixels.x
        state["touch_view_h"] = r21_touch.viewport_pixels.y
        state["touch_safe_left"] = r21_touch.r35_safe_insets.x
        state["touch_safe_top"] = r21_touch.r35_safe_insets.y
        state["touch_safe_right"] = r21_touch.r35_safe_insets.z
        state["touch_safe_bottom"] = r21_touch.r35_safe_insets.w
        state["touch_compact_portrait"] = r21_touch.r35_compact_portrait
        state["touch_stick_x"] = r21_touch.stick_center.x
        state["touch_stick_y"] = r21_touch.stick_center.y
        state["touch_events"] = r21_touch.r31_raw_touch_events
        state["touch_dom_bridge"] = r21_touch.r34_dom_bridge_active
        state["touch_dom_events"] = r21_touch.r34_dom_event_count
        state["touch_dom_sequence"] = r21_touch.r34_dom_sequence
        state["r36_browser_touch_poll_ms"] = snappedf(
            r21_touch.r36_input_poll_latency_ms, 0.1)
        state["r36_browser_touch_poll_samples"] = r21_touch.r36_input_poll_samples
        if is_instance_valid(performance_lab_r11):
            state["r36_mobile_perf"] = performance_lab_r11.r36_mobile
            state["r36_perf_visible"] = performance_lab_r11.overlay.visible
            state["r36_perf_active"] = performance_lab_r11.benchmarking
            state["r36_perf_report_ready"] = not performance_lab_r11.last_report.is_empty()
            state["r38_quality_mode"] = graphics_quality
            state["r38_auto_enabled"] = adaptive_r12.auto_enabled
            state["r38_mode_label"] = performance_lab_r11.r38_mode_button.text
            state["r38_genuine_button_presses"] = performance_lab_r11.r38_touch_button_presses
            state["r38_mode_button_x"] = (
                performance_lab_r11.r38_mode_button.global_position.x +
                performance_lab_r11.r38_mode_button.size.x * 0.5)
            state["r38_mode_button_y"] = (
                performance_lab_r11.r38_mode_button.global_position.y +
                performance_lab_r11.r38_mode_button.size.y * 0.5)
            var fps_button: Button = performance_lab_r11.r36_launcher
            var benchmark_button: Button = performance_lab_r11.r36_start_button
            state["r36_fps_button_x"] = (
                fps_button.global_position.x + fps_button.size.x * 0.5)
            state["r36_fps_button_y"] = (
                fps_button.global_position.y + fps_button.size.y * 0.5)
            state["r36_benchmark_button_x"] = (
                benchmark_button.global_position.x + benchmark_button.size.x * 0.5)
            state["r36_benchmark_button_y"] = (
                benchmark_button.global_position.y + benchmark_button.size.y * 0.5)
        state["qa_visuals_trimmed"] = r33_swiftshader_qa_visuals_trimmed
        state["touch_last_x"] = r21_touch.r31_last_touch_position.x
        state["touch_last_y"] = r21_touch.r31_last_touch_position.y
        state["touch_last_role"] = r21_touch.r31_last_touch_role
        state["touch_css_w"] = r31_mobile_css_size.x
        state["touch_css_h"] = r31_mobile_css_size.y
        state["touch_thrust_x"] = thrust_centre.x
        state["touch_thrust_y"] = thrust_centre.y
        state["touch_boost_x"] = boost_centre.x
        state["touch_boost_y"] = boost_centre.y
    JavaScriptBridge.eval("window.__nebulaPilotTelemetry = " + JSON.stringify(state))


func _r33_trim_nonessential_qa_meshes(node: Node) -> void:
    # Hosted SwiftShader is a software GPU. Mobile input acceptance must still
    # drive the REAL Godot 3D ship and physics, but need not draw thousands of
    # city facade meshes again. Never run this outside the explicit QA URL.
    if node == ship or node is CanvasLayer:
        return
    if node is GeometryInstance3D:
        (node as GeometryInstance3D).visible = false
    for child in node.get_children():
        _r33_trim_nonessential_qa_meshes(child)


func _r31_sync_touch_viewport() -> void:
    if not r31_touch_web:
        return
    var css_w: int = int(JavaScriptBridge.eval("Math.round(window.innerWidth)"))
    var css_h: int = int(JavaScriptBridge.eval("Math.round(window.innerHeight)"))
    if css_w < 300 or css_h < 280:
        return
    var css_size := Vector2i(css_w, css_h)
    # System bars/notches can change without resizing window.innerWidth.
    var safe_changed: bool = false
    if is_instance_valid(r21_touch):
        safe_changed = r21_touch._r35_refresh_safe_insets()
    if css_size == r31_mobile_css_size:
        if safe_changed and is_instance_valid(hud_panel):
            _fit_hud()
        return
    r31_mobile_css_size = css_size
    # Godot's 1280x720 desktop content scale must not turn a portrait phone's
    # UI into a letterboxed desktop game. Normalize UI to actual CSS pixels
    # while the WebGL framebuffer remains free to scale for display DPI.
    var root_window: Window = get_window()
    root_window.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
    root_window.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_IGNORE
    root_window.content_scale_size = css_size
    if is_instance_valid(r21_touch):
        r21_touch._resize()
    if is_instance_valid(hud_panel):
        _fit_hud()


func _r11_capture_browser_frame(request_id: int) -> void:
    await RenderingServer.frame_post_draw
    var frame: Image = get_viewport().get_texture().get_image()
    if frame.is_empty():
        JavaScriptBridge.eval("window.__nebulaR11CaptureError = 'empty Godot viewport image'; window.__nebulaR11CaptureCompletedId = " + str(request_id))
        r11_capture_busy = false
        return
    var jpg: PackedByteArray = frame.save_jpg_to_buffer(0.82)
    if jpg.is_empty():
        JavaScriptBridge.eval("window.__nebulaR11CaptureError = 'Godot JPEG encoding returned no data'; window.__nebulaR11CaptureCompletedId = " + str(request_id))
        r11_capture_busy = false
        return
    var encoded: String = Marshalls.raw_to_base64(jpg)
    JavaScriptBridge.eval("window.__nebulaR11CaptureData = 'data:image/jpeg;base64," + encoded + "'; window.__nebulaR11CaptureError = ''; window.__nebulaR11CaptureCompletedId = " + str(request_id))
    r11_capture_completed_request = request_id
    r11_capture_busy = false

func _ready() -> void:
    rng.seed = 20261022
    r31_touch_web = OS.has_feature("web") and bool(JavaScriptBridge.eval(
        "navigator.maxTouchPoints > 0 || window.matchMedia('(pointer: coarse)').matches"))
    if r31_touch_web:
        _r31_sync_touch_viewport()
    r31_mobile_qa_enabled = OS.has_feature("web") and bool(JavaScriptBridge.eval(
        "new URLSearchParams(window.location.search).get('r31-mobile-qa') === '1'"))
    r11_capture_enabled = OS.has_feature("web") and bool(JavaScriptBridge.eval(
        "new URLSearchParams(window.location.search).get('r11-qa') === '1'"))
    if r11_capture_enabled:
        # Lower only the software-rendered QA page's loop rate so the frame
        # can be read back without starving the browser's main thread.
        Engine.max_fps = 24
    _setup_environment()
    _build_city()
    _spawn_player()
    _spawn_civilians_and_pirates()
    fleet_r15 = FleetCombatR15Script.new()
    fleet_r15.name = "R15_FleetCombat"
    add_child(fleet_r15)
    fleet_r15.player_ship = ship
    fleet_r15.targets = drones
    fleet_r15.ally_fired.connect(_r16_ally_fire)
    fleet_r15.missile_launched.connect(_r49_report_weapon_discharge)
    _make_hud()
    r21_dashboard = PremiumHUDR21Script.new()
    r21_dashboard.name = "R21_PremiumFlightDashboard"
    hud_canvas.add_child(r21_dashboard)
    r21_dashboard.craft = ship
    r21_touch = MobileControlsR21Script.new()
    r21_touch.name = "R21_ResponsiveMobileController"
    hud_canvas.add_child(r21_touch)
    r21_touch.player_ship = ship
    r21_touch.ui_font = r21_ui_font
    r21_touch.rocket_requested.connect(_r21_launch_missile)
    r21_touch.hangar_requested.connect(_r21_toggle_hangar)
    r21_touch.camera_requested.connect(_r21_cycle_camera)
    r21_touch.cruise_requested.connect(_r23_toggle_cruise)
    _r49_make_buttons()
    r21_mobile_enabled = r21_touch.enabled
    _r16_setup_beam_pool()
    store_r15 = HangarStoreR15Script.new()
    store_r15.name = "R15_HangarShop"
    add_child(store_r15)
    store_r15.credit_purchase_requested.connect(_r15_buy_credit)
    store_r15.premium_purchase_requested.connect(_r15_request_checkout)
    store_r15.shop_closed.connect(_r16_hangar_closed)
    premium_client_r15 = PremiumFulfillmentR15Script.new()
    premium_client_r15.name = "R15_VerifiedPaymentFulfillment"
    add_child(premium_client_r15)
    premium_client_r15.inventory_synced.connect(_r15_premium_synced)
    premium_client_r15.purchased_missile_authorized.connect(_r15_paid_missile_authorized)
    premium_client_r15.sync_failed.connect(_r15_sync_failed)
    cinematic_post_r11 = CinematicPostR11Script.new()
    cinematic_post_r11.name = "R11_CinematicPost"
    add_child(cinematic_post_r11)
    performance_lab_r11 = PerformanceLabR11Script.new()
    performance_lab_r11.name = "R11_PerformanceLab"
    add_child(performance_lab_r11)
    performance_lab_r11.r38_quality_cycle_requested.connect(_r38_cycle_quality)
    # Touch controls already exist, so the R36 FPS launcher knows the real
    # browser viewport and safe-area offsets from the R35 mobile system.
    performance_lab_r11.configure_mobile(r21_mobile_enabled, r21_touch,
        r21_touch.r35_safe_insets,
        Vector2(r31_mobile_css_size) if r31_touch_web else
            get_viewport().get_visible_rect().size)
    lighting_r12 = CinematicLightingR12Script.new()
    lighting_r12.name = "R12_CinematicLighting"
    add_child(lighting_r12)
    adaptive_r12 = AdaptiveQualityR12Script.new()
    adaptive_r12.name = "R12_AdaptiveQuality"
    add_child(adaptive_r12)
    adaptive_r12.quality_requested.connect(_r12_on_auto_quality)
    _load_progress()
    _r21_rescue_blocked_spawn()
    _r15_apply_loadout()
    # R41: never spawn combat objectives while the pilot is in the garage.
    _r39_create_garage_hub()
    # Start the browser on HIGH instead of MAX. Real FPS can then
    # automatically downshift further; native CI retains deterministic MAX.
    if OS.has_feature("web"):
        _set_graphics_quality(1)
        adaptive_r12.set_auto(true)
    if r31_mobile_qa_enabled:
        # This branch is strictly URL opt-in for CI and cannot affect normal
        # players. Physical hull, collisions, controls, missions, input stack
        # and visible cockpit HUD remain authentic.
        adaptive_r12.set_auto(false)
        _set_graphics_quality(2)
        Engine.max_fps = 20
        _r33_trim_nonessential_qa_meshes(self)
        r33_swiftshader_qa_visuals_trimmed = true
    performance_lab_r11.set_r38_auto_enabled(adaptive_r12.auto_enabled)
    # Startup quality selection posts a toast; clear it so the opening skyline stays visible.
    hud_notice.text = ""
    notice_timer = 0.0
    last_notice = ""
    # Keep the opening skyline clear; mission and objective HUD carry the scene context.
    get_viewport().size_changed.connect(_fit_hud)
    _fit_hud()
    _r25_emit_browser_flight_state()

func _setup_environment() -> void:
    var node := WorldEnvironment.new()
    var env := Environment.new()
    # A cinematic sky and softer physical light, without unsupported Web-only SSR effects.
    var sky := Sky.new()
    var atmosphere := ProceduralSkyMaterial.new()
    atmosphere.sky_top_color = Color(0.008,0.024,0.078)
    atmosphere.sky_horizon_color = Color(0.115,0.18,0.28)
    atmosphere.ground_bottom_color = Color(0.008,0.012,0.028)
    atmosphere.ground_horizon_color = Color(0.10,0.15,0.24)
    sky.sky_material = atmosphere
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.ambient_light_energy = 0.49
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    # Compatibility renderer supports subtle glow and post-tonemap grading.
    # Never enable unsupported SSIL, SSR or volumetric fog.
    env.glow_enabled = true
    env.glow_bloom = 0.018
    env.adjustment_enabled = true
    env.adjustment_brightness = 0.94
    env.adjustment_contrast = 1.08
    env.adjustment_saturation = 0.95
    env.fog_enabled = true
    env.fog_light_color = Color(0.36,0.39,0.44)
    env.fog_density = 0.00031
    node.environment = env
    node.name = "R11_CinematicWorldEnvironment"
    add_child(node)
    var sun := DirectionalLight3D.new()
    sun.name = "OrbitalSun"
    sun.rotation_degrees = Vector3(-34.0,-52.0,0.0)
    sun.light_color = Color(1.0,0.85,0.70)
    sun.light_energy = 1.05
    sun.shadow_enabled = true
    add_child(sun)
    var fill := DirectionalLight3D.new()
    fill.name = "DeepBlueFill"
    fill.rotation_degrees = Vector3(-18,128,0)
    fill.light_color = Color(0.22,0.48,1.0)
    fill.light_energy = 0.20
    add_child(fill)
    var deck := MeshInstance3D.new()
    var plane := PlaneMesh.new()
    plane.size = Vector2(4100,4100)
    deck.mesh = plane
    deck.material_override = _mat(Color(0.023,0.040,0.075))
    deck.position.y = -5.0
    add_child(deck)

func _mat(col: Color, glow: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = col
    mat.metallic = 0.58
    mat.roughness = 0.46
    if glow > 0.01:
        mat.emission_enabled = true
        mat.emission = col
        mat.emission_energy_multiplier = glow
    return mat

func _box(pos: Vector3, size: Vector3, mat: Material, parent: Node3D) -> MeshInstance3D:
    var instance := MeshInstance3D.new()
    var mesh := BoxMesh.new()
    mesh.size = size
    instance.mesh = mesh
    instance.material_override = mat
    instance.position = pos
    parent.add_child(instance)
    return instance

func _build_city() -> void:
    # R18: each district is an independent MultiMesh with tight local GPU
    # bounds. Old global 360-instance batches forced unrelated sectors into
    # the same frustum/LOD decision and wasted GPU work.
    var count_per_district: int = int(360 / SECTOR_POSITIONS.size())
    var tower_geometry := BoxMesh.new()
    tower_geometry.size = Vector3.ONE
    var lamp_geometry := BoxMesh.new()
    lamp_geometry.size = Vector3.ONE
    premium_architecture = PremiumArchitectureScript.new()
    premium_architecture.name = "PremiumArchitecture"
    add_child(premium_architecture)
    var tower_material: StandardMaterial3D = premium_architecture.make_facade_material()
    var tower_data: Array[Dictionary] = []
    var main_parent := Node3D.new()
    main_parent.name = "CityTowers_MultiMesh"
    add_child(main_parent)
    var neon_parent := Node3D.new()
    neon_parent.name = "SkylineNeonCrowns"
    add_child(neon_parent)
    var glow_material := _mat(Color(0.78,0.83,0.86), 0.22)
    glow_material.vertex_color_use_as_albedo = true
    var multimeshes: Array[MultiMesh] = []
    var neon_multimeshes: Array[MultiMesh] = []
    for district in SECTOR_POSITIONS.size():
        var multimesh := MultiMesh.new()
        multimesh.transform_format = MultiMesh.TRANSFORM_3D
        multimesh.use_colors = true
        multimesh.mesh = tower_geometry
        multimesh.instance_count = count_per_district
        multimeshes.append(multimesh)
        var inst := MultiMeshInstance3D.new()
        inst.name = "R18_BaseCityDistrict_%02d" % district
        inst.position = SECTOR_POSITIONS[district]
        inst.multimesh = multimesh
        inst.material_override = tower_material
        main_parent.add_child(inst)
        r18_city_batches.append(inst)
        var skylights := MultiMesh.new()
        skylights.transform_format = MultiMesh.TRANSFORM_3D
        skylights.use_colors = true
        skylights.mesh = lamp_geometry
        skylights.instance_count = count_per_district
        neon_multimeshes.append(skylights)
        var glow_layer := MultiMeshInstance3D.new()
        glow_layer.name = "R18_NeonDistrict_%02d" % district
        glow_layer.position = SECTOR_POSITIONS[district]
        glow_layer.multimesh = skylights
        glow_layer.material_override = glow_material
        neon_parent.add_child(glow_layer)
        r18_neon_batches.append(glow_layer)
    r18_city_district_chunks = r18_city_batches.size()
    for i in range(360):
        var sector: int = i % SECTOR_POSITIONS.size()
        var center: Vector3 = SECTOR_POSITIONS[sector]
        var radius: float = rng.randf_range(130.0,320.0)
        var bearing: float = rng.randf_range(0.0,TAU)
        var w: float = rng.randf_range(12.0,29.0)
        var height: float = rng.randf_range(25.0,170.0)
        var depth: float = rng.randf_range(12.0,29.0)
        var pos := center + Vector3(cos(bearing)*radius,height*0.5,sin(bearing)*radius)
        # Keep the original 360 real towers/colliders, but shift a few away
        # from the player's takeoff and chase-camera corridor in Aurora.
        # Previous releases started the ship beside massive bright facades.
        if sector == 0 and absf(pos.x) < 88.0 and pos.z > -145.0 and pos.z < 245.0:
            pos.x = (1.0 if pos.x >= 0.0 else -1.0) * (118.0 + absf(pos.x) * 0.18)
            r21_towers_moved += 1
        var slot: int = int(i / SECTOR_POSITIONS.size())
        multimeshes[sector].set_instance_transform(
            slot, Transform3D(Basis.IDENTITY.scaled(Vector3(w, height, depth)), pos - center))
        r18_base_tower_instances += 1
        tower_data.append({"pos":pos,"w":w,"depth":depth,"h":height,"sector":sector})
        var col: Color = SECTOR_COLORS[sector].darkened(rng.randf_range(0.42,0.70))
        multimeshes[sector].set_instance_color(slot, col)
        neon_multimeshes[sector].set_instance_transform(slot, Transform3D(
            Basis.IDENTITY.scaled(Vector3(w + 2.0, 2.6, depth + 2.0)),
            pos - center + Vector3(0, height * 0.5 + 1.6, 0)))
        neon_multimeshes[sector].set_instance_color(slot, SECTOR_COLORS[sector].lightened(0.14))
        var solid := StaticBody3D.new()
        solid.name = "TowerCollision_%03d" % i
        solid.position = pos
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(w,height,depth)
        collision.shape = shape
        solid.add_child(collision)
        add_child(solid)
    _r18_set_city_quality()
    for i in SECTOR_POSITIONS.size():
        var base: Vector3 = SECTOR_POSITIONS[i]
        _build_sector(base,SECTOR_COLORS[i],SECTOR_NAMES[i],i)
    premium_architecture.build(tower_data,SECTOR_POSITIONS,SECTOR_COLORS)
    var architectural_detail_r4 := ArchitecturalDetailR4Script.new()
    architectural_detail_r4.name = "ArchitecturalDetailR4"
    add_child(architectural_detail_r4)
    architectural_detail_r4.build(tower_data, SECTOR_POSITIONS)
    var detail_r5 := CitySetDressingR5Script.new()
    detail_r5.name = "HighDetailCityR5"
    add_child(detail_r5)
    detail_r5.build(tower_data, SECTOR_POSITIONS)
    var docks_r6 := OrbitalDocksR6Script.new()
    docks_r6.name = "HeroMegadocksR6"
    add_child(docks_r6)
    docks_r6.build(SECTOR_POSITIONS, SECTOR_COLORS)
    var skyline_r6 := SculpturalSkylineR6Script.new()
    skyline_r6.name = "SculpturalSkylineR6"
    add_child(skyline_r6)
    skyline_r6.build(SECTOR_POSITIONS, SECTOR_COLORS)
    var fleet_r7 := CapitalFleetR7Script.new()
    fleet_r7.name = "CapitalFleetR7"
    add_child(fleet_r7)
    fleet_r7.build(SECTOR_POSITIONS)
    var industry_r9 := OrbitalIndustryR9Script.new()
    industry_r9.name = "OrbitalIndustryR9"
    add_child(industry_r9)
    industry_r9.build(SECTOR_POSITIONS)
    aegis_r10 = AegisMegadockR10Script.new()
    aegis_r10.name = "AegisMegadocksR10"
    add_child(aegis_r10)
    aegis_r10.build(SECTOR_POSITIONS)
    city_cladding_r10 = CityCladdingR10Script.new()
    city_cladding_r10.name = "R10_ArchitecturalCladding"
    add_child(city_cladding_r10)
    city_cladding_r10.build(tower_data, SECTOR_POSITIONS)
    industrial_r11 = IndustrialEnvironmentR11Script.new()
    industrial_r11.name = "R11_IndustrialHeroEnvironment"
    add_child(industrial_r11)
    industrial_r11.build(SECTOR_POSITIONS)
    engineering_r12 = EngineeringCampusR12Script.new()
    engineering_r12.name = "R12_AerospaceEngineeringCampus"
    add_child(engineering_r12)
    engineering_r12.build(SECTOR_POSITIONS)
    port_r14 = CinematicPortR14Script.new()
    port_r14.name = "R14_SculptedCinematicPorts"
    add_child(port_r14)
    port_r14.build(SECTOR_POSITIONS)
    aurora_scenic_r22 = AuroraScenicR22Script.new()
    aurora_scenic_r22.name = "R22_PhysicalGoldenAurora"
    add_child(aurora_scenic_r22)
    aurora_scenic_r22.build()
    _build_starfield()

func _build_sector(center: Vector3, tint: Color, name: String, index: int) -> void:
    # Landmark navigation tower; premium_architecture builds the actual dock.
    # R2's enormous emission toruses have been removed: they crossed the camera
    # and blew out the full frame on WebGL.
    var group := Node3D.new()
    group.name = name
    group.position = center + Vector3(91.0,0,-88.0)
    add_child(group)
    _box(Vector3(0,26,0),Vector3(12,52,12),_mat(Color(0.09,0.15,0.22)),group)
    _box(Vector3(0,55,0),Vector3(19,7,19),_mat(tint.darkened(0.28),0.40),group)
    _box(Vector3(0,74,0),Vector3(4,33,4),_mat(Color(0.12,0.23,0.34)),group)
    _box(Vector3(0,91,0),Vector3(8,2,8),_mat(tint,1.4),group)
    for side in [-1.0,1.0]:
        _box(Vector3(side*11,28,0),Vector3(1.2,42,4),_mat(tint.darkened(0.3),0.65),group)
    var text := Label3D.new()
    text.text = name
    text.font_size = 50
    text.pixel_size = 0.045
    text.modulate = tint.lightened(0.28)
    text.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    text.position = Vector3(0,111,0)
    group.add_child(text)
    var light := OmniLight3D.new()
    light.light_color = tint
    light.light_energy = 1.15
    light.omni_range = 50.0
    light.position.y = 60.0
    group.add_child(light)

func _build_starfield() -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    var unit := SphereMesh.new()
    unit.radius = 0.45
    unit.height = 0.9
    mm.mesh = unit
    mm.instance_count = 430
    var node := MultiMeshInstance3D.new()
    node.name = "DistantStars"
    node.multimesh = mm
    node.material_override = _mat(Color(0.55,0.80,1.0),2.0)
    add_child(node)
    for i in 430:
        var v := Vector3(rng.randf_range(-1850,1850),rng.randf_range(185,620),rng.randf_range(-1850,1850))
        mm.set_instance_transform(i,Transform3D(Basis.IDENTITY,v))

func _spawn_player() -> void:
    ship = ShipScript.new()
    ship.name = "PlayerShip"
    # A Node3D has no global transform before it belongs to the SceneTree.
    # Use parent-relative spawn transform until add_child completes.
    ship.position = R21_LAUNCH_CANDIDATES[0]
    add_child(ship)
    ship.fired.connect(_on_ship_fire)
    chase_camera = Camera3D.new()
    chase_camera.current = true
    chase_camera.fov = 64.0
    add_child(chase_camera)
    chase_camera.global_position = ship.global_position + Vector3(0,6,19)

func _r21_rescue_blocked_spawn() -> void:
    # Previous local save locations remain respected if safe. A collided
    # legacy save or first spawn is rescued onto a collision-clear corridor.
    var check := SphereShape3D.new()
    check.radius = 2.2
    var query := PhysicsShapeQueryParameters3D.new()
    query.shape = check
    query.collision_mask = 1
    query.exclude = [ship.get_rid()]
    query.transform = Transform3D(Basis.IDENTITY, ship.global_position)
    var space := get_world_3d().direct_space_state
    if space.intersect_shape(query, 1).is_empty():
        r21_safe_spawn = ship.global_position
        return
    for candidate in R21_LAUNCH_CANDIDATES:
        query.transform = Transform3D(Basis.IDENTITY, candidate)
        if space.intersect_shape(query, 1).is_empty():
            ship.global_position = candidate
            ship.velocity = Vector3.ZERO
            r21_safe_spawn = candidate
            r21_spawn_relocations += 1
            return
    # High-altitude emergency launch point; never leave the player trapped.
    ship.global_position = Vector3(0, 245, 112)
    ship.velocity = Vector3.ZERO
    r21_safe_spawn = ship.global_position
    r21_spawn_relocations += 1

func _r21_toggle_hangar() -> void:
    if r57_patrol.active:
        # A running timed contract must not open a shop overlay that locks
        # live flight controls while the route timer continues.
        _show_notice("КОНТРАКТ В ПОЛЁТЕ · МАГАЗИН ПОСЛЕ ВОЗВРАЩЕНИЯ")
        return
    if garage_open_r39:
        _r39_open_shop()
        return
    if not is_instance_valid(store_r15):
        return
    if store_r15.visible:
        store_r15.close()
    elif ship.global_position.distance_to(SECTOR_POSITIONS[0]) <= 150.0:
        store_r15.open(credits, owned_r15, equipped_r15)
        ship.set_cruise_assist(false)
        ship.controls_locked = true
        if is_instance_valid(r21_touch):
            r21_touch.set_shop_open(true)
    else:
        _show_notice("АНГАР ДОСТУПЕН ТОЛЬКО В ПОРТУ АВРОРА")

func _r23_toggle_cruise() -> void:
    if garage_open_r39 or not is_instance_valid(ship):
        return
    if is_instance_valid(store_r15) and store_r15.visible:
        return
    if ship.controls_locked:
        return
    ship.set_cruise_assist(not ship.cruise_assist)
    if ship.cruise_assist and mission_index < MISSIONS.size():
        # R49: a staged objective always owns the current navigation goal.
        # Do not overwrite the next terminal/rescue stop with the old mission center.
        if is_instance_valid(r52_station):
            ship.set_navigation_target(r52_station.objective_position())
        elif is_instance_valid(r51_courier):
            # Lead the moving signal for steering, but keep the beacon and
            # actual capture gate on its real physical position.
            ship.set_navigation_target(
                r51_courier.navigation_position(ship.global_position))
        elif is_instance_valid(r50_archive):
            ship.set_navigation_target(r50_archive.objective_position())
        elif is_instance_valid(r49_investigation):
            ship.set_navigation_target(r49_investigation.objective_position())
        elif is_instance_valid(mission_objectives_r48) and mission_objectives_r48.active:
            ship.set_navigation_target(mission_objectives_r48.objective_position())
        else:
            ship.set_navigation_target(MISSIONS[mission_index]["position"])
    r23_launch_button_events += 1
    if ship.cruise_assist:
        _show_notice("АВТОПИЛОТ К ЦЕЛИ · ЛЮБОЕ УПРАВЛЕНИЕ ОТКЛЮЧАЕТ")
    else:
        _show_notice("АВТОТЯГА ОТКЛЮЧЕНА · W ДЛЯ ПОЛЁТА")

func _r21_launch_missile() -> void:
    if garage_open_r39:
        return
    if is_instance_valid(store_r15) and store_r15.visible:
        return
    if fleet_r15.launch_missile():
        rockets_r15 = fleet_r15.missiles
        _save_progress()
        _show_notice("РАКЕТА · ОСТАЛОСЬ %d" % rockets_r15)
    else:
        _show_notice("РАКЕТЫ / ЦЕЛЬ НЕ ДОСТУПНЫ")

func _r21_cycle_camera() -> void:
    lens_mode = (lens_mode + 1) % 3
    camera_distance = [14.5,23.0,33.0][lens_mode]
    _show_notice("КАМЕРА · %d / 3" % (lens_mode + 1))

func _spawn_civilians_and_pirates() -> void:
    for i in 22:
        var drone = DroneScript.new()
        drone.hostile = i%4==0
        drone.speed = 21.0 if drone.hostile else 11.0
        drone.target = ship
        var sec: Vector3 = SECTOR_POSITIONS[i%SECTOR_POSITIONS.size()]
        drone.position = sec+Vector3(rng.randf_range(-140,140),rng.randf_range(13,60),rng.randf_range(-140,140))
        drone.destroyed.connect(_on_drone_destroyed)
        drone.fired.connect(_on_drone_fire)
        add_child(drone)
        drones.append(drone)

func _make_hud() -> void:
    var ui := CanvasLayer.new()
    ui.layer = 5
    add_child(ui)
    hud_canvas = ui
    var surface := Control.new()
    surface.name = "R21_ApprovedAuroraOverlay"
    surface.set_anchors_preset(Control.PRESET_FULL_RECT)
    surface.mouse_filter = Control.MOUSE_FILTER_IGNORE
    ui.add_child(surface)
    r21_ui_font = SystemFont.new()
    r21_ui_font.font_names = PackedStringArray([
        "Inter", "Manrope", "Segoe UI", "Noto Sans", "Roboto", "Arial"])
    var block := PanelContainer.new()
    block.name = "R21_GlassMissionBrief"
    block.set_anchors_preset(Control.PRESET_TOP_LEFT)
    block.offset_left = 20.0
    block.offset_top = 22.0
    block.offset_right = 540.0
    block.offset_bottom = 150.0
    var frame := StyleBoxFlat.new()
    frame.bg_color = Color(0.013,0.027,0.040,0.87)
    frame.border_color = Color(0.29,0.54,0.62,0.72)
    frame.set_border_width_all(1)
    frame.set_corner_radius_all(10)
    frame.content_margin_left = 18
    frame.content_margin_right = 18
    frame.content_margin_top = 15
    frame.content_margin_bottom = 14
    block.add_theme_stylebox_override("panel",frame)
    surface.add_child(block)
    hud_panel = block
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation",10)
    block.add_child(stack)
    hud_mission = Label.new()
    hud_mission.add_theme_font_override("font",r21_ui_font)
    hud_mission.add_theme_font_size_override("font_size",23)
    hud_mission.add_theme_color_override("font_color",Color(0.99,0.75,0.39))
    hud_mission.clip_text = true
    stack.add_child(hud_mission)
    hud_status = Label.new()
    hud_status.add_theme_font_override("font",r21_ui_font)
    hud_status.add_theme_font_size_override("font_size",15)
    hud_status.add_theme_color_override("font_color",Color(0.78,0.86,0.89))
    hud_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    stack.add_child(hud_status)
    hud_controls = Label.new()
    hud_controls.text = "WASD — ПОЛЁТ     Q/E — ВЫСОТА     Shift — ФОРСАЖ     Space — ОГОНЬ     R — РАКЕТА     H — АНГАР     F3 — ГРАФИКА"
    hud_controls.add_theme_font_override("font",r21_ui_font)
    hud_controls.add_theme_font_size_override("font_size",12)
    hud_controls.add_theme_color_override("font_color",Color(0.71,0.80,0.83))
    hud_controls.anchor_top = 1.0
    hud_controls.anchor_bottom = 1.0
    hud_controls.offset_left = 24.0
    hud_controls.offset_top = -45.0
    hud_controls.offset_right = 1060.0
    hud_controls.offset_bottom = -16.0
    surface.add_child(hud_controls)
    radar = RadarScript.new()
    radar.name = "WaypointRadar"
    radar.range_meters = fleet_r15.radar_range_r56()
    radar.anchor_top = 1.0
    radar.anchor_bottom = 1.0
    radar.offset_left = 16.0
    radar.offset_right = 236.0
    radar.offset_top = -277.0
    radar.offset_bottom = -57.0
    surface.add_child(radar)
    hud_flight = Label.new()
    hud_flight.text = "REMIX ARENA  /  NEBULA ASCENSION"
    hud_flight.add_theme_font_override("font",r21_ui_font)
    hud_flight.add_theme_font_size_override("font_size",14)
    hud_flight.add_theme_color_override("font_color",Color(0.54,0.82,0.90))
    hud_flight.anchor_left = 1.0
    hud_flight.anchor_right = 1.0
    hud_flight.offset_left = -380.0
    hud_flight.offset_right = -20.0
    hud_flight.offset_top = 25.0
    hud_flight.offset_bottom = 55.0
    hud_flight.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    surface.add_child(hud_flight)
    var objective_panel := PanelContainer.new()
    objective_panel.name = "R21_GlassObjective"
    objective_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
    objective_panel.offset_left = -360.0
    objective_panel.offset_right = -20.0
    objective_panel.offset_top = 67.0
    objective_panel.offset_bottom = 119.0
    var objective_style := StyleBoxFlat.new()
    objective_style.bg_color = Color(0.016,0.031,0.044,0.87)
    objective_style.border_color = Color(0.66,0.44,0.23,0.77)
    objective_style.set_border_width_all(1)
    objective_style.set_corner_radius_all(8)
    objective_style.content_margin_left = 13
    objective_style.content_margin_right = 13
    objective_style.content_margin_top = 8
    objective_style.content_margin_bottom = 8
    objective_panel.add_theme_stylebox_override("panel", objective_style)
    surface.add_child(objective_panel)
    r21_objective_panel = objective_panel
    hud_objective = Label.new()
    hud_objective.add_theme_font_override("font",r21_ui_font)
    hud_objective.add_theme_font_size_override("font_size",16)
    hud_objective.add_theme_color_override("font_color",Color(1.0,0.73,0.33))
    hud_objective.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    objective_panel.add_child(hud_objective)
    hud_notice = Label.new()
    hud_notice.add_theme_font_override("font",r21_ui_font)
    hud_notice.add_theme_font_size_override("font_size",20)
    hud_notice.add_theme_color_override("font_color",Color(1.0,0.77,0.43))
    hud_notice.set_anchors_preset(Control.PRESET_CENTER_TOP)
    hud_notice.offset_left = -240.0
    hud_notice.offset_top = 146.0
    hud_notice.offset_right = 240.0
    hud_notice.offset_bottom = 180.0
    hud_notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    surface.add_child(hud_notice)
    # A real clickable start/stop control. This makes first flight possible
    # with a mouse even if the browser swallowed WASD or a non-Latin layout.
    r23_cruise_button = Button.new()
    r23_cruise_button.name = "R23_StartRealFlight"
    r23_cruise_button.focus_mode = Control.FOCUS_NONE
    r23_cruise_button.text = "▶  НАЧАТЬ ПОЛЁТ"
    r23_cruise_button.anchor_left = 0.5
    r23_cruise_button.anchor_right = 0.5
    r23_cruise_button.anchor_top = 1.0
    r23_cruise_button.anchor_bottom = 1.0
    r23_cruise_button.offset_left = -122.0
    r23_cruise_button.offset_right = 122.0
    r23_cruise_button.offset_top = -96.0
    r23_cruise_button.offset_bottom = -45.0
    r23_cruise_button.add_theme_font_override("font",r21_ui_font)
    r23_cruise_button.add_theme_font_size_override("font_size",17)
    r23_cruise_button.add_theme_color_override("font_color",Color(0.91,0.96,0.98))
    var cruise_style := StyleBoxFlat.new()
    cruise_style.bg_color = Color(0.025,0.065,0.094,0.93)
    cruise_style.border_color = Color(0.27,0.76,0.88,0.87)
    cruise_style.set_border_width_all(1)
    cruise_style.set_corner_radius_all(8)
    cruise_style.content_margin_left = 14
    cruise_style.content_margin_right = 14
    r23_cruise_button.add_theme_stylebox_override("normal",cruise_style)
    r23_cruise_button.add_theme_stylebox_override("hover",cruise_style)
    r23_cruise_button.add_theme_stylebox_override("pressed",cruise_style)
    r23_cruise_button.pressed.connect(_r23_toggle_cruise)
    surface.add_child(r23_cruise_button)

func _process(delta: float) -> void:
    if not is_instance_valid(ship): return
    world_timer += delta
    world_pulse += delta
    if r31_touch_web:
        r31_mobile_poll_clock += delta
        if r31_mobile_poll_clock >= 1.0:
            r31_mobile_poll_clock = 0.0
            _r31_sync_touch_viewport()
    if r11_capture_enabled:
        r11_capture_poll_clock += delta
        if r11_capture_poll_clock >= 0.25 and not r11_capture_busy:
            r11_capture_poll_clock = 0.0
            var requested_capture: int = int(JavaScriptBridge.eval(
                "Number(window.__nebulaR11CaptureRequestId || 0)"))
            if requested_capture > r11_capture_completed_request:
                r11_capture_busy = true
                call_deferred("_r11_capture_browser_frame", requested_capture)
    if OS.has_feature("web"):
        r25_telemetry_period += delta
        if r25_telemetry_period >= 0.20:
            r25_telemetry_period = fmod(r25_telemetry_period, 0.20)
            _r25_emit_browser_flight_state()
    r21_launch_protection = maxf(0.0, r21_launch_protection - delta)
    if not garage_open_r39 and world_pulse > 92.0 and mission_index > 1 and mission_index != 7 and mission_index != 10 and mission_index != 11 and mission_index != 12 and ship.global_position.distance_to(SECTOR_POSITIONS[0]) > 270.0:
        world_pulse = 0.0
        _spawn_pirate_ambush()
    _r16_update_beam_pool(delta)
    notice_timer = maxf(0.0, notice_timer-delta)
    if notice_timer <= 0.0: hud_notice.text = ""
    var basis: Basis = ship.global_transform.basis
    var speed: float = ship.velocity.length()
    post_interval_r12 += delta
    if post_interval_r12 >= 0.12 and is_instance_valid(cinematic_post_r11):
        post_interval_r12 = 0.0
        cinematic_post_r11.set_flight_velocity(speed)
    var desired_distance: float = camera_distance + minf(5.0, speed * 0.035)
    var desired_height: float = 4.6 + minf(2.6, speed * 0.02)
    var target: Vector3 = ship.global_position + Vector3.UP * 1.5
    var ideal: Vector3 = ship.global_position + basis.z * desired_distance + Vector3.UP * desired_height
    # Camera collision: sweep from the player to the desired camera point.
    # Buildings behind the aircraft must never occupy the whole screen.
    var camera_query := PhysicsRayQueryParameters3D.create(target, ideal)
    camera_query.exclude = [ship.get_rid()]
    var obstruction: Dictionary = get_world_3d().direct_space_state.intersect_ray(camera_query)
    if not obstruction.is_empty():
        var delta_to_wall: Vector3 = obstruction["position"] - target
        ideal = target + delta_to_wall.limit_length(
            maxf(2.0, delta_to_wall.length() - 1.1))
        r21_camera_obstructions += 1
    chase_camera.global_position = chase_camera.global_position.lerp(ideal,
        1.0 - exp(-8.0 * delta))
    # A second collision query prevents lerp from crossing newly approached walls.
    camera_query.to = chase_camera.global_position
    obstruction = get_world_3d().direct_space_state.intersect_ray(camera_query)
    if not obstruction.is_empty():
        chase_camera.global_position = target + (
            obstruction["position"] - target) * 0.82
    chase_camera.look_at(ship.global_position - basis.z * 14.0 +
        Vector3.UP * 1.2, Vector3.UP)
    # R47: a short real chase-camera field-of-view sweep on launch.
    # Unlike a blocking cutscene, this never delays physics or touch input.
    var reveal: float = 9.0 * clampf(r47_launch_camera_time / 1.05, 0.0, 1.0)
    chase_camera.fov = lerpf(chase_camera.fov,
        65.0 + minf(6.0, speed * 0.060) + reveal,
        1.0 - exp((-7.0 if reveal > 0.0 else -1.8) * delta))
    r47_launch_camera_time = maxf(0.0, r47_launch_camera_time - delta)
    # R60: the player actually sees a physical wreck for 1.6 seconds
    # at the exact crash point. No ghost intact craft or immediate teleport.
    if r60_crash_pending:
        r60_crash_hold_sec = maxf(0.0, r60_crash_hold_sec - delta)
        if r60_crash_hold_sec <= 0.0:
            _r60_finish_actual_crash()
        return
    if not garage_open_r39 and ship.hull <= 0.0:
        _r60_begin_actual_crash()
        return
    _mission_tick(delta)
    if is_instance_valid(r21_dashboard):
        r21_dashboard.show_objective = mission_index < MISSIONS.size() or r57_patrol.active
        if r21_dashboard.show_objective:
            r21_dashboard.objective = _active_mission_goal()
    if garage_open_r39:
        # The dock is a safe room, not a place for pirates to farm the player.
        ship.shield = fleet_r15.ship_shield_cap()
        ship.hull = fleet_r15.ship_hull_cap()
    elif ship.hull <= 0.0:
        # Normally handled by the R60 crash state before mission ticking.
        # This branch is retained defensively against an external revival.
        _r60_begin_actual_crash()
    elif ship.global_position.distance_to(Vector3(0,19,78))<70:
        ship.shield = minf(fleet_r15.ship_shield_cap(),ship.shield+12.0*delta)
        ship.hull = minf(fleet_r15.ship_hull_cap(),ship.hull+4.0*delta)
    # UI and radar at 8-10 Hz, not every rendered frame. This also
    # avoids rebuilding strings and scanning all enemies 60+ times per second.
    r16_hud_clock += delta
    if r16_hud_clock >= R16_HUD_PERIOD:
        r16_hud_clock = fmod(r16_hud_clock, R16_HUD_PERIOD)
        _update_hud()
    r16_radar_clock += delta
    if r16_radar_clock >= R16_RADAR_PERIOD and is_instance_valid(radar):
        r16_radar_clock = fmod(r16_radar_clock, R16_RADAR_PERIOD)
        radar.player_position = ship.global_position
        radar.player_forward = -ship.global_transform.basis.z
        radar.has_objective = mission_index < MISSIONS.size() or r57_patrol.active
        if radar.has_objective:
            radar.objective = _active_mission_goal()
        radar.targets.clear()
        for n in drones:
            if is_instance_valid(n) and n.hostile and n.global_position.distance_squared_to(ship.global_position) < 211600.0:
                radar.targets.append(n.global_position)
        radar.queue_redraw()
    if world_timer>=25.0:
        world_timer=0.0
        _save_progress()

func _mission_tick(dt: float) -> void:
    if garage_open_r39:
        return
    if mission_index >= MISSIONS.size():
        _r57_patrol_tick(dt)
        return
    var mission: Dictionary = MISSIONS[mission_index]
    var target: Vector3 = mission["position"]
    if is_instance_valid(r52_station):
        var result_r52: String = r52_station.step(dt,
            ship.global_position, r49_interact_held or
            Input.is_key_pressed(KEY_T) or Input.is_physical_key_pressed(KEY_T))
        if r52_station.is_live_reactor() and not r52_hostiles_spawned:
            _r52_spawn_reactor_threats()
        var live_goal_r52: Vector3 = r52_station.objective_position()
        if is_instance_valid(mission_beacon):
            mission_beacon.global_position = live_goal_r52
        if r48_last_goal.distance_to(live_goal_r52) > 4.0:
            r48_last_goal = live_goal_r52
            ship.set_navigation_target(live_goal_r52)
        if result_r52 == "event":
            r49_interact_held = false
            _show_notice(r52_station.last_event)
        elif result_r52 == "failed":
            _r43_fail_sortie(r52_station.last_event)
        elif result_r52 == "success":
            _complete_mission()
        return
    if is_instance_valid(r51_courier):
        var jammer_count: int = _r51_active_interference()
        var result_r51: String = r51_courier.step(dt, ship.global_position,
            r49_interact_held or Input.is_key_pressed(KEY_T) or
            Input.is_physical_key_pressed(KEY_T), jammer_count)
        if r51_courier.is_extraction_active() and not r51_jammer_wave_spawned:
            _r51_spawn_jammers()
        var next_r51_goal: Vector3 = r51_courier.objective_position()
        var r51_flight_guidance: Vector3 = r51_courier.navigation_position(
            ship.global_position)
        # The beacon and the 95m capture condition remain at the real ship;
        # only the autopilot aims a bounded distance ahead of its trajectory.
        if is_instance_valid(mission_beacon):
            mission_beacon.global_position = next_r51_goal
        if r48_last_goal.distance_to(r51_flight_guidance) > 4.0:
            r48_last_goal = r51_flight_guidance
            ship.set_navigation_target(r51_flight_guidance)
        if result_r51 == "event":
            # Releasing the receiver or hiding a touch button can skip a
            # button_up signal. A NEW physical press is mandatory for the
            # final extraction; never inherit the previous station's hold.
            r49_interact_held = false
            _show_notice(r51_courier.last_event)
        elif result_r51 == "failed":
            # Report the actual failure condition (lost courier or timed
            # extraction), without rewarding an incomplete mission.
            _r43_fail_sortie(r51_courier.last_event if (
                not r51_courier.last_event.is_empty()) else
                "Данные «Эхо» потеряны. Повтори перехват.")
        elif result_r51 == "success":
            _complete_mission()
        return
    if is_instance_valid(r50_archive):
        var archive_result: String = r50_archive.step(dt, ship.global_position,
            r49_interact_held or Input.is_key_pressed(KEY_T) or
            Input.is_physical_key_pressed(KEY_T))
        var archive_goal: Vector3 = r50_archive.objective_position()
        if not r50_archive_wave_spawned and r50_archive.combat_started:
            _r50_spawn_archive_threats()
        if is_instance_valid(mission_beacon):
            mission_beacon.global_position = archive_goal
        if r48_last_goal.distance_to(archive_goal) > 5.0:
            r48_last_goal = archive_goal
            ship.set_navigation_target(archive_goal)
        if archive_result == "event":
            _show_notice(r50_archive.last_event)
        elif archive_result == "failed":
            _r43_fail_sortie("Архив уничтожен во время загрузки. Повтори вылет и защити сервер.")
        elif archive_result == "success":
            _complete_mission()
        return
    if is_instance_valid(r49_investigation):
        var result_r49: String = r49_investigation.step(dt, ship.global_position,
            r49_interact_held or Input.is_key_pressed(KEY_T) or
            Input.is_physical_key_pressed(KEY_T))
        var goal_r49: Vector3 = r49_investigation.objective_position()
        if is_instance_valid(mission_beacon):
            mission_beacon.global_position = goal_r49
        if r48_last_goal.distance_to(goal_r49) > 5.0:
            r48_last_goal = goal_r49
            ship.set_navigation_target(goal_r49)
        if result_r49 == "event":
            _show_notice(r49_investigation.last_event)
        elif result_r49 == "failed":
            _r43_fail_sortie("Тревога в порту. Повтори расследование без выстрелов.")
        elif result_r49 == "success":
            _complete_mission()
        return
    if is_instance_valid(mission_objectives_r48):
        var outcome: String = mission_objectives_r48.step(dt, ship.global_position)
        if mission["type"] == "escort" and (
                mission_objectives_r48.convoy_started and
                not r48_escort_enemies_spawned):
            _r48_spawn_convoy_threats()
        if outcome == "failed":
            _r43_fail_sortie("Конвой уничтожен. Гражданские не добрались до убежища. Повтори защиту.")
            return
        if outcome == "success":
            _complete_mission()
            return
        var next_goal: Vector3 = mission_objectives_r48.objective_position()
        if r48_last_goal.distance_to(next_goal) > 5.0:
            r48_last_goal = next_goal
            ship.set_navigation_target(next_goal)
        if is_instance_valid(mission_beacon):
            mission_beacon.global_position = next_goal
        return
    if mission["type"] == "reach" and ship.global_position.distance_to(target) < 47.0:
        _complete_mission()
    elif mission["type"] == "combat" and mission_started and mission_enemies <= 0:
        _complete_mission()

func _r48_spawn_convoy_threats() -> void:
    if r48_escort_enemies_spawned or garage_open_r39 or (
            not is_instance_valid(mission_objectives_r48)) or (
            mission_index != 7) or (
            not mission_objectives_r48.is_active_convoy()):
        return
    r48_escort_enemies_spawned = true
    mission_enemies = 3
    for i in mission_enemies:
        var hostile = DroneScript.new()
        hostile.hostile = true
        hostile.health = 14.0
        hostile.speed = 23.0
        hostile.activation_distance = 350.0
        hostile.target = mission_objectives_r48
        hostile.add_to_group("nebula_mission_hostiles")
        hostile.global_position = mission_objectives_r48.global_position + (
            Vector3(float(i - 1) * 42.0, 9.0, -69.0))
        hostile.destroyed.connect(_on_mission_drone_destroyed)
        hostile.fired.connect(_on_drone_fire)
        add_child(hostile)
        drones.append(hostile)
    _show_notice("КОНВОЙ ПОД АТАКОЙ · ЗАЩИТИ ГРАЖДАНСКИХ")

func _r50_spawn_archive_threats() -> void:
    if r50_archive_wave_spawned or not is_instance_valid(r50_archive) or (
            not r50_archive.is_active_server()) or garage_open_r39:
        return
    r50_archive_wave_spawned = true
    mission_enemies = 3
    for i in mission_enemies:
        var drone = DroneScript.new()
        drone.hostile = true
        drone.health = 15.0
        drone.speed = 24.0
        drone.activation_distance = 380.0
        drone.target = r50_archive
        drone.add_to_group("nebula_mission_hostiles")
        drone.destroyed.connect(_on_mission_drone_destroyed)
        drone.fired.connect(_on_drone_fire)
        add_child(drone)
        drone.global_position = r50_archive.global_position + Vector3(
            float(i - 1) * 38.0, 10.0, -83.0)
        drones.append(drone)
    _show_notice("АРХИВ ПОД АТАКОЙ · ЗАЩИЩАЙ ЯДРО")

func _r50_clear_archive() -> void:
    r49_interact_held = false
    r50_archive_wave_spawned = false
    if is_instance_valid(r50_archive):
        r50_archive.queue_free()
        r50_archive = null

func _r51_active_interference() -> int:
    var online: int = 0
    for drone in drones:
        if is_instance_valid(drone) and drone.is_in_group("nebula_r51_jammer") and (
                drone.hostile):
            online += 1
    return online

func _r51_spawn_jammers() -> void:
    if r51_jammer_wave_spawned or garage_open_r39 or (
            not is_instance_valid(r51_courier)) or (
            not r51_courier.is_extraction_active()):
        return
    r51_jammer_wave_spawned = true
    mission_enemies = 2
    for i in mission_enemies:
        var drone = DroneScript.new()
        drone.hostile = true
        drone.health = 16.0
        drone.speed = 23.0
        drone.activation_distance = 420.0
        drone.target = ship
        drone.add_to_group("nebula_mission_hostiles")
        drone.add_to_group("nebula_r51_jammer")
        drone.destroyed.connect(_on_mission_drone_destroyed)
        drone.fired.connect(_on_drone_fire)
        add_child(drone)
        drone.global_position = r51_courier.extraction_position + Vector3(
            -46.0 + float(i) * 92.0, 11.0, -65.0)
        drones.append(drone)
    _show_notice("СИГНАЛ ПОДАВЛЕН · УСТРАНИ 2 ДРОНА")

func _r51_clear_courier() -> void:
    r49_interact_held = false
    r51_jammer_wave_spawned = false
    if is_instance_valid(r51_courier):
        r51_courier.queue_free()
        r51_courier = null

func _r52_spawn_reactor_threats() -> void:
    if r52_hostiles_spawned or garage_open_r39 or not is_instance_valid(r52_station) or (
            not r52_station.is_live_reactor()):
        return
    r52_hostiles_spawned = true
    mission_enemies = 3
    for i in mission_enemies:
        var hostile = DroneScript.new()
        hostile.hostile = true
        hostile.health = 19.0
        hostile.speed = 24.0
        hostile.activation_distance = 460.0
        hostile.target = r52_station.reactor
        hostile.add_to_group("nebula_mission_hostiles")
        hostile.add_to_group("nebula_r52_reactor_attackers")
        hostile.destroyed.connect(_on_mission_drone_destroyed)
        hostile.fired.connect(_on_drone_fire)
        add_child(hostile)
        hostile.global_position = r52_station.reactor.global_position + Vector3(
            float(i - 1) * 56.0, 14.0, -85.0)
        drones.append(hostile)
    _show_notice("АВАРИЙНАЯ СТАНЦИЯ ПОД УДАРОМ · ПРИКРОЙ РЕАКТОР")

func _r52_clear_station() -> void:
    r49_interact_held = false
    r52_hostiles_spawned = false
    if is_instance_valid(r52_station):
        r52_station.queue_free()
        r52_station = null

func _active_mission_goal() -> Vector3:
    if r57_patrol.active and mission_index >= MISSIONS.size():
        return r57_patrol.objective_position()
    # Single physical objective for radar, HUD and waypoint beacon across
    # all staged mission types; predictive cruise steering is separate.
    if is_instance_valid(r52_station):
        return r52_station.objective_position()
    if is_instance_valid(r51_courier):
        return r51_courier.objective_position()
    if is_instance_valid(r50_archive):
        return r50_archive.objective_position()
    if is_instance_valid(r49_investigation):
        return r49_investigation.objective_position()
    if is_instance_valid(mission_objectives_r48) and mission_objectives_r48.active:
        return mission_objectives_r48.objective_position()
    if mission_index < MISSIONS.size():
        return MISSIONS[mission_index]["position"]
    return Vector3.ZERO

func _start_mission() -> void:
    mission_started = false
    r43_pending_bounty = 0
    r48_escort_enemies_spawned = false
    _r49_clear_investigation()
    _r50_clear_archive()
    _r51_clear_courier()
    _r52_clear_station()
    if is_instance_valid(fleet_r15): fleet_r15.defend_anchor = null
    if is_instance_valid(mission_objectives_r48):
        mission_objectives_r48.queue_free()
        mission_objectives_r48 = null
    if is_instance_valid(ship):
        if mission_index < MISSIONS.size():
            ship.set_navigation_target(MISSIONS[mission_index]["position"])
        else:
            ship.clear_navigation_target()
    mission_enemies = 0
    if is_instance_valid(mission_beacon):mission_beacon.queue_free()
    if mission_index>=MISSIONS.size():
        if not r57_selected_contract.is_empty() and (
                PatrolContractsR57Script.valid_contract(r57_selected_contract)):
            _r57_start_patrol()
        else:
            _show_notice("СЮЖЕТ ЗАВЕРШЁН · СВОБОДНЫЙ ПОЛЁТ")
        return
    var data: Dictionary = MISSIONS[mission_index]
    if str(data["type"]) == "blackout":
        r52_station = StationBlackoutR52Script.new()
        add_child(r52_station)
        r52_station.configure(data["position"])
        mission_started = true
        r48_last_goal = r52_station.objective_position()
        ship.set_navigation_target(r48_last_goal)
        if is_instance_valid(fleet_r15):
            fleet_r15.defend_anchor = r52_station.reactor
    if str(data["type"]) == "courier":
        r51_courier = CourierInterceptR51Script.new()
        add_child(r51_courier)
        r51_courier.configure(data["position"])
        mission_started = true
        r48_last_goal = r51_courier.objective_position()
        ship.set_navigation_target(r48_last_goal)
    if str(data["type"]) == "archive":
        r50_archive = ArchiveBreachR50Script.new()
        add_child(r50_archive)
        r50_archive.configure(data["position"])
        # Defend order must protect the real server, not the pilot's location.
        if is_instance_valid(fleet_r15):
            fleet_r15.defend_anchor = r50_archive
        mission_started = true
        r48_last_goal = r50_archive.objective_position()
        ship.set_navigation_target(r48_last_goal)
    if str(data["type"]) == "investigation":
        r49_investigation = PortInvestigationR49Script.new()
        add_child(r49_investigation)
        r49_investigation.configure(data["position"])
        mission_started = true
        r48_last_goal = r49_investigation.objective_position()
        ship.set_navigation_target(r48_last_goal)
        # Genuine stealth: the player's squad can fly, but cannot shoot.
        fleet_r15.combat_active = false
        fleet_r15.set_command("follow")
    if str(data["type"]) in ["scan", "escort", "evacuation"]:
        mission_objectives_r48 = MissionObjectivesR48Script.new()
        add_child(mission_objectives_r48)
        mission_objectives_r48.configure(str(data["type"]), data["position"])
        if str(data["type"]) == "escort": fleet_r15.defend_anchor = mission_objectives_r48
        mission_started = true
        r48_last_goal = mission_objectives_r48.objective_position()
        ship.set_navigation_target(r48_last_goal)
    var beacon := Node3D.new()
    beacon.name = "MissionBeacon"
    beacon.position = _active_mission_goal()
    var sphere := MeshInstance3D.new()
    var mesh := SphereMesh.new()
    mesh.radius=4.8
    mesh.height=9.6
    sphere.mesh=mesh
    sphere.material_override=_mat(Color(1.0,0.72,0.28),0.82)
    beacon.add_child(sphere)
    var lamp := OmniLight3D.new()
    lamp.omni_range=55.0
    lamp.light_energy=0.75
    lamp.light_color=Color(1.0,0.74,0.32)
    beacon.add_child(lamp)
    add_child(beacon)
    mission_beacon=beacon
    if data["type"]=="combat":
        mission_started=true
        mission_enemies=3 if mission_index==2 else 5
        for i in mission_enemies:
            var drone = DroneScript.new()
            drone.hostile=true
            drone.add_to_group("nebula_mission_hostiles")
            drone.health=17.0 if mission_index==5 else 9.0
            drone.target=ship
            drone.position=data["position"]+Vector3(float(i-2)*14.0,3.0,float(i%2)*17.0)
            drone.destroyed.connect(_on_mission_drone_destroyed)
            drone.fired.connect(_on_drone_fire)
            add_child(drone)
            drones.append(drone)

func _complete_mission() -> void:
    # R41: close the active sortie exactly once; do not chain directly to
    # another combat encounter or leave the player trapped in open flight.
    if garage_open_r39 or mission_index >= MISSIONS.size():
        return
    var completed_index := mission_index
    var data: Dictionary = MISSIONS[completed_index]
    var awarded_credits: int = CaptainRosterR42Script.reward(int(data["reward"]), selected_captain_r42) + r43_pending_bounty
    # A trained quartermaster pays only after a real successful mission.
    awarded_credits += PilotAcademyR54Script.credit_bonus(
        int(data["reward"]), selected_captain_r42,
        PilotAcademyR54Script.rank(pilot_training_r54.get(selected_captain_r42, 0)))
    var awarded_xp := 150 + completed_index * 65
    credits += awarded_credits
    xp += awarded_xp
    mission_index += 1
    var story: Dictionary = CampaignStoryR41Script.briefing(completed_index)
    r41_last_debrief = {
        "status": "success",
        "mission_index": completed_index,
        "credits": awarded_credits,
        "xp": awarded_xp,
        "reveal": str(story.get("reveal", "")),
    }
    mission_started = false
    mission_enemies = 0
    r43_pending_bounty = 0
    _r49_clear_investigation()
    _r50_clear_archive()
    _r51_clear_courier()
    _r52_clear_station()
    if is_instance_valid(fleet_r15): fleet_r15.defend_anchor = null
    if is_instance_valid(mission_objectives_r48):
        mission_objectives_r48.queue_free()
        mission_objectives_r48 = null
    r48_escort_enemies_spawned = false
    if is_instance_valid(mission_beacon):
        mission_beacon.queue_free()
        mission_beacon = null
    # Remove only the remaining mission hostiles before the next sortie.
    # Civilian traffic stays untouched.
    for actor in drones.duplicate():
        if is_instance_valid(actor) and actor.is_in_group("nebula_mission_hostiles"):
            drones.erase(actor)
            actor.queue_free()
    ship.set_cruise_assist(false)
    ship.clear_navigation_target()
    ship.velocity = Vector3.ZERO
    ship.global_position = R21_LAUNCH_CANDIDATES[0]
    _r21_rescue_blocked_spawn()
    _save_progress()
    _r39_create_garage_hub()
    _show_notice("МИССИЯ ВЫПОЛНЕНА · +%d CR · +%d XP" % [awarded_credits, awarded_xp])

func _r60_begin_actual_crash() -> void:
    if r60_crash_pending or garage_open_r39 or ship.hull > 0.0:
        return
    r60_crash_pending = true
    r60_crash_hold_sec = R60_CRASH_HOLD_SEC
    r60_crash_was_contract = r57_patrol.active and (
        mission_index >= MISSIONS.size())
    r60_last_impact = ShipWreckR60Script.safe_origin(ship.global_position)
    if is_instance_valid(active_wreck_r60):
        active_wreck_r60.queue_free()
        active_wreck_r60 = null
    var visible_paint: String = str(livery_equipped_r59.get(
        equipped_r15, "factory"))
    var color: Color = HangarLiveriesR59Script.palette(
        visible_paint).get("body", Color(0.40, 0.47, 0.52))
    var wreck := ShipWreckR60Script.new()
    wreck.name = "R60_AuthenticPlayerAircraftCrash"
    add_child(wreck)
    if wreck.spawn_crash(ship.global_position, ship.velocity,
            equipped_r15, color):
        active_wreck_r60 = wreck
        r60_crash_count += 1
    else:
        wreck.queue_free()
    # Hide only the intact craft, not the city or the physical wreck.
    # Preserve the camera position for a visible 1.6-second crash sequence.
    ship.visible = false
    ship.controls_locked = true
    ship.velocity = Vector3.ZERO
    ship.set_cruise_assist(false)
    ship.clear_navigation_target()
    _show_notice("КРИТИЧЕСКИЙ УРОН · ФИЗИЧЕСКАЯ АВАРИЯ · ЭВАКУАЦИЯ")

func _r60_finish_actual_crash() -> void:
    if not r60_crash_pending:
        return
    r60_crash_pending = false
    r60_crash_hold_sec = 0.0
    ship.visible = true
    if r60_crash_was_contract:
        _r57_end_patrol(false, "КОРАБЛЬ УНИЧТОЖЕН · КОНТРАКТ БЕЗ НАГРАДЫ")
    elif mission_index < MISSIONS.size():
        _r43_fail_sortie("КОРАБЛЬ РАЗРУШЕН · ЭВАКУАЦИЯ · ПОВТОРИТЬ МИССИЮ")
    else:
        ship.global_position = r21_safe_spawn
        ship.velocity = Vector3.ZERO
        ship.shield = fleet_r15.ship_shield_cap()
        ship.hull = fleet_r15.ship_hull_cap()
        credits = maxi(0, credits - 220)
        ship.controls_locked = false
        _save_progress()
        _show_notice("СВОБОДНЫЙ ПОЛЁТ · АВАРИЯ · ВОССТАНОВЛЕНИЕ −220 CR")

func _r43_fail_sortie(reason: String = "") -> void:
    if garage_open_r39 or mission_index >= MISSIONS.size():
        return
    # Mission stays available for retry. Unbanked enemy bounties are discarded,
    # so destroying enemies and crashing cannot be exploited for free credits.
    r41_last_debrief = {
        "status": "failed",
        "mission_index": mission_index,
        "credits": 0,
        "xp": 0,
        "reveal": reason if not reason.is_empty() else
            "Корпус уничтожен. Корабль отремонтирован в Авроре — миссию можно повторить.",
    }
    mission_started = false
    mission_enemies = 0
    r43_pending_bounty = 0
    _r49_clear_investigation()
    _r50_clear_archive()
    _r51_clear_courier()
    _r52_clear_station()
    if is_instance_valid(fleet_r15): fleet_r15.defend_anchor = null
    if is_instance_valid(mission_objectives_r48):
        mission_objectives_r48.queue_free()
        mission_objectives_r48 = null
    r48_escort_enemies_spawned = false
    if is_instance_valid(mission_beacon):
        mission_beacon.queue_free()
        mission_beacon = null
    for actor in drones.duplicate():
        if is_instance_valid(actor) and actor.is_in_group("nebula_mission_hostiles"):
            drones.erase(actor)
            actor.queue_free()
    ship.set_cruise_assist(false)
    ship.clear_navigation_target()
    ship.velocity = Vector3.ZERO
    ship.global_position = R21_LAUNCH_CANDIDATES[0]
    _r21_rescue_blocked_spawn()
    ship.shield = fleet_r15.ship_shield_cap()
    ship.hull = fleet_r15.ship_hull_cap()
    ship.boost = 100.0
    _save_progress()
    _r39_create_garage_hub()
    _show_notice("ПРОВАЛ МИССИИ · " + reason if not reason.is_empty() else
        "КОРАБЛЬ УНИЧТОЖЕН · ВОЗВРАТ В АНГАР · ПОВТОРИТЬ МИССИЮ")

func _on_drone_destroyed(drone: Node3D) -> void:
    drones.erase(drone)
    if drone.is_in_group("nebula_mission_hostiles"):
        r43_pending_bounty += 45
    else:
        credits += 45

func _on_mission_drone_destroyed(drone: Node3D) -> void:
    mission_enemies=maxi(0,mission_enemies-1)
    _on_drone_destroyed(drone)

func _on_drone_fire(from: Vector3, to: Vector3) -> void:
    if garage_open_r39 or not is_instance_valid(ship):return
    # The story's silent port investigation is not a random combat encounter.
    if is_instance_valid(r49_investigation):
        return
    _laser_effect_colored(from,to,Color(1.0,0.26,0.39))
    if is_instance_valid(r52_station) and r52_station.is_live_reactor() and (
            to.distance_to(r52_station.reactor.global_position) < 18.0) and (
            from.distance_to(r52_station.reactor.global_position) < 275.0):
        r52_station.take_damage(9.0)
        return
    if is_instance_valid(r50_archive) and r50_archive.is_active_server() and (
            to.distance_to(r50_archive.global_position) < 14.0) and (
            from.distance_to(r50_archive.global_position) < 260.0):
        r50_archive.take_damage(8.0)
        return
    if is_instance_valid(mission_objectives_r48) and (
            mission_objectives_r48.is_active_convoy()) and (
            to.distance_to(mission_objectives_r48.global_position) < 13.0) and (
            from.distance_to(mission_objectives_r48.global_position) < 250.0):
        mission_objectives_r48.take_damage(8.0)
        return
    if from.distance_to(ship.global_position)<250.0 and ship.global_position.distance_to(to)<7.0:
        # The approved first-flight mission must be playable before pirates
        # drain the starting shield while the player learns the controls.
        if mission_index > 0 and r21_launch_protection <= 0.0:
            ship.take_damage(8.0)

func _spawn_pirate_ambush() -> void:
    var nearby := 0
    for n in drones:
        if is_instance_valid(n) and n.hostile: nearby += 1
    if nearby >= 14:return
    for i in 3:
        var raider = DroneScript.new()
        raider.hostile = true
        raider.health = 10.0
        raider.speed = 26.0
        raider.target = ship
        raider.position = ship.global_position + Vector3(float(i-1)*42.0, 3.0, -115.0)
        raider.destroyed.connect(_on_drone_destroyed)
        raider.fired.connect(_on_drone_fire)
        add_child(raider)
        drones.append(raider)
    world_events += 1
    _show_notice("СОБЫТИЕ В МИРЕ · ПИРАТСКАЯ ЭСКАДРИЛЬЯ")

func _on_ship_fire(origin: Vector3, direction: Vector3) -> void:
    if garage_open_r39:
        return
    _r49_report_weapon_discharge()
    var endpoint: Vector3 = origin+direction*180.0
    var best_distance: float = 180.0
    var best
    for candidate in drones:
        if not is_instance_valid(candidate): continue
        var offset: Vector3 = candidate.global_position-origin
        var along: float = offset.dot(direction)
        if along<0.0 or along>best_distance: continue
        if offset.cross(direction).length()<=5.2:
            best_distance=along
            best=candidate
    if is_instance_valid(best):
        endpoint=best.global_position
        best.call("hit",fleet_r15.weapon_damage()+float(ship.weapon_rank))
    _laser_effect(origin,endpoint)

func _r16_ally_fire(origin: Vector3, endpoint: Vector3) -> void:
    _laser_effect_colored(origin, endpoint, Color(0.37, 0.86, 0.97))

func _laser_effect(a: Vector3,b: Vector3) -> void:
    _laser_effect_colored(a,b,Color(0.25,0.95,1.0))

func _r16_setup_beam_pool() -> void:
    var parent := Node3D.new()
    parent.name = "R16_PooledCombatBeams"
    add_child(parent)
    r16_beam_mesh = CylinderMesh.new()
    r16_beam_mesh.top_radius = 0.15
    r16_beam_mesh.bottom_radius = 0.15
    r16_beam_mesh.height = 1.0
    r16_beam_mesh.radial_segments = 8
    r16_player_laser = _mat(Color(0.25, 0.95, 1.0), 3.8)
    r16_enemy_laser = _mat(Color(1.0, 0.26, 0.39), 3.8)
    for i in R16_BEAM_POOL_SIZE:
        var shaft := MeshInstance3D.new()
        shaft.name = "Beam_%02d" % i
        shaft.mesh = r16_beam_mesh
        shaft.material_override = r16_player_laser
        shaft.visible = false
        parent.add_child(shaft)
        r16_beams.append(shaft)
        r16_beam_life.append(0.0)

func _r16_update_beam_pool(delta: float) -> void:
    for i in r16_beam_life.size():
        if r16_beam_life[i] <= 0.0:
            continue
        r16_beam_life[i] -= delta
        if r16_beam_life[i] <= 0.0:
            r16_beam_life[i] = 0.0
            r16_beams[i].visible = false

func _laser_effect_colored(a: Vector3, b: Vector3, tint: Color) -> void:
    var distance: float = a.distance_to(b)
    if distance < 0.01 or r16_beams.is_empty():
        return
    var slot: int = -1
    for offset in R16_BEAM_POOL_SIZE:
        var index: int = (r16_beam_cursor + offset) % R16_BEAM_POOL_SIZE
        if r16_beam_life[index] <= 0.0:
            slot = index
            break
    if slot < 0:
        slot = r16_beam_cursor
    r16_beam_cursor = (slot + 1) % R16_BEAM_POOL_SIZE
    var shaft: MeshInstance3D = r16_beams[slot]
    shaft.scale = Vector3.ONE
    shaft.global_position = (a + b) * 0.5
    shaft.look_at(b, Vector3.UP)
    shaft.rotate_object_local(Vector3.RIGHT, PI * 0.5)
    shaft.scale = Vector3(1.0, distance, 1.0)
    shaft.material_override = r16_enemy_laser if tint.r > 0.8 else r16_player_laser
    shaft.visible = true
    r16_beam_life[slot] = 0.13
    r16_beam_shots += 1

func _show_notice(message: String) -> void:
    if not is_instance_valid(hud_notice):return
    hud_notice.text=message
    last_notice = message
    notice_timer=3.3

func _update_hud() -> void:
    # Avoid reflowing button labels at rendering frame rate on mobile.
    _r49_refresh_buttons()
    if garage_open_r39:
        _r39_refresh_garage()
        return
    if not is_instance_valid(hud_status):
        return
    var resource_line: String = "КРЕДИТЫ  %d     XP  %d     ЩИТ  %d%%     КОРПУС  %d%%" % [
        credits, xp, roundi(ship.shield), roundi(ship.hull)]
    if is_instance_valid(r23_cruise_button):
        r23_cruise_button.text = "■  ВЫКЛ. АВТОПИЛОТ" if ship.cruise_assist else "▶  АВТОПИЛОТ К ЦЕЛИ"
    if mission_index >= MISSIONS.size():
        if r57_patrol.active:
            var current: int = r57_patrol.checkpoint_index + 1
            var total: int = r57_patrol.route_size_r58()
            hud_mission.text = "КОНТРАКТ · %s · %s" % [
                str(PatrolContractsR57Script.CATALOG[r57_patrol.active_id]["name"]),
                CareerPrestigeR58Script.tier_label(r57_patrol.risk_tier_r58)]
            hud_objective.text = "МАЯК %d/%d · %d С ОСТАЛОСЬ" % [
                current, total, ceili(r57_patrol.seconds_remaining())]
            hud_status.text = "Достигни синего маркера и удерживай позицию 1,5 с.\n" + resource_line
        else:
            hud_mission.text = "НЕБУЛА  /  СВОБОДНЫЙ ПОЛЁТ"
            hud_objective.text = "МИССИИ ВЫПОЛНЕНЫ"
            hud_status.text = "Исследуй шесть районов космического города.\n" + resource_line
    else:
        var m: Dictionary = MISSIONS[mission_index]
        var goal: Vector3 = _active_mission_goal()
        var d: int = roundi(ship.global_position.distance_to(goal))
        hud_mission.text = "%02d  ·  %s" % [mission_index + 1, m["title"]]
        if is_instance_valid(r52_station):
            hud_objective.text = "◇  " + r52_station.status_line()
        elif is_instance_valid(r51_courier):
            hud_objective.text = "◇  " + r51_courier.status_line()
        elif is_instance_valid(r50_archive):
            hud_objective.text = "◇  " + r50_archive.status_line()
        elif is_instance_valid(r49_investigation):
            hud_objective.text = "◇  " + r49_investigation.status_line()
        elif is_instance_valid(mission_objectives_r48):
            hud_objective.text = "◇  " + mission_objectives_r48.status_line()
        elif m["type"] == "combat" and mission_started:
            hud_objective.text = "◇  ВРАГОВ ОСТАЛОСЬ  /  %d" % mission_enemies
        else:
            hud_objective.text = "◇  ЦЕЛЬ МИССИИ  /  %d М" % d
        hud_status.text = "%s  ·  %d м\n%s" % [m["hint"], d, resource_line]
        if is_instance_valid(r49_investigation): hud_status.text += "\n" + r49_investigation.status_line()
        if is_instance_valid(r50_archive): hud_status.text += "\n" + r50_archive.status_line()
        if is_instance_valid(r51_courier): hud_status.text += "\n" + r51_courier.status_line()
        if is_instance_valid(r52_station): hud_status.text += "\n" + r52_station.status_line()

func _fit_hud() -> void:
    if not is_instance_valid(hud_panel):
        return
    var rect: Vector2 = get_viewport().get_visible_rect().size
    if r31_touch_web and r31_mobile_css_size.x > 0:
        rect = Vector2(r31_mobile_css_size)
    var width: float = rect.x
    var height: float = rect.y
    var safe: Vector4 = r21_touch.r35_safe_insets if (
        is_instance_valid(r21_touch) and r21_mobile_enabled) else Vector4.ZERO
    var safe_left: float = safe.x
    var safe_top: float = safe.y
    var safe_right: float = safe.z
    var safe_width: float = maxf(200.0, width - safe_left - safe_right)
    var compact: bool = width < 940.0 or height < 590.0 or r21_mobile_enabled
    var short_landscape: bool = r21_mobile_enabled and height < 530.0 and width > height
    if is_instance_valid(r23_cruise_button):
        r23_cruise_button.visible = not r21_mobile_enabled and width >= 800.0
    _r49_layout_buttons(rect, safe)
    if compact:
        hud_panel.offset_left = safe_left + 8.0
        hud_panel.offset_top = safe_top + 8.0
        # Keep top-left briefing away from the R32 landscape action grid.
        hud_panel.offset_right = minf(width - safe_right - 8.0,
            safe_left + safe_width * (0.37 if short_landscape else 1.0))
        hud_panel.offset_bottom = safe_top + (110.0 if short_landscape else 124.0)
        hud_mission.add_theme_font_size_override("font_size",
            16 if short_landscape else 19)
        hud_status.add_theme_font_size_override("font_size",
            10 if short_landscape else 12)
        hud_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hud_controls.visible = false
        radar.visible = not r21_mobile_enabled and height > 510.0
        if radar.visible:
            radar.scale = Vector2(0.67,0.67)
            radar.offset_top = -209.0
        hud_flight.visible = false
        r21_objective_panel.visible = false
        hud_notice.offset_top = safe_top + (
            118.0 if short_landscape else 129.0)
        hud_notice.offset_left = -minf(240.0, safe_width * 0.45)
        hud_notice.offset_right = minf(240.0, safe_width * 0.45)
    else:
        hud_panel.offset_left = 22.0
        hud_panel.offset_top = 25.0
        hud_panel.offset_right = 540.0
        hud_panel.offset_bottom = 152.0
        hud_mission.add_theme_font_size_override("font_size",23)
        hud_status.add_theme_font_size_override("font_size",15)
        hud_controls.visible = true
        radar.visible = true
        radar.scale = Vector2.ONE
        radar.offset_top = -277.0
        hud_flight.visible = true
        r21_objective_panel.visible = true
        hud_notice.offset_top = 146.0
    if is_instance_valid(r21_dashboard):
        r21_dashboard._fit_viewport()
    if is_instance_valid(r21_touch):
        r21_touch._resize()
    if is_instance_valid(performance_lab_r11) and is_instance_valid(r21_touch):
        performance_lab_r11.configure_mobile(r21_mobile_enabled, r21_touch,
            r21_touch.r35_safe_insets, rect)

func _unhandled_key_input(event: InputEvent) -> void:
    if garage_open_r39 and event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_ESCAPE or event.keycode == KEY_H:
            _r39_launch_sortie()
            get_viewport().set_input_as_handled()
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_C or event.physical_keycode == KEY_C:
            _r49_cycle_command()
        elif event.keycode == KEY_V or event.physical_keycode == KEY_V:
            _r50_next_focus()
        elif event.keycode==KEY_F5:
            _save_progress()
            _show_notice("ИГРА СОХРАНЕНА")
        elif event.keycode==KEY_H:
            _r21_toggle_hangar()
        elif event.keycode==KEY_R:
            if store_r15.visible:
                return
            if fleet_r15.launch_missile():
                rockets_r15 = fleet_r15.missiles
                _save_progress()
                _show_notice("РАКЕТА ЗАПУЩЕНА · ОСТАЛОСЬ %d" % rockets_r15)
            elif rockets_r15 <= 0 and int(premium_r15.get("missiles_6",0)) > 0 and is_instance_valid(fleet_r15._nearest_hostile(245.0)) and fleet_r15.cooldown <= 0:
                premium_client_r15.buy_rocket_consumption()
                _show_notice("ПРОВЕРЯЕМ ПЛАТНУЮ РАКЕТУ У СЕРВЕРА…")
            else:
                _show_notice("НЕТ РАКЕТ ИЛИ ЦЕЛИ В РАДИУСЕ")
        elif event.keycode==KEY_F2:
            lens_mode=(lens_mode+1)%3
            camera_distance=[14.5,23.0,33.0][lens_mode]
            _show_notice("КАМЕРА · " + str(lens_mode+1) + "/3")
        elif event.keycode==KEY_F3:
            if performance_lab_r11.benchmarking:
                _show_notice("ЗАМЕР FPS · ПРОФИЛЬ ЗАБЛОКИРОВАН")
            else:
                adaptive_r12.set_auto(false)
                _set_graphics_quality((graphics_quality+1)%3)
                performance_lab_r11.set_r38_auto_enabled(false)
        elif event.keycode==KEY_F4:
            hud_canvas.visible = not hud_canvas.visible
        elif event.keycode==KEY_F6:
            performance_lab_r11.toggle_panel()
        elif event.keycode==KEY_F7:
            performance_lab_r11.start_benchmark()
            _show_notice("ЗАМЕР FPS · 2 С ПРОГРЕВ + 20 С ТЕСТ")
        elif event.keycode==KEY_F8:
            cinematic_post_r11.toggle()
            _show_notice("КИНОЭФФЕКТЫ · " + ("ВКЛ" if cinematic_post_r11.is_active() else "ВЫКЛ"))
        elif event.keycode==KEY_F9:
            performance_lab_r11.copy_report()
        elif event.keycode==KEY_F10:
            performance_lab_r11.capture_frame()
            _show_notice("СКРИНШОТ R12 · ЗАХВАТ КАДРА")
        elif event.keycode==KEY_F11:
            if performance_lab_r11.benchmarking:
                _show_notice("ЗАМЕР FPS · АВТО БЛОКИРОВАНО")
            else:
                adaptive_r12.set_auto(not adaptive_r12.auto_enabled)
                performance_lab_r11.set_r38_auto_enabled(adaptive_r12.auto_enabled)
                _show_notice("АВТО-ГРАФИКА · " + ("ВКЛ" if adaptive_r12.auto_enabled else "ВЫКЛ"))
        elif event.keycode==KEY_F12:
            _show_notice("ОСВЕЩЕНИЕ · " + lighting_r12.toggle_look())
        elif event.keycode==KEY_1 or event.keycode==KEY_2 or event.keycode==KEY_3:
            _upgrade_docked(event.keycode-KEY_1)
        elif event.keycode==KEY_F1:
            _show_notice("R12 · F3 ПРОФИЛЬ · F6 FPS · F7 ТЕСТ · F8 ЭФФЕКТЫ · F9 ОТЧЁТ · F10 PNG · F11 АВТО · F12 СВЕТ")

func _r18_set_city_quality() -> void:
    # Base silhouettes stay visible at long range; detailed neon strips
    # disappear sooner, without touching tower physical collision bodies.
    for layer in r18_city_batches:
        if is_instance_valid(layer):
            layer.visibility_range_begin = 0.0
            layer.visibility_range_end = R18_CITY_LIMIT[graphics_quality]
            layer.visibility_range_end_margin = 250.0
    for layer in r18_neon_batches:
        if is_instance_valid(layer):
            layer.visibility_range_begin = 0.0
            layer.visibility_range_end = R18_NEON_LIMIT[graphics_quality]
            layer.visibility_range_end_margin = 170.0

func _set_graphics_quality(mode: int) -> void:
    graphics_quality = clampi(mode, 0, 2)
    if is_instance_valid(aegis_r10):
        aegis_r10.set_quality(graphics_quality)
    if is_instance_valid(city_cladding_r10):
        city_cladding_r10.set_quality(graphics_quality)
    if is_instance_valid(premium_architecture):
        premium_architecture.set_quality(graphics_quality)
    if is_instance_valid(aurora_scenic_r22):
        aurora_scenic_r22.set_quality(graphics_quality)
    var industry_r19 = get_node_or_null("OrbitalIndustryR9")
    if industry_r19 != null:
        industry_r19.set_quality(graphics_quality)
    _r18_set_city_quality()
    var details_r18 = get_node_or_null("HighDetailCityR5")
    if details_r18 != null:
        details_r18.set_quality(graphics_quality)
    var skyline_r18 = get_node_or_null("SculpturalSkylineR6")
    if skyline_r18 != null:
        skyline_r18.set_quality(graphics_quality)
    if is_instance_valid(industrial_r11):
        industrial_r11.set_quality(graphics_quality)
    if is_instance_valid(cinematic_post_r11):
        cinematic_post_r11.set_quality(graphics_quality)
    if is_instance_valid(performance_lab_r11):
        performance_lab_r11.set_quality(graphics_quality)
    if is_instance_valid(engineering_r12):
        engineering_r12.set_quality(graphics_quality)
    if is_instance_valid(lighting_r12):
        lighting_r12.set_quality(graphics_quality)
    if is_instance_valid(adaptive_r12):
        adaptive_r12.sync_quality(graphics_quality)
    if is_instance_valid(port_r14):
        port_r14.set_quality(graphics_quality)
    if is_instance_valid(ship):
        var detail_r14 = ship.get_node_or_null("AnimatedShip/HighDetailInterceptorR5/R14_AirframeRefinement")
        if detail_r14 != null:
            detail_r14.set_quality(graphics_quality)
    _show_notice("ГРАФИКА · " + ["МАКСИМУМ", "ВЫСОКАЯ", "ОПТИМИЗАЦИЯ"][graphics_quality])

func _r12_on_auto_quality(mode: int, reason: String) -> void:
    _set_graphics_quality(mode)
    _show_notice("АВТО-ПРОФИЛЬ · " + reason)


func _r38_cycle_quality() -> void:
    # The on-phone benchmark is comparable only if the quality stays fixed.
    if performance_lab_r11.benchmarking:
        return
    if adaptive_r12.auto_enabled:
        adaptive_r12.set_auto(false)
        _set_graphics_quality(0)
    elif graphics_quality < 2:
        _set_graphics_quality(graphics_quality + 1)
    else:
        _set_graphics_quality(1)
        adaptive_r12.set_auto(true)
    performance_lab_r11.set_r38_auto_enabled(adaptive_r12.auto_enabled)

func _upgrade_docked(slot: int) -> void:
    if ship.global_position.distance_to(SECTOR_POSITIONS[0])>115.0:
        _show_notice("УЛУЧШЕНИЯ ТОЛЬКО В ПОРТУ АВРОРА")
        return
    var price: int = 600 + (ship.engine_rank if slot == 0 else ship.weapon_rank if slot == 1 else 0)*500
    if credits<price:
        _show_notice("НЕДОСТАТОЧНО КРЕДИТОВ · %d CR" % price)
        return
    if slot == 2:
        if ship.hull >= fleet_r15.ship_hull_cap() - 1.0 and ship.shield >= fleet_r15.ship_shield_cap() - 1.0:
            return
        ship.hull = fleet_r15.ship_hull_cap()
        ship.shield = fleet_r15.ship_shield_cap()
    elif slot==0:
        if ship.engine_rank>=4:return
        ship.engine_rank+=1
    else:
        if ship.weapon_rank>=4:return
        ship.weapon_rank+=1
    credits-=price
    _save_progress()
    if garage_open_r39:
        _r39_refresh_garage()
    _show_notice("АНГАР · УЛУЧШЕНИЕ УСТАНОВЛЕНО")

func _r16_hangar_closed() -> void:
    if garage_open_r39:
        if is_instance_valid(garage_hub_r39):
            garage_hub_r39.visible = true
            _r39_refresh_garage()
        return
    if is_instance_valid(ship):
        ship.controls_locked = false
    if is_instance_valid(r21_touch):
        r21_touch.set_shop_open(false)

func _r15_apply_loadout() -> void:
    fleet_r15.set_loadout(equipped_r15, weapon_r15, rockets_r15, wingmen_r15)
    fleet_r15.set_workbench_r56(hangar_modules_r56)
    if is_instance_valid(ship):
        ship.hull_cap_r60 = fleet_r15.ship_hull_cap()
    livery_equipped_r59 = HangarLiveriesR59Script.safe_equipped(
        livery_equipped_r59, livery_owned_r59)
    if is_instance_valid(ship):
        ship.set_livery_r59(str(livery_equipped_r59.get(
            equipped_r15, "factory")))
        ship.set_workbench_modules_r56(
            HangarWorkbenchR56Script.rank_of(hangar_modules_r56, equipped_r15, "armor"),
            HangarWorkbenchR56Script.rank_of(hangar_modules_r56, equipped_r15, "shield"),
            HangarWorkbenchR56Script.rank_of(hangar_modules_r56, equipped_r15, "radar"))
    if is_instance_valid(radar):
        radar.range_meters = fleet_r15.radar_range_r56()
        radar.queue_redraw()
    if is_instance_valid(store_r15):
        var visible_owned: Dictionary = owned_r15.duplicate()
        for paid_sku in premium_r15:
            if int(premium_r15[paid_sku]) > 0 and paid_sku != "missiles_6":
                visible_owned[paid_sku] = true
        store_r15.refresh(credits, visible_owned, equipped_r15)

func _r15_buy_credit(sku: String) -> void:
    if not is_instance_valid(ship) or ship.global_position.distance_to(SECTOR_POSITIONS[0]) > 150.0:
        _show_notice("ПОКУПКИ ТОЛЬКО В АВРОРЕ")
        return
    for entry in HangarStoreR15Script.CREDIT_ITEMS:
        if str(entry["id"]) != sku:continue
        var cost: int = int(entry["cost"])
        var kind: String = str(entry["kind"])
        if kind != "ammo" and (owned_r15.has(sku) or int(premium_r15.get(sku,0)) > 0):
            if kind == "ship":
                equipped_r15 = sku
                _r15_apply_loadout()
                _show_notice("КОРАБЛЬ ВЫБРАН · " + sku)
            elif kind == "weapon":
                weapon_r15 = sku
                _r15_apply_loadout()
                _show_notice("ОРУЖИЕ УСТАНОВЛЕНО")
            elif kind == "ally" and not wingmen_r15.has(sku) and wingmen_r15.size() < 2:
                wingmen_r15.append(sku)
                _r15_apply_loadout()
                _show_notice("ПОМОЩНИК ПРИСОЕДИНИЛСЯ")
            else:
                _show_notice("УЖЕ КУПЛЕНО")
            return
        if credits < cost:
            _show_notice("НЕ ХВАТАЕТ КРЕДИТОВ · %d CR" % cost)
            return
        if kind == "ally" and wingmen_r15.size() >= 2:
            _show_notice("МАКСИМУМ ДВА ПОМОЩНИКА")
            return
        credits -= cost
        if kind == "ammo":
            rockets_r15 = mini(999, rockets_r15 + 6)
        else:
            owned_r15[sku] = true
            if kind == "ship":
                equipped_r15 = sku
            elif kind == "weapon":
                weapon_r15 = sku
            elif kind == "ally":
                wingmen_r15.append(sku)
        _r15_apply_loadout()
        if kind == "ship":
            ship.hull = fleet_r15.ship_hull_cap()
            ship.shield = fleet_r15.ship_shield_cap()
        _save_progress()
        _show_notice("АНГАР · ПРИОБРЕТЕНО " + sku)
        return
    _show_notice("НЕИЗВЕСТНЫЙ ТОВАР")

func _r15_request_checkout(_sku: String) -> void:
    # The separate account-based shop is allowed to open even when checkout is
    # disabled. Its buy buttons remain blocked by the server-side catalog.
    var url: String = "https://osgard.world/games/remix/arena-v2/nebula-3d/hangar.html"
    if OS.has_feature("web"):
        JavaScriptBridge.eval("window.location.assign('" + url + "')", true)
    else:
        OS.shell_open(url)

func _r15_premium_synced(receipts: Dictionary) -> void:
    # A Checkout return URL never unlocks goods. Only this authenticated server
    # inventory response is permitted to change the paid inventory.
    premium_r15.clear()
    for sku in receipts:
        if sku in ["ship_interceptor","ship_guardian","weapon_plasma",
                   "missiles_6","wingman_escort","wingman_ace",
                   "skin_obsidian","skin_aurora","hangar_visuals"]:
            premium_r15[sku] = maxi(0, int(receipts[sku]))
    if not owned_r15.has(equipped_r15) and int(premium_r15.get(equipped_r15,0)) <= 0:
        equipped_r15 = "ship_scout"
    if weapon_r15 != "weapon_basic" and not owned_r15.has(weapon_r15) and int(premium_r15.get(weapon_r15,0)) <= 0:
        weapon_r15 = "weapon_basic"
    for i in range(wingmen_r15.size()-1,-1,-1):
        var wingman: String = wingmen_r15[i]
        if not owned_r15.has(wingman) and int(premium_r15.get(wingman,0)) <= 0:
            wingmen_r15.remove_at(i)
    _r15_apply_loadout()
    if garage_open_r39:
        _r39_refresh_garage()
    _show_notice("ПРЕМИУМ-АНГАР · ПРАВА ПРОВЕРЕНЫ СЕРВЕРОМ")

func _r15_paid_missile_authorized() -> void:
    premium_r15["missiles_6"] = maxi(0,int(premium_r15.get("missiles_6",0))-1)
    fleet_r15.missiles += 1
    var launched: bool = fleet_r15.launch_missile()
    rockets_r15 = fleet_r15.missiles
    _save_progress()
    _show_notice("РАКЕТА ЗАПУЩЕНА" if launched else "РАКЕТА ДОБАВЛЕНА В ЗАПАС")

func _r15_sync_failed(error: String) -> void:
    _show_notice("ОПЛАЧЕННЫЕ ПРЕДМЕТЫ · " + error)

func _safe_float(value: Variant, fallback: float) -> float:
    if typeof(value) != TYPE_FLOAT and typeof(value) != TYPE_INT:
        return fallback
    var number: float = float(value)
    return number if is_finite(number) else fallback

func _save_progress() -> void:
    var file:=FileAccess.open(SAVE_PATH,FileAccess.WRITE)
    if file==null:return
    file.store_string(JSON.stringify({"version":1,"credits":credits,"xp":xp,"mission":mission_index,"player_x":ship.global_position.x,"player_y":ship.global_position.y,"player_z":ship.global_position.z,"engine_rank":ship.engine_rank,"weapon_rank":ship.weapon_rank,"owned_r15":owned_r15,"equipped_r15":equipped_r15,"weapon_r15":weapon_r15,"rockets_r15":rockets_r15,"wingmen_r15":wingmen_r15,"r41_last_debrief":r41_last_debrief,"captain_r42":selected_captain_r42,"pilot_training_r54":pilot_training_r54,"hangar_modules_r56":hangar_modules_r56,"r57_selected_contract":r57_selected_contract,"r57_contract_counts":r57_contract_counts,"r58_risk_tier":r58_risk_tier,"livery_owned_r59":livery_owned_r59,"livery_equipped_r59":livery_equipped_r59}))
    file.close()

func _load_progress() -> void:
    if not FileAccess.file_exists(SAVE_PATH):return
    var file:=FileAccess.open(SAVE_PATH,FileAccess.READ)
    if file==null:return
    var raw=JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(raw)!=TYPE_DICTIONARY or raw.get("version",0)!=1:return
    mission_index=clampi(int(_safe_float(raw.get("mission",0),0.0)),0,MISSIONS.size())
    credits=clampi(int(_safe_float(raw.get("credits",950),950.0)),0,99999999)
    xp=clampi(int(_safe_float(raw.get("xp",0),0.0)),0,99999999)
    var saved_captain: String = str(raw.get("captain_r42", "ada"))
    selected_captain_r42 = saved_captain if CaptainRosterR42Script.valid_id(saved_captain) else "ada"
    pilot_training_r54 = PilotAcademyR54Script.safe_roster(raw.get("pilot_training_r54", {}))
    hangar_modules_r56 = HangarWorkbenchR56Script.safe_roster(
        raw.get("hangar_modules_r56", {}))
    livery_owned_r59 = HangarLiveriesR59Script.safe_owned(
        raw.get("livery_owned_r59", {}))
    livery_equipped_r59 = HangarLiveriesR59Script.safe_equipped(
        raw.get("livery_equipped_r59", {}), livery_owned_r59)
    r57_selected_contract = PatrolContractsR57Script.safe_selection(
        raw.get("r57_selected_contract", ""))
    r57_contract_counts = PatrolContractsR57Script.safe_finish_counts(
        raw.get("r57_contract_counts", {}))
    r58_risk_tier = CareerPrestigeR58Script.safe_selected_tier(
        raw.get("r58_risk_tier", 0), r57_contract_counts)
    # Optional additive save field; original v1 save and premium ownership remain intact.
    var stored_result: Variant = raw.get("r41_last_debrief", {})
    if typeof(stored_result) == TYPE_DICTIONARY:
        var result_index: int = int(_safe_float(stored_result.get("mission_index", -1), -1.0))
        if result_index >= 0 and result_index < MISSIONS.size():
            r41_last_debrief = {
                "status": "failed" if str(stored_result.get("status", "success")) == "failed" else "success",
                "mission_index": result_index,
                "credits": clampi(int(_safe_float(stored_result.get("credits", 0), 0.0)), 0, 999999),
                "xp": clampi(int(_safe_float(stored_result.get("xp", 0), 0.0)), 0, 999999),
                "reveal": "Корабль отремонтирован. Можно повторить вылет." if str(stored_result.get("status", "success")) == "failed" else str(CampaignStoryR41Script.briefing(result_index).get("reveal", "")),
            }
    ship.engine_rank=clampi(int(_safe_float(raw.get("engine_rank",0),0.0)),0,4)
    ship.weapon_rank=clampi(int(_safe_float(raw.get("weapon_rank",0),0.0)),0,4)
    var saved_owned: Variant = raw.get("owned_r15", {})
    if typeof(saved_owned) == TYPE_DICTIONARY:
        for entry in saved_owned:
            if bool(saved_owned[entry]) and str(entry) in [
                "ship_scout","ship_interceptor","ship_guardian",
                "weapon_pulse","weapon_plasma","wingman_escort","wingman_ace"]:
                owned_r15[str(entry)] = true
    equipped_r15 = str(raw.get("equipped_r15", "ship_scout"))
    if not owned_r15.has(equipped_r15) or not equipped_r15.begins_with("ship_"):
        equipped_r15 = "ship_scout"
    weapon_r15 = str(raw.get("weapon_r15", "weapon_basic"))
    if weapon_r15 != "weapon_basic" and not owned_r15.has(weapon_r15):
        weapon_r15 = "weapon_basic"
    rockets_r15 = clampi(int(_safe_float(raw.get("rockets_r15",0),0.0)),0,999)
    var saved_allies: Variant = raw.get("wingmen_r15", [])
    if typeof(saved_allies) == TYPE_ARRAY:
        for item in saved_allies:
            if str(item) in ["wingman_escort","wingman_ace"] and owned_r15.has(str(item)) and wingmen_r15.size() < 2:
                if not wingmen_r15.has(str(item)):wingmen_r15.append(str(item))
    ship.global_position=Vector3(clampf(_safe_float(raw.get("player_x",0),0.0),-1700,1700),clampf(_safe_float(raw.get("player_y",19),19.0),4,160),clampf(_safe_float(raw.get("player_z",78),78.0),-1700,1700))

# Godot 4.7 source contract: procedural skyline, mission radar, enemy weapons, harbor upgrades.

## R39: Players enter the campaign through a command hub, not live combat.
func _r39_create_garage_hub() -> void:
    garage_hub_r39 = GarageHubR39Script.new()
    garage_hub_r39.name = "R39_GarageCommandHub"
    hud_canvas.add_child(garage_hub_r39)
    garage_hub_r39.sortie_requested.connect(_r39_launch_sortie)
    garage_hub_r39.shop_requested.connect(_r39_open_shop)
    garage_hub_r39.upgrade_requested_r54.connect(_upgrade_docked)
    garage_hub_r39.training_requested_r54.connect(_r54_train_selected_captain)
    garage_hub_r39.module_requested_r56.connect(_r56_purchase_workbench_module)
    garage_hub_r39.livery_requested_r59.connect(_r59_choose_livery)
    garage_hub_r39.contract_selected_r57.connect(_r57_select_contract)
    garage_hub_r39.risk_selected_r58.connect(_r58_select_risk_tier)
    garage_hub_r39.captain_selected.connect(_r42_select_captain)
    garage_hub_r39.ship_selected_r45.connect(_r45_select_owned_ship)
    garage_hub_r39.wingman_toggled_r47.connect(_r47_toggle_owned_wingman)
    garage_open_r39 = true
    ship.visible = true
    r47_launch_camera_time = 0.0
    if is_instance_valid(fleet_r15):
        fleet_r15.combat_active = false
        fleet_r15.set_command("follow")
    ship.controls_locked = true
    ship.velocity = Vector3.ZERO
    ship.set_cruise_assist(false)
    if is_instance_valid(r21_touch):
        r21_touch.set_shop_open(true)
    if is_instance_valid(r21_dashboard):
        r21_dashboard.visible = false
    if is_instance_valid(performance_lab_r11):
        # R57: keep the on-screen FPS/quality controls usable in the garage.
        # An actual ship can be destroyed between mobile QA frame samples;
        # previously the whole CanvasLayer disappeared after garage return,
        # leaving a real finger tap on the measured FPS button inert.
        # This is also useful to players testing garage GPU cost. The
        # GarageHub is CanvasLayer 30, so merely keeping the profiler
        # visible leaves its real Button behind a blocking 3D dock canvas.
        # Put the independent FPS layer on top only while docked.
        performance_lab_r11.visible = true
        performance_lab_r11.layer = 31
    _r39_refresh_garage()

func _r39_open_shop() -> void:
    if not garage_open_r39 or not is_instance_valid(store_r15):
        return
    if is_instance_valid(garage_hub_r39):
        garage_hub_r39.visible = false
    store_r15.open(credits, owned_r15, equipped_r15)
    if is_instance_valid(r21_touch):
        r21_touch.set_shop_open(true)

func _r39_refresh_garage() -> void:
    if not is_instance_valid(garage_hub_r39):
        return
    garage_hub_r39.refresh({
        "credits": credits, "xp": xp, "mission_index": mission_index,
        "missions": MISSIONS, "ship": equipped_r15, "wingmen": wingmen_r15,
        "story": CampaignStoryR41Script.briefing(mission_index),
        "last_result": r41_last_debrief,
        "captain_id": selected_captain_r42,
        "captain_info": CaptainRosterR42Script.info(selected_captain_r42),
        "pilot_training_r54": pilot_training_r54.duplicate(true),
        "engine_rank_r54": ship.engine_rank,
        "weapon_rank_r54": ship.weapon_rank,
        "hangar_modules_r56": hangar_modules_r56.duplicate(true),
        "livery_owned_r59": livery_owned_r59.duplicate(true),
        "livery_equipped_r59": livery_equipped_r59.duplicate(true),
        "livery_catalog_r59": HangarLiveriesR59Script.catalog(),
        "hull_cap_r56": fleet_r15.ship_hull_cap(),
        "shield_cap_r56": fleet_r15.ship_shield_cap(),
        "radar_range_r56": fleet_r15.radar_range_r56(),
        "r57_selected_contract": r57_selected_contract,
        "r57_contract_counts": r57_contract_counts.duplicate(true),
        "r57_contract_catalog": CareerPrestigeR58Script.offer_catalog(
            r57_contract_counts, r58_risk_tier),
        "r58_risk_tier": r58_risk_tier,
        "r58_career_status": CareerPrestigeR58Script.status(
            r57_contract_counts),
        "r57_last_report": r57_last_report,
        "ship_profiles": {
            "ship_scout": FleetCombatR15Script.hull_profile("ship_scout"),
            "ship_interceptor": FleetCombatR15Script.hull_profile("ship_interceptor"),
            "ship_guardian": FleetCombatR15Script.hull_profile("ship_guardian"),
        },
        "flight_equipment": {
            "weapon_name": "ПЛАЗМА" if weapon_r15 == "weapon_plasma" else
                ("ИМПУЛЬС" if weapon_r15 == "weapon_pulse" else "БАЗОВОЕ"),
            "weapon_damage": fleet_r15.weapon_damage() + float(ship.weapon_rank),
            "rockets": rockets_r15,
            "wingmen": mini(2, wingmen_r15.size()),
            "engine_rank": ship.engine_rank,
        },
        "owned_wingmen": {
            "wingman_escort": owned_r15.has("wingman_escort") or
                int(premium_r15.get("wingman_escort", 0)) > 0,
            "wingman_ace": owned_r15.has("wingman_ace") or
                int(premium_r15.get("wingman_ace", 0)) > 0,
        },
        "owned_ships": {
            "ship_scout": true,
            "ship_interceptor": owned_r15.has("ship_interceptor") or
                int(premium_r15.get("ship_interceptor", 0)) > 0,
            "ship_guardian": owned_r15.has("ship_guardian") or
                int(premium_r15.get("ship_guardian", 0)) > 0,
        },
    })

func _r47_toggle_owned_wingman(id: String) -> void:
    if not garage_open_r39 or not is_instance_valid(garage_hub_r39) or (
            not garage_hub_r39.visible) or not id in [
            "wingman_escort", "wingman_ace"]:
        return
    if not owned_r15.has(id) and int(premium_r15.get(id, 0)) <= 0:
        _show_notice("ВЕДОМЫЙ НЕ ПРИОБРЕТЁН · ОТКРОЙ МАГАЗИН")
        return
    if wingmen_r15.has(id):
        wingmen_r15.erase(id)
    else:
        if wingmen_r15.size() >= 2:
            _show_notice("В СТРОЮ МАКСИМУМ ДВА ВЕДОМЫХ")
            return
        wingmen_r15.append(id)
    _r15_apply_loadout()
    _save_progress()
    _r39_refresh_garage()
    _show_notice("ЭСКАДРИЛЬЯ · %d ИЗ 2 ГОТОВЫ" % wingmen_r15.size())

func _r45_select_owned_ship(id: String) -> void:
    if not garage_open_r39 or not id in [
        "ship_scout", "ship_interceptor", "ship_guardian"]:
        return
    var permitted: bool = id == "ship_scout" or owned_r15.has(id) or int(
        premium_r15.get(id, 0)) > 0
    if not permitted:
        _show_notice("КОРАБЛЬ НЕ ПРИОБРЕТЁН · ОТКРОЙ МАГАЗИН")
        return
    equipped_r15 = id
    _r15_apply_loadout()
    ship.shield = fleet_r15.ship_shield_cap()
    ship.hull = fleet_r15.ship_hull_cap()
    _save_progress()
    _r39_refresh_garage()
    _show_notice("КОРАБЛЬ ГОТОВ К ВЫЛЕТУ · " + id)

func _r59_choose_livery(style_id: String) -> void:
    # A repeat click on a purchased cosmetic only equips it; CR is debited
    # once and only while the real owned hull sits in the visible hangar.
    if not garage_open_r39 or not is_instance_valid(garage_hub_r39) or (
            not garage_hub_r39.visible) or not (
            HangarLiveriesR59Script.valid_style(style_id)):
        return
    var ship_id: String = equipped_r15
    if not HangarLiveriesR59Script.valid_ship(ship_id) or (
            ship_id != "ship_scout" and not owned_r15.has(ship_id) and
            int(premium_r15.get(ship_id, 0)) <= 0):
        _show_notice("ОКРАСКА · СНАЧАЛА ПРИОБРЕТИ КОРАБЛЬ")
        return
    if not HangarLiveriesR59Script.owns(
            livery_owned_r59, ship_id, style_id):
        var price: int = HangarLiveriesR59Script.price(style_id)
        if price <= 0 or credits < price:
            _show_notice("ОКРАСКА · НУЖНО %d CR" % price)
            return
        # Single ledger debit: no half-paid styles or cloned purchases.
        credits -= price
        var acquired: Array = livery_owned_r59[ship_id]
        acquired.append(style_id)
        livery_owned_r59[ship_id] = acquired
    livery_equipped_r59[ship_id] = style_id
    _r15_apply_loadout()
    _save_progress()
    _r39_refresh_garage()
    _show_notice("AURORA PAINT · %s · ГОТОВО" % str(
        HangarLiveriesR59Script.TITLES[style_id]))

func _r56_purchase_workbench_module(module_id: String) -> void:
    # Paid local CR transaction only, never premium receipts or free upgrades.
    if not garage_open_r39 or not is_instance_valid(garage_hub_r39) or (
            not garage_hub_r39.visible) or not HangarWorkbenchR56Script.is_valid_module(
            module_id):
        return
    var ship_id: String = equipped_r15
    if not HangarWorkbenchR56Script.is_valid_ship(ship_id) or (
            ship_id != "ship_scout" and not owned_r15.has(ship_id) and
            int(premium_r15.get(ship_id, 0)) <= 0):
        _show_notice("МАСТЕРСКАЯ · КОРАБЛЬ НЕ ПРИОБРЕТЁН")
        return
    var current: int = HangarWorkbenchR56Script.rank_of(
        hangar_modules_r56, ship_id, module_id)
    if current >= HangarWorkbenchR56Script.MAX_RANK:
        _show_notice("МАСТЕРСКАЯ · МАКСИМАЛЬНЫЙ РАНГ")
        return
    var cost: int = HangarWorkbenchR56Script.upgrade_cost(
        module_id, current)
    if cost <= 0 or credits < cost:
        _show_notice("МАСТЕРСКАЯ · НЕ ХВАТАЕТ %d CR" % cost)
        return
    # All checks precede the single debit; no half-completed transaction.
    credits -= cost
    var ship_modules: Dictionary = hangar_modules_r56[ship_id]
    ship_modules[module_id] = current + 1
    hangar_modules_r56[ship_id] = ship_modules
    _r15_apply_loadout()
    # Only grant the incremental equipment capacity that was actually bought.
    # Never fully heal a damaged craft through changing the module UI.
    if module_id == "armor":
        ship.hull = minf(ship.hull + HangarWorkbenchR56Script.HULL_GAIN_PER_RANK,
            fleet_r15.ship_hull_cap())
    elif module_id == "shield":
        ship.shield = minf(ship.shield + HangarWorkbenchR56Script.SHIELD_GAIN_PER_RANK,
            fleet_r15.ship_shield_cap())
    _save_progress()
    _r39_refresh_garage()
    _show_notice("МАСТЕРСКАЯ · %s · −%d CR" % [
        HangarWorkbenchR56Script.module_label(module_id), cost])

func _r58_select_risk_tier(tier: int) -> void:
    # A rank unlock is derived from genuine bounded completed-route
    # counters. Neither a mobile button nor a saved tier can bypass it.
    if not garage_open_r39 or not is_instance_valid(garage_hub_r39) or (
            not garage_hub_r39.visible) or mission_index < MISSIONS.size():
        return
    if not CareerPrestigeR58Script.unlocked(tier, r57_contract_counts):
        _show_notice("КАРЬЕРА · СНАЧАЛА ЗАРАБОТАЙ РЕПУТАЦИЮ")
        return
    r58_risk_tier = tier
    _save_progress()
    _r39_refresh_garage()
    _show_notice("КОНТРАКТ · РИСК %s" % CareerPrestigeR58Script.tier_label(tier))

func _r57_select_contract(id: String) -> void:
    # Contracts are a real post-campaign progression loop, not a shortcut
    # that lets unfinished missions or invisible UI mint currency.
    if not garage_open_r39 or not is_instance_valid(garage_hub_r39) or (
            not garage_hub_r39.visible) or mission_index < MISSIONS.size():
        return
    if id != "" and not PatrolContractsR57Script.valid_contract(id):
        return
    r57_selected_contract = id
    _save_progress()
    _r39_refresh_garage()
    _show_notice("МАРШРУТ ВЫБРАН · ВЫЛЕТЕТЬ ДЛЯ НАЧАЛА" if (
        not id.is_empty()) else "СВОБОДНЫЙ ПОЛЁТ ВЫБРАН")

func _r57_start_patrol() -> void:
    if mission_index < MISSIONS.size() or garage_open_r39 or (
            not r57_patrol.begin(r57_selected_contract)):
        return
    var real_tier: int = CareerPrestigeR58Script.safe_selected_tier(
        r58_risk_tier, r57_contract_counts)
    r58_risk_tier = real_tier
    if not r57_patrol.configure_challenge_r58(
            CareerPrestigeR58Script.challenge_route(r57_selected_contract,
                real_tier),
            CareerPrestigeR58Script.available_seconds(
                r57_selected_contract, real_tier), real_tier):
        # Never start an unverified high-reward flight or silently pay
        # a different tier if the route's physical geometry is invalid.
        r57_patrol.abandon()
        _r39_create_garage_hub()
        _show_notice("КОНТРАКТ НЕДОСТУПЕН · ПРОВЕРЬ МАРШРУТ")
        return
    r57_reward_committed = false
    mission_started = true
    var beacon := Node3D.new()
    beacon.name = "R57_ActualContractBeacon"
    beacon.position = r57_patrol.objective_position()
    var mesh := SphereMesh.new()
    mesh.radius = 4.2
    mesh.height = 8.4
    var body := MeshInstance3D.new()
    body.name = "R57_Genuine3DPhysicalBeacon"
    body.mesh = mesh
    body.material_override = _mat(Color(0.30, 0.88, 1.0), 0.8)
    beacon.add_child(body)
    var light := OmniLight3D.new()
    light.omni_range = 40.0
    light.light_energy = 0.48
    light.light_color = Color(0.20, 0.75, 1.0)
    beacon.add_child(light)
    add_child(beacon)
    mission_beacon = beacon
    ship.set_navigation_target(r57_patrol.objective_position())
    _show_notice("КОНТРАКТ НАЧАЛСЯ · %d КОНТРОЛЬНЫХ ТОЧЕК" % [
        r57_patrol.route_size_r58()])

func _r57_patrol_tick(dt: float) -> void:
    if not r57_patrol.active or garage_open_r39:
        return
    var outcome: String = r57_patrol.tick(dt, ship.global_position)
    if outcome == "checkpoint":
        var goal: Vector3 = r57_patrol.objective_position()
        ship.set_navigation_target(goal)
        if is_instance_valid(mission_beacon):
            mission_beacon.global_position = goal
        _show_notice("МАЯК ПРОЙДЕН · %d/%d" % [
            r57_patrol.checkpoint_index,
            r57_patrol.route_size_r58()])
    elif outcome == "success":
        _r57_end_patrol(true, "")
    elif outcome == "failed":
        _r57_end_patrol(false, "ВРЕМЯ ИСТЕКЛО · КОНТРАКТ БЕЗ НАГРАДЫ")

func _r57_end_patrol(success: bool, message: String) -> void:
    if garage_open_r39 or r57_reward_committed:
        return
    # The route engine marks success ONLY after every true 3D checkpoint was
    # visited. Bank rewards once, before any dock transition can repeat.
    var verified: bool = success and r57_patrol.finished and (
        r57_patrol.last_result == "success")
    if verified:
        r57_reward_committed = true
        var id: String = r57_patrol.active_id
        var base_cr: int = CareerPrestigeR58Script.earned_credits(
            id, r57_patrol.risk_tier_r58)
        # The previously paid logistics academy remains useful in the
        # post-campaign career, but only after a verified successful flight.
        var earned_cr: int = base_cr + PilotAcademyR54Script.credit_bonus(
            base_cr, selected_captain_r42,
            PilotAcademyR54Script.rank(pilot_training_r54.get(
                selected_captain_r42, 0)))
        var earned_xp: int = CareerPrestigeR58Script.earned_xp(
            id, r57_patrol.risk_tier_r58)
        credits += earned_cr
        xp += earned_xp
        r57_contract_counts[id] = mini(99999, int(
            r57_contract_counts.get(id, 0)) + 1)
        r57_last_report = "КОНТРАКТ %s ВЫПОЛНЕН · +%d CR / +%d XP" % [
            CareerPrestigeR58Script.tier_label(r57_patrol.risk_tier_r58),
            earned_cr, earned_xp]
    else:
        r57_reward_committed = true
        r57_last_report = message if not message.is_empty() else (
            "КОНТРАКТ НЕ ВЫПОЛНЕН · НАГРАДА 0 CR")
    r57_patrol.abandon()
    mission_started = false
    r43_pending_bounty = 0
    if is_instance_valid(mission_beacon):
        mission_beacon.queue_free()
        mission_beacon = null
    ship.set_cruise_assist(false)
    ship.clear_navigation_target()
    ship.velocity = Vector3.ZERO
    ship.global_position = R21_LAUNCH_CANDIDATES[0]
    _r21_rescue_blocked_spawn()
    if is_instance_valid(fleet_r15):
        fleet_r15.combat_active = false
    ship.hull = fleet_r15.ship_hull_cap()
    ship.shield = fleet_r15.ship_shield_cap()
    _save_progress()
    _r39_create_garage_hub()
    _show_notice(r57_last_report)

func _r54_train_selected_captain() -> void:
    # Garage-only purchase, signed entirely in the same local CR ledger as
    # ships and upgrades. No Stripe state, external payment or fake XP.
    if not garage_open_r39 or not is_instance_valid(garage_hub_r39) or (
            not garage_hub_r39.visible):
        return
    var pilot_id: String = selected_captain_r42
    if not PilotAcademyR54Script.valid_pilot(pilot_id):
        return
    var current: int = PilotAcademyR54Script.rank(
        pilot_training_r54.get(pilot_id, 0))
    if current >= PilotAcademyR54Script.MAX_RANK:
        _show_notice("АКАДЕМИЯ · МАКСИМАЛЬНЫЙ РАНГ")
        return
    var price: int = PilotAcademyR54Script.cost(current)
    if credits < price:
        _show_notice("АКАДЕМИЯ · НУЖНО %d CR" % price)
        return
    credits -= price
    pilot_training_r54[pilot_id] = current + 1
    _save_progress()
    _r39_refresh_garage()
    _show_notice("АКАДЕМИЯ · РАНГ %d · −%d CR" % [current + 1, price])

func _r42_select_captain(id: String) -> void:
    if not garage_open_r39 or not CaptainRosterR42Script.valid_id(id):
        return
    selected_captain_r42 = id
    _r39_refresh_garage()
    _save_progress()


func _r49_report_weapon_discharge() -> void:
    if is_instance_valid(r49_investigation):
        r49_investigation.report_weapon_discharge()

func _r49_make_buttons() -> void:
    r49_command_button = Button.new()
    r49_command_button.name = "R49_WingmanOrders"
    r49_command_button.focus_mode = Control.FOCUS_NONE
    r49_command_button.add_theme_font_override("font", r21_ui_font)
    r49_command_button.pressed.connect(_r49_cycle_command)
    hud_canvas.add_child(r49_command_button)
    r49_terminal_button = Button.new()
    r49_terminal_button.name = "R49_TerminalHold"
    r49_terminal_button.focus_mode = Control.FOCUS_NONE
    r49_terminal_button.text = "УДЕРЖИВАТЬ · ВВОД"
    r49_terminal_button.button_down.connect(_r49_hold_on)
    r49_terminal_button.button_up.connect(_r49_hold_off)
    r49_terminal_button.mouse_exited.connect(_r49_hold_off)
    hud_canvas.add_child(r49_terminal_button)
    r50_focus_button = Button.new()
    r50_focus_button.name = "R50_RealEnemyTargetLock"
    r50_focus_button.focus_mode = Control.FOCUS_NONE
    r50_focus_button.add_theme_font_override("font", r21_ui_font)
    r50_focus_button.add_theme_font_size_override("font_size", 14)
    r50_focus_button.pressed.connect(_r50_next_focus)
    hud_canvas.add_child(r50_focus_button)
    r50_repair_button = Button.new()
    r50_repair_button.name = "R50_ActualEmergencyArchiveRepair"
    r50_repair_button.focus_mode = Control.FOCUS_NONE
    r50_repair_button.add_theme_font_override("font", r21_ui_font)
    r50_repair_button.add_theme_font_size_override("font_size", 14)
    r50_repair_button.pressed.connect(_r50_toggle_repair_goal)
    hud_canvas.add_child(r50_repair_button)
    _r49_refresh_buttons()

func _r49_hold_on() -> void:
    r49_interact_held = not garage_open_r39 and (
        is_instance_valid(r49_investigation) or is_instance_valid(r50_archive) or (
        is_instance_valid(r51_courier) and r51_courier.stage != 1) or (
        is_instance_valid(r52_station) and (
            r52_station.stage < 2 or r52_station.can_repair())))

func _r49_hold_off() -> void:
    r49_interact_held = false

func _r49_clear_investigation() -> void:
    r49_interact_held = false
    if is_instance_valid(r49_investigation):
        r49_investigation.queue_free()
        r49_investigation = null

func _r50_next_focus() -> void:
    if garage_open_r39 or is_instance_valid(r49_investigation) or (
            not is_instance_valid(fleet_r15)) or fleet_r15.helpers.is_empty():
        return
    fleet_r15.set_command("attack")
    if fleet_r15.select_next_focus():
        _show_notice("ВЕДОМЫЕ · СОСРЕДОТОЧИТЬ ОГОНЬ · " +
            fleet_r15.focus_status())
    else:
        _show_notice("ВЕДОМЫЕ · НЕТ ПРОТИВНИКОВ В РАДИУСЕ")
    _r49_refresh_buttons()

func _r50_toggle_repair_goal() -> void:
    if not garage_open_r39 and is_instance_valid(r52_station) and (
            r52_station.stage == 2) and r52_station.can_repair():
        if r52_station.select_capacitor(not r52_station.focus_on_capacitor):
            var charge_goal: Vector3 = r52_station.objective_position()
            r48_last_goal = charge_goal
            ship.set_navigation_target(charge_goal)
            _show_notice("СТАНЦИЯ · " + (
                "ПОДЛЕТИ К РЕЗЕРВУ И УДЕРЖИВАЙ ВВОД" if
                r52_station.focus_on_capacitor else "ВЕРНИСЬ К РЕАКТОРУ"))
            _r49_refresh_buttons()
        return
    if garage_open_r39 or not is_instance_valid(r50_archive) or (
            r50_archive.stage != 2) or r50_archive.repair_used:
        return
    if not r50_archive.set_repair_navigation(not r50_archive.focus_on_repair):
        return
    var goal: Vector3 = r50_archive.objective_position()
    r48_last_goal = goal
    ship.set_navigation_target(goal)
    _show_notice("АРХИВ · " + (
        "ЛЕТИ К АВАРИЙНОМУ ЭЛЕМЕНТУ" if r50_archive.focus_on_repair
        else "ВЕРНИСЬ К СЕРВЕРУ"))
    _r49_refresh_buttons()

func _r49_order_label() -> String:
    if not is_instance_valid(fleet_r15): return "СЛЕДОВАТЬ"
    match fleet_r15.command_mode:
        "attack": return "АТАКОВАТЬ"
        "defend": return "ЗАЩИЩАТЬ"
        _: return "СЛЕДОВАТЬ"

func _r49_cycle_command() -> void:
    if garage_open_r39 or is_instance_valid(r49_investigation) or not is_instance_valid(fleet_r15) or fleet_r15.helpers.is_empty():
        return
    var modes: Array = fleet_r15.SQUAD_COMMANDS
    fleet_r15.set_command(str(modes[(modes.find(fleet_r15.command_mode) + 1) % modes.size()]))
    _r49_refresh_buttons()
    _show_notice("ВЕДОМЫЕ · " + _r49_order_label())

func _r49_refresh_buttons() -> void:
    if is_instance_valid(r49_command_button):
        r49_command_button.visible = not garage_open_r39 and is_instance_valid(fleet_r15) and not fleet_r15.helpers.is_empty()
        r49_command_button.disabled = is_instance_valid(r49_investigation)
        r49_command_button.text = ("ВЕДОМЫЕ · ТИХИЙ РЕЖИМ"
            if is_instance_valid(r49_investigation) else
            "ВЕДОМЫЕ · " + _r49_order_label())
    if is_instance_valid(r49_terminal_button):
        r49_terminal_button.visible = not garage_open_r39 and (
            is_instance_valid(r49_investigation) or is_instance_valid(r50_archive) or (
        is_instance_valid(r51_courier) and r51_courier.stage != 1) or (
        is_instance_valid(r52_station) and (
            r52_station.stage < 2 or r52_station.can_repair())))
        r49_terminal_button.text = ("ВВОД · РЕЛЕ" if (
            is_instance_valid(r52_station) and r52_station.stage < 2) else (
            "ВВОД · КОНДЕНСАТОР" if is_instance_valid(r52_station) else (
            "ВВОД · ЭВАКУАЦИЯ" if (
            is_instance_valid(r51_courier) and r51_courier.stage == 2) else (
            "ВВОД · ПРИЁМНИК" if is_instance_valid(r51_courier) else (
            "УДЕРЖИВАТЬ · АРХИВ" if is_instance_valid(r50_archive)
            else "УДЕРЖИВАТЬ · ВВОД")))))
    if is_instance_valid(r50_focus_button):
        r50_focus_button.visible = not garage_open_r39 and (
            not is_instance_valid(r49_investigation)) and is_instance_valid(fleet_r15) and (
            not fleet_r15.helpers.is_empty())
        r50_focus_button.text = "ПРИЦЕЛ · " + fleet_r15.focus_status()
    if is_instance_valid(r50_repair_button):
        r50_repair_button.visible = not garage_open_r39 and (
            (is_instance_valid(r50_archive) and r50_archive.can_repair()) or (
            is_instance_valid(r52_station) and r52_station.can_repair()))
        if is_instance_valid(r52_station):
            r50_repair_button.text = ("РЕЗЕРВ · К РЕАКТОРУ" if
                r52_station.focus_on_capacitor else "РЕЗЕРВ · К МОДУЛЮ")
        else:
            r50_repair_button.text = ("РЕМОНТ · К СЕРВЕРУ" if
                is_instance_valid(r50_archive) and r50_archive.focus_on_repair else
                "РЕМОНТ · К ЭЛЕМЕНТУ")

func _r49_layout_buttons(rect: Vector2, safe: Vector4) -> void:
    if not is_instance_valid(r49_command_button): return
    # 320px portrait needs a readable terminal label and a safe tap target.
    # The old 35% centre slot gave only 112px and clipped mission controls.
    var wide: float = minf(228.0, rect.x * (
        0.65 if rect.x < 430.0 else 0.35))
    var top: float = safe.y + (115.0 if rect.y < 530.0 else 164.0)
    var left: float = maxf(safe.x + 5.0, (rect.x - wide) * 0.5)
    r49_command_button.position = Vector2(left, top)
    r49_command_button.size = Vector2(wide, 44.0)
    r49_terminal_button.position = Vector2(left, top + 52.0)
    r49_terminal_button.size = Vector2(wide, 48.0)
    # R51 receiver/extraction uses the terminal button. Keep a 12px
    # gap before the focus button; stage-1 pursuit hides the terminal and
    # can use the compact layout. No overlapping interactive touch regions.
    var terminal_visible: bool = is_instance_valid(r50_archive) or (
        is_instance_valid(r51_courier) and r51_courier.stage != 1) or (
        is_instance_valid(r52_station) and (
            r52_station.stage < 2 or r52_station.can_repair()))
    r50_focus_button.position = Vector2(left, top + (
        108.0 if terminal_visible else 52.0))
    r50_focus_button.size = Vector2(wide, 48.0)
    r50_repair_button.position = Vector2(left, top + 160.0)
    r50_repair_button.size = Vector2(wide, 44.0)

func _r39_launch_sortie() -> void:
    if not garage_open_r39 or not is_instance_valid(garage_hub_r39):
        return
    garage_open_r39 = false
    if is_instance_valid(fleet_r15):
        fleet_r15.combat_active = true
        fleet_r15.clear_focus()
        fleet_r15.set_command("follow")
    garage_hub_r39.queue_free()
    garage_hub_r39 = null
    var captain: Dictionary = CaptainRosterR42Script.info(selected_captain_r42)
    var trained_rank: int = PilotAcademyR54Script.rank(
        pilot_training_r54.get(selected_captain_r42, 0))
    ship.damage_multiplier = PilotAcademyR54Script.damage_multiplier(
        selected_captain_r42, float(captain.get("damage_multiplier", 1.0)),
        trained_rank)
    ship.thrust_multiplier = PilotAcademyR54Script.thrust_multiplier(
        selected_captain_r42, float(captain.get("thrust_multiplier", 1.0)),
        trained_rank)
    ship.controls_locked = false
    ship.velocity = Vector3.ZERO
    r47_launch_camera_time = 1.05
    # A repaired pilot must not be shot down on the very first frame of a
    # retry. Restart the same short launch immunity every actual sortie.
    # This does not turn off collisions or reward failed attempts.
    r21_launch_protection = 7.0
    if is_instance_valid(r21_touch):
        r21_touch.set_shop_open(false)
    if is_instance_valid(r21_dashboard):
        r21_dashboard.visible = true
    if is_instance_valid(performance_lab_r11):
        performance_lab_r11.layer = 7
        performance_lab_r11.visible = true
    r23_cruise_button.text = "▶  АВТОПИЛОТ К ЦЕЛИ"
    _start_mission()
    _r49_refresh_buttons()
    _show_notice("ВЫЛЕТ · " + (str(MISSIONS[mission_index]["title"]) if mission_index < MISSIONS.size() else "СВОБОДНЫЙ ПОЛЁТ"))
