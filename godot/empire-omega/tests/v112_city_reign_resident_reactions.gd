extends SceneTree
## CITY REIGN E01: every real citizen dialog responds to saved civic actions.
var succeeded: int = 0
var failed: int = 0

func check(ok: bool, detail: String) -> void:
	if ok:
		succeeded += 1
	else:
		failed += 1
		push_error("CITY REIGN E01 CITIZENS FAIL: " + detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	if sim == null:
		quit(2)
		return
	var old_data: Dictionary = sim.data.duplicate(true)
	var old_locale: String = str(sim.locale)
	sim.data = sim.new_game()
	var script: Script = load("res://scripts/city_reign_resident_reactions.gd") as Script
	check(script != null,"original local-native neighborhood dialogue script loads")
	var baseline: Dictionary = sim.data.duplicate(true)
	check(script.feedback(baseline,"impossible","en").is_empty(),
		"unrecognized district never fabricates residents")
	for lang in ["ru","en","zh"]:
		for district in script.DISTRICTS:
			var ordinary: Dictionary = script.feedback(baseline,district,lang)
			check(not ordinary.is_empty() and not str(ordinary["comment"]).is_empty(),
				"all 4 real city districts have grounded dialogue in " + lang)
			check(ordinary["phase"] == "pending" if ["forum","housing"].has(district) else ordinary["phase"] == "ordinary",
				"dialogue phase comes only from actual civic project state: " + district)
	for id in ["open_records","safe_crossings"]:
		var cfg: Dictionary = sim.INITIATIVES.PROJECTS[id]
		var district: String = str(cfg["district"])
		var temp: Dictionary = baseline.duplicate(true)
		temp["projects_active"][id] = {"remaining":2}
		for lang in ["ru","en","zh"]:
			var voice: Dictionary = script.feedback(temp,district,lang)
			check(str(voice["phase"]) == "building" and str(voice["comment"]).contains("2"),
				"residents recognize actual 2-turn construction in " + lang + " at " + id)
		temp["projects_active"].erase(id)
		temp["projects_done"].append(id)
		for lang in ["ru","en","zh"]:
			var voice: Dictionary = script.feedback(temp,district,lang)
			check(str(voice["phase"]) == "fulfilled" and
				str(voice["comment"]).contains(str(cfg[lang])),
				"residents recognize completed real-world district building in " + lang)
	var crisis: Dictionary = baseline.duplicate(true)
	crisis["incident"] = "drought"
	check(script.feedback(crisis,"forum","en")["comment"].contains("emergency"),
		"emergency concerns are based on actual saved city incident")
	check(sim.data == baseline,"read-only resident dialogue never creates hidden story rewards")
	var hud_script: Script = load("res://scripts/hud.gd") as Script
	var hud: CanvasLayer = hud_script.new()
	root.add_child(hud)
	for id in ["open_records","safe_crossings"]:
		var district: String = str(sim.INITIATIVES.PROJECTS[id]["district"])
		sim.data = sim.new_game()
		sim.data["projects_done"].append(id)
		for lang in ["ru","en","zh"]:
			sim.locale = lang
			hud.show_citizen(0,district)
			var popup: ConfirmationDialog = hud.get("citizen_popup") as ConfirmationDialog
			check(popup != null and popup.dialog_text.contains(str(sim.INITIATIVES.PROJECTS[id][lang])),
				"ACTUAL native NPC popup contains completed project reaction: " + lang)
			popup.hide()
			await process_frame
	check(int(sim.data["wallet"]) == 600 and int(sim.data["mission"]) == 0,
		"real dialogue displays do not advance original mission or spend money")
	hud.queue_free()
	await process_frame
	sim.data = old_data
	sim.locale = old_locale
	print("CITY REIGN E01 real resident reactions: %d PASS %d FAIL" % [succeeded,failed])
	quit(0 if failed == 0 else 1)
