extends SceneTree
## R177 authentic original 3D playable HUD and source observer integration.
const SESSION=preload("res://scripts/city_reign_first_session_observer.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R177 ORIGINAL PLAYABLE SESSION QA FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var saved: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var lang: String=str(sim.get("locale"))
	sim.set("data",sim.new_game())
	var original: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var loaded: Error=change_scene_to_file("res://scenes/main.tscn")
	check(loaded==OK,"real native CITY REIGN full original scene loads")
	if loaded!=OK:
		sim.set("data",saved)
		sim.set("locale",lang)
		quit(2)
		return
	await process_frame
	for i in range(12):
		await physics_frame
	var game: Node3D=current_scene as Node3D
	var observer: RefCounted=game.get("first_session_observer")
	var hud: Node3D=game.get("hud")
	check(observer!=null and observer.started and
		observer.initial_step==0 and observer.last_step==0,
		"original live game owns same initial real six-mission observer")
	check(hud.has_signal("playtest_export_requested") and
		hud.r177_playtest_export!=null and hud.r177_playtest_status!=null,
		"real GPU HUD diagnostics has opt-in local first-six export control")
	check(hud.r177_playtest_export.custom_minimum_size.y>=40.0,
		"native real diagnostics retains usable touch/keyboard playtest export")
	check((game.get("ambient_cars") as Array).size()==12 and
		(game.get("pedestrians") as Array).size()==34,
		"true original 3D urban traffic/citizens unchanged")
	hud.update_playtest_status(observer.status_text("en"))
	check(hud.r177_playtest_status.text.contains("0/6") and
		observer.report()["first_six_verified"]==false,
		"actual fresh game displays objective 0/6 without invented completion")
	check(observer.invariants_hold() and
		not observer.report()["timing_goal_evaluated"],
		"real game must not claim 5–10 min from automatic smoke tests")
	check(int(sim.data["mission"])==int(original["mission"]) and
		int(sim.data["wallet"])==int(original["wallet"]) and
		original["buildings"]==sim.data["buildings"],
		"local observer never modifies core 40-mission game or real economy")
	current_scene.queue_free()
	await process_frame
	sim.set("data",saved)
	sim.set("locale",lang)
	print("CITY REIGN R177 TRUE PLAYABLE SESSION OBSERVER: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
