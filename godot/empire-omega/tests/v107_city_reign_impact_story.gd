extends SceneTree
## CITY REIGN C2: real native Godot calculations, UI and immutable save data.
var pass_count: int = 0
var fail_count: int = 0

func check(value: bool, reason: String) -> void:
	if value:
		pass_count += 1
	else:
		fail_count += 1
		push_error("CITY REIGN C2 FAIL: " + reason)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var sim: Node = root.get_node_or_null("GameState")
	check(sim != null,"the authoritative city state is available")
	if sim == null:
		quit(2)
		return
	var old_data: Dictionary = sim.data.duplicate(true)
	var old_lang: String = str(sim.locale)
	sim.data = sim.new_game()
	var impact: Script = load("res://scripts/city_reign_impact.gd") as Script
	var story: Script = load("res://scripts/city_reign_story.gd") as Script
	check(impact != null and story != null,"impact and narrative run as original Godot scripts")
	var before: Dictionary = sim.data.duplicate(true)
	var baseline: Dictionary = sim.CITY_ECONOMY.project(before,sim.BUILDINGS)
	for project_id in sim.INITIATIVES.ORDER:
		var reading: Dictionary = impact.preview(before,sim.BUILDINGS,project_id)
		var definition: Dictionary = sim.INITIATIVES.PROJECTS[project_id]
		check(not reading.is_empty() and str(reading["id"]) == project_id,
			"all eight real municipal initiatives have a grounded forecast: " + project_id)
		check(int(reading["cost"]) == int(definition["cost"]) and
			int(reading["duration"]) == int(definition["turns"]),
			"actual costs and durations, no fabricated values: " + project_id)
		check(int(reading["jobs_delta"]) == int(definition["jobs"]),
			"exact job changes from existing city economy: " + project_id)
		check(int(reading["trust_delta"]) == int(definition["trust"]),
			"real completion trust reward: " + project_id)
		var alternate: Dictionary = before.duplicate(true)
		alternate["projects_done"].append(project_id)
		var district: String = str(definition["district"])
		var idx: int = sim.INITIATIVES.DISTRICTS.find(district)
		alternate["trust"][idx] = mini(100,int(alternate["trust"][idx]) + int(definition["trust"]))
		var projected: Dictionary = sim.CITY_ECONOMY.project(alternate,sim.BUILDINGS)
		check(int(reading["net_delta"]) == int(projected["net"]) - int(baseline["net"]) and
			int(reading["district_delta"]) == int(projected["district_scores"][district]) - int(baseline["district_scores"][district]),
			"exact same-turn financial/quality comparison: " + project_id)
		for lang in ["ru","en","zh"]:
			check(not impact.explain(reading,lang).is_empty(),
				"localized honest forecast for " + project_id + " in " + lang)
	check(sim.data == before,"eight projections never touch original GameState")
	check(impact.preview(before,sim.BUILDINGS,"undefined").is_empty(),
		"unknown project has no fabricated forecast")
	var completed: Dictionary = before.duplicate(true)
	completed["projects_done"].append("open_records")
	check(impact.preview(completed,sim.BUILDINGS,"open_records").is_empty(),
		"completed work is never offered as a new project")
	for lang in ["ru","en","zh"]:
		var first: Dictionary = story.briefing(before,lang)
		check(int(first["act"]) == 0 and int(first["mission"]) == 0 and
			int(first["weakest_score"]) >= 0 and not str(first["heading"]).is_empty(),
			"authored first act and live citizen-quality pulse in " + lang)
	var advanced: Dictionary = before.duplicate(true)
	advanced["mission"] = 10
	check(int(story.briefing(advanced,"en")["act"]) == 1,"existing mission progress opens act II")
	advanced["mission"] = 29
	advanced["incident"] = "blackout"
	check(int(story.briefing(advanced,"en")["act"]) == 2 and
		str(story.briefing(advanced,"en")["pulse"]).contains("ACTIVE CRISIS"),
		"actual saved city crisis changes act III briefing")
	advanced["mission"] = 40
	check(int(story.briefing(advanced,"en")["act"]) == 3,"40 old missions give epilogue")
	check(sim.data == before,"pure narrative never changes rewards or story saves")
	var hud_script: Script = load("res://scripts/hud.gd") as Script
	check(hud_script != null and hud_script.can_instantiate(),"real native HUD imports with story")
	if hud_script != null and hud_script.can_instantiate():
		var hud: CanvasLayer = hud_script.new()
		root.add_child(hud)
		for lang in ["ru","en","zh"]:
			sim.locale = lang
			hud.call("_refresh")
			var title: Label = hud.get("city_reign_act_label") as Label
			var body: Label = hud.get("city_reign_story_label") as Label
			var pulse: Label = hud.get("city_reign_pulse_label") as Label
			check(title != null and body != null and pulse != null and
				title.text == str(story.briefing(before,lang)["heading"]) and
				body.text == str(story.briefing(before,lang)["copy"]) and
				pulse.text == str(story.briefing(before,lang)["pulse"]),
				"real existing city journal reflects localized source state: " + lang)
		sim.locale = "en"
		hud.call("_redraw_strategy")
		var found: bool = false
		for label in (hud.get("strategy_contents") as Node).find_children("*","Label",true,false):
			if (label as Label).text.contains("AFTER DELIVERY") and (label as Label).text.contains("jobs"):
				found = true
		check(found,"native cabinet renders real project completion forecast")
		hud.queue_free()
		await process_frame
	check(sim.data == before,"opening game UI cannot generate income or missions")
	sim.data = old_data
	sim.locale = old_lang
	print("CITY REIGN C2 impact and story: %d PASS %d FAIL" % [pass_count,fail_count])
	quit(0 if fail_count == 0 else 1)
