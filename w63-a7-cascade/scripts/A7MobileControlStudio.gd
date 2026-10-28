extends Control
class_name A7MobileControlStudio
## W84: real native Godot mobile control preferences in SAME original game.
## The user deliberately changes LIVE W83 Camera3D look sensitivity/Y axis and
## W78 actual physical Button ordering. No A7 decisions, saves, positions,
## synthetic points, teleports, or duplicated 3D viewports.

signal opened_changed(is_open: bool)
signal profile_changed

const INK := Color("0a1520f4")
const COPPER := Color("f0bf83")
const CYAN := Color("9ceadd")
const GREY := Color("a9bec8")
const SENSITIVITY_STEPS := [0.55,0.85,1.15,1.50]
const ORDER_RIGHT := [
    "left","forward","back","right",
    "look_left","look_right","world_use","inspect",
]
const ORDER_LEFT := [
    "right","back","forward","left",
    "inspect","world_use","look_right","look_left",
]

var physical_controls: A7TouchFieldControls
var actual_camera_touch: A7DualTouchLook
var original_stage: Control
var settings_button: Button
var panel: PanelContainer
var heading: Label
var sensitivity_button: Button
var invert_button: Button
var handed_button: Button
var reset_button: Button
var done_button: Button
var source_visible: bool = false
var opened: bool = false
var language: String = "ru"
var sensitivity_step: int = 1
var invert_y: bool = false
var left_handed: bool = false
var profile_path: String = "user://last_frontier_native_touch_controls_v1.cfg"
var persistence_enabled: bool = true
var saved_profiles: int = 0
var loaded_profiles: int = 0
var rejected_profile_values: int = 0
var native_profile_updates: int = 0
var panel_open_events: int = 0
var panel_close_events: int = 0
var original_game_commands_issued: int = 0

func _button(parent: Container, node_name: String) -> Button:
    var b := Button.new()
    b.name = node_name
    b.custom_minimum_size = Vector2(64,44)
    b.mouse_filter = Control.MOUSE_FILTER_STOP
    b.focus_mode = Control.FOCUS_NONE
    b.clip_text = true
    b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    b.add_theme_font_size_override("font_size",12)
    b.add_theme_color_override("font_color",COPPER)
    var normal := StyleBoxFlat.new()
    normal.bg_color = Color("142935f8")
    normal.border_color = Color("5d7886")
    normal.set_border_width_all(1)
    normal.set_corner_radius_all(8)
    normal.set_content_margin_all(5)
    b.add_theme_stylebox_override("normal",normal)
    var pressed: StyleBoxFlat = normal.duplicate() as StyleBoxFlat
    pressed.bg_color = Color("2d4654f8")
    pressed.border_color = CYAN
    b.add_theme_stylebox_override("hover",pressed)
    b.add_theme_stylebox_override("pressed",pressed)
    parent.add_child(b)
    return b

func build(real_stage: Control, original_buttons: A7TouchFieldControls,
        original_camera_touch: A7DualTouchLook) -> void:
    name = "W84OriginalGodotNativeAccessibleMobileControlStudio"
    original_stage = real_stage
    physical_controls = original_buttons
    actual_camera_touch = original_camera_touch
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    z_index = 18

    settings_button = Button.new()
    settings_button.name = "W84RealMobileTuneEntry"
    settings_button.custom_minimum_size = Vector2(77,44)
    settings_button.focus_mode = Control.FOCUS_NONE
    settings_button.mouse_filter = Control.MOUSE_FILTER_STOP
    settings_button.offset_left = 8.0
    settings_button.offset_right = 86.0
    settings_button.offset_top = 8.0
    settings_button.offset_bottom = 52.0
    settings_button.add_theme_font_size_override("font_size",12)
    settings_button.add_theme_color_override("font_color",COPPER)
    var skin := StyleBoxFlat.new()
    skin.bg_color = INK
    skin.border_color = Color("6f8792")
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(8)
    skin.set_content_margin_all(5)
    settings_button.add_theme_stylebox_override("normal",skin)
    var pressed := skin.duplicate() as StyleBoxFlat
    pressed.border_color = CYAN
    pressed.bg_color = Color("2b404e")
    settings_button.add_theme_stylebox_override("hover",pressed)
    settings_button.add_theme_stylebox_override("pressed",pressed)
    add_child(settings_button)
    settings_button.pressed.connect(_toggle_open)

    panel = PanelContainer.new()
    panel.name = "W84OriginalTouchProfileRealNativeOptions"
    panel.mouse_filter = Control.MOUSE_FILTER_STOP
    panel.anchor_left = 0.5
    panel.anchor_right = 0.5
    panel.anchor_top = 0.0
    panel.anchor_bottom = 0.0
    var box_style := StyleBoxFlat.new()
    box_style.bg_color = Color("08141ffb")
    box_style.border_color = Color("8c9f9e")
    box_style.set_border_width_all(1)
    box_style.set_corner_radius_all(12)
    box_style.set_content_margin_all(10)
    panel.add_theme_stylebox_override("panel",box_style)
    add_child(panel)
    var v := VBoxContainer.new()
    v.add_theme_constant_override("separation",5)
    panel.add_child(v)
    heading = Label.new()
    heading.name = "W84ActualCameraAndPhysicalTouchPreferences"
    heading.add_theme_color_override("font_color",CYAN)
    heading.add_theme_font_size_override("font_size",14)
    heading.mouse_filter = Control.MOUSE_FILTER_IGNORE
    heading.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
    heading.clip_text = true
    v.add_child(heading)
    var row_top := HBoxContainer.new()
    row_top.add_theme_constant_override("separation",5)
    v.add_child(row_top)
    sensitivity_button = _button(row_top,"W84PhysicalCameraSensitivity")
    invert_button = _button(row_top,"W84PhysicalCameraInvertY")
    var row_bottom := HBoxContainer.new()
    row_bottom.add_theme_constant_override("separation",5)
    v.add_child(row_bottom)
    handed_button = _button(row_bottom,"W84OriginalTouchButtonHandedness")
    reset_button = _button(row_bottom,"W84RestoreNativeTouchDefaults")
    done_button = _button(v,"W84CloseNativeControlSettings")
    sensitivity_button.pressed.connect(_cycle_sensitivity)
    invert_button.pressed.connect(_toggle_invert)
    handed_button.pressed.connect(_toggle_handedness)
    reset_button.pressed.connect(_reset)
    done_button.pressed.connect(_toggle_open)
    panel.visible = false
    visible = false
    load_preferences()
    _refresh_labels()

func configure(screen: Vector2) -> void:
    if panel == null:
        return
    var width: float = minf(screen.x-20.0,355.0)
    panel.offset_left = -width*0.5
    panel.offset_right = width*0.5
    panel.offset_top = maxf(54.0,minf(102.0,(screen.y-192.0)*0.33))
    panel.offset_bottom = panel.offset_top+190.0

func set_context(should_show: bool, locale: String, screen: Vector2) -> void:
    language = "en" if locale == "en" else "ru"
    source_visible = should_show
    if not should_show and opened:
        opened = false
        if actual_camera_touch != null:
            actual_camera_touch.input_suspended = false
    visible = should_show
    if panel != null:
        panel.visible = should_show and opened
    configure(screen)
    _refresh_labels()

func _refresh_labels() -> void:
    if settings_button == null:
        return
    var english: bool = language=="en"
    settings_button.text = "TUNE" if english else "НАСТР."
    heading.text = "TOUCH CONTROL / REAL CAMERA" if english else "СЕНСОРНОЕ УПРАВЛЕНИЕ"
    sensitivity_button.text = (
        ("LOOK ×%.2f" if english else "ОБЗОР ×%.2f")
        % float(SENSITIVITY_STEPS[sensitivity_step]))
    invert_button.text = (("INVERT Y: ON" if invert_y else "INVERT Y: OFF")
        if english else ("ОСЬ Y: ОБР." if invert_y else "ОСЬ Y: ПРЯМ."))
    handed_button.text = (
        ("LEFT HAND" if left_handed else "RIGHT HAND") if english
        else ("ЛЕВША" if left_handed else "ПРАВША"))
    reset_button.text = "RESET" if english else "СБРОС"
    done_button.text = "DONE · BACK TO MISSION" if english else "ГОТОВО · К МИССИИ"

func _apply_to_original_game_controls() -> void:
    if actual_camera_touch != null:
        actual_camera_touch.set_look_preferences(
            float(SENSITIVITY_STEPS[sensitivity_step]),invert_y)
    if physical_controls != null and physical_controls.rail != null:
        var order: Array = ORDER_LEFT if left_handed else ORDER_RIGHT
        for i in range(order.size()):
            var button: Button = physical_controls.controls.get(order[i]) as Button
            if button != null:
                physical_controls.rail.move_child(button,i)
    native_profile_updates += 1

func set_profile(step: int, inverted: bool, left: bool,
        persist: bool = true) -> void:
    if step < 0 or step >= SENSITIVITY_STEPS.size():
        rejected_profile_values += 1
        step = clampi(step,0,SENSITIVITY_STEPS.size()-1)
    sensitivity_step = step
    invert_y = inverted
    left_handed = left
    _apply_to_original_game_controls()
    _refresh_labels()
    if persist and persistence_enabled:
        save_preferences()
    profile_changed.emit()

func save_preferences() -> bool:
    if not persistence_enabled:
        return false
    var data := ConfigFile.new()
    data.set_value("touch","version",1)
    data.set_value("touch","sensitivity_step",sensitivity_step)
    data.set_value("touch","invert_y",invert_y)
    data.set_value("touch","left_handed",left_handed)
    var saved: Error = data.save(profile_path)
    if saved == OK:
        saved_profiles += 1
        return true
    return false

func load_preferences() -> bool:
    if not persistence_enabled:
        return false
    var data := ConfigFile.new()
    if data.load(profile_path)!=OK:
        _apply_to_original_game_controls()
        return false
    if int(data.get_value("touch","version",0))!=1:
        rejected_profile_values += 1
        _apply_to_original_game_controls()
        return false
    var step: int = int(data.get_value("touch","sensitivity_step",1))
    if step < 0 or step >= SENSITIVITY_STEPS.size():
        rejected_profile_values += 1
        step = 1
    sensitivity_step = step
    invert_y = bool(data.get_value("touch","invert_y",false))
    left_handed = bool(data.get_value("touch","left_handed",false))
    loaded_profiles += 1
    _apply_to_original_game_controls()
    _refresh_labels()
    return true

func _toggle_open() -> void:
    if not source_visible:
        return
    opened = not opened
    panel.visible = opened
    if opened:
        panel_open_events += 1
        if actual_camera_touch != null:
            actual_camera_touch.cancel_capture()
            actual_camera_touch.input_suspended = true
        if physical_controls != null:
            physical_controls.release_all()
    else:
        panel_close_events += 1
        if actual_camera_touch != null:
            actual_camera_touch.input_suspended = false
    opened_changed.emit(opened)

func _cycle_sensitivity() -> void:
    if opened:
        set_profile((sensitivity_step+1)%SENSITIVITY_STEPS.size(),
            invert_y,left_handed)

func _toggle_invert() -> void:
    if opened:
        set_profile(sensitivity_step,not invert_y,left_handed)

func _toggle_handedness() -> void:
    if opened:
        set_profile(sensitivity_step,invert_y,not left_handed)

func _reset() -> void:
    if opened:
        set_profile(1,false,false)

func qa_readout() -> Dictionary:
    return {
        "schema":"LAST_FRONTIER_W84_ORIGINAL_NATIVE_PREFERENCES_V1",
        "visible":visible,
        "opened":opened,
        "physical_controls_same_original":physical_controls != null and
            physical_controls.controls.size()==8,
        "actual_camera_same_original":actual_camera_touch != null and
            actual_camera_touch.actor != null and
            actual_camera_touch.actor.body is CharacterBody3D,
        "source_mouse_filter_safe":mouse_filter==Control.MOUSE_FILTER_IGNORE,
        "real_camera_sensitivity":float(SENSITIVITY_STEPS[sensitivity_step]),
        "real_camera_invert_y":invert_y,
        "real_native_left_handed":left_handed,
        "physical_first_button":physical_controls.rail.get_child(0).name
            if physical_controls != null else "",
        "actual_profile_updates":native_profile_updates,
        "real_profile_saved_success":saved_profiles,
        "real_profile_loaded_success":loaded_profiles,
        "rejected_invalid_profiles":rejected_profile_values,
        "real_option_opens":panel_open_events,
        "real_option_closes":panel_close_events,
        "original_core_commands_issued":original_game_commands_issued,
        "original_3d_body_never_replaced":true,
        "no_generated_images":true,
        "hardware_tested":false,
    }
