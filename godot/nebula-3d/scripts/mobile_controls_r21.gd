extends Control
## R21: true multitouch flight controller, one independent finger per control.
## Painted lightweight UI (no TextureRects/texture assets/network requests).
## Landscape + portrait; never sends input while the store is open.
signal rocket_requested
signal hangar_requested
signal camera_requested
signal cruise_requested

const TEXT: Color = Color(0.92, 0.97, 0.99)
const CYAN: Color = Color(0.32, 0.81, 0.94)
const AMBER: Color = Color(1.0, 0.70, 0.33)
const JOY_ID: String = "JOYSTICK"
const CONTROL_KEYS = ["THRUST", "BOOST", "FIRE", "ROCKET",
    "UP", "DOWN", "HANGAR", "CAMERA", "CRUISE"]
const LABELS = {
    "THRUST": "ГАЗ", "BOOST": "ФОРСАЖ", "FIRE": "ОГОНЬ",
    "ROCKET": "РАКЕТА", "UP": "ВЫШЕ", "DOWN": "НИЖЕ",
    "HANGAR": "АНГАР", "CAMERA": "КАМЕРА", "CRUISE": "ПОЛЁТ"
}
var player_ship: CharacterBody3D
var ui_font: Font
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
var r23_landscape_layout: bool = false
## R31: diagnostics count actual Godot touch delivery, not browser DOM alone.
var r31_raw_touch_events: int = 0
var r31_last_touch_position: Vector2 = Vector2.ZERO
var r31_last_touch_role: String = ""
# Browser-owned touch source; native ScreenTouch remains a safe fallback.
var r34_dom_bridge_active: bool = false
var r34_dom_sequence: int = -1
var r34_dom_seen: Dictionary = {}
var r34_dom_event_count: int = 0
var r34_ignore_until_all_released: bool = false
## R35: true CSS env() safe-area insets (left, top, right, bottom).
## These are browser CSS pixels, not hardware devicePixelRatio pixels.
var r35_safe_insets: Vector4 = Vector4.ZERO
var r35_compact_portrait: bool = false
## R36: monotonic browser DOM dispatch -> Godot poll age, not input-to-photon.
var r36_input_poll_latency_ms: float = -1.0
var r36_input_poll_latency_total_ms: float = 0.0
var r36_input_poll_latency_peak_ms: float = 0.0
var r36_input_poll_samples: int = 0
var r36_input_poll_invalid: int = 0

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
    if OS.has_feature("web") and enabled:
        r34_dom_bridge_active = bool(JavaScriptBridge.eval(
            "Boolean(window.__nebulaDomTouchState && Array.isArray(window.__nebulaDomTouchState.points))"))
    get_viewport().size_changed.connect(_resize)
    _resize()
    set_process(enabled)
    set_process_input(enabled)

func _clear_active_touches() -> void:
    # A lost finger must never leave the ship firing or accelerating.
    finger_roles.clear()
    finger_positions.clear()
    joystick = Vector2.ZERO
    active_touch_count = 0
    if is_instance_valid(player_ship):
        player_ship.clear_touch_controls()
    queue_redraw()

func _notification(what: int) -> void:
    # Mobile interruptions, browser tab changes and phone-call overlays may
    # prevent the matching touch-up event from reaching Godot.
    if what == NOTIFICATION_APPLICATION_FOCUS_OUT or (
            what == NOTIFICATION_WM_WINDOW_FOCUS_OUT):
        r34_ignore_until_all_released = true
        _clear_active_touches()

func force_mobile_for_tests(on: bool) -> void:
    if not on:
        _clear_active_touches()
    enabled = on
    visible = on
    set_process(on)
    set_process_input(on)
    _resize()

func set_shop_open(on: bool) -> void:
    shop_open = on
    if on:
        r34_ignore_until_all_released = true
        _clear_active_touches()
    queue_redraw()

func set_safe_insets(insets: Vector4) -> bool:
    var safe := Vector4(
        clampf(insets.x, 0.0, 96.0), clampf(insets.y, 0.0, 96.0),
        clampf(insets.z, 0.0, 96.0), clampf(insets.w, 0.0, 96.0))
    if safe.distance_to(r35_safe_insets) < 0.5:
        return false
    r35_safe_insets = safe
    # A dynamic island or system bar can invalidate the old button geometry.
    if not finger_roles.is_empty():
        r34_ignore_until_all_released = true
        _clear_active_touches()
    _layout_for_size(viewport_pixels)
    return true


func _r35_refresh_safe_insets() -> bool:
    if not OS.has_feature("web") or not enabled:
        return false
    var raw: Variant = JavaScriptBridge.eval(
        "JSON.stringify(window.__nebulaSafeArea || null)")
    if typeof(raw) != TYPE_STRING:
        return false
    var values: Variant = JSON.parse_string(str(raw))
    if typeof(values) != TYPE_DICTIONARY:
        return false
    return set_safe_insets(Vector4(
        float(values.get("left", 0.0)), float(values.get("top", 0.0)),
        float(values.get("right", 0.0)), float(values.get("bottom", 0.0))))


func _resize() -> void:
    _r35_refresh_safe_insets()
    # WebGL can keep a 1280x720 internal drawing surface while CSS displays
    # a portrait phone. Place controls in the browser's physical CSS viewport.
    if OS.has_feature("web") and enabled:
        var css_w: int = int(JavaScriptBridge.eval("Math.round(window.innerWidth)"))
        var css_h: int = int(JavaScriptBridge.eval("Math.round(window.innerHeight)"))
        if css_w >= 300 and css_h >= 280:
            _layout_for_size(Vector2(css_w, css_h))
            return
    _layout_for_size(get_viewport().get_visible_rect().size)

func _layout_for_size(pixels: Vector2) -> void:
    # Keep minor browser-toolbar resizes smooth, but cancel an ongoing hold
    # when an orientation change moves the controls under another finger.
    var changed_orientation: bool = (pixels.x >= pixels.y) != (
        viewport_pixels.x >= viewport_pixels.y)
    if not finger_roles.is_empty() and (
            changed_orientation or pixels.distance_to(viewport_pixels) > 24.0):
        r34_ignore_until_all_released = true
        _clear_active_touches()
    viewport_pixels = pixels
    var w: float = pixels.x
    var h: float = pixels.y
    var safe_left: float = r35_safe_insets.x
    var safe_top: float = r35_safe_insets.y
    var safe_right: float = r35_safe_insets.z
    var safe_bottom: float = r35_safe_insets.w
    var usable_w: float = maxf(200.0, w - safe_left - safe_right)
    var usable_h: float = maxf(180.0, h - safe_top - safe_bottom)
    r23_landscape_layout = h < 530.0 and w > h and usable_w >= 335.0
    # A short portrait screen needs a different 3x3 cluster. The old
    # 2-column vertical list overlapped CRUISE and UP on 320x480 phones.
    r35_compact_portrait = not r23_landscape_layout and (
        usable_h < 680.0 or usable_w < 330.0)
    if r23_landscape_layout:
        base_radius = clampf(minf(usable_w, usable_h) * 0.079, 30.0, 65.0)
        # Leave room for three rows above the bottom gesture/system bar.
        base_radius = minf(base_radius, maxf(22.0,
            (usable_h - 36.0) / 6.2))
    elif r35_compact_portrait:
        base_radius = clampf(minf(usable_w, usable_h) * 0.083, 25.0, 37.0)
        base_radius = minf(base_radius, maxf(23.0,
            (usable_w - 30.0) / 8.2))
    else:
        base_radius = clampf(minf(usable_w, usable_h) * 0.093, 38.0, 65.0)
    var r: float = base_radius
    var usable_right: float = w - safe_right
    var usable_bottom: float = h - safe_bottom
    stick_center = Vector2(safe_left + r + (
        22.0 if r35_compact_portrait else 30.0),
        usable_bottom - r - (28.0 if r35_compact_portrait else 30.0))
    if r23_landscape_layout:
        var x0: float = usable_right - r - 23.0
        var row_a: float = usable_bottom - r - 27.0
        var row_b: float = usable_bottom - 3.05 * r - 27.0
        var row_c: float = usable_bottom - 5.1 * r - 27.0
        var step: float = r * 2.12
        button_centres = {
            "THRUST": Vector2(x0,row_a),
            "BOOST": Vector2(x0-step,row_a),
            "FIRE": Vector2(x0,row_b),
            "ROCKET": Vector2(x0-step,row_b),
            "UP": Vector2(x0-step*2.0,row_a),
            "DOWN": Vector2(x0-step*2.0,row_b),
            "HANGAR": Vector2(x0-step*3.0,row_a),
            "CAMERA": Vector2(x0-step*3.0,row_b),
            "CRUISE": Vector2(x0-step,row_c)
        }
    elif r35_compact_portrait:
        var x0: float = usable_right - r - 18.0
        var row_a: float = usable_bottom - r - 28.0
        var step: float = r * 2.08
        button_centres = {
            "THRUST": Vector2(x0,row_a),
            "BOOST": Vector2(x0-step,row_a),
            "FIRE": Vector2(x0-step*2.0,row_a),
            "ROCKET": Vector2(x0,row_a-step),
            "UP": Vector2(x0-step,row_a-step),
            "DOWN": Vector2(x0-step*2.0,row_a-step),
            "HANGAR": Vector2(x0,row_a-step*2.0),
            "CAMERA": Vector2(x0-step,row_a-step*2.0),
            "CRUISE": Vector2(x0-step*2.0,row_a-step*2.0)
        }
    else:
        button_centres = {
            "THRUST": Vector2(usable_right - r - 25.0,
                usable_bottom - r - 34.0),
            "BOOST": Vector2(usable_right - 3.1 * r - 33.0,
                usable_bottom - r - 34.0),
            "FIRE": Vector2(usable_right - r - 25.0,
                usable_bottom - 3.0 * r - 45.0),
            "ROCKET": Vector2(usable_right - 3.1 * r - 33.0,
                usable_bottom - 3.0 * r - 45.0),
            "UP": Vector2(usable_right - r - 25.0,
                usable_bottom - 5.0 * r - 56.0),
            "DOWN": Vector2(usable_right - 3.1 * r - 33.0,
                usable_bottom - 5.0 * r - 56.0),
            "HANGAR": Vector2(usable_right - r - 25.0, safe_top + 188.0),
            "CAMERA": Vector2(usable_right - 3.1 * r - 33.0,
                safe_top + 188.0),
            "CRUISE": Vector2(usable_right - r - 25.0, safe_top + 254.0)
        }
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
        elif role == "CRUISE":
            cruise_requested.emit()
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
        r31_raw_touch_events += 1
        r31_last_touch_position = touch.position
        if touch.pressed:
            r31_last_touch_role = _role_at(touch.position)
        if r34_dom_bridge_active:
            # The DOM bridge owns Web touches to avoid duplicate native
            # ScreenTouch + DOM events launching a single button twice.
            get_viewport().set_input_as_handled()
            return
        var was_control: bool = finger_roles.has(touch.index)
        _set_touch(touch.index, touch.position, touch.pressed)
        if was_control or finger_roles.has(touch.index):
            get_viewport().set_input_as_handled()
    elif event is InputEventScreenDrag:
        if r34_dom_bridge_active:
            get_viewport().set_input_as_handled()
            return
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

func _r34_gate_stale_contacts(points: Array) -> bool:
    if not shop_open and not r34_ignore_until_all_released:
        return false
    r34_dom_seen.clear()
    _clear_active_touches()
    if points.is_empty() and not shop_open:
        # Closing an already finger-free hangar should accept the next tap.
        # Previously an unchanged DOM sequence suppressed this release,
        # forcing users to tap and release a second time.
        r34_ignore_until_all_released = false
    return true


func _r34_poll_browser_contacts() -> void:
    if not r34_dom_bridge_active:
        return
    # True browser-owned finger contacts from the same canvas used by Godot.
    # Only change the input state: all acceleration/collision remains in Godot.
    var raw: Variant = JavaScriptBridge.eval(
        "JSON.stringify(window.__nebulaDomTouchState || null)")
    if typeof(raw) != TYPE_STRING:
        return
    var parsed: Variant = JSON.parse_string(str(raw))
    if typeof(parsed) != TYPE_DICTIONARY:
        return
    var current: Dictionary = parsed
    var sequence: int = int(current.get("seq", -1))
    if sequence < 0:
        return
    var entries: Variant = current.get("points", [])
    if typeof(entries) != TYPE_ARRAY:
        return
    var points: Array = entries
    # Re-evaluate the hangar gate even if the browser sequence has not
    # changed since the panel closed. Otherwise the first new tap is lost.
    if sequence == r34_dom_sequence and not (
            r34_ignore_until_all_released and not shop_open and points.is_empty()):
        return
    r34_dom_sequence = sequence
    r34_dom_event_count = int(current.get("downs", 0)) + (
        int(current.get("ups", 0))) + int(current.get("cancels", 0))
    # R36: browser performance.now() uses a monotonic per-page time origin.
    # Both clock readings come from the same browser page; never compare
    # browser milliseconds to Godot system UTC timestamps.
    if sequence > 0:
        var browser_ms: Variant = JavaScriptBridge.eval(
            "performance.now()")
        var event_ms: float = float(current.get("last_event_ms", -1.0))
        if (typeof(browser_ms) == TYPE_FLOAT or typeof(browser_ms) == TYPE_INT)                 and event_ms >= 0.0:
            var input_age_ms: float = float(browser_ms) - event_ms
            if input_age_ms >= 0.0 and input_age_ms <= 30000.0:
                r36_input_poll_latency_ms = input_age_ms
                r36_input_poll_latency_total_ms += input_age_ms
                r36_input_poll_latency_peak_ms = maxf(
                    r36_input_poll_latency_peak_ms, input_age_ms)
                r36_input_poll_samples += 1
            else:
                r36_input_poll_invalid += 1
        else:
            r36_input_poll_invalid += 1
    if _r34_gate_stale_contacts(points):
        return
    var next_seen: Dictionary = {}
    for entry in points:
        if typeof(entry) != TYPE_ARRAY or entry.size() < 3:
            continue
        var id: int = int(entry[0])
        if id < 0 or id > 4096:
            continue
        var finger_id: int = 10000 + id
        # Browser JS stored canvas-local CSS coordinates. Since R31 sets
        # viewport_pixels to the same CSS viewport, no devicePixelRatio
        # multiplication is permitted here.
        var position := Vector2(float(entry[1]), float(entry[2]))
        next_seen[finger_id] = true
        if not r34_dom_seen.has(finger_id):
            r31_last_touch_position = position
            r31_last_touch_role = _role_at(position)
            _set_touch(finger_id, position, true)
        elif finger_positions.has(finger_id):
            _drag_touch(finger_id, position)
    for prior in r34_dom_seen:
        if not next_seen.has(prior):
            _set_touch(int(prior), Vector2.ZERO, false)
    r34_dom_seen = next_seen


func _process(_delta: float) -> void:
    if enabled:
        _r34_poll_browser_contacts()
    # Keep applying actual throttle while an acknowledged finger is held.
    if enabled and not shop_open:
        _update_ship_controls()

func _font() -> Font:
    # Match the mission HUD's designed UI font rather than a platform default.
    return ui_font if ui_font != null else ThemeDB.fallback_font

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
