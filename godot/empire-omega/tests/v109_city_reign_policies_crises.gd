extends SceneTree
## CITY REIGN C5: pure policy trade-offs + saved-crisis world consequence.
var checks: int = 0
var fails: int = 0

func check(ok: bool, detail: String) -> void:
	checks += 1
	if not ok:
		fails += 1
		push_error("CITY REIGN C5 FAIL: " + detail)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	if state == null:
		push_error("Missing real city state")
		quit(2)
		return
	var old_data: Dictionary = state.data.duplicate(true)
	var prior_lang: String = str(state.locale)
	state.data = state.new_game()
	var starting: Dictionary = state.data.duplicate(true)
	var impact: Script = load("res://scripts/city_reign_impact.gd") as Script
	var crisis_source: Script = load("res://scripts/city_reign_crisis_scene.gd") as Script
	check(impact != null and crisis_source != null,"actual native source scripts import")
	var baseline: Dictionary = state.CITY_ECONOMY.project(starting,state.BUILDINGS)
	for policy in ["industry","energy","welfare"]:
		var estimate: Dictionary = impact.policy_preview(starting,state.BUILDINGS,policy)
		check(str(estimate.get("course","")) == policy,
			"real non-current governance policy is forecast")
		var changed: Dictionary = starting.duplicate(true)
		changed["course"] = policy
		var hypothetical: Dictionary = state.CITY_ECONOMY.project(changed,state.BUILDINGS)
		check(int(estimate["net_delta"]) == int(hypothetical["net"]) - int(baseline["net"]) and
			int(estimate["energy_delta"]) == int(hypothetical["energy"]) - int(baseline["energy"]),
			"original next-turn economy agrees with displayed difference")
		check(int(estimate["trust_per_turn_delta"]) == int(hypothetical["trust_delta"]) - int(baseline["trust_delta"]),
			"real political trust trade-off, never invented")
		for lang in ["ru","en","zh"]:
			check(not impact.explain_policy(estimate,lang).is_empty() and
				impact.explain_policy(estimate,lang).contains(" "),
				"localized policy forecast is actual numeric text in " + lang)
	check(impact.policy_preview(starting,state.BUILDINGS,"balance").is_empty(),
		"same policy is not falsely listed as a decision")
	check(impact.policy_preview(starting,state.BUILDINGS,"broken").is_empty(),
		"unrecognized policy has no fake statistics")
	check(state.data == starting,"policy simulations do not change player money or story")
	var crisis: Node3D = crisis_source.new()
	root.add_child(crisis)
	crisis.sync_state(starting,"ru")
	check(str(crisis.get("current_id")) == "","no fake emergency when saved game is calm")
	for incident in crisis.INCIDENTS.keys():
		var snapshot: Dictionary = starting.duplicate(true)
		snapshot["incident"] = incident
		crisis.sync_state(snapshot,"ru")
		var active: Node3D = crisis.get("current_visual") as Node3D
		check(active != null and str(crisis.get("current_id")) == incident,
			"saved " + incident + " causes a true 3D city response")
		if active != null:
			check(active.get_child_count() >= 6 and
				active.find_children("*","CollisionShape3D",true,false).is_empty(),
				"emergency is visible geometry, never a physics blocker")
			crisis.sync_state(snapshot,"en")
			var first: Node3D = crisis.get("current_visual") as Node3D
			check(first == active,"language update does not duplicate world geometry")
			var sign: Label3D = crisis.get("sign") as Label3D
			check(sign != null and sign.text == str(crisis.INCIDENTS[incident]["en"]),
				"native warning text is correctly translated")
		crisis.sync_state(starting,"zh")
		check(str(crisis.get("current_id")) == "","resolving a crisis removes the actual alarm")
		check(snapshot["incident"] == incident and str(state.data["incident"]) == "",
			"3D crisis feedback cannot write to the saved city simulation")
	check(state.data == starting,"all crisis displays preserve original authoritative save")
	crisis.queue_free()
	await process_frame
	state.data = old_data
	state.locale = prior_lang
	print("CITY REIGN C5 real policy and emergencies: %d PASS %d FAIL" % [checks-fails,fails])
	quit(0 if fails == 0 else 1)
