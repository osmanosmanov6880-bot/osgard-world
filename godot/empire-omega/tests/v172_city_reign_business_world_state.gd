extends SceneTree
## R174 source-truth locale and saved ownership, power and near-player LOD.
const OWNED=preload("res://scripts/city_reign_owned_business_world.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R174 LIVE PORTFOLIO FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var original: Dictionary=sim.data.duplicate(true)
	var simulated: Dictionary=sim.new_game()
	var snapshot: Dictionary=simulated.duplicate(true)
	var art: Node3D=OWNED.new()
	root.add_child(art)
	check(art.graphics_are_bounded() and art.get_child_count()==6,
		"one real original 3D object + one native label for 3 actual businesses")
	art.update_view(OWNED.ANCHORS["market_stall"])
	art.sync_state(simulated,"ru",sim.BUSINESSES)
	var before: Label3D=art.get_node("OwnedLabel_market_stall")
	check(before.text.contains("НЕ ПРИОБРЕТЁН") and
		(art.get_node("Owned_market_stall") as MeshInstance3D).material_override==art.get("matte"),
		"unowned original business never shows fake possession")
	simulated["businesses"]["market_stall"]=true
	art.sync_state(simulated,"en",sim.BUSINESSES)
	check(before.text.contains("OWNED BUSINESS") and before.text.contains("42") and
		(art.get_node("Owned_market_stall") as MeshInstance3D).material_override==art.get("brass"),
		"real purchased market signature reads actual original income=42")
	check((art.get_node("OwnedLabel_logistics") as Label3D).text.contains("NOT PURCHASED"),
		"unbought logistics company remains unavailable in the original city")
	for lang in ["ru","en","zh"]:
		art.sync_state(simulated,lang,sim.BUSINESSES)
		check(not before.text.is_empty(),
			"live economic state and original business names render in "+lang)
	art.update_power(22.0,100)
	check((art.get("brass") as StandardMaterial3D).emission_enabled,
		"owned business physically lights after dusk with actual city electricity")
	art.update_power(22.0,0)
	check(not (art.get("brass") as StandardMaterial3D).emission_enabled,
		"city-wide blackout switches off genuine original business sign glow")
	art.update_quality("low")
	check(not (art.get_node("Owned_market_stall") as Node3D).visible,
		"LOW/phone GPU tier removes 3D optional portfolios and labels")
	art.update_quality("cinematic")
	art.update_view(Vector3(-500,0,-500))
	check(not (art.get_node("Owned_market_stall") as Node3D).visible,
		"far-distance real 3D portfolio object culled at 112 metres")
	art.update_view(OWNED.ANCHORS["market_stall"])
	check((art.get_node("Owned_market_stall") as Node3D).visible,
		"near-player physical street owner marker reappears without reallocation")
	check(simulated["wallet"]==snapshot["wallet"] and
		simulated["treasury"]==snapshot["treasury"] and
		simulated["mission"]==snapshot["mission"] and
		original==sim.data,
		"read-only sign cannot buy goods, mint income or advance any original mission")
	art.queue_free()
	await process_frame
	print("CITY REIGN R174 OWNED ECONOMIC SIGNS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
