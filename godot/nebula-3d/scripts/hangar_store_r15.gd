extends CanvasLayer
## R15 purchase hangar: durable game-credit purchases plus a separate
## locked real-money catalog. Real-money entitlements MUST come from a server,
## never from this browser's local save / return URL / callback.
signal credit_purchase_requested(sku: String)
signal premium_purchase_requested(sku: String)
signal ship_selected(sku: String)
signal shop_closed

const CREDIT_ITEMS = [
    {"id":"ship_scout","name":"NX-08 SCOUT","kind":"ship","cost":0,"info":"Разведчик · штатный корабль"},
    {"id":"ship_interceptor","name":"VORTEX INTERCEPTOR","kind":"ship","cost":1700,"info":"Манёвренный боевой перехватчик"},
    {"id":"ship_guardian","name":"AEGIS GUARDIAN","kind":"ship","cost":4200,"info":"Тяжёлая броня и усиленный щит"},
    {"id":"weapon_pulse","name":"PULSE CANNON","kind":"weapon","cost":850,"info":"Мощные импульсные выстрелы"},
    {"id":"weapon_plasma","name":"PLASMA LANCE","kind":"weapon","cost":2200,"info":"Усиленная плазма · +урон"},
    {"id":"missiles_6","name":"HOMING MISSILES ×6","kind":"ammo","cost":600,"info":"Шесть управляемых ракет"},
    {"id":"wingman_escort","name":"ESCORT DRONE","kind":"ally","cost":1150,"info":"Один сопровождающий помощник"},
    {"id":"wingman_ace","name":"ACE WINGMAN","kind":"ally","cost":3100,"info":"Элитный боевой помощник"}
]
const PREMIUM_ITEMS = [
    {"id":"premium_hangar","name":"КОСМИЧЕСКИЙ ПРЕМИУМ-АНГАР","price":"GBP","info":"Корабли, вооружение, ракеты, помощники и косметика. Цена подтверждается сервером."}
]
var panel: PanelContainer
var title_text: Label
var wallet: Label
var tabs: TabContainer
var owned: Dictionary = {"ship_scout":true}
var equipped_ship: String = "ship_scout"
var credits: int = 950
var premium_owned: Dictionary = {}
var checkout_enabled: bool = false # This is NOT a payment gate; only the server can enable checkout.

func _ready() -> void:
    layer = 13
    _draw()
    visible = false

func _make_label(content: String, size: int = 16) -> Label:
    var label := Label.new()
    label.text = content
    label.add_theme_font_size_override("font_size", size)
    label.add_theme_color_override("font_color", Color(0.90, 0.93, 0.94))
    label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    return label

func _button(label: String, callback: Callable, enabled: bool = true) -> Button:
    var button := Button.new()
    button.text = label
    button.disabled = not enabled
    button.custom_minimum_size = Vector2(150, 39)
    button.pressed.connect(callback)
    return button

func _draw() -> void:
    var cover := ColorRect.new()
    cover.name = "R15_DimmedHangarBackdrop"
    cover.color = Color(0.009, 0.016, 0.027, 0.90)
    cover.set_anchors_preset(Control.PRESET_FULL_RECT)
    cover.mouse_filter = Control.MOUSE_FILTER_STOP
    add_child(cover)
    panel = PanelContainer.new()
    panel.name = "R15_CommerceHangar"
    panel.set_anchors_preset(Control.PRESET_FULL_RECT)
    panel.offset_left = 38
    panel.offset_top = 30
    panel.offset_right = -38
    panel.offset_bottom = -30
    add_child(panel)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.024, 0.034, 0.048, 0.96)
    style.border_color = Color(0.42, 0.52, 0.58, 0.65)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.content_margin_left = 22
    style.content_margin_top = 16
    style.content_margin_right = 22
    style.content_margin_bottom = 18
    panel.add_theme_stylebox_override("panel", style)
    var root := VBoxContainer.new()
    root.add_theme_constant_override("separation", 9)
    panel.add_child(root)
    var bar := HBoxContainer.new()
    root.add_child(bar)
    title_text = _make_label("OSGARD  /  AEGIS HANGAR  ·  R15", 26)
    title_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    bar.add_child(title_text)
    wallet = _make_label("950 CR", 20)
    bar.add_child(wallet)
    bar.add_child(_button("× ЗАКРЫТЬ", close))
    root.add_child(_make_label("КОРАБЛИ · ОРУЖИЕ · РАКЕТЫ · ПОМОЩНИКИ", 15))
    tabs = TabContainer.new()
    tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
    root.add_child(tabs)
    _add_credit_tab("КОРАБЛИ", "ship")
    _add_credit_tab("ОРУЖИЕ", "weapon")
    _add_credit_tab("РАКЕТЫ", "ammo")
    _add_credit_tab("ПОМОЩНИКИ", "ally")
    _add_premium_tab()
    root.add_child(_make_label("Кредиты за миссии — игровая валюта. Платные товары не выдаются без подтверждения сервера.", 12))

func _scroll_tab(name: String) -> VBoxContainer:
    var scroll := ScrollContainer.new()
    scroll.name = name
    tabs.add_child(scroll)
    var list := VBoxContainer.new()
    list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    list.add_theme_constant_override("separation", 10)
    scroll.add_child(list)
    return list

func _add_credit_tab(tab_name: String, kind: String) -> void:
    var list := _scroll_tab(tab_name)
    for entry in CREDIT_ITEMS:
        if entry["kind"] != kind:
            continue
        var row := HBoxContainer.new()
        list.add_child(row)
        var meta := VBoxContainer.new()
        meta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(meta)
        meta.add_child(_make_label(str(entry["name"]), 18))
        meta.add_child(_make_label(str(entry["info"]), 13))
        var sku: String = entry["id"]
        var cost: int = entry["cost"]
        if kind == "ship":
            row.add_child(_button("ВЫБРАТЬ / КУПИТЬ · %d CR" % cost,
                func() -> void: credit_purchase_requested.emit(sku)))
        else:
            row.add_child(_button("КУПИТЬ · %d CR" % cost,
                func() -> void: credit_purchase_requested.emit(sku)))

func _add_premium_tab() -> void:
    var list := _scroll_tab("ПРЕМИУМ GBP")
    list.add_child(_make_label("ПЛАТНЫЕ ПРЕДМЕТЫ · ЗАЩИЩЁННЫЙ МАГАЗИН STRIPE", 16))
    for item in PREMIUM_ITEMS:
        var row := HBoxContainer.new()
        list.add_child(row)
        var caption := VBoxContainer.new()
        caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(caption)
        caption.add_child(_make_label(str(item["name"]) + "  ·  " + str(item["price"]), 18))
        caption.add_child(_make_label(str(item["info"]), 13))
        var sku: String = item["id"]
        # This opens a separately authenticated shop. Payment buttons on the
        # website are locked unless the backend verifies a live merchant.
        row.add_child(_button("ОТКРЫТЬ МАГАЗИН",
            func() -> void: premium_purchase_requested.emit(sku), true))
    list.add_child(_make_label("Реальная касса отключена до проверки MAGA live. После покупки сервер выдаёт подтверждённые предметы.", 13))

func open(credit_balance: int, inventory: Dictionary, selected: String) -> void:
    credits = credit_balance
    owned = inventory.duplicate(true)
    equipped_ship = selected
    wallet.text = "%d CR" % credits
    visible = true
    tabs.current_tab = 0

func close() -> void:
    visible = false
    shop_closed.emit()

func refresh(balance: int, inventory: Dictionary, selected: String) -> void:
    credits = balance
    owned = inventory.duplicate(true)
    equipped_ship = selected
    wallet.text = "%d CR · %s" % [credits, selected.to_upper()]
