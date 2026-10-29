extends SceneTree
## R172 actual Godot HUD: source-bound action, 46px journal access,
## multilingual labels, original mobile business input and zero new rewards.
const COACH=preload("res://scripts/city_reign_action_readiness.gd")
const TOUCH=preload("res://scripts/horizon_touch_controls.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R172 ACTUAL HUD FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var contracts: Node=root.get_node_or_null("ContractManager")
	var saved: Dictionary=sim.data.duplicate(true)
	var saved_lang: String=sim.locale
	sim.data=sim.new_game()
	var hud_script: Variant=load("res://scripts/hud.gd")
	check(hud_script is Script and hud_script.can_instantiate(),"original HUD GDScript loads")
	if not (hud_script is Script and hud_script.can_instantiate()):
		sim.data=saved
		sim.locale=saved_lang
		quit(2)
		return
	var hud: CanvasLayer=hud_script.new()
	root.add_child(hud)
	var actor: Vector3=Vector3(-100,1,-100)
	var car: Vector3=Vector3(-105,1,-100)
	for lang in ["ru","en","zh"]:
		sim.locale=lang
		sim.data["mission"]=0
		hud.call("_refresh")
		hud.call("update_world_context",actor,car,car,false,0.0,100.0,"",100.0)
		var coach: Dictionary=COACH.project(sim.data,contracts.current_offer(),
			contracts.POSITIONS,actor,car,false,0.0,false,lang)
		var heading: Label=hud.get("mission_label") as Label
		var journal: Label=hud.get("r170_episode_controls") as Label
		check(heading.text.contains(str(coach["title"])) and journal.text==str(coach["detail"]),
			"live on-foot E action uses original rendered HUD in "+lang)
		sim.data["mission"]=3
		hud.call("_refresh")
		hud.call("update_world_context",actor,car,Vector3.ZERO,false,0.0,100.0,"",100.0)
		var expected: Dictionary=COACH.project(sim.data,contracts.current_offer(),
			contracts.POSITIONS,actor,car,false,0.0,false,lang)
		check(heading.text.contains(str(expected["title"])) and expected["key"]=="Tab",
			"real municipal cabinet step actionable in "+lang)
	var detail: Button=hud.get("objective_details_button")
	check(detail!=null and detail.custom_minimum_size.y>=46.0,
		"journal touch target remains at least 46px")
	check((hud.get("mission_label") as Label).max_lines_visible==1,
		"short native action heading avoids mobile multi-line occlusion")
	var touch: CanvasLayer=TOUCH.new()
	root.add_child(touch)
	var quick: Dictionary=touch.get("_quick_buttons")
	check(quick.has("buy_business") and (quick["buy_business"] as Button).text!="",
		"real phone menu exposes business action from original InputMap")
	check(InputMap.has_action("buy_business"),"touch B action is same as desktop mission action")
	touch.queue_free()
	hud.queue_free()
	await process_frame
	sim.data=saved
	sim.locale=saved_lang
	print("CITY REIGN R172 ORIGINAL HUD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
