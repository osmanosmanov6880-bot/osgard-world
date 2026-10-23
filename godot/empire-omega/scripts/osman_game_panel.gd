extends CanvasLayer
## A playable dynasty UI INSIDE the existing Godot scene, not a screenshot.
## F6 toggles progression. F7 toggles verified ecosystem. F8 opens store status.
var panel: PanelContainer
var content: VBoxContainer
var status: Label
var visible_page := "dynasty"
const CATALOG = ["Стартовый набор", "Премиальная машина", "Набор основателя", "Династия", "VIP подписка"]
const PROJECTS = [
    {"name":"OSGARD WORLD", "url":"https://osgard.world/"},
    {"name":"SkillCred", "url":"https://github.com/osmanosmanov6880-bot/SkillCred"},
    {"name":"ZION-9 INFINITE", "url":"https://github.com/osmanosmanov6880-bot/ZION-9-INFINITE"},
    {"name":"Impossible Ventures", "url":"https://github.com/osmanosmanov6880-bot/impossible-ventures"}
]
func _ready() -> void:
    panel = PanelContainer.new()
    panel.name = "OsmanCommandCenter"
    panel.visible = false
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.offset_left = 28
    panel.offset_top = 65
    panel.custom_minimum_size = Vector2(530,360)
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.028,0.055,0.081,0.97)
    style.border_color = Color(0.76,0.63,0.40)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    panel.add_theme_stylebox_override("panel",style)
    add_child(panel)
    content = VBoxContainer.new()
    content.add_theme_constant_override("separation",10)
    panel.add_child(content)
    OsmanDynasty.dynasty_changed.connect(_redraw)
    _redraw()

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F6:
            _toggle("dynasty")
        elif event.keycode == KEY_F7:
            _toggle("ecosystem")
        elif event.keycode == KEY_F8:
            _toggle("store")

func _toggle(page: String) -> void:
    var same: bool = panel.visible and visible_page == page
    visible_page = page
    panel.visible = not same
    if panel.visible:
        _redraw()
        get_viewport().set_input_as_handled()

func _label(text: String, size: int = 15) -> void:
    var label := Label.new()
    label.text = text
    label.add_theme_font_size_override("font_size",size)
    label.add_theme_color_override("font_color",Color(0.91,0.89,0.81))
    content.add_child(label)

func _button(label: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = label
    b.pressed.connect(callback)
    content.add_child(b)

func _redraw() -> void:
    if content == null:
        return
    for child in content.get_children():
        child.queue_free()
    _label("OSMAN: WORLD DOMINION",25)
    _label("FROM THE CASPIAN TO THE WORLD.",13)
    if visible_page == "dynasty":
        var d: Dictionary = OsmanDynasty.dynasty
        _label("Репутация: %d | Влияние: %d | Управление: %d" % [d["reputation"],d["influence"],d["governance"]])
        _label("Миссий: %d / %d" % [d["completed"].size(),OsmanDynasty.MISSIONS.size()])
        var next: Dictionary = OsmanDynasty.next_mission()
        if next.is_empty():
            _label("Сюжет завершён. Финал: " + OsmanDynasty.ending())
        else:
            _label("Следующий этап: " + next["title"])
            _button("Сотрудничать",func(): _complete(next["id"],"cooperate"))
            _button("Конкурировать",func(): _complete(next["id"],"compete"))
            _button("Договориться",func(): _complete(next["id"],"negotiate"))
    elif visible_page == "ecosystem":
        _label("OSMAN ECOSYSTEM · ПРОВЕРЕННЫЕ ПРОЕКТЫ",16)
        for p in PROJECTS:
            _button(p["name"] + " ↗",func(): OS.shell_open(str(p["url"])))
    else:
        _label("МАГАЗИН ДИНАСТИИ · ОЖИДАЕТ LIVE АВТОРИЗАЦИИ",16)
        for product in CATALOG:
            _label("○ " + product + " — покупка пока недоступна")
        _label("Купленные предметы подтверждает только сервер Stripe.")
    _button("Закрыть (F6/F7/F8)",func(): panel.visible = false)

func _complete(id: String, decision: String) -> void:
    if not OsmanDynasty.complete_mission(id,decision):
        push_warning("OSMAN dynasty mission not saved or already completed")
