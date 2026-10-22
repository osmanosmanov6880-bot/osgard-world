extends SceneTree
## Requires installed Godot 4.4.1. No test result is claimed until actually run.
## Includes actual GameState methods and instantiated 3D interior nodes.

var tests := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_test")

func verify(condition: bool, label: String) -> void:
	tests += 1
	if condition:
		print("V08 PASS: " + label)
	else:
		failures += 1
		push_error("V08 FAIL: " + label)

func _test() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	verify(sim != null,"GameState singleton available")
	if sim == null:
		quit(2)
		return
	sim.data = sim.new_game()
	var market = load("res://scripts/city_market.gd")
	var garage = load("res://scripts/vehicle_catalog.gd")
	verify(market.GOODS.size() == 3,"three commodity groups")
	verify(garage.ORDER.size() == 4,"four distinct vehicle models")
	for commodity in market.GOODS:
		verify(market.price(sim.data,commodity,true) > market.price(sim.data,commodity,false),"buy/sell spread protects " + commodity)
	verify(sim.market_quote("fake",true).is_empty(),"unknown commodity rejected")
	verify(not sim.trade_goods("grain",true,1000),"oversized market order rejected")
	var money: int = int(sim.data["treasury"])
	var wallet: int = int(sim.data["wallet"])
	var before_grain: int = int(sim.data["inventories"]["grain"])
	var price: int = int(sim.market_quote("grain",true)["total"])
	verify(sim.trade_goods("grain",true),"buy food on external market")
	verify(int(sim.data["treasury"]) == money-price,"market debits municipal treasury exactly")
	verify(int(sim.data["inventories"]["grain"]) == before_grain+10,"market replenishes real stocks")
	verify(sim.trade_goods("grain",false),"sell inventory back to market")
	verify(int(sim.data["treasury"]) < money,"round-trip trade cannot print public money")
	verify(sim.trade_goods("materials",true),"trade in construction materials")
	verify(sim.trade_goods("goods",true),"trade in consumer goods")
	verify(int(sim.data["wallet"]) == wallet,"public market never transfers municipal money to player")
	verify(not sim.trade_goods("grain",true),"maximum four orders per economic turn")
	verify(sim._valid_state(sim.data),"market trades preserve save validity")
	sim.advance_turn()
	verify(int(sim.data["market_orders"]) == 0,"trade quota resets next turn")
	# An unresolved crisis must not allow a free turn or mission progress.
	sim.data["incident"] = "blackout"
	var previous_turn: int = int(sim.data["turn"])
	verify(not sim.advance_turn(),"advance rejected while crisis is active")
	verify(int(sim.data["turn"]) == previous_turn,"blocked crisis does not modify turn number")
	verify(sim.resolve_incident(false),"active crisis can be acknowledged")

	sim.data = sim.new_game()
	verify(bool(sim.data["vehicle_owned"]["compact"]),"starter car is owned")
	verify(not sim.select_vehicle("executive"),"unowned car cannot be selected")
	verify(not sim.buy_vehicle("utility"),"expensive/high reputation vehicle gated")
	sim.data["wallet"] = 3500
	sim.data["reputation"] = 50
	verify(sim.buy_vehicle("executive"),"player can buy sedan when qualified")
	verify(not sim.buy_vehicle("executive"),"duplicate purchase blocked")
	sim.sync_vehicle_live(18.0,40.0,250.0)
	verify(sim.select_vehicle("executive"),"garage selection changes active model")
	verify(float(sim.data["vehicle_fuel"]) == 100.0,"newly purchased car has a separate fuel tank")
	verify(float(sim.data["vehicle_health"]) == 100.0,"newly purchased car has independent condition")
	verify(sim.select_vehicle("compact"),"switching back to the original car")
	verify(float(sim.data["vehicle_fuel"]) == 18.0,"old car fuel is not magically replenished")
	verify(float(sim.data["vehicle_health"]) == 40.0,"old car damage cannot be erased by switching")
	verify(sim._valid_state(sim.data),"garage fields validate after purchase")
	var save_payload: Dictionary = sim._save_state_payload()
	var json: Variant = JSON.parse_string(JSON.stringify(save_payload))
	verify(json is Dictionary and sim._valid_state(json["state"]),"market and garage state roundtrip")
	var legacy: Dictionary = sim.data.duplicate(true)
	for field in ["market_orders","market_history","vehicle_owned","vehicle_selected","vehicle_mileage","interior"]:
		legacy.erase(field)
	verify(sim._valid_state(legacy),"original v0.7 save remains accepted")
	var migrated: Dictionary = sim._upgrade_state(legacy)
	verify(sim._valid_state(migrated) and migrated.has("vehicle_owned"),"v0.7 save receives default garage")

	var interior_script = load("res://scripts/interior_manager.gd")
	var manager: Node3D = interior_script.new()
	root.add_child(manager)
	await process_frame
	verify(manager.room_nodes.size() == 12,"twelve procedural interiors generate")
	verify(manager.can_enter("market") and manager.can_enter("depot") and manager.can_enter("power"),"four legacy public interiors remain accessible")
	verify(not manager.can_enter("clinic"),"unbuilt clinic is inaccessible")
	sim.data["buildings"]["clinic"] = 1
	verify(manager.can_enter("clinic"),"constructing clinic unlocks its room")
	var avatar := Node3D.new()
	avatar.position = Vector3(-130.0,1.2,-120.0)
	root.add_child(avatar)
	verify(manager.enter("cityhall",avatar),"player enters city hall interior")
	verify(manager.is_inside(),"active room state tracks interior")
	verify(not manager.enter("market",avatar),"cannot stack multiple interiors")
	avatar.global_position = manager.CENTERS["cityhall"] + Vector3(0,1,10)
	verify(manager.at_exit(avatar.global_position),"exit zone is inside walkable room")
	verify(manager.leave(avatar),"player can return to exterior")
	verify(not manager.is_inside(),"room state clears on exit")
	verify(avatar.global_position.distance_to(Vector3(-130.0,1.2,-120.0)) < 1.0,"return position is preserved")
	manager.queue_free()
	avatar.queue_free()
	verify(InputMap.has_action("enter_interior"),"interior hotkey registered")

	var packed: PackedScene = load("res://scenes/main.tscn")
	if packed != null:
		sim.data = sim.new_game()
		var scene: Node = packed.instantiate()
		root.add_child(scene)
		await process_frame
		var city: Variant = scene.get("world")
		verify(city != null,"main scene creates procedural world")
		if city != null:
			verify(city.building_chunks.size() > 40,"city buildings grouped into streaming quarters")
			city.update_chunks(Vector3(-130,0,-130),"low")
			verify(city.active_chunk_count < city.building_chunks.size(),"distant districts inactive on low preset")
			city.update_chunks(Vector3(0,0,0),"cinematic")
			verify(city.active_chunk_count > 20,"near chunks reactivate when player approaches")
		scene.queue_free()
	print("V08 GODOT GAMEPLAY: %d / %d PASS" % [tests-failures,tests])
	quit(0 if failures == 0 else 1)
