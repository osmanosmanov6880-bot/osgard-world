extends SceneTree
## R171 original full main scene, car, live HUD and source-stable missions.
const COACH=preload("res://scripts/city_reign_episode_live_coach.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R171 REAL SOURCE WORLD FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var previous: Dictionary=sim.data.duplicate(true)
	var old_lang: String=str(sim.locale)
	sim.data=sim.new_game()
	var err: Error=change_scene_to_file("res://scenes/main.tscn")
	check(err==OK,"original full original city game scene is playable after source guidance")
	if err==OK:
		await process_frame
		await physics_frame
		var live: Node3D=current_scene as Node3D
		var car: CharacterBody3D=live.get("car") as CharacterBody3D
		var hud: CanvasLayer=live.get("hud") as CanvasLayer
		var actor: CharacterBody3D=live.get("player") as CharacterBody3D
		check(car!=null and hud!=null and actor!=null,
			"original world still has REAL vehicle, protagonist and HUD")
		var prior: Dictionary=sim.data.duplicate(true)
		hud.call("toggle_field_journal")
		check((hud.get("journal_panel") as PanelContainer).visible,
			"original H interaction opens source episode journal in real 3D scene")
		hud.call("update_world_context",actor.global_position,car.global_position,
			car.global_position,false,car.speed,car.fuel,"")
		var context: Label=hud.get("r171_live_context") as Label
		check(context.text==COACH.explain("enter_car",str(sim.locale)),
			"real full city player observes authentic 8m E interaction")
		check(sim.data==prior,
			"even running in real 3D world, suggestions cannot mutate 40 missions or resources")
		check((live.get("ambient_cars") as Array).size()==12 and
			(live.get("pedestrians") as Array).size()==34,
			"original 12 ambient cars and 34 real citizens still exist")
		check(live.get("city_reign_opening_director")!=null and
			car.get("horizon_visual")!=null,
			"original street landmarks, physical car shell and R169 cockpit retained")
		current_scene.queue_free()
		await process_frame
	sim.data=previous
	sim.locale=old_lang
	print("CITY REIGN R171 REAL WORLD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
