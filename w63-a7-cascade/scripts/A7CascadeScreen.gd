extends Control
class_name A7CascadeScreen
## W63 standalone, genuinely interactive Godot game prototype.
## Purely fictional systems: no network, real machinery or physical advice.

const BG := Color("05080d")
const PANEL := Color("111923")
const BORDER := Color("344551")
const GOLD := Color("cbb58c")
const WHITE := Color("ebeee9")
const MUTED := Color("9aa9ad")
const MINT := Color("79d2c0")
const ORANGE := Color("eeb66e")
const RED := Color("eb786f")

const ORDER := ["heat", "pressure", "seal", "signal", "energy", "integrity"]
const ACTION_ORDER := ["PUMP", "VENT", "SEAL", "SCAN", "POWER"]
const RU := {
    "brand": "ПОСЛЕДНИЙ РУБЕЖ  /  A7",
    "sub": "ЭКСПЕРИМЕНТ: ПОСЛЕДНЯЯ СМЕНА",
    "intro": "Шесть аварийных циклов. В каждом только два решения. Спасая одну систему, вы меняете другие.",
    "disclaimer": "ТОЛЬКО ВЫМЫШЛЕННАЯ ИГРА. НЕ ИНСТРУКЦИЯ ДЛЯ РЕАЛЬНОГО ОБОРУДОВАНИЯ.",
    "round": "ЦИКЛ", "actions": "ОСТАЛОСЬ РЕШЕНИЙ",
    "heat": "ТЕПЛОВАЯ НАГРУЗКА", "pressure": "ДАВЛЕНИЕ",
    "seal": "ГЕРМЕТИЧНОСТЬ", "signal": "ТОЧНОСТЬ СИГНАЛА",
    "energy": "ЗАПАС ЭНЕРГИИ", "integrity": "ЦЕЛОСТНОСТЬ",
    "PUMP": "01 / НАСОС", "VENT": "02 / СБРОС",
    "SEAL": "03 / УКРЕПИТЬ", "SCAN": "04 / ДИАГНОСТИКА", "POWER": "05 / ПИТАНИЕ",
    "PUMP_d": "-20 тепло  +8 давление  -6 энергия",
    "VENT_d": "-23 давление  -5 герметичность",
    "SEAL_d": "+24 герметичность  -7 энергия",
    "SCAN_d": "+22 сигнал  +5 тепло",
    "POWER_d": "+28 энергия  +4 давление",
    "reset": "НАЧАТЬ ЗАНОВО", "language": "EN",
    "begin": "Связь с узлом A7 потеряна. Ваша смена начинается.",
    "incident": "Система изменила параметры после вашего решения.",
    "damage": "Последствия: целостность объекта снизилась.",
    "failed": "ПОТЕРЯ КОНТРОЛЯ. Пересмотрите последовательность.",
    "unstable": "ШЕСТЬ ЦИКЛОВ ПРОЙДЕНО, НО УЗЕЛ НЕ СТАБИЛИЗИРОВАН.",
    "won": "A7 СТАБИЛИЗИРОВАН. Вы удержали систему.",
    "keys": "1-5: ДЕЙСТВИЯ  |  C: КАМЕРА  |  Q: КАЧЕСТВО  |  M: АНИМАЦИЯ  |  L: ЯЗЫК  |  S: ЗВУК  |  R: ПЕРЕЗАПУСК",
    "objective": "ЦЕЛЬ: ТЕПЛО И ДАВЛЕНИЕ <= 75; ГЕРМЕТИЧНОСТЬ И СИГНАЛ >= 50; ЭНЕРГИЯ >= 30; ЦЕЛОСТНОСТЬ >= 55.",
    "stage": "A7 / ЖИВАЯ 3D-КАМЕРА  •  ВЫМЫШЛЕННЫЙ ОБЪЕКТ",
    "camera0": "01 / ОБЩИЙ", "camera1": "02 / ФРОНТ", "camera2": "03 / БОКОВОЙ",
    "quality_hero": "ГРАФИКА / HERO", "quality_eco": "ГРАФИКА / ECO",
    "motion_on": "АНИМАЦИЯ / ВКЛ", "motion_off": "АНИМАЦИЯ / ВЫКЛ",
    "visual": "ТЕПЛО %d   •   ДАВЛЕНИЕ %d   •   ЭНЕРГИЯ %d",
    "area_core": "СЕКТОР 01 / РЕАКТОР",
    "area_relay": "СЕКТОР 02 / РЕЛЕЙНЫЙ ЗАЛ",
    "guide_prev": "НАЗАД",
    "guide_next": "ВПЕРЁД",
    "tour_status": "ПУТЬ ОПЕРАТОРА %d%%  •  W/A — ДВИЖЕНИЕ, N — ПЕРЕХОД",
    "sound_on": "ЗВУК / ВКЛ", "sound_off": "ЗВУК / ВЫКЛ",
    "cinema_on": "КИНОРЕЖИМ / ВКЛ", "cinema_off": "КИНОРЕЖИМ / ВЫКЛ",
    "focus_on": "ОПТИКА / ПРИБЛИЗИТЬ", "focus_off": "ОПТИКА / ОБЩИЙ ВИД",
    "pilot_on": "ПЕРВОЕ ЛИЦО / ВОЙТИ", "pilot_off": "ПЕРВОЕ ЛИЦО / ВЫЙТИ",
    "pilot_hint": "P — ОПЕРАТОР, WASD — ХОДЬБА, ПРАВАЯ КНОПКА МЫШИ — ВЗГЛЯД, E — ОСМОТР",
    "pilot_inspect": "ОСМОТРЕТЬ / E",
    "pilot_forward": "ВПЕРЁД", "pilot_left": "ВЛЕВО",
    "pilot_back": "НАЗАД", "pilot_right": "ВПРАВО",
    "pilot_core": "ОСМОТРЕН РЕАКТОР",
    "pilot_relay": "ОСМОТРЕН РЕЛЕЙНЫЙ КОМПЛЕКС",
    "pilot_far": "ПОДОЙДИТЕ БЛИЖЕ К ОБОРУДОВАНИЮ",
    "mission_start": "НАЧАТЬ ПРОСТРАНСТВЕННУЮ МИССИЮ / T",
    "mission_active": "МИССИЯ A7 / АКТИВНА",
    "mission_wait": "МИССИЯ ДОСТУПНА ТОЛЬКО В НАЧАЛЕ НОВОЙ СМЕНЫ",
    "mission_proximity": "ФИЗИЧЕСКИЙ ОСМОТР: ТОЛЬКО В РЕЖИМЕ ОПЕРАТОРА",
    "field_start": "ПОЛЕВАЯ МИССИЯ / Y",
    "field_mode": "РЕЖИМ: ПОЛЕВЫЕ ОПЕРАЦИИ",
    "field_valve_minus": "J  /  ← КЛАПАН",
    "field_valve_plus": "K  /  КЛАПАН →",
    "field_relay_a": "7  /  КОНТУР А",
    "field_relay_b": "8  /  КОНТУР Б",
    "field_relay_c": "9  /  КОНТУР В",
    "field_sync_a": "U  /  ИМПУЛЬС 1",
    "field_sync_b": "I  /  ИМПУЛЬС 2",
    "field_sync_c": "O  /  ИМПУЛЬС 3",
    "field_far": "ПОДОЙДИТЕ К АКТИВНОМУ ПУЛЬТУ И ВКЛЮЧИТЕ РЕЖИМ ОПЕРАТОРА (P).",
    "field_gate": "ЗАВЕРШИТЕ НАСТРОЙКУ ПУЛЬТА ПЕРЕД ОСМОТРОМ (E).",
    "world_use": "G / ПРИМЕНИТЬ ИНСТРУМЕНТ",
    "world_aim": "НАВЕДИТЕ ПРИЦЕЛ НА НАСТОЯЩИЙ УЗЕЛ",
    "save_game": "СОХРАНИТЬ СМЕНУ / F5",
    "load_game": "ВОССТАНОВИТЬ / F9",
    "save_done": "СМЕНА СОХРАНЕНА ЛОКАЛЬНО",
    "load_done": "СМЕНА ВОССТАНОВЛЕНА ПО ПРОВЕРЕННЫМ СОБЫТИЯМ",
    "save_fail": "НЕ УДАЛОСЬ СОХРАНИТЬ",
    "load_fail": "ФАЙЛ ПОВРЕЖДЕН ИЛИ СОБЫТИЯ НЕ ПРОХОДЯТ ПРОВЕРКУ",
    "fps_label": "F3 / МОНИТОР КАДРОВ",
    "w76_play": "ИГРАТЬ СЕЙЧАС / ENTER",
    "w76_focus_on": "КИНОИГРА / TAB",
    "w76_focus_off": "ПОКАЗАТЬ ПАНЕЛИ / TAB",
    "preview_default": "ВЫБЕРИТЕ ДЕЙСТВИЕ: ПОСЛЕДСТВИЯ ПОКАЗАНЫ В ИГРОВЫХ ЕДИНИЦАХ.",
}
const EN := {
    "brand": "LAST FRONTIER  /  A7",
    "sub": "EXPERIMENTAL MODE: THE LAST SHIFT",
    "intro": "Six incident cycles. Only two decisions each. Fixing one system changes the others.",
    "disclaimer": "FICTIONAL GAME ONLY. NOT INSTRUCTIONS FOR REAL INDUSTRIAL EQUIPMENT.",
    "round": "CYCLE", "actions": "DECISIONS LEFT",
    "heat": "THERMAL LOAD", "pressure": "PRESSURE",
    "seal": "SEAL INTEGRITY", "signal": "SIGNAL ACCURACY",
    "energy": "ENERGY RESERVE", "integrity": "CONTAINMENT",
    "PUMP": "01 / PUMP", "VENT": "02 / VENT",
    "SEAL": "03 / RESEAL", "SCAN": "04 / DIAGNOSE", "POWER": "05 / RECHARGE",
    "PUMP_d": "-20 heat  +8 pressure  -6 energy",
    "VENT_d": "-23 pressure  -5 seal",
    "SEAL_d": "+24 seal  -7 energy",
    "SCAN_d": "+22 signal  +5 heat",
    "POWER_d": "+28 energy  +4 pressure",
    "reset": "RESTART SHIFT", "language": "RU",
    "begin": "Contact with A7 has been lost. Your shift begins.",
    "incident": "The environment changed after your decisions.",
    "damage": "System damage: containment integrity decreased.",
    "failed": "CONTAINMENT LOST. Reconsider your sequence.",
    "unstable": "SIX CYCLES SURVIVED, BUT THE SYSTEM IS UNSTABLE.",
    "won": "A7 STABILIZED. You held the frontier.",
    "keys": "1-5: ACTIONS  |  C: CAMERA  |  Q: QUALITY  |  M: MOTION  |  L: LANGUAGE  |  S: SOUND  |  R: RESTART",
    "objective": "TARGET: HEAT AND PRESSURE <= 75; SEAL AND SIGNAL >= 50; ENERGY >= 30; CONTAINMENT >= 55.",
    "stage": "A7 / TRUE NATIVE 3D VIEW  •  FICTIONAL FACILITY",
    "camera0": "01 / WIDE", "camera1": "02 / FRONT", "camera2": "03 / SIDE",
    "quality_hero": "QUALITY / HERO", "quality_eco": "QUALITY / ECO",
    "motion_on": "MOTION / ON", "motion_off": "MOTION / OFF",
    "visual": "HEAT %d   •   PRESSURE %d   •   ENERGY %d",
    "area_core": "SECTOR 01 / REACTOR",
    "area_relay": "SECTOR 02 / RELAY HALL",
    "guide_prev": "BACK",
    "guide_next": "FORWARD",
    "tour_status": "GUIDED INSPECTION %d%%  •  W/A MOVE, N SWITCH SECTOR",
    "sound_on": "SOUND / ON", "sound_off": "SOUND / OFF",
    "cinema_on": "CINEMA VIEW / ON", "cinema_off": "CINEMA VIEW / OFF",
    "focus_on": "OPTICS / ZOOM IN", "focus_off": "OPTICS / WIDE VIEW",
    "pilot_on": "FIRST PERSON / ENTER", "pilot_off": "FIRST PERSON / EXIT",
    "pilot_hint": "P — OPERATOR, WASD — WALK, RIGHT MOUSE — LOOK, E — INSPECT",
    "pilot_inspect": "INSPECT / E",
    "pilot_forward": "FORWARD", "pilot_left": "LEFT",
    "pilot_back": "BACK", "pilot_right": "RIGHT",
    "pilot_core": "REACTOR INSPECTED",
    "pilot_relay": "POWER RELAY INSPECTED",
    "pilot_far": "MOVE CLOSER TO THE MACHINERY",
    "mission_start": "START SPATIAL MISSION / T",
    "mission_active": "MISSION A7 / ACTIVE",
    "mission_wait": "MISSION AVAILABLE ONLY BEFORE THE FIRST SHIFT DECISION",
    "mission_proximity": "PHYSICAL INSPECTION: ENTER FIRST PERSON MODE",
    "field_start": "FIELD OPERATIONS / Y",
    "field_mode": "MODE: THREE PHYSICAL STATION PUZZLES",
    "field_valve_minus": "J  /  ← VALVE",
    "field_valve_plus": "K  /  VALVE →",
    "field_relay_a": "7  /  BUS A",
    "field_relay_b": "8  /  BUS B",
    "field_relay_c": "9  /  BUS C",
    "field_sync_a": "U  /  PULSE 1",
    "field_sync_b": "I  /  PULSE 2",
    "field_sync_c": "O  /  PULSE 3",
    "field_far": "MOVE NEAR THE ACTIVE CONSOLE AND ENTER OPERATOR MODE (P).",
    "field_gate": "COMPLETE THE STATION MECHANIC BEFORE INSPECTION (E).",
    "world_use": "G / USE WORLD TOOL",
    "world_aim": "AIM DIRECTLY AT THE REAL MACHINE",
    "save_game": "SAVE SHIFT / F5",
    "load_game": "RESTORE SESSION / F9",
    "save_done": "SHIFT SAVED LOCALLY",
    "load_done": "SESSION RESTORED FROM VALIDATED REAL ACTIONS",
    "save_fail": "LOCAL SAVE FAILED",
    "load_fail": "CORRUPT FILE OR INVALID SESSION JOURNAL",
    "fps_label": "F3 / FRAME DIAGNOSTICS",
    "w76_play": "PLAY NOW / ENTER",
    "w76_focus_on": "IMMERSIVE GAME / TAB",
    "w76_focus_off": "SHOW CONTROLS / TAB",
    "preview_default": "CHOOSE AN ACTION: FORECASTS ARE FICTIONAL GAME UNITS.",
}

var model: A7CascadeCore = A7CascadeCore.new()
var checkpoint: A7SessionCheckpoint = A7SessionCheckpoint.new()
var gamepad: A7GamepadDirector = A7GamepadDirector.new()
var frame_telemetry: A7FrameTelemetry = A7FrameTelemetry.new()
var controller_hint_label: Label
var diagnostic_label: Label
var show_diagnostics: bool = false
var diagnostic_elapsed: float = 0.0
var save_button: Button
var load_button: Button
var checkpoint_status_label: Label
var locale: String = "ru"
var brand_label: Label
var subtitle: Label
var intro: Label
var cycle_label: Label
var actions_label: Label
var event_label: Label
var objective_label: Label
var footnote: Label
var round_pips: Array[ColorRect] = []
var metric_labels: Dictionary = {}
var metric_bars: Dictionary = {}
var action_buttons: Dictionary = {}
var restart_button: Button
var language_button: Button
# W64: actual Godot 3D visual stage; never replaces original W63 decision model.
var stage_shell: Control
var visual_container: SubViewportContainer
var sub_viewport: SubViewport
var stage_3d: A7CinematicStage
var cinematic_hud: A7CinematicHud
var sector_buttons: Array[Button] = []
var route_buttons: Array[Button] = []
var route_label: Label
var cinema_caption: Label
var cinema_readout: Label
var camera_buttons: Array[Button] = []
var quality_button: Button
var motion_button: Button
var quality: String = "hero"
var reduced_motion: bool = false
var w77_operator_focus_tween: Tween
var w77_focus_cancelled_by_actual_input: int = 0
var w76_immersive: bool = false
var w76_immersive_switches: int = 0
var top_rail: HFlowContainer
var w78_touch_overlay: A7TouchFieldControls
var w79_mission_deck: A7MobileMissionDeck
var w80_full_bleed: A7FullBleedViewport
var w82_nav_cockpit: A7MissionNavCockpit
var w83_dual_touch: A7DualTouchLook
var w76_play_button: Button
var w76_focus_button: Button
var w76_objective_label: Label
var w76_hidden_sections: Array[Control] = []
var scroll: ScrollContainer
var _web_state_element: Variant = null
# W65 new standalone narrative and original procedural sound (no external files).
var sound_bus: A7ProceduralAudio
var sound_button: Button
var focus_button: Button
var cinema_button: Button
var cinema_mode: bool = false
var pilot_button: Button
var mission_button: Button
var field_start_button: Button
var field_label: Label
var field_help: Label
var field_valve_controls: HFlowContainer
var field_relay_controls: HFlowContainer
var field_sync_controls: HFlowContainer
var field_buttons: Dictionary = {}
var world_use_button: Button
var world_reticle: Label
var world_aim_hint: Label
var world_aim_elapsed: float = 0.0
var field_focused_devices: Dictionary = {}
var field_focus_events: int = 0
var mission_title: Label
var mission_briefing: Label
var mission_meta: Label
var mission_pips: Array[ColorRect] = []
var pilot_rail: HFlowContainer
var pilot_nudge_buttons: Dictionary = {}
var pilot_inspect_button: Button
var pilot_status_label: Label
var _pilot_browser_elapsed: float = 0.0
var narrative_title: Label
var narrative_body: Label
var forecast_label: Label
var _previewed_action: String = ""

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build()
    # W80 mounts a REAL top-level original Godot viewport host.
    # Only the same existing live stage is reparented upon opt-in.
    w80_full_bleed = A7FullBleedViewport.new()
    add_child(w80_full_bleed)
    w80_full_bleed.build(stage_shell)
    # W81 accessible physical fullscreen MENU and language controls.
    w80_full_bleed.exit_button.custom_minimum_size.y = 44.0
    w80_full_bleed.language_button.custom_minimum_size.y = 44.0
    w80_full_bleed.exit_requested.connect(_w76_toggle_immersive)
    w80_full_bleed.language_requested.connect(_toggle_locale)
    # W83 uses source InputEventScreenTouch + ScreenDrag, preserving
    # W78 actual held physical movement and W79 source-gated controls.
    w83_dual_touch = A7DualTouchLook.new()
    stage_shell.add_child(w83_dual_touch)
    w83_dual_touch.build(stage_shell,stage_3d.first_person,
        w78_touch_overlay,w79_mission_deck,w82_nav_cockpit,w80_full_bleed)
    w83_dual_touch.real_camera_drag_started.connect(
        _w77_cancel_guided_camera_on_manual_input)
    sound_bus = A7ProceduralAudio.new()
    add_child(sound_bus)
    _create_web_accessibility()
    model.changed.connect(_render)
    resized.connect(_layout_stage)
    call_deferred("_layout_stage")
    _render(model.snapshot())

func _t(key: String) -> String:
    var dict: Dictionary = RU if locale == "ru" else EN
    return str(dict.get(key, key))

func _style_panel() -> StyleBoxFlat:
    var skin := StyleBoxFlat.new()
    # W68: machined inset consoles, not generic rounded web cards.
    skin.bg_color = Color("101b27")
    skin.border_color = Color("344553")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(5)
    skin.set_content_margin_all(18)
    return skin

func _label(parent: Container, value: String, size: int, tone: Color) -> Label:
    var l := Label.new()
    l.text = value
    l.add_theme_color_override("font_color", tone)
    l.add_theme_font_size_override("font_size", size)
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(l)
    return l

func _panel(parent: Container) -> VBoxContainer:
    var panel := PanelContainer.new()
    panel.add_theme_stylebox_override("panel", _style_panel())
    panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(panel)
    var inner := VBoxContainer.new()
    inner.add_theme_constant_override("separation", 12)
    panel.add_child(inner)
    return inner

func _button(parent: Container, caption: String, handler: Callable) -> Button:
    var b := Button.new()
    b.text = caption
    b.custom_minimum_size = Vector2(180, 50)
    b.focus_mode = Control.FOCUS_ALL
    b.add_theme_font_size_override("font_size", 13)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("182533")
    normal.border_color = Color("394b5a")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(4)
    normal.set_content_margin_all(11)
    var hover := normal.duplicate() as StyleBoxFlat
    hover.bg_color = Color("2b3e4c")
    hover.border_color = GOLD
    var pressed := normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("36505b")
    pressed.border_color = MINT
    var disabled := normal.duplicate() as StyleBoxFlat
    disabled.bg_color = Color("121b25")
    disabled.border_color = Color("25333d")
    var focus := StyleBoxFlat.new()
    focus.bg_color = Color.TRANSPARENT
    focus.border_color = MINT
    focus.set_border_width_all(2)
    focus.set_corner_radius_all(4)
    b.add_theme_stylebox_override("normal", normal)
    b.add_theme_stylebox_override("hover", hover)
    b.add_theme_stylebox_override("pressed", pressed)
    b.add_theme_stylebox_override("disabled", disabled)
    b.add_theme_stylebox_override("focus", focus)
    b.add_theme_color_override("font_color", WHITE)
    b.add_theme_color_override("font_hover_color", GOLD)
    b.add_theme_color_override("font_pressed_color", MINT)
    b.add_theme_color_override("font_disabled_color", MUTED)
    b.pressed.connect(handler)
    parent.add_child(b)
    return b

func _build() -> void:
    var backdrop := ColorRect.new()
    backdrop.color = BG
    backdrop.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)
    scroll = ScrollContainer.new()
    scroll.name = "AdaptiveScrollableCascade"
    scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.follow_focus = true
    add_child(scroll)
    var margins := MarginContainer.new()
    margins.add_theme_constant_override("margin_left", 20)
    margins.add_theme_constant_override("margin_right", 20)
    margins.add_theme_constant_override("margin_top", 20)
    margins.add_theme_constant_override("margin_bottom", 30)
    margins.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(margins)
    var body := VBoxContainer.new()
    body.add_theme_constant_override("separation", 16)
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    margins.add_child(body)

    var top := HFlowContainer.new()
    top.add_theme_constant_override("h_separation", 12)
    top.add_theme_constant_override("v_separation", 8)
    body.add_child(top)
    top_rail = top
    brand_label = _label(top, "", 27, GOLD)
    language_button = _button(top, "EN", _toggle_locale)
    language_button.custom_minimum_size = Vector2(90, 45)
    w76_play_button = _button(top, "", _w76_play_now)
    w76_play_button.name = "W76PlayActualOriginal3DGameNow"
    w76_play_button.custom_minimum_size = Vector2(185,45)
    w76_focus_button = _button(top, "", _w76_toggle_immersive)
    w76_focus_button.name = "W76OptInSingleGoalFirstPersonExperience"
    w76_focus_button.custom_minimum_size = Vector2(220,45)
    # W65 inherits the tested W64 cinema-first composition:
    # place native 3D reactor before verbose story and instructions.
    # Cinema-first native 3D stage is mounted inside the *actual* Godot UI.
    # Not an HTML video, screenshot, Three.js overlay or mockup.
    var cinema := _panel(body)
    cinema.name = "A7CinematicViewportPanel"
    cinema_caption = _label(cinema, "", 12, GOLD)
    stage_shell = Control.new()
    stage_shell.name = "A7ActualCinemaFrame"
    stage_shell.custom_minimum_size = Vector2(0, 470)
    stage_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    cinema.add_child(stage_shell)
    visual_container = SubViewportContainer.new()
    visual_container.name = "A7RealGodot3DViewport"
    visual_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visual_container.stretch = true
    visual_container.stretch_shrink = 1
    visual_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
    stage_shell.add_child(visual_container)
    # Actual Godot controls on top of the live SubViewport, not a 2D proxy
    # for machine-selection. The hit comes exclusively from a physics ray.
    world_reticle = Label.new()
    world_reticle.name = "W73RealGodot3DCrosshair"
    world_reticle.text = "+"
    world_reticle.add_theme_font_size_override("font_size",26)
    world_reticle.add_theme_color_override("font_color", MINT)
    world_reticle.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_reticle.anchor_left = 0.5
    world_reticle.anchor_right = 0.5
    world_reticle.anchor_top = 0.5
    world_reticle.anchor_bottom = 0.5
    world_reticle.offset_left = -8
    world_reticle.offset_right = 14
    world_reticle.offset_top = -17
    world_reticle.offset_bottom = 17
    world_reticle.visible = false
    stage_shell.add_child(world_reticle)
    world_aim_hint = Label.new()
    world_aim_hint.name = "W73SingleLowLoadNativeWorldRaycastHint"
    world_aim_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    world_aim_hint.add_theme_font_size_override("font_size",13)
    world_aim_hint.add_theme_color_override("font_color", GOLD)
    world_aim_hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    world_aim_hint.anchor_left = 0.08
    world_aim_hint.anchor_right = 0.92
    world_aim_hint.anchor_top = 1.0
    world_aim_hint.anchor_bottom = 1.0
    world_aim_hint.offset_top = -40
    world_aim_hint.offset_bottom = -10
    world_aim_hint.visible = false
    stage_shell.add_child(world_aim_hint)
    sub_viewport = SubViewport.new()
    sub_viewport.name = "A7WorldRender"
    sub_viewport.own_world_3d = true
    sub_viewport.size = Vector2i(1280, 720)
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    visual_container.add_child(sub_viewport)
    stage_3d = A7CinematicStage.new()
    sub_viewport.add_child(stage_3d)
    cinematic_hud = A7CinematicHud.new()
    cinematic_hud.name = "ObsidianAuroraLiveHUD"
    stage_shell.add_child(cinematic_hud)
    w78_touch_overlay = A7TouchFieldControls.new()
    stage_shell.add_child(w78_touch_overlay)
    w78_touch_overlay.build(stage_3d.first_person)
    w78_touch_overlay.world_tool_requested.connect(_world_use)
    w78_touch_overlay.physical_inspection_requested.connect(_pilot_inspect)
    w78_touch_overlay.actual_manual_motion_started.connect(
        _w77_cancel_guided_camera_on_manual_input)
    w79_mission_deck = A7MobileMissionDeck.new()
    stage_shell.add_child(w79_mission_deck)
    w79_mission_deck.build(stage_3d.spatial_mission,
        stage_3d.field_operations,stage_3d.first_person)
    # W79 always invokes the already-tested original game/UI handlers;
    # it has no authority to choose A7 actions or bypass physical distance.
    w79_mission_deck.valve_requested.connect(_field_valve)
    w79_mission_deck.relay_requested.connect(_field_relay)
    w79_mission_deck.sync_requested.connect(_field_sync)
    w79_mission_deck.original_action_requested.connect(_on_action)
    w79_mission_deck.save_requested.connect(_save_checkpoint)
    w79_mission_deck.load_requested.connect(_load_checkpoint)
    w79_mission_deck.restart_requested.connect(_restart)
    # W82: new real source-only navigation in actual same full-bleed game.
    # It receives no action signals and cannot override game state or physics.
    w82_nav_cockpit = A7MissionNavCockpit.new()
    stage_shell.add_child(w82_nav_cockpit)
    w82_nav_cockpit.build(stage_3d.spatial_mission,
        stage_3d.field_operations,stage_3d.first_person,
        stage_3d.mission_wayfinder)
    cinema_readout = _label(cinema, "", 12, MINT)
    w76_objective_label = _label(cinema, "", 15, GOLD)
    w76_objective_label.name = "W76ActualMissionGoalAndPhysicalDistance"
    diagnostic_label = _label(cinema, "", 11, MUTED)
    diagnostic_label.name = "W74ActualGodotFrameDeltaNotClaimedGPUBenchmark"
    diagnostic_label.visible = false
    var cinema_controls := HFlowContainer.new()
    cinema_controls.name = "A7ViewAndAccessibilityRail"
    cinema_controls.add_theme_constant_override("h_separation", 10)
    cinema_controls.add_theme_constant_override("v_separation", 8)
    cinema.add_child(cinema_controls)
    for camera_index in range(3):
        var view := _button(cinema_controls, "", _select_camera.bind(camera_index))
        view.name = "A7Camera%02d" % camera_index
        view.custom_minimum_size = Vector2(98, 42)
        camera_buttons.append(view)
    quality_button = _button(cinema_controls, "", _toggle_quality)
    quality_button.custom_minimum_size = Vector2(145, 42)
    motion_button = _button(cinema_controls, "", _toggle_motion)
    motion_button.custom_minimum_size = Vector2(158, 42)
    sound_button = _button(cinema_controls, "", _toggle_sound)
    sound_button.custom_minimum_size = Vector2(138, 42)
    focus_button = _button(cinema_controls, "", _toggle_inspection_focus)
    focus_button.custom_minimum_size = Vector2(167, 42)
    cinema_button = _button(cinema_controls, "", _toggle_cinema_mode)
    cinema_button.custom_minimum_size = Vector2(163, 42)
    pilot_button = _button(cinema_controls, "", _toggle_pilot)
    pilot_button.custom_minimum_size = Vector2(198, 42)
    # W67 real two-sector walk: native controls change only the camera
    # position along the modeled catwalk, never the six-cycle puzzle state.
    var route_rail := HFlowContainer.new()
    route_rail.name = "TwoTrueSpatialSectors"
    route_rail.add_theme_constant_override("h_separation", 9)
    route_rail.add_theme_constant_override("v_separation", 7)
    cinema.add_child(route_rail)
    for idx in range(2):
        var sector_view := _button(route_rail, "", _select_inspection_sector.bind(idx))
        sector_view.name = "RealSector%02d" % (idx + 1)
        sector_view.custom_minimum_size = Vector2(182, 42)
        sector_buttons.append(sector_view)
    var walk_back := _button(route_rail, "", _step_route.bind(-1))
    walk_back.name = "WalkBackOn3DDeck"
    walk_back.custom_minimum_size = Vector2(112, 42)
    route_buttons.append(walk_back)
    var walk_forward := _button(route_rail, "", _step_route.bind(1))
    walk_forward.name = "WalkForwardOn3DDeck"
    walk_forward.custom_minimum_size = Vector2(112, 42)
    route_buttons.append(walk_forward)
    route_label = _label(cinema, "", 11, MUTED)
    # W70 native accessible directional controls operate REAL CharacterBody3D
    # physics, never teleport or inject fictional "completed" game actions.
    pilot_rail = HFlowContainer.new()
    pilot_rail.name = "RealFirstPersonMobileControlRail"
    pilot_rail.add_theme_constant_override("h_separation", 8)
    pilot_rail.add_theme_constant_override("v_separation", 6)
    cinema.add_child(pilot_rail)
    for keycode in [KEY_W, KEY_A, KEY_S, KEY_D]:
        var button := _button(pilot_rail, "", _pilot_nudge.bind(keycode))
        button.name = "PhysicalWalkKey%d" % keycode
        button.custom_minimum_size = Vector2(93, 40)
        pilot_nudge_buttons[keycode] = button
    pilot_inspect_button = _button(pilot_rail, "", _pilot_inspect)
    pilot_inspect_button.custom_minimum_size = Vector2(148, 40)
    world_use_button = _button(pilot_rail, "", _world_use)
    world_use_button.name = "W73Actual3DAimedPhysicalTool"
    world_use_button.custom_minimum_size = Vector2(230,40)
    world_use_button.visible = false
    pilot_status_label = _label(cinema, "", 11, MINT)
    controller_hint_label = _label(cinema, "", 11, GOLD)
    controller_hint_label.name = "W74ActualJoypadContextHintOnlyOnInput"
    controller_hint_label.visible = false
    pilot_rail.visible = false
    pilot_status_label.visible = false
    subtitle = _label(body, "", 15, MINT)
    intro = _label(body, "", 15, MUTED)
    # W71: actual connected physical storyline, not another decorative HUD.
    var mission_panel := _panel(body)
    mission_panel.name = "W71TrueConnectedSpatialMissionPanel"
    mission_panel.add_theme_constant_override("separation", 10)
    var mission_row := HFlowContainer.new()
    mission_row.name = "W71MissionProgressAndActivation"
    mission_row.add_theme_constant_override("h_separation", 12)
    mission_row.add_theme_constant_override("v_separation", 8)
    mission_panel.add_child(mission_row)
    mission_button = _button(mission_row, "", _start_spatial_mission)
    mission_button.custom_minimum_size = Vector2(245, 42)
    field_start_button = _button(mission_row, "", _start_extended_mission)
    field_start_button.custom_minimum_size = Vector2(225, 42)
    mission_title = _label(mission_row, "", 17, GOLD)
    var mission_strip := HBoxContainer.new()
    mission_strip.name = "RealSpatialObjectivePips"
    mission_strip.add_theme_constant_override("separation", 8)
    mission_panel.add_child(mission_strip)
    for step in range(5):
        var progress_pip := ColorRect.new()
        progress_pip.name = "ActualStationObjective%02d" % (step + 1)
        progress_pip.color = BORDER
        progress_pip.custom_minimum_size = Vector2(28, 6)
        progress_pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        progress_pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        mission_strip.add_child(progress_pip)
        mission_pips.append(progress_pip)
    mission_briefing = _label(mission_panel, "", 13, WHITE)
    mission_meta = _label(mission_panel, "", 11, MUTED)
    field_label = _label(mission_panel, "", 13, GOLD)
    field_help = _label(mission_panel, "", 12, MINT)
    field_valve_controls = HFlowContainer.new()
    field_valve_controls.name = "ActualPhysicalThermalDialControls"
    mission_panel.add_child(field_valve_controls)
    field_relay_controls = HFlowContainer.new()
    field_relay_controls.name = "ActualPhysicalRelayRoutingControls"
    mission_panel.add_child(field_relay_controls)
    field_sync_controls = HFlowContainer.new()
    field_sync_controls.name = "ActualPhysicalContainmentSyncControls"
    mission_panel.add_child(field_sync_controls)
    for index in range(2):
        var id: String = "valve_minus" if index == 0 else "valve_plus"
        var direction: int = -1 if index == 0 else 1
        field_buttons[id] = _button(field_valve_controls, "",
            _field_valve.bind(direction))
        (field_buttons[id] as Button).custom_minimum_size = Vector2(162, 42)
    for i in range(3):
        var key: String = "relay_%d" % i
        field_buttons[key] = _button(field_relay_controls, "",
            _field_relay.bind(i))
        (field_buttons[key] as Button).custom_minimum_size = Vector2(128, 42)
    for i in range(3):
        var key: String = "sync_%d" % i
        field_buttons[key] = _button(field_sync_controls, "",
            _field_sync.bind(i))
        (field_buttons[key] as Button).custom_minimum_size = Vector2(128, 42)
    field_label.visible = false
    field_help.visible = false
    field_valve_controls.visible = false
    field_relay_controls.visible = false
    field_sync_controls.visible = false

    # Original story beats are generated from actual game shift/status;
    # never play fake cutscenes that are independent of the player's choices.
    var narrative_panel := _panel(body)
    w76_hidden_sections.append(narrative_panel.get_parent() as Control)
    narrative_panel.name = "A7TrueStateIncidentBriefing"
    narrative_title = _label(narrative_panel, "", 17, GOLD)
    narrative_body = _label(narrative_panel, "", 14, WHITE)
    forecast_label = _label(narrative_panel, "", 12, MINT)

    var status_box := _panel(body)
    w76_hidden_sections.append(status_box.get_parent() as Control)
    var strip := HBoxContainer.new()
    strip.add_theme_constant_override("separation", 7)
    status_box.add_child(strip)
    for i in range(6):
        var pip := ColorRect.new()
        pip.name = "IncidentCycle%02d" % (i + 1)
        pip.color = BORDER
        pip.custom_minimum_size = Vector2(24, 6)
        pip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
        strip.add_child(pip)
        round_pips.append(pip)
    cycle_label = _label(status_box, "", 16, GOLD)
    actions_label = _label(status_box, "", 14, WHITE)
    event_label = _label(status_box, "", 20, MINT)

    var metrics_flow := HFlowContainer.new()
    metrics_flow.name = "TrueInteractiveSystemMetrics"
    metrics_flow.add_theme_constant_override("h_separation", 12)
    metrics_flow.add_theme_constant_override("v_separation", 12)
    body.add_child(metrics_flow)
    w76_hidden_sections.append(metrics_flow)
    for key in ORDER:
        var p := PanelContainer.new()
        p.custom_minimum_size = Vector2(210, 112)
        p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        p.add_theme_stylebox_override("panel", _style_panel())
        metrics_flow.add_child(p)
        var inside := VBoxContainer.new()
        inside.add_theme_constant_override("separation", 8)
        p.add_child(inside)
        var caption := _label(inside, "", 13, MUTED)
        metric_labels[key] = caption
        var bar := ProgressBar.new()
        bar.name = "Metric_" + key
        bar.custom_minimum_size = Vector2(182, 13)
        bar.max_value = 100
        bar.show_percentage = false
        var groove := StyleBoxFlat.new()
        groove.bg_color = Color("1e2b38")
        groove.set_corner_radius_all(2)
        var fill := StyleBoxFlat.new()
        fill.bg_color = MINT
        fill.set_corner_radius_all(2)
        bar.add_theme_stylebox_override("background", groove)
        bar.add_theme_stylebox_override("fill", fill)
        bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
        inside.add_child(bar)
        metric_bars[key] = bar

    var command_box := _panel(body)
    w76_hidden_sections.append(command_box.get_parent() as Control)
    _label(command_box, "SELECT TWO ACTIONS / EACH SHIFT", 13, GOLD)
    var action_flow := HFlowContainer.new()
    action_flow.add_theme_constant_override("h_separation", 12)
    action_flow.add_theme_constant_override("v_separation", 12)
    command_box.add_child(action_flow)
    for action in ACTION_ORDER:
        var section := VBoxContainer.new()
        section.custom_minimum_size = Vector2(180, 105)
        action_flow.add_child(section)
        var b := _button(section, "", _on_action.bind(action))
        action_buttons[action] = b
        b.mouse_entered.connect(_preview_action.bind(action))
        b.focus_entered.connect(_preview_action.bind(action))
        b.mouse_exited.connect(_clear_action_preview)
        b.focus_exited.connect(_clear_action_preview)
        var effect := _label(section, "", 12, MUTED)
        effect.name = "Effect_" + action
    objective_label = _label(command_box, "", 13, WHITE)
    var bottom := HFlowContainer.new()
    bottom.add_theme_constant_override("h_separation", 10)
    bottom.add_theme_constant_override("v_separation", 10)
    body.add_child(bottom)
    restart_button = _button(bottom, "", _restart)
    save_button = _button(bottom, "", _save_checkpoint)
    save_button.custom_minimum_size = Vector2(194,46)
    load_button = _button(bottom, "", _load_checkpoint)
    load_button.custom_minimum_size = Vector2(194,46)
    checkpoint_status_label = _label(body, "", 11, GOLD)
    footnote = _label(body, "", 12, MUTED)
    _label(body, "A7 CASCADE / EXPERIMENTAL VERTICAL-SLICE MECHANIC / SOFTWARE-ONLY", 11, GOLD)

func _on_action(action: String) -> void:
    # No sound or cinematic confirmation is issued for an invalid/blocked
    # move; an accepted command first alters the original W63 rules engine.
    _previewed_action = ""
    var before: Dictionary = model.snapshot()
    if not model.choose(action):
        return
    var after: Dictionary = model.snapshot()
    if stage_3d != null:
        stage_3d.trigger_action(action)
        if stage_3d.spatial_mission != null:
            stage_3d.spatial_mission.accepted_game_action(action, before, after)
            if stage_3d.field_operations != null:
                stage_3d.field_operations.observe_phase(
                    stage_3d.spatial_mission.phase, after)
                if stage_3d.field_feedback != null:
                    stage_3d.field_feedback.refresh_from_original_equipment()
            _refresh_mission_ui(after)
            # W77: mission-accepted game event must immediately update the
            # real bulkhead collider and contextual goal in the SAME frame.
            # A delayed signal can leave a misleading "LOCKED" label after
            # Godot has already begun to open the actual passage.
            if stage_3d.sector_bulkhead != null:
                stage_3d.sector_bulkhead.refresh_state()
            _w76_update_goal()
    checkpoint.note("action", action, self)
    if sound_bus != null:
        var cue: String = "action"
        if str(after["status"]) == "won":
            cue = "win"
        elif str(after["status"]) == "failed" or str(after["status"]) == "unstable":
            cue = "loss"
        elif int(after["shift"]) > int(before["shift"]):
            cue = "danger" if str(after["last_event"]).begins_with("damage_") else "incident"
        sound_bus.cue(cue)
    call_deferred("_publish_web_accessibility")

func _restart() -> void:
    _previewed_action = ""
    checkpoint.clear()
    field_focused_devices.clear()
    if stage_3d != null and stage_3d.field_feedback != null:
        stage_3d.field_feedback.reset_visual_feedback()
    if stage_3d != null and stage_3d.spatial_mission != null:
        stage_3d.spatial_mission.reset()
        if stage_3d.field_feedback != null:
            stage_3d.field_feedback.refresh_from_original_equipment()
    model.reset()
    if sound_bus != null:
        sound_bus.cue("restart")
    if stage_3d != null:
        stage_3d.recent_action = ""
        stage_3d.pulse = 0.0

func _update_gamepad_hint() -> void:
    if controller_hint_label == null:
        return
    var active: bool = (gamepad.any_controller_event_observed and
        stage_3d != null and stage_3d.first_person != null and
        stage_3d.first_person.piloting)
    controller_hint_label.visible = active
    if active:
        controller_hint_label.text = gamepad.explain(locale)

func _w76_play_now() -> void:
    if stage_3d == null or stage_3d.spatial_mission == null:
        return
    if not stage_3d.spatial_mission.active:
        _start_extended_mission()
    if not stage_3d.first_person.piloting:
        _toggle_pilot()
    if not w76_immersive:
        _w76_toggle_immersive()
    _w76_update_goal()

func _w76_update_goal() -> void:
    if w76_objective_label == null or stage_3d == null:
        return
    var mission: A7SpatialMission = stage_3d.spatial_mission
    # First click must show the true objective immediately without waiting
    # a rendered frame, as verified by the native game accept test.
    if stage_3d.mission_wayfinder != null:
        stage_3d.mission_wayfinder._reconcile()
    if stage_3d.sector_bulkhead != null:
        stage_3d.sector_bulkhead.refresh_state()
    var label: String = mission.title(locale) if mission != null else ""
    var helper: String = stage_3d.mission_wayfinder.localized_hint(locale) if stage_3d.mission_wayfinder != null else ""
    if mission != null and mission.active and mission.extended_mode and stage_3d.sector_bulkhead != null:
        var gate_status: String = ("ЗАТВОР ЗАКРЫТ" if stage_3d.sector_bulkhead.physically_blocked else "ЗАТВОР ОТКРЫТ")
        if locale == "en":
            gate_status = "GATE LOCKED" if stage_3d.sector_bulkhead.physically_blocked else "GATE OPEN"
        helper += "  ·  " + gate_status
    w76_objective_label.text = (label + "   /   " + helper) if mission != null and mission.active else ""
    w76_objective_label.visible = (mission != null and mission.active
        and not (w76_immersive and _w81_touch_context()))

func _w81_touch_context() -> bool:
    # A phone in landscape is still touch-driven; W78 width-only rule lost controls.
    return size.x < 640.0 or (size.x <= 1100.0 and size.y <= 600.0)

func _w81_refresh_layout_chrome() -> void:
    # Recompute on resize. W80 separate grid browser failed on stale 390px goal.
    if w76_play_button != null:
        w76_play_button.visible = not (w76_immersive and stage_3d != null
            and stage_3d.first_person != null and stage_3d.first_person.piloting)
    if w76_objective_label != null:
        _w76_update_goal()
    if cinema_caption != null:
        cinema_caption.text = (
            ("A7 / ПОЛЕВАЯ МИССИЯ" if locale == "ru" else "A7 / FIELD MISSION")
            if w76_immersive and _w81_touch_context() else _t("stage"))

func _w76_toggle_immersive() -> void:
    w76_immersive = not w76_immersive
    w76_immersive_switches += 1
    for section in w76_hidden_sections:
        if section != null:
            section.visible = not w76_immersive
    if intro != null:
        intro.visible = not w76_immersive
    if subtitle != null:
        subtitle.visible = not w76_immersive
    if footnote != null:
        footnote.visible = not w76_immersive
    if scroll != null:
        scroll.scroll_vertical = 0
    if w80_full_bleed != null:
        w80_full_bleed.set_immersive(w76_immersive)
    _layout_stage()
    _render(model.snapshot())

func _toggle_diagnostics() -> void:
    show_diagnostics = not show_diagnostics
    if diagnostic_label != null:
        diagnostic_label.visible = show_diagnostics
        if show_diagnostics:
            diagnostic_label.text = frame_telemetry.display(locale)
    call_deferred("_publish_web_accessibility")

func _save_checkpoint() -> void:
    var ok: bool = checkpoint.write_packet(self)
    checkpoint_status_label.text = _t("save_done" if ok else "save_fail")
    call_deferred("_publish_web_accessibility")

func _load_checkpoint() -> void:
    var ok: bool = checkpoint.restore_into(self)
    checkpoint_status_label.text = _t("load_done" if ok else "load_fail")
    call_deferred("_publish_web_accessibility")

func _toggle_sound() -> void:
    if sound_bus != null:
        sound_bus.set_muted(not sound_bus.muted)
    _render(model.snapshot())

func _preview_action(action: String) -> void:
    if str(model.snapshot()["status"]) != "playing":
        return
    _previewed_action = action
    _update_forecast(model.snapshot())

func _clear_action_preview() -> void:
    _previewed_action = ""
    _update_forecast(model.snapshot())

func _update_forecast(state: Dictionary) -> void:
    if forecast_label == null:
        return
    if _previewed_action == "":
        forecast_label.text = _t("preview_default")
        forecast_label.add_theme_color_override("font_color", MINT)
        return
    var preview: Dictionary = A7IncidentDirector.preview(locale,
        _previewed_action, state["metrics"])
    forecast_label.text = str(preview.get("headline", "")) + "  /  " + str(preview.get("body", ""))
    forecast_label.add_theme_color_override(
        "font_color", RED if bool(preview.get("risk", false)) else MINT)

func _select_camera(index: int) -> void:
    if stage_3d != null:
        stage_3d.set_camera(index)
    _render(model.snapshot())

func _select_inspection_sector(index: int) -> void:
    if stage_3d != null:
        stage_3d.set_inspection_sector(index)
    _render(model.snapshot())

func _step_route(direction: int) -> void:
    if stage_3d != null:
        stage_3d.step_inspection_route(direction)
    _render(model.snapshot())

func _start_spatial_mission() -> void:
    if stage_3d == null or stage_3d.spatial_mission == null:
        return
    var mission: A7SpatialMission = stage_3d.spatial_mission
    if mission.start(model.snapshot()):
        checkpoint.note("start_normal", 0, self)
    else:
        mission_meta.text = _t("mission_wait")
    _refresh_mission_ui(model.snapshot())
    call_deferred("_publish_web_accessibility")

func _start_extended_mission() -> void:
    if (stage_3d == null or stage_3d.spatial_mission == null
            or stage_3d.field_operations == null):
        return
    var ok: bool = stage_3d.spatial_mission.start_extended(
        model.snapshot(), stage_3d.field_operations)
    if ok:
        checkpoint.note("start_extended", 0, self)
        if stage_3d.field_feedback != null:
            stage_3d.field_feedback.refresh_from_original_equipment()
    else:
        mission_meta.text = _t("mission_wait")
    _refresh_mission_ui(model.snapshot())
    call_deferred("_publish_web_accessibility")

# Original first-person context camera: one gentle operator-initiated turn
# toward the REAL physical device, never a teleport or a fabricated rendering.
# 3D details remain manipulable even when the player disables camera motion.
func _w77_cancel_guided_camera_on_manual_input() -> void:
    # Actual player W/A/S/D, mouse drag and nonzero gamepad stick override
    # any pending cinematic auto-look. No force-teleport or fake key state.
    if w77_operator_focus_tween != null and w77_operator_focus_tween.is_running():
        w77_operator_focus_tween.kill()
        w77_focus_cancelled_by_actual_input += 1

func _focus_physical_field_device(key: String, target: Vector3) -> void:
    if (field_focused_devices.has(key) or stage_3d == null
            or stage_3d.first_person == null
            or not stage_3d.first_person.piloting):
        return
    var actor: A7FirstPersonOperator = stage_3d.first_person
    var eye: Vector3 = actor.body.global_position + Vector3(0, A7FirstPersonOperator.HEAD_HEIGHT, 0)
    var delta_aim: Vector3 = target - eye
    var flat: float = Vector2(delta_aim.x, delta_aim.z).length()
    if flat < 0.10:
        return
    field_focused_devices[key] = true
    field_focus_events += 1
    var yaw: float = atan2(-delta_aim.x, -delta_aim.z)
    # Godot Camera3D looks along LOCAL -Z; positive X pitch aims UP.
    # Earlier W72 used -atan2 and wrongly pitched the real operator below
    # machines higher than eye-level. W73 raycast regression reproduces it.
    var pitch: float = clampf(atan2(delta_aim.y, flat),
        deg_to_rad(-60.0), deg_to_rad(60.0))
    if reduced_motion:
        actor.body.rotation.y = yaw
        actor.head_camera.rotation.x = pitch
        return
    _w77_cancel_guided_camera_on_manual_input()
    w77_operator_focus_tween = create_tween()
    w77_operator_focus_tween.set_parallel(true)
    w77_operator_focus_tween.tween_property(
        actor.body, "rotation:y", yaw, 0.32).set_trans(
        Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
    w77_operator_focus_tween.tween_property(
        actor.head_camera, "rotation:x", pitch, 0.32).set_trans(
        Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)

func _field_valve(direction: int) -> void:
    if stage_3d == null or stage_3d.field_operations == null:
        return
    var ok: bool = stage_3d.field_operations.rotate_valve(
        direction, stage_3d.first_person)
    if ok:
        _focus_physical_field_device("thermal", A7FieldOperations.CORE + Vector3(0, 1.0, 0))
        if stage_3d.field_feedback != null:
            stage_3d.field_feedback.notify_real_world_operation("valve", 0)
        if sound_bus != null:
            sound_bus.cue("action")
        checkpoint.note("valve", direction, self)
    field_help.text = stage_3d.field_operations.instructions(locale) if ok else _t("field_far")
    _refresh_mission_ui(model.snapshot())
    if w79_mission_deck != null:
        w79_mission_deck.report_real_physical_result(ok)
    call_deferred("_publish_web_accessibility")

func _field_relay(index: int) -> void:
    if stage_3d == null or stage_3d.field_operations == null:
        return
    var ok: bool = stage_3d.field_operations.toggle_relay(
        index, stage_3d.first_person)
    if ok:
        _focus_physical_field_device("relay", A7FieldOperations.RELAY + Vector3(0, 0.93, 0))
        if stage_3d.field_feedback != null:
            stage_3d.field_feedback.notify_real_world_operation("relay", index)
        if sound_bus != null:
            sound_bus.cue("action")
        checkpoint.note("relay", index, self)
    field_help.text = stage_3d.field_operations.instructions(locale) if ok else _t("field_far")
    _refresh_mission_ui(model.snapshot())
    if w79_mission_deck != null:
        w79_mission_deck.report_real_physical_result(ok)
    call_deferred("_publish_web_accessibility")

func _field_sync(index: int) -> void:
    if stage_3d == null or stage_3d.field_operations == null:
        return
    var ok: bool = stage_3d.field_operations.sync_connector(
        index, stage_3d.first_person, model.snapshot())
    if ok:
        _focus_physical_field_device("sync", A7FieldOperations.CORE + Vector3(1.02, 1.45, 0))
        if stage_3d.field_feedback != null:
            stage_3d.field_feedback.notify_real_world_operation("sync", index)
        if sound_bus != null:
            sound_bus.cue("action")
        checkpoint.note("sync", index, self)
    field_help.text = stage_3d.field_operations.instructions(locale) if ok else _t("field_far")
    _refresh_mission_ui(model.snapshot())
    if w79_mission_deck != null:
        w79_mission_deck.report_real_physical_result(ok)
    call_deferred("_publish_web_accessibility")

func _refresh_mission_ui(state: Dictionary) -> void:
    if stage_3d == null or stage_3d.spatial_mission == null or mission_button == null:
        return
    var mission: A7SpatialMission = stage_3d.spatial_mission
    mission_title.text = mission.title(locale)
    mission_briefing.text = mission.briefing(locale)
    mission_button.text = _t("mission_active" if mission.active else "mission_start")
    mission_button.disabled = mission.active or str(state.get("status", "")) != "playing" or (
        (state.get("history", []) as Array).size() > 0)
    field_start_button.text = _t("field_mode" if mission.extended_mode else "field_start")
    field_start_button.disabled = mission.active or mission_button.disabled
    var ops: A7FieldOperations = stage_3d.field_operations
    var show_field: bool = mission.extended_mode and ops != null and ops.enabled
    field_label.visible = show_field
    field_help.visible = show_field
    field_label.text = _t("field_mode")
    if show_field:
        var contextual: String = ops.instructions(locale)
        field_help.text = contextual
    field_valve_controls.visible = show_field and mission.phase == 0
    field_relay_controls.visible = show_field and mission.phase == 2
    field_sync_controls.visible = show_field and mission.phase == 4
    var field_labels: Dictionary = {
        "valve_minus": "field_valve_minus", "valve_plus": "field_valve_plus",
        "relay_0": "field_relay_a", "relay_1": "field_relay_b",
        "relay_2": "field_relay_c", "sync_0": "field_sync_a",
        "sync_1": "field_sync_b", "sync_2": "field_sync_c",
    }
    for key in field_buttons.keys():
        (field_buttons[key] as Button).text = _t(str(field_labels[key]))
    if w79_mission_deck != null:
        w79_mission_deck.refresh(state)
    mission_meta.text = ("0 / 5" if not mission.active else "%d / 5" % mini(5, mission.phase))
    if mission.active and mission.phase == 6:
        mission_meta.text = "FAILED / 5"
    for index in range(mission_pips.size()):
        var pip: ColorRect = mission_pips[index]
        pip.color = (RED if mission.phase == 6 else MINT) if (
            mission.active and (mission.phase == 5 or index < mission.phase)) else (
            ORANGE if mission.active and index == mission.phase else BORDER)

func _toggle_pilot() -> void:
    if stage_3d != null:
        stage_3d.toggle_first_person()
    _render(model.snapshot())

func _pilot_nudge(keycode: int) -> void:
    _w77_cancel_guided_camera_on_manual_input()
    if stage_3d != null:
        stage_3d.first_person_nudge(keycode)
    call_deferred("_publish_web_accessibility")

func _pilot_inspect() -> void:
    if stage_3d == null:
        return
    var target: String = stage_3d.first_person_inspect()
    pilot_status_label.text = _t("pilot_core") if target == "CORE" else (
        _t("pilot_relay") if target == "RELAY" else _t("pilot_far"))
    if stage_3d.spatial_mission != null and stage_3d.first_person != null:
        var before_inspections: int = stage_3d.spatial_mission.real_inspections
        var did_advance: bool = stage_3d.spatial_mission.inspect_physical(
            target, model.snapshot(), stage_3d.first_person)
        if (not did_advance and target != ""
                and stage_3d.spatial_mission.extended_mode):
            pilot_status_label.text = _t("field_gate")
        if stage_3d.field_operations != null:
            stage_3d.field_operations.observe_phase(
                stage_3d.spatial_mission.phase, model.snapshot())
            if stage_3d.field_feedback != null:
                stage_3d.field_feedback.refresh_from_original_equipment()
        if (target in ["CORE","RELAY"] and stage_3d.spatial_mission.active
                and (did_advance or
                stage_3d.spatial_mission.real_inspections > before_inspections)):
            checkpoint.note("inspect", target, self)
        _refresh_mission_ui(model.snapshot())
    call_deferred("_publish_web_accessibility")

func _world_use() -> void:
    if (stage_3d == null or stage_3d.world_interaction == null
            or stage_3d.spatial_mission == null
            or not stage_3d.spatial_mission.extended_mode):
        return
    var result: Dictionary = stage_3d.world_interaction.interact(model.snapshot())
    if result.is_empty():
        return
    var kind: String = str(result["kind"])
    if kind == "valve":
        _focus_physical_field_device("thermal",
            A7FieldOperations.CORE + Vector3(0,1.0,0))
    elif kind == "relay":
        _focus_physical_field_device("relay",
            A7FieldOperations.RELAY + Vector3(0,0.93,0))
    elif kind == "sync":
        _focus_physical_field_device("sync",
            A7FieldOperations.CORE + Vector3(1.02,1.45,0))
    if stage_3d.field_feedback != null:
        stage_3d.field_feedback.notify_real_world_operation(
            kind,int(result["index"]))
    if sound_bus != null:
        sound_bus.cue("action")
    checkpoint.note(kind if kind in ["relay","sync"] else "valve",
        int(result["index"]) if kind in ["relay","sync"] else 1, self)
    _refresh_mission_ui(model.snapshot())
    _refresh_world_reticle()
    call_deferred("_publish_web_accessibility")

func _refresh_world_reticle() -> void:
    if world_reticle == null or stage_3d == null:
        return
    var enabled: bool = (stage_3d.first_person != null
        and stage_3d.first_person.piloting
        and stage_3d.spatial_mission != null
        and stage_3d.spatial_mission.extended_mode
        and stage_3d.world_interaction != null)
    world_reticle.visible = enabled
    world_aim_hint.visible = enabled
    world_use_button.visible = enabled
    if not enabled:
        return
    var hit: Dictionary = stage_3d.world_interaction.look_at_active_target()
    world_reticle.add_theme_color_override("font_color",MINT if not hit.is_empty() else MUTED)
    world_aim_hint.text = stage_3d.world_interaction.hint(locale)
    world_use_button.text = _t("world_use")
    world_use_button.disabled = hit.is_empty()

func _toggle_inspection_focus() -> void:
    if stage_3d != null:
        stage_3d.toggle_inspection_focus()
    _render(model.snapshot())

func _toggle_cinema_mode() -> void:
    # Recompose the real native SubViewport only; never enlarge a fake image
    # or disconnect game commands, readable safety/status messages.
    cinema_mode = not cinema_mode
    cinema_readout.visible = not cinema_mode
    route_label.visible = not cinema_mode
    intro.visible = not cinema_mode
    subtitle.visible = not cinema_mode
    _layout_stage()
    _render(model.snapshot())

func _toggle_quality() -> void:
    quality = "eco" if quality == "hero" else "hero"
    if stage_3d != null:
        stage_3d.set_quality(quality)
    _layout_stage()
    _render(model.snapshot())

func _toggle_motion() -> void:
    reduced_motion = not reduced_motion
    if stage_3d != null:
        stage_3d.set_reduced_motion(reduced_motion)
    _render(model.snapshot())

func _layout_stage() -> void:
    if stage_shell == null:
        return
    var height: float = clampf(size.y * 0.56, 390.0, 580.0)
    if size.x < 640.0:
        height = clampf(size.x * 0.76, 242.0, 305.0)
    elif size.x < 900.0:
        height = clampf(size.y * 0.50, 350.0, 470.0)
    if w76_immersive:
        height = maxf(height, clampf(size.y * 0.81, 420.0, 850.0))
        if size.x < 640.0:
            height = clampf(size.y * 0.61, 345.0, 570.0)
    if w80_full_bleed != null and w80_full_bleed.active:
        # This is an actual full-viewport 3D render size, not a camera
        # crop or screenshot. W76's old 61% phone stage is superseded.
        height = maxf(height, size.y)
    if cinema_mode:
        var cinema_target: float = clampf(size.y * 0.78, 585.0, 760.0)
        if size.x < 640.0:
            cinema_target = clampf(size.x * 0.98, 325.0, 460.0)
        elif size.x < 900.0:
            cinema_target = clampf(size.y * 0.70, 475.0, 620.0)
        # The cinematic camera must genuinely gain screen area even if
        # a nonstandard headless/window layout starts unusually tall.
        height = maxf(height + 125.0, cinema_target)
        if size.x < 640.0:
            height = minf(height, 460.0)
    # Fullscreen has no offscreen scroll area. The W76 minimum 420px was
    # designed for a dashboard: on an 844x390 phone it pushes actual
    # physical G/E and mission controls *below* the visible framebuffer.
    if w80_full_bleed != null and w80_full_bleed.active:
        height = size.y
    stage_shell.custom_minimum_size = Vector2(0, height)
    if cinematic_hud != null:
        cinematic_hud._relayout()
    visual_container.custom_minimum_size = Vector2(0, height)
    visual_container.stretch_shrink = 2 if quality == "eco" else 1
    var compact: bool = size.x < 640.0
    var touch_context: bool = _w81_touch_context()
    var landscape_touch: bool = touch_context and size.x >= 640.0
    # W77 real-Chromium mobile art QA: A7 title must be a FIRST ROW,
    # never a 2-character column that inflates three buttons to 400px.
    if brand_label != null:
        brand_label.autowrap_mode = (
            TextServer.AUTOWRAP_OFF if compact else
            TextServer.AUTOWRAP_WORD_SMART)
        brand_label.size_flags_horizontal = (
            Control.SIZE_SHRINK_BEGIN if compact else
            Control.SIZE_EXPAND_FILL)
        brand_label.custom_minimum_size = (
            Vector2(maxf(150.0,size.x - 52.0),40.0)
            if compact else Vector2.ZERO)
        brand_label.add_theme_font_size_override(
            "font_size",18 if compact else 27)
        brand_label.text = (
            ("ПОСЛЕДНИЙ РУБЕЖ" if locale == "ru" else "LAST FRONTIER")
            if compact else _t("brand"))
    if top_rail != null:
        top_rail.add_theme_constant_override(
            "h_separation",8 if compact else 12)
    if language_button != null:
        language_button.custom_minimum_size = (
            Vector2(62,40) if compact else Vector2(90,45))
    if w76_play_button != null:
        w76_play_button.custom_minimum_size = (
            Vector2(155,40) if compact else Vector2(185,45))
    if w76_focus_button != null:
        w76_focus_button.custom_minimum_size = (
            Vector2(160,40) if compact else Vector2(220,45))
    if stage_3d != null:
        stage_3d.set_compact_view(compact)
    if w78_touch_overlay != null and stage_3d != null:
        w78_touch_overlay.set_context(touch_context,w76_immersive,
            stage_3d.first_person.piloting,locale,size.x)
        w78_touch_overlay.configure_landscape(landscape_touch)
    if w79_mission_deck != null and stage_3d != null:
        w79_mission_deck.set_context(touch_context,w76_immersive,
            stage_3d.first_person.piloting,locale,size.x,model.snapshot())
        w79_mission_deck.configure_landscape(landscape_touch)
    if w83_dual_touch != null:
        w83_dual_touch.set_context(touch_context and w76_immersive,
            locale,size)
    if w82_nav_cockpit != null:
        w82_nav_cockpit.configure(size.x)
    if cinematic_hud != null:
        cinematic_hud.set_compact_mode(compact)
    for view in camera_buttons:
        view.custom_minimum_size.x = 84.0 if compact else 118.0
    if compact:
        quality_button.custom_minimum_size.x = 136.0
        motion_button.custom_minimum_size.x = 136.0
    _w81_refresh_layout_chrome()
    call_deferred("_publish_web_accessibility")

func _toggle_locale() -> void:
    locale = "en" if locale == "ru" else "ru"
    _render(model.snapshot())

func _notification(what: int) -> void:
    # W83: avoid a stuck CharacterBody3D walk or continued camera gesture
    # after browser/tab focus loss. Never changes original mission decisions.
    if what == NOTIFICATION_WM_WINDOW_FOCUS_OUT or (
            what == NOTIFICATION_APPLICATION_FOCUS_OUT) or (
            what == NOTIFICATION_APPLICATION_PAUSED):
        if w83_dual_touch != null:
            w83_dual_touch.cancel_capture()
        if w78_touch_overlay != null:
            w78_touch_overlay.release_all()

func _unhandled_input(event: InputEvent) -> void:
    # Right mouse drag rotates the actual first-person Camera3D when active.
    if stage_3d == null or stage_3d.first_person == null:
        return
    if not stage_3d.first_person.piloting:
        return
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _w77_cancel_guided_camera_on_manual_input()
        stage_3d.first_person.rotate_view((event as InputEventMouseMotion).relative)
        get_viewport().set_input_as_handled()

func _input(event: InputEvent) -> void:
    # W83: explicitly indexed touch gestures; only right-side FREE world
    # screen events are handled. Every W78/W79/W80 interactive button retains
    # its independent pointer and real source action routing.
    if w83_dual_touch != null and w83_dual_touch.handle_screen_event(event):
        get_viewport().set_input_as_handled()
        call_deferred("_publish_web_accessibility")
        return
    # W74 native controller events are handled before focused GUI widgets.
    # The analog axis drives the real W70 CharacterBody3D's continuous speed,
    # never fake camera images or a teleported player position.
    if event is InputEventJoypadMotion:
        var axis_event: InputEventJoypadMotion = event as InputEventJoypadMotion
        if absf(axis_event.axis_value) >= 0.17:
            _w77_cancel_guided_camera_on_manual_input()
        if gamepad.route_motion(axis_event,self):
            _update_gamepad_hint()
            get_viewport().set_input_as_handled()
        return
    if event is InputEventJoypadButton:
        var pad_button: InputEventJoypadButton = event as InputEventJoypadButton
        if pad_button.pressed and gamepad.route_button(
                pad_button.button_index,self):
            _update_gamepad_hint()
            get_viewport().set_input_as_handled()
        return
    # W71 actual-browser correction: raw player motion must be captured before
    # scroll containers or focused buttons consume a WASD key. Both keydown and
    # keyup reach real CharacterBody3D physics; all normal shortcuts continue
    # through _unhandled_key_input when not in operator mode.
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if (stage_3d != null and stage_3d.first_person != null
            and stage_3d.first_person.piloting
            and [KEY_W, KEY_A, KEY_S, KEY_D].has(key.keycode)):
        if key.pressed and not key.echo:
            _w77_cancel_guided_camera_on_manual_input()
        stage_3d.first_person_key(key.keycode, key.pressed)
        get_viewport().set_input_as_handled()
        call_deferred("_publish_web_accessibility")

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
        return
    if key.keycode == KEY_ESCAPE and w76_immersive:
        _w76_toggle_immersive()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_TAB:
        _w76_toggle_immersive()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_ENTER or key.keycode == KEY_KP_ENTER:
        _w76_play_now()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_F3:
        _toggle_diagnostics()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_F5:
        _save_checkpoint()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_F9:
        _load_checkpoint()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_G:
        _world_use()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_Y:
        _start_extended_mission()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_J:
        _field_valve(-1)
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_K:
        _field_valve(1)
        get_viewport().set_input_as_handled()
        return
    if key.keycode in [KEY_7, KEY_8, KEY_9]:
        _field_relay([KEY_7, KEY_8, KEY_9].find(key.keycode))
        get_viewport().set_input_as_handled()
        return
    if key.keycode in [KEY_U, KEY_I, KEY_O]:
        _field_sync([KEY_U, KEY_I, KEY_O].find(key.keycode))
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_T:
        _start_spatial_mission()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_P:
        _toggle_pilot()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_E:
        _pilot_inspect()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_R:
        _restart()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_C:
        _select_camera((stage_3d.camera_index + 1) % 3)
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_Q:
        _toggle_quality()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_M:
        _toggle_motion()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_L:
        _toggle_locale()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_S:
        _toggle_sound()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_F:
        _toggle_inspection_focus()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_X:
        _toggle_cinema_mode()
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_W:
        _step_route(1)
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_A:
        _step_route(-1)
        get_viewport().set_input_as_handled()
        return
    if key.keycode == KEY_N:
        _select_inspection_sector(1 - stage_3d.sector_index)
        get_viewport().set_input_as_handled()
        return
    var keys := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
    var idx: int = keys.find(key.keycode)
    if idx >= 0 and idx < ACTION_ORDER.size():
        _on_action(ACTION_ORDER[idx])
        get_viewport().set_input_as_handled()

func _render(state: Dictionary) -> void:
    if brand_label == null:
        return
    brand_label.text = (
        ("ПОСЛЕДНИЙ РУБЕЖ" if locale == "ru" else "LAST FRONTIER")
        if size.x < 640.0 else _t("brand"))
    subtitle.text = _t("sub")
    intro.text = _t("intro")
    language_button.text = _t("language")
    w76_play_button.text = _t("w76_play")
    w76_focus_button.text = _t("w76_focus_off" if w76_immersive else "w76_focus_on")
    if w80_full_bleed != null:
        w80_full_bleed.set_locale(locale)
    _w76_update_goal()
    if w78_touch_overlay != null and stage_3d != null:
        w78_touch_overlay.set_context(_w81_touch_context(),w76_immersive,
            stage_3d.first_person.piloting,locale,size.x)
    if w79_mission_deck != null and stage_3d != null:
        w79_mission_deck.set_context(_w81_touch_context(),w76_immersive,
            stage_3d.first_person.piloting,locale,size.x,state)
    if w82_nav_cockpit != null and stage_3d != null:
        w82_nav_cockpit.set_context(w76_immersive,
            stage_3d.first_person.piloting,locale,state)
    if w83_dual_touch != null:
        w83_dual_touch.set_context(_w81_touch_context() and w76_immersive,
            locale,size)
    restart_button.text = _t("reset")
    save_button.text = _t("save_game")
    load_button.text = _t("load_game")
    var story: Dictionary = A7IncidentDirector.describe(locale, state)
    narrative_title.text = str(story.get("title", ""))
    narrative_body.text = str(story.get("body", ""))
    _update_forecast(state)
    sound_button.text = _t("sound_off" if sound_bus != null and sound_bus.muted else "sound_on")
    cinema_button.text = _t("cinema_off" if cinema_mode else "cinema_on")
    focus_button.text = _t("focus_off" if stage_3d != null and stage_3d.inspection_focus else "focus_on")
    var piloting: bool = stage_3d != null and stage_3d.first_person != null and stage_3d.first_person.piloting
    pilot_button.text = _t("pilot_off" if piloting else "pilot_on")
    pilot_rail.visible = piloting
    pilot_status_label.visible = piloting
    if piloting and pilot_status_label.text == "":
        pilot_status_label.text = _t("pilot_hint")
    elif not piloting:
        pilot_status_label.text = ""
    var pilot_strings: Dictionary = {
        KEY_W: "pilot_forward", KEY_A: "pilot_left",
        KEY_S: "pilot_back", KEY_D: "pilot_right",
    }
    for keycode in pilot_nudge_buttons.keys():
        (pilot_nudge_buttons[keycode] as Button).text = _t(str(pilot_strings[keycode]))
    pilot_inspect_button.text = _t("pilot_inspect")
    _refresh_world_reticle()
    _update_gamepad_hint()
    if diagnostic_label != null and show_diagnostics:
        diagnostic_label.text = frame_telemetry.display(locale)
    cycle_label.text = "%s %02d / 06" % [_t("round"), mini(6, int(state["shift"]) + 1)]
    actions_label.text = "%s: %d / 2" % [_t("actions"), int(state["actions_left"])]
    var result: String = str(state["status"])
    var last: String = str(state["last_event"])
    if result == "won" or result == "unstable" or result == "failed":
        event_label.text = _t(result)
    elif last.begins_with("damage_"):
        event_label.text = _t("damage") + "  -" + last.trim_prefix("damage_")
    elif last.begins_with("incident_"):
        event_label.text = _t("incident")
    else:
        event_label.text = _t("begin")
    event_label.add_theme_color_override("font_color", RED if result in ["failed", "unstable"] or last.begins_with("damage_") else MINT)
    var stats: Dictionary = state["metrics"]
    for key in ORDER:
        var value: int = int(stats[key])
        (metric_labels[key] as Label).text = "%s   %03d / 100" % [_t(key), value]
        var meter: ProgressBar = metric_bars[key] as ProgressBar
        meter.value = value
        var danger: bool = (key in ["heat", "pressure"] and value > 85) or (
            key in ["seal", "signal", "energy"] and value < 30) or (
            key == "integrity" and value < 45)
        var meter_fill := StyleBoxFlat.new()
        meter_fill.bg_color = RED if danger else GOLD if key == "energy" else MINT
        meter_fill.set_corner_radius_all(2)
        meter.add_theme_stylebox_override("fill", meter_fill)
    for i in range(round_pips.size()):
        round_pips[i].color = MINT if i < int(state["shift"]) else ORANGE if i == int(state["shift"]) and result == "playing" else BORDER
    for action in ACTION_ORDER:
        (action_buttons[action] as Button).text = _t(action)
        (action_buttons[action] as Button).disabled = result != "playing" or int(state["actions_left"]) == 0
        var holder: VBoxContainer = (action_buttons[action] as Button).get_parent() as VBoxContainer
        var effect: Label = holder.get_node("Effect_" + action) as Label
        effect.text = _t(action + "_d")
    objective_label.text = _t("objective")
    _refresh_mission_ui(state)
    footnote.text = _t("disclaimer") + "\n" + _t("keys")
    if cinematic_hud != null:
        cinematic_hud.present(state, locale)
    if stage_3d != null:
        stage_3d.apply_snapshot(state)
        cinema_caption.text = _t("stage")
        _w81_refresh_layout_chrome()
        var stats_display: Dictionary = state["metrics"]
        cinema_readout.text = _t("visual") % [
            int(stats_display["heat"]), int(stats_display["pressure"]),
            int(stats_display["energy"])]
        for i in range(camera_buttons.size()):
            camera_buttons[i].text = _t("camera%d" % i)
            camera_buttons[i].button_pressed = stage_3d.camera_index == i
        quality_button.text = _t("quality_" + quality)
        motion_button.text = _t("motion_off" if reduced_motion else "motion_on")
        for idx in range(sector_buttons.size()):
            sector_buttons[idx].text = _t("area_core" if idx == 0 else "area_relay")
        route_buttons[0].text = _t("guide_prev")
        route_buttons[1].text = _t("guide_next")
        route_buttons[0].disabled = stage_3d.guide_progress <= 0.0
        route_buttons[1].disabled = stage_3d.guide_progress >= 1.0
        route_label.text = _t("tour_status") % roundi(stage_3d.guide_progress * 100.0)
    call_deferred("_publish_web_accessibility")

func _create_web_accessibility() -> void:
    if not OS.has_feature("web"):
        return
    var document: Variant = JavaScriptBridge.get_interface("document")
    if document == null:
        return
    var node: Variant = document.getElementById("a7-cascade-native-state")
    if node == null:
        node = document.createElement("div")
        node.setAttribute("id", "a7-cascade-native-state")
        node.setAttribute("role", "status")
        node.setAttribute("aria-live", "polite")
        node.setAttribute("aria-atomic", "true")
        node.setAttribute("style",
            "position:fixed;left:0;top:0;width:1px;height:1px;opacity:0;overflow:hidden;pointer-events:none")
        document.body.appendChild(node)
    _web_state_element = node

# Browser QA is passive: it may observe an actual moving physics body but
# cannot fabricate or move it. Limit DOM state updates while the player walks.
func _process(delta: float) -> void:
    frame_telemetry.sample_frame(delta)
    diagnostic_elapsed += delta
    if diagnostic_elapsed >= 0.6:
        diagnostic_elapsed = 0.0
        if show_diagnostics and diagnostic_label != null:
            diagnostic_label.text = frame_telemetry.display(locale)
    world_aim_elapsed += delta
    if world_aim_elapsed >= 0.21:
        world_aim_elapsed = 0.0
        _refresh_world_reticle()
    if not OS.has_feature("web") or stage_3d == null or stage_3d.first_person == null:
        return
    if not stage_3d.first_person.piloting:
        return
    _pilot_browser_elapsed += delta
    if _pilot_browser_elapsed >= 0.18:
        _pilot_browser_elapsed = 0.0
        _publish_web_accessibility()

func _web_rect(node: Control) -> Array:
    if node == null:
        return [0, 0, 0, 0]
    var rect: Rect2 = node.get_global_rect()
    return [roundi(rect.position.x), roundi(rect.position.y),
        roundi(rect.size.x), roundi(rect.size.y)]

func _publish_web_accessibility() -> void:
    if _web_state_element == null or stage_3d == null:
        return
    # Passive read-only gameplay state; browser tests must use actual
    # keyboard/canvas events to change the real game.
    var snapshot: Dictionary = model.snapshot()
    var stage_state: Dictionary = stage_3d.qa_readout()
    var state: Dictionary = {
        "schema": "LAST_FRONTIER_W64_REAL_GODOT_WEB_STATE",
        "locale": locale, "quality": quality,
        "reduced_motion": reduced_motion,
        "status": str(snapshot["status"]),
        "shift": int(snapshot["shift"]),
        "actions_left": int(snapshot["actions_left"]),
        "last_event": str(snapshot["last_event"]),
        "history_count": (snapshot["history"] as Array).size(),
        "metrics": snapshot["metrics"],
        "real_native_3d": bool(stage_state["actual_native_3d"]),
        "scene_meshes": int(stage_state["real_meshes"]),
        "scene_lights": int(stage_state["real_lights"]),
        "w66_hud": cinematic_hud != null,
        "w66_art_meshes": int(stage_state.get("art_geometry", 0)),
        "w67_cathedral_meshes": int(stage_state.get("cathedral_geometry", 0)),
        "w68_machined_hero_meshes": int(stage_state.get("w68_hero_geometry", 0)),
        "w68_smooth_parts": int(stage_state.get("w68_machined_torus", 0)),
        "w68_pbr_profiles": int(stage_state.get("w68_original_texture_profiles", 0)),
        "w68_genuine_texture_pixels": int(stage_state.get("w68_original_texture_pixels", 0)),
        "w68_restrained_hud": cinematic_hud != null and
            bool(cinematic_hud.qa_readout()["read_only"]),
        "w68_mobile_hud_compact": cinematic_hud != null and
            bool(cinematic_hud.qa_readout()["w68_compact_minimal"]),
        "w69_cinema_mode": cinema_mode,
        "w69_focus_mode": bool(stage_state.get("w69_focus", false)),
        "w69_focus_switches": int(stage_state.get("w69_focus_switches", 0)),
        "w69_in_world_machine_readouts": int(stage_state.get("w69_live_in_world_readouts", 0)),
        "w69_real_incident_shutters": int(stage_state.get("w69_real_hazard_shutters", 0)),
        "w69_visual_severity": float(stage_state.get("w69_visual_severity", 0.0)),
        "w69_real_action_reactions": int(stage_state.get("w69_cinema_actions", 0)),
        "w70_physical_operator": bool(stage_state.get("w70_first_person_enabled", false)),
        "w70_real_body_xyz": stage_state.get("w70_actual_player_position", []),
        "w70_real_physical_distance": float(stage_state.get("w70_actual_walk_distance", 0.0)),
        "w70_collision_shapes": int(stage_state.get("w70_real_collision_count", 0)),
        "w70_real_physics_frames": int(stage_state.get("w70_physics_frames", 0)),
        "w70_real_collisions": int(stage_state.get("w70_physics_contacts", 0)),
        "w70_inspections": int(stage_state.get("w70_player_inspections", 0)),
        "w70_last_inspected": str(stage_state.get("w70_last_machine_inspected", "")),
        "w70_true_headlamp": bool(stage_state.get("w70_headlamp_real", false)),
        "w70_true_industrial_bridge_meshes": int(stage_state.get("w70_true_3d_catwalk_meshes", 0)),
        "w70_real_practical_bay_lights": int(stage_state.get("w70_actual_walkway_lights", 0)),
        "w70_native_bridge_collision": bool(stage_state.get("w70_real_walkable_deck_collider", false)),
        "w71_mission_active": stage_3d.spatial_mission.active if stage_3d.spatial_mission != null else false,
        "w71_mission_phase": stage_3d.spatial_mission.phase if stage_3d.spatial_mission != null else -1,
        "w71_mission_complete": stage_3d.spatial_mission.qa_readout()["completed"] if stage_3d.spatial_mission != null else false,
        "w71_mission_failure": stage_3d.spatial_mission.qa_readout()["failed"] if stage_3d.spatial_mission != null else false,
        "w71_real_3d_mission": bool(stage_state.get("w71_real_objective_meshes", false)),
        "w71_mission_events": stage_3d.spatial_mission.progress_events if stage_3d.spatial_mission != null else 0,
        "w71_mission_physical_inspections": stage_3d.spatial_mission.real_inspections if stage_3d.spatial_mission != null else 0,
        "w71_mission_actions": stage_3d.spatial_mission.accepted_game_decisions if stage_3d.spatial_mission != null else 0,
        "w72_extended_mode": stage_3d.spatial_mission.extended_mode if stage_3d.spatial_mission != null else false,
        "w72_ops_active": stage_3d.field_operations.enabled if stage_3d.field_operations != null else false,
        "w72_active_mechanic": stage_3d.field_operations.active_mechanic() if stage_3d.field_operations != null else "inactive",
        "w72_valve_index": stage_3d.field_operations.valve_index if stage_3d.field_operations != null else 0,
        "w72_valve_target": stage_3d.field_operations.valve_target if stage_3d.field_operations != null else 0,
        "w72_valve_solved": stage_3d.field_operations.valve_solved if stage_3d.field_operations != null else false,
        "w72_relay_mask": stage_3d.field_operations.relay_mask if stage_3d.field_operations != null else 0,
        "w72_relay_target": stage_3d.field_operations.relay_target if stage_3d.field_operations != null else -1,
        "w72_relay_solved": stage_3d.field_operations.relay_solved if stage_3d.field_operations != null else false,
        "w72_sync_order": stage_3d.field_operations.sync_order.duplicate() if stage_3d.field_operations != null else [],
        "w72_sync_step": stage_3d.field_operations.sync_step if stage_3d.field_operations != null else 0,
        "w72_sync_solved": stage_3d.field_operations.sync_solved if stage_3d.field_operations != null else false,
        "w72_actual_mechanic_meshes": int(stage_state.get("w72_true_mechanic_meshes", 0)),
        "w72_physically_rejected_actions": stage_3d.field_operations.rejected_far_uses if stage_3d.field_operations != null else 0,
        "w72_contextual_real_camera_focuses": field_focus_events,
        "w72_thermal_camera_focused": field_focused_devices.has("thermal"),
        "w73_real_native_world_raycast": bool(stage_state.get("w73_true_eye_raycast", false)),
        "w73_real_collider_target_count": int(stage_state.get("w73_real_ray_targets", 0)),
        "w73_actual_world_ray_target": stage_3d.world_interaction.qa_readout()["actual_active_ray_target"] if stage_3d.world_interaction != null else "",
        "w73_actual_ray_physics_debug": stage_3d.world_interaction.qa_readout() if stage_3d.world_interaction != null else {},
        "w73_real_raycast_uses": stage_3d.world_interaction.accepted_world_uses if stage_3d.world_interaction != null else 0,
        "w73_rejected_world_uses": stage_3d.world_interaction.rejected_world_uses if stage_3d.world_interaction != null else 0,
        "w73_checkpoint_events": checkpoint.events.size(),
        "w73_checkpoint_saves": checkpoint.saves,
        "w73_checkpoint_restores": checkpoint.successful_restores,
        "w73_checkpoint_rejected": checkpoint.rejected_loads,
        "w73_checkpoint_status": checkpoint.last_status,
        "w74_true_3d_feedback_meshes": int(stage_state.get("w74_real_3d_feedback_meshes",0)),
        "w74_accepted_diegetic_world_actions": int(stage_state.get("w74_3d_mechanic_animations",0)),
        "w74_original_analog_axis_events": int(stage_state.get("w74_native_controller_motion_events",0)),
        "w74_original_analog_physics_frames": int(stage_state.get("w74_native_analog_player_movement_frames",0)),
        "w74_native_gamepad_event_routes": gamepad.actual_button_events,
        "w74_native_gamepad_action_choices": gamepad.original_actions_via_controller,
        "w74_native_gamepad_aimed_world_uses": gamepad.world_interactions_via_controller,
        "w74_native_gamepad_selected_action": gamepad.selected_action(),
        "w74_real_frame_time_samples": frame_telemetry.total_frames,
        "w74_real_frame_time_p95_ms": float(frame_telemetry.qa_readout()["window_p95_frame_ms"]),
        "w74_diagnostics_visible":show_diagnostics,
        "w74_hardware_gamepad_certified":false,
        "w76_actual_immersive_first_person":w76_immersive,
        "w76_real_play_button":w76_play_button != null,
        "w76_immersive_switches":w76_immersive_switches,
        "w76_true_world_wayfinder_meshes":int(stage_state.get("w76_actual_mission_wayfinder_meshes",0)),
        "w76_actual_wayfinding_target":str(stage_state.get("w76_real_mission_target","none")),
        "w76_world_objective_meters":float(stage_state.get("w76_real_target_distance",-1.0)),
        "w77_original_physical_sector_bulkhead":bool(stage_state.get("w77_true_physical_bulkhead",false)),
        "w77_original_mission_gate_locked":bool(stage_state.get("w77_physically_restricted_sector",false)),
        "w77_true_native_bulkhead_leaves":int(stage_state.get("w77_bulkhead_mesh_count",0)),
        "w77_true_bulkhead_open_events":int(stage_state.get("w77_real_bulkhead_openings",0)),
        "w77_native_door_open_ratio":float(stage_state.get("w77_real_door_open_ratio",0.0)),
        "w77_genuine_player_motion_focus_cancels":w77_focus_cancelled_by_actual_input,
        "w78_original_touch_movement_visible":w78_touch_overlay.visible if w78_touch_overlay != null else false,
        "w78_true_native_touch_button_count":w78_touch_overlay.controls.size() if w78_touch_overlay != null else 0,
        "w78_true_touch_physics_frames":w78_touch_overlay.live_touch_motion_frames if w78_touch_overlay != null else 0,
        "w78_touch_player_inputs":w78_touch_overlay.touch_press_events if w78_touch_overlay != null else 0,
        "w78_touch_look_frames":w78_touch_overlay.actual_continuous_look_frames if w78_touch_overlay != null else 0,
        "w78_touch_actual_world_G_actions":w78_touch_overlay.world_use_requests if w78_touch_overlay != null else 0,
        "w78_touch_actual_E_inspections":w78_touch_overlay.inspect_requests if w78_touch_overlay != null else 0,
        "w78_phone_hardware_approved":false,
        "w79_mobile_complete_mission_visible":w79_mission_deck.visible if w79_mission_deck != null else false,
        "w79_current_source_phase":w79_mission_deck.current_phase if w79_mission_deck != null else -1,
        "w79_source_based_mode":w79_mission_deck.current_mode if w79_mission_deck != null else "hidden",
        "w79_native_command_slots":w79_mission_deck.slots.size() if w79_mission_deck != null else 0,
        "w79_original_action_attempts":w79_mission_deck.original_core_action_requests if w79_mission_deck != null else 0,
        "w79_physical_equipment_attempts":w79_mission_deck.physical_equipment_request_count if w79_mission_deck != null else 0,
        "w79_actual_source_phase_changes":w79_mission_deck.actual_source_phase_changes if w79_mission_deck != null else 0,
        "w79_original_offline_save_requests":w79_mission_deck.save_requests if w79_mission_deck != null else 0,
        "w79_checked_load_requests":w79_mission_deck.load_requests if w79_mission_deck != null else 0,
        "w79_phone_hardware_certified":false,
        "w80_genuine_full_bleed_original_stage":w80_full_bleed.active if w80_full_bleed != null else false,
        "w80_full_3d_stage_area_fraction":float(w80_full_bleed.qa_readout()["native_stage_area_fraction"]) if w80_full_bleed != null else 0.0,
        "w80_real_subviewport_id_preserved":bool(w80_full_bleed.qa_readout()["original_real_3d_subviewport_unchanged"]) if w80_full_bleed != null else false,
        "w80_real_viewport_parent_changes":w80_full_bleed.real_reparent_events if w80_full_bleed != null else 0,
        "w80_reversible_screen_returns":w80_full_bleed.reversible_returns if w80_full_bleed != null else 0,
        "w80_physical_phone_hardware_certified":false,
        "w80_true_native_touch_grid_columns":w78_touch_overlay.rail.columns if w78_touch_overlay != null else 0,
        "w80_real_immersive_play_button_hidden":not w76_play_button.visible,
        "w80_redundant_long_objective_hidden":not w76_objective_label.visible,
        "w81_touch_landscape_enabled":w78_touch_overlay.landscape_layout if w78_touch_overlay != null else false,
        "w81_true_mobile_mission_and_full_bleed":(w80_full_bleed.active and
            w78_touch_overlay.visible and w79_mission_deck.visible)
            if w80_full_bleed != null and w78_touch_overlay != null and w79_mission_deck != null else false,
        "w81_real_phone_hardware_certified":false,
        "w82_native_navigation_visible":w82_nav_cockpit.visible if w82_nav_cockpit != null else false,
        "w82_source_phase":int(w82_nav_cockpit.qa_readout()["source_original_phase"]) if w82_nav_cockpit != null else -1,
        "w82_source_target":str(w82_nav_cockpit.qa_readout()["source_target_kind"]) if w82_nav_cockpit != null else "none",
        "w82_real_player_body_id":int(w82_nav_cockpit.qa_readout()["real_player_body_id"]) if w82_nav_cockpit != null else 0,
        "w82_real_goal_distance_m":float(w82_nav_cockpit.qa_readout()["real_distance_m"]) if w82_nav_cockpit != null else -1.0,
        "w82_real_device_proximity":bool(w82_nav_cockpit.qa_readout()["true_physical_device_near"]) if w82_nav_cockpit != null else false,
        "w82_navigation_source_redraws":int(w82_nav_cockpit.qa_readout()["real_source_redraws"]) if w82_nav_cockpit != null else 0,
        "w82_compass_source_label":str(w82_nav_cockpit.qa_readout()["label"]) if w82_nav_cockpit != null else "",
        "w82_compass_source_guidance":str(w82_nav_cockpit.qa_readout()["guidance"]) if w82_nav_cockpit != null else "",
        "w82_no_automatic_gameplay":true,
        "w82_real_phone_hardware_certified":false,
        "w83_real_multitouch_active":w83_dual_touch.visible if w83_dual_touch != null else false,
        "w83_real_drag_events":w83_dual_touch.physical_look_drags if w83_dual_touch != null else 0,
        "w83_real_camera_rotations":w83_dual_touch.real_camera_rotations if w83_dual_touch != null else 0,
        "w83_touch_claimed":w83_dual_touch.touch_begins if w83_dual_touch != null else 0,
        "w83_active_look_finger":w83_dual_touch.look_finger if w83_dual_touch != null else -1,
        "w83_touch_release_events":w83_dual_touch.released_fingers if w83_dual_touch != null else 0,
        "w83_touch_release_position_recovers":w83_dual_touch.recovered_end_by_position if w83_dual_touch != null else 0,
        "w83_touch_release_timeout_recovers":w83_dual_touch.recovered_missing_end_timeout if w83_dual_touch != null else 0,
        "w83_source_active_walk_fingers":w83_dual_touch.source_walk_fingers.size() if w83_dual_touch != null else 0,
        "w83_source_walk_touch_starts":w83_dual_touch.actual_walk_touch_starts if w83_dual_touch != null else 0,
        "w83_source_walk_touch_ends":w83_dual_touch.actual_walk_touch_ends if w83_dual_touch != null else 0,
        "w83_real_walk_reassert_frames":w83_dual_touch.original_walk_reassert_frames if w83_dual_touch != null else 0,
        "w83_source_yaw":float(w83_dual_touch.qa_readout()["actual_source_yaw"]) if w83_dual_touch != null else 0.0,
        "w83_source_pitch":float(w83_dual_touch.qa_readout()["actual_source_pitch"]) if w83_dual_touch != null else 0.0,
        "w83_real_UI_touches_not_intercepted":w83_dual_touch.rejected_ui_starts if w83_dual_touch != null else 0,
        "w83_original_body_preserved":bool(w83_dual_touch.qa_readout()["original_source_characterbody_preserved"]) if w83_dual_touch != null else false,
        "w83_phone_hardware_approved":false,
        "w67_two_3d_sectors": bool(stage_state.get("cathedral_two_real_sectors", false)),
        "w67_inspection_sector": int(stage_state.get("inspection_sector", 0)),
        "w67_walk_progress": float(stage_state.get("inspection_progress", 0.0)),
        "w67_nav_steps": int(stage_state.get("inspection_navigation_moves", 0)),
        "w67_mobile_world_text_hidden": bool(stage_state.get("mobile_world_text_hidden", false)),
        "w67_relay_fov": float(stage_state.get("relay_framed_fov", 52.0)),
        "renderer_camera": int(stage_state["camera"]),
        "energy_gauge": float(stage_3d.energy_gauge.scale.y),
        "renderer_frames": Engine.get_frames_drawn(),
        "hardware_certified": false,
        "narrative_id": str(A7IncidentDirector.describe(locale, snapshot).get("id", "")),
        "sound_muted": bool(sound_bus.muted) if sound_bus != null else true,
        "sound_cues": int(sound_bus.accepted_cues) if sound_bus != null else 0,
    }
    var geometry: Dictionary = {
        "viewport": [roundi(size.x), roundi(size.y)],
        "stage": _web_rect(stage_shell),
        "stage_requested_height": roundi(stage_shell.custom_minimum_size.y),
        "cinema_caption": _web_rect(cinema_caption),
        "cinema_inner": _web_rect(stage_shell.get_parent() as Control),
        "cinema_panel": _web_rect(stage_shell.get_parent().get_parent() as Control),
        "subtitle": _web_rect(subtitle),
        "intro": _web_rect(intro),
        "brand": _web_rect(brand_label),
        "reset": _web_rect(restart_button),
        "language": _web_rect(language_button),
        "quality": _web_rect(quality_button),
        "motion": _web_rect(motion_button),
        "sound": _web_rect(sound_button),
        "cinema": _web_rect(cinema_button),
        "optics": _web_rect(focus_button),
        "pilot": _web_rect(pilot_button),
        "pilot_inspect": _web_rect(pilot_inspect_button),
        "mission_start": _web_rect(mission_button),
        "extended_start": _web_rect(field_start_button),
        "field_help": _web_rect(field_help),
        "world_use": _web_rect(world_use_button),
        "world_reticle": _web_rect(world_reticle),
        "checkpoint_save": _web_rect(save_button),
        "checkpoint_load": _web_rect(load_button),
        "controller_hint": _web_rect(controller_hint_label),
        "w76_play":_web_rect(w76_play_button),
        "w76_immersive":_web_rect(w76_focus_button),
        "w76_current_goal":_web_rect(w76_objective_label),
        "w78_true_touch_forward":_web_rect(w78_touch_overlay.controls["forward"] as Control) if w78_touch_overlay != null else [],
        "w78_true_touch_world_use":_web_rect(w78_touch_overlay.controls["world_use"] as Control) if w78_touch_overlay != null else [],
        "w78_true_touch_inspect":_web_rect(w78_touch_overlay.controls["inspect"] as Control) if w78_touch_overlay != null else [],
        "w79_context_title":_web_rect(w79_mission_deck.headline) if w79_mission_deck != null else [],
        "w79_command0":_web_rect(w79_mission_deck.slots[0]) if w79_mission_deck != null else [],
        "w79_command1":_web_rect(w79_mission_deck.slots[1]) if w79_mission_deck != null else [],
        "w79_command2":_web_rect(w79_mission_deck.slots[2]) if w79_mission_deck != null else [],
        "w79_command3":_web_rect(w79_mission_deck.slots[3]) if w79_mission_deck != null else [],
        "w79_command4":_web_rect(w79_mission_deck.slots[4]) if w79_mission_deck != null else [],
        "w79_offline_save":_web_rect(w79_mission_deck.save_button) if w79_mission_deck != null else [],
        "w79_checked_load":_web_rect(w79_mission_deck.load_button) if w79_mission_deck != null else [],
        "w80_touch_left":_web_rect(w78_touch_overlay.controls["left"] as Control) if w78_touch_overlay != null else [],
        "w80_touch_back":_web_rect(w78_touch_overlay.controls["back"] as Control) if w78_touch_overlay != null else [],
        "w80_touch_right":_web_rect(w78_touch_overlay.controls["right"] as Control) if w78_touch_overlay != null else [],
        "w80_touch_look_left":_web_rect(w78_touch_overlay.controls["look_left"] as Control) if w78_touch_overlay != null else [],
        "w80_touch_look_right":_web_rect(w78_touch_overlay.controls["look_right"] as Control) if w78_touch_overlay != null else [],
        "w80_native_touch_rail":_web_rect(w78_touch_overlay.rail) if w78_touch_overlay != null else [],
        "w80_native_mission_panel":_web_rect(w79_mission_deck.panel) if w79_mission_deck != null else [],
        "w82_native_compass_hud":_web_rect(w82_nav_cockpit.frame) if w82_nav_cockpit != null else [],
        "w82_nav_label":_web_rect(w82_nav_cockpit.title_label) if w82_nav_cockpit != null else [],
        "w83_camera_swipe_hint":_web_rect(w83_dual_touch.hint_label) if w83_dual_touch != null else [],
        "w80_true_native_menu":_web_rect(w80_full_bleed.exit_button) if w80_full_bleed != null else [],
        "w80_true_native_language":_web_rect(w80_full_bleed.language_button) if w80_full_bleed != null else [],
        "frame_diagnostics": _web_rect(diagnostic_label),
        "mission_title": _web_rect(mission_title),
        "mission_briefing": _web_rect(mission_briefing),
        "walk_back": _web_rect(route_buttons[0]),
        "walk_forward": _web_rect(route_buttons[1]),
        "sector_0": _web_rect(sector_buttons[0]),
        "sector_1": _web_rect(sector_buttons[1]),
        "story": _web_rect(narrative_title),
        "forecast": _web_rect(forecast_label),
        "scroll": int(scroll.scroll_vertical),
    }
    for i in range(camera_buttons.size()):
        geometry["camera%d" % i] = _web_rect(camera_buttons[i])
    for key in ACTION_ORDER:
        geometry["action_" + key.to_lower()] = _web_rect(action_buttons[key] as Control)
    _web_state_element.setAttribute("data-state", JSON.stringify(state))
    _web_state_element.setAttribute("data-geometry", JSON.stringify(geometry))
    _web_state_element.textContent = (
        "A7 simulation. " + str(snapshot["status"]) +
        ". Cycle " + str(int(snapshot["shift"]) + 1) +
        ". Actions left " + str(snapshot["actions_left"]))
