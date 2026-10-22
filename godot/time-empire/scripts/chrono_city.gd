extends Node3D
## OSGARD TIME EMPIRE — CHRONOS CITY. Original Godot 4.7.2 strategy vertical slice.
## No art ripped from any reference titles. Procedural 3D visuals; gameplay is stateful.

const GOLD := Color(1.0, 0.76, 0.43)
const CYAN := Color(0.27, 0.82, 0.96)
const PEARL := Color(0.85, 0.91, 0.95)
const STEEL := Color(0.16, 0.26, 0.34)
const MIDNIGHT := Color(0.035, 0.075, 0.13)
const MINT := Color(0.38, 0.92, 0.69)
const START_TIME := 180.0
const BASE_RATE := 2.0
const PLOTS := [
    Vector3(-11.0, 0.0, -11.0),
    Vector3(11.0, 0.0, -11.0),
    Vector3(11.0, 0.0, 11.0),
    Vector3(-11.0, 0.0, 11.0),
    Vector3(-18.5, 0.0, 0.0),
    Vector3(18.5, 0.0, 0.0),
]

@export var save_path: String = "user://osgard_chronos_city_v01.json"
var time_units: float = START_TIME
var production_rate: float = BASE_RATE
var core_level: int = 1
var district_count: int = 0
var lifetime_earned: float = 0.0
var orbit: float = 0.78
var camera_radius: float = 31.0
var map_mode: bool = false
var drag_camera: bool = false
var mobile_hud: bool = false
var elapsed: float = 0.0
var notification: float = 0.0
var materials: Dictionary = {}
var metal_texture: ImageTexture

var world_environment: WorldEnvironment
var camera: Camera3D
var sunlight: DirectionalLight3D
var core: Node3D
var core_rings: Array[Node3D] = []
var plots: Node3D
var root_ui: Control
var resource_label: Label
var rate_label: Label
var mission_label: Label
var city_label: Label
var status_label: Label
var build_button: Button
var upgrade_button: Button
var map_button: Button

func _ready() -> void:
    metal_texture = _metal_microtexture()
    _build_world()
    _build_city()
    _build_ui()
    _load_game()
    _refresh_ui()
    get_viewport().size_changed.connect(_resize_ui)
    _resize_ui()

func _build_world() -> void:
    world_environment = WorldEnvironment.new()
    world_environment.name = "ChronosAtmosphere"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.017, 0.035, 0.072)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.32, 0.41, 0.57)
    env.ambient_light_energy = 0.6
    env.reflected_light_source = Environment.REFLECTION_SOURCE_BG
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.glow_enabled = true
    env.glow_intensity = 0.45
    env.fog_enabled = true
    env.fog_light_color = Color(0.24, 0.37, 0.46)
    env.fog_density = 0.003
    world_environment.environment = env
    add_child(world_environment)

    sunlight = DirectionalLight3D.new()
    sunlight.name = "ChronosSun"
    sunlight.rotation_degrees = Vector3(-54.0, -26.0, 0.0)
    sunlight.light_color = Color(0.98, 0.8, 0.58)
    sunlight.light_energy = 1.1
    add_child(sunlight)
    _omni(Vector3(0, 12, 0), GOLD, 2.8, 22.0)
    _omni(Vector3(-15, 6, -15), CYAN, 1.5, 17.0)
    _omni(Vector3(15, 6, 15), GOLD, 1.8, 16.0)

    camera = Camera3D.new()
    camera.name = "StrategyCamera"
    camera.current = true
    camera.fov = 55.0
    camera.near = 0.1
    camera.far = 250.0
    add_child(camera)
    camera.position = Vector3(24.0, 24.0, 29.0)
    camera.look_at(Vector3(0.0, 3.5, 0.0))

func _build_city() -> void:
    var city := Node3D.new()
    city.name = "LivingCity"
    add_child(city)
    _cylinder(city, "CityFoundation", Vector3(0, -2.5, 0), 30.0, 4.6, MIDNIGHT, 0.82, 0.39)
    _cylinder(city, "CitySurface", Vector3(0, -0.1, 0), 29.2, 0.5, Color(0.21, 0.3, 0.34), 0.85, 0.39)
    _torus(city, "OuterCityBoundary", Vector3(0, 0.22, 0), 28.6, 0.13, GOLD, 0.46, 0.19, 2.0)
    _torus(city, "InnerTransitRing", Vector3(0, 0.25, 0), 20.5, 0.12, CYAN, 0.3, 0.2, 1.35)
    _torus(city, "CivicPromenade", Vector3(0, 0.23, 0), 7.8, 0.25, GOLD, 0.42, 0.29, 1.5)
    _box(city, "NorthSouthAvenue", Vector3(3.4, 0.08, 56.0), Vector3(0, 0.23, 0), Color(0.06, 0.12, 0.16), 0.3, 0.55)
    _box(city, "EastWestAvenue", Vector3(56.0, 0.08, 3.4), Vector3(0, 0.23, 0), Color(0.06, 0.12, 0.16), 0.3, 0.55)
    for mark in range(-25, 26, 4):
        _box(city, "AvenueLight", Vector3(0.11, 0.03, 0.76), Vector3(0.0, 0.29, float(mark)), GOLD, 0.0, 0.1, 2.0)
        _box(city, "AvenueLight", Vector3(0.76, 0.03, 0.11), Vector3(float(mark), 0.29, 0.0), GOLD, 0.0, 0.1, 2.0)
    _populate_skyline(city)

    core = Node3D.new()
    core.name = "ChronoCore"
    city.add_child(core)
    _cylinder(core, "ReactorPedestal", Vector3(0, 0.75, 0), 3.6, 1.5, STEEL, 0.85, 0.21)
    _cylinder(core, "ReactorCollar", Vector3(0, 1.8, 0), 2.2, 0.8, Color(0.39, 0.47, 0.54), 0.85, 0.16)
    _cylinder(core, "ReactorShaft", Vector3(0, 4.25, 0), 0.95, 5.0, Color(0.18, 0.26, 0.32), 0.78, 0.25)
    _sphere(core, "ChronoEnergyHeart", Vector3(0, 6.5, 0), 1.62, GOLD, 0.24, 0.18, 2.8)
    _sphere(core, "EnergyFilament", Vector3(0, 6.5, 0), 0.84, Color(1.0, 0.96, 0.75), 0.0, 0.10, 3.3)
    for i in range(3):
        var ring_root := Node3D.new()
        ring_root.name = "ChronoRing_%d" % i
        ring_root.position = Vector3(0, 6.5, 0)
        core.add_child(ring_root)
        _torus(ring_root, "OrbitRing", Vector3.ZERO, 2.25 + float(i) * 0.46, 0.11, GOLD if i < 2 else CYAN, 0.82, 0.18, 2.3)
        ring_root.rotation_degrees = Vector3(float(i) * 39.0 + 26.0, float(i) * 30.0, 15.0)
        core_rings.append(ring_root)
    for i in range(8):
        var a: float = float(i) * TAU / 8.0
        var x: float = cos(a) * 4.65
        var z: float = sin(a) * 4.65
        _cylinder(core, "ReactorArcTower", Vector3(x, 2.35, z), 0.42, 4.2, STEEL, 0.86, 0.26)
        _sphere(core, "TowerPowerNode", Vector3(x, 4.65, z), 0.31, CYAN, 0.1, 0.11, 2.4)
        _box(core, "PowerConduit", Vector3(0.19, 0.12, 2.6), Vector3(x * 0.72, 0.42, z * 0.72), GOLD, 0.63, 0.24, 0.7).rotate_y(-a)
    var stamp := Label3D.new()
    stamp.text = "C H R O N O S  /  0 1"
    stamp.font_size = 100
    stamp.pixel_size = 0.006
    stamp.modulate = PEARL
    stamp.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    stamp.position = Vector3(0.0, 11.3, 0.0)
    city.add_child(stamp)
    plots = Node3D.new()
    plots.name = "DistrictPlots"
    city.add_child(plots)
    for i in range(PLOTS.size()):
        var site: Vector3 = PLOTS[i]
        _cylinder(city, "DistrictAnchor", site + Vector3(0, 0.36, 0), 3.35, 0.18, Color(0.17, 0.28, 0.32), 0.65, 0.36)
        _torus(city, "PlotOutline", site + Vector3(0, 0.49, 0), 3.0, 0.05, CYAN, 0.15, 0.24, 1.2)

func _populate_skyline(parent: Node3D) -> void:
    # Dense 3D skyline in two draw calls (PBR blocks + emissive windows).
    # MultiMesh keeps the browser renderer fast despite the city scale.
    var buildings: Array[Transform3D] = []
    var windows: Array[Transform3D] = []
    for ix in range(-10, 11):
        for iz in range(-10, 11):
            var x: float = float(ix) * 2.45
            var z: float = float(iz) * 2.45
            var r: float = Vector2(x, z).length()
            if r < 8.9 or r > 25.2 or abs(ix) <= 1 or abs(iz) <= 1:
                continue
            # Reserved sites for user-built districts are physically clear.
            var reserved := false
            for slot in PLOTS:
                if Vector2(x - slot.x, z - slot.z).length() < 4.5:
                    reserved = true
                    break
            if reserved:
                continue
            var h: float = 2.3 + float(abs(ix * 31 + iz * 19) % 11) * 0.50
            buildings.append(Transform3D(Basis().scaled(Vector3(1.52, h, 1.52)), Vector3(x, h * 0.5 + 0.38, z)))
            for floor_index in range(1, int(h / 1.0)):
                windows.append(Transform3D(Basis().scaled(Vector3(0.83, 0.075, 0.08)), Vector3(x, 0.38 + float(floor_index), z + 0.80)))
    _batch_mesh(parent, "SkylineTowers", buildings, _material(Color(0.27, 0.37, 0.43), 0.83, 0.24))
    _batch_mesh(parent, "IlluminatedWindows", windows, _material(Color(0.8, 0.83, 0.74), 0.18, 0.17, 1.45))

func _batch_mesh(parent: Node3D, item_name: String, locations: Array[Transform3D], material: Material) -> void:
    var mesh := BoxMesh.new()
    mesh.size = Vector3.ONE
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = locations.size()
    for i in range(locations.size()):
        multi.set_instance_transform(i, locations[i])
    var instance := MultiMeshInstance3D.new()
    instance.name = item_name
    instance.multimesh = multi
    instance.material_override = material
    parent.add_child(instance)

func _district_cost() -> float:
    return 65.0 + float(district_count) * 50.0

func _upgrade_cost() -> float:
    return 120.0 + float(core_level - 1) * 95.0

func _build_district() -> bool:
    if district_count >= PLOTS.size():
        status_label.text = "Все шесть районов уже построены"
        notification = 4.0
        return false
    var cost := _district_cost()
    if time_units < cost:
        status_label.text = "Не хватает времени. Подожди накопления."
        notification = 4.0
        return false
    time_units -= cost
    _place_district(district_count)
    district_count += 1
    production_rate = _calculate_rate()
    status_label.text = "Новый район построен! Доход увеличился."
    notification = 4.0
    _refresh_ui()
    _save_game()
    return true

func _place_district(index: int) -> void:
    var pos: Vector3 = PLOTS[index]
    var district := Node3D.new()
    district.name = "District_%02d" % (index + 1)
    district.position = pos
    plots.add_child(district)
    _cylinder(district, "Platform", Vector3(0, 0.7, 0), 2.7, 0.8, STEEL, 0.77, 0.3)
    _cylinder(district, "Generator", Vector3(0, 2.5, 0), 1.2, 3.7, Color(0.39, 0.51, 0.56), 0.82, 0.22)
    _sphere(district, "ActiveChronosphere", Vector3(0, 4.55, 0), 0.82, GOLD, 0.18, 0.15, 2.0)
    _torus(district, "FocusingRing", Vector3(0, 4.55, 0), 1.22, 0.08, CYAN, 0.3, 0.16, 1.8)
    for tower in range(4):
        var a: float = float(tower) * TAU / 4.0
        _cylinder(district, "DistrictPylon", Vector3(cos(a) * 2.0, 1.6, sin(a) * 2.0), 0.25, 2.4, STEEL, 0.85, 0.33)
        _sphere(district, "SignalLamp", Vector3(cos(a) * 2.0, 3.0, sin(a) * 2.0), 0.18, MINT, 0.0, 0.15, 2.3)

func _calculate_rate() -> float:
    return BASE_RATE + float(district_count) * 3.0 + float(core_level - 1) * 2.0

func _upgrade_core() -> bool:
    var cost := _upgrade_cost()
    if time_units < cost:
        status_label.text = "На улучшение ядра пока не хватает времени"
        notification = 4.0
        return false
    time_units -= cost
    core_level += 1
    production_rate = _calculate_rate()
    status_label.text = "Хроноядро улучшено. Генерация ускорилась!"
    notification = 4.0
    _refresh_ui()
    _save_game()
    return true

func _toggle_map() -> void:
    map_mode = not map_mode
    map_button.text = "ГОРОД" if map_mode and mobile_hud else "КАРТА" if mobile_hud else "ВЕРНУТЬСЯ В ГОРОД" if map_mode else "КАРТА ГОРОДА"
    status_label.text = "Карта: смотри на районы сверху" if map_mode else "Камера вернулась к городу"
    notification = 2.0

func _process(delta: float) -> void:
    elapsed += delta
    if delta > 0.0:
        time_units += delta * production_rate
        lifetime_earned += delta * production_rate
    for i in range(core_rings.size()):
        core_rings[i].rotate_y(delta * (0.12 + float(i) * 0.05) * (1.0 + float(core_level - 1) * 0.14))
        core_rings[i].rotate_x(delta * (0.035 + float(i) * 0.025))
    if camera != null:
        var high: float = 1.1 if map_mode else 0.70
        var r: float = camera_radius * (1.18 if map_mode else 1.0)
        var destination := Vector3(cos(orbit) * r, r * high, sin(orbit) * r)
        camera.position = camera.position.lerp(destination, minf(delta * 2.5, 1.0))
        camera.look_at(Vector3(0.0, 3.4, 0.0))
    if sunlight != null:
        sunlight.light_energy = 0.92 + sin(elapsed * 0.045) * 0.2
    if notification > 0.0:
        notification = maxf(0.0, notification - delta)
    if resource_label != null:
        _refresh_ui()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            drag_camera = event.pressed
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            camera_radius = maxf(20.0, camera_radius - 2.0)
        if event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            camera_radius = minf(55.0, camera_radius + 2.0)
    elif event is InputEventMouseMotion and drag_camera:
        orbit += event.relative.x * 0.008
    elif event is InputEventKey and event.pressed and not event.echo:
        match event.keycode:
            KEY_B:
                _build_district()
            KEY_U:
                _upgrade_core()
            KEY_TAB, KEY_M:
                _toggle_map()
            KEY_LEFT, KEY_A:
                orbit -= 0.13
            KEY_RIGHT, KEY_D:
                orbit += 0.13
            KEY_UP, KEY_W:
                camera_radius = maxf(20.0, camera_radius - 2.0)
            KEY_DOWN, KEY_S:
                camera_radius = minf(55.0, camera_radius + 2.0)

func _build_ui() -> void:
    root_ui = Control.new()
    root_ui.name = "EmpireHUD"
    root_ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    root_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(root_ui)

    var title := PanelContainer.new()
    title.name = "TopBar"
    _panel(title, Color(0.025, 0.046, 0.071, 0.92), GOLD)
    title.anchor_left = 0.025
    title.anchor_right = 0.975
    title.offset_top = 22.0
    title.offset_bottom = 132.0
    root_ui.add_child(title)
    var bar := HBoxContainer.new()
    bar.add_theme_constant_override("separation", 25)
    title.add_child(bar)
    var brand := VBoxContainer.new()
    brand.name = "Brand"
    bar.add_child(brand)
    brand.add_child(_label("ИМПЕРИЯ ВРЕМЕНИ", 24, PEARL))
    brand.add_child(_label("CHRONOS  /  ЖИВОЙ ГОРОД", 13, GOLD))
    var gap := Control.new()
    gap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(gap)
    var progress := VBoxContainer.new()
    progress.name = "CurrentMission"
    bar.add_child(progress)
    progress.add_child(_label("ТВОЯ ЦЕЛЬ", 13, GOLD))
    mission_label = _label("Построй первый хроногенератор", 22, PEARL)
    progress.add_child(mission_label)
    var counters := VBoxContainer.new()
    counters.name = "ResourceCounters"
    bar.add_child(counters)
    resource_label = _label("ВРЕМЯ 180", 23, GOLD)
    rate_label = _label("ДОХОД +2 / сек", 15, MINT)
    counters.add_child(resource_label)
    counters.add_child(rate_label)

    var actions := PanelContainer.new()
    actions.name = "PrimaryActions"
    _panel(actions, Color(0.023, 0.047, 0.068, 0.93), Color(0.32, 0.47, 0.50))
    actions.anchor_left = 0.15
    actions.anchor_right = 0.85
    actions.anchor_top = 1.0
    actions.anchor_bottom = 1.0
    actions.offset_top = -162.0
    actions.offset_bottom = -25.0
    root_ui.add_child(actions)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation", 9)
    actions.add_child(v)
    var buttons := HBoxContainer.new()
    buttons.name = "Buttons"
    buttons.add_theme_constant_override("separation", 10)
    v.add_child(buttons)
    build_button = _button("СТРОИТЬ РАЙОН", GOLD, Color(0.21, 0.13, 0.065))
    build_button.pressed.connect(_build_district)
    buttons.add_child(build_button)
    upgrade_button = _button("УЛУЧШИТЬ ЯДРО", CYAN, Color(0.07, 0.17, 0.23))
    upgrade_button.pressed.connect(_upgrade_core)
    buttons.add_child(upgrade_button)
    map_button = _button("КАРТА ГОРОДА", PEARL, Color(0.11, 0.15, 0.19))
    map_button.pressed.connect(_toggle_map)
    buttons.add_child(map_button)
    for child in buttons.get_children():
        child.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    var note := HBoxContainer.new()
    v.add_child(note)
    city_label = _label("РАЙОНОВ 0/6  ·  ЯДРО УРОВЕНЬ 1", 14, Color(0.72, 0.83, 0.88))
    note.add_child(city_label)
    var filler := Control.new()
    filler.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    note.add_child(filler)
    note.add_child(_label("B — строить  ·  U — улучшить  ·  TAB — карта", 12, Color(0.64, 0.75, 0.8)))

    var info := PanelContainer.new()
    info.name = "HintPanel"
    _panel(info, Color(0.027, 0.056, 0.077, 0.88), GOLD)
    info.anchor_left = 0.02
    info.anchor_right = 0.41
    info.anchor_top = 0.51
    info.anchor_bottom = 0.51
    info.offset_top = 0.0
    info.offset_bottom = 75.0
    root_ui.add_child(info)
    status_label = _label("Строй районы. Они ускоряют накопление времени.", 15, PEARL)
    status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    info.add_child(status_label)

func _resize_ui() -> void:
    var mobile: bool = get_viewport().get_visible_rect().size.x < 850.0
    mobile_hud = mobile
    var bar := root_ui.get_node_or_null("TopBar") as PanelContainer
    var action_bar := root_ui.get_node_or_null("PrimaryActions") as PanelContainer
    var hint := root_ui.get_node_or_null("HintPanel") as PanelContainer
    if bar:
        var row := bar.get_child(0) as HBoxContainer
        row.get_node("Brand").visible = not mobile
        row.get_node("CurrentMission").visible = true
        mission_label.add_theme_font_size_override("font_size", 15 if mobile else 22)
        resource_label.add_theme_font_size_override("font_size", 17 if mobile else 23)
    if action_bar:
        action_bar.anchor_left = 0.02 if mobile else 0.15
        action_bar.anchor_right = 0.98 if mobile else 0.85
        var buttons := action_bar.get_node("VBoxContainer/Buttons") as HBoxContainer
        var action_column := action_bar.get_child(0) as VBoxContainer
        action_column.get_child(1).visible = not mobile
        action_bar.offset_top = -117.0 if mobile else -162.0
        for child in buttons.get_children():
            var b := child as Button
            b.add_theme_font_size_override("font_size", 15 if mobile else 17)
    if hint:
        hint.visible = not mobile
    _refresh_ui()

func _refresh_ui() -> void:
    if resource_label == null:
        return
    resource_label.text = "ВРЕМЯ  %d" % int(time_units)
    rate_label.text = "ДОХОД  +%.1f / сек" % production_rate
    city_label.text = "РАЙОНОВ  %d/6   ·   ЯДРО  УРОВЕНЬ %d" % [district_count, core_level]
    if district_count == 0:
        mission_label.text = "Построй генератор" if mobile_hud else "Построй первый хроногенератор"
    elif core_level == 1:
        mission_label.text = "Улучши ядро" if mobile_hud else "Улучши хроноядро до уровня 2"
    elif district_count < PLOTS.size():
        mission_label.text = "Строй районы" if mobile_hud else "Расширяй город новыми районами"
    else:
        mission_label.text = "Развивай город" if mobile_hud else "Империя развивается — продолжай улучшения"
    build_button.text = "СТРОИТЬ" if mobile_hud else "СТРОИТЬ  ·  %d" % int(_district_cost()) if district_count < PLOTS.size() else "РАЙОНЫ ГОТОВЫ"
    build_button.disabled = time_units < _district_cost() or district_count >= PLOTS.size()
    upgrade_button.text = "УЛУЧШИТЬ" if mobile_hud else "ЯДРО +1  ·  %d" % int(_upgrade_cost())
    map_button.text = "ГОРОД" if map_mode and mobile_hud else "КАРТА" if mobile_hud else "ВЕРНУТЬСЯ В ГОРОД" if map_mode else "КАРТА ГОРОДА"
    upgrade_button.disabled = time_units < _upgrade_cost()
    if notification <= 0.0:
        status_label.text = "Построй район: +3 времени/сек. Улучши ядро: +2/сек."

func _save_game() -> void:
    var payload := {
        "version": 1,
        "time_units": time_units,
        "district_count": district_count,
        "core_level": core_level,
        "lifetime_earned": lifetime_earned,
    }
    var f := FileAccess.open(save_path, FileAccess.WRITE)
    if f != null:
        f.store_string(JSON.stringify(payload))

func _load_game() -> void:
    if not FileAccess.file_exists(save_path):
        return
    var f := FileAccess.open(save_path, FileAccess.READ)
    if f == null:
        return
    var parsed: Variant = JSON.parse_string(f.get_as_text())
    if not parsed is Dictionary or int(parsed.get("version", -1)) != 1:
        return
    district_count = clampi(int(parsed.get("district_count", 0)), 0, PLOTS.size())
    core_level = clampi(int(parsed.get("core_level", 1)), 1, 100)
    time_units = clampf(float(parsed.get("time_units", START_TIME)), 0.0, 1000000000.0)
    lifetime_earned = maxf(0.0, float(parsed.get("lifetime_earned", 0.0)))
    production_rate = _calculate_rate()
    for i in range(district_count):
        _place_district(i)

func _panel(node: PanelContainer, backdrop: Color, stroke: Color) -> void:
    var style := StyleBoxFlat.new()
    style.bg_color = backdrop
    style.border_color = stroke.darkened(0.55)
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(14.0)
    node.add_theme_stylebox_override("panel", style)

func _label(content: String, fontsize: int, color: Color) -> Label:
    var node := Label.new()
    node.text = content
    node.add_theme_font_size_override("font_size", fontsize)
    node.add_theme_color_override("font_color", color)
    return node

func _button(content: String, foreground: Color, backdrop: Color) -> Button:
    var button := Button.new()
    button.text = content
    button.custom_minimum_size = Vector2(155.0, 61.0)
    button.add_theme_font_size_override("font_size", 17)
    button.add_theme_color_override("font_color", foreground)
    var style := StyleBoxFlat.new()
    style.bg_color = backdrop
    style.border_color = foreground.darkened(0.53)
    style.set_border_width_all(1)
    style.set_corner_radius_all(9)
    style.set_content_margin_all(10.0)
    button.add_theme_stylebox_override("normal", style)
    var hover := style.duplicate() as StyleBoxFlat
    hover.bg_color = backdrop.lightened(0.19)
    button.add_theme_stylebox_override("hover", hover)
    button.add_theme_stylebox_override("focus", hover)
    return button

func _metal_microtexture() -> ImageTexture:
    var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    var noise := FastNoiseLite.new()
    noise.seed = 24012026
    noise.frequency = 0.043
    for y in range(128):
        for x in range(128):
            var detail: float = noise.get_noise_2d(float(x), float(y))
            var streak: float = sin(float(y) * 1.1) * 0.04
            var v: float = clampf(0.88 + detail * 0.12 + streak, 0.64, 1.0)
            image.set_pixel(x, y, Color(v, v, v * 0.98, 1.0))
    image.generate_mipmaps()
    return ImageTexture.create_from_image(image)

func _material(color: Color, metallic: float, roughness: float, emission: float = 0.0) -> StandardMaterial3D:
    var key := "%s|%.2f|%.2f|%.2f" % [color.to_html(), metallic, roughness, emission]
    if materials.has(key):
        return materials[key] as StandardMaterial3D
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = roughness
    if metallic > 0.72 and emission == 0.0 and metal_texture != null:
        mat.albedo_texture = metal_texture
        mat.uv1_scale = Vector3(2.0, 2.0, 1.0)
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    materials[key] = mat
    return mat

func _box(parent: Node3D, item_name: String, size: Vector3, center: Vector3, color: Color, metallic: float, rough: float, glow: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = item_name
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.material_override = _material(color, metallic, rough, glow)
    node.position = center
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, item_name: String, center: Vector3, radius: float, height: float, color: Color, metallic: float, rough: float, glow: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = item_name
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 64 if radius > 10.0 else 28
    node.mesh = mesh
    node.material_override = _material(color, metallic, rough, glow)
    node.position = center
    parent.add_child(node)
    return node

func _sphere(parent: Node3D, item_name: String, center: Vector3, radius: float, color: Color, metallic: float, rough: float, glow: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = item_name
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 40
    mesh.rings = 24
    node.mesh = mesh
    node.material_override = _material(color, metallic, rough, glow)
    node.position = center
    parent.add_child(node)
    return node

func _torus(parent: Node3D, item_name: String, center: Vector3, radius: float, tube: float, color: Color, metallic: float, rough: float, glow: float = 0.0) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = item_name
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius - tube
    mesh.outer_radius = radius + tube
    mesh.rings = 80 if radius > 5.0 else 48
    mesh.ring_segments = 16
    node.mesh = mesh
    node.material_override = _material(color, metallic, rough, glow)
    node.position = center
    parent.add_child(node)
    return node

func _omni(center: Vector3, color: Color, intensity: float, radius: float) -> OmniLight3D:
    var light := OmniLight3D.new()
    light.position = center
    light.light_color = color
    light.light_energy = intensity
    light.omni_range = radius
    light.shadow_enabled = false
    add_child(light)
    return light