extends SceneTree
## R64: true GameState transactions before MissionManager mission awards.
## Every scenario uses an authored mission stage and an original economy method;
## these are native ENGINE transaction tests, not a full player/UI playthrough.
const MOBILITY = preload("res://scripts/city_mobility.gd")

var passed := 0
var failed := 0

func verify(condition: bool, reason: String) -> void:
	if condition:
		passed += 1
	else:
		failed += 1
		push_error("R64 REAL MISSION TRANSACTION FAILED: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _perform_real_transaction(game: Node, state: Dictionary, kind: String) -> bool:
	match kind:
		"business":
			return bool(game.call("buy_business", "market_stall"))
		"advance_turn":
			return bool(game.call("advance_turn"))
		"build":
			return bool(game.call("build", "clinic"))
		"research":
			return bool(game.call("research", "grid"))
		"property":
			return bool(game.call("buy_property", "arcade"))
		"renovation":
			return bool(game.call("renovate_property", "arcade"))
		"transfer":
			return bool(game.call("transfer_to_city", 250))
		"set_course":
			return bool(game.call("set_course", "welfare"))
		"resolve_incident":
			return bool(game.call("resolve_incident", true))
		"trade":
			return bool(game.call("trade_goods", "materials", false, 10))
		"vehicle_buy":
			return bool(game.call("buy_vehicle", "courier"))
		"vehicle_select":
			return bool(game.call("select_vehicle", "courier"))
		"initiative_start":
			return bool(game.call("start_initiative", "open_records"))
		"road_repair":
			var closures: Array[Dictionary] = MOBILITY.active_incidents(state)
			return not closures.is_empty() and bool(game.call("repair_road", str(closures[0]["id"])))
		"road_maintenance":
			return bool(game.call("maintain_roads"))
	return false

func _run() -> void:
	var game: Node = root.get_node_or_null("GameState")
	var missions: Node = root.get_node_or_null("MissionManager")
	verify(game != null and missions != null, "original GameState and MissionManager autoloads exist")
	if game == null or missions == null:
		quit(1)
		return

	var original_data: Dictionary = game.get("data").duplicate(true)
	var original_locale: String = str(game.get("locale"))
	game.set("locale", "ru")
	var scenarios: Array[Dictionary] = [
		{"stage":2, "id":"business"},
		{"stage":3, "id":"advance_turn"},
		{"stage":6, "id":"build"},
		{"stage":7, "id":"research"},
		{"stage":8, "id":"property"},
		{"stage":9, "id":"renovation"},
		{"stage":10, "id":"transfer"},
		{"stage":11, "id":"set_course"},
		{"stage":18, "id":"resolve_incident"},
		{"stage":21, "id":"trade"},
		{"stage":22, "id":"vehicle_buy"},
		{"stage":23, "id":"vehicle_select"},
		{"stage":28, "id":"initiative_start"},
		{"stage":32, "id":"road_repair"},
		{"stage":33, "id":"road_maintenance"}
	]
	var ledger: Array[Dictionary] = []
	for scenario in scenarios:
		var stage: int = int(scenario["stage"])
		var action: String = str(scenario["id"])
		var state: Dictionary = game.call("new_game")
		# Disposable, affluent fixture isolates each transaction's actual
		# rules; this explicitly does NOT prove start-to-finish affordability.
		state["mission"] = stage
		state["wallet"] = 5000
		state["treasury"] = 5000
		state["science"] = 500
		state["reputation"] = 75
		state["actions_left"] = 2
		state["inventories"]["materials"] = 200
		state["inventories"]["goods"] = 200
		if action == "renovation":
			state["properties"]["arcade"] = 1
		elif action == "vehicle_select":
			state["vehicle_owned"]["courier"] = true
		elif action == "resolve_incident":
			state["incident"] = "fire"
		game.set("data", state)
		var original_mission: Dictionary = missions.call("get_mission")
		verify(str(original_mission.get("id","")) == action,
			"stage %d is the actual authored %s mission" % [stage,action])
		verify(not bool(missions.call("register_action","invalid-r64-action")),
			"stage %d cannot advance using an invented event" % stage)
		verify(int(state["mission"]) == stage,
			"stage %d remains unchanged without the real transaction" % stage)

		var before_wallet: int = int(state["wallet"])
		var before_treasury: int = int(state["treasury"])
		var transaction_ok: bool = _perform_real_transaction(game,state,action)
		verify(transaction_ok, "stage %d executes original GameState.%s transaction" % [stage,action])
		var changed: Dictionary = game.get("data")
		var post_transaction_wallet: int = int(changed["wallet"])
		var post_transaction_treasury: int = int(changed["treasury"])
		if action == "road_repair":
			verify(int(changed["roads_repaired_total"]) == 1 and changed["roads_cleared"].size() == 1,
				"road repair really clears one blocked edge without double credit")
		if action == "initiative_start":
			verify(changed["projects_active"].has("open_records"),
				"new civic initiative really enters the project queue")
		if action == "vehicle_buy":
			verify(bool(changed["vehicle_owned"]["courier"]) and post_transaction_wallet < before_wallet,
				"real garage purchase costs private wallet money")
		if action == "research":
			verify(bool(changed["technologies"]["grid"]) and int(changed["science"]) == 455,
				"research consumes science and changes real technology state")
		if action == "build":
			verify(int(changed["buildings"]["clinic"]) == 1 and post_transaction_treasury < before_treasury,
				"construction consumes municipal funds and changes the city")
		if action == "trade":
			verify(int(changed["market_orders"]) == 1 and changed["market_history"].size() == 1,
				"market order is persisted before any quest credit")
		if action == "transfer":
			verify(post_transaction_wallet == before_wallet - 250 and post_transaction_treasury == before_treasury + 250,
				"investing moves exactly 250 credits from private wallet into city budget")
		verify(bool(game.call("_valid_state", changed)),
			"stage %d actual transaction produces save-valid real state" % stage)
		var earned: int = int(original_mission.get("reward",0))
		var completed: bool = bool(missions.call("register_action",action)) if transaction_ok else false
		verify(completed, "stage %d accepts only its completed actual transaction" % stage)
		var after: Dictionary = game.get("data")
		verify(int(after["mission"]) == stage + 1,
			"stage %d advances exactly once" % stage)
		verify(int(after["wallet"]) == post_transaction_wallet + (earned if completed else 0),
			"stage %d awards exact quest credits in addition to actual purchase/costs" % stage)
		verify(not bool(missions.call("register_action",action)),
			"stage %d cannot be double-awarded by reusing the same event" % stage)
		verify(bool(game.call("_valid_state",after)),
			"stage %d remains valid for authentic game saves after payout" % stage)
		ledger.append({
			"mission_index":stage,
			"action":action,
			"actual_transaction_passed":transaction_ok,
			"before_wallet":before_wallet,
			"post_transaction_wallet":post_transaction_wallet,
			"post_mission_wallet":int(after["wallet"]),
			"before_treasury":before_treasury,
			"post_transaction_treasury":post_transaction_treasury,
			"reward":earned,
			"mission_after":int(after["mission"])
		})

	var evidence: Dictionary = {
		"schema":"empire-omega-r64-real-transactions-v1",
		"engine":"Godot 4.4.1",
		"source_path":"godot/empire-omega",
		"real_gamestate_transactions":scenarios.size(),
		"transaction_results":ledger,
		"checks_passed":passed,
		"checks_failed":failed,
		"simulated_economy_fixture":true,
		"human_40_mission_playthrough_attested":false,
		"published_browser_attested":false,
		"physical_hardware_attested":false,
		"production_release_authorized":false
	}
	var path: String = ProjectSettings.globalize_path("res://tests/r64-original-transactions-evidence.json")
	var output: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	verify(output != null,"Godot persists measured native transaction ledger")
	if output != null:
		evidence["checks_passed"] = passed
		evidence["checks_failed"] = failed
		output.store_string(JSON.stringify(evidence,"  "))
		output.close()
	game.set("data",original_data)
	game.set("locale",original_locale)
	await process_frame
	print("EMPIRE OMEGA R64 REAL ECONOMY: %d passed, %d failed; %d actual transactions" % [passed,failed,scenarios.size()])
	quit(0 if failed == 0 else 1)
