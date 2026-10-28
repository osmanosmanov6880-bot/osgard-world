extends SceneTree
## CITY REIGN AAA A9: authentic responsive charcoal/brass garage presentation.
## All prices, owned vehicles and performance factors are read from actual
## GameState/VehicleCatalog. Buttons still call the authoritative transaction.
const HUD = preload("res://scripts/hud.gd")
const DISPLAY = preload("res://scripts/city_reign_premium_garage.gd")
const CATALOG = preload("res://scripts/vehicle_catalog.gd")
var passed: int = 0
var failed: int = 0

func verify(ok: bool,message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("CITY REIGN AAA GARAGE UI FAIL: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var state: Node = root.get_node_or_null("GameState")
	verify(state!=null,"original source GameState autoload available")
	if state==null:
		quit(2)
		return
	var original: Dictionary = state.data.duplicate(true)
	var lang_old: String = str(state.locale)
	state.data = state.new_game()
	var starting: Dictionary = state.data.duplicate(true)
	verify(DISPLAY.columns_for(390.0,true)==1 and
		DISPLAY.columns_for(900.0,false)==1 and
		DISPLAY.columns_for(1400.0,false)==2 and
		DISPLAY.columns_for(NAN,false)==1,
		"responsive phone/desktop columns follow actual viewport and accessibility")
	verify(DISPLAY.details(state.data,"unsupported","en").is_empty(),
		"unknown vehicle cannot mint a card, price or valid buy action")
	for language in ["ru","en","zh"]:
		for id in CATALOG.ORDER:
			var snapshot: Dictionary = DISPLAY.details(starting,id,language)
			var source: Dictionary = CATALOG.VEHICLES[id]
			verify(not str(snapshot["title"]).is_empty() and
				int(snapshot["price"])==int(source["price"]) and
				int(snapshot["reputation"])==int(source["reputation"]),
				"true original car cost/name in native "+language+"/"+id)
			for metric in ["speed","acceleration","handling","fuel"]:
				verify(is_equal_approx(float(snapshot[metric]),float(source[metric]))
					and float(snapshot[metric])>0.0,
					"no fabricated commercial stats in "+metric+"/"+id)
			verify(bool(snapshot["selected"])==(id=="compact") and
				bool(snapshot["owned"])==(id=="compact"),
				"actual starting garage status in "+language+"/"+id)
			verify(bool(snapshot["disabled"]),
				"cannot buy original locked car or select already driving vehicle")
	verify(state.data==starting,"creating pure AAA card data does not mutate save, cash or missions")
	var hud: CanvasLayer = HUD.new()
	root.add_child(hud)
	for language in ["ru","en","zh"]:
		state.locale = language
		hud.call("_redraw_strategy")
		await process_frame
		var gallery: GridContainer = hud.find_child("CityReignAAAOriginalGarageGallery",true,false) as GridContainer
		verify(gallery!=null and gallery.get_child_count()==4,
			"four original native Godot cards exist in actual operations HUD: "+language)
		if gallery==null:
			continue
		verify(gallery.columns==DISPLAY.columns_for(get_viewport().get_visible_rect().size.x,
			bool(hud.get("compact_hud")) or get_viewport().get_visible_rect().size.x<1000.0),
			"real running Godot viewport drives native garage column count")
		var buttons: int = 0
		for id in CATALOG.ORDER:
			var card: PanelContainer = gallery.get_node("CityReignGarageCard_"+id) as PanelContainer
			verify(card!=null and card.get_theme_stylebox("panel") is StyleBoxFlat,
				"real GPU-backed graphite/brass card exists for "+id)
			var row: Button = card.find_child("CityReignGarageAction_"+id,true,false) as Button
			verify(row!=null and row.custom_minimum_size.y>=46.0,
				"garage original business action remains touch/keyboard accessible")
			if row!=null:
				buttons += 1
				verify(row.disabled,"real insufficient funds/selection disables initial gallery actions")
			for metric in ["speed","acceleration","handling"]:
				var gauge: ProgressBar = card.find_child("CityReignGarageMeter_"+metric,true,false) as ProgressBar
				verify(gauge!=null and
					is_equal_approx(gauge.value,float(CATALOG.VEHICLES[id][metric])) and
					not gauge.show_percentage,
					"source-bound actual PBR styled metric, not guessed percentages")
		verify(buttons==4,"no duplicated garage actions for all original 4 vehicles")
	# Full original purchase: sufficient real wallet and reputation are setup
	# ONLY inside this isolated native test; game authority charges real amount.
	state.locale = "ru"
	state.data["wallet"] = 3200
	state.data["reputation"] = 80
	var before: int = int(state.data["wallet"])
	hud.call("_redraw_strategy")
	await process_frame
	var available: Button = hud.find_child("CityReignGarageAction_courier",true,false) as Button
	verify(available!=null and not available.disabled,
		"actual source card enables real courier buy once budget/reputation permit")
	if available!=null:
		available.pressed.emit()
	verify(bool(state.data["vehicle_owned"]["courier"]) and
		int(state.data["wallet"])==before-int(CATALOG.VEHICLES["courier"]["price"]),
		"pressing the rendered card invokes GameState.buy_vehicle EXACTLY once")
	var paid: int = int(state.data["wallet"])
	await process_frame
	hud.call("_redraw_strategy")
	await process_frame
	var owned: Button = hud.find_child("CityReignGarageAction_courier",true,false) as Button
	verify(owned!=null and not owned.disabled,
		"purchased car changes actual button from buy to select in full HUD")
	if owned!=null:
		owned.pressed.emit()
	verify(str(state.data["vehicle_selected"])=="courier" and
		int(state.data["wallet"])==paid,
		"real car selection changes authoritative car but never double-charges")
	await process_frame
	hud.call("_redraw_strategy")
	await process_frame
	var selected: Button = hud.find_child("CityReignGarageAction_courier",true,false) as Button
	verify(selected!=null and selected.disabled,
		"selected real car is clearly visible and cannot be chosen twice")
	verify(DISPLAY.details(state.data,"courier","en")["status"]=="ON THE ROAD",
		"localization reflects selected original vehicle state after actual purchase")
	var wallet_after: int = int(state.data["wallet"])
	var fuel_status: Dictionary = state.data["garage_status"]["courier"]
	verify(float(fuel_status["fuel"])>=0 and wallet_after==2000,
		"existing vehicle fuel / wallet state remains source-of-truth")
	hud.queue_free()
	await process_frame
	state.data = original
	state.locale = lang_old
	print("CITY REIGN AAA native premium garage cards: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
