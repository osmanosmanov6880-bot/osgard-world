extends SceneTree
## R172 loaded original 3D city, car, 12 traffic actors and mission UI.
const COACH=preload("res://scripts/city_reign_action_readiness.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R172 LIVE WORLD FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var contracts: Node=root.get_node_or_null("ContractManager")
	var saved: Dictionary=sim.data.duplicate(true)
	var lang: String=sim.locale
	sim.data=sim.new_game()
	sim.locale="en"
	var money: int=int(sim.data["wallet"])
	var err: Error=change_scene_to_file("res://scenes/main.tscn")
	check(err==OK,"real original R171 scene loads without duplicate world")
	if err!=OK:
		sim.data=saved
		sim.locale=lang
		quit(2)
		return
	await process_frame
	for i in range(24): await physics_frame
	var scene: Node3D=current_scene as Node3D
	var car: CharacterBody3D=scene.get("car") as CharacterBody3D
	var hud: CanvasLayer=scene.get("hud") as CanvasLayer
	var touch: CanvasLayer=scene.get("touch_controls") as CanvasLayer
	check(car!=null and hud!=null and touch!=null,"actual car, HUD and real phone controls exist")
	check((scene.get("ambient_cars") as Array).size()==12 and
		(scene.get("pedestrians") as Array).size()==34,
		"12 original 3D traffic cars and 34 citizens unchanged")
	check((touch.get("_quick_buttons") as Dictionary).has("buy_business"),
		"native phone menu can perform original career's B action")
	sim.data["mission"]=2
	for i in range(5): await physics_frame
	var player: CharacterBody3D=scene.get("player") as CharacterBody3D
	var coach: Dictionary=COACH.project(sim.data,contracts.current_offer(),contracts.POSITIONS,
		player.global_position,car.global_position,false,0.0,false,"en")
	check(coach["active"] and str((hud.get("mission_label") as Label).text).contains(str(coach["title"])),
		"true live 3D scene projects current market action to HUD")
	check(int(sim.data["wallet"])==money and int(sim.data["mission"])==2,
		"presentation never modifies original economy or mission authority")
	current_scene.queue_free()
	await process_frame
	sim.data=saved
	sim.locale=lang
	print("CITY REIGN R172 ORIGINAL WORLD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
