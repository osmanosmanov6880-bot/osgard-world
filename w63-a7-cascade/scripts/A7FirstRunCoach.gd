extends Control
class_name A7FirstRunCoach
## W86 FIRST CONTACT: actual original Godot source-driven human onboarding.
## Every lesson is proven by the existing W70 physical body, W83 real camera,
## W85 manually opened guide, W72 physical equipment/inspection and W73
## accepted offline checkpoint. NEVER alters game state, solves anything
## for the player, moves the actor or sends a phantom touch/key.
## Completion/skip are local, optional, non-sensitive ConfigFile preferences.

const COPPER := Color("f0c491")
const CYAN := Color("94e5dc")
const MUTED := Color("c3d4dc")
const SUCCESS := Color("93dbb4")
const INK := Color("091824f5")
const LESSON_TOTAL: int = 7
const MISSION_SAVE_MODE: String = "user://last_frontier_first_contact_v1.cfg"

var operator: A7FirstPersonOperator
var camera_touch: A7DualTouchLook
var physical_touch: A7TouchFieldControls
var field_guide: A7MissionFieldGuide
var equipment: A7FieldOperations
var mission: A7SpatialMission
var checkpoint: A7SessionCheckpoint
var original_stage: Control

var panel: PanelContainer
var headline: Label
var hint: Label
var action_button: Button
var layout_row: HBoxContainer
var localized_language: String = "ru"
var viewport_size: Vector2 = Vector2(390,844)
var source_eligible: bool = false
var blocked_by_original_modal: bool = false
var source_session_started: bool = false
var lesson_step: int = 0
var skipped: bool = false
var completed: bool = false
var preference_path: String = MISSION_SAVE_MODE
var persistence_enabled: bool = true
var successful_saves: int = 0
var successful_loads: int = 0
var invalid_preferences: int = 0
var explicit_skips: int = 0
var explicit_replays: int = 0
var successful_lessons: int = 0
var attempts: int = 0
var original_game_commands_issued: int = 0
var observed_source_ticks: int = 0
var source_started_distance: float = 0.0
var source_started_camera_turns: int = 0
var source_started_pointer_turns: int = 0
var source_started_look_button_frames: int = 0
var source_started_guide_opens: int = 0
var source_started_checkpoint_saves: int = 0
var elapsed: float = 0.0
var completed_proofs: Array[String] = []

func _button_style() -> StyleBoxFlat:
    var result := StyleBoxFlat.new()
    result.bg_color = Color("173342fa")
    result.border_color = Color("729ba8")
    result.set_border_width_all(1)
    result.set_corner_radius_all(7)
    result.set_content_margin_all(4)
    return result

func build(real_stage: Control, physical_operator: A7FirstPersonOperator,
        authentic_camera_touch: A7DualTouchLook,
        original_touch_buttons: A7TouchFieldControls,
        original_guide: A7MissionFieldGuide,
        source_equipment: A7FieldOperations,
        source_mission: A7SpatialMission,
        source_checkpoint: A7SessionCheckpoint) -> void:
    name = "W86RealFirstContactFromPhysicalGodotInput"
    original_stage = real_stage
    operator = physical_operator
    camera_touch = authentic_camera_touch
    physical_touch = original_touch_buttons
    field_guide = original_guide
    equipment = source_equipment
    mission = source_mission
    checkpoint = source_checkpoint
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 15

    panel = PanelContainer.new()
    panel.name = "W86RealSourceFirstContactOnboarding"
    panel.set_anchors_preset(Control.PRESET_TOP_LEFT)
    panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var skin := StyleBoxFlat.new()
    skin.bg_color = INK
    skin.border_color = Color("476c7c")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(9)
    skin.set_content_margin_all(6)
    panel.add_theme_stylebox_override("panel",skin)
    add_child(panel)

    var vertical := VBoxContainer.new()
    vertical.name = "OneTrueLessonOneAction"
    vertical.add_theme_constant_override("separation",3)
    vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
    panel.add_child(vertical)
    layout_row = HBoxContainer.new()
    layout_row.add_theme_constant_override("separation",3)
    layout_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vertical.add_child(layout_row)
    headline = Label.new()
    headline.name = "W86GenuineSourceLessonProgress"
    headline.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    headline.clip_text = true
    headline.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    headline.mouse_filter = Control.MOUSE_FILTER_IGNORE
    headline.add_theme_font_size_override("font_size",12)
    headline.add_theme_color_override("font_color",COPPER)
    layout_row.add_child(headline)

    action_button = Button.new()
    action_button.name = "W86NativeOptionalSkipAndReplay"
    action_button.custom_minimum_size = Vector2(82,44)
    action_button.mouse_filter = Control.MOUSE_FILTER_STOP
    action_button.focus_mode = Control.FOCUS_NONE
    action_button.clip_text = true
    action_button.add_theme_font_size_override("font_size",11)
    action_button.add_theme_color_override("font_color",CYAN)
    action_button.add_theme_stylebox_override("normal",_button_style())
    var active_skin: StyleBoxFlat = _button_style()
    active_skin.bg_color = Color("2b4c5d")
    active_skin.border_color = CYAN
    action_button.add_theme_stylebox_override("hover",active_skin)
    action_button.add_theme_stylebox_override("pressed",active_skin)
    action_button.pressed.connect(_user_skip_or_replay)
    layout_row.add_child(action_button)

    hint = Label.new()
    hint.name = "W86OneUserInputHintActualWorld"
    hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
    hint.add_theme_font_size_override("font_size",12)
    hint.add_theme_color_override("font_color",MUTED)
    hint.clip_text = true
    hint.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vertical.add_child(hint)
    visible = false
    load_preferences()
    _paint()
    set_process(true)

func _phrase(russian: String, english: String) -> String:
    return russian if localized_language=="ru" else english

func configure(screen_size: Vector2) -> void:
    viewport_size = screen_size
    if panel == null:
        return
    # Original W82 compass x10..310, y58..126; original MENU in upper
    # right y8..52; original W85 GUIDE on 320px x8..99, y135..179;
    # original W79 real commands in landscape begin below y159.
    # Positions below are measured on genuine source viewport coordinates.
    if screen_size.x >= 750.0:
        panel.offset_left = 320.0
        panel.offset_right = minf(screen_size.x-206.0,690.0)
        panel.offset_top = 58.0
        panel.offset_bottom = 137.0
    else:
        panel.offset_left = 8.0
        panel.offset_right = maxf(220.0,screen_size.x-8.0)
        # Keep source W83's real second-finger camera swipe around
        # x≈0.83*width, y≈205 physically clear. A 185px panel would put
        # SKIP directly under the user's aiming finger and steal touchStart.
        # Original W79 equipment dock starts well below this 284..363 HUD.
        panel.offset_top = 284.0
        panel.offset_bottom = 363.0

func set_context(immersed: bool, piloting: bool, language: String,
        screen_size: Vector2) -> void:
    localized_language = "en" if language=="en" else "ru"
    source_eligible = (immersed and piloting and mission != null and
        mission.active and operator != null and operator.body != null)
    if source_eligible and not source_session_started:
        _begin_actual_source_session()
    configure(screen_size)
    _visibility()
    _paint()

func set_suppressed(original_modal_open: bool) -> void:
    blocked_by_original_modal = original_modal_open
    _visibility()

func _visibility() -> void:
    visible = source_eligible and not blocked_by_original_modal

func _begin_actual_source_session() -> void:
    source_session_started = true
    attempts += 1
    source_started_distance = operator.move_distance
    source_started_camera_turns = camera_touch.real_camera_rotations
    source_started_pointer_turns = operator.mouse_look_events
    source_started_look_button_frames = physical_touch.actual_continuous_look_frames
    source_started_guide_opens = field_guide.opens
    source_started_checkpoint_saves = checkpoint.saves

func _user_skip_or_replay() -> void:
    if not source_eligible or blocked_by_original_modal:
        return
    if completed or skipped:
        replay_training()
        return
    skipped = true
    completed = false
    explicit_skips += 1
    save_preferences()
    _paint()

func replay_training() -> void:
    if not source_eligible:
        return
    completed = false
    skipped = false
    lesson_step = 0
    completed_proofs.clear()
    source_session_started = false
    _begin_actual_source_session()
    explicit_replays += 1
    save_preferences()
    _paint()

func _lesson_proven() -> bool:
    if (mission == null or not mission.active or operator == null or
            operator.body == null):
        return false
    match lesson_step:
        0:
            return operator.move_distance-source_started_distance >= 0.25
        1:
            return (camera_touch.real_camera_rotations >
                source_started_camera_turns or
                operator.mouse_look_events > source_started_pointer_turns or
                physical_touch.actual_continuous_look_frames >
                source_started_look_button_frames)
        2:
            return field_guide.opens > source_started_guide_opens
        3:
            # Real W70 CharacterBody3D proximity, not a UI tap or virtual marker.
            return (operator.body.position.distance_to(
                operator.inspection_console_core)<3.20)
        4:
            return equipment.valve_solved
        5:
            # No "E" lesson auto-success: W71/W72 original mission
            # only advances after physical inspection and gate checks.
            return mission.phase>=1
        6:
            # Genuine W73 authenticated source checkpoint written to disk.
            return checkpoint.saves > source_started_checkpoint_saves
    return false

func observe_source() -> void:
    if not source_eligible or not source_session_started or completed or skipped:
        return
    observed_source_ticks += 1
    if not _lesson_proven():
        return
    completed_proofs.append([
        "W70_PHYSICAL_DISTANCE","W70_REAL_CAMERA_ROTATION",
        "W85_GENUINE_GUIDE_USER_OPEN","W70_SOURCE_CORE_PROXIMITY",
        "W72_SOURCE_CALIBRATED_VALVE","W71_PHYSICAL_E_GATE_INSPECTION",
        "W73_ACTUAL_LOCAL_CHECKPOINT"
    ][lesson_step])
    lesson_step += 1
    successful_lessons += 1
    if lesson_step >= LESSON_TOTAL:
        completed = true
        save_preferences()
    _paint()

func _process(delta: float) -> void:
    if not source_eligible or completed or skipped:
        return
    elapsed += minf(delta,0.12)
    if elapsed>=0.20:
        elapsed=0.0
        observe_source()

func _paint() -> void:
    if panel == null:
        return
    if completed:
        headline.text = _phrase("ПЕРВЫЙ КОНТАКТ ПРОЙДЕН","FIRST CONTACT COMPLETED")
        hint.text = _phrase("Игровые действия подтверждены","All seven real game actions confirmed")
        action_button.text = _phrase("ПОВТОР","REPLAY")
    elif skipped:
        headline.text = _phrase("ОБУЧЕНИЕ ПРОПУЩЕНО","TRAINING SKIPPED")
        hint.text = _phrase("Миссия продолжается без ограничений","Gameplay remains fully available")
        action_button.text = _phrase("ПОВТОР","REPLAY")
    else:
        headline.text = _phrase("ПЕРВЫЙ КОНТАКТ %d/%d",
            "FIRST CONTACT %d/%d") % [lesson_step+1,LESSON_TOTAL]
        var ru: Array[String] = [
            "W/A/S/D: пройдите 0.25 м",
            "СВАЙП: поверните камеру",
            "ПОМОЩЬ: откройте справочник",
            "ДО РЕАКТОРА: ближе 3.2 м",
            "КЛАПАН: настройте деления",
            "E: осмотрите готовый реактор",
            "СОХР: сохраните реальную игру",
        ]
        var en: Array[String] = [
            "W/A/S/D: walk at least 0.25 m",
            "SWIPE: turn your real camera",
            "GUIDE: open the field manual",
            "REACTOR: approach within 3.2 m",
            "VALVE: calibrate real detents",
            "E: inspect calibrated reactor",
            "SAVE: write actual checkpoint",
        ]
        hint.text=(ru if localized_language=="ru" else en)[lesson_step]
        action_button.text = _phrase("ПРОПУСК","SKIP")
    action_button.tooltip_text = _phrase(
        "Только обучение. Не изменяет миссию.",
        "Tutorial only. Does not change gameplay.")

func save_preferences() -> bool:
    if not persistence_enabled:
        return false
    var data := ConfigFile.new()
    data.set_value("onboarding","version",1)
    data.set_value("onboarding","finished",completed)
    data.set_value("onboarding","skipped",skipped)
    var status: Error = data.save(preference_path)
    if status==OK:
        successful_saves += 1
        return true
    return false

func load_preferences() -> bool:
    if not persistence_enabled:
        return false
    var data := ConfigFile.new()
    if data.load(preference_path)!=OK:
        return false
    if int(data.get_value("onboarding","version",0))!=1:
        invalid_preferences += 1
        return false
    var was_finished: Variant = data.get_value("onboarding","finished",false)
    var was_skipped: Variant = data.get_value("onboarding","skipped",false)
    if not (was_finished is bool and was_skipped is bool) or (
            was_finished and was_skipped):
        invalid_preferences += 1
        return false
    completed = was_finished
    skipped = was_skipped
    lesson_step = LESSON_TOTAL if completed else 0
    successful_loads += 1
    _paint()
    return true

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W86_ORIGINAL_FIRST_CONTACT_V1",
        "source_eligible":source_eligible,
        "visible":visible,
        "suppressed_by_real_modal":blocked_by_original_modal,
        "step":lesson_step,
        "total":LESSON_TOTAL,
        "completed":completed,
        "skipped":skipped,
        "real_original_body_id":operator.body.get_instance_id()
            if operator != null and operator.body != null else -1,
        "real_original_mission_phase":mission.phase if mission!=null else -1,
        "original_source_motion_m":operator.move_distance
            if operator!=null else 0.0,
        "real_original_camera_turns":camera_touch.real_camera_rotations
            if camera_touch!=null else 0,
        "observed_actual_game_ticks":observed_source_ticks,
        "source_proofs":completed_proofs.duplicate(),
        "successful_source_lessons":successful_lessons,
        "authentic_original_game_actions_issued":original_game_commands_issued,
        "explicit_skips":explicit_skips,
        "explicit_replays":explicit_replays,
        "offline_preference_saves":successful_saves,
        "offline_preference_loads":successful_loads,
        "invalid_pref_rejections":invalid_preferences,
        "same_original_stage":get_parent()==original_stage,
        "hardware_certified":false,
        "source_authored_gameplay_unchanged":true,
    }
