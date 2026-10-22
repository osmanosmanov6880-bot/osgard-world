extends SceneTree
## Native-only executable tests. Run with Godot 4.4.1 (NOT Python).
var checked := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_test")

func verify(condition: bool, message: String) -> void:
	checked += 1
	if condition:
		print("PROPERTY/WEATHER PASS: ",message)
	else:
		failures += 1
		push_error("PROPERTY/WEATHER FAIL: "+message)

func _test() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	verify(sim != null,"GameState autoload available")
	if sim == null:
		quit(2)
		return
	var realty: Variant = load("res://scripts/real_estate.gd")
	var climate: Variant = load("res://scripts/city_weather.gd")
	sim.data = sim.new_game()
	verify(realty.PROPERTY_IDS.size() == 8,"eight independently identified investment sites")
	verify(sim.data["properties"].size() == 8,"ownership stored in save state")
	verify(sim.property_cost("arcade") == 420,"first property is initially affordable")
	verify(not sim.buy_property("unknown"),"unknown property rejected")
	verify(not sim.renovate_property("arcade"),"unowned property cannot be renovated")
	var before_wallet: int = int(sim.data["wallet"])
	verify(sim.buy_property("arcade"),"player buys first property")
	verify(int(sim.data["wallet"]) == before_wallet - 420,"purchase debits personal wallet once")
	verify(not sim.buy_property("arcade"),"duplicate purchase rejected")
	verify(int(sim.data["properties"]["arcade"]) == 1,"ownership changes only once")
	var after_purchase: Dictionary = sim.data.duplicate(true)
	var first_projection: Dictionary = sim.forecast()
	var second_projection: Dictionary = sim.forecast()
	verify(first_projection == second_projection,"city and rental forecasts deterministic")
	verify(sim.data == after_purchase,"forecast does not mutate game state")
	verify(first_projection["real_estate"]["entries"].size() == 1,"owned property included in rent calculation")
	verify(first_projection["personal_income"] == first_projection["real_estate"]["net"],"rent and private earnings share the same forecast")
	var rainy: Dictionary = climate.for_turn(781413,5)
	verify(rainy == climate.for_turn(781413,5),"weather deterministic for equal seed and turn")
	var seen := {}
	for turn in range(1,100):
		seen[climate.for_turn(781413,turn)["kind"]] = true
	verify(seen.size() >= 3,"climate changes across the season")
	var conditions: Dictionary = sim.current_weather()
	verify(climate.LABELS.has(conditions["kind"]),"weather is localizable")
	var private_before: int = int(sim.data["wallet"])
	sim.advance_turn()
	verify(int(sim.data["turn"]) == 2,"economic turn advances with rentals")
	verify(int(sim.data["wallet"]) >= 0,"negative balance protected")
	verify(int(sim.data["real_estate_revenue"]) == int(first_projection["real_estate"]["net"]),"rental income booked once")
	verify(int(sim.data["wallet"]) >= private_before,"profitable rented property pays player")
	verify(sim._valid_state(sim.data),"extended state passes validation")
	var serialized: Variant = JSON.parse_string(JSON.stringify(sim._save_state_payload()))
	verify(sim._valid_state(serialized["state"]),"properties survive versioned JSON save roundtrip")
	var bad: Dictionary = sim.data.duplicate(true)
	bad["properties"]["arcade"] = 99
	verify(not sim._valid_state(bad),"invalid ownership level rejected")
	var old: Dictionary = sim.data.duplicate(true)
	old.erase("properties")
	old.erase("personal_debt")
	old.erase("real_estate_revenue")
	verify(sim._valid_state(old),"legacy v4 save remains accepted")
	var restored: Dictionary = sim._upgrade_state(old)
	verify(restored.has("properties") and restored.has("personal_debt"),"legacy v4 state migrated")
	verify(not sim.repay_private_debt(250),"debt repayment refused if there is no debt")
	sim.data = sim.new_game()
	sim.data["properties"]["skyline"] = 3
	sim.data["wallet"] = 0
	sim.data["energy"] = 0
	sim.data["water"] = 0
	sim.data["unemployment"] = 100
	sim.advance_turn()
	verify(sim.data["wallet"] >= 0,"utility crisis cannot create negative private balance")
	verify(sim.data["personal_debt"] > 0,"unpaid rental loss becomes explicit personal debt")
	verify(sim._valid_state(sim.data),"economic crisis preserves save validity")
	sim.data = sim.new_game()
	verify(sim.citizen_available(0),"citizen has not yet been contacted")
	var before_reputation: int = int(sim.data["reputation"])
	verify(sim.respond_to_citizen(0,"forum","listen"),"listen to a resident")
	verify(int(sim.data["reputation"]) == before_reputation+1,"conversation changes reputation")
	verify(not sim.respond_to_citizen(0,"forum","listen"),"cannot farm reputation with the same resident")
	verify(not sim.respond_to_citizen(44,"forum","listen"),"invalid citizen ID blocked")
	verify(not sim.respond_to_citizen(1,"forum","bribe"),"unknown dialogue choices are rejected")
	verify(sim.respond_to_citizen(2,"housing","support"),"municipal help is a paid social action")
	verify(int(sim.data["treasury"]) == 925,"funding uses city treasury, not private money")
	verify(sim._valid_state(sim.data),"social interactions remain serializable")
	var restored_citizen: Dictionary = sim._upgrade_state(sim.data.duplicate(true))
	verify(restored_citizen.has("citizen_contacts"),"social progress survives data upgrade")
	print("GODOT PROPERTY/WEATHER: %d / %d PASS" % [checked-failures,checked])
	quit(0 if failures == 0 else 1)
