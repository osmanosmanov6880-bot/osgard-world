extends Node3D
## IRON PULSE: BLACKOUT — real, player-controlled 3D vertical slice in Godot 4.4.1.
## Procedural artwork and generated UI; offline and self-contained.

const NIGHT := Color(0.013, 0.025, 0.048)
const STEEL := Color(0.105, 0.16, 0.21)
const METAL := Color(0.18, 0.24, 0.29)
const CYAN := Color(0.13, 0.83, 0.91)
const AMBER := Color(1.0, 0.53, 0.22)
const RED := Color(0.95, 0.20, 0.25)
const WHITE := Color(0.91, 0.96, 0.98)
const DIM := Color(0.58, 0.7, 0.78)

const COPY := {
    "ru": {
        "subtitle": "BLACKOUT  /  ГЛАВА 00",
        "intro": "СИГНАЛ БЕДСТВИЯ: СЕКТОР A7\n\nВ реакторном комплексе пропало питание. Люди заблокированы внутри. У вас две независимые линии питания, но три системы: охлаждение, жизнеобеспечение и аварийные двери.\n\nВыберите, чем пожертвовать на время, чтобы открыть путь к эвакуации.\n\nWASD — движение    SHIFT — бег\nМЫШЬ — обзор    E — действие\nL — язык    F — фонарь    ESC — пауза\nM — звук    V — плавная камера    G — графика\n\nЭто вымышленная игра, не инструкция по эксплуатации оборудования.",
        "start": "НАЧАТЬ ОПЕРАЦИЮ", "resume": "ПРОДОЛЖИТЬ", "restart": "ПОВТОРИТЬ",
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
        "intro": "DISTRESS SIGNAL: SECTOR A7\n\nPower has failed across the reactor complex. Your crew is trapped. You have two independent power buses but three systems: cooling, life support and emergency doors.\n\nChoose what to deprioritize briefly to unlock the evacuation path.\n\nWASD — move    SHIFT — sprint\nMOUSE — look    E — interact\nL — language    F — flashlight    ESC — pause\nM — audio    V — reduced motion    G — graphics\n\nFictional game only. Not real equipment instructions.",
        "start": "BEGIN OPERATION", "resume": "RESUME", "restart": "RESTART",
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
var art_stage: IPCinematicStage
var audio_director: IPSoundscape
var legacy_lamps: Array[OmniLight3D] = []
var reduced_motion: bool = false
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
var hud_root: Control
var brand_label: Label
var subtitle_label: Label
var guidance_label: Label
var side_panel: PanelContainer
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

func _ready() -> void:
    session.reset()
    _make_environment()
    _make_complex()
    audio_director = IPSoundscape.new()
    add_child(audio_director)
    _make_player()
    _make_hud()
    _attach_web_state()
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
    state["touch_controls_visible"] = touch_ui.visible
    state["intro_visible"] = intro_panel.visible
    state["end_visible"] = end_panel.visible
    state["quality_mode"] = quality_mode
    state["reduced_motion"] = reduced_motion
    state["audio_muted"] = muted_audio
    state["soundscape_ready"] = audio_director != null and audio_director.ambient != null
    state["cinematic_details"] = art_stage.readout() if art_stage != null else {}
    state["vitals_visible"] = vitals_panel.visible if vitals_panel != null else false
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

func _copy(key: String) -> String:
    return str(COPY[locale].get(key, key))

func _metal(c: Color, metalness: float = 0.8, emissive: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = c
    mat.metallic = metalness
    mat.roughness = 0.31
    if emissive:
        mat.emission_enabled = true
        mat.emission = c
        mat.emission_energy_multiplier = 2.6
    return mat

func _make_environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = NIGHT
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.17, 0.26, 0.39)
    env.ambient_light_energy = 0.37
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    var key := DirectionalLight3D.new()
    key.rotation_degrees = Vector3(-50.0, 24.0, -10.0)
    key.light_color = Color(0.22, 0.42, 0.63)
    key.light_energy = 0.5
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
    var concrete := _metal(Color(0.045,0.075,0.11),0.36)
    var steel := _metal(STEEL)
    var polished := _metal(METAL)
    var amber := _metal(AMBER,0.18,true)
    var cyan := _metal(CYAN,0.12,true)
    var red := _metal(RED,0.12,true)
    _box(self,Vector3(0,-0.48,-28.0),Vector3(14,0.95,74),concrete,true)
    _box(self,Vector3(0,6.2,-28.0),Vector3(14,0.55,74),steel,true)
    _box(self,Vector3(-7.0,2.8,-28.0),Vector3(0.70,6.3,74),steel,true)
    _box(self,Vector3(7.0,2.8,-28.0),Vector3(0.70,6.3,74),steel,true)
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
        lamp.light_energy = 1.35
        lamp.omni_range = 12.0
        lamp.shadow_enabled = false
        add_child(lamp)
        legacy_lamps.append(lamp)
    for index in 9:
        var z := -3.5 - float(index)*7.0
        _box(self,Vector3(-6.2,2.7,z),Vector3(0.20,4.8,0.34),polished)
        _box(self,Vector3(6.2,2.7,z),Vector3(0.20,4.8,0.34),polished)
        _box(self,Vector3(0,5.1,z),Vector3(13,0.23,0.22),polished)
        _box(self,Vector3(-6.1,2.7,z+0.5),Vector3(0.09,0.85,0.14),red)
        _box(self,Vector3(6.1,2.7,z+0.5),Vector3(0.09,0.85,0.14),red)
    _build_reactor()
    _build_terminals()
    _build_bulkhead()
    art_stage = IPCinematicStage.new()
    add_child(art_stage)
    _terminal_active_material = _metal(Color(0.20,0.95,0.72),0.12,true)
    _terminal_idle_material = _metal(Color(0.08,0.32,0.39),0.12,true)

func _build_reactor() -> void:
    var frame := Node3D.new()
    frame.position = Vector3(0,3.0,-20.5)
    add_child(frame)
    _box(frame,Vector3(0,-2.3,0),Vector3(5.0,0.6,4.6),_metal(METAL))
    var core_mesh := SphereMesh.new()
    core_mesh.radius = 1.02
    core_mesh.height = 2.04
    reactor_core = MeshInstance3D.new()
    reactor_core.mesh = core_mesh
    reactor_core.material_override = _metal(Color(0.24,0.79,1.0),0.1,true)
    frame.add_child(reactor_core)
    for i in 3:
        var pivot := Node3D.new()
        pivot.rotation_degrees = Vector3(25.0*float(i),-22.0*float(i),45.0*float(i))
        frame.add_child(pivot)
        var ring := MeshInstance3D.new()
        var torus := TorusMesh.new()
        torus.inner_radius = 1.65 + float(i)*0.44
        torus.outer_radius = 1.78 + float(i)*0.44
        torus.rings = 32
        torus.ring_segments = 12
        ring.mesh = torus
        ring.material_override = _metal(AMBER if i==1 else CYAN,0.35,true)
        ring.rotation_degrees.x = 90.0
        pivot.add_child(ring)
        reactor_rings.append(pivot)
    for i in 6:
        var angle: float = TAU * float(i) / 6.0
        var p := Vector3(cos(angle)*3.0, sin(angle)*2.0, 0)
        _box(frame,p,Vector3(0.35,0.3,0.55),_metal(METAL))
    var halo := OmniLight3D.new()
    halo.light_color = Color(0.11,0.7,0.9)
    halo.light_energy = 3.5
    halo.omni_range = 9.0
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
    style.border_color = Color(0.25,0.53,0.61,0.75)
    style.set_border_width_all(1)
    style.set_corner_radius_all(7)
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
    var head := _panel(hud_root,Rect2(17,14,-17,91),Rect2(0,0,1,0),Color(0.018,0.036,0.066,0.88))
    var col := VBoxContainer.new()
    col.add_theme_constant_override("separation",1)
    head.add_child(col)
    brand_label = _label(col,"IRON PULSE",29,CYAN)
    subtitle_label = _label(col,_copy("subtitle"),12,AMBER)
    objective_label = _label(col,"",17,WHITE)
    guidance_label = _label(col,"",12,AMBER)
    var side := _panel(hud_root,Rect2(17,113,370,255),Rect2(0,0,0,0),Color(0.014,0.026,0.05,0.88))
    side_panel = side
    var metrics := VBoxContainer.new()
    side.add_child(metrics)
    telemetry_label = _label(metrics,"",15,WHITE)
    allocation_label = _label(metrics,"",16,CYAN)
    vitals_panel = _panel(hud_root,Rect2(-357,113,-17,315),Rect2(1,0,1,0),Color(0.014,0.026,0.05,0.88))
    var vitals := VBoxContainer.new()
    vitals.add_theme_constant_override("separation",4)
    vitals_panel.add_child(vitals)
    _label(vitals,"A7 / SYSTEM TELEMETRY",15,AMBER)
    _make_vital_meter(vitals,"heat","01  /  REACTOR TEMP",RED)
    _make_vital_meter(vitals,"oxygen","02  /  LIFE SUPPORT",CYAN)
    _make_vital_meter(vitals,"crew","03  /  CREW CONDITION",Color(0.26,0.87,0.62))
    _make_vital_meter(vitals,"door","04  /  BULKHEAD CAPACITOR",Color(0.97,0.67,0.27))
    var lower := _panel(hud_root,Rect2(17,-133,-17,-71),Rect2(0,1,1,1),Color(0.015,0.035,0.061,0.82))
    var lower_col := VBoxContainer.new()
    lower.add_child(lower_col)
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
    intro_panel = _panel(hud_root,Rect2(-310,-220,310,220),Rect2(0.5,0.5,0.5,0.5),Color(0.012,0.029,0.055,0.98))
    intro_panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var start_box := VBoxContainer.new()
    start_box.add_theme_constant_override("separation",16)
    intro_panel.add_child(start_box)
    intro_title = _label(start_box,"IRON PULSE / BLACKOUT",29,CYAN)
    var intro_scroll := ScrollContainer.new()
    intro_scroll.name = "BriefingScroll"
    intro_scroll.custom_minimum_size = Vector2(0,244)
    intro_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    start_box.add_child(intro_scroll)
    intro_body = _label(intro_scroll,_copy("intro"),15,WHITE)
    intro_body.custom_minimum_size.x = 500.0
    intro_button = Button.new()
    intro_button.text = _copy("start")
    intro_button.custom_minimum_size = Vector2(0,50)
    intro_button.pressed.connect(start_run)
    start_box.add_child(intro_button)
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
    btn.add_theme_font_size_override("font_size",20)
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
    _touch_button(touch_ui,"↑",66,-242,55,"forward")
    _touch_button(touch_ui,"←",6,-186,55,"left")
    _touch_button(touch_ui,"↓",66,-186,55,"back")
    _touch_button(touch_ui,"→",126,-186,55,"right")
    var use := _touch_button(touch_ui,"USE / E",216,-186,94)
    use.pressed.connect(_interact)
    var look := _touch_button(touch_ui,"L / RU-EN",216,-242,94)
    look.pressed.connect(_toggle_language)

func _layout_hud() -> void:
    if hud_root == null:
        return
    var width: float = get_viewport().get_visible_rect().size.x
    var narrow: bool = width < 650.0
    touch_ui.visible = width < 850.0 or DisplayServer.is_touchscreen_available()
    vitals_panel.visible = not narrow
    subtitle_label.visible = not narrow
    # Default small screens to an intentionally lighter renderer profile.
    if narrow and quality_mode == "hero" and art_stage != null:
        quality_mode = "eco"
        art_stage.set_quality("eco")
        for i in range(legacy_lamps.size()):
            legacy_lamps[i].visible = i % 3 == 0
    side_panel.offset_right = minf(370.0,width-22.0)
    side_panel.offset_bottom = 247.0 if narrow else 255.0
    intro_body.custom_minimum_size.x = minf(500.0,width-66.0)
    intro_title.add_theme_font_size_override("font_size",20 if narrow else 29)
    intro_body.add_theme_font_size_override("font_size",13 if narrow else 15)
    brand_label.add_theme_font_size_override("font_size",20 if narrow else 29)
    objective_label.add_theme_font_size_override("font_size",15 if narrow else 17)
    guidance_label.add_theme_font_size_override("font_size",11 if narrow else 12)
    telemetry_label.add_theme_font_size_override("font_size",13 if narrow else 15)
    allocation_label.add_theme_font_size_override("font_size",12 if narrow else 16)
    interaction_label.add_theme_font_size_override("font_size",12 if narrow else 17)
    feedback_label.add_theme_font_size_override("font_size",12 if narrow else 15)
    footer_label.add_theme_font_size_override("font_size",9 if narrow else 11)
    intro_panel.offset_left = -minf(310.0,width*0.45)
    intro_panel.offset_right = minf(310.0,width*0.45)
    end_panel.offset_left = -minf(300.0,width*0.45)
    end_panel.offset_right = minf(300.0,width*0.45)
    if narrow:
        # The mobile HUD deliberately leaves the center unobstructed.
        objective_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

func start_run() -> void:
    started = true
    paused = false
    intro_panel.visible = false
    pause_panel.visible = false
    end_panel.visible = false
    _announce("shift_started")
    audio_director.set_active(true)
    if DisplayServer.get_name() != "headless":
        Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)

func _restart() -> void:
    session.reset()
    player.position = Vector3(0,1.1,2.0)
    player.velocity = Vector3.ZERO
    exit_gate.position = Vector3(0,2.6,-58.9)
    walking_phase = 0.0
    camera.position = Vector3(0,0.62,0)
    yaw = 0.0
    pitch = 0.0
    player.rotation.y = 0.0
    camera.rotation.x = 0.0
    started = true
    paused = false
    end_panel.visible = false
    _announce("shift_started")
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
    pause_title.text = _copy("pause")
    resume_button.text = _copy("resume")
    end_button.text = _copy("restart")
    footer_label.text = _copy("footer")
    _announce("language")
    _refresh_hud()

func _input(event: InputEvent) -> void:
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
            for i in range(legacy_lamps.size()):
                legacy_lamps[i].visible = quality_mode == "hero" or i % 3 == 0
            _announce("quality_eco" if quality_mode == "eco" else "quality_hero")
            return
        if event.keycode == KEY_ESCAPE:
            _pause_toggle()
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
        if event.keycode == KEY_E:
            _interact()
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
    horizontal += float(touch_moves["right"]) - float(touch_moves["left"])
    vertical += float(touch_moves["back"]) - float(touch_moves["forward"])
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
            _announce(session.last_event)
    if session.finished():
        _show_end()

func _process(delta: float) -> void:
    runtime_seconds += delta
    if started and not paused and not session.finished():
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

func _interact() -> void:
    if not started or paused or session.finished():
        return
    var target: Dictionary = _nearest_terminal()
    if target.is_empty():
        return
    var terminal_id: String = str(target["id"])
    match terminal_id:
        "scan":
            session.scan_core()
        "repair":
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
    _announce(session.last_event)
    if session.finished():
        _show_end()
    _refresh_hud()

func _announce(key: String) -> void:
    notice_key = key
    notice_time = 4.0
    if audio_director == null or not started:
        return
    match key:
        "surge", "reactor_overheat", "life_support_lost", "time_expired":
            audio_director.cue("surge")
        "crew_evacuated":
            audio_director.cue("victory")
        "action_denied":
            audio_director.cue("denied")
        "core_scanned", "coolant_repaired", "bus_switched", "override_authorized":
            audio_director.cue("confirm")

func _show_end() -> void:
    if end_panel.visible:
        return
    end_panel.visible = true
    end_title.text = _copy("victory") if session.won else _copy("failure")
    var template: String = _copy("stats")
    end_stats.text = template.format({"time":"%.0f" % session.elapsed,"switches":session.switches,"faults":session.faults,"grade":session.grade()})
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
    objective_label.text = _copy(objective_key)
    _update_guidance(objective_key)
    _update_terminal_highlights(objective_key)
    telemetry_label.text = "%s  %d°C    |    %s  %d%%\n%s  %d%%    |    %s  %d%%    |    %s  %02d:%02d" % [
        _copy("heat"),int(session.heat),_copy("oxygen"),int(session.oxygen),
        _copy("crew"),int(session.crew_health),_copy("door"),int(session.door_charge),
        _copy("time"),floori(session.time_left/60.0),int(session.time_left)%60]
    allocation_label.text = "%s  /  A: %s   |   B: %s" % [
        _copy("power"),session.bus_a.to_upper(),session.bus_b.to_upper()]
    (vitals_meters["heat"] as ProgressBar).value = session.heat
    (vitals_meters["oxygen"] as ProgressBar).value = session.oxygen
    (vitals_meters["crew"] as ProgressBar).value = session.crew_health
    (vitals_meters["door"] as ProgressBar).value = session.door_charge
    var nearby: Dictionary = _nearest_terminal()
    if not nearby.is_empty() and started and not session.finished():
        var at: Vector3 = nearby["position"]
        var dist: float = Vector2(at.x,at.z).distance_to(Vector2(player.global_position.x,player.global_position.z))
        interaction_label.text = _copy("hint").format({"name":_copy(str(nearby["key"])),"distance":"%.1f" % dist})
    else:
        interaction_label.text = _copy("action") if started and not session.finished() else ""
    feedback_label.text = _copy(notice_key) if notice_time > 0.0 else ""
    if session.heat >= 80.0 or session.oxygen < 30.0:
        telemetry_label.add_theme_color_override("font_color",RED)
    else:
        telemetry_label.add_theme_color_override("font_color",WHITE)
    # Keep operator telemetry visible in both RU and EN without font dependence.
    brand_label.text = "IRON PULSE"
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
    var arrow: String = "↑" if dot_value > 0.6 else "↓" if dot_value < -0.6 else "←" if turn > 0.0 else "→"
    guidance_label.text = _copy("navigate").format({"arrow":arrow,"distance":"%.0f" % distance,"node":target_name})

func _update_terminal_highlights(objective_key: String) -> void:
    for info in terminals:
        var key: String = str(info["id"])
        var active: bool = key == objective_key or (objective_key == "charge" and (key == "bus_a" or key == "bus_b"))
        var indicator: MeshInstance3D = info["indicator"]
        var material: StandardMaterial3D = _terminal_active_material if active else _terminal_idle_material
        if indicator.material_override != material:
            indicator.material_override = material
