extends SceneTree
## R171 native integration with the REAL R170 physical city, waypoint and HUD.
const GOAL=preload("res://scripts/city_reign_goal_fabric.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R171 LIVE WAYPOINT FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var original: Dictionary=sim.data.duplicate(true)
	var locale: String=sim.locale
	sim.data=sim.new_game()
	var initial: Dictionary=sim.data.duplicate(true)
	var loaded: Error=change_scene_to_file("res://scenes/main.tscn")
	check(loaded==OK,"actual original full world loads with one shared route fabric")
	if loaded!=OK:
		sim.data=original
		sim.locale=locale
		quit(2)
		return
	for i in range(4): await physics_frame
	var main: Node3D=current_scene as Node3D
	var car: CharacterBody3D=main.get("car") as CharacterBody3D
	var world: Node3D=main.get("world") as Node3D
	var hud: CanvasLayer=main.get("hud") as CanvasLayer
	check(car!=null and world!=null and hud!=null,
		"real native drivable car, city world and original HUD remain")
	check(str(main.get("last_route_source"))=="vehicle",
		"the current actual car is first genuine on-road GPS objective")
	var initial_nav: Dictionary=GOAL.resolve(sim.data,"enter_vehicle",ContractManager.current_offer(),
		ContractManager.POSITIONS,car.global_position,Vector3.ZERO,Vector3.ZERO,Vector3.ZERO)
	check(initial_nav["active"] and initial_nav["point"]==car.global_position,
		"original source car transform, not stale save position, drives live objective")
	sim.data["mission"]=1
	for i in range(4): await physics_frame
	check(str(main.get("last_route_source"))=="market",
		"switching first career action invalidates and reroutes to real market")
	sim.data["mission"]=2
	for i in range(4): await physics_frame
	check(str(main.get("last_route_source"))=="none",
		"menu-only business acquisition no longer paints a FALSE freight road")
	var map: Control=hud.get("map") as Control
	check(map!=null and (map.get("route") as Array).is_empty(),
		"changing to nonspatial activity clears stale 2D A* route")
	check((main.get("route_chevron") as Node3D).visible==false,
		"no 3D arrow advertising a non-spatial menu action")
	check((main.get("ambient_cars") as Array).size()==12 and
		(main.get("pedestrians") as Array).size()==34,
		"all original real 12 city traffic vehicles and 34 citizens still exist")
	check(sim.data["treasury"]==initial["treasury"] and
		int(sim.data["wallet"])==int(initial["wallet"]) and
		int(sim.data["mission"])==2,
		"read-only route changes do not mint cash or alter career progression")
	current_scene.queue_free()
	await process_frame
	sim.data=original
	sim.locale=locale
	print("CITY REIGN R171 REAL IN-GAME NAV: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
