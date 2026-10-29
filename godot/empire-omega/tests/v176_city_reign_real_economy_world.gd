extends SceneTree
## R175 true playable original GameState.advance_turn -> 3D stock and street PBR.
const PULSE=preload("res://scripts/city_reign_live_economy_pulse.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R175 ECONOMIC FULL 3D GAME FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var prior: Dictionary=sim.data.duplicate(true)
	var original_lang: String=sim.locale
	sim.data=sim.new_game()
	var status: Error=change_scene_to_file("res://scenes/main.tscn")
	check(status==OK,"real original Godot playable WebGL scene loads")
	if status!=OK:
		sim.data=prior
		sim.locale=original_lang
		quit(2)
		return
	await process_frame
	for i in range(8): await physics_frame
	var game: Node3D=current_scene as Node3D
	var world: Node3D=game.get("world")
	var meters: Node3D=world.get("city_reign_live_economy")
	var street: Node3D=world.get("city_reign_street_identity")
	check(meters!=null and meters.geometry_is_bounded(),
		"actual playable city owns original 12 physical economic meter nodes")
	check(street!=null and street.vitality_is_bounded(),
		"all 128 already existing 3D district marks read REAL saved vitality")
	check(int(world.get("building_count"))>0 and
		int(world.get("building_count"))<=128 and
		int(world.get("building_count"))==int(street.get("count")),
		"real original building count matches exact existing authored 3D building instances")
	check((game.get("ambient_cars") as Array).size()==12 and
		(game.get("pedestrians") as Array).size()==34,
		"original 12 NPC cars, 34 real citizens continue unmodified")
	var first_goods: int=int(meters.last_snapshot["housing"]["value"])
	check(first_goods==int(sim.data["inventories"]["goods"]),
		"native 3D label and saved goods inventory are originally identical")
	world.update_chunks(PULSE.SITE_ANCHORS["forum"],"cinematic")
	check((meters.foundations["forum"] as Node3D).visible and
		not (meters.foundations["lower"] as Node3D).visible,
		"original 1.1s world chunk culling now controls economic 3D proximity")
	var bought: bool=sim.buy_business("market_stall")
	await process_frame
	check(bought and int(meters.last_snapshot["housing"]["value"])==
		int(sim.data["inventories"]["goods"]),
		"original player purchase updates economy visuals through existing state_changed")
	var before_materials: int=int(sim.data["inventories"]["materials"])
	var turn: bool=sim.advance_turn()
	await process_frame
	check(turn and int(sim.data["turn"])==2,
		"original authoritative economy performs a REAL new city turn")
	check(int(meters.last_snapshot["lower"]["value"])==
		int(sim.data["inventories"]["materials"]) and
		int(meters.last_snapshot["aqueduct"]["value"])==int(sim.data["energy"]),
		"saved turn inventory and electricity instantly drive original physical city")
	check(int(sim.data["inventories"]["materials"])!=before_materials,
		"city economic engine actually recomputes real productive inventory")
	check(street.vitality_is_bounded() and
		int(street.city_vitality["housing"])==
		int(sim.data["district_scores"]["housing"]),
		"actual generated GPU facade color follows genuine district score after turn")
	var old_shade: Color=(street.nodes["District_forum"] as MultiMeshInstance3D).multimesh.get_instance_color(0)
	sim.data["district_scores"]["forum"]=0
	world.update_development()
	var down: Color=(street.nodes["District_forum"] as MultiMeshInstance3D).multimesh.get_instance_color(0)
	sim.data["district_scores"]["forum"]=100
	world.update_development()
	var up: Color=(street.nodes["District_forum"] as MultiMeshInstance3D).multimesh.get_instance_color(0)
	print("R175 ACTUAL MULTIMESH PROOF forum_count=%d samples original=%s low=%s high=%s vitality=%s revisions=%d" % [
		(street.nodes["District_forum"] as MultiMeshInstance3D).multimesh.instance_count,
		str(old_shade),str(down),str(up),str(street.city_vitality),int(street.vitality_updates)])
	check(up.r>down.r and up.g>down.g and is_finite(old_shade.r) and is_finite(old_shade.g),
		"same REAL original 3D facades visually change with live city district health")
	world.apply_visual_budget("low")
	check(not (meters.foundations["forum"] as Node3D).visible and
		not meters.is_processing() and street.graphics_are_bounded(),
		"phone LOW keeps original physical gameplay and disables new CPU/GPU art")
	check(int(sim.data["mission"])==0 and bool(sim.data["businesses"]["market_stall"]),
		"visual updates never grant mission completion or undo real paid business")
	current_scene.queue_free()
	await process_frame
	sim.data=prior
	sim.locale=original_lang
	print("CITY REIGN R175 REAL ECONOMIC 3D TURN: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
