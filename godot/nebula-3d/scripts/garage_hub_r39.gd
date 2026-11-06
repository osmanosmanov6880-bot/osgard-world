
extends CanvasLayer
const Hangar3DPreviewR44Script = preload("res://scripts/hangar_ship_preview_r44.gd")
## R39 garage command hub. Reads the live campaign state supplied by world.gd.
signal sortie_requested
signal shop_requested
signal upgrade_requested_r54(slot: int)
signal training_requested_r54
signal module_requested_r56(module_id: String)
signal contract_selected_r57(contract_id: String)
signal captain_selected(captain_id: String)
signal ship_selected_r45(ship_id: String)
signal wingman_toggled_r47(wingman_id: String)

var ui_font: Font
var profile: Dictionary = {}
var launch_button: Button
var mission_label: Label
var mission_detail: Label
var captain_label: Label
var ship_label: Label
var progression_label: Label
var roster_label: Label
var wingman_choice_buttons_r47: Dictionary = {}
var wingman_status_r47: Label
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
var ship_choice_buttons_r45: Dictionary = {}
var ship_ownership_hint_r45: Label
var comparison_toggle_r46: Button
var comparison_detail_r46: Label
var readiness_label_r46: Label
var comparison_open_r46: bool = false
## R44 separate 3D dock, actual in-game NX imported geometry and orbit controls.
var ship_preview_r44
var preview_frame_r44: PanelContainer
var preview_title_r44: Label
var preview_hint_r44: Label
var turn_left_r44: Button
var turn_right_r44: Button
var brand_label_r44: Label
var shop_header_button_r54: Button
var zoom_in_button_r54: Button
var zoom_out_button_r54: Button
var section_buttons_r54: Dictionary = {}
var active_section_r54: String = "fleet"
var ship_card_r54: PanelContainer
var captain_card_r54: PanelContainer
var mission_card_r54: PanelContainer
var introductory_section_r54: VBoxContainer
var squad_controls_r54: HBoxContainer
var academy_panel_r54: PanelContainer
var academy_status_r54: Label
var academy_train_button_r54: Button
var engine_upgrade_r54: Button
var weapon_upgrade_r54: Button
var r56_workshop_panel: PanelContainer
var r56_workshop_status: Label
var r56_module_buttons: Dictionary = {}
var r57_contract_panel: PanelContainer
var r57_contract_buttons: Dictionary = {}
var r57_contract_description: Label
var r57_contract_result: Label
var r57_free_flight_button: Button
var footer_r54: HBoxContainer

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
    # The ship viewer is a dedicated SubViewport / World3D, not a flat JPG.
    # It does not control or move the actual gameplay CharacterBody3D.
    preview_frame_r44 = PanelContainer.new()
    preview_frame_r44.name = "R44_Real3DShipGallery"
    preview_frame_r44.set_anchors_preset(Control.PRESET_TOP_LEFT)
    preview_frame_r44.add_theme_stylebox_override("panel",
        _panel_style(Color(0.014, 0.032, 0.054, 0.98),
            Color(0.13, 0.36, 0.49, 0.75)))
    root.add_child(preview_frame_r44)
    ship_preview_r44 = Hangar3DPreviewR44Script.new()
    ship_preview_r44.name = "R44_RealShipViewport"
    ship_preview_r44.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    ship_preview_r44.size_flags_vertical = Control.SIZE_EXPAND_FILL
    preview_frame_r44.add_child(ship_preview_r44)

    preview_title_r44 = Label.new()
    preview_title_r44.name = "R44_Real3DShipName"
    preview_title_r44.text = "AURORA  /  BAY ZERO  /  NX-08"
    preview_title_r44.add_theme_font_override("font", ui_font)
    preview_title_r44.add_theme_font_size_override("font_size", 13)
    preview_title_r44.add_theme_color_override("font_color", CYAN)
    preview_title_r44.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(preview_title_r44)

    preview_hint_r44 = Label.new()
    preview_hint_r44.name = "R44_InspectionHint"
    preview_hint_r44.text = "ТЕХНИЧЕСКИЙ АНГАР  ·  ВРАЩЕНИЕ: ПЕРЕТАЩИ  ·  МАСШТАБ: + / −"
    preview_hint_r44.add_theme_font_override("font", ui_font)
    preview_hint_r44.add_theme_font_size_override("font_size", 11)
    preview_hint_r44.add_theme_color_override("font_color", MUTED)
    preview_hint_r44.mouse_filter = Control.MOUSE_FILTER_IGNORE
    root.add_child(preview_hint_r44)

    turn_left_r44 = _turn_button_r44(root, "R44_TurnLeft", "↶", -1)
    turn_right_r44 = _turn_button_r44(root, "R44_TurnRight", "↷", 1)
    zoom_out_button_r54 = _r54_zoom_button(root, "R54_ZoomOut", "−", 1)
    zoom_in_button_r54 = _r54_zoom_button(root, "R54_ZoomIn", "+", -1)

    var top := HBoxContainer.new()
    top.add_theme_constant_override("separation", 10)
    header.add_child(top)
    brand_label_r44 = _label(top, "NEBULA  /  AURORA ZERO", 20, CYAN)
    brand_label_r44.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    resource_label = _label(top, "950 CR    •    0 XP", 16, GOLD)
    resource_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    shop_header_button_r54 = Button.new()
    shop_header_button_r54.name = "R54_AlwaysVisibleRealCreditHangarShop"
    shop_header_button_r54.text = "МАГАЗИН"
    shop_header_button_r54.custom_minimum_size = Vector2(116, 42)
    shop_header_button_r54.add_theme_font_override("font", ui_font)
    shop_header_button_r54.add_theme_font_size_override("font_size", 13)
    shop_header_button_r54.add_theme_color_override("font_color", GOLD)
    shop_header_button_r54.add_theme_stylebox_override("normal",
        _panel_style(Color(0.085, 0.066, 0.038, 0.98), GOLD))
    shop_header_button_r54.pressed.connect(func(): shop_requested.emit())
    top.add_child(shop_header_button_r54)

    panel = PanelContainer.new()
    panel.name = "R39_GarageBriefing"
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.offset_left = 30
    panel.offset_top = 108
    panel.offset_right = 430
    panel.offset_bottom = 645
    panel.add_theme_stylebox_override("panel", _panel_style(BG))
    root.add_child(panel)

    var content_root := VBoxContainer.new()
    content_root.name = "R54_GarageNavigatorAndScrollableContent"
    content_root.size_flags_vertical = Control.SIZE_EXPAND_FILL
    panel.add_child(content_root)
    var nav := HBoxContainer.new()
    nav.name = "R54_AlwaysAvailableHubSections"
    nav.add_theme_constant_override("separation", 6)
    content_root.add_child(nav)
    for tab_id in ["fleet", "workshop", "crew", "operations"]:
        var tab := Button.new()
        tab.name = "R54_Tab_" + tab_id
        tab.text = {"fleet":"ФЛОТ", "workshop":"МОДУЛИ",
            "crew":"ПИЛОТЫ", "operations":"МИССИИ"}[tab_id]
        tab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        tab.custom_minimum_size = Vector2(76, 42)
        tab.focus_mode = Control.FOCUS_ALL
        tab.add_theme_font_override("font", ui_font)
        tab.add_theme_font_size_override("font_size", 12)
        tab.pressed.connect(_r54_select_section.bind(tab_id))
        nav.add_child(tab)
        section_buttons_r54[tab_id] = tab
    var scroll := ScrollContainer.new()
    scroll.name = "R39_GarageContents"
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    content_root.add_child(scroll)
    var column := VBoxContainer.new()
    column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    column.add_theme_constant_override("separation", 12)
    scroll.add_child(column)
    introductory_section_r54 = VBoxContainer.new()
    introductory_section_r54.name = "R54_SingleMissionBriefOnlyWhenSelected"
    introductory_section_r54.add_theme_constant_override("separation", 7)
    column.add_child(introductory_section_r54)
    _label(introductory_section_r54, "AURORA  /  ЦЕНТР ОПЕРАЦИЙ", 12, CYAN)
    _label(introductory_section_r54, "БРИФИНГ ВЫЛЕТА", 22, Color(0.94,0.97,0.98))
    description_label = _label(introductory_section_r54, "Осмотри задачу и подготовь экипаж.", 13, MUTED)
    story_label = _label(introductory_section_r54, "АДА ВЕЙЛ · КОМАНДИР", 12, GOLD)
    objective_label = _label(introductory_section_r54, "ЦЕЛЬ · ДОСТИГНУТЬ МАЯКА", 13, CYAN)
    stakes_label = _label(introductory_section_r54, "Учебный вылет без атаки в начале.", 12, MUTED)
    debrief_label = _label(introductory_section_r54, "", 12, GOLD)
    debrief_label.visible = false

    var ship_card := PanelContainer.new()
    ship_card.name = "R39_FleetCard"
    ship_card_r54 = ship_card
    ship_card.add_theme_stylebox_override("panel", _panel_style(Color(0.025, 0.059, 0.086, 0.96)))
    column.add_child(ship_card)
    var ship_stack := VBoxContainer.new()
    ship_stack.add_theme_constant_override("separation", 5)
    ship_card.add_child(ship_stack)
    _label(ship_stack, "АКТИВНЫЙ КОРАБЛЬ", 11, MUTED)
    ship_label = _label(ship_stack, "NX-08  /  SCOUT", 18, Color(0.93,0.97,0.99))
    _label(ship_stack, "ЩИТ И КОРПУС · СИСТЕМЫ ГОТОВЫ", 11, CYAN)
    var hull_selector := HBoxContainer.new()
    hull_selector.name = "R45_ActualFleetSelector"
    hull_selector.add_theme_constant_override("separation", 5)
    ship_stack.add_child(hull_selector)
    for hull_id in ["ship_scout", "ship_interceptor", "ship_guardian"]:
        var selector := Button.new()
        selector.name = "R45_Choose_" + hull_id
        selector.text = {"ship_scout":"NX-08", "ship_interceptor":"NX-12",
            "ship_guardian":"NX-21"}[hull_id]
        selector.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        selector.custom_minimum_size = Vector2(64, 44)
        selector.focus_mode = Control.FOCUS_ALL
        selector.add_theme_font_override("font", ui_font)
        selector.add_theme_font_size_override("font_size", 12)
        selector.add_theme_stylebox_override("normal", _panel_style(PANEL))
        selector.pressed.connect(_on_r45_ship_pressed.bind(hull_id))
        hull_selector.add_child(selector)
        ship_choice_buttons_r45[hull_id] = selector
    ship_ownership_hint_r45 = _label(ship_stack,
        "Недоступную технику можно открыть в магазине.", 11, MUTED)
    readiness_label_r46 = _label(ship_stack, "ПОДГОТОВКА · ОРУЖИЕ / РАКЕТЫ / ВЕДОМЫЕ", 12, CYAN)
    var upgrade_tools := HBoxContainer.new()
    upgrade_tools.name = "R54_DockedEngineAndWeaponWorkbench"
    upgrade_tools.add_theme_constant_override("separation", 6)
    # R56: two classic upgrades move to the dedicated workshop section.
    engine_upgrade_r54 = _r54_credit_action(upgrade_tools,
        "R54_EngineUpgrade", "ДВИГАТЕЛЬ · 600 CR")
    weapon_upgrade_r54 = _r54_credit_action(upgrade_tools,
        "R54_WeaponUpgrade", "ОРУЖИЕ · 600 CR")
    engine_upgrade_r54.pressed.connect(func(): upgrade_requested_r54.emit(0))
    weapon_upgrade_r54.pressed.connect(func(): upgrade_requested_r54.emit(1))
    comparison_toggle_r46 = Button.new()
    comparison_toggle_r46.name = "R46_CompareRealFleet"
    comparison_toggle_r46.text = "СРАВНИТЬ ТЕХНИКУ  ▾"
    comparison_toggle_r46.custom_minimum_size = Vector2(148, 44)
    comparison_toggle_r46.add_theme_font_override("font", ui_font)
    comparison_toggle_r46.add_theme_font_size_override("font_size", 12)
    comparison_toggle_r46.add_theme_color_override("font_color", CYAN)
    comparison_toggle_r46.add_theme_stylebox_override("normal", _panel_style(PANEL))
    comparison_toggle_r46.pressed.connect(_r46_toggle_comparison)
    ship_stack.add_child(comparison_toggle_r46)
    comparison_detail_r46 = _label(ship_stack, "", 12, MUTED)
    comparison_detail_r46.name = "R46_RealShipStatistics"
    comparison_detail_r46.visible = false

    # R56: a focused module workbench, not a second shop or fake purchase.
    r56_workshop_panel = PanelContainer.new()
    r56_workshop_panel.name = "R56_ActualShipModuleWorkbench"
    r56_workshop_panel.add_theme_stylebox_override("panel",
        _panel_style(Color(0.025, 0.057, 0.085, 0.98), LINE))
    column.add_child(r56_workshop_panel)
    var workbench_stack := VBoxContainer.new()
    workbench_stack.add_theme_constant_override("separation", 10)
    r56_workshop_panel.add_child(workbench_stack)
    _label(workbench_stack, "AURORA · МАСТЕРСКАЯ ФЛОТА", 13, GOLD)
    _label(workbench_stack, "ОБОРУДОВАНИЕ АКТИВНОГО КОРАБЛЯ", 12, CYAN)
    r56_workshop_status = _label(workbench_stack,
        "КОРПУС 100 / ЩИТ 100 / РАДАР 460 М", 13, MUTED)
    _label(workbench_stack, "БАЗОВЫЕ СИСТЕМЫ · ДО 4 УРОВНЯ", 12, CYAN)
    workbench_stack.add_child(upgrade_tools)
    _label(workbench_stack, "ПЕРСОНАЛЬНЫЕ МОДУЛИ · ДО 3 УРОВНЯ", 12, GOLD)
    for module_id in ["armor", "shield", "radar"]:
        var module_button := _r54_credit_action(workbench_stack,
            "R56_Install_" + module_id, "УСТАНОВИТЬ · " + module_id)
        module_button.tooltip_text = "Покупка за игровые кредиты"
        module_button.pressed.connect(
            _r56_request_module.bind(module_id))
        r56_module_buttons[module_id] = module_button

    var captain_card := PanelContainer.new()
    captain_card.name = "R39_CaptainCard"
    captain_card_r54 = captain_card
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

    academy_panel_r54 = PanelContainer.new()
    academy_panel_r54.name = "R54_CreditBasedCaptainAcademy"
    academy_panel_r54.add_theme_stylebox_override("panel",
        _panel_style(Color(0.026,0.052,0.078,0.97), LINE))
    column.add_child(academy_panel_r54)
    var academy_column := VBoxContainer.new()
    academy_column.add_theme_constant_override("separation", 8)
    academy_panel_r54.add_child(academy_column)
    _label(academy_column, "АКАДЕМИЯ · ОБУЧЕНИЕ ЗА CR", 13, GOLD)
    academy_status_r54 = _label(academy_column, "РАНГ 0 / 3", 12, MUTED)
    academy_train_button_r54 = _r54_credit_action(academy_column,
        "R54_ActualCaptainTrainingPurchase", "ОБУЧИТЬ · 650 CR")
    academy_train_button_r54.pressed.connect(
        func(): training_requested_r54.emit())
    roster_label = _label(column, "ЭКИПАЖ  ·  Ведомые", 13, Color(0.86,0.92,0.95))
    var squad_choices := HBoxContainer.new()
    squad_choices.name = "R47_RealWingmanSelectors"
    squad_controls_r54 = squad_choices
    squad_choices.add_theme_constant_override("separation", 7)
    column.add_child(squad_choices)
    for id in ["wingman_escort", "wingman_ace"]:
        var button := Button.new()
        button.name = "R47_Toggle_" + id
        button.text = "ЭСКОРТ" if id == "wingman_escort" else "АС"
        button.custom_minimum_size = Vector2(105, 44)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.focus_mode = Control.FOCUS_ALL
        button.add_theme_font_override("font", ui_font)
        button.add_theme_font_size_override("font_size", 12)
        button.add_theme_stylebox_override("normal", _panel_style(PANEL))
        button.pressed.connect(_on_wingman_pressed_r47.bind(id))
        squad_choices.add_child(button)
        wingman_choice_buttons_r47[id] = button
    wingman_status_r47 = _label(column,
        "2 МЕСТА В СТРОЮ · ВЕДОМЫХ МОЖНО ВЗЯТЬ В МАГАЗИНЕ", 11, MUTED)

    var mission_card := PanelContainer.new()
    mission_card.name = "R39_MissionCard"
    mission_card_r54 = mission_card
    mission_card.add_theme_stylebox_override("panel", _panel_style(Color(0.09, 0.071, 0.043, 0.94), Color(0.62, 0.42, 0.19, 0.82)))
    column.add_child(mission_card)
    var mission_stack := VBoxContainer.new()
    mission_stack.add_theme_constant_override("separation", 5)
    mission_card.add_child(mission_stack)
    _label(mission_stack, "СЛЕДУЮЩИЙ ВЫЛЕТ", 11, GOLD)
    mission_label = _label(mission_stack, "01  ·  ПЕРВЫЙ ПОЛЁТ", 17, Color(0.97,0.96,0.91))
    mission_detail = _label(mission_stack, "Достигни навигационного маяка и защити Аврору.", 12, MUTED)

    r57_contract_panel = PanelContainer.new()
    r57_contract_panel.name = "R57_RealPostCampaignContractBoard"
    r57_contract_panel.add_theme_stylebox_override("panel",
        _panel_style(Color(0.025, 0.055, 0.075, 0.98), GOLD))
    column.add_child(r57_contract_panel)
    var contract_stack := VBoxContainer.new()
    contract_stack.add_theme_constant_override("separation", 8)
    r57_contract_panel.add_child(contract_stack)
    _label(contract_stack, "КАРЬЕРА ПИЛОТА · КОНТРАКТЫ АВРОРЫ", 13, GOLD)
    _label(contract_stack, "14 СЮЖЕТНЫХ ОПЕРАЦИЙ ПРОЙДЕНЫ", 12, MUTED)
    r57_contract_description = _label(contract_stack,
        "Выбирай настоящий рейс. Награда только после всех точек.", 12, CYAN)
    r57_contract_result = _label(contract_stack, "", 12, GOLD)
    r57_free_flight_button = _r54_credit_action(contract_stack,
        "R57_ChooseFreeFlight", "БЕЗ ЗАДАНИЯ · СВОБОДНЫЙ ПОЛЁТ")
    r57_free_flight_button.pressed.connect(
        _r57_request_contract.bind(""))
    for route_id in ["aurora","neon","rift"]:
        var route_button := _r54_credit_action(contract_stack,
            "R57_SelectPatrol_" + route_id, "ПАТРУЛЬ · " + route_id)
        route_button.custom_minimum_size.y = 53
        route_button.pressed.connect(_r57_request_contract.bind(route_id))
        r57_contract_buttons[route_id] = route_button

    status_label = _label(column, "Задача простая: следуй за маркером. Бой начнётся позже по сюжету.", 11, MUTED)

    var footer := HBoxContainer.new()
    footer_r54 = footer
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
    # Keep the old shop action reachable for regression, but never bury the
    # primary shop CTA inside a scrollable column.
    footer_r54.visible = false
    var bottom_scroll_space := Control.new()
    bottom_scroll_space.custom_minimum_size = Vector2(0.0, 78.0)
    column.add_child(bottom_scroll_space)
    _r54_select_section("fleet")

func _r54_credit_action(parent: Container, button_name: String,
        label: String) -> Button:
    var action := Button.new()
    action.name = button_name
    action.text = label
    action.custom_minimum_size = Vector2(0, 42)
    action.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    action.focus_mode = Control.FOCUS_ALL
    action.add_theme_font_override("font", ui_font)
    action.add_theme_font_size_override("font_size", 12)
    action.add_theme_color_override("font_color", CYAN)
    action.add_theme_stylebox_override("normal",
        _panel_style(Color(0.032,0.062,0.090,0.98), LINE))
    parent.add_child(action)
    return action

func _r54_zoom_button(parent: Control, button_name: String, glyph: String,
        direction: int) -> Button:
    var action := Button.new()
    action.name = button_name
    action.text = glyph
    action.focus_mode = Control.FOCUS_ALL
    action.add_theme_font_override("font", ui_font)
    action.add_theme_font_size_override("font_size", 18)
    action.add_theme_stylebox_override("normal", _panel_style(PANEL, CYAN))
    action.pressed.connect(_r54_zoom_preview.bind(direction))
    parent.add_child(action)
    return action

func _r54_zoom_preview(direction: int) -> void:
    if is_instance_valid(ship_preview_r44):
        ship_preview_r44.zoom_r54(direction)

func _r57_request_contract(contract_id: String) -> void:
    if active_section_r54 == "operations" and (
            is_instance_valid(r57_contract_panel) and
            r57_contract_panel.visible):
        contract_selected_r57.emit(contract_id)

func _r56_request_module(module_id: String) -> void:
    if r56_module_buttons.has(module_id) and active_section_r54 == "workshop":
        module_requested_r56.emit(module_id)

func _r54_select_section(section_id: String) -> void:
    if not section_buttons_r54.has(section_id):
        return
    active_section_r54 = section_id
    var fleet: bool = section_id == "fleet"
    var workshop: bool = section_id == "workshop"
    var crew: bool = section_id == "crew"
    var operations: bool = section_id == "operations"
    if is_instance_valid(ship_card_r54):
        ship_card_r54.visible = fleet
    if is_instance_valid(r56_workshop_panel):
        r56_workshop_panel.visible = workshop
    if is_instance_valid(captain_card_r54):
        captain_card_r54.visible = crew
    if is_instance_valid(academy_panel_r54):
        academy_panel_r54.visible = crew
    if is_instance_valid(roster_label):
        roster_label.visible = crew
    if is_instance_valid(squad_controls_r54):
        squad_controls_r54.visible = crew
    if is_instance_valid(wingman_status_r47):
        wingman_status_r47.visible = crew
    if is_instance_valid(introductory_section_r54):
        introductory_section_r54.visible = operations
    if is_instance_valid(mission_card_r54):
        mission_card_r54.visible = operations
    if is_instance_valid(r57_contract_panel):
        var m: Array = profile.get("missions", [])
        r57_contract_panel.visible = operations and (
            int(profile.get("mission_index", 0)) >= m.size() and
            not m.is_empty())
    if is_instance_valid(status_label):
        status_label.visible = operations
    for key in section_buttons_r54:
        var tab: Button = section_buttons_r54[key]
        var chosen: bool = str(key) == section_id
        tab.add_theme_stylebox_override("normal",
            _panel_style(Color(0.10,0.19,0.23,0.98) if chosen else PANEL,
                CYAN if chosen else LINE))
        tab.add_theme_color_override("font_color", CYAN if chosen else MUTED)

func _turn_button_r44(parent: Control, node_name: String, glyph: String,
        direction: int) -> Button:
    var button := Button.new()
    button.name = node_name
    button.text = glyph
    button.custom_minimum_size = Vector2(46, 44)
    button.focus_mode = Control.FOCUS_ALL
    button.add_theme_font_override("font", ui_font)
    button.add_theme_font_size_override("font_size", 20)
    button.add_theme_color_override("font_color", CYAN)
    button.add_theme_stylebox_override("normal",
        _panel_style(Color(0.018, 0.065, 0.100, 0.98), LINE))
    button.add_theme_stylebox_override("hover",
        _panel_style(Color(0.06, 0.18, 0.24, 0.98), CYAN))
    button.tooltip_text = "Повернуть корабль"
    button.pressed.connect(_on_turn_preview_r44.bind(direction))
    parent.add_child(button)
    return button

func _on_turn_preview_r44(direction: int) -> void:
    if is_instance_valid(ship_preview_r44):
        ship_preview_r44.rotate_step(direction)

func _r46_toggle_comparison() -> void:
    comparison_open_r46 = not comparison_open_r46
    comparison_detail_r46.visible = comparison_open_r46
    comparison_toggle_r46.text = (
        "СКРЫТЬ СРАВНЕНИЕ  ▴" if comparison_open_r46 else
        "СРАВНИТЬ ТЕХНИКУ  ▾")

func _on_r45_ship_pressed(id: String) -> void:
    ship_selected_r45.emit(id)

func _on_wingman_pressed_r47(id: String) -> void:
    wingman_toggled_r47.emit(id)

func _on_captain_pressed(id: String) -> void:
    captain_selected.emit(id)

func refresh(data: Dictionary) -> void:
    profile = data
    var credits := int(data.get("credits", 0))
    var xp := int(data.get("xp", 0))
    var level := 1 + int(floor(float(xp) / 500.0))
    var xp_next := xp % 500
    resource_label.text = "%s CR    •    %s XP" % [_format_number(credits), _format_number(xp)]
    if is_instance_valid(engine_upgrade_r54):
        var engine_rank: int = clampi(int(data.get("engine_rank_r54", 0)), 0, 4)
        engine_upgrade_r54.text = ("ДВИГАТЕЛЬ · MAX" if engine_rank >= 4
            else "ДВИГАТЕЛЬ · %s CR" % _format_number(600 + engine_rank * 500))
        engine_upgrade_r54.disabled = engine_rank >= 4
    if is_instance_valid(weapon_upgrade_r54):
        var weapon_rank: int = clampi(int(data.get("weapon_rank_r54", 0)), 0, 4)
        weapon_upgrade_r54.text = ("ОРУЖИЕ · MAX" if weapon_rank >= 4
            else "ОРУЖИЕ · %s CR" % _format_number(600 + weapon_rank * 500))
        weapon_upgrade_r54.disabled = weapon_rank >= 4
    var selected_training: String = str(data.get("captain_id", "ada"))
    var training_map: Dictionary = data.get("pilot_training_r54", {})
    var trained: int = clampi(int(training_map.get(selected_training, 0)), 0, 3)
    var training_cost: int = [650, 1100, 1800][mini(trained, 2)]
    if is_instance_valid(academy_status_r54):
        var title_for_pilot: String = str({"ada":"АДА","kai":"КАЙ",
            "leya":"ЛЕЯ"}.get(selected_training, "ПИЛОТ"))
        academy_status_r54.text = "%s · РАНГ %d/3 · %s" % [
            title_for_pilot, trained, 
            ("ЗАЩИТА +%d%%" % (trained*3)) if selected_training == "ada" else
            ("ТЯГА +%d%%" % (trained*4)) if selected_training == "kai" else
            ("КРЕДИТЫ +%d%%" % (trained*4))]
    if is_instance_valid(academy_train_button_r54):
        academy_train_button_r54.text = ("ОБУЧЕНИЕ ЗАВЕРШЕНО" if trained >= 3
            else "ОБУЧИТЬ · %s CR" % _format_number(training_cost))
        academy_train_button_r54.disabled = trained >= 3
    # Module costs and installed bonuses are bound to the real owned hull.
    var module_hull: String = str(data.get("ship", "ship_scout"))
    var module_roster: Dictionary = data.get("hangar_modules_r56", {})
    var module_data: Variant = module_roster.get(module_hull, {})
    var module_levels: Dictionary = (
        module_data if typeof(module_data) == TYPE_DICTIONARY else {})
    if is_instance_valid(r56_workshop_status):
        var ship_title: String = str({
            "ship_scout":"NX-08", "ship_interceptor":"NX-12",
            "ship_guardian":"NX-21"}.get(module_hull, "NX"))
        r56_workshop_status.text = (
            "%s · КОРПУС %d · ЩИТ %d · РАДАР %d М" % [
            ship_title, roundi(float(data.get("hull_cap_r56", 100))),
            roundi(float(data.get("shield_cap_r56", 100))),
            roundi(float(data.get("radar_range_r56", 460)))])
    var module_titles: Dictionary = {
        "armor":"БРОНЯ · +20 КОРПУС",
        "shield":"ГЕНЕРАТОР ЩИТА · +25 ЕД.",
        "radar":"СЕНСОРЫ · +100 М"}
    var base_price: Dictionary = {"armor":500, "shield":550, "radar":400}
    var price_step: Dictionary = {"armor":400, "shield":450, "radar":320}
    for module_id in ["armor", "shield", "radar"]:
        var button: Button = r56_module_buttons[module_id]
        var rank: int = clampi(int(module_levels.get(module_id, 0)), 0, 3)
        var cost: int = int(base_price[module_id]) + int(price_step[module_id]) * rank
        button.text = ("%s · РАНГ %d/3 · МАКСИМУМ" % [
            module_titles[module_id], rank] if rank >= 3 else
            "%s · РАНГ %d/3 → %d/3 · %s CR" % [
            module_titles[module_id], rank, rank + 1, _format_number(cost)])
        button.disabled = rank >= 3
        button.tooltip_text = ("Максимальная модернизация" if rank >= 3 else
            ("Нужно %s CR" % _format_number(cost) if credits < cost else
            "Установить за игровые кредиты, изменения сохраняются"))
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
    var owned_hulls: Dictionary = data.get("owned_ships", {})
    for hull_id in ship_choice_buttons_r45:
        var button: Button = ship_choice_buttons_r45[hull_id]
        var permitted: bool = bool(owned_hulls.get(hull_id, hull_id == "ship_scout"))
        var current: bool = str(hull_id) == ship_id
        button.disabled = not permitted
        button.text = ("✓ " if current else "") + str({
            "ship_scout":"NX-08", "ship_interceptor":"NX-12",
            "ship_guardian":"NX-21"}.get(hull_id, "NX"))
        button.add_theme_stylebox_override("normal",
            _panel_style(CYAN if current else PANEL, CYAN if current else LINE))
        button.add_theme_color_override("font_color",
            BG if current else (CYAN if permitted else MUTED))
        button.tooltip_text = ("Экипирован" if current else
            ("Выбрать принадлежащий корабль" if permitted else
            "Сначала приобрести в магазине"))
    ship_ownership_hint_r45.text = ("КАТАЛОГ  ·  NX-12: 1 700 CR  ·  NX-21: 4 200 CR" if (
        not owned_hulls.get("ship_interceptor", false) or not owned_hulls.get("ship_guardian", false))
        else "ВСЕ ТРИ КОРАБЛЯ ПРИОБРЕТЕНЫ")
    var specs: Dictionary = data.get("ship_profiles", {})
    var compare_rows := PackedStringArray()
    for hull_id in ["ship_scout", "ship_interceptor", "ship_guardian"]:
        var spec: Dictionary = specs.get(hull_id, {})
        var model_name: String = str({
            "ship_scout":"NX-08", "ship_interceptor":"NX-12",
            "ship_guardian":"NX-21"}.get(hull_id, "NX"))
        var access: String = "ДОСТУПЕН" if bool(owned_hulls.get(
            hull_id, hull_id == "ship_scout")) else "ЗАКРЫТ"
        compare_rows.append("%s · %s\n  КОРПУС %d  /  ЩИТ %d  /  ПОВОРОТ %.1f рад/с" % [
            model_name, access, int(spec.get("hull", 0)),
            int(spec.get("shield", 0)), float(spec.get("turn_speed", 0.0))])
    comparison_detail_r46.text = "\n".join(compare_rows)
    comparison_detail_r46.visible = comparison_open_r46
    var equipment: Dictionary = data.get("flight_equipment", {})
    readiness_label_r46.text = "БОЕГОТОВНОСТЬ · %s · УРОН %.1f\nРАКЕТЫ %d  /  ВЕДОМЫЕ %d ИЗ 2  /  ДВИГАТЕЛЬ %d" % [
        str(equipment.get("weapon_name", "СТАНДАРТ")),
        float(equipment.get("weapon_damage", 4.0)),
        int(equipment.get("rockets", 0)),
        int(equipment.get("wingmen", 0)),
        int(equipment.get("engine_rank", 0))]
    if is_instance_valid(ship_preview_r44):
        ship_preview_r44.set_ship_type(ship_id)
        var owned_module_sets: Dictionary = data.get("hangar_modules_r56", {})
        var active_modules: Variant = owned_module_sets.get(ship_id, {})
        var configured: Dictionary = (
            active_modules if typeof(active_modules) == TYPE_DICTIONARY else {})
        ship_preview_r44.set_workbench_modules_r56(
            clampi(int(configured.get("armor", 0)), 0, 3),
            clampi(int(configured.get("shield", 0)), 0, 3),
            clampi(int(configured.get("radar", 0)), 0, 3))
    if is_instance_valid(preview_title_r44):
        preview_title_r44.text = "AURORA  /  BAY ZERO  /  " + str(ship_names.get(ship_id,
            "NX-08  /  РАЗВЕДЧИК"))
    var allies: Array = data.get("wingmen", [])
    var owned_wingmen: Dictionary = data.get("owned_wingmen", {})
    for ally_id in wingman_choice_buttons_r47:
        var button: Button = wingman_choice_buttons_r47[ally_id]
        var owned: bool = bool(owned_wingmen.get(ally_id, false))
        var equipped: bool = allies.has(ally_id)
        button.disabled = not owned
        button.text = ("✓ " if equipped else "") + (
            "ЭСКОРТ" if ally_id == "wingman_escort" else "АС")
        button.add_theme_color_override("font_color",
            BG if equipped else (CYAN if owned else MUTED))
        button.add_theme_stylebox_override("normal",
            _panel_style(CYAN if equipped else PANEL, CYAN if equipped else LINE))
        button.tooltip_text = ("Исключить из группы" if equipped else
            ("Поставить на взлётную площадку" if owned else
             "Сначала получить в магазине"))
    wingman_status_r47.text = "В СТРОЮ: %d ИЗ 2 · ПЛОЩАДКИ ПОКАЗАНЫ В 3D" % allies.size()
    if is_instance_valid(ship_preview_r44):
        ship_preview_r44.set_wingmen_r47(allies)
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
    # R57 contract board is enabled only when the real campaign is finished.
    var finished_campaign: bool = int(data.get("mission_index", 0)) >= (
        (data.get("missions", []) as Array).size())
    var route_selected: String = str(data.get("r57_selected_contract", ""))
    var route_catalog: Array = data.get("r57_contract_catalog", [])
    var route_totals: Dictionary = data.get("r57_contract_counts", {})
    if is_instance_valid(r57_contract_panel):
        r57_contract_panel.visible = finished_campaign and (
            active_section_r54 == "operations")
        r57_contract_description.text = (
            "Выбери маршрут. Пройди все физические маяки за отведённое "
            + "время: награда не начисляется при выборе или провале.")
        r57_contract_result.text = str(data.get("r57_last_report", ""))
        r57_free_flight_button.text = (
            ("✓  " if route_selected.is_empty() else "")
            + "СВОБОДНЫЙ ПОЛЁТ · БЕЗ НАГРАДЫ")
        for item in route_catalog:
            if typeof(item) != TYPE_DICTIONARY:
                continue
            var route_id: String = str(item.get("id", ""))
            if not r57_contract_buttons.has(route_id):
                continue
            var choose: Button = r57_contract_buttons[route_id]
            choose.text = ("%s%s · %d МАЯКА · %d CR / %d XP\n"
                + "ЛИМИТ %d МИН · ВЫПОЛНЕНО %d РАЗ") % [
                "✓  " if route_selected == route_id else "",
                str(item.get("title", "КОНТРАКТ")),
                int(item.get("checkpoints", 0)),
                int(item.get("credits", 0)),
                int(item.get("xp", 0)),
                ceili(float(item.get("duration_sec", 0.0)) / 60.0),
                int(route_totals.get(route_id, 0))]
            choose.tooltip_text = str(item.get("description", ""))

    var mission_index := int(data.get("mission_index", 0))
    var missions: Array = data.get("missions", [])
    if mission_index >= missions.size():
        if route_selected.is_empty():
            mission_label.text = "СВОБОДНЫЙ ПОЛЁТ"
            mission_detail.text = "Кампания завершена. Исследуй шесть районов."
            launch_button.text = "▶  СВОБОДНЫЙ ПОЛЁТ"
            status_label.text = "Сюжет пройден — можно исследовать город без задания."
        else:
            mission_label.text = "КОНТРАКТ · %s" % route_selected.to_upper()
            mission_detail.text = "Контрольные точки и реальные сроки рейса."
            launch_button.text = "▶  НА КОНТРАКТ"
            status_label.text = "На каждом маяке удерживай позицию 1,5 секунды."
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
    var compact: bool = view.x < 580.0
    var landscape: bool = view.x >= 740.0 and view.x > view.y * 1.28
    var short_view: bool = view.y < 560.0
    var margin: float = 10.0 if compact else (12.0 if view.x < 980.0 else 30.0)

    header_panel.offset_left = margin
    header_panel.offset_right = -margin
    header_panel.offset_top = 12.0
    header_panel.offset_bottom = 72.0
    brand_label_r44.text = "NEBULA" if compact else "NEBULA  /  AURORA ZERO"
    shop_header_button_r54.text = "КУПИТЬ" if compact else "МАГАЗИН" 
    shop_header_button_r54.custom_minimum_size = Vector2(74 if compact else 116, 42)
    brand_label_r44.add_theme_font_size_override("font_size", 14 if compact else 20)
    resource_label.add_theme_font_size_override("font_size", 10 if compact else 16)

    var stage_left: float
    var stage_top: float
    var stage_width: float
    var stage_height: float
    if landscape:
        var left_panel_width: float = clampf(view.x * 0.31, 300.0, 440.0)
        panel.offset_left = margin
        panel.offset_top = 88.0
        panel.offset_right = margin + left_panel_width
        panel.offset_bottom = view.y - 12.0
        stage_left = panel.offset_right + 14.0
        stage_top = 88.0
        stage_width = maxf(160.0, view.x - stage_left - margin)
        stage_height = maxf(142.0, view.y - stage_top - 12.0)
    else:
        stage_left = margin
        stage_top = 80.0
        stage_width = maxf(180.0, view.x - margin * 2.0)
        stage_height = clampf(view.y * 0.255, 108.0, 218.0)
        panel.offset_left = margin
        panel.offset_top = stage_top + stage_height + 10.0
        panel.offset_right = view.x - margin
        panel.offset_bottom = view.y - 10.0

    preview_frame_r44.offset_left = stage_left
    preview_frame_r44.offset_top = stage_top
    preview_frame_r44.offset_right = stage_left + stage_width
    preview_frame_r44.offset_bottom = stage_top + stage_height
    preview_title_r44.position = Vector2(stage_left + 19.0, stage_top + 14.0)
    preview_title_r44.size = Vector2(stage_width - 32.0, 20.0)
    preview_title_r44.add_theme_font_size_override("font_size", 10 if compact else 13)
    preview_hint_r44.position = Vector2(stage_left + 18.0,
        stage_top + stage_height - 32.0)
    preview_hint_r44.visible = landscape and stage_width >= 480.0
    turn_left_r44.position = Vector2(
        stage_left + stage_width - 116.0, stage_top + stage_height - 58.0)
    turn_right_r44.position = Vector2(
        stage_left + stage_width - 65.0, stage_top + stage_height - 58.0)
    turn_left_r44.size = Vector2(46.0, 44.0)
    turn_right_r44.size = Vector2(46.0, 44.0)
    zoom_out_button_r54.position = Vector2(
        stage_left + stage_width - 218.0, stage_top + stage_height - 58.0)
    zoom_in_button_r54.position = Vector2(
        stage_left + stage_width - 167.0, stage_top + stage_height - 58.0)
    zoom_out_button_r54.size = Vector2(46.0, 44.0)
    zoom_in_button_r54.size = Vector2(46.0, 44.0)

    description_label.visible = not short_view
    status_label.visible = not short_view and active_section_r54 == "operations"
    launch_button.position = Vector2(panel.offset_left + 16.0,
        minf(view.y - 62.0, panel.offset_bottom - 64.0))
    launch_button.size = Vector2(maxf(170.0,
        panel.offset_right - panel.offset_left - 32.0), 48.0)
