extends SceneTree
## R171 actual Godot HUD renders contextual genuine source guidance.
const COACH=preload("res://scripts/city_reign_episode_live_coach.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R171 JOURNAL HUD FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var old: Dictionary=sim.data.duplicate(true)
	var old_locale: String=str(sim.locale)
	sim.data=sim.new_game()
	var source: Variant=load("res://scripts/hud.gd")
	check(source is Script and source.can_instantiate(),
		"true original HUD loads only after required runtime autoloads")
	if not (source is Script and source.can_instantiate()):
		sim.data=old
		quit(2)
		return
	var hud: CanvasLayer=source.new()
	root.add_child(hud)
	var context: Label=hud.get("r171_live_context") as Label
	var journal: PanelContainer=hud.get("journal_panel") as PanelContainer
	check(context!=null and journal!=null,
		"R171 actual original scrollable H journal now owns exactly one new 15px label")
	check(not journal.visible and hud.get_child_count()>0,
		"original CITY REIGN HUD remains unchanged when journal closed")
	hud.call("update_world_context",Vector3(-118,1.3,-104),Vector3(-120,1.3,-104),
		Vector3(-120,0,-104),false,0.0,100.0,"")
	check(context.text=="","closed journal does not allocate live coaching strings or overlays")
	hud.call("toggle_field_journal")
	check(journal.visible and
		(hud.get("objective_details_button") as Button).custom_minimum_size.y>=46.0,
		"actual 46px keyboard/touch button opens source H journal")
	for lang in ["ru","en","zh"]:
		sim.locale=lang
		sim.data["mission"]=0
		hud.call("_refresh")
		hud.call("update_world_context",Vector3(-118,1.3,-104),
			Vector3(-120,1.3,-104),Vector3(-120,0,-104),false,0.0,100.0,"")
		check(context.text==COACH.explain("enter_car",lang),
			"native original HUD shows actual nearby E in "+lang)
		sim.data["mission"]=1
		hud.call("_refresh")
		hud.call("update_world_context",Vector3(130,1.3,-130),
			Vector3(130,1.3,-130),Vector3(130,0,-130),true,0.5,100.0,"market")
		check(context.text==COACH.explain("deliver_market",lang),
			"native HUD shows source market F at actual market in "+lang)
	# A source-safe hidden panel must not mutate guidance on 20Hz world ticks.
	hud.call("toggle_field_journal")
	var prior: String=context.text
	sim.data["mission"]=3
	hud.call("update_world_context",Vector3(-118,1.3,-104),Vector3(-120,1.3,-104),
		Vector3(-130,0,-130),false,0.0,100.0,"")
	check(not journal.visible and context.text==prior,
		"closed journal incurs no live-context UI redraws")
	check(sim.data["mission"]==3 and sim.data["wallet"]==600,
		"real mission and money unaffected by language or HUD redraws")
	hud.queue_free()
	await process_frame
	sim.data=old
	sim.locale=old_locale
	print("CITY REIGN R171 NATIVE HUD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
