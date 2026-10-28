extends Control
## Actual gameplay telemetry, not a static image of the reference speedometer.
const BRASS = Color("eac482")
const WHITE = Color("f0f1f4")
const SOFT = Color("334255",0.90)
var speed_kmh := 0.0
var fuel_percent := 100.0
var health_percent := 100.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size = Vector2(82,82)

func set_vehicle(speed_mps: float, fuel: float, health: float) -> void:
	speed_kmh = clampf(absf(speed_mps)*3.6 if is_finite(speed_mps) else 0.0,0.0,350.0)
	fuel_percent = clampf(fuel if is_finite(fuel) else 0.0,0.0,100.0)
	health_percent = clampf(health if is_finite(health) else 0.0,0.0,100.0)
	queue_redraw()

func _draw() -> void:
	var size_px: Vector2 = get_rect().size
	var middle := size_px*0.5
	var radius: float = maxf(6.0,minf(size_px.x,size_px.y)*0.42)
	draw_arc(middle,radius,PI*0.75,PI*2.25,54,SOFT,3.0,true)
	var progress: float = clampf(speed_kmh/260.0,0.0,1.0)
	draw_arc(middle,radius,PI*0.75,PI*(0.75+1.5*progress),54,BRASS,3.5,true)
	for i in range(13):
		var radians: float = PI*(0.75+1.5*float(i)/12.0)
		var direction := Vector2(cos(radians),sin(radians))
		draw_line(middle+direction*(radius-7.0),middle+direction*(radius-3.0),WHITE,1.0,true)
	var fuel_angle: float = PI*0.25
	var fuel_tip := Vector2(cos(fuel_angle),sin(fuel_angle))
	draw_arc(middle,radius*0.69,PI*0.05,PI*(0.05+0.40*fuel_percent/100.0),24,
		BRASS if fuel_percent>=15.0 else Color("fa6855"),2.0,true)
