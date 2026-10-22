extends Control
const MOBILITY = preload("res://scripts/city_mobility.gd")
const DISCOVERY = preload("res://scripts/city_discovery.gd")
## Immediate-mode map: district colors, road grid, player and mission waypoint.

var player_world := Vector3(-112,0,-104)
var goal_world := Vector3(130,0,-130)
var vehicle_world := Vector3(-120,0,-104)
var driving := false
var case_active := false
var case_world := Vector3.ZERO
var route: Array[Vector3] = []
var police_world: Array[Vector3] = []

func _ready() -> void:
	custom_minimum_size = Vector2(194,194)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _point(world: Vector3) -> Vector2:
	return Vector2((world.x+224.0)/448.0*size.x,(world.z+224.0)/448.0*size.y)

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO,size),Color("0a1722"),true)
	var half := size*0.5
	draw_rect(Rect2(Vector2.ZERO,half),Color("1c313f"),true)
	draw_rect(Rect2(Vector2(half.x,0),half),Color("1a3636"),true)
	draw_rect(Rect2(Vector2(0,half.y),half),Color("373029"),true)
	draw_rect(Rect2(half,half),Color("18343e"),true)
	for i in range(-4,5):
		var p := (float(i*52)+224.0)/448.0*size.x
		draw_line(Vector2(p,0),Vector2(p,size.y),Color("60717b",0.7),1.0)
		draw_line(Vector2(0,p),Vector2(size.x,p),Color("60717b",0.7),1.0)
	draw_line(Vector2(0,size.y*0.5),Vector2(size.x,size.y*0.5),Color("1c7783",0.85),5.0)
	# Closure markers derive from the SAME game state as route calculation.
	for road in MOBILITY.active_incidents(GameState.data):
		var a: Array = road["a"]
		var b: Array = road["b"]
		var first: Vector3 = Vector3(-208.0+float(a[0])*52.0,0,-208.0+float(a[1])*52.0)
		var second: Vector3 = Vector3(-208.0+float(b[0])*52.0,0,-208.0+float(b[1])*52.0)
		draw_line(_point(first),_point(second),Color("ed604f"),4.0)
		draw_circle((_point(first)+_point(second))*0.5,3.6,Color("ffd36d"))
	if route.size() >= 2:
		var line_points := PackedVector2Array()
		for location in route:
			line_points.append(_point(location))
		draw_polyline(line_points,Color("d9b978",0.85),2.2,true)
	# Each street discovery is mapped from the same JSON catalog as its 3D beacon.
	var discovered: Array = GameState.data.get("discovered_sites",[])
	for item in DISCOVERY.sites():
		var map_at: Vector2 = _point(DISCOVERY.position(item))
		var collected: bool = discovered.has(str(item["id"]))
		draw_circle(map_at,3.2,Color("49566b") if collected else Color("7ce6c7"))
		if not collected:
			draw_arc(map_at,5.3,0.0,TAU,12,Color("97f5cf"),1.0)
	if case_active:
		var marker_point: Vector2 = _point(case_world)
		draw_arc(marker_point,8.5,0.0,TAU,20,Color("66f2d2"),2.5,true)
		draw_circle(marker_point,3.0,Color("b6fff3"))
	draw_circle(_point(goal_world),7.5,Color("ddba70",0.4))
	draw_circle(_point(goal_world),4.0,Color("e7d09a"))
	for unit in police_world:
		draw_circle(_point(unit),4.3,Color("3975ff"))
		draw_arc(_point(unit),6.3,0.0,TAU,16,Color("e34b61"),1.6)
	draw_circle(_point(vehicle_world),3.0,Color("7ab8c6"))
	draw_circle(_point(player_world),4.5,Color("7ee1b6") if not driving else Color("bceff4"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("8293a4",0.8),false,1.5)
