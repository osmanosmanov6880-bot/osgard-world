extends Control
class_name A7MissionNavCockpit
## W82 original source-driven in-world mission navigation.
## Reads only genuine W70 CharacterBody, Camera3D, W71 phase, W72 equipment,
## W76 goal and original A7 snapshot; NEVER walks, teleports, or chooses for user.

const INK := Color("091723ec")
const COPPER := Color("e9be86")
const CYAN := Color("a9f0e5")
const MUTED := Color("b5c7cf")
var original_mission: A7SpatialMission
var original_equipment: A7FieldOperations
var physical_operator: A7FirstPersonOperator
var world_wayfinder: A7MissionWayfinder
var frame: PanelContainer
var title_label: Label
var status_label: Label
var bearing_label: Label
var locale: String = "ru"
var live_source_state: Dictionary = {}
var goal_kind: String = "none"
var goal_distance_m: float = -1.0
var physical_near: bool = false
var bearing_degrees: float = 0.0
var redraws: int = 0
var proximity_transitions: int = 0
var _seconds: float = 0.0
var _prior_near: bool = false

func _style() -> StyleBoxFlat:
    var skin := StyleBoxFlat.new()
    skin.bg_color = INK
    skin.border_color = Color("517281")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(9)
    skin.content_margin_left = 11
    skin.content_margin_right = 8
    skin.content_margin_top = 6
    skin.content_margin_bottom = 6
    return skin

func build(mission: A7SpatialMission, equipment: A7FieldOperations,
        operator: A7FirstPersonOperator, wayfinder: A7MissionWayfinder) -> void:
    name = "W82RealPhysicsReadOnlyMissionNavigation"
    original_mission = mission
    original_equipment = equipment
    physical_operator = operator
    world_wayfinder = wayfinder
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    frame = PanelContainer.new()
    frame.name = "W82SourceTruthPhysicalDirectionAndDistance"
    frame.set_anchors_preset(Control.PRESET_TOP_LEFT)
    frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
    frame.offset_left = 10
    frame.offset_right = 310
    frame.offset_top = 58
    frame.offset_bottom = 126
    frame.add_theme_stylebox_override("panel",_style())
    add_child(frame)
    var horizontal := HBoxContainer.new()
    horizontal.name = "RealTargetHeadingWithConciseAction"
    horizontal.mouse_filter = Control.MOUSE_FILTER_IGNORE
    horizontal.add_theme_constant_override("separation",6)
    frame.add_child(horizontal)
    var vertical := VBoxContainer.new()
    vertical.name = "SingleTrueObjectiveAndSourceDistance"
    vertical.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    vertical.mouse_filter = Control.MOUSE_FILTER_IGNORE
    vertical.add_theme_constant_override("separation",3)
    horizontal.add_child(vertical)
    title_label = Label.new()
    title_label.add_theme_color_override("font_color",COPPER)
    title_label.add_theme_font_size_override("font_size",14)
    title_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    title_label.clip_text = true
    vertical.add_child(title_label)
    status_label = Label.new()
    status_label.add_theme_color_override("font_color",MUTED)
    status_label.add_theme_font_size_override("font_size",12)
    status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    status_label.clip_text = true
    vertical.add_child(status_label)
    bearing_label = Label.new()
    bearing_label.custom_minimum_size = Vector2(37,35)
    bearing_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bearing_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    bearing_label.add_theme_color_override("font_color",CYAN)
    bearing_label.add_theme_font_size_override("font_size",28)
    horizontal.add_child(bearing_label)
    visible = false
    set_process(true)

func configure(stage_width: float) -> void:
    if frame == null:
        return
    # Keep the actual source readout inside a genuine 320px screen and
    # below native fullscreen MENU/RU/EN (8..48px, top-right).
    frame.offset_right = maxf(160.0,minf(310.0,stage_width-10.0))

func set_context(immersed: bool, piloting: bool, lang: String,
        state: Dictionary) -> void:
    locale = "en" if lang == "en" else "ru"
    live_source_state = state.duplicate(true)
    visible = (immersed and piloting and original_mission != null
        and original_mission.active and physical_operator != null
        and physical_operator.body != null)
    if visible:
        _paint()

func _turn_to_real_target(target: Vector3) -> float:
    if physical_operator == null or physical_operator.head_camera == null:
        return 0.0
    var forward: Vector3 = -physical_operator.head_camera.global_transform.basis.z
    var toward: Vector3 = target - physical_operator.body.global_position
    forward.y = 0.0
    toward.y = 0.0
    if forward.length_squared() < 0.0001 or toward.length_squared() < 0.0001:
        return 0.0
    forward = forward.normalized()
    toward = toward.normalized()
    # Positive = actual target to camera RIGHT. Purely read-only direction.
    return rad_to_deg(atan2(-forward.cross(toward).y,forward.dot(toward)))

func _arrow(degrees: float) -> String:
    if absf(degrees) < 22.5:
        return "↑"
    if absf(degrees) < 67.5:
        return "↗" if degrees > 0.0 else "↖"
    if absf(degrees) < 112.5:
        return "→" if degrees > 0.0 else "←"
    if absf(degrees) < 157.5:
        return "↘" if degrees > 0.0 else "↙"
    return "↓"

func _paint() -> void:
    if (not visible or original_mission == null or physical_operator == null
            or physical_operator.body == null):
        return
    redraws += 1
    var phase: int = original_mission.phase
    goal_kind = "core" if phase in [0,4] else (
        "relay" if phase == 2 else (
        "decisions" if phase in [1,3] else "terminal"))
    var russian: bool = locale == "ru"
    var phase_word: String = ""
    var detail: String = ""
    bearing_label.text = "●"
    goal_distance_m = -1.0
    physical_near = false
    bearing_degrees = 0.0
    if goal_kind in ["core","relay"]:
        var core: bool = goal_kind == "core"
        var target: Vector3 = (physical_operator.inspection_console_core
            if core else physical_operator.inspection_console_relay)
        var radius: float = 3.2 if core else 4.0
        goal_distance_m = physical_operator.body.position.distance_to(target)
        physical_near = goal_distance_m < radius
        bearing_degrees = _turn_to_real_target(target)
        bearing_label.text = _arrow(bearing_degrees)
        phase_word = (
            ("РЕАКТОР" if core else "РЕЛЕЙНЫЙ ЗАЛ") if russian
            else ("REACTOR" if core else "RELAY HALL"))
        if physical_near:
            var solved: bool = (
                original_equipment.valve_solved if phase == 0 else (
                original_equipment.relay_solved if phase == 2 else
                original_equipment.sync_solved))
            detail = (
                ("ГОТОВО · ОСМОТР E" if russian else "READY · INSPECT E")
                if solved else (
                "НАСТРОЙТЕ УСТРОЙСТВО" if russian else "OPERATE LOCAL DEVICE"))
        else:
            detail = (("%.1f м · ИДИТЕ К УЗЛУ" if russian
                else "%.1f m · GO TO STATION") % goal_distance_m)
    elif goal_kind == "decisions":
        phase_word = "РЕШЕНИЯ" if russian else "DECISIONS"
        var shift: int = mini(6,int(live_source_state.get("shift",0))+1)
        var actions_left: int = int(live_source_state.get("actions_left",0))
        detail = (("%d/6 · ХОДОВ ОСТАЛОСЬ %d" if russian
            else "%d/6 · ACTIONS LEFT %d") % [shift,actions_left])
    else:
        phase_word = (
            ("МИССИЯ ВЫПОЛНЕНА" if phase == 5 else "МИССИЯ ПРОВАЛЕНА")
            if russian else
            ("MISSION COMPLETE" if phase == 5 else "MISSION FAILED"))
        detail = "РЕЗУЛЬТАТ ЯДРА A7" if russian else "A7 CORE RESULT"
    if physical_near != _prior_near:
        proximity_transitions += 1
        _prior_near = physical_near
    title_label.text = "%02d / %s" % [mini(phase+1,5),phase_word]
    status_label.text = detail

func _process(delta: float) -> void:
    if not visible:
        return
    _seconds += minf(delta,0.10)
    if _seconds >= 0.18:
        _seconds = 0.0
        _paint()

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W82_REAL_NAVIGATION_SOURCE_READONLY_V1",
        "visible":visible,
        "source_original_phase":original_mission.phase if original_mission != null else -1,
        "source_target_kind":goal_kind,
        "real_player_body_id":physical_operator.body.get_instance_id()
            if physical_operator != null and physical_operator.body != null else 0,
        "real_distance_m":snappedf(goal_distance_m,0.01),
        "true_physical_device_near":physical_near,
        "real_camera_relative_bearing_deg":snappedf(bearing_degrees,0.1),
        "real_source_redraws":redraws,
        "physical_distance_transitions":proximity_transitions,
        "label":title_label.text if title_label != null else "",
        "guidance":status_label.text if status_label != null else "",
        "native_mouse_ignores_real_world_inputs":mouse_filter==Control.MOUSE_FILTER_IGNORE
            and frame != null and frame.mouse_filter==Control.MOUSE_FILTER_IGNORE,
        "never_mutates_original_gameplay":true,
        "physical_phone_hardware_verified":false,
        "not_AAA_art_certified":true,
    }
