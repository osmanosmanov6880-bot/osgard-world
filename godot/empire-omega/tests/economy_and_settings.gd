extends SceneTree
## Executed by an actual Godot 4 runtime, not Python emulation:
## godot --headless --path godot --script res://tests/economy_and_settings.gd

var tests := 0
var failed := 0

func _initialize() -> void:
	call_deferred("_run")

func verify(condition: bool, label: String) -> void:
	tests += 1
	if condition:
		print("PASS: ",label)
	else:
		push_error("FAIL: "+label)
		failed += 1

func _run() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	var prefs: Variant = root.get_node_or_null("GameSettings")
	var courier: Variant = root.get_node_or_null("ContractManager")
	verify(sim != null and prefs != null and courier != null,"autoloads are initialized")
	if sim == null or prefs == null or courier == null:
		quit(2)
		return
	sim.data = sim.new_game()
	var pristine: String = JSON.stringify(sim.data)
	var before: Dictionary = sim.forecast()
	var second: Dictionary = sim.forecast()
	verify(before == second,"forecast deterministic for the same state")
	verify(JSON.stringify(sim.data) == pristine,"forecast never mutates GameState")
	verify(before.has("inventories") and before.has("district_scores"),"supply chain and districts included in forecast")
	verify(before.has("ledger") and before["ledger"].size() >= 6,"explainable economic ledger exists")
	var lowered: Dictionary = sim.data.duplicate(true)
	lowered["energy"] = 0
	lowered["water"] = 0
	lowered["food"] = 0
	lowered["inventories"] = {"grain":0,"materials":0,"goods":0}
	var engine: Variant = load("res://scripts/city_economy.gd")
	var hardship: Dictionary = engine.project(lowered,sim.BUILDINGS)
	verify(hardship["stability_delta"] < before["stability_delta"],"supply crisis decreases social stability")
	verify(hardship["shortages"] > 0,"insufficient stock generates shortage")
	verify(int(hardship["inventories"]["grain"]) >= 0,"stock cannot become negative")
	var forecast: Dictionary = sim.forecast()
	sim.advance_turn()
	verify(sim.data["inventories"] == forecast["inventories"],"one source of truth: applied inventories equal forecast")
	verify(int(sim.data["unemployment"]) == int(forecast["unemployment"]),"employment changes exactly as forecasted")
	verify(sim._valid_state(sim.data),"new economy serializes to supported state")
	var legacy: Dictionary = sim.data.duplicate(true)
	for field in ["inventories","unemployment","district_scores","economy_ledger","deliveries_value","vehicle_health"]:
		legacy.erase(field)
	verify(sim._valid_state(legacy),"legacy v4 saves remain valid")
	var upgraded: Dictionary = sim._upgrade_state(legacy)
	verify(sim._valid_state(upgraded) and upgraded.has("inventories"),"legacy saves migrate to current fields")

	# Exactly-once settlement: a second identical delivery cannot pay twice.
	sim.data = sim.new_game()
	verify(courier.offers.size() >= 12,"12 distinct logistics jobs loaded")
	var offer: Dictionary = courier.current_offer()
	verify(courier.interact(str(offer["pickup"])) == "accepted","job accepted")
	var stock_before: int = int(sim.data["inventories"][offer["cargo"]])
	var wallet_before: int = int(sim.data["wallet"])
	verify(courier.interact(str(offer["dropoff"]),true,0.0) == "travel_more","delivery requires a real trip")
	var journey_distance: float = float(courier.active_contract()["cargo_progress"]["required"])
	for step in range(ceili(journey_distance / 2.0) + 2):
		sim.sync_vehicle_live(90.0,100.0,float(step+1)*2.0,true)
	verify(courier.interact(str(offer["dropoff"]),true,0.0) == "completed","job completed after driving")
	verify(int(sim.data["wallet"]) > wallet_before,"courier earns real personal income")
	verify(int(sim.data["inventories"][offer["cargo"]]) > stock_before,"courier adds real municipal supplies")
	verify(not sim.complete_courier(offer,500),"same contract cannot settle twice")
	verify(sim._valid_state(sim.data),"completed delivery state validates")

	# These are live InputMap bindings, not decorative settings entries.
	verify(InputMap.has_action("jump") and InputMap.has_action("governor"),"movement and strategy actions registered")
	var previous: int = int(prefs.keys["jump"])
	verify(not prefs.rebind("jump",int(prefs.keys["interact"])),"conflicting key is rejected")
	verify(prefs.rebind("jump",KEY_J),"free key can be assigned")
	verify(int(prefs.keys["jump"]) == KEY_J,"remap persisted in current configuration")
	verify(prefs.rebind("jump",previous),"default binding restored")
	prefs.reset_bindings()
	prefs.set_reduced_motion(false)

	# Repeatable simulation beyond the first turn: reserves and savings stay legal.
	sim.data = sim.new_game()
	var valid_turns := true
	for i in range(36):
		sim.advance_turn()
		if str(sim.data["incident"]) != "": sim.resolve_incident(false)
		if not sim._valid_state(sim.data):
			valid_turns = false
			break
	verify(valid_turns,"36 economy turns stay within serialization bounds")
	verify(sim.data["history"].size() == 36,"history retains 36 turn summaries")
	print("NATIVE ECONOMY/SETTINGS: ",tests-failed," / ",tests)
	quit(0 if failed == 0 else 1)
