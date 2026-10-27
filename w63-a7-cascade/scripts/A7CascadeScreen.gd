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
    "keys": "1-5: ДЕЙСТВИЯ  |  C: КАМЕРА  |  Q: КАЧЕСТВО  |  M: АНИМАЦИЯ  |  L: ЯЗЫК  |  R: ПЕРЕЗАПУСК",
    "objective": "ЦЕЛЬ: ТЕПЛО И ДАВЛЕНИЕ <= 75; ГЕРМЕТИЧНОСТЬ И СИГНАЛ >= 50; ЭНЕРГИЯ >= 30; ЦЕЛОСТНОСТЬ >= 55.",
    "stage": "A7 / ЖИВАЯ 3D-КАМЕРА  •  ВЫМЫШЛЕННЫЙ ОБЪЕКТ",
    "camera0": "01 / ОБЩИЙ", "camera1": "02 / ФРОНТ", "camera2": "03 / БОКОВОЙ",
    "quality_hero": "ГРАФИКА / HERO", "quality_eco": "ГРАФИКА / ECO",
    "motion_on": "АНИМАЦИЯ / ВКЛ", "motion_off": "АНИМАЦИЯ / ВЫКЛ",
    "visual": "ТЕПЛО %d   •   ДАВЛЕНИЕ %d   •   ЭНЕРГИЯ %d",
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
    "keys": "1-5: ACTIONS  |  C: CAMERA  |  Q: QUALITY  |  M: MOTION  |  L: LANGUAGE  |  R: RESTART",
    "objective": "TARGET: HEAT AND PRESSURE <= 75; SEAL AND SIGNAL >= 50; ENERGY >= 30; CONTAINMENT >= 55.",
    "stage": "A7 / TRUE NATIVE 3D VIEW  •  FICTIONAL FACILITY",
    "camera0": "01 / WIDE", "camera1": "02 / FRONT", "camera2": "03 / SIDE",
    "quality_hero": "QUALITY / HERO", "quality_eco": "QUALITY / ECO",
    "motion_on": "MOTION / ON", "motion_off": "MOTION / OFF",
    "visual": "HEAT %d   •   PRESSURE %d   •   ENERGY %d",
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

func _ready() -> void:
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _build()
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
    # W64 visual hierarchy: place the real reactor above explanatory copy.
    # First-time visitors must see gameplay at the top of the viewport.
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
    subtitle = _label(body, "", 15, MINT)
    intro = _label(body, "", 15, MUTED)

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
    # Real UI action drives the original deterministic game FIRST;
    # the 3D stage reacts only to an accepted command.
    if model.choose(action) and stage_3d != null:
        stage_3d.trigger_action(action)
        call_deferred("_publish_web_accessibility")

func _restart() -> void:
    model.reset()
    if stage_3d != null:
        stage_3d.recent_action = ""
        stage_3d.pulse = 0.0

func _select_camera(index: int) -> void:
    if stage_3d != null:
        stage_3d.set_camera(index)
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
    }
    var geometry: Dictionary = {
        "viewport": [roundi(size.x), roundi(size.y)],
        "stage": _web_rect(stage_shell),
        "brand": _web_rect(brand_label),
        "reset": _web_rect(restart_button),
        "language": _web_rect(language_button),
        "quality": _web_rect(quality_button),
        "motion": _web_rect(motion_button),
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
