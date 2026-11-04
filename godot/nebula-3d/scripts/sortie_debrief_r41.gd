extends CanvasLayer
## R41: real mission result and retry/garage decision. All values come from world.gd.
signal continue_requested
signal garage_requested

const BG := Color(0.014, 0.029, 0.050, 0.98)
const PANEL := Color(0.035, 0.073, 0.105, 0.97)
const EDGE := Color(0.19, 0.41, 0.51, 0.86)
const CYAN := Color(0.40, 0.86, 0.94)
const GOLD := Color(1.0, 0.75, 0.38)
const MUTED := Color(0.71, 0.79, 0.83)
const WHITE := Color(0.96, 0.98, 0.99)

var ui_font: SystemFont
var panel: PanelContainer
var title_label: Label
var mission_label: Label
var reward_label: Label
var outcome_label: Label
var career_label: Label
var next_label: Label
var next_description: Label
var garage_button: Button
var continue_button: Button

func _ready() -> void:
    layer = 40
    ui_font = SystemFont.new()
    ui_font.font_names = PackedStringArray(["Inter", "Manrope", "Segoe UI", "Noto Sans", "Roboto", "Arial"])
    _build()
    get_viewport().size_changed.connect(_layout)
    _layout()

func _style(fill: Color, stroke: Color = EDGE) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = fill
    style.border_color = stroke
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 13
    style.content_margin_bottom = 13
    return style

func _label(parent: Container, content: String, font_size: int, tint: Color) -> Label:
    var item := Label.new()
    item.text = content
    item.add_theme_font_override("font", ui_font)
    item.add_theme_font_size_override("font_size", font_size)
    item.add_theme_color_override("font_color", tint)
    item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    item.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(item)
    return item

func _action(parent: Container, node_name: String, text_value: String, primary: bool) -> Button:
    var button := Button.new()
    button.name = node_name
    button.text = text_value
    button.focus_mode = Control.FOCUS_NONE
    button.custom_minimum_size = Vector2(0, 48)
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    button.add_theme_font_override("font", ui_font)
    button.add_theme_font_size_override("font_size", 13)
    button.add_theme_color_override("font_color", BG if primary else CYAN)
    var style := _style(CYAN if primary else PANEL, CYAN if primary else EDGE)
    style.content_margin_left = 10
    style.content_margin_right = 10
    button.add_theme_stylebox_override("normal", style)
    button.add_theme_stylebox_override("hover", style)
    button.add_theme_stylebox_override("pressed", style)
    parent.add_child(button)
    return button

func _build() -> void:
    var dim := ColorRect.new()
    dim.name = "R41_FullscreenDimmer"
    dim.color = Color(0.006, 0.014, 0.027, 0.88)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(dim)

    panel = PanelContainer.new()
    panel.name = "R41_SortieDebrief"
    panel.set_anchors_preset(Control.PRESET_CENTER)
    panel.add_theme_stylebox_override("panel", _style(BG))
    add_child(panel)

    var layout := VBoxContainer.new()
    layout.name = "R41_ResultContents"
    layout.add_theme_constant_override("separation", 10)
    panel.add_child(layout)

    _label(layout, "NEBULA   /   ОТЧЁТ О ВЫЛЕТЕ", 12, CYAN)
    title_label = _label(layout, "ЗАДАНИЕ ЗАВЕРШЕНО", 24, WHITE)
    mission_label = _label(layout, "01  ·  ПЕРВЫЙ ПОЛЁТ", 15, GOLD)

    var scroll := ScrollContainer.new()
    scroll.name = "R41_ResultScroll"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    layout.add_child(scroll)
    var content := VBoxContainer.new()
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation", 10)
    scroll.add_child(content)

    var reward_card := PanelContainer.new()
    reward_card.name = "R41_RealRewardCard"
    reward_card.add_theme_stylebox_override("panel", _style(PANEL))
    content.add_child(reward_card)
    var reward_stack := VBoxContainer.new()
    reward_stack.add_theme_constant_override("separation", 5)
    reward_card.add_child(reward_stack)
    _label(reward_stack, "ИТОГ ВЫЛЕТА", 11, MUTED)
    reward_label = _label(reward_stack, "+350 CR    /    +150 XP", 21, GOLD)
    outcome_label = _label(reward_stack, "ВРЕМЯ  00:00  ·  ЦЕЛЕЙ  0", 12, MUTED)
    career_label = _label(reward_stack, "КАПИТАН УР. 1  ·  950 CR", 12, CYAN)

    var next_card := PanelContainer.new()
    next_card.name = "R41_NextMissionCard"
    next_card.add_theme_stylebox_override("panel", _style(Color(0.041, 0.078, 0.094, 0.96)))
    content.add_child(next_card)
    var next_stack := VBoxContainer.new()
    next_stack.add_theme_constant_override("separation", 5)
    next_card.add_child(next_stack)
    _label(next_stack, "СЛЕДУЮЩИЙ ШАГ", 11, CYAN)
    next_label = _label(next_stack, "02  ·  НЕОНОВЫЙ КВАРТАЛ", 16, WHITE)
    next_description = _label(next_stack, "Двигайся к следующему маяку или вернись в гараж.", 12, MUTED)

    var footer := HBoxContainer.new()
    footer.name = "R41_ResultActions"
    footer.add_theme_constant_override("separation", 8)
    layout.add_child(footer)
    garage_button = _action(footer, "R41_ReturnToGarage", "В ГАРАЖ", false)
    continue_button = _action(footer, "R41_ContinueSortie", "▶  ПРОДОЛЖИТЬ", true)
    garage_button.pressed.connect(func(): garage_requested.emit())
    continue_button.pressed.connect(func(): continue_requested.emit())

func show_result(data: Dictionary) -> void:
    var succeeded: bool = bool(data.get("success", true))
    var number: int = maxi(1, int(data.get("number", 1)))
    var title: String = str(data.get("title", "ЗАДАНИЕ"))
    var gained_credits: int = maxi(0, int(data.get("reward", 0)))
    var gained_xp: int = maxi(0, int(data.get("xp_gain", 0)))
    var repair_paid: int = maxi(0, int(data.get("repair_paid", 0)))
    var total_xp: int = maxi(0, int(data.get("total_xp", 0)))
    var total_credits: int = maxi(0, int(data.get("total_credits", 0)))
    var seconds: int = maxi(0, int(data.get("elapsed_seconds", 0)))
    var targets: int = maxi(0, int(data.get("targets_destroyed", 0)))
    var hull_percent: int = clampi(int(data.get("hull_percent", 100)), 0, 100)
    var finished: bool = bool(data.get("campaign_finished", false))
    title_label.text = "МИССИЯ ВЫПОЛНЕНА" if succeeded else "КОРАБЛЬ ПОТЕРЯН"
    title_label.add_theme_color_override("font_color", WHITE if succeeded else GOLD)
    mission_label.text = "%02d  ·  %s" % [number, title]
    reward_label.text = ("+%d CR   /   +%d XP" % [gained_credits, gained_xp]) if succeeded else ("РЕМОНТ  ·  -%d CR" % repair_paid)
    outcome_label.text = "ВРЕМЯ %02d:%02d   ·   ЦЕЛЕЙ %d   ·   КОРПУС %d%%" % [
        int(seconds / 60), seconds % 60, targets, hull_percent]
    career_label.text = "КАПИТАН УР. %d   ·   %d CR   ·   %d XP" % [
        1 + int(total_xp / 500), total_credits, total_xp]
    if finished and succeeded:
        next_label.text = "КАМПАНИЯ ПРОЙДЕНА"
        next_description.text = "Все десять заданий завершены. Можно исследовать районы или вернуться в ангар."
        continue_button.text = "▶  СВОБОДНЫЙ ПОЛЁТ"
    elif succeeded:
        next_label.text = "%02d  ·  %s" % [
            int(data.get("next_number", number + 1)), str(data.get("next_title", "НОВОЕ ЗАДАНИЕ"))]
        next_description.text = str(data.get("next_hint", "Следуй за маркером следующего задания."))
        continue_button.text = "▶  ДАЛЬШЕ"
    else:
        next_label.text = "ПОВТОРНЫЙ ВЫЛЕТ  ·  %s" % title
        next_description.text = "Корабль восстановлен. Можно повторить задание или вернуться в гараж."
        continue_button.text = "▶  ПОВТОРИТЬ"
    _layout()

func _layout() -> void:
    if not is_instance_valid(panel):
        return
    var view: Vector2 = get_viewport().get_visible_rect().size
    var panel_width: float = minf(540.0, maxf(250.0, view.x - 22.0))
    var panel_height: float = minf(550.0, maxf(170.0, view.y - 22.0))
    panel.anchor_left = 0.5
    panel.anchor_top = 0.5
    panel.anchor_right = 0.5
    panel.anchor_bottom = 0.5
    panel.offset_left = -panel_width * 0.5
    panel.offset_right = panel_width * 0.5
    panel.offset_top = -panel_height * 0.5
    panel.offset_bottom = panel_height * 0.5
    var compact: bool = view.x < 430.0 or view.y < 460.0
    title_label.add_theme_font_size_override("font_size", 18 if compact else 24)
    reward_label.add_theme_font_size_override("font_size", 16 if compact else 21)
    continue_button.add_theme_font_size_override("font_size", 12 if compact else 13)
    garage_button.add_theme_font_size_override("font_size", 12 if compact else 13)
