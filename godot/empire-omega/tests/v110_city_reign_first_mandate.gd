extends SceneTree
## CITY REIGN EPISODE 01: real, player-triggered first promise.
## All UI, World3D proposals, simulation payments and completion come from
## the original Godot code. No external UI mock, save migration or fake XP.
var successes: int = 0
var failures: int = 0

func check(ok: bool, reason: String) -> void:
	if ok:
		successes += 1
	else:
		failures += 1
		push_error("CITY REIGN E01 FAIL: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	var mission: Node = root.get_node_or_null("MissionManager")
	if sim == null or mission == null:
		push_error("Missing authentic city autoloads")
		quit(2)
		return
	var original: Dictionary = sim.data.duplicate(true)
	var original_language: String = str(sim.locale)
	sim.data = sim.new_game()
	var baseline: Dictionary = sim.data.duplicate(true)
	var promise: Script = load("res://scripts/city_reign_first_promise.gd") as Script
	var markers_source: Script = load("res://scripts/city_reign_promise_markers.gd") as Script
	var hud_source: Script = load("res://scripts/hud.gd") as Script
	check(promise != null and markers_source != null and hud_source != null,
		"original native scripts compile")
	check(str(promise.phase(sim.data)["id"]) == "arrival",
		"new player starts actual car-and-market prologue")
	for id in promise.CHOICES:
		var choice: Dictionary = promise.choice(sim.data,sim.BUILDINGS,id,"en")
		var config: Dictionary = sim.INITIATIVES.PROJECTS[id]
		check(bool(choice["allowed"]) and not bool(choice["active"]) and not bool(choice["completed"]),
			"authentic initial budget allows the optional " + id + " civic proposal")
		check(int(choice["cost"]) == int(config["cost"]) and
			int(choice["materials"]) == int(config["materials"]) and
			int(choice["turns"]) == int(config["turns"]),
			"real spending, stock and city-turn restrictions for " + id)
		check(not (choice["forecast"] as Dictionary).is_empty(),
			"exact existing city economic forecast for " + id)
		check(promise.button_text(choice,"en").contains(str(config["cost"])),
			"first choice button shows actual treasury cost for " + id)
	check(promise.choice(sim.data,sim.BUILDINGS,"fake_project","en").is_empty(),
		"unknown choices cannot grant resources")
	var stage: Dictionary = sim.data.duplicate(true)
	stage["mission"] = 3
	check(str(promise.phase(stage)["id"]) == "capital",
		"real original mission #3 yields business/turn advice")
	stage["mission"] = 4
	check(str(promise.phase(stage)["id"]) == "council",
		"real original mission #4 opens a council choice")
	for lang in ["ru","en","zh"]:
		var b: Dictionary = promise.briefing(stage,sim.BUILDINGS,lang)
		check(str(b["phase"]) == "council" and not str(b["heading"]).is_empty()
			and not str(b["hint"]).is_empty(),"three native languages explain optional choice: " + lang)
	check(sim.data == baseline,"read-only first-episode projections do not mutate saved campaign")

	var beacons: Node3D = markers_source.new()
	root.add_child(beacons)
	beacons.sync_state(sim.data,"ru")
	check((beacons.get("boards") as Dictionary).size() == 2,
		"two real physical street proposals exist at start")
	for id in promise.CHOICES:
		var data: Dictionary = (beacons.get("boards") as Dictionary)[id]
		var node: Node3D = data["root"]
		check(node.position == markers_source.LANDMARKS.POSITIONS[id],
			"native proposal sits at the real district project location: " + id)
		check(node.get_child_count() >= 6 and
			node.find_children("*","CollisionShape3D",true,false).is_empty(),
			"original 3D geometry remains non-colliding with traffic")
		for lang in ["ru","en","zh"]:
			beacons.sync_state(sim.data,lang)
			var label: Label3D = data["label"]
			check(label.text.contains(str(sim.INITIATIVES.PROJECTS[id][lang])) and
				label.text.contains("TAB"),"street proposal signage localizes in " + lang)
	var journal: CanvasLayer = hud_source.new()
	root.add_child(journal)
	for lang in ["ru","en","zh"]:
		sim.locale = lang
		journal.call("_refresh")
		var report: Dictionary = promise.briefing(sim.data,sim.BUILDINGS,lang)
		var title: Label = journal.get("city_reign_promise_title") as Label
		var details: Label = journal.get("city_reign_promise_body") as Label
		var tip: Label = journal.get("city_reign_promise_hint") as Label
		check(title != null and details != null and tip != null and
			title.text == str(report["heading"]) and details.text == str(report["body"])
			and tip.text == str(report["hint"]),
			"authentic HUD journal reads saved gameplay in " + lang)
	sim.locale = "ru"
	journal.call("_redraw_strategy")
	var buttons: Array = (journal.get("strategy_contents") as Node).find_children(
		"CityReignPromise_*","Button",true,false)
	check(buttons.size() == 2,"two native 46px clickable proposal buttons exist in real cabinet")
	check((buttons[0] as Button).custom_minimum_size.y >= 46.0,
		"first civic decision has accessible keyboard/touch target")
	var open_button: Button = (journal.get("strategy_contents") as Node).find_child(
		"CityReignPromise_open_records",true,false) as Button
	check(open_button != null and not open_button.disabled,
		"actual city cabinet makes first public-budget investment available")
	if open_button != null:
		open_button.pressed.emit()
	check(sim.data["projects_active"].has("open_records"),
		"click triggers real GameState civic initiative, not an inert demo")
	check(int(sim.data["treasury"]) == int(baseline["treasury"])-380 and
		int(sim.data["inventories"]["materials"]) == int(baseline["inventories"]["materials"])-12 and
		int(sim.data["actions_left"]) == int(baseline["actions_left"])-1,
		"authentic investment debits exact funds/materials/action")
	check(str(promise.phase(sim.data)["id"]) == "building" and
		int(promise.phase(sim.data)["remaining"]) == 2,
		"real first-episode state follows existing two-turn construction")
	beacons.sync_state(sim.data,"en")
	check((beacons.get("boards") as Dictionary).size() == 1 and
		not (beacons.get("boards") as Dictionary).has("open_records"),
		"selected street proposal disappears and makes way for actual scaffold")
	check(not sim.start_initiative("open_records"),"repeated approval cannot charge twice")
	check(int(sim.data["treasury"]) == int(baseline["treasury"])-380,
		"duplicate press cannot double debit a chosen project")
	check(sim.advance_turn(),"first real city turn can advance the building")
	check(int(promise.phase(sim.data)["remaining"]) == 1,
		"construction advances by one actual city turn")
	check(sim.advance_turn(),"second real city turn completes first promise")
	check(sim.data["projects_done"].has("open_records") and
		str(promise.phase(sim.data)["id"]) == "delivered",
		"completion is backed by authoritative existing projects_done save state")
	var delivered: Dictionary = promise.briefing(sim.data,sim.BUILDINGS,"en")
	check(delivered["body"].contains("40 new jobs") and
		str(delivered["chosen"]) == "open_records",
		"completed civic promise names real permanent project jobs")
	var saved_copy: Dictionary = sim.data.duplicate(true)
	beacons.sync_state(saved_copy,"zh")
	check((beacons.get("boards") as Dictionary).size() == 1,
		"loading an authoritative completed save does not restore a phantom proposal")
	beacons.sync_state(baseline,"ru")
	check((beacons.get("boards") as Dictionary).size() == 2,
		"resetting to old save reconstructs both optional street proposals")
	check(sim.data == saved_copy,"visual reload never changes original saved funds or timeline")
	sim.data = sim.new_game()
	check(sim.start_initiative("safe_crossings"),"second path supports real safe-crossings investment")
	check(str(promise.phase(sim.data)["id"]) == "building" and
		str(promise.phase(sim.data)["chosen"]) == "safe_crossings",
		"same original simulation supports alternate district priority")
	beacons.sync_state(sim.data,"ru")
	check((beacons.get("boards") as Dictionary).size() == 1,
		"alternate district choice removes only the selected proposal")
	journal.queue_free()
	beacons.queue_free()
	await process_frame
	sim.data = original
	sim.locale = original_language
	print("CITY REIGN E01 real playable promise: %d PASS %d FAIL" % [successes,failures])
	quit(0 if failures == 0 else 1)
