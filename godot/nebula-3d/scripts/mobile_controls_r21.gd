extends Control
## R21: true multitouch flight controller, one independent finger per control.
## Painted lightweight UI (no TextureRects/texture assets/network requests).
## Landscape + portrait; never sends input while the store is open.
signal rocket_requested
signal hangar_requested
signal camera_requested

const TEXT: Color = Color(0.92, 0.97, 0.99)
const CYAN: Color = Color(0.32, 0.81, 0.94)
const AMBER: Color = Color(1.0, 0.70, 0.33)
const JOY_ID: String = "JOYSTICK"
const CONTROL_KEYS = ["THRUST", "BOOST", "FIRE", "ROCKET",
    "UP", "DOWN", "HANGAR", "CAMERA"]
const LABELS = {
    "THRUST": "ГАЗ", "BOOST": "ФОРСАЖ", "FIRE": "ОГОНЬ",
    "ROCKET": "РАКЕТА", "UP": "ВЫШЕ", "DOWN": "НИЖЕ",
    "HANGAR": "АНГАР", "CAMERA": "КАМЕРА"
}
var player_ship: CharacterBody3D
var enabled: bool = false
var shop_open: bool = false
var finger_roles: Dictionary = {}
var finger_positions: Dictionary = {}
var joystick: Vector2 = Vector2.ZERO
var button_centres: Dictionary = {}
var stick_center: Vector2 = Vector2.ZERO
var base_radius: float = 52.0
var viewport_pixels: Vector2 = Vector2(1280, 720)
var active_touch_count: int = 0
var ui_draws: int = 0

func _ready() -> void:
    name = "R21_ResponsiveMobileController"
    set_anchors_preset(Control.PRESET_FULL_RECT)
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    enabled = OS.has_feature("mobile") or DisplayServer.is_touchscreen_available()
    if OS.has_feature("web"):
        # The Web feature bit alone does not identify a phone. This browser
        # check also detects touch tablets whose viewport is landscape.
        enabled = bool(JavaScriptBridge.eval(
            "navigator.maxTouchPoints > 0 || window.matchMedia('(pointer: coarse)').matches"))
    visible = enabled
    get_viewport().size_changed.connect(_resize)
    _resize()
    set_process(enabled)
    set_process_input(enabled)

func force_mobile_for_tests(on: bool) -> void:
    enabled = on
    visible = on
    set_process(on)
    set_process_input(on)
    _resize()

func set_shop_open(on: bool) -> void:
    shop_open = on
    if on:
        finger_roles.clear()
        finger_positions.clear()
        joystick = Vector2.ZERO
        _update_ship_controls()
    queue_redraw()

func _resize() -> void:
    viewport_pixels = get_viewport().get_visible_rect().size
    var w: float = viewport_pixels.x
    var h: float = viewport_pixels.y
    base_radius = clampf(minf(w, h) * 0.093, 38.0, 68.0)
    var r: float = base_radius
    stick_center = Vector2(r + 27.0, h - r - 34.0)
    button_centres = {
        "THRUST": Vector2(w - r - 25.0, h - r - 34.0),
        "BOOST": Vector2(w - 3.1 * r - 33.0, h - r - 34.0),
        "FIRE": Vector2(w - r - 25.0, h - 3.0 * r - 45.0),
        "ROCKET": Vector2(w - 3.1 * r - 33.0, h - 3.0 * r - 45.0),
        "UP": Vector2(w - r - 25.0, h - 5.0 * r - 56.0),
        "DOWN": Vector2(w - 3.1 * r - 33.0, h - 5.0 * r - 56.0),
        "HANGAR": Vector2(w - r - 25.0, 188.0),
        "CAMERA": Vector2(w - 3.1 * r - 33.0, 188.0)
    }
    # Keep central rear-facing ship and objective free from touch controls.
    queue_redraw()

func _role_at(where: Vector2) -> String:
    if where.distance_to(stick_center) < base_radius * 1.45:
        return JOY_ID
    for role in CONTROL_KEYS:
        if where.distance_to(button_centres[role]) <= base_radius * 0.80:
            return role
    return ""

func _set_touch(index: int, where: Vector2, pressed: bool) -> void:
    if not enabled or shop_open:
        return
    if pressed:
        var role: String = _role_at(where)
        if role.is_empty():
            return
        finger_roles[index] = role
        finger_positions[index] = where
        if role == "ROCKET":
            rocket_requested.emit()
        elif role == "HANGAR":
            hangar_requested.emit()
        elif role == "CAMERA":
            camera_requested.emit()
    else:
        finger_roles.erase(index)
        finger_positions.erase(index)
    _refresh_inputs()

func _drag_touch(index: int, where: Vector2) -> void:
    if not finger_roles.has(index) or shop_open:
        return
    finger_positions[index] = where
    _refresh_inputs()

func _input(event: InputEvent) -> void:
    if not enabled or shop_open:
        return
    if event is InputEventScreenTouch:
        var touch: InputEventScreenTouch = event
        _set_touch(touch.index, touch.position, touch.pressed)
        if finger_roles.has(touch.index):
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        var drag: InputEventScreenDrag = event
        if finger_roles.has(drag.index):
            _drag_touch(drag.index, drag.position)
            get_viewport().set_input_as_handled()

func _pressed(role: String) -> bool:
    for value in finger_roles.values():
        if value == role:
            return true
    return false

func _refresh_inputs() -> void:
    joystick = Vector2.ZERO
    for index in finger_roles:
        if finger_roles[index] == JOY_ID:
            joystick = ((finger_positions[index] as Vector2) -
                stick_center) / base_radius
            joystick = joystick.limit_length(1.0)
            break
    active_touch_count = finger_roles.size()
    _update_ship_controls()
    queue_redraw()

func _update_ship_controls() -> void:
    if not is_instance_valid(player_ship):
        return
    if shop_open:
        player_ship.clear_touch_controls()
        return
    # Left pad: X yaw, Y pitch; pressing GAS accelerates; moving the pad
    # backwards without GAS enables reverse-thrust docking.
    var forward: float = 1.0 if _pressed("THRUST") else (
        -clampf(joystick.y, 0.0, 1.0))
    var height: float = float(_pressed("UP")) - float(_pressed("DOWN"))
    player_ship.set_touch_controls(joystick, forward, height,
        _pressed("BOOST"), _pressed("FIRE"))

func _process(_delta: float) -> void:
    # Recomputing is inexpensive; it also recovers if a finger is lifted
    # outside of the viewport and the browser sends a terminal touch event.
    if enabled and not shop_open:
        _update_ship_controls()

func _font() -> Font:
    return ThemeDB.fallback_font

func _label(text: String, center: Vector2, size: int, tint: Color) -> void:
    var typeface: Font = _font()
    var text_width: float = typeface.get_string_size(text,
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
    draw_string(typeface, center + Vector2(-text_width * 0.5, float(size) * 0.33),
        text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, tint)

func _draw() -> void:
    if not enabled or shop_open:
        return
    ui_draws += 1
    draw_circle(stick_center, base_radius * 1.23, Color(0.025, 0.05, 0.07, 0.53))
    draw_arc(stick_center, base_radius, 0.0, TAU, 72,
        CYAN.darkened(0.12), 2.2, true)
    draw_circle(stick_center + joystick * base_radius * 0.68,
        base_radius * 0.28, CYAN.lightened(0.17))
    _label("ПОЛЁТ", stick_center + Vector2(0,-base_radius-19),
        13, TEXT)
    for key in CONTROL_KEYS:
        var center: Vector2 = button_centres[key]
        var pressed: bool = _pressed(key)
        var r: float = base_radius * 0.72
        var color: Color = AMBER if key in ["BOOST","ROCKET"] else CYAN
        draw_circle(center, r, Color(0.014,0.029,0.045,0.82 if pressed else 0.61))
        draw_arc(center, r, 0.0, TAU, 48,
            color if pressed else color.darkened(0.35), 2.2, true)
        _label(LABELS[key], center, 13 if base_radius >= 48.0 else 11,
            color if pressed else TEXT)
