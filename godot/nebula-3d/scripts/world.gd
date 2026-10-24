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
const SAVE_PATH = "user://nebula_3d_save.json"
const SECTOR_COLORS = [Color(0.10,0.68,0.97), Color(0.64,0.35,1.0), Color(0.98,0.73,0.40), Color(1.0,0.46,0.34), Color(0.87,0.27,0.88), Color(0.24,0.92,0.88)]
const SECTOR_NAMES = ["ПОРТ АВРОРА","НЕОНОВЫЙ КВАРТАЛ","ЦИТАДЕЛЬ","ЧЁРНЫЙ РЫНОК","РАЗЛОМ","НЕКСУС"]
const SECTOR_POSITIONS = [Vector3(0,0,0),Vector3(610,0,-330),Vector3(1070,0,330),Vector3(-500,0,670),Vector3(480,0,940),Vector3(1250,0,-730)]
const MISSIONS = [
    {"title":"ПЕРВЫЙ ПОЛЁТ","hint":"Доберись до светящегося навигационного маяка","position":Vector3(210,18,-270),"type":"reach","reward":350},
    {"title":"НЕОНОВЫЙ КВАРТАЛ","hint":"Посети новый сектор и найди торговый маршрут","position":Vector3(610,20,-330),"type":"reach","reward":450},
    {"title":"СИГНАЛ ПЕРЕХВАТА","hint":"Очисти сектор от трёх пиратских дронов","position":Vector3(1070,19,330),"type":"combat","reward":900},
    {"title":"ВОЗВРАЩЕНИЕ В ПОРТ","hint":"Доставь разведданные обратно в Аврору","position":Vector3(0,16,0),"type":"reach","reward":600},
    {"title":"РАЗЛОМ","hint":"Открой нестабильный навигационный портал","position":Vector3(480,23,940),"type":"reach","reward":1300},
    {"title":"НЕКСУС","hint":"Отрази элитную эскадрилью Корпорации Хелиос","position":Vector3(1250,26,-730),"type":"combat","reward":2100},
    {"title":"ПРОТОКОЛ ХЕЛИОС","hint":"Найди зашифрованный терминал в Неоновом квартале","position":Vector3(690,21,-400),"type":"reach","reward":1700},
    {"title":"ПОХИЩЕННЫЙ КОНВОЙ","hint":"Уничтожь охрану и освободи транспортные суда","position":Vector3(-500,20,670),"type":"combat","reward":2400},
    {"title":"СЕРДЦЕ РАЗЛОМА","hint":"Доставь стабилизатор в ядро аномалии","position":Vector3(520,24,1010),"type":"reach","reward":2600},
    {"title":"ПОСЛЕДНИЙ СИГНАЛ","hint":"Разгроми командную группу Хелиос у Нексуса","position":Vector3(1290,28,-780),"type":"combat","reward":4300}
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
var r21_objective_panel: PanelContainer
var r21_ui_font: SystemFont
var r21_mobile_enabled: bool = false
var r21_launch_protection: float = 9.0
var r23_cruise_button: Button
var r23_launch_button_events: int = 0
## R22: real playable golden-hour skyline, not an image/background plate.
var aurora_scenic_r22: Node3D
## R25: Browser E2E receives sanitized read-only real Godot physics state.
## Previous releases tested only headless native flight; actual WebGL
## input may differ and SwiftShader image capture has been inconclusive.
var r25_telemetry_period: float = 0.0
var r25_telemetry_samples: int = 0

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
    JavaScriptBridge.eval("window.__nebulaPilotTelemetry = " + JSON.stringify(state))


func _ready() -> void:
    rng.seed = 20261022
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
    _make_hud()
    r21_dashboard = PremiumHUDR21Script.new()
    r21_dashboard.name = "R21_PremiumFlightDashboard"
    hud_canvas.add_child(r21_dashboard)
    r21_dashboard.craft = ship
    r21_touch = MobileControlsR21Script.new()
    r21_touch.name = "R21_ResponsiveMobileController"
    hud_canvas.add_child(r21_touch)
    r21_touch.player_ship = ship
    r21_touch.rocket_requested.connect(_r21_launch_missile)
    r21_touch.hangar_requested.connect(_r21_toggle_hangar)
    r21_touch.camera_requested.connect(_r21_cycle_camera)
    r21_touch.cruise_requested.connect(_r23_toggle_cruise)
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
    _start_mission()
    # Start the browser on HIGH instead of MAX. Real FPS can then
    # automatically downshift further; native CI retains deterministic MAX.
    if OS.has_feature("web"):
        _set_graphics_quality(1)
        adaptive_r12.set_auto(true)
    _show_notice("АВРОРА · ЗОЛОТОЙ ЧАС · R22")
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
    if not is_instance_valid(ship):
        return
    if is_instance_valid(store_r15) and store_r15.visible:
        return
    if ship.controls_locked:
        return
    ship.set_cruise_assist(not ship.cruise_assist)
    if ship.cruise_assist and mission_index < MISSIONS.size():
        ship.set_navigation_target(MISSIONS[mission_index]["position"])
    r23_launch_button_events += 1
    if ship.cruise_assist:
        _show_notice("ПОЛЁТ НАЧАТ · ТЯГА ВКЛЮЧЕНА · S ДЛЯ ТОРМОЖЕНИЯ")
    else:
        _show_notice("АВТОТЯГА ОТКЛЮЧЕНА · W ДЛЯ ПОЛЁТА")

func _r21_launch_missile() -> void:
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
    if OS.has_feature("web"):
        r25_telemetry_period += delta
        if r25_telemetry_period >= 0.20:
            r25_telemetry_period = fmod(r25_telemetry_period, 0.20)
            _r25_emit_browser_flight_state()
    r21_launch_protection = maxf(0.0, r21_launch_protection - delta)
    if world_pulse > 92.0 and mission_index > 0 and ship.global_position.distance_to(SECTOR_POSITIONS[0]) > 270.0:
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
    chase_camera.fov = lerpf(chase_camera.fov,
        65.0 + minf(6.0, speed * 0.060), 1.0 - exp(-1.8 * delta))
    _mission_tick(delta)
    if is_instance_valid(r21_dashboard):
        r21_dashboard.show_objective = mission_index < MISSIONS.size()
        if r21_dashboard.show_objective:
            r21_dashboard.objective = MISSIONS[mission_index]["position"]
    if ship.hull <= 0.0:
        ship.global_position = r21_safe_spawn
        ship.velocity = Vector3.ZERO
        ship.shield = fleet_r15.ship_shield_cap()
        ship.hull = fleet_r15.ship_hull_cap()
        credits = maxi(0,credits-220)
        _show_notice("КОРАБЛЬ ВОССТАНОВЛЕН · -220 CR")
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
        radar.has_objective = mission_index < MISSIONS.size()
        if radar.has_objective:
            radar.objective = MISSIONS[mission_index]["position"]
        radar.targets.clear()
        for n in drones:
            if is_instance_valid(n) and n.hostile and n.global_position.distance_squared_to(ship.global_position) < 211600.0:
                radar.targets.append(n.global_position)
        radar.queue_redraw()
    if world_timer>=25.0:
        world_timer=0.0
        _save_progress()

func _mission_tick(_dt: float) -> void:
    if mission_index>=MISSIONS.size():return
    var mission: Dictionary = MISSIONS[mission_index]
    var target: Vector3 = mission["position"]
    if mission["type"]=="reach" and ship.global_position.distance_to(target)<47.0:
        _complete_mission()
    elif mission["type"]=="combat" and mission_started and mission_enemies<=0:
        _complete_mission()

func _start_mission() -> void:
    mission_started = false
    if is_instance_valid(ship):
        if mission_index < MISSIONS.size():
            ship.set_navigation_target(MISSIONS[mission_index]["position"])
        else:
            ship.clear_navigation_target()
    mission_enemies = 0
    if is_instance_valid(mission_beacon):mission_beacon.queue_free()
    if mission_index>=MISSIONS.size():
        _show_notice("СЮЖЕТ ЗАВЕРШЁН · СВОБОДНЫЙ ПОЛЁТ")
        return
    var data: Dictionary = MISSIONS[mission_index]
    var beacon := Node3D.new()
    beacon.name = "MissionBeacon"
    beacon.position = data["position"]
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
            drone.health=17.0 if mission_index==5 else 9.0
            drone.target=ship
            drone.position=data["position"]+Vector3(float(i-2)*14.0,3.0,float(i%2)*17.0)
            drone.destroyed.connect(_on_mission_drone_destroyed)
            drone.fired.connect(_on_drone_fire)
            add_child(drone)
            drones.append(drone)

func _complete_mission() -> void:
    var data: Dictionary = MISSIONS[mission_index]
    credits+=int(data["reward"])
    xp+=150+mission_index*65
    mission_index+=1
    _show_notice("МИССИЯ ВЫПОЛНЕНА · +"+str(data["reward"])+" CR")
    _save_progress()
    _start_mission()

func _on_drone_destroyed(drone: Node3D) -> void:
    drones.erase(drone)
    credits+=45

func _on_mission_drone_destroyed(drone: Node3D) -> void:
    mission_enemies=maxi(0,mission_enemies-1)
    _on_drone_destroyed(drone)

func _on_drone_fire(from: Vector3, to: Vector3) -> void:
    if not is_instance_valid(ship):return
    _laser_effect_colored(from,to,Color(1.0,0.26,0.39))
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
    if not is_instance_valid(hud_status):
        return
    var resource_line: String = "КРЕДИТЫ  %d     XP  %d     ЩИТ  %d%%     КОРПУС  %d%%" % [
        credits, xp, roundi(ship.shield), roundi(ship.hull)]
    if is_instance_valid(r23_cruise_button):
        r23_cruise_button.text = "■  ЗАВЕРШИТЬ ПОЛЁТ" if ship.cruise_assist else "▶  НАЧАТЬ ПОЛЁТ"
    if mission_index >= MISSIONS.size():
        hud_mission.text = "НЕБУЛА  /  СВОБОДНЫЙ ПОЛЁТ"
        hud_objective.text = "МИССИИ ВЫПОЛНЕНЫ"
        hud_status.text = "Исследуй шесть районов космического города.\n" + resource_line
    else:
        var m: Dictionary = MISSIONS[mission_index]
        var d: int = roundi(ship.global_position.distance_to(m["position"]))
        hud_mission.text = "%02d  ·  %s" % [mission_index + 1, m["title"]]
        hud_objective.text = "◇  ЦЕЛЬ МИССИИ  /  %d М" % d
        hud_status.text = "%s  ·  %d м\n%s" % [m["hint"], d, resource_line]

func _fit_hud() -> void:
    if not is_instance_valid(hud_panel):
        return
    var rect: Vector2 = get_viewport().get_visible_rect().size
    var width: float = rect.x
    var height: float = rect.y
    var compact: bool = width < 940.0 or height < 590.0 or r21_mobile_enabled
    if is_instance_valid(r23_cruise_button):
        r23_cruise_button.visible = not r21_mobile_enabled and width >= 800.0
    if compact:
        hud_panel.offset_left = 8.0
        hud_panel.offset_top = 8.0
        hud_panel.offset_right = minf(465.0, width - 8.0)
        hud_panel.offset_bottom = 124.0
        hud_mission.add_theme_font_size_override("font_size",19)
        hud_status.add_theme_font_size_override("font_size",12)
        hud_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        hud_controls.visible = false
        radar.visible = not r21_mobile_enabled and height > 510.0
        if radar.visible:
            radar.scale = Vector2(0.67,0.67)
            radar.offset_top = -209.0
        hud_flight.visible = false
        r21_objective_panel.visible = false
        hud_notice.offset_top = 129.0
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

func _unhandled_key_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_F5:
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
            adaptive_r12.set_auto(false)
            _set_graphics_quality((graphics_quality+1)%3)
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
            adaptive_r12.set_auto(not adaptive_r12.auto_enabled)
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
    _show_notice("АНГАР · УЛУЧШЕНИЕ УСТАНОВЛЕНО")

func _r16_hangar_closed() -> void:
    if is_instance_valid(ship):
        ship.controls_locked = false
    if is_instance_valid(r21_touch):
        r21_touch.set_shop_open(false)

func _r15_apply_loadout() -> void:
    fleet_r15.set_loadout(equipped_r15, weapon_r15, rockets_r15, wingmen_r15)
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
    file.store_string(JSON.stringify({"version":1,"credits":credits,"xp":xp,"mission":mission_index,"player_x":ship.global_position.x,"player_y":ship.global_position.y,"player_z":ship.global_position.z,"engine_rank":ship.engine_rank,"weapon_rank":ship.weapon_rank,"owned_r15":owned_r15,"equipped_r15":equipped_r15,"weapon_r15":weapon_r15,"rockets_r15":rockets_r15,"wingmen_r15":wingmen_r15}))
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
