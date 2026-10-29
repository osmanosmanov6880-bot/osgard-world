extends SceneTree
## R174 true GameState.buy_business -> real 3D street visual after actual money debit.
const OWNED=preload("res://scripts/city_reign_owned_business_world.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R174 ORIGINAL PURCHASE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node_or_null("GameState")
	var old: Dictionary=sim.data.duplicate(true)
	var old_locale: String=sim.locale
	sim.data=sim.new_game()
	var wallet_before: int=int(sim.data["wallet"])
	var treasury_before: int=int(sim.data["treasury"])
	var mission_before: int=int(sim.data["mission"])
	var result: Error=change_scene_to_file("res://scenes/main.tscn")
	check(result==OK,"real original game 3D city loads")
	if result!=OK:
		sim.data=old
		sim.locale=old_locale
		quit(2)
		return
	await process_frame
	for i in range(8): await physics_frame
	var main: Node3D=current_scene as Node3D
	var world: Node3D=main.get("world")
	var art: Node3D=world.get("city_reign_business_portfolio")
	check(art!=null and art.graphics_are_bounded(),
		"new real 3D business portfolio installed in original WorldBuilder")
	check(art.get_child_count()==6 and (main.get("ambient_cars") as Array).size()==12 and
		(main.get("pedestrians") as Array).size()==34,
		"original drivable city, 12 traffic cars and 34 citizens unchanged")
	check((art.get("owned") as Dictionary).get("market_stall",true)==false,
		"new game's real market business starts unowned")
	var bought: bool=sim.buy_business("market_stall")
	await process_frame
	check(bought and int(sim.data["wallet"])==wallet_before-500 and
		bool(sim.data["businesses"]["market_stall"]) and
		int(sim.data["mission"])==mission_before,
		"only original buy_business charges 500 and marks ownership; no free mission completion")
	check((art.get("owned") as Dictionary).get("market_stall",false)==true,
		"original state_changed immediately propagates physical ownership into real 3D street")
	check((art.get_node("Owned_market_stall") as MeshInstance3D).material_override==art.get("brass"),
		"owned street sign actually changes PBR material after original paid purchase")
	check(int(sim.data["treasury"])==treasury_before and
		int(sim.private_turn_income())>=42,
		"private income comes from original authoritative economic engine, not sign")
	check(not sim.buy_business("market_stall"),
		"original economic safeguards prevent repeated purchase or double payout")
	world.apply_visual_budget("low")
	check(not (art.get_node("Owned_market_stall") as MeshInstance3D).visible,
		"phone-safe quality turns off optional ownership 3D art but preserves purchased state")
	world.update_language("zh")
	check((art.get_node("OwnedLabel_market_stall") as Label3D).text.contains("市场商铺"),
		"actual world business label follows existing multilingual language mode")
	current_scene.queue_free()
	await process_frame
	sim.data=old
	sim.locale=old_locale
	print("CITY REIGN R174 ACTUAL TRANSACTION AND 3D WORLD: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
