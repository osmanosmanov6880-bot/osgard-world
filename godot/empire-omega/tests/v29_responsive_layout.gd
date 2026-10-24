extends SceneTree
## HORIZON R7 layout gates: real viewport pixel geometries, no screenshot guesswork.
const LAYOUT = preload("res://scripts/horizon_responsive_layout.gd")
var passed := 0
var failed := 0

func verify(condition: bool, message: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R7 GEOMETRY: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	for size in [Vector2(320,568),Vector2(360,640),Vector2(390,844),Vector2(430,932),
				Vector2(768,1024),Vector2(860,540),Vector2(320,410)]:
		var frame: Dictionary = LAYOUT.compute(size)
		verify(bool(frame.get("compact",false)),"compact viewport "+str(size))
		var keys := ["header","objective","speed","map","help","journal","diagnostics","toast","modal","quick_toggle","quick_panel"]
		for key in keys:
			var rect: Rect2 = frame[key]
			verify(rect.position.x>=0.0 and rect.position.y>=0.0,"no negative coordinate "+str(size)+" / "+key)
			verify(rect.size.x>40.0 and rect.size.y>=40.0,"legible area "+str(size)+" / "+key)
			verify(rect.end.x<=size.x+0.1 and rect.end.y<=size.y+0.1,"fits viewport "+str(size)+" / "+key)
		var header: Rect2 = frame["header"]
		var speed: Rect2 = frame["speed"]
		var objective: Rect2 = frame["objective"]
		var help: Rect2 = frame["help"]
		verify(not header.intersects(speed),"header and speedometer never overlap")
		verify(not objective.intersects(header) and not objective.intersects(speed),"objective below header row")
		verify(help.end.y<=size.y-100.0,"touch driving row stays clear of help text")
		verify(frame["quick_toggle"].end.y < help.position.y or size.y<=410.0,"quick menu does not cover hint on common phones")
		if size.x<360.0 or size.y<690.0:
			verify(not bool(frame["map_default"]),"optional map hidden in narrow/short modes")
	for size in [Vector2(1024,768),Vector2(1600,900),Vector2(1920,1080)]:
		var frame: Dictionary = LAYOUT.compute(size)
		verify(not bool(frame.get("compact",false)),"desktop retains original layout "+str(size))
	var hud: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	var touch: String = FileAccess.get_file_as_string("res://scripts/horizon_touch_controls.gd")
	verify(hud.contains("HORIZON_LAYOUT.compute(screen)"),"live HUD uses tested geometry")
	verify(hud.contains("get_viewport().size_changed.connect(_apply_responsive_layout)"),"orientation changes update actual HUD")
	verify(hud.contains("func toggle_map()"),"phone route can toggle minimap panel")
	verify(main.contains("hud.toggle_map()"),"map shortcut calls real minimap API")
	verify(touch.contains("HORIZON_LAYOUT.compute(viewport_size)"),"quick actions obey same geometry")
	verify(touch.contains("Input.parse_input_event(down)"),"quick actions send actual native InputMap events")
	verify(main.contains("DisplayServer.is_touchscreen_available() else Input.MOUSE_MODE_CAPTURED"),"touch never gets mouse captured on dialog closure")
	print("HORIZON R7 RESPONSIVE NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
