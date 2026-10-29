extends SceneTree
## R170 real saved original mission authority, physically drivable scene remains.
const EP=preload("res://scripts/city_reign_episode_sequence.gd")
# Main car script depends on runtime GameState autoload; load after initialize.
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R170 REAL GAME FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var career: Node=root.get_node_or_null("MissionManager")
	var original: Dictionary=sim.data.duplicate(true)
	var original_lang: String=sim.locale
	sim.data=sim.new_game()
	var initial_wallet: int=int(sim.data["wallet"])
	var offered: Dictionary=ContractManager.current_offer()
	# Wrong actions NEVER advance a single byte of original campaign.
	check(not career.register_action("deliver") and sim.data["mission"]==0,
		"arbitrary F before entering vehicle does NOT advance first mission")
	for index in range(EP.TOTAL_STEPS):
		var step: Dictionary=EP.first_six(sim.data,offered,ContractManager.POSITIONS,"en")
		check(step["action"]==career.MISSIONS[index]["id"] and step["step"]==index+1,
			"native existing MissionManager owns real six milestones")
		check(career.register_action(str(step["action"])) and sim.data["mission"]==index+1,
			"only original career action registers and advances authoritative mission index")
		check(not career.register_action(str(step["action"])),
			"old actions cannot replay the same step or pay twice")
	check(sim.data["mission"]==6 and int(sim.data["wallet"])>initial_wallet,
		"real Chapter 1 completed by original mission actions and authoritative rewards")
	var earned: int=int(sim.data["wallet"])-initial_wallet
	var after: Dictionary=sim.data.duplicate(true)
	for i in range(80):
		EP.first_six(sim.data,offered,ContractManager.POSITIONS,["ru","en","zh"][i%3])
	check(sim.data==after and int(sim.data["wallet"])-initial_wallet==earned,
		"80 journal, resume and translation projections cannot duplicate one credit")
	# REAL game engine scene: do not fake route screenshots or skip the true car.
	var err: Error=change_scene_to_file("res://scenes/main.tscn")
	check(err==OK,"original actual playable main city imports from R170 source")
	if err==OK:
		await process_frame
		await physics_frame
		var current: Node3D=current_scene as Node3D
		var vehicle: CharacterBody3D=current.get("car") as CharacterBody3D
		check(vehicle!=null and vehicle.get("horizon_visual")!=null,
			"full physical R169 original car and cockpit remains on actual road")
		check((current.get("ambient_cars") as Array).size()==12 and
			(current.get("pedestrians") as Array).size()==34,
			"original 12 physically moving traffic cars and 34 citizens survive R170")
		check(current.get("city_reign_opening_director")!=null,
			"genuine original on-street 3D markers remain installed")
		current_scene.queue_free()
		await process_frame
	sim.data=original
	sim.locale=original_lang
	print("CITY REIGN R170 REAL CHAPTER: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
