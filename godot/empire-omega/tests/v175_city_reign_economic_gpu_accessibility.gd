extends SceneTree
## R175: native source artifacts, the real GPU and Reduced Motion budgets.
const PULSE=preload("res://scripts/city_reign_live_economy_pulse.gd")
const ID=preload("res://scripts/city_reign_district_identity.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R175 REAL GPU CITY PULSE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var saved: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var state: Dictionary=sim.new_game()
	var original: Dictionary=state.duplicate(true)
	var node: Node3D=PULSE.new()
	root.add_child(node)
	check(node.geometry_is_bounded() and node.get_child_count()==12,
		"four real source stations, four single Mesh rotors and four labels only")
	node.update_view(PULSE.SITE_ANCHORS["forum"])
	check(node.visible_sites==1 and node.is_processing(),
		"real near-player city renders and animates only one visited active source station")
	node.set_reduced_motion(true)
	check(not node.is_processing(),
		"Reduced Motion actually disables all optional per-frame rotation")
	var original_rotation: float=(node.rotors["forum"] as Node3D).rotation.z
	await process_frame
	check(is_equal_approx(original_rotation,(node.rotors["forum"] as Node3D).rotation.z),
		"animation does not sneak through disabled Reduced Motion")
	node.sync_state(state,"ru")
	check((node.captions["forum"] as Label3D).text.contains("72%") and
		(node.captions["housing"] as Label3D).text.contains("80"),
		"real saved stability percent and market stock units, no invented percentages")
	state["inventories"]["goods"]=0
	state["energy"]=0
	node.sync_state(state,"en")
	check((node.captions["housing"] as Label3D).text.contains("LOW LEVEL") and
		node.last_snapshot["housing"]["normalized"]==0.0,
		"true empty saved goods stock visibly halts 3D source meter")
	node.update_ambience(22.0,0)
	check(not (node.finishes["aqueduct"] as StandardMaterial3D).emission_enabled,
		"actual zero city electricity prevents decorative emission")
	node.update_ambience(22.0,100)
	check((node.finishes["aqueduct"] as StandardMaterial3D).emission_enabled,
		"real municipal power makes physically rendered metal emissive at night")
	node.set_quality("low")
	check(node.visible_sites==0 and not node.is_processing(),
		"LOW physically hides all 12 new render nodes and pauses rotor CPU")
	for id in PULSE.SITES:
		check(not (node.foundations[id] as Node3D).visible and
			not (node.rotors[id] as Node3D).visible and
			not (node.captions[id] as Node3D).visible,
			"low/mobile tier cannot waste GPU on 3D economic sculpture: "+id)
	node.set_quality("cinematic")
	node.set_reduced_motion(false)
	node.update_view(PULSE.SITE_ANCHORS["forum"])
	check(node.is_processing() and node.visible_sites==1,
		"source rotor resume occurs only within genuine camera proximity")
	check(state["wallet"]==original["wallet"] and
		state["mission"]==original["mission"] and
		sim.get("data")==saved and node.geometry_is_bounded(),
		"visual economy consumes neither fake rewards nor source player state")
	node.queue_free()
	await process_frame
	print("CITY REIGN R175 ORIGINAL GPU AND ACCESSIBILITY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
