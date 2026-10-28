extends Control
class_name A7CinematicHud
## W66 — Native 2D cinema reticle and typography over genuine 3D Godot viewport.
## Read-only representation of A7CascadeCore.snapshot(); no input or simulation edits.

const GOLD := Color("dbc29a")
const ICE := Color("8adbd4")
const WHITE := Color("e6eeef")
const MUTED := Color("94a9b0")
const RED := Color("f18a7a")
const SHADE := Color(0.02, 0.035, 0.055, 0.74)

var caption: Label
var coordinate: Label
var incident: Label
var integrity: Label
var scene_state: Dictionary = {}
var is_english: bool = false

func _ready() -> void:
    name = "W66CinematicDiegeticHUD"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    focus_mode = Control.FOCUS_NONE
    set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    caption = _hud_label(15, GOLD)
    coordinate = _hud_label(10, MUTED)
    incident = _hud_label(13, WHITE)
    integrity = _hud_label(12, ICE)
    resized.connect(_relayout)
    _relayout()

func _hud_label(font_size: int, color: Color) -> Label:
    var label := Label.new()
    label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    label.add_theme_font_size_override("font_size", font_size)
    label.add_theme_color_override("font_color", color)
    label.add_theme_color_override("font_shadow_color", Color("020509"))
    label.add_theme_constant_override("shadow_offset_x", 1)
    label.add_theme_constant_override("shadow_offset_y", 2)
    label.clip_text = true
    add_child(label)
    return label

func _relayout() -> void:
    if caption == null:
        return
    var compact: bool = size.x < 540.0
    var xmargin: float = 16.0 if compact else 34.0
    caption.position = Vector2(xmargin, 14.0 if compact else 26.0)
    caption.size = Vector2(maxf(100.0, size.x * 0.70), 24.0)
    caption.add_theme_font_size_override("font_size", 12 if compact else 17)
    coordinate.position = Vector2(xmargin, 39.0 if compact else 57.0)
    coordinate.size = Vector2(maxf(90.0, size.x * 0.66), 20.0)
    coordinate.add_theme_font_size_override("font_size", 9 if compact else 11)
    incident.position = Vector2(xmargin, maxf(52.0, size.y - (35.0 if compact else 54.0)))
    incident.size = Vector2(maxf(80.0, size.x * 0.66), 22.0)
    incident.add_theme_font_size_override("font_size", 10 if compact else 14)
    integrity.position = Vector2(size.x - (115.0 if compact else 205.0),
        maxf(52.0, size.y - (35.0 if compact else 54.0)))
    integrity.size = Vector2(105.0 if compact else 185.0, 22.0)
    integrity.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    integrity.add_theme_font_size_override("font_size", 10 if compact else 13)
    queue_redraw()

func present(snapshot: Dictionary, locale: String) -> void:
    scene_state = snapshot.duplicate(true)
    is_english = locale != "ru"
    var cycle: int = mini(6, int(snapshot.get("shift", 0)) + 1)
    var status: String = str(snapshot.get("status", "playing"))
    caption.text = "A7  /  " + ("CONTAINMENT ARRAY" if is_english else "КОНТУР СДЕРЖИВАНИЯ")
    coordinate.text = ("OPERATOR CAM    •    LIVE SYSTEMS" if is_english
        else "КАМЕРА ОПЕРАТОРА    •    ДАННЫЕ СИСТЕМЫ")
    var event: String = "SHIFT %02d / 06" % cycle if is_english else "ЦИКЛ %02d / 06" % cycle
    if status == "won":
        event = "CONTAINED  /  STABLE" if is_english else "СИСТЕМА СТАБИЛЬНА"
    elif status == "failed":
        event = "SYSTEM LOST  /  CRITICAL" if is_english else "СИСТЕМА ПОТЕРЯНА"
    elif status == "unstable":
        event = "UNSTABLE  /  RETRY" if is_english else "СИСТЕМА НЕСТАБИЛЬНА"
    incident.text = event
    var stats: Dictionary = snapshot.get("metrics", {})
    var reserve: int = int(stats.get("integrity", 100))
    integrity.text = ("INTEGRITY  %d%%" if is_english else "ЦЕЛОСТНОСТЬ  %d%%") % reserve
    integrity.add_theme_color_override("font_color", RED if reserve < 40 else ICE)
    incident.add_theme_color_override("font_color",
        RED if status in ["failed", "unstable"] else WHITE)
    queue_redraw()

func _draw() -> void:
    if size.x < 10 or size.y < 10:
        return
    var width: float = size.x
    var height: float = size.y
    var compact: bool = width < 540.0
    var m: float = 11.0 if compact else 20.0
    var line: Color = GOLD
    line.a = 0.68
    var faint: Color = ICE
    faint.a = 0.24

    # Restrained Cinema / engineering HUD visual framing. All native CanvasItem.
    draw_rect(Rect2(0, 0, width, 2), GOLD, true)
    draw_rect(Rect2(0, height - 2, width, 2), GOLD.darkened(0.25), true)
    var corner: float = 14 if compact else 26
    for left in [true, false]:
        for top in [true, false]:
            var x: float = m if left else width - m
            var y: float = m if top else height - m
            var dx: float = corner if left else -corner
            var dy: float = corner if top else -corner
            draw_line(Vector2(x, y), Vector2(x + dx, y), line, 1.5, true)
            draw_line(Vector2(x, y), Vector2(x, y + dy), line, 1.5, true)

    var cx: float = width * 0.5
    var cy: float = height * 0.52
    var radius: float = 12 if compact else 27
    draw_line(Vector2(cx - radius - 14, cy), Vector2(cx - radius, cy), faint, 1, true)
    draw_line(Vector2(cx + radius, cy), Vector2(cx + radius + 14, cy), faint, 1, true)
    draw_line(Vector2(cx, cy - radius - 14), Vector2(cx, cy - radius), faint, 1, true)
    draw_line(Vector2(cx, cy + radius), Vector2(cx, cy + radius + 14), faint, 1, true)
    draw_arc(Vector2(cx, cy), radius, PI * 0.14, PI * 0.86, 16, faint, 1.3, true)
    draw_arc(Vector2(cx, cy), radius, PI * 1.14, PI * 1.86, 16, faint, 1.3, true)

    # Deliberate HUD tick scale: information hierarchy rather than visual noise.
    var tick_y: float = height - (27.0 if compact else 45.0)
    var lower_width: float = width - m * 2.0
    for i in range(16):
        var x: float = m + lower_width * float(i) / 15.0
        var tall: float = 8.0 if i % 5 == 0 else 4.0
        draw_line(Vector2(x, tick_y), Vector2(x, tick_y - tall), faint, 1.0, true)

    if scene_state.is_empty():
        return
    var stats: Dictionary = scene_state.get("metrics", {})
    var integrity_percent: float = clampf(float(stats.get("integrity", 100)) / 100.0, 0, 1)
    var warning: Color = RED if integrity_percent < 0.4 else ICE
    var bar_size: float = 84.0 if compact else 158.0
    var bar_x: float = width - m - bar_size
    var bar_y: float = height - (16.0 if compact else 27.0)
    draw_rect(Rect2(bar_x, bar_y, bar_size, 2), faint, true)
    draw_rect(Rect2(bar_x, bar_y, bar_size * integrity_percent, 2), warning, true)

func qa_readout() -> Dictionary:
    return {
        "schema": "LAST_FRONTIER_W66_NATIVE_HUD_V1",
        "read_only": true,
        "interactive": false,
        "has_native_labels": caption != null and incident != null and integrity != null,
        "screen_width": roundi(size.x),
        "text": caption.text if caption != null else "",
        "status": incident.text if incident != null else "",
        "gameplay_model_modified": false,
    }
