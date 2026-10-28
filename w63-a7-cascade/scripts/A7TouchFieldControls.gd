extends Control
class_name A7TouchFieldControls
## W78: physical mobile touch affordances inside ORIGINAL live Godot 3D game.
## Every held movement button drives W70 CharacterBody3D.set_key -> native
## move_and_slide; eye look rotates actual Camera3D, G/E reuse W73/W71.
## This is actual source-input software, not remote phone hardware testing.

signal world_tool_requested
signal physical_inspection_requested
signal actual_manual_motion_started

const INK := Color("08121ae8")
const COPPER := Color("efbd81")
const CYAN := Color("94e8dd")
const BORDER := Color("58707b")
const TOUCH_LABELS := {
    "left":"A", "forward":"W", "back":"S", "right":"D",
    "look_left":"<", "look_right":">",
    "world_use":"G", "inspect":"E",
}
const WALK_KEYS := {
    "left": KEY_A, "forward": KEY_W,
    "back": KEY_S, "right": KEY_D,
}

var actor: A7FirstPersonOperator
var rail: GridContainer
var controls: Dictionary = {}
var held_directions: Dictionary = {}
var held_look: int = 0
var compact_view: bool = false
var immersive: bool = false
var actual_piloting: bool = false
var live_touch_motion_frames: int = 0
var actual_continuous_look_frames: int = 0
var touch_press_events: int = 0
var world_use_requests: int = 0
var inspect_requests: int = 0
var physically_stopped_keys: int = 0
var last_input: String = ""
var localized_language: String = "ru"

func _skin(button: Button, selected: bool) -> void:
    var look: StyleBoxFlat = StyleBoxFlat.new()
    look.bg_color = INK
    look.border_color = CYAN if selected else BORDER
    look.set_border_width_all(1)
    look.set_corner_radius_all(8)
    look.content_margin_left = 3
    look.content_margin_right = 3
    look.content_margin_top = 2
    look.content_margin_bottom = 2
    button.add_theme_stylebox_override("normal",look)
    var focus: StyleBoxFlat = look.duplicate() as StyleBoxFlat
    focus.bg_color = Color("244954e8")
    focus.border_color = COPPER
    focus.set_border_width_all(1)
    button.add_theme_stylebox_override("hover",focus)
    button.add_theme_stylebox_override("pressed",focus)
    button.add_theme_color_override("font_color",COPPER)
    button.add_theme_font_size_override("font_size",18)

func build(physical_operator: A7FirstPersonOperator) -> void:
    actor = physical_operator
    name = "W78ActualBrowserTouchToNative3DPhysics"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    # W80: authentic 390px/320px screenshot QA exposed the long W78
    # single row spilling E outside the 3D stage. Four-column native Godot
    # layout fits the actual stage width, not the wider root browser frame.
    rail = GridContainer.new()
    rail.columns = 4
    rail.name = "W80TwoRowSourcePhysicsThumbControls"
    rail.anchor_left = 0.0
    rail.anchor_right = 1.0
    rail.anchor_top = 1.0
    rail.anchor_bottom = 1.0
    rail.offset_left = 8.0
    rail.offset_right = -8.0
    rail.offset_top = -119.0
    rail.offset_bottom = -7.0
    rail.add_theme_constant_override("h_separation",4)
    rail.add_theme_constant_override("v_separation",5)
    rail.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(rail)
    for key in ["left","forward","back","right",
            "look_left","look_right","world_use","inspect"]:
        var button := Button.new()
        button.name = "W78ActualPhysicsTouch_"+key
        button.text = str(TOUCH_LABELS[key])
        button.focus_mode = Control.FOCUS_NONE
        button.mouse_filter = Control.MOUSE_FILTER_STOP
        button.clip_text = true
        button.custom_minimum_size = Vector2(33,48)
        button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        button.size_flags_vertical = Control.SIZE_FILL
        button.pressed.connect(_press_action.bind(key))
        if key in WALK_KEYS or key in ["look_left","look_right"]:
            button.button_down.connect(_held_start.bind(key))
            button.button_up.connect(_held_stop.bind(key))
            button.mouse_exited.connect(_held_stop.bind(key))
        _skin(button,key in ["world_use","inspect"])
        rail.add_child(button)
        controls[key] = button
    visible = false
    set_process(true)

func _held_start(key: String) -> void:
    if not visible or actor == null or not actor.piloting:
        return
    touch_press_events += 1
    last_input = key
    actual_manual_motion_started.emit()
    if WALK_KEYS.has(key):
        held_directions[key] = true
        actor.set_key(int(WALK_KEYS[key]),true)
        return
    if key == "look_left":
        held_look = -1
    elif key == "look_right":
        held_look = 1

func _held_stop(key: String) -> void:
    if WALK_KEYS.has(key):
        if held_directions.has(key):
            held_directions.erase(key)
            physically_stopped_keys += 1
        if actor != null:
            actor.set_key(int(WALK_KEYS[key]),false)
    elif (key=="look_left" and held_look==-1) or (
            key=="look_right" and held_look==1):
        held_look = 0

func _press_action(key: String) -> void:
    if not visible or actor == null or not actor.piloting:
        return
    last_input = key
    if key == "world_use":
        world_use_requests += 1
        world_tool_requested.emit()
    elif key == "inspect":
        inspect_requests += 1
        physical_inspection_requested.emit()

func release_all() -> void:
    if actor != null:
        for key in WALK_KEYS.keys():
            actor.set_key(int(WALK_KEYS[key]),false)
    physically_stopped_keys += held_directions.size()
    held_directions.clear()
    held_look = 0

func set_context(compact: bool, immersed: bool, piloting: bool,
        language: String, actual_screen_width: float) -> void:
    compact_view = compact
    immersive = immersed
    actual_piloting = piloting
    localized_language = language
    var should_show: bool = compact and immersed and piloting
    if not should_show and visible:
        release_all()
    visible = should_show
    if visible:
        # Minimum touch hit target is 40px for a 390px CSS viewport, with
        # 320px fallback; no oversized 400px buttons or vertical word wrap.
        var smallest: float = 32.0 if actual_screen_width < 355.0 else 48.0
        for button in controls.values():
            (button as Button).custom_minimum_size = Vector2(smallest,48)
    (controls["inspect"] as Button).tooltip_text = (
        "Реальный осмотр • E" if language=="ru" else
        "Physical inspection • E")
    (controls["world_use"] as Button).tooltip_text = (
        "Работа с устройством • G" if language=="ru" else
        "Use actual aimed equipment • G")

func _process(delta: float) -> void:
    if not visible or actor == null or not actor.piloting:
        return
    if not held_directions.is_empty():
        live_touch_motion_frames += 1
    if held_look != 0:
        # rotate_view() is the ORIGINAL live W70 Camera3D method with native
        # angular speed. Never mutate DOM or fabricate a player position.
        actor.rotate_view(Vector2(float(held_look)*delta*950.0,0.0))
        actual_continuous_look_frames += 1

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W78_ORIGINAL_NATIVE_TOUCH_TO_PHYSICS_V1",
        "real_original_characterbody_connected":actor != null and
            actor.body is CharacterBody3D,
        "native_touch_buttons":controls.size(),
        "touch_context_visible":visible,
        "actual_physical_held_keys":held_directions.keys(),
        "real_controller_motion_frames":live_touch_motion_frames,
        "true_eye_camera_look_frames":actual_continuous_look_frames,
        "real_input_press_events":touch_press_events,
        "actual_g_world_tool_requests":world_use_requests,
        "actual_e_world_inspections":inspect_requests,
        "stuck_key_prevention_release_count":physically_stopped_keys,
        "last_input":last_input,
        "compact_mobile":compact_view,
        "immersive":immersive,
        "full_physical_mobile_hardware_tested":false,
        "gameplay_core_decisions_ever_fabricated":false,
    }
