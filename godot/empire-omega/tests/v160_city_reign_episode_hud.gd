extends SceneTree
## R170 original player HUD with real native journal and zero extra overlays.
const HUD=preload("res://scripts/hud.gd")
const EP=preload("res://scripts/city_reign_episode_sequence.gd")
var passed:=0
var failed:=0
func check(ok: bool,reason: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R170 REAL JOURNAL FAIL: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var contracts: Node=root.get_node_or_null("ContractManager")
	var old: Dictionary=sim.data.duplicate(true)
	var old_lang: String=str(sim.locale)
	sim.data=sim.new_game()
	var hud: CanvasLayer=HUD.new()
	root.add_child(hud)
	for lang in ["ru","en","zh"]:
		sim.locale=lang
		for stage in range(7):
			sim.data["mission"]=stage
			hud.call("_refresh")
			var projection: Dictionary=EP.first_six(sim.data,contracts.current_offer(),
				contracts.POSITIONS,lang)
			var progress: Label=hud.get("r170_episode_progress")
			var direction: Label=hud.get("r170_episode_direction")
			var commands: Label=hud.get("r170_episode_controls")
			check(progress!=null and direction!=null and commands!=null,
				"native Godot labels exist in original expandable journal")
			check(progress.text.contains(str(projection["progress"])) and
				direction.text.contains(str(projection["title"])) and
				commands.text==str(projection["hint"]),
				"read-only localized original mission state drives actual UI "+lang+"/"+str(stage))
	var detail: Button=hud.get("objective_details_button") as Button
	check(detail!=null and detail.custom_minimum_size.y>=46.0,
		"phone and keyboard keep original accessible 46px journal action")
	var scene: Control=hud.get("root") as Control
	check(scene!=null and hud.get("journal_panel")!=null,
		"real HUD from exact saved game, not separate screenshot")
	hud.queue_free()
	await process_frame
	sim.locale=old_lang
	sim.data=old
	print("CITY REIGN R170 ORIGINAL JOURNAL: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
