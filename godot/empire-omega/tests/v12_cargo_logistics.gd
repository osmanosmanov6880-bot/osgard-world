extends SceneTree
## Only Godot can run this: verifies the real cargo module and GameState end to end.
const CARGO = preload("res://scripts/cargo_logistics.gd")
var checked := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, message: String) -> void:
	checked += 1
	if ok:
		print("CARGO OK: " + message)
	else:
		failed += 1
		push_error("CARGO FAIL: " + message)

func _run() -> void:
	var contracts: Variant = root.get_node_or_null("ContractManager")
	if contracts == null:
		push_error("ContractManager singleton unavailable")
		quit(2)
		return
	var sim: Variant = root.get_node_or_null("GameState")
	if sim == null:
		push_error("GameState autoload is missing")
		quit(2)
		return
	sim.data = sim.new_game()
	var initial: Dictionary = sim.data
	var offer: Dictionary = contracts.current_offer()
	check(not offer.is_empty(),"contract catalog available")
	check(contracts.interact(str(offer["pickup"])) == "accepted","cargo accepted at origin")
	var active: Dictionary = sim.data["active_contract"]
	var required: float = float(active["cargo_progress"]["required"])
	check(required >= 65.0 and required <= 1500.0,"required journey is finite")
	check(sim._valid_state(initial),"active cargo serializes")
	check(contracts.interact(str(offer["dropoff"]),false,0.0) == "vehicle_required","walking delivery rejected")
	check(contracts.interact(str(offer["dropoff"]),true,5.0) == "stop_vehicle","unsafe moving unload rejected")
	check(contracts.interact(str(offer["dropoff"]),true,0.0) == "travel_more","teleporting to destination is not delivery")
	check(not sim.complete_courier(active,5000),"direct free payout rejected before driving")
	sim.data["wallet"] = 9000
	sim.data["reputation"] = 100
	check(sim.buy_vehicle("courier"),"garage can purchase second vehicle")
	check(not sim.select_vehicle("courier"),"cannot swap vehicle while cargo is loaded")
	var current_miles: float = float(sim.data["vehicle_mileage"])
	var iteration_count: int = ceili(required/2.0)+3
	for i in range(iteration_count):
		current_miles += 2.0
		var wear: float = 90.0 if i >= 35 else 100.0
		sim.sync_vehicle_live(75.0,wear,current_miles,true)
	check(CARGO.ready(active),"physical driving completes route")
	check(float(active["cargo_progress"]["condition"]) < 100.0,"damage reduces cargo quality")
	var lower_payment: int = sim.courier_payment(active)
	check(lower_payment < int(active["reward"]),"cargo damage reduces base compensation")
	var prior_stocks: int = int(sim.data["inventories"][str(offer["cargo"])])
	var expected_goods: int = CARGO.delivered_quantity(active)
	check(expected_goods <= int(offer["quantity"]),"damaged cargo cannot create supplies")
	check(not sim.complete_courier(active,lower_payment+1),"arbitrary payout rejected")
	check(contracts.interact(str(offer["dropoff"]),true,0.0) == "completed","parked delivery settles once")
	check(int(sim.data["inventories"][str(offer["cargo"])]) == prior_stocks + expected_goods,"received city stocks match intact cargo")
	check(int(sim.data["contracts_completed"]) == 1,"one completed contract counted")
	check(not sim.complete_courier(active,lower_payment),"duplicate settlement blocked")
	check(sim.select_vehicle("courier"),"vehicle switching restored after delivery")
	check(sim._valid_state(sim.data),"finished freight state validates")
	var payload: Variant = JSON.parse_string(JSON.stringify(sim._save_state_payload()))
	check(payload is Dictionary and sim._valid_state(payload["state"]),"finished delivery survives JSON roundtrip")
	var before: Dictionary = CARGO.begin(offer,100.0,0.0,100.0,"compact",1)
	var wet: Dictionary = before.duplicate(true)
	CARGO.update(before,5.0,100.0,true,"clear")
	CARGO.update(wet,5.0,100.0,true,"storm")
	check(float(wet["cargo_progress"]["condition"]) < float(before["cargo_progress"]["condition"]),"storm worsens cargo wear")
	var previous: Dictionary = offer.duplicate(true)
	previous["accepted_turn"] = 1
	sim.data = sim.new_game()
	sim.data["active_contract"] = previous
	check(sim._valid_state(sim.data),"v0.11 save with old active contract remains valid")
	var migrated: Dictionary = sim._upgrade_state(sim.data.duplicate(true))
	check(CARGO.ready(migrated["active_contract"]),"old in-flight job is grandfathered")
	check(sim._valid_state(migrated),"upgraded previous save validates")
	var damaged: Dictionary = migrated.duplicate(true)
	damaged["active_contract"]["cargo_progress"]["condition"] = 10000.0
	check(not sim._valid_state(damaged),"malformed cargo condition rejected")
	print("OSGARD NATIVE CARGO: %d / %d" % [checked-failed,checked])
	quit(0 if failed == 0 else 1)
