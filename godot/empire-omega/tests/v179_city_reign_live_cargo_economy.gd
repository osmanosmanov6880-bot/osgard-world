extends SceneTree
## R176 full original 3D game, original contract acceptance and CARGO.update.
const CARGO=preload("res://scripts/cargo_logistics.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R176 REAL COURIER SCENE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var state: Node=root.get_node("GameState")
	var original: Dictionary=(state.get("data") as Dictionary).duplicate(true)
	var old_locale: String=str(state.get("locale"))
	state.set("data",state.new_game())
	var status: Error=change_scene_to_file("res://scenes/main.tscn")
	check(status==OK,"real original playable main.tscn still loads")
	if status!=OK:
		state.set("data",original)
		state.set("locale",old_locale)
		quit(2)
		return
	await process_frame
	for i in range(8): await physics_frame
	var main: Node3D=current_scene as Node3D
	var physical_car: Node3D=main.get("car")
	var freight: Node3D=main.get("cargo_visual")
	var contracts: Node=root.get_node("ContractManager")
	check(freight!=null and freight.get_parent()==physical_car and
		freight.visuals_are_source_bounded(),
		"true 3D source cargo HUD remains physically attached to original live car")
	check((main.get("ambient_cars") as Array).size()==12 and
		(main.get("pedestrians") as Array).size()==34,
		"all 12 native traffic vehicles and 34 citizens retained")
	check(not freight.visible,"original empty-game car has no fake physical goods")
	var original_wallet: int=int(state.data["wallet"])
	var offer: Dictionary=contracts.current_offer()
	var pickup: String=str(offer.get("pickup",""))
	var accepted: String=contracts.interact(pickup,false,0.0)
	await process_frame
	check(accepted=="accepted" and freight.visible and
		int(state.data["wallet"])==original_wallet,
		"original authorized cargo contract loads actual car with ZERO unearned reward")
	var progress: Dictionary=state.data["active_contract"]["cargo_progress"]
	check(CARGO.valid_progress(progress) and freight.display_is_authoritative(),
		"same original secure accepted contract drives read-only HUD projection")
	var before: Dictionary=state.data["active_contract"].duplicate(true)
	CARGO.update(state.data["active_contract"],20.0,
		100.0,true,"clear")
	freight.sync_state(state.data,"en")
	check(int(freight.last_projection["meters"])==20 and
		not bool(freight.last_projection["distance_met"]),
		"original cargo source meters follow real odometer API, not visual scripted success")
	check(int(state.data["wallet"])==original_wallet and
		int(state.data["contracts_completed"])==0 and
		!state.data["active_contract"].is_empty(),
		"3D display cannot complete, reward or change accepted contract")
	# Prevent false out-of-contract drop: original source still blocks.
	var destination: String=str(offer.get("dropoff",""))
	check(contracts.interact(destination,true,0.0)=="travel_more",
		"original physically unready delivery remains blocked despite fancy HUD")
	var restored: Dictionary=before.duplicate(true)
	check(CARGO.completion_fraction(restored)<1.0 and
		not freight.last_projection["distance_met"],
		"original source and native display agree that measured trip is incomplete")
	current_scene.queue_free()
	await process_frame
	state.set("data",original)
	state.set("locale",old_locale)
	print("CITY REIGN R176 ACTUAL PLAYABLE CARGO: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
