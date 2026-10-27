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
    "keys": "1-5: ДЕЙСТВИЯ  |  F: ХОДЬБА  |  E: ПУЛЬТ  |  C: КАМЕРА  |  Q: КАЧЕСТВО  |  M: АНИМАЦИЯ  |  L: ЯЗЫК  |  S: ЗВУК/ШАГ НАЗАД  |  R: ЗАНОВО",
    "objective": "ЦЕЛЬ: ТЕПЛО И ДАВЛЕНИЕ <= 75; ГЕРМЕТИЧНОСТЬ И СИГНАЛ >= 50; ЭНЕРГИЯ >= 30; ЦЕЛОСТНОСТЬ >= 55.",
    "stage": "A7 / ЖИВАЯ 3D-КАМЕРА  •  ВЫМЫШЛЕННЫЙ ОБЪЕКТ",
    "camera0": "01 / ОБЩИЙ", "camera1": "02 / ФРОНТ", "camera2": "03 / БОКОВОЙ",
    "quality_hero": "ГРАФИКА / HERO", "quality_eco": "ГРАФИКА / ECO",
    "motion_on": "АНИМАЦИЯ / ВКЛ", "motion_off": "АНИМАЦИЯ / ВЫКЛ",
    "visual": "ТЕПЛО %d   •   ДАВЛЕНИЕ %d   •   ЭНЕРГИЯ %d",
    "sound_on": "ЗВУК / ВКЛ", "sound_off": "ЗВУК / ВЫКЛ",
    "preview_default": "ВЫБЕРИТЕ ДЕЙСТВИЕ: ПОСЛЕДСТВИЯ ПОКАЗАНЫ В ИГРОВЫХ ЕДИНИЦАХ.",
    "walk_enter": "F / ПРОЙТИ В КОМПЛЕКС", "walk_exit": "F / ОБЩАЯ КАМЕРА",
    "walk_forward": "↑ ВПЕРЁД", "walk_back": "↓ НАЗАД",
    "walk_left": "← ВЛЕВО", "walk_right": "→ ВПРАВО",
    "walk_use": "E / ИСПОЛЬЗОВАТЬ ПУЛЬТ",
    "walk_coolant": "ОТСЕК ОХЛАЖДЕНИЯ", "walk_pressure": "ОТСЕК ДАВЛЕНИЯ",
    "walk_central": "ЦЕНТРАЛЬНЫЙ УЗЕЛ",
    "walk_status": "ОПЕРАТОР: %s  •  ДЕЙСТВИЕ E: %s",
    "walk_hint": "WASD / ХОДЬБА  •  E / РАБОТА С ПУЛЬТОМ  •  F / КАМЕРА",
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
    "keys": "1-5: ACTIONS  |  F: WALK  |  E: CONSOLE  |  C: CAMERA  |  Q: QUALITY  |  M: MOTION  |  L: LANGUAGE  |  S: SOUND/BACK  |  R: RESTART",
    "objective": "TARGET: HEAT AND PRESSURE <= 75; SEAL AND SIGNAL >= 50; ENERGY >= 30; CONTAINMENT >= 55.",
    "stage": "A7 / TRUE NATIVE 3D VIEW  •  FICTIONAL FACILITY",
    "camera0": "01 / WIDE", "camera1": "02 / FRONT", "camera2": "03 / SIDE",
    "quality_hero": "QUALITY / HERO", "quality_eco": "QUALITY / ECO",
    "motion_on": "MOTION / ON", "motion_off": "MOTION / OFF",
    "visual": "HEAT %d   •   PRESSURE %d   •   ENERGY %d",
    "sound_on": "SOUND / ON", "sound_off": "SOUND / OFF",
    "preview_default": "CHOOSE AN ACTION: FORECASTS ARE FICTIONAL GAME UNITS.",
    "walk_enter": "F / ENTER FACILITY", "walk_exit": "F / CINEMATIC VIEW",
    "walk_forward": "↑ FORWARD", "walk_back": "↓ BACK",
    "walk_left": "← LEFT", "walk_right": "→ RIGHT",
    "walk_use": "E / USE CONSOLE",
    "walk_coolant": "COOLANT BAY", "walk_pressure": "PRESSURE BAY",
    "walk_central": "CENTRAL CORE",
    "walk_status": "OPERATOR: %s  •  E ACTION: %s",
    "walk_hint": "WASD / WALK  •  E / USE CONSOLE  •  F / CAMERA",
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
# W67 optional real first-person 3D operator. Original W63 rules untouched.
var walk_button: Button
var walk_action_button: Button
var walk_status: Label
var walk_direction_buttons: Dictionary = {}
var _walk_direction_state: Dictionary = {
    "forward": false, "back": false, "left": false, "right": false
}
var _walk_report_elapsed: float = 0.0

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
    skin.bg_color = PANEL
    skin.border_color = BORDER
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(10)
    skin.set_content_margin_all(16)
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
    b.add_theme_font_size_override("font_size", 14)
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
    walk_button = _button(cinema_controls, "", _toggle_walk)
    walk_button.name = "A7TrueFirstPersonModeToggle"
    walk_button.custom_minimum_size = Vector2(174, 42)
    walk_action_button = _button(cinema_controls, "", _walk_interact)
    walk_action_button.name = "A7PhysicalContextConsoleAction"
    walk_action_button.custom_minimum_size = Vector2(176, 42)
    var walk_controls := HFlowContainer.new()
    walk_controls.name = "A7ActualHoldToMoveMobileRail"
    walk_controls.add_theme_constant_override("h_separation", 8)
    walk_controls.add_theme_constant_override("v_separation", 8)
    cinema.add_child(walk_controls)
    for direction in ["forward", "back", "left", "right"]:
        var movement := Button.new()
        movement.name = "A7Move_" + direction
        movement.focus_mode = Control.FOCUS_ALL
        movement.custom_minimum_size = Vector2(111, 43)
        movement.button_down.connect(_set_walk_direction.bind(direction, true))
        movement.button_up.connect(_set_walk_direction.bind(direction, false))
        walk_controls.add_child(movement)
        walk_direction_buttons[direction] = movement
    walk_status = _label(cinema, "", 12, MINT)
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
        if stage_3d.operator_rig != null:
            stage_3d.operator_rig.reset_operator()
        _clear_walk_directions()

func _clear_walk_directions() -> void:
    for key in ["forward", "back", "left", "right"]:
        _walk_direction_state[key] = false
    if stage_3d != null and stage_3d.operator_rig != null:
        stage_3d.operator_rig.set_move_intent(Vector2.ZERO)

func _set_walk_direction(direction: String, pressed: bool) -> void:
    if not _walk_direction_state.has(direction):
        return
    _walk_direction_state[direction] = pressed
    if stage_3d == null or not stage_3d.walk_mode:
        return
    var dx: float = float(int(_walk_direction_state["right"]) -
        int(_walk_direction_state["left"]))
    var dz: float = float(int(_walk_direction_state["forward"]) -
        int(_walk_direction_state["back"]))
    stage_3d.operator_rig.set_move_intent(Vector2(dx, dz))

func _toggle_walk() -> void:
    if stage_3d == null:
        return
    stage_3d.set_walk_mode(not stage_3d.walk_mode)
    _clear_walk_directions()
    _render(model.snapshot())

func _walk_interact() -> void:
    if stage_3d == null or not stage_3d.walk_mode:
        return
    var nearby_action: String = stage_3d.operator_rig.context_action()
    if nearby_action != "":
        _on_action(nearby_action)
    _render(model.snapshot())

func _refresh_walk_status() -> void:
    if walk_status == null or stage_3d == null:
        return
    var exploring: bool = stage_3d.walk_mode
    walk_button.text = _t("walk_exit" if exploring else "walk_enter")
    walk_action_button.text = _t("walk_use")
    walk_action_button.disabled = not exploring or str(model.snapshot()["status"]) != "playing"
    for direction in walk_direction_buttons.keys():
        var button: Button = walk_direction_buttons[direction] as Button
        button.text = _t("walk_" + str(direction))
        button.disabled = not exploring
    if exploring:
        var readout: Dictionary = stage_3d.operator_rig.qa_readout()
        walk_status.text = _t("walk_status") % [
            _t("walk_" + str(readout["sector"])), str(readout["context_action"])]
    else:
        walk_status.text = _t("walk_hint")

func _process(delta: float) -> void:
    if stage_3d == null or not stage_3d.walk_mode:
        return
    _walk_report_elapsed += delta
    if _walk_report_elapsed >= 0.16:
        _walk_report_elapsed = 0.0
        _refresh_walk_status()
        _publish_web_accessibility()

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
        _clear_walk_directions()
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
    visual_container.custom_minimum_size = Vector2(0, height)
    visual_container.stretch_shrink = 2 if quality == "eco" else 1
    var compact: bool = size.x < 640.0
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
        (metric_bars[key] as ProgressBar).value = value
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
