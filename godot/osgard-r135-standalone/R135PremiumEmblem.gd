extends Control
## Original procedural OSGARD emblem: drawn by Godot, no third-party font/logo/image.
## Clean vector silhouette at any desktop/phone DPR.
func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(52, 52)

func _draw() -> void:
    var center := size * 0.5
    var radius: float = minf(size.x, size.y) * 0.40
    var vertices := PackedVector2Array()
    for i in range(6):
        var angle: float = -PI / 2.0 + TAU * float(i) / 6.0
        vertices.append(center + Vector2(cos(angle), sin(angle)) * radius)
    draw_colored_polygon(vertices, Color(0.075, 0.14, 0.18, 0.96))
    for i in range(6):
        draw_line(vertices[i], vertices[(i + 1) % 6], Color(0.90, 0.57, 0.31), 2.6, true)
    # Two precision-cut elements form an abstract O and a suspended spindle.
    var left := PackedVector2Array([
        center + Vector2(-11, -10), center + Vector2(-3, -15),
        center + Vector2(-3, 2), center + Vector2(0, 7),
        center + Vector2(-8, 12), center + Vector2(-11, 7)
    ])
    var right := PackedVector2Array([
        center + Vector2(3, -15), center + Vector2(11, -10),
        center + Vector2(11, 7), center + Vector2(8, 12),
        center + Vector2(0, 7), center + Vector2(3, 2)
    ])
    draw_colored_polygon(left, Color(0.83, 0.90, 0.92))
    draw_colored_polygon(right, Color(0.94, 0.55, 0.24))
    draw_line(center + Vector2(-3, 3), center + Vector2(3, 3), Color(0.29, 0.84, 0.94), 2.5, true)
