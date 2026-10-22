extends Control
## In-game compass/radar drawn without external textures. All inputs are world-space.
var player_position: Vector3 = Vector3.ZERO
var player_forward: Vector3 = Vector3.FORWARD
var objective: Vector3 = Vector3.ZERO
var has_objective: bool = true
var targets: Array[Vector3] = []
var visual_radius: float = 88.0
var range_meters: float = 460.0

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    custom_minimum_size = Vector2(220, 220)

func _draw() -> void:
    var origin := Vector2(108, 108)
    draw_circle(origin, visual_radius + 8.0, Color(0.018, 0.05, 0.09, 0.84))
    draw_arc(origin, visual_radius, 0.0, TAU, 90, Color(0.35, 0.84, 1.0, 0.9), 2.5, true)
    for factor in [0.33, 0.66]:
        draw_arc(origin, visual_radius * factor, 0.0, TAU, 90, Color(0.24, 0.66, 0.85, 0.35), 1.0, true)
    draw_line(origin + Vector2(-visual_radius, 0), origin + Vector2(visual_radius, 0), Color(0.26,0.65,0.86,0.32),1.0)
    draw_line(origin + Vector2(0,-visual_radius), origin + Vector2(0,visual_radius), Color(0.26,0.65,0.86,0.32),1.0)
    for point in targets:
        var pos := _world_to_radar(point)
        if pos.length() < visual_radius:
            draw_circle(origin + pos, 3.0, Color(1.0,0.39,0.45,0.9))
    if has_objective:
        var target_pos := _world_to_radar(objective).limit_length(visual_radius-5.0)
        var p := origin + target_pos
        draw_colored_polygon(PackedVector2Array([p + Vector2(0,-8),p + Vector2(7,6),p + Vector2(-7,6)]),Color(1.0,0.79,0.35))
    draw_colored_polygon(PackedVector2Array([origin + Vector2(0,-11),origin + Vector2(8,9),origin,origin + Vector2(-8,9)]),Color(0.42,0.95,1.0))

func _world_to_radar(world: Vector3) -> Vector2:
    var displacement := world-player_position
    var fwd := Vector2(player_forward.x, player_forward.z).normalized()
    if fwd.length_squared() < 0.5:
        fwd=Vector2(0,-1)
    var right := Vector2(-fwd.y,fwd.x)
    var v := Vector2(displacement.x,displacement.z)
    return Vector2(v.dot(right),-v.dot(fwd))*(visual_radius/range_meters)
