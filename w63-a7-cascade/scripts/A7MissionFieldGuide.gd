extends Control
class_name A7MissionFieldGuide
## W85: source-driven mission field guide. It reads the ORIGINAL A7 mission,
## actual physics-body distance, real equipment gates and native A7 state.
## No automatic choices, fabricated progress or movement teleports.

signal opened_changed(is_open: bool)

const COPPER := Color("eabe85")
const CYAN := Color("a7f0e2")
const MUTED := Color("afc2cc")
const SUCCESS := Color("8bd5af")
const INK := Color("08141ff7")
var mission: A7SpatialMission
var equipment: A7FieldOperations
var operator: A7FirstPersonOperator
var navigation: A7MissionNavCockpit
var stage: Control
var entry_button: Button
var panel: PanelContainer
var title_label: Label
var subtitle_label: Label
var progress_line: HBoxContainer
var progress_pips: Array[Label] = []
var objective_label: Label
var distance_label: Label
var steps: Array[Label] = []
var close_button: Button
var opened: bool = false
var source_visible: bool = false
var locale: String = "ru"
var current_phase: int = -1
var source_history_count: int = 0
var current_distance_m: float = -1.0
var within_source_range: bool = false
var source_goal: String = "none"
var latest_state: Dictionary = {}
var renders: int = 0
var phase_transitions: int = 0
var opens: int = 0
var closes: int = 0
var blocked_inactive_opens: int = 0
var gameplay_actions_issued: int = 0
var refresh_elapsed: float = 0.0

func _button(parent: Node, id: String, caption: String) -> Button:
    var button := Button.new()
    button.name = id
    button.text = caption
    button.custom_minimum_size = Vector2(80,44)
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.focus_mode = Control.FOCUS_NONE
    button.add_theme_font_size_override("font_size",12)
    button.add_theme_color_override("font_color",COPPER)
    var skin := StyleBoxFlat.new()
    skin.bg_color = Color("102735f9")
    skin.border_color = Color("607e8b")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(8)
    skin.set_content_margin_all(6)
    button.add_theme_stylebox_override("normal",skin)
    var hover: StyleBoxFlat = skin.duplicate() as StyleBoxFlat
    hover.bg_color = Color("294854")
    hover.border_color = CYAN
    button.add_theme_stylebox_override("hover",hover)
    button.add_theme_stylebox_override("pressed",hover)
    parent.add_child(button)
    return button

func _label(parent: Container, id: String, text_size: int,
        tone: Color, wrap: bool = false) -> Label:
    var label := Label.new()
    label.name = id
    label.add_theme_color_override("font_color",tone)
    label.add_theme_font_size_override("font_size",text_size)
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    label.clip_text = not wrap
    label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    if wrap:
        label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    parent.add_child(label)
    return label

func build(real_stage: Control, original_mission: A7SpatialMission,
        original_equipment: A7FieldOperations,
        original_operator: A7FirstPersonOperator,
        original_compass: A7MissionNavCockpit) -> void:
    name = "W85TrueOriginalMissionHumanFieldGuide"
    stage = real_stage
    mission = original_mission
    equipment = original_equipment
    operator = original_operator
    navigation = original_compass
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 22

    entry_button = _button(self,"W85SourceMissionGuideEntry","СПРАВКА")
    entry_button.offset_left = 93
    entry_button.offset_right = 182
    entry_button.offset_top = 8
    entry_button.offset_bottom = 52
    entry_button.pressed.connect(_toggle_open)

    panel = PanelContainer.new()
    panel.name = "W85RealSourceFiveObjectiveGuide"
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    var shell := StyleBoxFlat.new()
    shell.bg_color = INK
    shell.border_color = Color("607b88")
    shell.set_border_width_all(1)
    shell.set_corner_radius_all(12)
    shell.set_content_margin_all(10)
    panel.add_theme_stylebox_override("panel",shell)
    add_child(panel)
    var vertical := VBoxContainer.new()
    vertical.name = "OneGoalThreeHumanSteps"
    vertical.add_theme_constant_override("separation",5)
    panel.add_child(vertical)
    title_label = _label(vertical,"OriginalPhaseName",14,COPPER)
    subtitle_label = _label(vertical,"OriginalPhaseDetail",11,MUTED)
    progress_line = HBoxContainer.new()
    progress_line.name = "FiveActualMissionProgressMarkers"
    progress_line.add_theme_constant_override("separation",5)
    progress_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vertical.add_child(progress_line)
    for index in range(5):
        var pip := _label(progress_line,"RealPhase%02d" % (index+1),11,MUTED)
        pip.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
        progress_pips.append(pip)
    objective_label = _label(vertical,"NowOneAuthenticHumanObjective",14,CYAN)
    distance_label = _label(vertical,"RealSourcePhysicalRangeFeedback",11,MUTED)
    for i in range(3):
        var step := _label(vertical,"PhysicalHumanStep%02d" % (i+1),12,MUTED)
        steps.append(step)
    close_button = _button(vertical,"W85ReturnToOriginalPhysicalMission","К МИССИИ")
    close_button.pressed.connect(_toggle_open)
    panel.visible = false
    visible = false
    set_process(true)

func configure(viewport_size: Vector2) -> void:
    if panel == null:
        return
    # At <=355px the original W80 top-right MENU starts around x118.
    # The 390px W85 GUIDE x93..182 would overlap MENU and accidentally
    # EXIT the genuine full-bleed game. At narrow width, put GUIDE
    # deliberately BELOW the real W82 top compass (ends at y126).
    if viewport_size.x < 356.0:
        entry_button.offset_left = 8.0
        entry_button.offset_right = 99.0
        entry_button.offset_top = 135.0
        entry_button.offset_bottom = 179.0
    else:
        entry_button.offset_left = 93.0
        entry_button.offset_right = 182.0
        entry_button.offset_top = 8.0
        entry_button.offset_bottom = 52.0
    var width: float = minf(372.0,viewport_size.x-18.0)
    panel.offset_left = -width*0.5
    panel.offset_right = width*0.5
    panel.offset_top = maxf(58.0,minf(76.0,(viewport_size.y-270.0)*0.5))
    panel.offset_bottom = minf(viewport_size.y-9.0,panel.offset_top+272.0)

func set_context(allowed: bool, language: String, viewport_size: Vector2,
        actual_game_state: Dictionary) -> void:
    locale = "en" if language=="en" else "ru"
    latest_state = actual_game_state.duplicate(true)
    source_visible = (allowed and mission != null and
        mission.active and operator != null and operator.piloting and
        operator.body != null)
    if not source_visible:
        opened = false
    visible = source_visible
    if panel != null:
        panel.visible = source_visible and opened
    configure(viewport_size)
    _paint_source()

func _local(english: String, russian: String) -> String:
    return english if locale=="en" else russian

func _paint_source() -> void:
    if mission == null or title_label == null:
        return
    renders += 1
    var phase: int = mission.phase
    if current_phase != phase:
        if current_phase >= 0:
            phase_transitions += 1
        current_phase = phase
    var history: Array = latest_state.get("history",[]) as Array
    source_history_count = history.size()
    source_goal = "core" if phase in [0,4] else (
        "relay" if phase==2 else (
        "decisions" if phase in [1,3] else "result"))
    current_distance_m = -1.0
    within_source_range = false
    if source_goal in ["core","relay"] and operator != null and operator.body != null:
        var target: Vector3 = (
            operator.inspection_console_core if source_goal=="core"
            else operator.inspection_console_relay)
        var radius: float = 3.2 if source_goal=="core" else 4.0
        current_distance_m = operator.body.position.distance_to(target)
        within_source_range = current_distance_m<radius

    entry_button.text = _local("GUIDE","ПОМОЩЬ")
    close_button.text = _local("BACK TO MISSION","К МИССИИ")
    title_label.text = _local("MISSION FIELD GUIDE","ПОЛЕВОЙ СПРАВОЧНИК")
    subtitle_label.text = _local("READS REAL GAME / NO AUTOPLAY",
        "РЕАЛЬНАЯ МИССИЯ / БЕЗ АВТОПРОХОЖДЕНИЯ")
    for index in range(progress_pips.size()):
        var pip: Label=progress_pips[index]
        # Some default Godot web fonts do not contain ornamental circle
        # glyphs. Native text-only numbers plus SOURCE-DRIVEN color are
        # readable at 320px and never show replacement-box symbols.
        pip.text = "%02d" % (index+1)
        pip.add_theme_color_override("font_color",
            SUCCESS if phase>index else (COPPER if phase==index else MUTED))
    var goal: String=""
    var lines: Array[String]=[]
    match phase:
        0:
            goal = _local("01 / CALIBRATE CORE VALVE",
                "01 / НАСТРОЙКА КЛАПАНА")
            lines = [
                _local("W/A/S/D: walk to reactor","W/A/S/D: к реактору"),
                _local("Use VALVE +/- to align detents","КЛАПАН +/−: настройте деления"),
                _local("When calibrated press E to inspect",
                    "После настройки нажмите E"),
            ]
        1:
            goal = _local("02 / FIRST TWO REAL DECISIONS",
                "02 / ПЕРВЫЕ ДВА РЕШЕНИЯ")
            lines = [
                _local("Watch real heat / pressure / power",
                    "Следите за нагревом и давлением"),
                _local("Choose commands on mission dock",
                    "Выберите команды на панели миссии"),
                _local("Two choices advance the real shift",
                    "Два действия завершают смену"),
            ]
        2:
            goal = _local("03 / POWER RELAY",
                "03 / СИЛОВОЕ РЕЛЕ")
            lines = [
                _local("Follow original compass into sector 02",
                    "По компасу идите в сектор 02"),
                _local("Configure A/B/C physical relays",
                    "Настройте физические реле A/B/C"),
                _local("Press E only after relay is ready",
                    "Нажмите E после настройки реле"),
            ]
        3:
            goal = _local("04 / SURVIVE SIX CRISIS CYCLES",
                "04 / ВЫДЕРЖИТЕ ШЕСТЬ ЦИКЛОВ")
            lines = [
                _local("One real command per chosen action",
                    "Каждая команда меняет реальные параметры"),
                _local("Balance heat, pressure and power",
                    "Балансируйте нагрев, давление, энергию"),
                _local("Reach source engine WIN, not fake timer",
                    "Добейтесь победы ядра, не таймера"),
            ]
        4:
            goal = _local("05 / RETURN TO REACTOR",
                "05 / ВОЗВРАЩЕНИЕ К РЕАКТОРУ")
            lines = [
                _local("Navigate physically back to sector 01",
                    "Вернитесь в сектор 01 самостоятельно"),
                _local("Match all three SYNC connectors in order",
                    "Включите три разъёма СИНХР. по порядку"),
                _local("Press E near reactor to confirm victory",
                    "Нажмите E у реактора для завершения"),
            ]
        5:
            goal = _local("MISSION COMPLETE / SOURCE VERIFIED",
                "МИССИЯ ПРОЙДЕНА / ПОДТВЕРЖДЕНО")
            lines = [
                _local("The original A7 core confirmed victory",
                    "Победа подтверждена ядром A7"),
                _local("Your real decisions remain recorded",
                    "Принятые решения остались в журнале"),
                _local("Use mission dock for another attempt",
                    "Повтор можно начать с панели миссии"),
            ]
        6:
            goal = _local("CONTAINMENT LOST / RESTART",
                "КОНТУР ПОТЕРЯН / ПОВТОР")
            lines = [
                _local("Original core reported failure",
                    "Исходное ядро сообщило о поражении"),
                _local("Review your choices and equipment",
                    "Пересмотрите решения и оборудование"),
                _local("Use original restart to try again",
                    "Для новой попытки нажмите ПОВТОР"),
            ]
        _:
            goal = _local("WAIT FOR SOURCE MISSION","ОЖИДАНИЕ МИССИИ")
            lines = ["","",""]
    objective_label.text=goal
    if current_distance_m>=0:
        distance_label.text=(
            _local("READY / %.1f m — genuine physical proximity",
                "РЯДОМ / %.1f м — физическая дистанция")
            if within_source_range else _local(
                "DISTANCE %.1f m — WALK CLOSER",
                "РАССТОЯНИЕ %.1f м — ПОДОЙДИТЕ БЛИЖЕ")
        ) % current_distance_m
    elif phase in [1,3]:
        distance_label.text = _local(
            "SOURCE CYCLE %d/6 · ACTIONS LEFT %d",
            "СМЕНА %d/6 · ОСТАЛОСЬ ДЕЙСТВИЙ %d") % [
            mini(6,int(latest_state.get("shift",0))+1),
            int(latest_state.get("actions_left",0))]
    else:
        distance_label.text = _local("SOURCE RESULT · NOT A MOCKUP",
            "ИСХОДНЫЙ РЕЗУЛЬТАТ · НЕ МАКЕТ")
    for i in range(steps.size()):
        (steps[i] as Label).text = "%d. %s" % [i+1,lines[i]]

func close_guide() -> void:
    if not opened:
        return
    opened = false
    if panel != null:
        panel.visible = false
    closes += 1
    opened_changed.emit(false)

func _toggle_open() -> void:
    if not source_visible:
        blocked_inactive_opens += 1
        return
    if opened:
        close_guide()
        return
    opened = true
    panel.visible = true
    opens += 1
    _paint_source()
    opened_changed.emit(true)

func _process(delta: float) -> void:
    if not (source_visible and opened):
        return
    refresh_elapsed += minf(delta,0.10)
    if refresh_elapsed>=0.25:
        refresh_elapsed=0.0
        _paint_source()

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W85_REAL_MISSION_GUIDE_V1",
        "visible":visible,
        "opened":opened,
        "source_phase":current_phase,
        "real_history_entries":source_history_count,
        "source_target_kind":source_goal,
        "real_physical_distance_m":snappedf(current_distance_m,0.01),
        "actual_physical_near":within_source_range,
        "actual_source_render_updates":renders,
        "source_phase_transitions":phase_transitions,
        "opens":opens,
        "closes":closes,
        "inactive_opens_blocked":blocked_inactive_opens,
        "real_original_w70_body":operator.body.get_instance_id()
            if operator != null and operator.body != null else 0,
        "native_guide_on_original_stage":get_parent()==stage,
        "five_source_progress_markers":progress_pips.size(),
        "human_readable_steps":steps.size(),
        "original_gameplay_actions_issued":gameplay_actions_issued,
        "source_truth_only":true,
        "hardware_tested":false,
    }
