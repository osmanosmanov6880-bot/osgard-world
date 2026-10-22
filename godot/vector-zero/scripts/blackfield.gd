extends Node3D
## VECTOR//ZERO — BLACKFIELD / playable 3D vertical slice.
## Procedural industrial geometry is original; no borrowed commercial game assets.

const Sim = preload("res://scripts/magnetic_sim.gd")
const UltraDetail = preload("res://scripts/ultra_detail_kit.gd")
const HeroDetailV2 = preload("res://scripts/hero_detail_v2.gd")
const CYAN := Color(0.24, 0.83, 1.0)
const VIOLET := Color(0.64, 0.43, 1.0)
const MINT := Color(0.37, 1.0, 0.75)
const GOLD := Color(1.0, 0.66, 0.3)
const STEEL := Color(0.27, 0.35, 0.40)
const DARK := Color(0.075, 0.107, 0.14)

const STAGES: Array[Dictionary] = [
    {"name": "МАГНИТНЫЙ РАЗЛОМ", "hint": "Притягивай ядро к катушке, чтобы изменить дугу полёта.", "magnet": Vector3(-0.4, 5.3, 0.0), "target": Vector3(8.8, 3.65, 0.0), "field": 6.0, "angle": 32.0},
    {"name": "ИНВЕРСИЯ ПОЛЯ", "hint": "Смени полярность: отталкивание позволит обойти катушку.", "magnet": Vector3(1.0, 3.8, 0.0), "target": Vector3(8.8, 3.65, 0.0), "field": 8.0, "angle": 29.0},
    {"name": "ХРОНОПРОТОКОЛ", "hint": "Подбери угол запуска и силу магнитного поля.", "magnet": Vector3(-1.2, 6.2, 0.0), "target": Vector3(8.8, 3.65, 0.0), "field": 10.0, "angle": 29.0},
]

var stage_index: int = 0
var state: String = "aiming" # aiming / flying / success / failed
var polarity: int = 1
var launch_angle: float = 30.0
var sim_position: Vector3 = Vector3.ZERO
var sim_velocity: Vector3 = Vector3.ZERO
var launch_origin := Vector3(-8.8, 2.3, 0.0)
var magnet_position := Vector3.ZERO
var target_position := Vector3.ZERO
var field_strength: float = 6.0
var accumulator: float = 0.0
var elapsed: float = 0.0
var shots: int = 0
var camera_tactical: bool = false
var camera_shake: float = 0.0
var mobile_hud: bool = false
var time_elapsed: float = 0.0

var camera: Camera3D
var core_root: Node3D
var magnet_root: Node3D
var target_root: Node3D
var trajectory_root: Node3D
var dynamo_rings: Array[Node3D] = []
var jet_light: OmniLight3D
var status_label: Label
var stage_label: Label
var hint_label: Label
var polarity_label: Label
var info_label: Label
var launch_button: Button
var polarity_button: Button
var angle_label: Label
var steel_texture: Texture2D
var material_cache: Dictionary = {}

func _ready() -> void:
    steel_texture = _create_brushed_steel_texture()
    _build_world()
    _build_environment()
    _build_game_objects()
    UltraDetail.build(self, core_root, magnet_root, target_root)
    HeroDetailV2.build(self, core_root, magnet_root, target_root)
    _build_ui()
    _load_stage(0)
    get_viewport().size_changed.connect(_on_viewport_changed)
    _on_viewport_changed()

func _build_world() -> void:
    var world_environment := WorldEnvironment.new()
    world_environment.name = "CinematicEnvironment"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.022, 0.042, 0.064)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.35, 0.43, 0.51)
    env.ambient_light_energy = 1.0
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    env.glow_intensity = 0.24
    env.fog_enabled = true
    env.fog_light_color = Color(0.09, 0.19, 0.27)
    env.fog_density = 0.004
    world_environment.environment = env
    add_child(world_environment)

    camera = Camera3D.new()
    camera.name = "CinematicCamera"
    camera.current = true
    camera.fov = 58.0
    camera.near = 0.1
    camera.far = 190.0
    camera.position = Vector3(0.0, 7.8, 18.8)
    add_child(camera)
    camera.look_at(Vector3(0.0, 4.2, 0.0), Vector3.UP)

    var directional := DirectionalLight3D.new()
    directional.name = "AtriumMoonlight"
    directional.rotation_degrees = Vector3(-50.0, 35.0, 0.0)
    directional.light_color = Color(0.52, 0.75, 1.0)
    directional.light_energy = 1.20
    add_child(directional)

    _omni(Vector3(-9.0, 11.2, 5.0), CYAN, 3.8, 20.0)
    _omni(Vector3(9.0, 11.2, 5.0), GOLD, 3.0, 20.0)
    _omni(Vector3(0.0, 11.5, -5.5), CYAN, 1.5, 24.0)
    _omni(Vector3(0.0, 5.0, 0.0), VIOLET, 1.5, 7.5)

    _box(self, "LowerFoundation", Vector3(29.0, 0.9, 22.0), Vector3(0.0, -0.9, 0.0), DARK, 0.93, 0.32)
    _box(self, "MainDeck", Vector3(28.0, 0.3, 16.0), Vector3(0.0, -0.26, -1.0), STEEL, 0.94, 0.3)
    _box(self, "RearWall", Vector3(28.0, 15.0, 0.8), Vector3(0.0, 6.8, -8.8), DARK, 0.82, 0.42)
    _box(self, "LeftWall", Vector3(0.8, 15.0, 18.0), Vector3(-14.0, 6.8, -0.5), DARK, 0.84, 0.38)
    _box(self, "RightWall", Vector3(0.8, 15.0, 18.0), Vector3(14.0, 6.8, -0.5), DARK, 0.84, 0.38)
    _box(self, "UpperRoof", Vector3(28.0, 1.2, 16.0), Vector3(0.0, 14.3, -1.0), DARK, 0.82, 0.37)

    # 3D chamber: architectural rhythm, maintenance passages and genuine depth.
    for x in range(-12, 13, 3):
        _box(self, "FloorRail", Vector3(0.09, 0.025, 15.8), Vector3(float(x), -0.08, -1.0), Color(0.36, 0.48, 0.55), 0.8, 0.48)
    for z in range(-8, 7, 2):
        _box(self, "DeckJoint", Vector3(27.0, 0.025, 0.07), Vector3(0.0, -0.08, float(z)), Color(0.1, 0.14, 0.19), 0.4, 0.8)
    for x in range(-12, 13, 4):
        _box(self, "RearColumn", Vector3(0.52, 13.8, 1.2), Vector3(float(x), 6.9, -8.2), Color(0.24, 0.32, 0.38), 0.85, 0.32)
        _box(self, "ColumnFacing", Vector3(0.28, 12.7, 0.1), Vector3(float(x), 6.9, -7.56), Color(0.34, 0.45, 0.52), 0.9, 0.24)
        _box(self, "VoltageRiser", Vector3(0.07, 10.0, 0.06), Vector3(float(x) + 0.13, 6.9, -7.47), CYAN, 0.1, 0.1, 2.0)
        _box(self, "OverheadTruss", Vector3(0.38, 0.4, 15.5), Vector3(float(x), 13.4, -1.0), Color(0.25, 0.34, 0.4), 0.82, 0.35)
    for y in [2.0, 6.0, 10.0, 13.0]:
        _box(self, "WallBridge", Vector3(26.5, 0.25, 0.42), Vector3(0.0, y, -7.65), STEEL, 0.88, 0.31)
        _box(self, "WallLighting", Vector3(26.4, 0.055, 0.06), Vector3(0.0, y + 0.19, -7.38), CYAN, 0.2, 0.15, 1.5)

    # Massive overhead luminaires, cabling, reinforced walls, hanging crane girders.
    for x in [-10.0, -5.0, 0.0, 5.0, 10.0]:
        _box(self, "LightGantries", Vector3(2.5, 0.3, 7.0), Vector3(x, 13.0, 0.8), Color(0.13, 0.2, 0.27), 0.82, 0.4)
        for z in [-5.3, -1.4, 2.5]:
            _box(self, "LightPanel", Vector3(1.6, 0.05, 0.33), Vector3(x, 12.78, z), Color(0.6, 0.91, 1.0), 0.18, 0.12, 3.0)
    for x in [-13.2, 13.2]:
        for z in [-6.0, -2.0, 2.0]:
            for y in [3.0, 8.0]:
                _box(self, "Bulkhead", Vector3(1.1, 3.0, 1.5), Vector3(x, y, z), STEEL, 0.9, 0.42)
                _box(self, "Indicator", Vector3(0.1, 0.2, 0.8), Vector3(x * 0.95, y + 1.0, z), GOLD, 0.2, 0.14, 2.0)
    for x in [-8.0, 8.0]:
        for z in [-6.2, 5.7]:
            _box(self, "MaintenancePlinth", Vector3(2.4, 0.36, 2.5), Vector3(x, 0.14, z), Color(0.26, 0.32, 0.39), 0.87, 0.33)
            _box(self, "PlinthCap", Vector3(2.45, 0.1, 2.55), Vector3(x, 0.39, z), Color(0.42, 0.48, 0.51), 0.85, 0.24)
    for z in [-7.0, -4.0, 3.0, 6.0]:
        _box(self, "ServiceConduit", Vector3(26.0, 0.12, 0.18), Vector3(0.0, 0.17, z), Color(0.51, 0.36, 0.21), 0.73, 0.47)
    # Architectural art pass: observation gallery, glass partitions and
    # recognizable industrial silhouettes behind the core playable objects.
    for x in [-11.0, -7.5, -4.0, 4.0, 7.5, 11.0]:
        _box(self, "ObservationWindowFrame", Vector3(2.0, 4.2, 0.23), Vector3(x, 8.3, -7.3), Color(0.43, 0.52, 0.57), 0.87, 0.24)
        var glazing := _box(self, "ObservationWindow", Vector3(1.74, 3.92, 0.08), Vector3(x, 8.3, -7.16), Color(0.12, 0.32, 0.43), 0.46, 0.12)
        var glaze := (glazing.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
        glaze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        glaze.albedo_color.a = 0.33
        glazing.material_override = glaze
        for i in range(3):
            var yy: float = 7.0 + float(i) * 1.1
            _box(self, "ObservationBrace", Vector3(2.05, 0.06, 0.16), Vector3(x, yy, -7.03), STEEL, 0.91, 0.3)
        _box(self, "ObservationSill", Vector3(2.25, 0.23, 0.55), Vector3(x, 6.08, -6.99), Color(0.48, 0.51, 0.52), 0.87, 0.25)
    for x in [-11.3, 11.3]:
        _box(self, "ElevatedGallery", Vector3(2.1, 0.24, 15.0), Vector3(x, 6.0, -0.7), Color(0.38, 0.44, 0.49), 0.86, 0.32)
        for z in [-6.4, -4.1, -1.8, 0.5, 2.8, 5.1]:
            _box(self, "RailSupport", Vector3(0.08, 1.3, 0.08), Vector3(x - (0.78 if x > 0.0 else -0.78), 6.6, z), Color(0.65, 0.70, 0.71), 0.85, 0.19)
        _box(self, "WalkwayGuard", Vector3(0.08, 0.14, 15.0), Vector3(x - (0.78 if x > 0.0 else -0.78), 7.25, -0.7), Color(0.59, 0.63, 0.65), 0.88, 0.26)
    for x in [-10.8, 10.8]:
        for z in [-4.0, 3.5]:
            _box(self, "EngineeringConsole", Vector3(1.2, 1.4, 0.82), Vector3(x, 0.7, z), Color(0.36, 0.43, 0.46), 0.84, 0.33)
            _box(self, "ConsoleDisplay", Vector3(0.95, 0.63, 0.04), Vector3(x, 1.07, z+0.44), Color(0.20, 0.67, 0.81), 0.26, 0.12, 0.95)
    for y in [2.5, 3.0, 3.5]:
        _box(self, "HazardStripe", Vector3(25.8, 0.03, 0.07), Vector3(0.0, -0.04, float(y)), Color(0.67, 0.48, 0.14), 0.34, 0.33)
    # Large plate steel wall typography stays in-world, not in floating HUD.
    _sign("B L A C K F I E L D", Vector3(0.0, 11.8, -7.25), 115, CYAN, 0.007)
    _sign("M A G N E T I C   T E S T   F A C I L I T Y   /   0 1", Vector3(0.0, 10.7, -7.25), 47, Color(0.58, 0.75, 0.8), 0.007)

func _build_environment() -> void:
    # Layered science-fiction machinery, with material response and silhouette.
    for x in [-10.3, -6.3, 5.2, 10.3]:
        var chassis := _box(self, "Cryopump", Vector3(1.5, 3.2, 1.6), Vector3(x, 1.6, -5.8), STEEL, 0.92, 0.24)
        var glass := _box(self, "GlassReservoir", Vector3(1.2, 1.8, 0.1), Vector3(x, 1.7, -4.9), Color(0.12, 0.35, 0.45), 0.54, 0.13, 0.55)
        var glass_material := (glass.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
        glass_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
        glass_material.albedo_color.a = 0.58
        glass.material_override = glass_material
        _box(self, "CryopumpCap", Vector3(1.75, 0.22, 1.9), Vector3(x, 3.22, -5.8), Color(0.43, 0.5, 0.56), 0.88, 0.23)
        for yy in [0.7, 1.0, 2.5]:
            _box(chassis, "Readout", Vector3(0.03, 0.06, 0.25), Vector3(-0.74, (yy - 1.6), 0.0), MINT, 0.08, 0.12, 2.0)
    for x in [-11.0, 11.0]:
        _box(self, "CraneRail", Vector3(0.4, 9.7, 0.4), Vector3(x, 5.0, -3.5), Color(0.3, 0.4, 0.44), 0.89, 0.28)
        for y in [1.5, 5.0, 8.5]:
            _box(self, "BracePlate", Vector3(2.1, 0.22, 0.52), Vector3(x, y, -3.5), Color(0.54, 0.51, 0.35), 0.8, 0.38)
        _box(self, "UprightLuminance", Vector3(0.09, 8.4, 0.11), Vector3(x + (0.28 if x < 0.0 else -0.28), 5.0, -3.11), CYAN, 0.15, 0.12, 2.0)

func _build_game_objects() -> void:
    core_root = Node3D.new()
    core_root.name = "PlayerEnergyCore"
    add_child(core_root)
    var core_base := _sphere(core_root, "PlasmaContainment", 0.53, Color(0.18, 0.55, 0.8), 0.4, 0.18, 0.85)
    core_base.scale = Vector3(1.0, 1.0, 1.0)
    _sphere(core_root, "InnerPlasma", 0.32, Color(0.75, 0.97, 1.0), 0.05, 0.05, 3.0)
    _torus(core_root, "GyroscopeA", 0.72, 0.065, CYAN, 0.8, 0.18, 2.0).rotation_degrees = Vector3(30, 70, 0)
    _torus(core_root, "GyroscopeB", 0.81, 0.045, Color(0.75, 0.84, 0.95), 0.83, 0.24, 1.0).rotation_degrees = Vector3(70, 30, 0)
    _torus(core_root, "GyroscopeC", 0.92, 0.03, CYAN, 0.82, 0.22, 1.5).rotation_degrees = Vector3(0, 0, 30)
    jet_light = _omni(Vector3(-8.8, 2.3, 0.0), CYAN, 2.4, 6.0)
    jet_light.name = "PlayerCorePointLight"

    magnet_root = Node3D.new()
    magnet_root.name = "MagnetAssembly"
    add_child(magnet_root)
    _cylinder(magnet_root, "SuperconductingStator", Vector3.ZERO, 1.0, 4.0, STEEL, 0.88, 0.3)
    _torus(magnet_root, "StatorWarningRing", 1.55, 0.12, GOLD, 0.8, 0.21, 1.0).position.y = -2.0
    _cylinder(magnet_root, "MagneticConductor", Vector3.ZERO, 0.66, 4.6, Color(0.21, 0.18, 0.36), 0.8, 0.2)
    for i in range(7):
        var side: float = -1.65 + float(i) * 0.55
        _torus(magnet_root, "CoilSegment", 1.33, 0.14, VIOLET, 0.72, 0.19, 1.6).position.y = side
    var halo := _sphere(magnet_root, "ContainmentField", 1.84, Color(0.26, 0.18, 0.48), 0.0, 0.12, 0.12)
    var halo_material := (halo.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
    halo_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    halo_material.albedo_color.a = 0.09
    halo_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    halo.material_override = halo_material
    for i in range(3):
        var ring := Node3D.new()
        ring.name = "ChargedGyro_%s" % i
        magnet_root.add_child(ring)
        ring.rotation_degrees = Vector3(25.0 * float(i), 40.0 * float(i), 0.0)
        _torus(ring, "FieldRing", 2.1 + i * 0.25, 0.06, VIOLET, 0.7, 0.14, 2.3)
        dynamo_rings.append(ring)
    _box(magnet_root, "StatorTop", Vector3(3.8, 0.28, 3.8), Vector3(0, 2.35, 0), STEEL, 0.87, 0.33)
    _box(magnet_root, "StatorBottom", Vector3(3.8, 0.28, 3.8), Vector3(0, -2.35, 0), STEEL, 0.87, 0.33)
    _sign("МАГНИТНАЯ КАТУШКА", Vector3(-0.4, 9.0, -4.5), 50, Color(0.8, 0.68, 1.0), 0.009)

    target_root = Node3D.new()
    target_root.name = "ReceiverAssembly"
    add_child(target_root)
    _torus(target_root, "ReceiverOuterRing", 1.25, 0.22, STEEL, 0.84, 0.2)
    _torus(target_root, "ReceiverActiveRing", 1.03, 0.12, MINT, 0.1, 0.1, 3.0)
    _torus(target_root, "ReceiverInnerRing", 0.75, 0.07, MINT, 0.35, 0.16, 1.8)
    _sphere(target_root, "TargetSensor", 0.25, MINT, 0.1, 0.1, 2.5)
    _box(target_root, "ReceiverStand", Vector3(0.55, 3.0, 0.65), Vector3(0, -2.3, -0.3), STEEL, 0.9, 0.25)
    _sign("ПРИЁМНИК", Vector3(8.7, 8.7, -4.5), 62, MINT, 0.011)

    trajectory_root = Node3D.new()
    trajectory_root.name = "PredictedFlightPath"
    add_child(trajectory_root)

    _box(self, "LaunchBase", Vector3(2.5, 0.5, 3.0), Vector3(-8.8, 0.18, 0), STEEL, 0.9, 0.2)
    _cylinder(self, "LaunchCradle", Vector3(-8.8, 1.2, 0), 0.7, 1.0, Color(0.4, 0.53, 0.61), 0.8, 0.27)
    _torus(self, "LaunchEmit", 0.75, 0.08, CYAN, 0.45, 0.2, 1.6).position = Vector3(-8.8, 1.95, 0.0)
    _sign("ПУСКОВОЙ УЗЕЛ", Vector3(-8.8, 4.9, -4.7), 48, CYAN, 0.01)

func _build_ui() -> void:
    var ui := Control.new()
    ui.name = "RussianGameHUD"
    ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(ui)

    var top := PanelContainer.new()
    top.name = "MissionBar"
    _panel(top, Color(0.024, 0.052, 0.07, 0.9), CYAN)
    top.anchor_left = 0.025
    top.anchor_right = 0.975
    top.offset_top = 22.0
    top.offset_bottom = 128.0
    top.mouse_filter = Control.MOUSE_FILTER_PASS
    ui.add_child(top)
    var h := HBoxContainer.new()
    h.add_theme_constant_override("separation", 32)
    top.add_child(h)
    var identity := VBoxContainer.new()
    h.add_child(identity)
    identity.add_child(_label("V E C T O R  / /  Z E R O", 17, CYAN, true))
    identity.add_child(_label("BLACKFIELD  ·  ПРОТОКОЛ 01", 13, Color(0.64, 0.75, 0.8)))
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(gap)
    var objective := VBoxContainer.new()
    objective.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    h.add_child(objective)
    objective.add_child(_label("ЦЕЛЬ ИСПЫТАНИЯ", 13, Color(0.61, 0.75, 0.81)))
    objective.add_child(_label("Доставь ядро в приёмник", 26, Color.WHITE, true))
    var info := VBoxContainer.new()
    h.add_child(info)
    stage_label = _label("ИСПЫТАНИЕ 01 / 03", 15, MINT, true)
    info.add_child(stage_label)
    status_label = _label("ГОТОВО К ЗАПУСКУ", 13, Color(0.75, 0.84, 0.89))
    info.add_child(status_label)

    var bottom := PanelContainer.new()
    bottom.name = "GameControls"
    _panel(bottom, Color(0.022, 0.045, 0.065, 0.94), Color(0.19, 0.45, 0.57))
    bottom.anchor_left = 0.16
    bottom.anchor_right = 0.84
    bottom.anchor_top = 1.0
    bottom.anchor_bottom = 1.0
    bottom.offset_top = -152.0
    bottom.offset_bottom = -24.0
    bottom.mouse_filter = Control.MOUSE_FILTER_PASS
    ui.add_child(bottom)
    var controls := VBoxContainer.new()
    controls.add_theme_constant_override("separation", 8)
    bottom.add_child(controls)
    var buttons := HBoxContainer.new()
    buttons.add_theme_constant_override("separation", 10)
    controls.add_child(buttons)
    launch_button = _button("ПРОБЕЛ · ЗАПУСТИТЬ", CYAN, Color(0.02, 0.16, 0.22))
    launch_button.pressed.connect(_primary_action)
    launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    buttons.add_child(launch_button)
    polarity_button = _button("Q · ПРИТЯЖЕНИЕ", VIOLET, Color(0.15, 0.075, 0.24))
    polarity_button.pressed.connect(_toggle_polarity)
    polarity_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    buttons.add_child(polarity_button)
    var reset_button := _button("R · СНАЧАЛА", Color(0.82, 0.9, 0.94), Color(0.11, 0.16, 0.2))
    reset_button.pressed.connect(_restart)
    reset_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    buttons.add_child(reset_button)
    var below := HBoxContainer.new()
    controls.add_child(below)
    angle_label = _label("← →  Угол запуска: 30°", 14, Color(0.69, 0.82, 0.87))
    below.add_child(angle_label)
    var expand := Control.new()
    expand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    below.add_child(expand)
    polarity_label = _label("ПОЛЕ: ПРИТЯЖЕНИЕ", 13, VIOLET, true)
    below.add_child(polarity_label)

    var left := PanelContainer.new()
    left.name = "TipPanel"
    _panel(left, Color(0.02, 0.045, 0.065, 0.81), Color(0.2, 0.42, 0.52))
    left.anchor_left = 0.02
    left.anchor_right = 0.32
    left.anchor_top = 0.47
    left.anchor_bottom = 0.47
    left.offset_top = 0.0
    left.offset_bottom = 106.0
    ui.add_child(left)
    var tips := VBoxContainer.new()
    left.add_child(tips)
    tips.add_child(_label("КАК ПРОЙТИ", 14, CYAN, true))
    hint_label = _label("Смотри на траекторию, затем запускай ядро.", 16, Color.WHITE)
    hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tips.add_child(hint_label)

    var top_right := PanelContainer.new()
    top_right.name = "ForecastPanel"
    _panel(top_right, Color(0.02, 0.045, 0.065, 0.82), Color(0.2, 0.42, 0.52))
    top_right.anchor_left = 0.735
    top_right.anchor_right = 0.975
    top_right.offset_top = 145.0
    top_right.offset_bottom = 208.0
    ui.add_child(top_right)
    var detail := VBoxContainer.new()
    top_right.add_child(detail)
    detail.add_child(_label("ПРОГНОЗ ПОЛЁТА", 12, CYAN, true))
    info_label = _label("Траектория отображается до запуска", 13, Color(0.88, 0.94, 0.98))
    detail.add_child(info_label)

    var camera_button := _button("TAB · СМЕНИТЬ КАМЕРУ", Color(0.68, 0.78, 0.84), Color(0.07, 0.12, 0.16))
    camera_button.name = "CameraSwitch"
    camera_button.anchor_left = 0.785
    camera_button.anchor_right = 0.97
    camera_button.anchor_top = 0.25
    camera_button.anchor_bottom = 0.25
    camera_button.offset_top = 0.0
    camera_button.offset_bottom = 52.0
    camera_button.pressed.connect(_toggle_camera)
    ui.add_child(camera_button)

func _on_viewport_changed() -> void:
    var is_mobile: bool = get_viewport().get_visible_rect().size.x < 850.0
    mobile_hud = is_mobile
    var header := get_node_or_null("RussianGameHUD/MissionBar") as PanelContainer
    if header:
        var header_row := header.get_child(0) as HBoxContainer
        header_row.get_child(0).visible = not is_mobile
        header_row.get_child(3).visible = not is_mobile
        (header_row.get_child(2) as VBoxContainer).get_child(1).add_theme_font_size_override("font_size", 17 if is_mobile else 26)
    var buttons := get_node_or_null("RussianGameHUD/GameControls") as PanelContainer
    if buttons:
        var button_row := (buttons.get_child(0) as VBoxContainer).get_child(0) as HBoxContainer
        for button in button_row.get_children():
            var b := button as Button
            b.custom_minimum_size = Vector2(0.0 if is_mobile else 140.0, 58.0)
            b.add_theme_font_size_override("font_size", 15 if is_mobile else 18)
    var forecast := get_node_or_null("RussianGameHUD/ForecastPanel") as PanelContainer
    if forecast:
        forecast.visible = not is_mobile
    var camera_switch := get_node_or_null("RussianGameHUD/CameraSwitch") as Button
    if camera_switch:
        camera_switch.visible = not is_mobile
    var controls := get_node_or_null("RussianGameHUD/GameControls") as PanelContainer
    var tip := get_node_or_null("RussianGameHUD/TipPanel") as PanelContainer
    if controls:
        controls.anchor_left = 0.03 if is_mobile else 0.16
        controls.anchor_right = 0.97 if is_mobile else 0.84
    if tip:
        tip.visible = not is_mobile
    _update_controls()
    if state == "aiming":
        launch_button.text = "▶ ЗАПУСК" if mobile_hud else "ПРОБЕЛ · ЗАПУСТИТЬ"

func _load_stage(next_stage: int) -> void:
    stage_index = next_stage % STAGES.size()
    var level: Dictionary = STAGES[stage_index]
    magnet_position = level["magnet"]
    target_position = level["target"]
    field_strength = float(level["field"])
    launch_angle = float(level["angle"])
    magnet_root.position = magnet_position + Vector3(0.0, 0.0, -2.55)
    target_root.position = target_position
    shots = 0
    polarity = 1
    _restart()
    stage_label.text = "ИСПЫТАНИЕ %02d / %02d" % [stage_index + 1, STAGES.size()]
    hint_label.text = str(level["hint"])
    _update_controls()

func _launch_velocity() -> Vector3:
    return Vector3(cos(deg_to_rad(launch_angle)), sin(deg_to_rad(launch_angle)), 0.0) * 14.25

func _primary_action() -> void:
    if state == "success":
        _load_stage(stage_index + 1)
        return
    if state == "failed":
        _restart()
        return
    if state == "flying":
        return
    state = "flying"
    sim_position = launch_origin
    sim_velocity = _launch_velocity()
    elapsed = 0.0
    accumulator = 0.0
    shots += 1
    status_label.text = "ЯДРО В ДВИЖЕНИИ"
    launch_button.text = "ПОЛЁТ..." if mobile_hud else "ЯДРО ЛЕТИТ..."
    launch_button.disabled = true
    _clear_preview()
    camera_shake = 0.3

func _restart() -> void:
    state = "aiming"
    sim_position = launch_origin
    sim_velocity = Vector3.ZERO
    core_root.position = sim_position
    elapsed = 0.0
    accumulator = 0.0
    status_label.text = "ГОТОВО К ЗАПУСКУ"
    launch_button.text = "▶ ЗАПУСК" if mobile_hud else "ПРОБЕЛ · ЗАПУСТИТЬ"
    launch_button.disabled = false
    _draw_preview()
    _update_controls()

func _toggle_polarity() -> void:
    polarity *= -1
    camera_shake = 0.13
    _update_controls()
    if state == "aiming":
        _draw_preview()

func _update_controls() -> void:
    if polarity == 1:
        polarity_label.text = "ПОЛЕ: ПРИТЯЖЕНИЕ"
        polarity_label.add_theme_color_override("font_color", VIOLET)
        polarity_button.text = "Q · ПОЛЕ +" if mobile_hud else "Q · ПРИТЯЖЕНИЕ"
    else:
        polarity_label.text = "ПОЛЕ: ОТТАЛКИВАНИЕ"
        polarity_label.add_theme_color_override("font_color", GOLD)
        polarity_button.text = "Q · ПОЛЕ −" if mobile_hud else "Q · ОТТАЛКИВАНИЕ"
    angle_label.text = "← →  %.0f°" % launch_angle if mobile_hud else "← →  Угол запуска: %.0f°" % launch_angle

func _toggle_camera() -> void:
    camera_tactical = not camera_tactical

func _unhandled_key_input(event: InputEvent) -> void:
    if not event is InputEventKey or not event.pressed or event.echo:
        return
    match event.keycode:
        KEY_SPACE:
            _primary_action()
        KEY_Q:
            _toggle_polarity()
        KEY_R:
            _restart()
        KEY_TAB:
            _toggle_camera()
        KEY_LEFT, KEY_A:
            if state == "aiming":
                launch_angle = maxf(10.0, launch_angle - 1.0)
                _update_controls()
                _draw_preview()
        KEY_RIGHT, KEY_D:
            if state == "aiming":
                launch_angle = minf(70.0, launch_angle + 1.0)
                _update_controls()
                _draw_preview()

func _physics_process(delta: float) -> void:
    if state != "flying":
        return
    accumulator += delta
    var limit: int = 0
    while accumulator >= Sim.STEP and limit < 12:
        limit += 1
        accumulator -= Sim.STEP
        elapsed += Sim.STEP
        var next_state: Dictionary = Sim.step(sim_position, sim_velocity, magnet_position, polarity, field_strength, Sim.STEP)
        sim_position = next_state["position"]
        sim_velocity = next_state["velocity"]
        core_root.position = sim_position
        jet_light.position = sim_position
        if Sim.reached_target(sim_position, target_position):
            _win()
            return
        if Sim.is_lost(sim_position) or elapsed >= 9.0:
            _fail()
            return
    if limit == 12:
        accumulator = minf(accumulator, Sim.STEP)

func _process(delta: float) -> void:
    time_elapsed += delta
    core_root.rotate_y(delta * 1.15)
    core_root.rotate_x(delta * 0.35)
    for i in range(dynamo_rings.size()):
        dynamo_rings[i].rotate_y((0.15 + 0.13 * i) * delta * float(polarity))
        dynamo_rings[i].rotate_x(0.10 * delta)
    target_root.rotate_z(delta * 0.08)
    if state == "aiming":
        core_root.position = launch_origin + Vector3(0.0, sin(time_elapsed * 2.0) * 0.06, 0.0)
        jet_light.position = core_root.position
    var desired := Vector3(0.0, 12.1, 25.0) if camera_tactical else Vector3(0.0, 7.8, 18.8)
    camera.position = camera.position.lerp(desired, minf(delta * 2.4, 1.0))
    camera_shake = maxf(0.0, camera_shake - delta)
    var shake: float = camera_shake * camera_shake * 0.06
    camera.look_at(Vector3(0.0, 4.2, 0.0) + Vector3(sin(time_elapsed * 60.0) * shake, 0.0, 0.0), Vector3.UP)

func _win() -> void:
    state = "success"
    status_label.text = "УСПЕХ · ПРИЁМНИК АКТИВЕН"
    launch_button.text = "ДАЛЬШЕ →" if mobile_hud else "СЛЕДУЮЩЕЕ ИСПЫТАНИЕ →"
    launch_button.disabled = false
    info_label.text = "Испытание пройдено за %.1f сек." % elapsed
    camera_shake = 0.6

func _fail() -> void:
    state = "failed"
    status_label.text = "ЯДРО ПОТЕРЯНО · ПОПРОБУЙ ЕЩЁ"
    launch_button.text = "↻ ПОВТОР" if mobile_hud else "ПОВТОРИТЬ ИСПЫТАНИЕ ↻"
    launch_button.disabled = false
    info_label.text = "Измени угол или полярность магнитного поля."
    camera_shake = 0.3

func _draw_preview() -> void:
    if trajectory_root == null:
        return
    _clear_preview()
    var result: Dictionary = Sim.simulate(launch_origin, _launch_velocity(), magnet_position, polarity, field_strength, target_position, 420, 5)
    var points: Array[Vector3] = result["samples"]
    # Single GPU draw group instead of hundreds of heavyweight MeshInstance3D nodes.
    # Degenerate samples (at the receiver/floor) must never produce a zero-vector quaternion.
    var transforms: Array[Transform3D] = []
    for i in range(1, points.size()):
        if i % 3 == 0:
            continue
        var direction: Vector3 = points[i] - points[i - 1]
        var length: float = direction.length()
        if length < 0.001 or not direction.is_finite():
            continue
        var frame := Basis(Quaternion(Vector3.UP, direction / length))
        transforms.append(Transform3D(frame.scaled(Vector3(0.040, length, 0.040)), (points[i] + points[i - 1]) * 0.5))
    if not transforms.is_empty():
        var segment_mesh := CylinderMesh.new()
        segment_mesh.top_radius = 1.0
        segment_mesh.bottom_radius = 1.0
        segment_mesh.height = 1.0
        segment_mesh.radial_segments = 8
        var bundle := MultiMesh.new()
        bundle.transform_format = MultiMesh.TRANSFORM_3D
        bundle.mesh = segment_mesh
        bundle.instance_count = transforms.size()
        for j in range(transforms.size()):
            bundle.set_instance_transform(j, transforms[j])
        var path_renderer := MultiMeshInstance3D.new()
        path_renderer.name = "FlightForecast"
        path_renderer.multimesh = bundle
        path_renderer.material_override = _standard(CYAN, 0.08, 0.14, 2.6)
        trajectory_root.add_child(path_renderer)
    info_label.text = "Прогноз: успешное попадание" if result["outcome"] == "reached" else "Прогноз: настрой угол или полярность"

func _clear_preview() -> void:
    for child in trajectory_root.get_children():
        trajectory_root.remove_child(child)
        child.queue_free()

func _panel(panel: PanelContainer, bg: Color, stroke: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = bg
    style.border_color = stroke.darkened(0.5)
    style.set_border_width_all(1)
    style.set_corner_radius_all(14)
    style.set_content_margin_all(14.0)
    panel.add_theme_stylebox_override("panel", style)

func _label(content: String, font_size: int, color: Color, bold_style: bool = false) -> Label:
    var lbl := Label.new()
    lbl.text = content
    lbl.add_theme_font_size_override("font_size", font_size)
    lbl.add_theme_color_override("font_color", color)
    if bold_style:
        lbl.add_theme_color_override("font_shadow_color", Color(0.0, 0.0, 0.0, 0.4))
        lbl.add_theme_constant_override("shadow_offset_y", 1)
    return lbl

func _button(content: String, ink: Color, background: Color) -> Button:
    var btn := Button.new()
    btn.text = content
    btn.custom_minimum_size = Vector2(140.0, 58.0)
    btn.add_theme_font_size_override("font_size", 18)
    btn.add_theme_color_override("font_color", ink)
    btn.add_theme_color_override("font_hover_color", Color.WHITE)
    var normal := StyleBoxFlat.new()
    normal.bg_color = background
    normal.border_color = ink.darkened(0.55)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(9)
    normal.set_content_margin_all(10)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = background.lightened(0.25)
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = background.lightened(0.37)
    btn.add_theme_stylebox_override("normal", normal)
    btn.add_theme_stylebox_override("hover", hover)
    btn.add_theme_stylebox_override("pressed", pressed)
    btn.add_theme_stylebox_override("focus", hover)
    return btn

func _create_brushed_steel_texture() -> ImageTexture:
    # Generated original microtexture: no external AAA game assets are copied.
    # Subtle grain and horizontal brushed-metal tooling marks catch specular light.
    var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    var noise := FastNoiseLite.new()
    noise.seed = 270106
    noise.frequency = 0.045
    for y in range(128):
        for x in range(128):
            var grain: float = noise.get_noise_2d(float(x), float(y))
            var stroke: float = sin(float(y) * 1.3 + grain * 1.7) * 0.045
            var scratch: float = -0.12 if (x * 37 + y * 19) % 263 < 2 else 0.0
            var shine: float = clampf(0.9 + grain * 0.10 + stroke + scratch, 0.60, 1.0)
            image.set_pixel(x, y, Color(shine, shine * 0.99, shine * 0.97, 1.0))
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)

func _standard(albedo: Color, metal: float, rough: float, glow: float = 0.0) -> StandardMaterial3D:
    var key := "%s|%.3f|%.3f|%.3f" % [albedo.to_html(), metal, rough, glow]
    if material_cache.has(key):
        return material_cache[key] as StandardMaterial3D
    var mat := StandardMaterial3D.new()
    mat.albedo_color = albedo
    mat.metallic = metal
    mat.roughness = rough
    if metal >= 0.7 and glow <= 0.0 and steel_texture != null:
        mat.albedo_texture = steel_texture
        mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
    if glow > 0.0:
        mat.emission_enabled = true
        mat.emission = albedo
        mat.emission_energy_multiplier = glow
    material_cache[key] = mat
    return mat

func _box(parent: Node3D, item_name: String, size: Vector3, pos: Vector3, albedo: Color, metal: float = 0.0, rough: float = 0.5, glow: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = item_name
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = _standard(albedo, metal, rough, glow)
    node.position = pos
    parent.add_child(node)
    return node

func _sphere(parent: Node3D, item_name: String, radius: float, albedo: Color, metal: float, rough: float, glow: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = item_name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 32
    mesh.rings = 16
    node.mesh = mesh
    node.material_override = _standard(albedo, metal, rough, glow)
    parent.add_child(node)
    return node

func _torus(parent: Node3D, item_name: String, major_radius: float, tube_radius: float, albedo: Color, metal: float, rough: float, glow: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = item_name
    var mesh := TorusMesh.new()
    mesh.inner_radius = major_radius - tube_radius
    mesh.outer_radius = major_radius + tube_radius
    mesh.rings = 48
    mesh.ring_segments = 16
    node.mesh = mesh
    node.material_override = _standard(albedo, metal, rough, glow)
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, item_name: String, pos: Vector3, radius: float, height: float, albedo: Color, metal: float, rough: float) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = item_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 28
    node.mesh = mesh
    node.material_override = _standard(albedo, metal, rough)
    node.position = pos
    parent.add_child(node)
    return node

func _omni(pos: Vector3, color: Color, energy: float, light_range: float) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = pos
    light.light_color = color
    light.light_energy = energy
    light.omni_range = light_range
    light.shadow_enabled = false
    add_child(light)
    return light

func _sign(text: String, position: Vector3, font_size: int, color: Color, pixel: float) -> void:
    var sign := Label3D.new()
    sign.text = text
    sign.font_size = font_size
    sign.pixel_size = pixel
    sign.modulate = color
    sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    sign.no_depth_test = false
    sign.position = position
    add_child(sign)