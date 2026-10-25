extends SceneTree
## R92 native 3D->HUD projection test. No static image fixtures.
const PINS = preload("res://scripts/horizon_r92_projective_districts.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R92 REAL DISTRICT PROJECTION FAILED: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,400)
	root.add_child(viewport)
	var camera := Camera3D.new()
	viewport.add_child(camera)
	camera.position = Vector3(205,170,215)
	camera.look_at(Vector3(0,6,0),Vector3.UP)
	camera.current = true
	var positions: Array[Vector2] = []
	for key in ["forum","housing","lower","aqueduct"]:
		var projected: Dictionary = PINS.project_district(camera,key,Vector2(640,400))
		check(bool(projected.get("visible",false)),"world district actually in front of atlas camera: "+key)
		if bool(projected.get("visible",false)):
			var anchor: Vector2 = projected["anchor"]
			check(anchor.x>=0.15 and anchor.x<=0.85 and anchor.y>=0.20 and anchor.y<=0.84,
				"projected selection remains on-screen: "+key)
			positions.append(anchor)
	for a in range(positions.size()):
		for b in range(a+1,positions.size()):
			check(positions[a].distance_to(positions[b])>0.03,
				"separate real districts must not be stacked")
	var old: Dictionary = PINS.project_district(camera,"forum",Vector2(640,400))
	camera.position = Vector3(-205,170,215)
	camera.look_at(Vector3(0,6,0),Vector3.UP)
	var moved: Dictionary = PINS.project_district(camera,"forum",Vector2(640,400))
	if bool(old.get("visible",false)) and bool(moved.get("visible",false)):
		check((old["anchor"] as Vector2).distance_to(moved["anchor"])>0.015,
			"labels follow the actual 3D camera rather than hardcoded percentages")
	check(not bool(PINS.project_district(camera,"bogus",Vector2(640,400))["visible"]),
		"unknown location cannot create an invented map label")
	check(not bool(PINS.project_district(camera,"forum",Vector2.ZERO)["visible"]),
		"invalid viewport cannot generate a fake projection")
	viewport.queue_free()
	await process_frame
	print("EMPIRE Omega R92 actual 3D atlas projection: %d PASS, %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
