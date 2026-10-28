extends SceneTree
## CITY REIGN E01 street acceptance on the REAL shipped 3D city scene.
## Physically position the authentic on-foot CharacterBody3D at a source
## proposal and interact with F's actual _interact handler: opens live native
## cabinet, selects correct district, never fabricates a mission or expense.
var passed: int = 0
var failed: int = 0

func check(value: bool, why: String) -> void:
	if value:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN E01 STREET FAIL: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	if sim == null:
		push_error("Missing original Godot GameState")
		quit(2)
		return
	var old_data: Dictionary = sim.data.duplicate(true)
	var old_lang: String = str(sim.locale)
	sim.data = sim.new_game()
	sim.locale = "en"
	var error: Error = change_scene_to_file("res://scenes/main.tscn")
	check(error == OK,"exact original shipped CITY REIGN scene loads")
	if error != OK:
		sim.data = old_data
		sim.locale = old_lang
		quit(1)
		return
	await process_frame
	await physics_frame
	var game: Node3D = current_scene as Node3D
	check(game != null,"authentic game scene instantiates")
	if game == null:
		sim.data = old_data
		sim.locale = old_lang
		quit(1)
		return
	var boards: Node3D = game.get("city_reign_proposals") as Node3D
	var player: CharacterBody3D = game.get("player") as CharacterBody3D
	var hud: CanvasLayer = game.get("hud") as CanvasLayer
	var car: CharacterBody3D = game.get("car") as CharacterBody3D
	check(boards != null and player != null and hud != null and car != null,
		"real on-foot player, car, 3D signs and original HUD exist")
	if boards != null and player != null and hud != null:
		var starting: Dictionary = sim.data.duplicate(true)
		check(boards.closest_proposal(Vector3.ZERO,1.0) == "",
			"out-of-range F cannot teleport to a distant civic investment")
		check((boards.get("boards") as Dictionary).size() == 2,
			"both district choices physically exist in the real 3D city")
		var housing: Node3D = (boards.get("boards") as Dictionary)["safe_crossings"]["root"]
		player.global_position = housing.global_position + Vector3(2.0,1.3,1.0)
		check(boards.closest_proposal(player.global_position,9.0) == "safe_crossings",
			"real walk-to target selects the nearby housing board")
		check(not bool(game.get("driving")),
			"the main game is in on-foot, not driving, mode")
		game.call("_interact")
		check(hud.is_strategy_open(),
			"actual F interaction opens the working native governance screen")
		check(str(sim.data["selected"]) == "housing",
			"real district selector follows housing proposal, not arbitrary task marker")
		check(int(sim.data["treasury"]) == int(starting["treasury"]) and
			int(sim.data["actions_left"]) == int(starting["actions_left"]) and
			int(sim.data["mission"]) == int(starting["mission"]),
			"reading a street proposal charges nothing and never grants fake XP")
		var choice: Button = (hud.get("strategy_contents") as Node).find_child(
			"CityReignPromise_safe_crossings",true,false) as Button
		check(choice != null and not choice.disabled and choice.custom_minimum_size.y >= 46.0,
			"physically opened cabinet exposes real accessible paid choice")
		hud.call("toggle_strategy")
		check(not hud.is_strategy_open(),"real open-world player can resume walking")
		var source: Script = load("res://scripts/city_reign_first_promise.gd") as Script
		var option: Dictionary = source.choice(sim.data,sim.BUILDINGS,"safe_crossings","en")
		check(int(option["cost"]) == 330,"existing real housing priority costs 330 game credits")
		if choice != null:
			# Old button remains accessible after cabinet closes, but the real
			# authoritative callback must still charge only once when clicked.
			choice.pressed.emit()
		check(sim.data["projects_active"].has("safe_crossings") and
			int(sim.data["treasury"]) == int(starting["treasury"])-330,
			"the original real Godot transaction accepts the housing investment")
		boards.sync_state(sim.data,"en")
		check(boards.closest_proposal(housing.global_position,9.0) == "",
			"paid proposal is removed from its physical street before construction")
		var open_records: Node3D = (boards.get("boards") as Dictionary)["open_records"]["root"]
		check(boards.closest_proposal(open_records.global_position,9.0) == "open_records",
			"unselected forum proposal remains interactable and independent")
		check(car != null and (game.get("ambient_cars") as Array).size() == 12 and
			(game.get("pedestrians") as Array).size() == 34,
			"real city retains traffic and residents through civic interaction")
	current_scene.queue_free()
	await process_frame
	sim.data = old_data
	sim.locale = old_lang
	print("CITY REIGN E01 real on-foot street choice: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed == 0 else 1)
