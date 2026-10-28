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
    "preview_default": "CHOOSE AN ACTION: FORECASTS ARE FICTIONAL GAME UNITS.",
}

var model: A7CascadeCore = A7CascadeCore.new()
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
var scroll: ScrollContainer
var _web_state_element: Variant = null
# W65 new standalone narrative and original procedural sound (no external files).
var sound_bus: A7ProceduralAudio
var sound_button: Button
var narrative_title: Label
var narrative_body: Label
var forecast_label: Label
var _previewed_action: String = ""

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build()
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
    brand_label = _label(top, "", 27, GOLD)
    language_button = _button(top, "EN", _toggle_locale)
    language_button.custom_minimum_size = Vector2(90, 45)
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
    cinema_readout = _label(cinema, "", 12, MINT)
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
    subtitle = _label(body, "", 15, MINT)
    intro = _label(body, "", 15, MUTED)

    # Original story beats are generated from actual game shift/status;
    # never play fake cutscenes that are independent of the player's choices.
    var narrative_panel := _panel(body)
    narrative_panel.name = "A7TrueStateIncidentBriefing"
    narrative_title = _label(narrative_panel, "", 17, GOLD)
    narrative_body = _label(narrative_panel, "", 14, WHITE)
    forecast_label = _label(narrative_panel, "", 12, MINT)

    var status_box := _panel(body)
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
    model.reset()
    if sound_bus != null:
        sound_bus.cue("restart")
    if stage_3d != null:
        stage_3d.recent_action = ""
        stage_3d.pulse = 0.0

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
    stage_shell.custom_minimum_size = Vector2(0, height)
    if cinematic_hud != null:
        cinematic_hud._relayout()
    visual_container.custom_minimum_size = Vector2(0, height)
    visual_container.stretch_shrink = 2 if quality == "eco" else 1
    var compact: bool = size.x < 640.0
    if stage_3d != null:
        stage_3d.set_compact_view(compact)
    if cinematic_hud != null:
        cinematic_hud.set_compact_mode(compact)
    for view in camera_buttons:
        view.custom_minimum_size.x = 84.0 if compact else 118.0
    if compact:
        quality_button.custom_minimum_size.x = 136.0
        motion_button.custom_minimum_size.x = 136.0
    call_deferred("_publish_web_accessibility")

func _toggle_locale() -> void:
    locale = "en" if locale == "ru" else "ru"
    _render(model.snapshot())

func _unhandled_key_input(event: InputEvent) -> void:
    if not (event is InputEventKey):
        return
    var key: InputEventKey = event as InputEventKey
    if not key.pressed or key.echo:
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
    brand_label.text = _t("brand")
    subtitle.text = _t("sub")
    intro.text = _t("intro")
    language_button.text = _t("language")
    restart_button.text = _t("reset")
    var story: Dictionary = A7IncidentDirector.describe(locale, state)
    narrative_title.text = str(story.get("title", ""))
    narrative_body.text = str(story.get("body", ""))
    _update_forecast(state)
    sound_button.text = _t("sound_off" if sound_bus != null and sound_bus.muted else "sound_on")
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
    footnote.text = _t("disclaimer") + "\n" + _t("keys")
    if cinematic_hud != null:
        cinematic_hud.present(state, locale)
    if stage_3d != null:
        stage_3d.apply_snapshot(state)
        cinema_caption.text = _t("stage")
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
