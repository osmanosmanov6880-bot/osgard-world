extends PanelContainer
class_name IPOperationsPanel
## V9 IRON PULSE / Command Center: accessible RU/EN offline career board.
## Genuine Godot UI, no HTML mockup, remote image, account, or API dependency.
signal close_requested
signal launch_requested(scenario: String)
signal setting_requested(option: String)

const INK := Color(0.025,0.039,0.055,0.99)
const GUNMETAL := Color(0.070,0.098,0.116,0.98)
const EDGE := Color(0.19,0.35,0.41,0.83)
const ICE := Color(0.76,0.90,0.93)
const MUTED := Color(0.56,0.68,0.73)
const SIGNAL := Color(0.36,0.80,0.82)
const COPPER := Color(0.98,0.59,0.30)
const SUCCESS := Color(0.52,0.85,0.67)
const LABELS := {
    "ru":{
        "eyebrow":"IRON PULSE  /  ОПЕРАЦИОННЫЙ ЦЕНТР",
        "heading":"ТВОЯ ИСТОРИЯ ОПЕРАЦИЙ",
        "subtitle":"ТРИ АВАРИИ. РЕАЛЬНЫЕ РЕШЕНИЯ. ТВОИ РЕЗУЛЬТАТЫ.",
        "played":"ОПЕРАЦИИ","saved":"ЭВАКУАЦИИ","mastery":"ДОСТИЖЕНИЯ",
        "chapters":"АВАРИЙНЫЕ ПРОТОКОЛЫ","rewards":"ПРОГРЕСС ОПЕРАТОРА",
        "history":"ПОСЛЕДНИЕ ОПЕРАЦИИ","next":"РЕКОМЕНДУЕМЫЙ ВЫЗОВ",
        "launch":"НАЧАТЬ РЕКОМЕНДУЕМУЮ ОПЕРАЦИЮ",
        "locked":"ЕЩЁ НЕ ПОЛУЧЕНЫ","none":"История появится после первой операции.",
        "settings":"УСТРОЙСТВО И ДОСТУПНОСТЬ",
        "language":"ЯЗЫК","graphics":"ГРАФИКА",
        "reduced_motion":"МЕНЬШЕ ДВИЖЕНИЯ","muted":"ЗВУК",
        "enabled":"ВКЛ","disabled":"ВЫКЛ",
        "wins":"УСПЕХ","attempts":"ПОПЫТОК","best":"ЛУЧШАЯ ОЦЕНКА",
        "time":"ЛУЧШЕЕ ВРЕМЯ","win":"СПАСЕНЫ","loss":"ПОТЕРЯНЫ",
        "footer":"ЛОКАЛЬНО НА УСТРОЙСТВЕ  /  БЕЗ АККАУНТА И СЕТЕВОЙ ТЕЛЕМЕТРИИ",
        "close":"X","recommended":"Следующая цель: {name}",
        "noawards":"Ещё нет достижений. Они открываются за реальные решения."
    },
    "en":{
        "eyebrow":"IRON PULSE  /  OPERATIONS CENTER",
        "heading":"YOUR OPERATOR RECORD",
        "subtitle":"THREE EMERGENCIES. REAL DECISIONS. YOUR RESULTS.",
        "played":"OPERATIONS","saved":"EXTRACTIONS","mastery":"ACHIEVEMENTS",
        "chapters":"EMERGENCY PROTOCOLS","rewards":"OPERATOR PROGRESSION",
        "history":"RECENT OPERATIONS","next":"RECOMMENDED CHALLENGE",
        "launch":"LAUNCH RECOMMENDED OPERATION",
        "locked":"STILL LOCKED","none":"Your record will appear after your first operation.",
        "settings":"DEVICE & ACCESSIBILITY",
        "language":"LANGUAGE","graphics":"GRAPHICS",
        "reduced_motion":"REDUCED MOTION","muted":"AUDIO",
        "enabled":"ON","disabled":"OFF",
        "wins":"SUCCESS","attempts":"ATTEMPTS","best":"BEST GRADE",
        "time":"BEST TIME","win":"EXTRACTED","loss":"LOST",
        "footer":"STORED LOCALLY  /  NO ACCOUNT OR NETWORK TELEMETRY",
        "close":"X","recommended":"Next objective: {name}",
        "noawards":"No achievements yet. Earn them through actual game choices."
    }
}
const MISSION_NAMES := {
    "ru":{"blackout":"01 / GRID — ЭНЕРГОКОНТУР","thermal":"02 / HEAT — ПЕРЕГРЕВ","breach":"03 / AIR — РАЗГЕРМЕТИЗАЦИЯ"},
    "en":{"blackout":"01 / GRID — POWER FAILURE","thermal":"02 / HEAT — THERMAL CASCADE","breach":"03 / AIR — OXYGEN BREACH"}
}

var _eyebrow: Label
var _heading: Label
var _subtitle: Label
var _metric_labels: Array[Label] = []
var _metric_values: Array[Label] = []
var _chapter_heading: Label
var _chapter_labels: Dictionary = {}
var _settings_heading: Label
var _settings_buttons: Dictionary = {}
var _rewards_heading: Label
var _rewards_label: Label
var _history_heading: Label
var _history_label: Label
var _next_heading: Label
var _recommend_label: Label
var launch_button: Button
var close_button: Button
var _footer: Label
var _scroll: ScrollContainer
var _language: String = "ru"
var _recommended: String = "blackout"

func _init() -> void:
    name = "OperationsPlatformV9"
    mouse_filter = Control.MOUSE_FILTER_STOP
    visible = false
    z_index = 90

func _ready() -> void:
    var shell := StyleBoxFlat.new()
    shell.bg_color = INK
    shell.border_color = EDGE
    shell.set_border_width_all(1)
    shell.set_corner_radius_all(13)
    shell.shadow_color = Color(0,0,0,0.60)
    shell.shadow_size = 18
    shell.set_content_margin_all(17)
    add_theme_stylebox_override("panel",shell)
    var vertical := VBoxContainer.new()
    vertical.add_theme_constant_override("separation",10)
    add_child(vertical)
    var header := HBoxContainer.new()
    header.add_theme_constant_override("separation",8)
    vertical.add_child(header)
    var brand := VBoxContainer.new()
    brand.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    brand.add_theme_constant_override("separation",5)
    header.add_child(brand)
    _eyebrow = _make_label(brand,"",12,COPPER)
    _heading = _make_label(brand,"",29,ICE)
    _subtitle = _make_label(brand,"",12,MUTED)
    close_button = _button("X",Vector2(56,48))
    close_button.name = "CloseOperations"
    close_button.pressed.connect(func(): close_requested.emit())
    header.add_child(close_button)
    _rule(vertical)
    _scroll = ScrollContainer.new()
    _scroll.name = "OperationsScroll"
    _scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
    _scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    vertical.add_child(_scroll)
    var content := VBoxContainer.new()
    content.name = "OperationsContent"
    content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    content.add_theme_constant_override("separation",15)
    _scroll.add_child(content)
    var metrics := HBoxContainer.new()
    metrics.add_theme_constant_override("separation",8)
    content.add_child(metrics)
    for index in range(3):
        var cell := _card(metrics)
        cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        cell.custom_minimum_size = Vector2(100,75)
        var stack := VBoxContainer.new()
        stack.add_theme_constant_override("separation",3)
        cell.add_child(stack)
        var lbl := _make_label(stack,"",11,MUTED)
        var val := _make_label(stack,"0",27,SIGNAL if index==0 else ICE if index==1 else COPPER)
        _metric_labels.append(lbl)
        _metric_values.append(val)
    _chapter_heading = _make_label(content,"",15,COPPER)
    for scenario in IPCrisisEngine.SCENARIOS:
        var outer := _card(content)
        outer.custom_minimum_size.y = 76
        var row := VBoxContainer.new()
        row.add_theme_constant_override("separation",4)
        outer.add_child(row)
        _chapter_labels[scenario] = [
            _make_label(row,"",16,ICE),
            _make_label(row,"",12,MUTED)
        ]
    _settings_heading = _make_label(content,"",15,COPPER)
    var setting_grid := GridContainer.new()
    setting_grid.name = "RealAccessibleSettings"
    setting_grid.columns = 2
    setting_grid.add_theme_constant_override("h_separation",8)
    setting_grid.add_theme_constant_override("v_separation",8)
    content.add_child(setting_grid)
    for option in ["language","graphics","reduced_motion","muted"]:
        var option_button := _button("",Vector2(140,50))
        option_button.name = "Preference_"+option
        option_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        option_button.pressed.connect(_request_setting.bind(option))
        setting_grid.add_child(option_button)
        _settings_buttons[option] = option_button
    _rewards_heading = _make_label(content,"",15,COPPER)
    var awards := _card(content)
    _rewards_label = _make_label(awards,"",13,ICE)
    _history_heading = _make_label(content,"",15,COPPER)
    var history := _card(content)
    _history_label = _make_label(history,"",13,MUTED)
    _next_heading = _make_label(content,"",15,COPPER)
    _recommend_label = _make_label(content,"",14,SIGNAL)
    launch_button = _button("",Vector2(0,48))
    launch_button.name = "LaunchRecommendedOperation"
    launch_button.pressed.connect(func(): launch_requested.emit(_recommended))
    content.add_child(launch_button)
    _rule(vertical)
    _footer = _make_label(vertical,"",10,MUTED)
    _footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _request_setting(option: String) -> void:
    setting_requested.emit(option)

func _make_label(parent: Node,words: String,font_size: int,tint: Color) -> Label:
    var node := Label.new()
    node.text = words
    node.add_theme_font_size_override("font_size",font_size)
    node.add_theme_color_override("font_color",tint)
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(node)
    return node

func _rule(parent: Control) -> void:
    var line := ColorRect.new()
    line.color = EDGE
    line.custom_minimum_size.y = 1
    line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(line)

func _card(parent: Control) -> PanelContainer:
    var node := PanelContainer.new()
    var style := StyleBoxFlat.new()
    style.bg_color = GUNMETAL
    style.border_color = Color(0.19,0.32,0.38,0.6)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(11)
    node.add_theme_stylebox_override("panel",style)
    parent.add_child(node)
    return node

func _button(words: String,minimum: Vector2) -> Button:
    var node := Button.new()
    node.text = words
    node.custom_minimum_size = minimum
    node.add_theme_font_size_override("font_size",14)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color(0.10,0.23,0.28)
    normal.border_color = Color(0.31,0.65,0.72,0.75)
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(7)
    normal.set_content_margin_all(10)
    node.add_theme_stylebox_override("normal",normal)
    var hovered := normal.duplicate() as StyleBoxFlat
    hovered.bg_color = Color(0.15,0.34,0.40)
    node.add_theme_stylebox_override("hover",hovered)
    return node

func apply_layout(width: float,height: float) -> void:
    var half_width: float = minf(388.0,(width-24.0)/2.0)
    var half_height: float = minf(325.0,(height-24.0)/2.0)
    anchor_left = 0.5
    anchor_right = 0.5
    anchor_top = 0.5
    anchor_bottom = 0.5
    offset_left = -half_width
    offset_right = half_width
    offset_top = -half_height
    offset_bottom = half_height
    var narrow: bool = width < 650.0
    _heading.add_theme_font_size_override("font_size",19 if narrow else 29)
    _subtitle.add_theme_font_size_override("font_size",10 if narrow else 12)
    for value in _metric_values:
        value.add_theme_font_size_override("font_size",20 if narrow else 27)
    for label in _metric_labels:
        label.add_theme_font_size_override("font_size",9 if narrow else 11)

func set_view(profile: IPCareerProfile,language: String,can_launch: bool,runtime_settings: Dictionary={}) -> void:
    _language = "en" if language=="en" else "ru"
    var t: Dictionary = LABELS[_language]
    _eyebrow.text = t["eyebrow"]
    _heading.text = t["heading"]
    _subtitle.text = t["subtitle"]
    for index in range(3):
        _metric_labels[index].text = [t["played"],t["saved"],t["mastery"]][index]
    _metric_values[0].text = str(profile.operations)
    _metric_values[1].text = str(profile.victories)
    _metric_values[2].text = "%d / %d" % [profile.achievements.size(),IPCareerProfile.ACHIEVEMENT_IDS.size()]
    _chapter_heading.text = t["chapters"]
    for scenario in IPCrisisEngine.SCENARIOS:
        var nodes: Array = _chapter_labels[scenario]
        var item: Dictionary = profile.mission_records[scenario]
        (nodes[0] as Label).text = MISSION_NAMES[_language][scenario]
        var time_label: String = "--" if float(item["best_seconds"])<=0.0 else "%.0f s" % float(item["best_seconds"])
        (nodes[1] as Label).text = "%s %d  /  %s %d  /  %s %s  /  %s %s" % [
            t["attempts"],item["attempts"],t["wins"],item["wins"],
            t["best"],item["best_grade"],t["time"],time_label
        ]
    _settings_heading.text = t["settings"]
    var active_settings: Dictionary = profile.preferences.duplicate(true)
    for option in runtime_settings:
        active_settings[option] = runtime_settings[option]
    for option in ["language","graphics","reduced_motion","muted"]:
        var shown: String = ""
        match option:
            "language":
                shown = "RU" if active_settings[option]=="ru" else "EN"
            "graphics":
                shown = str(active_settings[option]).to_upper()
            "reduced_motion":
                shown = t["enabled"] if bool(active_settings[option]) else t["disabled"]
            "muted":
                shown = t["disabled"] if bool(active_settings[option]) else t["enabled"]
        (_settings_buttons[option] as Button).text = "%s: %s" % [t[option],shown]
    _rewards_heading.text = t["rewards"]
    var earned_lines: Array[String] = []
    for achievement_id in IPCareerProfile.ACHIEVEMENT_IDS:
        if profile.achievements.has(achievement_id):
            earned_lines.append("◆  "+profile.achievement_title(achievement_id,_language))
    _rewards_label.text = "\n".join(earned_lines) if not earned_lines.is_empty() else t["noawards"]
    _history_heading.text = t["history"]
    var history_lines: Array[String] = []
    for index in range(mini(5,profile.recent.size())):
        var item: Dictionary = profile.recent[index]
        var mission: String = str(MISSION_NAMES[_language][item["scenario"]]).split(" — ")[0]
        history_lines.append("#%02d   %s   /   %s   /   %s s" % [
            int(item["id"]),mission,t["win"] if item["won"] else t["loss"],
            "%.0f" % float(item["elapsed"])
        ])
    _history_label.text = "\n".join(history_lines) if not history_lines.is_empty() else t["none"]
    _next_heading.text = t["next"]
    _recommended = profile.recommended_scenario()
    _recommend_label.text = str(t["recommended"]).format({"name":MISSION_NAMES[_language][_recommended]})
    launch_button.text = t["launch"]
    launch_button.visible = can_launch
    close_button.text = t["close"]
    _footer.text = t["footer"]
