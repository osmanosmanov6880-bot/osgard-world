extends Control
class_name A7MobileMissionDeck
## W79 / complete original five-objective gameplay via touch, without ever
## modifying original W63 cascade decisions, W72 field rules or W77 physics.
## The compact rail is a VIEW of the actual mission state, not an autowin bot.

signal valve_requested(direction: int)
signal relay_requested(index: int)
signal sync_requested(index: int)
signal original_action_requested(action: String)
signal save_requested
signal load_requested
signal restart_requested

const ACTIONS: Array[String] = ["PUMP","VENT","SEAL","SCAN","POWER"]
const AMBER := Color("e9b87b")
const CYAN := Color("97e2d9")
const MUTED := Color("93aab5")
const BG := Color("08121ce8")
const EN_ACTIONS: Dictionary = {
    "PUMP":"PUMP","VENT":"VENT","SEAL":"SEAL",
    "SCAN":"SCAN","POWER":"POWER",
}
const RU_ACTIONS: Dictionary = {
    "PUMP":"НАСОС","VENT":"СБРОС","SEAL":"ЗАТВОР",
    "SCAN":"СКАН","POWER":"ЭНЕРГ.",
}
var mission: A7SpatialMission
var equipment: A7FieldOperations
var operator: A7FirstPersonOperator
var panel: PanelContainer
var headline: Label
var actions: HBoxContainer
var slots: Array[Button] = []
var actual_commands: Array[String] = []
var save_button: Button
var load_button: Button
var current_phase: int = -1
var current_mode: String = "hidden"
var actual_source_phase_changes: int = 0
var physical_equipment_request_count: int = 0
var original_core_action_requests: int = 0
var save_requests: int = 0
var load_requests: int = 0
var restart_requests: int = 0
var rejected_invalid_context: int = 0
var real_source_proximity_rejections_shown: int = 0
var compact: bool = false
var immersed: bool = false
var piloting: bool = false
var locale: String = "ru"
var mobile_screen_width: float = 390.0
var latest_game_state: Dictionary = {}
var real_dynamic_ui_updates: int = 0

func _panel_style() -> StyleBoxFlat:
    var skin := StyleBoxFlat.new()
    skin.bg_color = BG
    skin.border_color = Color("4d6b76")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(10)
    skin.content_margin_left = 7
    skin.content_margin_right = 7
    skin.content_margin_top = 4
    skin.content_margin_bottom = 5
    return skin

func _style_button(button: Button, subtle: bool = false) -> void:
    var skin := StyleBoxFlat.new()
    skin.bg_color = Color("0d2330e0")
    skin.border_color = Color("607a86") if subtle else AMBER
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(6)
    skin.content_margin_left = 3
    skin.content_margin_right = 3
    skin.content_margin_top = 3
    skin.content_margin_bottom = 3
    button.add_theme_stylebox_override("normal",skin)
    var pressed: StyleBoxFlat = skin.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("325061ee")
    pressed.border_color = CYAN
    button.add_theme_stylebox_override("hover",pressed)
    button.add_theme_stylebox_override("pressed",pressed)
    button.add_theme_color_override("font_color",CYAN if subtle else AMBER)
    button.add_theme_font_size_override("font_size",13)
    button.clip_text = true
    button.focus_mode = Control.FOCUS_NONE
    button.mouse_filter = Control.MOUSE_FILTER_STOP
    button.size_flags_horizontal = Control.SIZE_EXPAND_FILL

func build(real_mission: A7SpatialMission,
        real_equipment: A7FieldOperations,
        real_operator: A7FirstPersonOperator) -> void:
    name = "W79AllFiveRealMissionPhasesOnOriginalMobileViewport"
    mission = real_mission
    equipment = real_equipment
    operator = real_operator
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

    panel = PanelContainer.new()
    panel.name = "W79ContextOnlySourceDrivenMissionCommands"
    panel.anchor_left = 0.0
    panel.anchor_right = 1.0
    panel.anchor_top = 1.0
    panel.anchor_bottom = 1.0
    panel.offset_left = 7
    panel.offset_right = -7
    # W80: the real 4x2 W78 thumb grid now occupies the bottom 112px.
    # Keep the entire five-phase mission above it with a visible 5px gap,
    # within the exact original live 3D stage; no overlay intercepts WASD.
    panel.offset_top = -231
    panel.offset_bottom = -124
    panel.add_theme_stylebox_override("panel",_panel_style())
    panel.mouse_filter = Control.MOUSE_FILTER_PASS
    add_child(panel)

    var vertical := VBoxContainer.new()
    vertical.name = "OneGoalOnlyThenActualCommands"
    vertical.add_theme_constant_override("separation",3)
    panel.add_child(vertical)
    var status_row := HBoxContainer.new()
    status_row.add_theme_constant_override("separation",4)
    vertical.add_child(status_row)
    headline = Label.new()
    headline.name = "OriginalMissionProgressNoSyntheticInstructions"
    headline.add_theme_color_override("font_color",CYAN)
    headline.add_theme_font_size_override("font_size",12)
    headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    headline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    headline.clip_text = true
    status_row.add_child(headline)

    save_button = Button.new()
    save_button.name = "W79OriginalOfflineCheckpointSave"
    save_button.custom_minimum_size = Vector2(43,23)
    _style_button(save_button,true)
    save_button.pressed.connect(_save)
    status_row.add_child(save_button)
    load_button = Button.new()
    load_button.name = "W79AuthenticSourceVerifiedCheckpointLoad"
    load_button.custom_minimum_size = Vector2(43,23)
    _style_button(load_button,true)
    load_button.pressed.connect(_load)
    status_row.add_child(load_button)

    actions = HBoxContainer.new()
    actions.name = "W79OnlyCurrentMachineOrTwoActionCascade"
    actions.add_theme_constant_override("separation",4)
    vertical.add_child(actions)
    for idx in range(5):
        var button := Button.new()
        button.name = "W79TrueSourceDecisionSlot%d" % idx
        button.custom_minimum_size = Vector2(44,46)
        _style_button(button)
        button.pressed.connect(_dispatch.bind(idx))
        actions.add_child(button)
        slots.append(button)
    visible = false
    set_process(false)

func _eligible() -> bool:
    return compact and immersed and piloting and mission != null and (
        mission.active and mission.extended_mode and equipment != null and
        equipment.enabled and operator != null and operator.piloting)

func set_context(is_compact: bool, is_immersive: bool, is_piloting: bool,
        lang: String, actual_width: float, state: Dictionary) -> void:
    compact = is_compact
    immersed = is_immersive
    piloting = is_piloting
    locale = "en" if lang == "en" else "ru"
    mobile_screen_width = actual_width
    var new_visible: bool = _eligible()
    visible = new_visible
    if new_visible:
        refresh(state)
    else:
        current_mode = "hidden"
        actual_commands.clear()

func _progress() -> String:
    if locale == "ru":
        return "МИССИЯ" if mission != null else "A7"
    return "MISSION"

func _label_for(action: String) -> String:
    if locale == "ru":
        return str(RU_ACTIONS.get(action,action))
    return str(EN_ACTIONS.get(action,action))

func refresh(state: Dictionary) -> void:
    if not _eligible():
        visible = false
        current_mode = "hidden"
        actual_commands.clear()
        return
    visible = true
    latest_game_state = state.duplicate(true)
    real_dynamic_ui_updates += 1
    var phase: int = mission.phase
    if current_phase != phase:
        current_phase = phase
        actual_source_phase_changes += 1
    actual_commands.clear()
    var heading: String = ""
    match phase:
        0:
            current_mode = "valve"
            actual_commands.append_array(["VALVE_MINUS","VALVE_PLUS"])
            heading = (("РЕАКТОР • КЛАПАН %d/%d" if locale=="ru" else
                "REACTOR • VALVE %d/%d") %
                [equipment.valve_index,equipment.valve_target])
        1,3:
            current_mode = "decisions"
            actual_commands.append_array(ACTIONS)
            heading = (("СМЕНА %d/6 • РЕШЕНИЯ %d/2" if locale=="ru" else
                "SHIFT %d/6 • DECISIONS %d/2") %
                [mini(6,int(state.get("shift",0))+1),
                int(state.get("actions_left",0))])
        2:
            current_mode = "relay"
            actual_commands.append_array(["RELAY_0","RELAY_1","RELAY_2"])
            heading = (("РЕЛЕ • ШИНА %d/%d" if locale=="ru" else
                "RELAY • BUS %d/%d") %
                [equipment.relay_mask,equipment.relay_target])
        4:
            current_mode = "sync"
            actual_commands.append_array(["SYNC_0","SYNC_1","SYNC_2"])
            heading = (("РЕАКТОР • СИНХРОНИЗАЦИЯ %d/3" if locale=="ru" else
                "REACTOR • SYNC %d/3") % equipment.sync_step)
        5:
            current_mode = "complete"
            actual_commands.append("RESTART")
            heading = ("КОНТУР СТАБИЛЕН / ПОБЕДА" if locale=="ru" else
                "CONTAINMENT STABLE / VICTORY")
        6:
            current_mode = "failed"
            actual_commands.append("RESTART")
            heading = ("КОНТУР ПОТЕРЯН / ПОВТОР" if locale=="ru" else
                "CONTAINMENT LOST / RETRY")
        _:
            current_mode = "hidden"
    headline.text = heading
    save_button.text = "СОХР" if locale == "ru" else "SAVE"
    load_button.text = "ЗАГР" if locale == "ru" else "LOAD"
    save_button.tooltip_text = (
        "Сохранить действительную игру / F5" if locale=="ru" else
        "Save real source-authenticated game / F5")
    load_button.tooltip_text = (
        "Загрузить проверенное сохранение / F9" if locale=="ru" else
        "Load checked original game / F9")
    for idx in range(slots.size()):
        var button: Button = slots[idx]
        button.visible = idx < actual_commands.size()
        if not button.visible:
            continue
        var command: String = actual_commands[idx]
        if command == "VALVE_MINUS":
            button.text = "−"
        elif command == "VALVE_PLUS":
            button.text = "+"
        elif command.begins_with("RELAY_"):
            button.text = "ABC"[int(command.right(1))]
        elif command.begins_with("SYNC_"):
            button.text = str(int(command.right(1))+1)
        elif command == "RESTART":
            button.text = "ПОВТОР" if locale=="ru" else "RESTART"
        else:
            button.text = _label_for(command)
        var available: bool = true
        if current_mode=="valve":
            available = not equipment.valve_solved
        elif current_mode=="relay":
            available = not equipment.relay_solved
        elif current_mode=="sync":
            available = not equipment.sync_solved
        elif current_mode=="decisions":
            available = (str(state.get("status",""))=="playing"
                and int(state.get("actions_left",0)) > 0)
        button.disabled = not available
        button.custom_minimum_size = Vector2(
            38 if mobile_screen_width < 355.0 else 51,46)
        button.tooltip_text = ("Действие оригинальной игры: " if locale=="ru"
            else "Actual original game command: ") + command

func report_real_physical_result(accepted: bool) -> void:
    if accepted or not _eligible():
        return
    # Only the original W72 input handler knows whether collision/proximity
    # rejected an action. Display its real result in the current mission dock;
    # never show fake success or change field/mission/game state.
    real_source_proximity_rejections_shown += 1
    headline.text = ("ПОДОЙДИТЕ К УСТРОЙСТВУ • НЕ ПРИНЯТО"
        if locale=="ru" else "MOVE CLOSER TO DEVICE • REJECTED")

func _dispatch(idx: int) -> void:
    if not _eligible() or idx < 0 or idx >= actual_commands.size():
        rejected_invalid_context += 1
        return
    var key: String = actual_commands[idx]
    var phase: int = mission.phase
    if phase==0 and key in ["VALVE_MINUS","VALVE_PLUS"]:
        if equipment.valve_solved:
            rejected_invalid_context += 1
            return
        physical_equipment_request_count += 1
        valve_requested.emit(-1 if key=="VALVE_MINUS" else 1)
    elif phase==2 and key.begins_with("RELAY_"):
        if equipment.relay_solved:
            rejected_invalid_context += 1
            return
        physical_equipment_request_count += 1
        relay_requested.emit(int(key.right(1)))
    elif phase==4 and key.begins_with("SYNC_"):
        if equipment.sync_solved:
            rejected_invalid_context += 1
            return
        physical_equipment_request_count += 1
        sync_requested.emit(int(key.right(1)))
    elif phase in [1,3] and ACTIONS.has(key):
        if (str(latest_game_state.get("status","")) != "playing" or
                int(latest_game_state.get("actions_left",0)) <= 0):
            rejected_invalid_context += 1
            return
        original_core_action_requests += 1
        original_action_requested.emit(key)
    elif phase in [5,6] and key=="RESTART":
        restart_requests += 1
        restart_requested.emit()
    else:
        rejected_invalid_context += 1

func _save() -> void:
    if not _eligible():
        rejected_invalid_context += 1
        return
    save_requests += 1
    save_requested.emit()

func _load() -> void:
    if not _eligible():
        rejected_invalid_context += 1
        return
    load_requests += 1
    load_requested.emit()

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W79_TRUE_COMPLETE_SOURCE_MISSION_TOUCH_V1",
        "original_mission_phase":mission.phase if mission != null else -1,
        "active_context":current_mode,
        "native_context_buttons":slots.size(),
        "current_original_commands":actual_commands.duplicate(),
        "real_source_phase_changes":actual_source_phase_changes,
        "physical_equipment_requests_not_automatic_success":physical_equipment_request_count,
        "original_core_decision_requests_not_fabricated_results":original_core_action_requests,
        "actual_offline_save_requests":save_requests,
        "source_checked_load_requests":load_requests,
        "original_restart_requests":restart_requests,
        "rejected_context_inputs":rejected_invalid_context,
        "real_source_proximity_rejections_shown":real_source_proximity_rejections_shown,
        "live_source_state_redraws":real_dynamic_ui_updates,
        "visible":visible,
        "read_only_source_authority":true,
        "no_fake_physical_inspections_or_win":true,
        "mobile_hardware_playtested":false,
    }
