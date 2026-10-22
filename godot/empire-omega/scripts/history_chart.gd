extends Control
## Compact treasury / private-wallet history for the governor's office.
## Pure rendering: it never mutates the economy.

var snapshots: Array = []

func _ready() -> void:
	custom_minimum_size = Vector2(660,145)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func set_history(records: Array) -> void:
	snapshots = records.duplicate(true)
	queue_redraw()

func _draw() -> void:
	var width: float = maxf(size.x,560.0)
	var height: float = maxf(size.y,140.0)
	var plot := Rect2(10,10,width-20,height-20)
	draw_rect(plot,Color("122638"),true)
	for step in range(1,4):
		var y: float = plot.position.y+float(step)*plot.size.y/4.0
		draw_line(Vector2(plot.position.x,y),Vector2(plot.end.x,y),Color("7890a8",0.18),1)
	if snapshots.size() < 2: return
	var lows: float = INF
	var highs: float = -INF
	for item in snapshots:
		if item is Dictionary:
			for key in ["treasury","wallet"]:
				var v: float = float(item.get(key,0))
				lows = minf(lows,v)
				highs = maxf(highs,v)
	var spread: float = maxf(200.0,highs-lows)
	var floor_value: float = lows-spread*0.08
	var ceiling_value: float = highs+spread*0.08
	for key in ["treasury","wallet"]:
		var points := PackedVector2Array()
		for i in range(snapshots.size()):
			var x: float = plot.position.x + float(i)/float(snapshots.size()-1)*plot.size.x
			var value: float = float(snapshots[i].get(key,0))
			var y: float = plot.end.y - (value-floor_value)/(ceiling_value-floor_value)*plot.size.y
			points.append(Vector2(x,y))
		if points.size() >= 2:
			draw_polyline(points,Color("e9c782") if key=="treasury" else Color("71cfbe"),2.8,true)
