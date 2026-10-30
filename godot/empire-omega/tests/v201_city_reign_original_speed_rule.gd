extends SceneTree
## R184 original player-speeding fine is source-locked to visible 90km/h signs.
const RULE=preload("res://scripts/city_reign_speed_limit_policy.gd")
const CITY_LAW=preload("res://scripts/city_law.gd")
const DRIVER=preload("res://scripts/city_reign_driver_awareness.gd")
var passed: int=0
var failed: int=0
func check(value: bool,why: String) -> void:
	if value:passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R184 ORIGINAL SPEED LAW FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(RULE.source_rule_valid() and RULE.displayed_limit()==90 and
		is_equal_approx(RULE.LIMIT_MPS*3.6,float(RULE.LIMIT_KMH)),
		"the 64 real physical street signs and actual 25m/s=90kmh city law share ONE source")
	check(not RULE.above_limit(25.0) and RULE.above_limit(25.01) and
		RULE.above_limit(-25.1) and not RULE.above_limit(NAN),
		"exact original player legal boundary preserved, reverse still uses magnitude")
	check(RULE.player_warning(21.0).is_empty() and
		RULE.player_warning(22.5).get("limit_kmh",0)==90 and
		RULE.player_warning(26.0).get("over_limit",false),
		"genuine legal proximity warning appears before original 4s offence; no false low-speed hint")
	check(RULE.player_warning(NAN).is_empty() and
		RULE.player_warning(INF).is_empty(),
		"invalid source physics cannot generate fabricated legal warning")
	var t: float=0.0
	for i in range(16):
		t=RULE.timer_step(t,25.5,0.25)
	check(RULE.citation_ready(t) and is_equal_approx(t,4.0),
		"real 4s sustained high-speed offence matches original GameState rule")
	check(not RULE.citation_ready(RULE.timer_step(0.0,26.0,2.0)),
		"browser frame spike cannot fake a four-second high-speed offence")
	check(is_equal_approx(RULE.timer_step(4.0,19.0,0.25),3.5) and
		not RULE.citation_ready(RULE.timer_step(3.5,24.0,0.25)),
		"safe driving decays physical offence timer by original two-times rule")
	check(RULE.timer_step(1.0,NAN,0.1)==0.0 and
		RULE.timer_step(1.0,26.0,NAN)==0.0,
		"invalid deltas and sensor speeds cannot grant fines")
	var caution: Dictionary=RULE.player_warning(25.5)
	check(DRIVER.localized(caution,"ru").contains("90") and
		DRIVER.localized(caution,"en").contains("90") and
		DRIVER.localized(caution,"zh").contains("90"),
		"RU/EN/ZH original native driver HUD warns with the TRUE law number")
	check(DRIVER.localized({"kind":"pedestrian","urgency":"urgent"},"en").contains("PEDESTRIAN") and
		DRIVER.localized({"kind":"signal","phase":"red"},"ru").contains("КРАСНЫЙ"),
		"original urgent player-collision and red-light alerts survive new speed hint")
	var sim: Node=root.get_node("GameState")
	var old: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	sim.set("data",sim.new_game())
	check(bool(sim.call("register_traffic_offence","speeding")),
		"actual original CityLaw issues existing speed offence, no new wallet")
	check(sim.data["law"]["fine"]==90 and sim.data["law"]["heat"]==1 and
		sim.data["law"]["history"][0]["type"]=="speeding" and
		CITY_LAW.valid(sim.data["law"],int(sim.data["turn"])),
		"true source speed 90kmh law still uses original 90-credit strict JSON save")
	check(not bool(sim.call("register_traffic_offence","speeding")) and
		sim.data["law"]["fine"]==90,
		"original 18-second cooldown prevents repetitive speeding fines")
	sim.set("data",old)
	print("CITY REIGN R184 SOURCE SPEEDING & LAW: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
