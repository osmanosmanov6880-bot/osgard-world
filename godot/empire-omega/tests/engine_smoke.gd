extends SceneTree
## Execute only with an installed Godot 4 runtime:
## godot --headless --path godot --script res://tests/engine_smoke.gd
## Unlike Python validators, these checks load actual GDScript and a real scene.

var failures := 0
var checks := 0

func _initialize() -> void:
	call_deferred("_test")

func _check(condition: bool, name: String) -> void:
	checks += 1
	if condition:
		print("SMOKE OK: " + name)
	else:
		push_error("SMOKE FAILED: " + name)
		failures += 1

func _test() -> void:
	var state: Variant = root.get_node_or_null("GameState")
	var missions: Variant = root.get_node_or_null("MissionManager")
	var courier: Variant = root.get_node_or_null("ContractManager")
	_check(state != null,"GameState autoload")
	_check(missions != null,"MissionManager autoload")
	_check(courier != null,"ContractManager autoload")
	if state == null or missions == null or courier == null:
		quit(2)
		return
	state.data = state.new_game()
	_check(state._valid_state(state.data),"new game has a valid versioned state")
	_check(int(state.data["wallet"]) == 600,"player wallet initialized separately")
	_check(int(state.data["treasury"]) == 1000,"city treasury initialized")
	var offer: Dictionary = courier.current_offer()
	_check(not offer.is_empty(),"non-empty courier catalog")
	if not offer.is_empty():
		_check(courier.interact(str(offer["pickup"])) == "accepted","courier accepts cargo at pickup")
		_check(not courier.active_contract().is_empty(),"contract is stored inside GameState")
		_check(courier.interact("nonexistent") == "not_here","delivery requires correct destination")
		var wallet_before: int = int(state.data["wallet"])
		_check(courier.interact(str(offer["dropoff"]),true,0.0) == "travel_more","delivery needs road distance")
		var travel_required: float = float(courier.active_contract()["cargo_progress"]["required"])
		for step in range(ceili(travel_required / 2.0) + 2):
			state.sync_vehicle_live(90.0,100.0,float(step+1)*2.0,true)
		_check(courier.interact(str(offer["dropoff"]),true,0.0) == "completed","courier delivers after real driving")
		_check(int(state.data["wallet"]) > wallet_before,"courier pays player's wallet")
		_check(int(state.data["contracts_completed"]) == 1,"delivery counter updated")
	_check(state.buy_business("market_stall"),"player can acquire a business")
	_check(state.private_turn_income() > 0,"business provides personal income")
	_check(state.build("plant"),"new power station can be constructed")
	_check(int(state.data["buildings"]["plant"]) == 1,"construction updates GameState")
	var projected: Dictionary = state.forecast()
	_check(projected.has("net"),"economic forecast calculated")
	var wallet_before_turn: int = int(state.data["wallet"])
	state.advance_turn()
	_check(int(state.data["turn"]) == 2,"economic turn advances")
	_check(int(state.data["wallet"]) >= wallet_before_turn+42,"business profit is paid once per turn")
	_check(state.data["history"].size() == 1,"turn history recorded")
	_check(state.transfer_to_city(250),"player can invest private money in city")
	_check(state._valid_state(state.data),"modified economy remains serializable")
	var payload: String = JSON.stringify(state._save_state_payload())
	var parsed: Variant = JSON.parse_string(payload)
	_check(parsed is Dictionary,"versioned state serializes to JSON")
	if parsed is Dictionary:
		_check(state._valid_state(parsed["state"]),"round-trip state validates")
	var router: Variant = load("res://scripts/street_router.gd")
	var path: Array[Vector3] = router.find_route(Vector3(-115,0,-104),Vector3(130,0,130))
	_check(path.size() > 2,"GPS route has street waypoints")
	_check(path.front().x == -115.0,"route begins at current position")
	_check(path.back().x == 130.0,"route ends at destination")
	_check(missions.MISSIONS.size() == 40,"forty sequential authored career missions")
	var packed: PackedScene = load("res://scenes/main.tscn")
	_check(packed != null,"world scene parses")
	if packed != null:
		var scene: Variant = packed.instantiate()
		root.add_child(scene)
		await process_frame
		_check(scene.get_child_count() >= 5,"3D world and playable systems instantiate")
		var simulated_world: Variant = scene.get("world")
		_check(simulated_world != null,"procedural city exists")
		if simulated_world != null:
			_check(simulated_world.building_count > 80,"city generates a meaningful set of buildings")
			_check(simulated_world.window_points.size() > 200,"procedural facades create window instances")
			_check(simulated_world.project_visuals["plant"]["root"].visible,"investment materializes in 3D")
			var building_visual: Node3D = simulated_world.project_visuals["plant"]["root"]
			_check(building_visual.get_node_or_null("VisualMesh") is MeshInstance3D,"built project has a geometry node separate from its collider")
		scene.queue_free()
	print("OSGARD NATIVE SMOKE: %d / %d passed" % [checks-failures,checks])
	quit(0 if failures == 0 else 1)
