extends SceneTree
## Native Godot acceptance test. Requires installed Godot 4.4.1; not a Python emulation.
const JOBS = preload("res://scripts/neighborhood_jobs.gd")
var assertions := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	assertions += 1
	if not ok:
		failures += 1
		push_error("NEIGHBORHOOD FAILED: " + label)
	else:
		print("NEIGHBORHOOD OK: " + label)

func _initialize() -> void:
	call_deferred("run_tests")

func run_tests() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	if sim == null:
		push_error("GameState autoload is missing")
		quit(2)
		return
	var catalog: Array = JOBS.catalog()
	check(catalog.size() == 12,"twelve translated jobs load from JSON")
	for entry in catalog:
		check(JOBS._valid_entry(entry),"valid: " + str(entry["id"]))
	for region in JOBS.REGIONS:
		var fresh: Dictionary = sim.new_game()
		var offered: Dictionary = JOBS.offer(fresh,0,region)
		check(not offered.is_empty(),"district offer: " + region)
		check(JOBS.accept(fresh,0,region),"accept resident's request")
		check(JOBS.valid(fresh),"accepted-state save validates")
		check(not JOBS.accept(fresh,0,region),"cannot accept duplicate request")
		var pickup: String = str(offered["pickup"])
		var destination: String = str(offered["dropoff"])
		check(JOBS.interact(fresh,pickup,false,false,0.0) == "vehicle_near","park near supplier")
		check(JOBS.interact(fresh,pickup,true,false,2.0) == "stop","stop car for loading")
		var wallet_start: int = int(fresh["wallet"])
		check(JOBS.interact(fresh,pickup,true,false,0.0) == "collected","supplies purchased")
		check(int(fresh["wallet"]) == wallet_start-int(offered["supply_cost"]),"personal spending recorded")
		check(JOBS.valid(fresh),"loaded job passes state validation")
		check(JOBS.interact(fresh,destination,true,true,0.0) == "distance","no reward without travel")
		fresh["vehicle_mileage"] = float(offered["min_drive"])-0.01
		check(JOBS.interact(fresh,destination,true,true,0.0) == "distance","short route cannot finish")
		fresh["vehicle_mileage"] = float(offered["min_drive"])+0.1
		check(JOBS.interact(fresh,destination,true,false,0.0) == "wrong_vehicle","must arrive in vehicle")
		check(JOBS.interact(fresh,destination,true,true,2.0) == "stop","must stop for unloading")
		check(JOBS.interact(fresh,destination,true,true,0.0) == "completed","deliver job and receive reward")
		check(int(fresh["wallet"]) == wallet_start-int(offered["supply_cost"])+int(offered["reward"]),"exact money conserved for one contract")
		check(int(fresh["neighborhood_completed"]) == 1,"completed counter only once")
		check(JOBS.interact(fresh,destination,true,true,0.0) == "not_active","cannot collect the same reward again")
		check(JOBS.valid(fresh) and sim._valid_state(fresh),"entire save validates after delivery")
		var json_copy: Variant = JSON.parse_string(JSON.stringify(fresh))
		check(json_copy is Dictionary and sim._valid_state(json_copy),"JSON round trip validates")
		var legacy: Dictionary = sim.new_game()
		for field in ["neighborhood_active","neighborhood_history","neighborhood_completed","neighborhood_last_turn"]:
			legacy.erase(field)
		check(sim._valid_state(legacy),"previous v4 snapshot remains accepted")
		var restored: Dictionary = sim._upgrade_state(legacy)
		check(JOBS.valid(restored),"previous snapshot receives neutral defaults")
	var failing: Dictionary = sim.new_game()
	check(JOBS.accept(failing,2,"forum"),"accept expiring request")
	failing["turn"] = int(failing["neighborhood_active"]["due_turn"])+1
	check(JOBS.expire(failing) != "","expired request consumed")
	check(JOBS.expire(failing) == "","no duplicate expiration")
	check(int(failing["neighborhood_history"][0]["reward"]) == 0,"no payout on expiration")
	check(sim._valid_state(failing),"expired-state save validates")
	var corrupt: Dictionary = sim.new_game()
	check(JOBS.accept(corrupt,0,"forum"),"accept for tampering validation")
	corrupt["neighborhood_active"]["id"] = "../not-a-job"
	check(not sim._valid_state(corrupt),"reject invalid job identifier in save")
	print("Native neighborhood acceptance: %d checks, %d failures" % [assertions,failures])
	quit(0 if failures == 0 else 1)
