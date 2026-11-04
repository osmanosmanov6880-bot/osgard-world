
extends CanvasLayer
## R39 garage command hub. Reads the live campaign state supplied by world.gd.
signal sortie_requested
signal shop_requested
signal captain_selected(captain_id: String)

var ui_font: Font
var profile: Dictionary = {}
var launch_button: Button
var mission_label: Label
var mission_detail: Label
var captain_label: Label
var ship_label: Label
var progression_label: Label
var roster_label: Label
var resource_label: Label
var status_label: Label
var panel: PanelContainer
var root_control: Control
var header_panel: PanelContainer
var description_label: Label
var story_label: Label
var objective_label: Label
var stakes_label: Label
var debrief_label: Label
var captain_role_label: Label
var captain_bonus_label: Label
var captain_choice_buttons: Dictionary = {}

const BG := Color(0.018, 0.035, 0.058, 0.96)
const PANEL := Color(0.035, 0.073, 0.105, 0.94)
const LINE := Color(0.17, 0.43, 0.54, 0.78)
const CYAN := Color(0.39, 0.85, 0.94)
const GOLD := Color(1.0, 0.72, 0.34)
const MUTED := Color(0.65, 0.77, 0.82)

func _ready() -> void:
    layer = 30
    ui_font = SystemFont.new()
    ui_font.font_names = PackedStringArray(["Inter", "Manrope", "Segoe UI", "Noto Sans", "Roboto", "Arial"])
    _build()
    get_viewport().size_changed.connect(_layout_hub)
    _layout_hub()

func _panel_style(color: Color = PANEL, border: Color = LINE) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = color
    style.border_color = border
    style.set_border_width_all(1)
    style.set_corner_radius_all(10)
    style.content_margin_left = 16
    style.content_margin_right = 16
    style.content_margin_top = 12
    style.content_margin_bottom = 12
    return style

func _label(parent: Container, value: String, size: int, color: Color) -> Label:
    var label := Label.new()
    label.text = value
    label.add_theme_font_override("font", ui_font)
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", color)
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label

func _build() -> void:
    var dim := ColorRect.new()
    dim.name = "R39_GarageBackdrop"
    dim.color = Color(0.006, 0.018, 0.035, 0.54)
    dim.set_anchors_preset(Control.PRESET_FULL_RECT)
    dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(dim)

    var root := Control.new()
    root_control = root
    root.name = "R39_GarageRoot"
    root.set_anchors_preset(Control.PRESET_FULL_RECT)
    root.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(root)

    var header := PanelContainer.new()
    header_panel = header
    header.name = "R39_Header"
    header.set_anchors_preset(Control.PRESET_TOP_WIDE)
    header.offset_left = 30
    header.offset_top = 22
    header.offset_right = -30
    header.offset_bottom = 84
    header.add_theme_stylebox_override("panel", _panel_style(BG))
    root.add_child(header)
    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 18)
    header.add_child(top)
    var brand := _label(top, "NEBULA  /  КОМАНДОВАНИЕ", 20, CYAN)
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    resource_label = _label(top, "950 CR    •    0 XP", 16, GOLD)
    resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT

    panel = PanelContainer.new()
    panel.name = "R39_GarageBriefing"
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.offset_left = 30
    panel.offset_top = 108
    panel.offset_right = 430
    panel.offset_bottom = 645
    panel.add_theme_stylebox_override("panel", _panel_style(BG))
    root.add_child(panel)

    var scroll := ScrollContainer.new()
    scroll.name = "R39_GarageContents"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 12)
    scroll.add_child(column)
    _label(column, "АНГАР АВРОРЫ  /  ПОДГОТОВКА", 12, CYAN)
    _label(column, "Корабль ждёт командира.", 23, Color(0.94, 0.97, 0.98))
    description_label = _label(column, "Осмотри экипаж и задачу. Когда будешь готов — выходи на маршрут.", 13, MUTED)
    story_label = _label(column, "АДА ВЕЙЛ · КОМАНДИР", 12, GOLD)
    objective_label = _label(column, "ЦЕЛЬ · ДОСТИГНУТЬ МАЯКА", 13, CYAN)
    stakes_label = _label(column, "Учебный вылет без атаки в начале.", 12, MUTED)
    debrief_label = _label(column, "", 12, GOLD)
    debrief_label.visible = false

    var ship_card := PanelContainer.new()
    ship_card.name = "R39_FleetCard"
    ship_card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.059, 0.086, 0.96)))
    column.add_child(ship_card)
    var ship_stack := VBoxContainer.new()
    ship_stack.add_theme_constant_override("separation", 5)
    ship_card.add_child(ship_stack)
    _label(ship_stack, "АКТИВНЫЙ КОРАБЛЬ", 11, MUTED)
    ship_label = _label(ship_stack, "NX-08  /  SCOUT", 18, Color(0.93,0.97,0.99))
    _label(ship_stack, "ЩИТ И КОРПУС · СИСТЕМЫ ГОТОВЫ", 11, CYAN)

    var captain_card := PanelContainer.new()
    captain_card.name = "R39_CaptainCard"
    captain_card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.059, 0.086, 0.96)))
    column.add_child(captain_card)
    var captain_stack := VBoxContainer.new()
    captain_stack.add_theme_constant_override("separation", 5)
    captain_card.add_child(captain_stack)
    _label(captain_stack, "КОМАНДИР ЭСКАДРИЛЬИ", 11, MUTED)
    captain_label = _label(captain_stack, "КАПИТАН · УРОВЕНЬ 1", 17, GOLD)
    progression_label = _label(captain_stack, "0 / 500 XP до следующего уровня", 12, MUTED)
    captain_role_label = _label(captain_stack, "ВЫБРАН · АДА ВЕЙЛ / ТАКТИК", 12, CYAN)
    captain_bonus_label = _label(captain_stack, "−10% входящего урона", 12, MUTED)
    var selectors := HBoxContainer.new()
    selectors.name = "R42_CommanderSelector"
    selectors.add_theme_constant_override("separation", 7)
    captain_stack.add_child(selectors)
    for id in ["ada", "kai", "leya"]:
        var select_button := Button.new()
        select_button.name = "R42_Captain_" + id
        select_button.text = {"ada":"АДА", "kai":"КАЙ", "leya":"ЛЕЯ"}[id]
        select_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        select_button.custom_minimum_size = Vector2(68, 44)
        select_button.add_theme_font_override("font", ui_font)
        select_button.add_theme_font_size_override("font_size", 13)
        select_button.add_theme_color_override("font_color", CYAN)
        select_button.add_theme_stylebox_override("normal", _panel_style(PANEL))
        select_button.add_theme_stylebox_override("hover", _panel_style(Color(0.08,0.16,0.23,1.0), CYAN))
        select_button.focus_mode = Control.FOCUS_ALL
        select_button.pressed.connect(_on_captain_pressed.bind(id))
        selectors.add_child(select_button)
        captain_choice_buttons[id] = select_button

    roster_label = _label(column, "ЭКИПАЖ  ·  Ведомые", 13, Color(0.86,0.92,0.95))

    var mission_card := PanelContainer.new()
    mission_card.name = "R39_MissionCard"
    mission_card.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.071, 0.043, 0.94), Color(0.62, 0.42, 0.19, 0.82)))
    column.add_child(mission_card)
    var mission_stack := VBoxContainer.new()
    mission_stack.add_theme_constant_override("separation", 5)
    mission_card.add_child(mission_stack)
    _label(mission_stack, "СЛЕДУЮЩИЙ ВЫЛЕТ", 11, GOLD)
    mission_label = _label(mission_stack, "01  ·  ПЕРВЫЙ ПОЛЁТ", 17, Color(0.97,0.96,0.91))
    mission_detail = _label(mission_stack, "Достигни навигационного маяка и защити Аврору.", 12, MUTED)

    status_label = _label(column, "Задача простая: следуй за маркером. Бой начнётся позже по сюжету.", 11, MUTED)

    var footer := HBoxContainer.new()
    footer.add_theme_constant_override("separation", 10)
    column.add_child(footer)
    var shop := Button.new()
    shop.name = "R39_OpenHangarShop"
    shop.text = "МАГАЗИН"
    shop.custom_minimum_size = Vector2(108, 48)
    shop.focus_mode = Control.FOCUS_NONE
    shop.add_theme_font_override("font", ui_font)
    shop.add_theme_color_override("font_color", CYAN)
    shop.add_theme_stylebox_override("normal", _panel_style(Color(0.025,0.059,0.086,0.98)))
    shop.pressed.connect(func(): shop_requested.emit())
    footer.add_child(shop)
    launch_button = Button.new()
    launch_button.name = "R39_SortieButton"
    launch_button.text = "▶  ВЫЛЕТЕТЬ"
    launch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    launch_button.custom_minimum_size = Vector2(0, 48)
    launch_button.focus_mode = Control.FOCUS_NONE
    launch_button.add_theme_font_override("font", ui_font)
    launch_button.add_theme_font_size_override("font_size", 16)
    launch_button.add_theme_color_override("font_color", Color(0.035,0.07,0.09))
    var launch_style := _panel_style(CYAN, CYAN)
    launch_style.content_margin_left = 16
    launch_style.content_margin_right = 16
    launch_button.add_theme_stylebox_override("normal", launch_style)
    launch_button.add_theme_stylebox_override("hover", launch_style)
    launch_button.add_theme_stylebox_override("pressed", launch_style)
    launch_button.pressed.connect(func(): sortie_requested.emit())
    root.add_child(launch_button)

func _on_captain_pressed(id: String) -> void:
    captain_selected.emit(id)

func refresh(data: Dictionary) -> void:
    profile = data
    var credits := int(data.get("credits", 0))
    var xp := int(data.get("xp", 0))
    var level := 1 + int(floor(float(xp) / 500.0))
    var xp_next := xp % 500
    resource_label.text = "%s CR    •    %s XP" % [_format_number(credits), _format_number(xp)]
    captain_label.text = "КАПИТАН · УРОВЕНЬ %d" % level
    progression_label.text = "%d / 500 XP до следующего уровня" % xp_next
    var selected_id: String = str(data.get("captain_id", "ada"))
    var captain: Dictionary = data.get("captain_info", {})
    captain_role_label.text = "ВЫБРАН · " + str(captain.get("name", "АДА ВЕЙЛ")) + " / " + str(captain.get("role", "ТАКТИК"))
    captain_bonus_label.text = str(captain.get("effect", "−10% входящего урона"))
    for id in captain_choice_buttons:
        var button: Button = captain_choice_buttons[id]
        var active: bool = str(id) == selected_id
        button.text = ("✓  " if active else "") + str({"ada":"АДА","kai":"КАЙ","leya":"ЛЕЯ"}.get(id, id))
        button.add_theme_stylebox_override("normal", _panel_style(CYAN if active else PANEL, CYAN if active else LINE))
        button.add_theme_color_override("font_color", BG if active else CYAN)
        button.tooltip_text = "Текущий капитан" if active else "Выбрать капитана " + str(id)
    var ship_id := str(data.get("ship", "ship_scout"))
    var ship_names := {
        "ship_scout": "NX-08  /  РАЗВЕДЧИК",
        "ship_interceptor": "NX-12  /  ПЕРЕХВАТЧИК",
        "ship_guardian": "NX-21  /  СТРАЖ",
    }
    ship_label.text = str(ship_names.get(ship_id, "NX-08  /  РАЗВЕДЧИК"))
    var allies: Array = data.get("wingmen", [])
    if allies.is_empty():
        roster_label.text = "ЭКИПАЖ  ·  Капитан %d ур.  |  Ведомые: резерв" % level
    else:
        var names := PackedStringArray()
        for ally in allies:
            names.append("ACE" if str(ally) == "wingman_ace" else "ESCORT")
        roster_label.text = "ЭКИПАЖ  ·  Капитан %d ур.  |  " % level + "  +  ".join(names)
    var story: Dictionary = data.get("story", {})
    var last_result: Dictionary = data.get("last_result", {})
    var result_index: int = int(last_result.get("mission_index", -1))
    var current_index: int = int(data.get("mission_index", 0))
    var failed_sortie: bool = str(last_result.get("status", "success")) == "failed" and result_index >= 0 and result_index == current_index
    var completed_sortie: bool = str(last_result.get("status", "success")) != "failed" and result_index >= 0 and result_index == current_index - 1
    var new_result: bool = failed_sortie or completed_sortie
    story_label.text = str(story.get("act", "КАМПАНИЯ")) + "\n" + str(story.get("speaker", "КОМАНДОВАНИЕ АВРОРЫ"))
    description_label.text = str(story.get("brief", "Подготовь корабль и экипаж к следующему вылету."))
    objective_label.text = "ЦЕЛЬ  /  " + str(story.get("objective", "Следуй к навигационному маяку"))
    stakes_label.text = str(story.get("stakes", ""))
    debrief_label.visible = new_result
    if failed_sortie:
        debrief_label.text = "ВЫЛЕТ НЕ УДАЛСЯ · НАГРАДА 0 CR / 0 XP\n" + str(last_result.get("reveal", "Повтори миссию после ремонта."))
    elif completed_sortie:
        debrief_label.text = "ПОСЛЕДНИЙ ВЫЛЕТ: +%d CR  /  +%d XP\n%s" % [int(last_result.get("credits", 0)), int(last_result.get("xp", 0)), str(last_result.get("reveal", ""))]
    var mission_index := int(data.get("mission_index", 0))
    var missions: Array = data.get("missions", [])
    if mission_index >= missions.size():
        mission_label.text = "СВОБОДНЫЙ ПОЛЁТ"
        mission_detail.text = "Кампания завершена. Исследуй шесть районов."
        launch_button.text = "▶  СВОБОДНЫЙ ПОЛЁТ"
        status_label.text = "Сюжет пройден — теперь город открыт для исследования."
        mission_detail.text = str(story.get("objective", "Кампания завершена"))
    else:
        var mission: Dictionary = missions[mission_index]
        mission_label.text = "%02d  ·  %s" % [mission_index + 1, str(mission.get("title", "ЗАДАНИЕ"))]
        var type := str(mission.get("type", "reach"))
        mission_detail.text = "Цель: %s  ·  награда %s CR" % [
            "перехватить эскадрилью" if type == "combat" else "достигнуть маяка",
            _format_number(int(mission.get("reward", 0)))]
        launch_button.text = "▶  ВЫЛЕТЕТЬ"
        status_label.text = "Цель отмечена на HUD. Автопилот доведёт до неё; управление можно перехватить в любой момент."
        mission_detail.text += "\n" + str(story.get("objective", ""))

func _format_number(value: int) -> String:
    var raw := str(maxi(value, 0))
    var out := ""
    var count := 0
    for i in range(raw.length() - 1, -1, -1):
        if count > 0 and count % 3 == 0:
            out = " " + out
        out = raw.substr(i, 1) + out
        count += 1
    return out
func _layout_hub() -> void:
    if not is_instance_valid(root_control) or not is_instance_valid(panel):
        return
    var view := get_viewport().get_visible_rect().size
    var short_view := view.y < 560.0
    var margin := 12.0 if view.x < 520.0 else 30.0
    header_panel.offset_left = margin
    header_panel.offset_right = -margin
    header_panel.offset_top = 14.0
    header_panel.offset_bottom = 74.0
    panel.offset_left = margin
    panel.offset_top = 88.0 if short_view else 96.0
    panel.offset_right = minf(430.0, view.x - margin)
    panel.offset_bottom = view.y - 14.0
    description_label.visible = not short_view
    status_label.visible = not short_view
    launch_button.position = Vector2(panel.offset_left + 16.0,
        minf(view.y - 62.0, panel.offset_bottom - 64.0))
    launch_button.size = Vector2(maxf(170.0, panel.offset_right - panel.offset_left - 32.0), 48.0)
