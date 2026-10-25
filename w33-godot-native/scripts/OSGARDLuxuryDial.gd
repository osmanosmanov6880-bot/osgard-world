extends Control
class_name OSGARDLuxuryDial
## OBSIDIAN W36: physical-look interactive calibrator for a *simulation*.
## 270-degree machined dial; mouse, touch and keyboard all use one clamped
## channel request. The real safety interlock lives only in OSGARDCore.

signal value_requested(value: int)

const GRAPHITE := Color("111920")
const EDGE := Color("475158")
const TITANIUM := Color("303c45")
const BRASS := Color("b9a17d")
const SIGNAL := Color("85d3bd")
const DISABLED := Color("516067")

var channel: String = "A"
var dial_value: int = 0
var active: bool = false
var _dragging: bool = false

func _ready() -> void:
    name = "PhysicalCalibrationDial" + channel
    custom_minimum_size = Vector2(132, 142)
    focus_mode = Control.FOCUS_ALL
    mouse_filter = Control.MOUSE_FILTER_STOP
    tooltip_text = "Virtual channel " + channel + " / 0-100"
    queue_redraw()

func set_active(enabled: bool) -> void:
    if active == enabled:
        return
    active = enabled
    if not enabled:
        _dragging = false
    queue_redraw()

func set_value_silent(next_value: int) -> void:
    var sanitized: int = clampi(next_value, 0, 100)
    if sanitized == dial_value:
        return
    dial_value = sanitized
    queue_redraw()

func request_value(next_value: int) -> void:
    if not active:
        return
    var sanitized: int = clampi(next_value, 0, 100)
    if sanitized == dial_value:
        return
    dial_value = sanitized
    queue_redraw()
    value_requested.emit(sanitized)

func _knob_center() -> Vector2:
    return Vector2(size.x * 0.5, size.y * 0.50)

func _position_to_value(point: Vector2) -> int:
    var centre: Vector2 = _knob_center()
    var angle_degrees: float = rad_to_deg(atan2(point.y - centre.y, point.x - centre.x))
    var arc_degrees: float = fposmod(angle_degrees - 135.0 + 360.0, 360.0)
    return clampi(roundi(clampf(arc_degrees, 0.0, 270.0) * (100.0 / 270.0)), 0, 100)

func _gui_input(event: InputEvent) -> void:
    if not active:
        return
    var pointer: InputEventMouseButton = event as InputEventMouseButton
    if pointer != null and pointer.button_index == MOUSE_BUTTON_LEFT:
        _dragging = pointer.pressed
        if pointer.pressed:
            grab_focus()
            request_value(_position_to_value(pointer.position))
        accept_event()
        return
    var motion: InputEventMouseMotion = event as InputEventMouseMotion
    if motion != null and _dragging:
        request_value(_position_to_value(motion.position))
        accept_event()
        return
    var touch: InputEventScreenTouch = event as InputEventScreenTouch
    if touch != null:
        _dragging = touch.pressed
        if touch.pressed:
            grab_focus()
            request_value(_position_to_value(touch.position))
        accept_event()
        return
    var finger: InputEventScreenDrag = event as InputEventScreenDrag
    if finger != null and _dragging:
        request_value(_position_to_value(finger.position))
        accept_event()
        return
    var key: InputEventKey = event as InputEventKey
    if key == null or not key.pressed or key.echo:
        return
    if key.keycode == KEY_LEFT or key.keycode == KEY_DOWN:
        request_value(dial_value - 1)
    elif key.keycode == KEY_RIGHT or key.keycode == KEY_UP:
        request_value(dial_value + 1)
    elif key.keycode == KEY_HOME:
        request_value(0)
    elif key.keycode == KEY_END:
        request_value(100)
    else:
        return
    accept_event()

func _draw() -> void:
    var centre: Vector2 = _knob_center()
    var radius: float = minf(size.x, size.y) * 0.33
    var start: float = deg_to_rad(135.0)
    var span: float = deg_to_rad(270.0)
    var tone: Color = SIGNAL if active else DISABLED
    draw_circle(centre, radius + 12.0, Color("070c10"))
    draw_circle(centre, radius + 7.0, EDGE)
    draw_circle(centre, radius + 4.0, GRAPHITE)
    draw_arc(centre, radius + 1.0, start, start + span, 72, TITANIUM, 6.0, true)
    draw_arc(centre, radius + 1.0, start, start + span * float(dial_value) / 100.0, 72, tone, 4.0, true)
    for i in range(11):
        var theta: float = start + span * float(i) / 10.0
        var tangent: Vector2 = Vector2(cos(theta), sin(theta))
        draw_line(centre + tangent * (radius + 6.0), centre + tangent * (radius + (12.0 if i % 5 == 0 else 10.0)), BRASS if i % 5 == 0 else EDGE, 1.5, true)
    draw_circle(centre, radius - 7.0, Color("121a21"))
    draw_circle(centre, radius - 12.0, Color("242d34"))
    draw_circle(centre, radius - 18.0, Color("0d141a"))
    var indicator_angle: float = start + span * float(dial_value) / 100.0
    var needle: Vector2 = Vector2(cos(indicator_angle), sin(indicator_angle))
    draw_line(centre + needle * 8.0, centre + needle * (radius - 15.0), tone, 5.0, true)
    draw_circle(centre, 7.0, BRASS)
    draw_circle(centre, 3.5, Color("0b1015"))

func visual_contract() -> Dictionary:
    return {
        "art_direction": "OSGARD_W36_MACHINED_DIAL",
        "interactive": true,
        "simulation_only": true,
        "channel": channel,
        "current_value": dial_value,
        "enabled": active,
        "mouse_touch_keyboard": true,
        "independent_safety_bypass": false
    }
