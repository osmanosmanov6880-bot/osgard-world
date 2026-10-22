extends SceneTree
## Godot 4 native runtime test. Must not be reported as PASS without engine execution.
var assertions := 0
var failures := 0

func _initialize() -> void:
	call_deferred("_run")

func check(value: bool, detail: String) -> void:
	assertions += 1
	if value:
		print("V09 PASS: " + detail)
	else:
		failures += 1
		push_error("V09 FAIL: " + detail)

func _run() -> void:
	var sim: Variant = root.get_node_or_null("GameState")
	if sim == null:
		push_error("GameState autoload unavailable")
		quit(2)
		return
	var career = load("res://scripts/career_progress.gd")
	var projects = load("res://scripts/civic_initiatives.gd")
	var vehicles = load("res://scripts/vehicle_catalog.gd")
	sim.data = sim.new_game()
	check(career.TRACKS.size() == 4,"four independent career paths")
	check(career.level(0) == 1,"level one begins at zero XP")
	check(career.level(100) == 2,"career levels up at 100 XP")
	check(career.level(1400) == 6,"highest track level")
	check(career.next_level_xp(900) == 1400,"next XP threshold")
	check(career.valid_xp(sim.data["career_xp"]),"new-game career schema")
	check(not career.award(sim.data,"unknown",100),"unknown career rejected")
	var old_cost: int = sim.get_build_cost("clinic")
	check(career.award(sim.data,"engineering",100),"engineering XP awarded")
	check(sim.get_build_cost("clinic") < old_cost,"engineering reduces construction cost")
	check(career.award(sim.data,"enterprise",100),"enterprise XP awarded")
	sim.data["businesses"]["market_stall"] = true
	check(sim.private_turn_income() > int(sim.BUSINESSES["market_stall"]["income"]),"enterprise changes real passive income")
	check(career.award(sim.data,"logistics",260),"logistics XP awarded")
	check(career.bonus(sim.data,"logistics") >= 0.08,"courier bonus increases with rank")

	sim.data = sim.new_game()
	check(projects.ORDER.size() == 8,"eight multi-turn city initiatives")
	check(projects.valid(sim.data),"initial initiative schema valid")
	check(not projects.can_start(sim.data,"wrong"),"unknown initiative rejected")
	var before_material: int = int(sim.data["inventories"]["materials"])
	var before_goods: int = int(sim.data["inventories"]["goods"])
	var before_treasury: int = int(sim.data["treasury"])
	check(sim.start_initiative("open_records"),"first initiative starts")
	check(int(sim.data["treasury"]) == before_treasury - 380,"initiative debits public budget")
	check(int(sim.data["inventories"]["materials"]) == before_material - 12,"initiative consumes real construction materials")
	check(int(sim.data["inventories"]["goods"]) == before_goods - 8,"initiative consumes consumer goods")
	check(not sim.start_initiative("open_records"),"initiative cannot start twice")
	check(sim.start_initiative("safe_crossings"),"a second initiative runs concurrently")
	check(not sim.start_initiative("community_park"),"action limit and queue apply")
	check(sim._valid_state(sim.data),"ongoing projects preserve save schema")
	var revenue_before: int = int(sim.forecast()["revenue"])
	check(sim.advance_turn(),"first project construction turn succeeds")
	check(int(sim.data["projects_active"]["open_records"]["remaining"]) == 1,"one remaining turn on first initiative")
	check(sim.advance_turn(),"second project construction turn succeeds")
	check(sim.data["projects_done"].has("open_records"),"initiative completes exactly on time")
	check(sim.data["projects_done"].has("safe_crossings"),"parallel initiative completes")
	check(not sim.data["projects_active"].has("open_records"),"completed job leaves queue")
	check(int(sim.forecast()["revenue"]) >= revenue_before + 8,"open budget raises city revenue")
	check(sim._valid_state(sim.data),"completed projects save successfully")
	var snapshot: Dictionary = sim._save_state_payload()
	var encoded: Variant = JSON.parse_string(JSON.stringify(snapshot))
	check(encoded is Dictionary and sim._valid_state(encoded["state"]),"JSON career/project roundtrip")

	sim.data = sim.new_game()
	sim.data["wallet"] = 10000
	sim.data["reputation"] = 100
	check(vehicles.valid_garage(sim.data["garage_status"]),"four vehicle condition records")
	check(sim.buy_vehicle("courier"),"buy vehicle without overwriting active car")
	sim.sync_vehicle_live(15.0,49.0,850.0)
	check(sim.select_vehicle("courier"),"switch to purchased courier")
	check(absf(float(sim.data["vehicle_fuel"]) - 100.0) < 0.01,"courier has independent tank")
	sim.sync_vehicle_live(43.0,81.0,240.0)
	check(sim.select_vehicle("compact"),"switch to prior hatchback")
	check(absf(float(sim.data["vehicle_fuel"]) - 15.0) < 0.01,"hatchback fuel preserved")
	check(absf(float(sim.data["vehicle_health"]) - 49.0) < 0.01,"hatchback damage preserved")
	check(absf(float(sim.data["vehicle_mileage"]) - 850.0) < 0.01,"hatchback mileage preserved")
	check(sim.select_vehicle("courier"),"switch back to courier")
	check(absf(float(sim.data["vehicle_fuel"]) - 43.0) < 0.01,"courier fuel preserved")
	check(sim._valid_state(sim.data),"multi-car garage passes schema validation")
	var previous: Dictionary = sim.data.duplicate(true)
	previous.erase("garage_status")
	previous.erase("career_xp")
	previous.erase("projects_active")
	previous.erase("projects_done")
	check(sim._valid_state(previous),"pre-v09 version-4 save accepted")
	var upgraded: Dictionary = sim._upgrade_state(previous)
	check(sim._valid_state(upgraded),"old save upgraded to new schema")
	check(absf(float(upgraded["garage_status"]["courier"]["fuel"]) - 43.0) < 0.01,"legacy car condition migrated to its selected slot")

	var landmarks_script = load("res://scripts/project_landmarks.gd")
	var landmarks: Node3D = landmarks_script.new()
	root.add_child(landmarks)
	landmarks.sync_projects(["open_records","clean_network"])
	check(landmarks.created.size() == 2,"two completed projects create two visible landmarks")
	landmarks.update_language("zh")
	check((landmarks.created["open_records"] as Node3D).get_child_count() >= 3,"landmark meshes and signs exist")
	landmarks.sync_projects(["clean_network"])
	check(landmarks.created.size() == 1,"reset removes obsolete landmarks")
	landmarks.queue_free()
	var signals_script = load("res://scripts/traffic_signal_controller.gd")
	var signals: Node3D = signals_script.new()
	root.add_child(signals)
	await process_frame
	check(signals.lights.size() == 16,"sixteen visual intersection signals")
	signals.elapsed = 0.0
	check(signals.permitted(Vector3(-156,0,-156),Vector3(1,0,0)),"east-west travel green at phase zero")
	check(not signals.permitted(Vector3(-156,0,-156),Vector3(0,0,1)),"north-south traffic red at phase zero")
	signals.elapsed = 13.0
	check(not signals.permitted(Vector3(-156,0,-156),Vector3(1,0,0)),"east-west stops after phase switch")
	check(signals.permitted(Vector3(-156,0,-156),Vector3(0,0,1)),"north-south moves after phase switch")
	signals.queue_free()
	print("V09 GODOT: %d / %d PASS" % [assertions-failures,assertions])
	quit(0 if failures == 0 else 1)
