extends Control
## R21 approved Aurora reference: dark glass instruments, restrained cyan/amber
## accents, speed/ship condition, mission bearing and actual kinetic telemetry.
## Does not intercept gameplay input or allocate new meshes/fonts per frame.
var craft: CharacterBody3D
var objective: Vector3 = Vector3.ZERO
var show_objective: bool = false
var cached_font: Font
var last_draw_interval: float = 0.0
var ui_frames: int = 0
var compact: bool = false

const TEXT = Color(0.89, 0.95, 0.96)
const MUTED = Color(0.55, 0.68, 0.73)
const CYAN = Color(0.23, 0.78, 0.94)
const GOLD = Color(0.98, 0.67, 0.28)
const BACK = Color(0.014, 0.028, 0.043, 0.84)
const BORDER = Color(0.28, 0.53, 0.61, 0.66)

func _ready() -> void:
    name = "R21_PremiumFlightDashboard"
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    set_anchors_preset(Control.PRESET_FULL_RECT)
    var system_font := SystemFont.new()
    system_font.font_names = PackedStringArray([
        "Inter", "Manrope", "Segoe UI", "Noto Sans", "Roboto", "Arial"])
    cached_font = system_font
    get_viewport().size_changed.connect(_fit_viewport)
    _fit_viewport()

func _fit_viewport() -> void:
    var rect: Rect2 = get_viewport().get_visible_rect()
    compact = rect.size.x < 900.0 or rect.size.y < 570.0
    queue_redraw()

func _process(delta: float) -> void:
    last_draw_interval += delta
    if last_draw_interval > 0.105:
        last_draw_interval = 0.0
        queue_redraw()

func _text(label: String, point: Vector2, size: int,
        tint: Color = TEXT, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
    if cached_font == null:
        return
    var visual_width: float = cached_font.get_string_size(label,
        HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
    var p: Vector2 = point
    if align == HORIZONTAL_ALIGNMENT_RIGHT:
        p.x -= visual_width
    elif align == HORIZONTAL_ALIGNMENT_CENTER:
        p.x -= visual_width * 0.5
    draw_string(cached_font, p, label, HORIZONTAL_ALIGNMENT_LEFT,
        -1.0, size, tint)

func _panel(rect: Rect2) -> void:
    draw_rect(rect, BACK, true)
    draw_rect(rect, BORDER, false, 1.0)

func _gauge(base: Vector2, length: float, ratio: float, color: Color) -> void:
    draw_rect(Rect2(base, Vector2(length, 5.0)), Color(0.14,0.22,0.27), true)
    draw_rect(Rect2(base, Vector2(length * clampf(ratio,0.0,1.0), 5.0)), color, true)

func _draw() -> void:
    if not is_instance_valid(craft):
        return
    ui_frames += 1
    var size: Vector2 = get_viewport().get_visible_rect().size
    var w: float = size.x
    var h: float = size.y
    var speed: int = roundi(craft.velocity.length() * 3.6)
    var shield_pct: int = roundi(craft.shield)
    var hull_pct: int = roundi(craft.hull)
    var boost_pct: int = roundi(craft.boost)
    if compact:
        # Short top-centre flight instrument stays clear of thumb controls.
        var top := Rect2(Vector2(w * 0.34, 10), Vector2(w * 0.32, 33))
        _panel(top)
        _text("%03d км/ч" % speed, top.position+Vector2(9,24), 16,CYAN)
        _text("АССИСТ", top.position+Vector2(top.size.x-10,22),
            11,MUTED,HORIZONTAL_ALIGNMENT_RIGHT)
        return
    var right := Rect2(Vector2(w - 320.0,h - 174.0),
        Vector2(295.0,142.0))
    _panel(right)
    _text("NX-08  /  FLIGHT SYSTEM", right.position + Vector2(15,21), 12,MUTED)
    _text("%03d" % speed, right.position+Vector2(16,63), 40,TEXT)
    _text("км/ч", right.position+Vector2(98,63), 14,MUTED)
    _text("АССИСТ  •  %s" % ("ПОЛЁТ" if craft.was_flying else "ОЖИДАНИЕ"),
        right.position+Vector2(157,61), 12,CYAN)
    _text("КОРПУС  %d%%" % hull_pct, right.position+Vector2(16,85), 12,MUTED)
    _gauge(right.position+Vector2(135,78),145.0,float(hull_pct)/100.0,CYAN)
    _text("ЩИТ  %d%%" % shield_pct, right.position+Vector2(16,108), 12,MUTED)
    _gauge(right.position+Vector2(135,101),145.0,float(shield_pct)/100.0,CYAN)
    _text("ФОРСАЖ  %d%%" % boost_pct,right.position+Vector2(16,131),12,GOLD)
    _gauge(right.position+Vector2(135,124),145.0,float(boost_pct)/100.0,GOLD)
    # Approved concept has a restrained horizontal compass just below top edge.
    var center := Vector2(w * 0.5, 38.0)
    draw_line(center + Vector2(-145.0,0), center + Vector2(145.0,0),
        Color(0.35,0.61,0.69,0.42), 1.2)
    for i in 13:
        var x: float = center.x + float(i-6) * 23.0
        draw_line(Vector2(x,center.y-5.0),Vector2(x,center.y+5.0),
            Color(0.57,0.77,0.81,0.36),1.0)
    _text("N",center+Vector2(-9,-9),11,MUTED)
    var fwd: Vector3 = -craft.global_basis.z
    var angle: float = atan2(fwd.x,-fwd.z)
    _text("%03d°" % posmod(roundi(rad_to_deg(angle)),360),
        center+Vector2(-14,27),12,TEXT)
    if show_objective:
        var travel: Vector3 = (objective - craft.global_position).normalized()
        var error_angle: float = atan2(travel.dot(craft.global_basis.x),
            travel.dot(fwd))
        var offset: float = clampf(error_angle / 1.2, -1.0, 1.0) * 136.0
        var point := center + Vector2(offset,0)
        draw_colored_polygon(PackedVector2Array([
            point+Vector2(0,-8),point+Vector2(-6,-15),
            point+Vector2(6,-15)]),GOLD)
