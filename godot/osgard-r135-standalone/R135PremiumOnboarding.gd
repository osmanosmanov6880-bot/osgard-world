extends Control
## OSGARD R135 / approved luxury UI art direction, implemented as real Godot UI.
## No external images, invented controls, remote commands or fabricated telemetry.
## Six guided chapters control the EXISTING safety-first simulation.
const TITLES_RU = [
    "ПЕРВОЕ ЗНАКОМСТВО", "ОСМОТР УСТАНОВКИ", "БЕЗОПАСНОЕ ОБСЛУЖИВАНИЕ",
    "ДИАГНОСТИКА ОПТИКИ", "ТРИ НЕИСПРАВНОСТИ", "ИТОГ И РЕЗУЛЬТАТЫ"
]
const TITLES_EN = [
    "FIRST CONTACT", "INSPECT THE MACHINE", "SAFETY-FIRST SERVICE",
    "OPTICAL DIAGNOSTICS", "THREE FAULT SCENARIOS", "RESULTS AND REVIEW"
]
const DETAILS_RU = [
    "Вы — новый инженер учебной лаборатории OSGARD. Изучите управление, осмотрите установку и пройдите настоящие игровые сценарии диагностики. Это симуляция, а не инструкция для работы с действующим оборудованием.",
    "Осмотрите промышленную линию с разных сторон. Смените ракурс кнопкой внизу или клавишей V. Камеру можно вращать мышью или касанием, масштаб — колёсиком или жестом.",
    "Сначала остановите привод, затем откройте сервисный люк. Закройте его и дождитесь полного запирания перед запуском. Защита должна отклонять опасный порядок действий.",
    "Запустите диагностический сценарий. Остановите привод, откройте люк, дождитесь открытия, выберите подсвеченный узел и сканируйте его. Затем закройте люк и безопасно возобновите работу.",
    "Повторите диагностику для трёх учебных неисправностей: оптика, охлаждение и блокировка люка. Для каждой выполняйте настоящий игровой порядок действий и проверяйте обратную связь.",
    "Сравните результат трёх сценариев, оцените ошибки и время. Пройденные учебные кейсы сохраняются только на вашем устройстве. Любое действие с реальной техникой требует допуска и полной энергетической изоляции."
]
const DETAILS_EN = [
    "You are the new OSGARD training-lab engineer. Learn the controls, inspect the machine and finish real simulated diagnostics. This is a game, NOT a real-equipment maintenance guide.",
    "Inspect the industrial line from different viewpoints. Use NEXT VIEW or V. Drag the camera with mouse/touch; use wheel or pinch to zoom.",
    "Stop the drive BEFORE opening the service hatch. Close it and wait until fully sealed before restarting. Unsafe action order must be blocked.",
    "Start a diagnostic case. Stop the drive, open the hatch, wait for full travel, choose the highlighted view and scan. Close and safely restart.",
    "Complete all three simulated cases: optics, cooling and hatch interlock. Each uses real game input and gives safety feedback.",
    "Review your results, elapsed time and errors. Records remain local on your device. Real machinery demands authorization and verified energy isolation."
]
const HELP_RU = [
    "НАЧНИТЕ С КНОПКИ НИЖЕ. 6 учебных глав, без пропуска правил безопасности.",
    "ПОДСКАЗКА: V — ракурс, мышь или палец — камера, колесо или жест — масштаб.",
    "ПОРЯДОК: остановка → открытие → закрытие → полная фиксация → пуск.",
    "ПОРЯДОК: остановка → люк → ракурс → сканирование → закрытие → пуск.",
    "ПОДСКАЗКА: правильный ракурс указан в задании. Подсвеченный индикатор показывает учебную неисправность.",
    "ВЫ ПРОШЛИ УЧЕБНУЮ ЛАБОРАТОРИЮ. Изучите результаты и повторите испытания для улучшения счёта."
]
const HELP_EN = [
    "START BELOW. Six chapters; safety rules cannot be bypassed.",
    "TIP: V for viewpoints, mouse or touch to orbit; wheel/pinch to zoom.",
    "ORDER: stop → open → close → fully seal → restart.",
    "ORDER: stop → hatch → correct viewpoint → scan → close → restart.",
    "TIP: the objective shows the required camera. The lit marker shows the simulated fault.",
    "TRAINING COMPLETE. Review your results and repeat challenges to improve your score."
]
const SAVE_PATH = "user://r135_luxury_tutorial_v1.cfg"
const R135LearningCoach = preload("res://R135LearningCoach.gd")
var host: Node3D
var locale: String = "ru"
var begun: bool = false
var finished: bool = false
var expanded: bool = true
var step: int = 0
var state_cache: Dictionary = {}
var view_cache: int = 0
var brand: PanelContainer
var brand_title: Label
var brand_subtitle: Label
var language_button: Button
var collapse_button: Button
var card: PanelContainer
var rail: PanelContainer
var compact_status: PanelContainer
var compact_status_clip: Control
var compact_status_title: Label
var compact_status_detail: Label
var compact_status_safety: Label
var eyebrow: Label
var title_label: Label
var description_label: Label
var hint_label: Label
var metrics_label: Label
var safety_label: Label
var primary_button: Button
var guide_button: Button
var rail_header: Label
var rail_rows: Array[Label] = []
var controls_open: bool = false
var coach_expanded: bool = false
var coach_last_status: String = "intro"
var coach_heading: Label
var coach_summary: Label
var coach_more_button: Button
var coach_detail: Label
var settings_open: bool = false
var brand_header: HBoxContainer
var settings_button: Button
var settings_panel: PanelContainer
var settings_clip: Control
var settings_scroll: ScrollContainer
var settings_title: Label
var settings_note: Label
var settings_quality_button: Button
var settings_motion_button: Button
var settings_close_button: Button

func _ready() -> void:
    name = "R135LuxuryTraining"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _build()
    _load_progress()
    _present()
    get_viewport().size_changed.connect(_layout)
    call_deferred("_layout")

func _glass(accent: bool = false) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.014, 0.022, 0.032, 0.94)
    s.border_color = Color(0.75, 0.44, 0.22, 0.88) if accent else Color(0.25, 0.36, 0.43, 0.82)
    s.set_border_width_all(1)
    s.set_corner_radius_all(12)
    s.set_content_margin_all(14)
    s.shadow_color = Color(0.0, 0.0, 0.0, 0.40)
    s.shadow_size = 12
    return s

func _button_style(primary: bool = false, hover: bool = false) -> StyleBoxFlat:
    var s := StyleBoxFlat.new()
    s.bg_color = Color(0.62, 0.29, 0.10, 0.97) if primary else Color(0.050, 0.090, 0.12, 0.97)
    if hover:
        s.bg_color = Color(0.87, 0.44, 0.17, 1.0) if primary else Color(0.10, 0.18, 0.22, 1.0)
    s.border_color = Color(1.0, 0.63, 0.34, 0.96) if primary else Color(0.28, 0.54, 0.62, 0.86)
    s.set_border_width_all(1)
    s.set_corner_radius_all(8)
    s.set_content_margin_all(10)
    return s

func _label(parent: Node, color: Color, font_size: int) -> Label:
    var l := Label.new()
    l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    l.add_theme_color_override("font_color", color)
    l.add_theme_font_size_override("font_size", font_size)
    parent.add_child(l)
    return l

func _styled_button(text_value: String, primary: bool) -> Button:
    var b := Button.new()
    b.text = text_value
    b.focus_mode = Control.FOCUS_ALL
    b.clip_text = true
    b.custom_minimum_size = Vector2(0, 46)
    b.add_theme_font_size_override("font_size", 15)
    b.add_theme_color_override("font_color", Color(0.97, 0.98, 0.97))
    b.add_theme_stylebox_override("normal", _button_style(primary))
    b.add_theme_stylebox_override("hover", _button_style(primary, true))
    b.add_theme_stylebox_override("pressed", _button_style(primary, true))
    b.add_theme_stylebox_override("focus", _button_style(false, true))
    return b

func _build() -> void:
    brand = PanelContainer.new()
    brand.name = "LuxuryBrandHeader"
    brand.add_theme_stylebox_override("panel", _glass())
    add_child(brand)
    var header := HBoxContainer.new()
    brand_header = header
    header.add_theme_constant_override("separation", 9)
    brand.add_child(header)
    var icon: Control = preload("res://R135PremiumEmblem.gd").new()
    icon.custom_minimum_size = Vector2(50, 50)
    header.add_child(icon)
    var headings := VBoxContainer.new()
    headings.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    headings.add_theme_constant_override("separation", 0)
    header.add_child(headings)
    brand_title = _label(headings, Color(0.95, 0.96, 0.97), 23)
    brand_title.text = "O S G A R D"
    brand_subtitle = _label(headings, Color(0.97, 0.57, 0.30), 12)
    brand_subtitle.text = "S E R V I C E   L A B"
    language_button = _styled_button("EN", false)
    language_button.name = "LuxurySwitchLanguage"
    language_button.custom_minimum_size = Vector2(52, 46)
    language_button.pressed.connect(_switch_language)
    header.add_child(language_button)
    settings_button = _styled_button("SET", false)
    settings_button.name = "LuxuryOpenPlayerSettings"
    settings_button.custom_minimum_size = Vector2(46, 46)
    settings_button.pressed.connect(_toggle_settings)
    header.add_child(settings_button)
    collapse_button = _styled_button("−", false)
    collapse_button.name = "LuxuryToggleGuide"
    collapse_button.custom_minimum_size = Vector2(46, 46)
    collapse_button.pressed.connect(_toggle_expanded)
    header.add_child(collapse_button)

    # The old W18 free-floating status container has a stale offscreen height
    # when hidden/revealed after WebGL viewport changes. Replace it visually
    # with a bounded luxury live readout rather than showing a 6,000px pane.
    compact_status = PanelContainer.new()
    compact_status.name = "LuxuryCompactLiveStatus"
    compact_status.add_theme_stylebox_override("panel", _glass())
    add_child(compact_status)
    # PanelContainer inherits its child's minimum height. Three auto-wrapping
    # labels previously inflated a visually hidden status to 2806 / 6306
    # pixels on actual desktop/landscape WebGL, obscuring the usable scene.
    # A plain Control breaks that minimum-size propagation while clipping
    # overflowing text; the outer PanelContainer remains a true hit-tested UI.
    compact_status_clip = Control.new()
    compact_status_clip.name = "LuxuryStatusViewport"
    compact_status_clip.clip_contents = true
    compact_status_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    compact_status.add_child(compact_status_clip)
    var status_stack := VBoxContainer.new()
    status_stack.name = "LuxuryBoundedLiveLines"
    status_stack.add_theme_constant_override("separation", 7)
    compact_status_clip.add_child(status_stack)
    compact_status_title = _label(status_stack, Color(0.97, 0.67, 0.41), 15)
    compact_status_detail = _label(status_stack, Color(0.89, 0.94, 0.96), 14)
    compact_status_safety = _label(status_stack, Color(0.55, 0.84, 0.90), 11)
    # Status is deliberately short, not a second expanding training article.
    # Full safety instructions and diagnostic logs remain available in guide.
    for line in [compact_status_title, compact_status_safety]:
        line.autowrap_mode = TextServer.AUTOWRAP_OFF
        line.max_lines_visible = 1
        line.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    compact_status_detail.max_lines_visible = 2
    compact_status_detail.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS

    card = PanelContainer.new()
    card.name = "LuxuryTrainingCard"
    card.add_theme_stylebox_override("panel", _glass(true))
    add_child(card)
    var stack := VBoxContainer.new()
    stack.add_theme_constant_override("separation", 8)
    card.add_child(stack)
    eyebrow = _label(stack, Color(0.98, 0.58, 0.29), 12)
    title_label = _label(stack, Color(0.95, 0.98, 0.99), 24)
    var rule := ColorRect.new()
    rule.color = Color(0.63, 0.37, 0.19, 0.80)
    rule.custom_minimum_size = Vector2(0, 1)
    stack.add_child(rule)
    var scroll := ScrollContainer.new()
    scroll.name = "TrainingScrollableText"
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    stack.add_child(scroll)
    var body := VBoxContainer.new()
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    body.add_theme_constant_override("separation", 11)
    scroll.add_child(body)
    description_label = _label(body, Color(0.85, 0.90, 0.93), 16)
    hint_label = _label(body, Color(0.45, 0.86, 0.94), 14)
    # W21 progressive disclosure: the cause always appears in simple words;
    # detailed evidence and recovery stay available by keyboard/touch on demand.
    coach_heading = _label(body, Color(0.98, 0.68, 0.40), 14)
    coach_heading.name = "ExplainableCoachHeading"
    coach_summary = _label(body, Color(0.87, 0.91, 0.92), 14)
    coach_summary.name = "ExplainableCoachSummary"
    coach_more_button = _styled_button("ПОЧЕМУ? ПОДРОБНЕЕ", false)
    coach_more_button.name = "ExpandCauseExplanation"
    coach_more_button.pressed.connect(_toggle_coach_details)
    # Keep this button visible beside HELP at the bottom of the training card,
    # even when the cause text itself must scroll on a 360px device.
    coach_detail = _label(body, Color(0.68, 0.82, 0.86), 13)
    coach_detail.name = "CauseAndNextAction"
    coach_detail.visible = false
    metrics_label = _label(body, Color(0.93, 0.72, 0.49), 13)
    safety_label = _label(body, Color(0.69, 0.73, 0.76), 12)
    safety_label.text = "СИМУЛЯЦИЯ • Реальное оборудование требует допуска и проверки отсутствия энергии."
    primary_button = _styled_button("НАЧАТЬ ОБУЧЕНИЕ", true)
    primary_button.name = "LuxuryStartOrNext"
    primary_button.pressed.connect(_primary_pressed)
    stack.add_child(primary_button)
    guide_button = _styled_button("УПРАВЛЕНИЕ И ИНСТРУКЦИЯ", false)
    guide_button.name = "LuxuryGuideButton"
    guide_button.pressed.connect(_show_controls)
    var assistance_row := HBoxContainer.new()
    assistance_row.name = "PermanentCourseAssistanceActions"
    assistance_row.add_theme_constant_override("separation", 6)
    guide_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    coach_more_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    assistance_row.add_child(guide_button)
    assistance_row.add_child(coach_more_button)
    stack.add_child(assistance_row)

    rail = PanelContainer.new()
    rail.name = "LuxuryTutorialRail"
    rail.add_theme_stylebox_override("panel", _glass())
    add_child(rail)
    var rail_stack := VBoxContainer.new()
    rail_stack.add_theme_constant_override("separation", 12)
    rail.add_child(rail_stack)
    rail_header = _label(rail_stack, Color(0.96, 0.58, 0.27), 15)
    for i in range(6):
        var label := _label(rail_stack, Color(0.76, 0.85, 0.88), 14)
        label.name = "Chapter_%d" % i
        rail_rows.append(label)

    # A real local settings surface: no new machinery controls, always closes
    # back to the existing six-chapter course. A clipped scroll area avoids
    # multiplying layout minimum heights on 360px and 932x430 WebGL screens.
    settings_panel = PanelContainer.new()
    settings_panel.name = "LuxuryPlayerSettings"
    settings_panel.add_theme_stylebox_override("panel", _glass(true))
    add_child(settings_panel)
    settings_clip = Control.new()
    settings_clip.name = "SettingsViewport"
    settings_clip.clip_contents = true
    settings_clip.custom_minimum_size = Vector2.ZERO
    settings_panel.add_child(settings_clip)
    settings_scroll = ScrollContainer.new()
    settings_scroll.name = "SettingsScrollableActions"
    settings_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    settings_scroll.follow_focus = true
    settings_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    settings_clip.add_child(settings_scroll)
    var settings_stack := VBoxContainer.new()
    settings_stack.name = "ActualPlayerSettingsControls"
    settings_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    settings_stack.add_theme_constant_override("separation", 10)
    settings_scroll.add_child(settings_stack)
    settings_title = _label(settings_stack, Color(0.97, 0.70, 0.42), 22)
    settings_note = _label(settings_stack, Color(0.83, 0.90, 0.92), 14)
    settings_quality_button = _styled_button("ГРАФИКА: ЭКО", true)
    settings_quality_button.name = "PlayerQualityToggle"
    settings_quality_button.pressed.connect(_settings_quality_pressed)
    settings_stack.add_child(settings_quality_button)
    settings_motion_button = _styled_button("АНИМАЦИИ: ПОЛНЫЕ", false)
    settings_motion_button.name = "PlayerReducedMotionToggle"
    settings_motion_button.pressed.connect(_settings_motion_pressed)
    settings_stack.add_child(settings_motion_button)
    settings_close_button = _styled_button("НАЗАД К ОБУЧЕНИЮ", false)
    settings_close_button.name = "ReturnToCourse"
    settings_close_button.pressed.connect(_toggle_settings)
    settings_stack.add_child(settings_close_button)

func _t(ru: String, en: String) -> String:
    return ru if locale == "ru" else en

func _assign(label: Label, value: String) -> void:
    if label.text != value:
        label.text = value

func _set_expand_state() -> void:
    card.visible = expanded and not settings_open
    settings_panel.visible = expanded and settings_open
    compact_status.visible = not expanded
    rail.visible = expanded and not settings_open and get_viewport().get_visible_rect().size.x / maxf(1.0, float(host.get("touch_pixel_ratio"))) >= 950
    collapse_button.text = "−" if expanded else "+"

func _layout() -> void:
    if brand == null or host == null:
        return
    # Godot renders at WebGL DPR on touch devices. Measure in physical engine
    # pixels, but size every visual and hit target in device-independent units.
    var area := get_viewport().get_visible_rect().size
    var ratio: float = maxf(1.0, float(host.get("touch_pixel_ratio")))
    var css_width: float = area.x / ratio
    var portrait: bool = area.y > area.x * 1.03
    var compact: bool = css_width < 620.0
    # W19 original real 932x430 screenshot: preserve a readable scrollable
    # tutorial even in short landscape, without covering operator controls.
    var short_landscape: bool = not portrait and area.y / ratio < 510.0
    var margin: float = (14.0 if compact or short_landscape else 22.0) * ratio
    var header_height: float = (70.0 if compact else 78.0) * ratio
    brand.position = Vector2(margin, margin)
    brand.size = Vector2(minf(area.x - 2.0 * margin, 510.0 * ratio), header_height)
    brand_subtitle.visible = not compact
    # Explicit short brand on narrow devices: three real header buttons
    # including Settings remain at least 44 CSS px, never clipped by logo.
    brand_title.text = "OSGARD" if compact else "O S G A R D"
    brand_header.add_theme_constant_override("separation", 4 if compact else 9)
    brand_title.add_theme_font_size_override("font_size", int((18 if compact else 23) * ratio))
    brand_subtitle.add_theme_font_size_override("font_size", int(12 * ratio))
    var mark: Control = brand.get_child(0).get_child(0) as Control
    mark.custom_minimum_size = Vector2((40.0 if compact else 48.0) * ratio,
        (40.0 if compact else 48.0) * ratio)
    language_button.add_theme_font_size_override("font_size", int(14 * ratio))
    settings_button.add_theme_font_size_override("font_size", int(12 * ratio))
    collapse_button.add_theme_font_size_override("font_size", int(18 * ratio))
    language_button.custom_minimum_size = Vector2(44.0 * ratio, 46.0 * ratio)
    settings_button.custom_minimum_size = Vector2(44.0 * ratio, 46.0 * ratio)
    collapse_button.custom_minimum_size = Vector2(44.0 * ratio, 46.0 * ratio)

    var action_y: float = area.y - (290.0 if portrait else 133.0) * ratio
    var host_actions: Control = host.get("action_panel") as Control
    if host_actions != null and host_actions.position.y > 0.0:
        action_y = host_actions.position.y
    var top: float = margin + header_height + (7.0 if short_landscape else 12.0) * ratio
    compact_status.position = Vector2(margin, top)
    compact_status.custom_minimum_size = Vector2(0, 0)
    compact_status.size = Vector2(brand.size.x, 158.0 * ratio)
    # Preserve bounded layout when Chromium DPR/orientation changes. The
    # custom child does not contribute minimum size to PanelContainer.
    var status_stack: VBoxContainer = compact_status_clip.get_child(0) as VBoxContainer
    status_stack.position = Vector2.ZERO
    status_stack.custom_minimum_size = Vector2.ZERO
    status_stack.size = Vector2(maxf(90.0, brand.size.x - 42.0 * ratio),
        maxf(48.0, 158.0 * ratio - 32.0 * ratio))
    compact_status_title.add_theme_font_size_override("font_size", int((13 if compact else 15) * ratio))
    compact_status_detail.add_theme_font_size_override("font_size", int((12 if compact else 14) * ratio))
    compact_status_safety.add_theme_font_size_override("font_size", int(11 * ratio))
    var max_height: float = maxf(172.0 * ratio,
        action_y - top - (7.0 if short_landscape else 12.0) * ratio)
    # The primary/secondary actions remain touch-sized. Reduce only empty
    # separators so the genuine scroll container keeps meaningful height.
    var card_stack: VBoxContainer = card.get_child(0) as VBoxContainer
    card_stack.add_theme_constant_override("separation", 3 if short_landscape else 8)
    card.position = Vector2(margin, top)
    card.custom_minimum_size = Vector2(0, 0)
    card.size = Vector2(minf(460.0 * ratio, area.x - margin * 2.0), minf(max_height, 480.0 * ratio))
    eyebrow.add_theme_font_size_override("font_size", int(12 * ratio))
    title_label.add_theme_font_size_override("font_size", int((18 if compact else 24) * ratio))
    description_label.add_theme_font_size_override("font_size", int((14 if compact else 16) * ratio))
    hint_label.add_theme_font_size_override("font_size", int((13 if compact else 14) * ratio))
    coach_heading.add_theme_font_size_override("font_size", int((12 if compact else 14) * ratio))
    coach_summary.add_theme_font_size_override("font_size", int((12 if compact else 14) * ratio))
    coach_detail.add_theme_font_size_override("font_size", int((12 if compact else 13) * ratio))
    coach_more_button.custom_minimum_size = Vector2(0, 44.0 * ratio)
    coach_more_button.add_theme_font_size_override("font_size", int((12 if compact else 13) * ratio))
    metrics_label.add_theme_font_size_override("font_size", int(13 * ratio))
    safety_label.add_theme_font_size_override("font_size", int(11 * ratio))
    primary_button.add_theme_font_size_override("font_size", int((13 if compact else 15) * ratio))
    guide_button.add_theme_font_size_override("font_size", int((12 if compact else 14) * ratio))
    primary_button.custom_minimum_size = Vector2(0, 48.0 * ratio)
    guide_button.custom_minimum_size = Vector2(0, 44.0 * ratio)
    settings_panel.position = card.position
    settings_panel.custom_minimum_size = Vector2.ZERO
    settings_panel.size = card.size
    settings_clip.custom_minimum_size = Vector2.ZERO
    settings_scroll.position = Vector2.ZERO
    settings_scroll.size = Vector2(maxf(90.0, card.size.x - 28.0 * ratio),
        maxf(80.0, card.size.y - 28.0 * ratio))
    settings_title.add_theme_font_size_override("font_size", int((18 if compact else 22) * ratio))
    settings_note.add_theme_font_size_override("font_size", int((12 if compact else 14) * ratio))
    for settings_action in [settings_quality_button, settings_motion_button, settings_close_button]:
        settings_action.custom_minimum_size = Vector2(0, 46.0 * ratio)
        settings_action.add_theme_font_size_override("font_size", int((12 if compact else 14) * ratio))
    _refresh_settings()

    rail.position = Vector2(area.x - margin - 286.0 * ratio, top)
    rail.size = Vector2(286.0 * ratio, minf(385.0 * ratio, max_height))
    rail_header.add_theme_font_size_override("font_size", int(15 * ratio))
    for label in rail_rows:
        label.add_theme_font_size_override("font_size", int(14 * ratio))
    rail.visible = expanded and not settings_open and css_width >= 950.0
    _set_expand_state()
func is_expanded() -> bool:
    return expanded

func set_language(value: String) -> void:
    locale = "en" if value == "en" else "ru"
    language_button.text = "RU" if locale == "en" else "EN"
    language_button.tooltip_text = "Переключить на русский" if locale == "en" else "Switch to English"
    _refresh_settings()
    _present()
    call_deferred("_layout")

func _switch_language() -> void:
    if host != null:
        host.call("_toggle_locale")

func _toggle_expanded() -> void:
    expanded = not expanded
    if not expanded:
        settings_open = false
    _set_expand_state()
    if host != null:
        host.call_deferred("_settle_hud_after_layout")
    call_deferred("_layout")

func _toggle_coach_details() -> void:
    coach_expanded = not coach_expanded
    _present()
    # Existing bounded ScrollContainer safely handles a longer deep explanation.
    call_deferred("_layout")


func _present_coach() -> void:
    if coach_heading == null:
        return
    var result: Dictionary = R135LearningCoach.explain(state_cache, step, locale)
    coach_last_status = str(result["status"])
    _assign(coach_heading, str(result["title"]))
    _assign(coach_summary, str(result["cause"]))
    coach_more_button.text = _t("СКРЫТЬ РАЗБОР", "HIDE DETAILS") if coach_expanded else _t(
        "ПОЧЕМУ?", "WHY?")
    coach_detail.visible = coach_expanded
    var detail_text: String = str(result["deeper"]) + "\n\n" + _t("СЛЕДУЮЩЕЕ ДЕЙСТВИЕ: ", "NEXT ACTION: ") + str(result["next"])
    var evidence_text: String = str(result.get("evidence", ""))
    if evidence_text.length() > 0 and str(result["status"]) not in ["maintenance", "intro"]:
        detail_text += "\n" + _t("УЧЕБНЫЙ СИГНАЛ: ", "SIMULATED EVIDENCE: ") + evidence_text
    detail_text += "\n" + _t("ТОЛЬКО СИМУЛЯЦИЯ. Никаких команд реальному оборудованию.",
        "SIMULATION ONLY. No commands are sent to real machinery.")
    _assign(coach_detail, detail_text)


func _toggle_settings() -> void:
    settings_open = not settings_open
    if settings_open:
        expanded = true
    _set_expand_state()
    _refresh_settings()
    if host != null:
        host.call_deferred("_settle_hud_after_layout")
    call_deferred("_layout")


func _settings_quality_pressed() -> void:
    if host != null:
        host.call("_toggle_quality")
    _refresh_settings()


func _settings_motion_pressed() -> void:
    if host != null:
        host.call("_set_reduced_motion", not bool(host.get("reduced_motion")))
    _refresh_settings()


func _refresh_settings() -> void:
    if host == null or settings_button == null or settings_title == null:
        return
    settings_button.tooltip_text = _t("Настройки игрока", "Player settings")
    _assign(settings_title, _t("ПАРАМЕТРЫ ИГРЫ", "PLAYER SETTINGS"))
    _assign(settings_note, _t(
        "Язык меняется кнопкой RU / EN сверху. Настройки сохраняются только на этом устройстве. Реальное оборудование здесь не управляется.",
        "Switch RU / EN above. Settings stay only on this device. This game does not control real equipment."))
    settings_quality_button.text = _t(
        "ГРАФИКА: HERO (детально)" if int(host.get("quality")) == 2 else "ГРАФИКА: ECO (быстрее)",
        "GRAPHICS: HERO (detail)" if int(host.get("quality")) == 2 else "GRAPHICS: ECO (faster)")
    settings_motion_button.text = _t(
        "АНИМАЦИИ: МЕНЬШЕ" if bool(host.get("reduced_motion")) else "АНИМАЦИИ: ПОЛНЫЕ",
        "MOTION: REDUCED" if bool(host.get("reduced_motion")) else "MOTION: FULL")
    settings_close_button.text = _t("НАЗАД К ОБУЧЕНИЮ", "BACK TO TRAINING")


func on_gameplay_command() -> void:
    # Legacy direct controls remain fully operable; don't force a modal tutorial
    # onto existing players or browser QA that starts the mission directly.
    if not begun and expanded:
        expanded = false
        _set_expand_state()
        if host != null:
            host.call_deferred("_settle_hud_after_layout")
        call_deferred("_layout")

func _load_progress() -> void:
    var file := ConfigFile.new()
    if file.load(SAVE_PATH) != OK:
        return
    if int(file.get_value("tutorial", "schema", -1)) != 1:
        return
    begun = bool(file.get_value("tutorial", "begun", false))
    finished = bool(file.get_value("tutorial", "finished", false))
    step = clampi(int(file.get_value("tutorial", "step", 0)), 0, 5)
    # Always make resumed training discoverable. No mutation of W14 case saves.
    expanded = true

func _save_progress() -> void:
    var file := ConfigFile.new()
    file.set_value("tutorial", "schema", 1)
    file.set_value("tutorial", "begun", begun)
    file.set_value("tutorial", "finished", finished)
    file.set_value("tutorial", "step", step)
    file.save(SAVE_PATH)

func start_tutorial() -> void:
    begun = true
    finished = false
    step = 1
    expanded = true
    _save_progress()
    controls_open = false
    _set_expand_state()
    _present()
    call_deferred("_layout")

func reset_tutorial() -> void:
    begun = false
    finished = false
    step = 0
    expanded = true
    _save_progress()
    controls_open = false
    _set_expand_state()
    _present()
    call_deferred("_layout")

func sync_game(state: Dictionary, view_index: int) -> void:
    state_cache = state
    view_cache = view_index
    if begun and not finished:
        var next_step := step
        if step == 1 and view_cache != 0:
            next_step = 2
        elif step == 2 and bool(state.get("mission_completed", false)):
            next_step = 3
        elif step == 3 and bool(state.get("challenge_completed", false)) and int(state.get("cleared_case_count", 0)) >= 1:
            next_step = 4
        elif step == 4 and int(state.get("cleared_case_count", 0)) >= 3:
            next_step = 5
        if next_step != step:
            step = next_step
            _save_progress()
    _present()

func _guided_mission() -> void:
    if not bool(state_cache.get("mission_active", false)) and not bool(state_cache.get("mission_completed", false)):
        host.call("_start_mission")
        return
    match int(state_cache.get("mission_step", 0)):
        0:
            host.call("_toggle_motion")
        1:
            host.call("_toggle_hatch")
        2:
            if float(state_cache.get("lid_progress", 0.0)) >= 0.95:
                host.call("_toggle_hatch")
        3:
            if float(state_cache.get("lid_progress", 1.0)) <= 0.05:
                host.call("_toggle_motion")

func _guided_diagnostic() -> void:
    if not bool(state_cache.get("challenge_active", false)):
        host.call("_start_challenge")
        return
    match int(state_cache.get("challenge_step", 0)):
        0:
            host.call("_toggle_motion")
        1:
            host.call("_toggle_hatch")
        2:
            if float(state_cache.get("lid_progress", 0.0)) >= 0.95:
                var target := int(state_cache.get("challenge_target_view", 2))
                if int(host.get("view_index")) != target:
                    host.call("_apply_view", target)
                else:
                    host.call("_scan_component")
        3:
            host.call("_toggle_hatch")
        4:
            if float(state_cache.get("lid_progress", 1.0)) <= 0.05:
                host.call("_toggle_motion")

func _primary_pressed() -> void:
    if host == null:
        return
    if finished:
        reset_tutorial()
        return
    if not begun:
        start_tutorial()
        return
    match step:
        1:
            host.call("_next_view")
        2:
            _guided_mission()
        3, 4:
            _guided_diagnostic()
        5:
            finished = true
            _save_progress()
    var rig: Node3D = host.get("controller") as Node3D
    if rig != null:
        sync_game(rig.call("summary"), int(host.get("view_index")))
    _present()

func _show_controls() -> void:
    # Actual, implemented input mapping; not a fictional first-person WASD rig.
    var controls_ru := "МЫШЬ / ПАЛЕЦ — вращение камеры\nКОЛЕСО / ЖЕСТ — приближение\nV — сменить ракурс\nM — начать сервисную миссию\nC — начать диагностику\nE — сканировать учебный узел\nF — люк (только после остановки)\nПРОБЕЛ — остановка / пуск\nQ — ECO / HERO\nR — сброс камеры\nL — русский / English"
    var controls_en := "MOUSE / TOUCH — orbit camera\nWHEEL / PINCH — zoom\nV — next view\nM — start service mission\nC — begin diagnostics\nE — scan simulated target\nF — hatch (after stopping)\nSPACE — stop / run\nQ — ECO / HERO\nR — reset camera\nL — Russian / English"
    controls_open = not controls_open
    _assign(hint_label, _t(controls_ru, controls_en) if controls_open else str((HELP_RU if locale == "ru" else HELP_EN)[clampi(step, 0, 5)]))

func _primary_caption() -> String:
    if finished:
        return _t("ПОВТОРИТЬ ОБУЧЕНИЕ", "RESTART TRAINING")
    if not begun:
        return _t("НАЧАТЬ ОБУЧЕНИЕ", "START TRAINING")
    if step == 1:
        return _t("СМЕНИТЬ РАКУРС · V", "NEXT VIEW · V")
    if step == 5:
        return _t("ЗАВЕРШИТЬ ОБУЧЕНИЕ", "FINISH TRAINING")
    if step == 2:
        if not bool(state_cache.get("mission_active", false)):
            return _t("НАЧАТЬ СЕРВИСНУЮ МИССИЮ", "START SERVICE MISSION")
        var mission_step := int(state_cache.get("mission_step", 0))
        if mission_step == 0:
            return _t("ОСТАНОВИТЬ ПРИВОД", "STOP DRIVE")
        if mission_step == 1:
            return _t("ОТКРЫТЬ ЛЮК", "OPEN HATCH")
        if mission_step == 2:
            return _t("ЗАКРЫТЬ ЛЮК" if float(state_cache.get("lid_progress", 0)) >= 0.95 else "ОЖИДАНИЕ ОТКРЫТИЯ…",
                "CLOSE HATCH" if float(state_cache.get("lid_progress", 0)) >= 0.95 else "WAIT FOR HATCH…")
        return _t("ВОЗОБНОВИТЬ ПРИВОД" if float(state_cache.get("lid_progress", 1)) <= 0.05 else "ОЖИДАНИЕ ЗАКРЫТИЯ…",
            "RESTART DRIVE" if float(state_cache.get("lid_progress", 1)) <= 0.05 else "WAIT UNTIL SEALED…")
    if not bool(state_cache.get("challenge_active", false)):
        return _t("НАЧАТЬ ДИАГНОСТИКУ", "START DIAGNOSTICS")
    match int(state_cache.get("challenge_step", 0)):
        0:
            return _t("ОСТАНОВИТЬ ПРИВОД", "STOP DRIVE")
        1:
            return _t("ОТКРЫТЬ СЕРВИСНЫЙ ЛЮК", "OPEN HATCH")
        2:
            if float(state_cache.get("lid_progress", 0)) < 0.95:
                return _t("ОЖИДАНИЕ ОТКРЫТИЯ…", "WAIT FOR HATCH…")
            if view_cache != int(state_cache.get("challenge_target_view", 2)):
                return _t("ПОКАЗАТЬ НУЖНЫЙ УЗЕЛ", "SHOW TARGET VIEW")
            return _t("СКАНИРОВАТЬ УЗЕЛ", "SCAN TARGET")
        3:
            return _t("ЗАКРЫТЬ ЛЮК", "CLOSE HATCH")
        4:
            return _t("ВОЗОБНОВИТЬ ПРИВОД" if float(state_cache.get("lid_progress", 1)) <= 0.05 else "ОЖИДАНИЕ ЗАКРЫТИЯ…",
                "RESTART DRIVE" if float(state_cache.get("lid_progress", 1)) <= 0.05 else "WAIT UNTIL SEALED…")
    return _t("СЛЕДУЮЩЕЕ ДЕЙСТВИЕ", "NEXT ACTION")

func _is_waiting() -> bool:
    if not begun or finished:
        return false
    if step == 2:
        return (int(state_cache.get("mission_step", -1)) == 2 and float(state_cache.get("lid_progress", 0)) < 0.95) or (
            int(state_cache.get("mission_step", -1)) == 3 and float(state_cache.get("lid_progress", 1)) > 0.05)
    if step == 3 or step == 4:
        return (int(state_cache.get("challenge_step", -1)) == 2 and float(state_cache.get("lid_progress", 0)) < 0.95) or (
            int(state_cache.get("challenge_step", -1)) == 4 and float(state_cache.get("lid_progress", 1)) > 0.05)
    return false

func _present() -> void:
    if title_label == null:
        return
    var i := clampi(step, 0, 5)
    var current_titles: Array = TITLES_RU if locale == "ru" else TITLES_EN
    var current_details: Array = DETAILS_RU if locale == "ru" else DETAILS_EN
    var current_hints: Array = HELP_RU if locale == "ru" else HELP_EN
    var completed_cases := int(state_cache.get("cleared_case_count", 0))
    _assign(eyebrow, _t("ДОБРО ПОЖАЛОВАТЬ  •  ГЛАВА", "WELCOME  •  CHAPTER") + "  %d / 6" % (i + 1))
    _assign(title_label, str(current_titles[i]))
    _assign(description_label, str(current_details[i]))
    if not controls_open:
        _assign(hint_label, str(current_hints[i]))
    _present_coach()
    _assign(safety_label, _t(
        "ТОЛЬКО СИМУЛЯЦИЯ. Реальное обслуживание требует допуска, блокировки питания и проверки отсутствия энергии.",
        "SIMULATION ONLY. Real machinery requires authorization, lockout and verified zero energy."))
    var motion_text := _t("ПРИВОД РАБОТАЕТ", "DRIVE RUNNING") if bool(state_cache.get("motion_enabled", true)) else _t("ПРИВОД ОСТАНОВЛЕН", "DRIVE PAUSED")
    var score_text := _t("КЕЙСЫ %d/3  •  %s", "CASES %d/3  •  %s") % [completed_cases, motion_text]
    if finished:
        score_text = _t("ОБУЧЕНИЕ ЗАВЕРШЕНО  •  %d/3 КЕЙСА", "TRAINING FINISHED  •  %d/3 CASES") % completed_cases
    _assign(metrics_label, score_text)
    var drive_label: String = _t("ПРИВОД РАБОТАЕТ", "DRIVE RUNNING") if bool(state_cache.get("motion_enabled", true)) else _t("ПРИВОД ОСТАНОВЛЕН", "DRIVE STOPPED")
    var mode: String = "HERO" if int(state_cache.get("quality", 0)) == 2 else "ECO"
    _assign(compact_status_title, "OSGARD  /  %s  •  %s" % [mode, drive_label])
    var feedback: String = str(state_cache.get("challenge_feedback", "")) if (
        bool(state_cache.get("challenge_active", false)) or bool(state_cache.get("challenge_completed", false))
    ) else str(state_cache.get("mission_feedback", ""))
    var goal: String = str(state_cache.get("challenge_goal", "")) if (
        bool(state_cache.get("challenge_active", false)) or bool(state_cache.get("challenge_completed", false))
    ) else str(state_cache.get("mission_goal", ""))
    var live_text: String = goal + "\n" + feedback
    if host != null:
        live_text = str(host.call("_translated", live_text))
    if live_text.length() > 155:
        live_text = live_text.substr(0, 152) + "…"
    _assign(compact_status_detail, live_text)
    _assign(compact_status_safety, _t(
        "ТОЛЬКО УЧЕБНАЯ СИМУЛЯЦИЯ  •  ОТКРОЙТЕ «+» ДЛЯ ОБУЧЕНИЯ",
        "SIMULATION ONLY  •  OPEN «+» TO RESUME THE COURSE"))
    if primary_button.text != _primary_caption():
        primary_button.text = _primary_caption()
    primary_button.disabled = _is_waiting()
    _assign(rail_header, _t("ЭТАПЫ ОБУЧЕНИЯ", "TRAINING PROGRESS") + "   %d/6" % (i + 1))
    for j in range(6):
        # Avoid tofu squares from missing decorative glyphs in Godot Web
        # fallback fonts; plain ASCII stays crisp in Chromium + native.
        var mark := "OK" if (j < step or (finished and j == 5)) else (">" if j == step else "-")
        var row_text := "%s  %02d   %s" % [mark, j + 1, str(current_titles[j])]
        _assign(rail_rows[j], row_text)
        rail_rows[j].add_theme_color_override("font_color",
            Color(0.98, 0.68, 0.40) if j == step else (Color(0.44, 0.84, 0.80) if j < step else Color(0.72, 0.78, 0.82)))
    guide_button.text = _t("УПРАВЛЕНИЕ", "CONTROLS")
    if settings_open:
        _refresh_settings()
