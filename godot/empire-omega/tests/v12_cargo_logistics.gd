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
	GameState.data = GameState.new_game()
	var initial: Dictionary = GameState.data
	var offer: Dictionary = ContractManager.current_offer()
	check(not offer.is_empty(),"contract catalog available")
	check(ContractManager.interact(str(offer["pickup"])) == "accepted","cargo accepted at origin")
	var active: Dictionary = GameState.data["active_contract"]
	var required: float = float(active["cargo_progress"]["required"])
	check(required >= 65.0 and required <= 1500.0,"required journey is finite")
	check(GameState._valid_state(initial),"active cargo serializes")
	check(ContractManager.interact(str(offer["dropoff"]),false,0.0) == "vehicle_required","walking delivery rejected")
	check(ContractManager.interact(str(offer["dropoff"]),true,5.0) == "stop_vehicle","unsafe moving unload rejected")
	check(ContractManager.interact(str(offer["dropoff"]),true,0.0) == "travel_more","teleporting to destination is not delivery")
	check(not GameState.complete_courier(active,5000),"direct free payout rejected before driving")
	GameState.data["wallet"] = 9000
	GameState.data["reputation"] = 100
	check(GameState.buy_vehicle("courier"),"garage can purchase second vehicle")
	check(not GameState.select_vehicle("courier"),"cannot swap vehicle while cargo is loaded")
	var current_miles: float = float(GameState.data["vehicle_mileage"])
	var iteration_count: int = ceili(required/2.0)+3
	for i in range(iteration_count):
		current_miles += 2.0
		var wear: float = 90.0 if i >= 35 else 100.0
		GameState.sync_vehicle_live(75.0,wear,current_miles,true)
	check(CARGO.ready(active),"physical driving completes route")
	check(float(active["cargo_progress"]["condition"]) < 100.0,"damage reduces cargo quality")
	var lower_payment: int = GameState.courier_payment(active)
	check(lower_payment < int(active["reward"]),"cargo damage reduces base compensation")
	var prior_stocks: int = int(GameState.data["inventories"][str(offer["cargo"])])
	var expected_goods: int = CARGO.delivered_quantity(active)
	check(expected_goods <= int(offer["quantity"]),"damaged cargo cannot create supplies")
	check(not GameState.complete_courier(active,lower_payment+1),"arbitrary payout rejected")
	check(ContractManager.interact(str(offer["dropoff"]),true,0.0) == "completed","parked delivery settles once")
	check(int(GameState.data["inventories"][str(offer["cargo"])]) == prior_stocks + expected_goods,"received city stocks match intact cargo")
	check(int(GameState.data["contracts_completed"]) == 1,"one completed contract counted")
	check(not GameState.complete_courier(active,lower_payment),"duplicate settlement blocked")
	check(GameState.select_vehicle("courier"),"vehicle switching restored after delivery")
	check(GameState._valid_state(GameState.data),"finished freight state validates")
	var payload: Variant = JSON.parse_string(JSON.stringify(GameState._save_state_payload()))
	check(payload is Dictionary and GameState._valid_state(payload["state"]),"finished delivery survives JSON roundtrip")
	var before: Dictionary = CARGO.begin(offer,100.0,0.0,100.0,"compact",1)
	var wet: Dictionary = before.duplicate(true)
	CARGO.update(before,5.0,100.0,true,"clear")
	CARGO.update(wet,5.0,100.0,true,"storm")
	check(float(wet["cargo_progress"]["condition"]) < float(before["cargo_progress"]["condition"]),"storm worsens cargo wear")
	var previous: Dictionary = offer.duplicate(true)
	previous["accepted_turn"] = 1
	GameState.data = GameState.new_game()
	GameState.data["active_contract"] = previous
	check(GameState._valid_state(GameState.data),"v0.11 save with old active contract remains valid")
	var migrated: Dictionary = GameState._upgrade_state(GameState.data.duplicate(true))
	check(CARGO.ready(migrated["active_contract"]),"old in-flight job is grandfathered")
	check(GameState._valid_state(migrated),"upgraded previous save validates")
	var damaged: Dictionary = migrated.duplicate(true)
	damaged["active_contract"]["cargo_progress"]["condition"] = 10000.0
	check(not GameState._valid_state(damaged),"malformed cargo condition rejected")
	print("OSGARD NATIVE CARGO: %d / %d" % [checked-failed,checked])
	quit(0 if failed == 0 else 1)
