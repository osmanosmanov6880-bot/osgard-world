extends SceneTree
## R179 REAL native existing money/fines cooldown and unchanged save schema.
const LAW=preload("res://scripts/city_law.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R179 ORIGINAL CITY LAW REGRESSION FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var old: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	sim.set("data",sim.new_game())
	var first: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	check(LAW.OFFENCES.has("red_light") and LAW.OFFENCES.size()==4,
		"one new source lawful offence joins old three unchanged traffic acts")
	check(bool(sim.call("register_traffic_offence","red_light")),
		"real GameState authority issues actual red violation fine")
	var d: Dictionary=sim.get("data")
	check(int(d["law"]["heat"])==1 and int(d["law"]["fine"])==115 and
		int(d["law"]["infractions"])==1,
		"real saved city law escalates a confirmed red offence once")
	check(d["law"]["history"][0]["type"]=="red_light" and
		LAW.valid(d["law"],int(d["turn"])),
		"same strict original JSON save validator accepts new authentic offence")
	check(not bool(sim.call("register_traffic_offence","red_light")) and
		int(d["law"]["fine"])==115 and int(d["law"]["infractions"])==1,
		"original 18-second legal cooldown prevents repeated punishment")
	d["law"]["cooldown"]=0.0
	check(bool(sim.call("register_traffic_offence","red_light")) and
		int(d["law"]["heat"])==2 and int(d["law"]["fine"])==345,
		"second genuinely independent crossing uses original graduated law fine")
	check(LAW.valid(d["law"],int(d["turn"])),
		"all real new and old stored infraction history stays save-valid")
	check(int(d["wallet"])==int(first["wallet"]) and
		int(d["treasury"])==int(first["treasury"]) and
		int(d["mission"])==int(first["mission"]),
		"issuing lawful citation is not a magic money transfer or mission win")
	check(bool(sim.call("resolve_traffic_fines",false)) and
		int(d["wallet"])==int(first["wallet"])-345 and
		int(d["treasury"])==int(first["treasury"])+345,
		"actual City Hall fine payment transfers REAL wallet funds to real treasury")
	check(d["law"]["fine"]==0 and d["law"]["heat"]==0 and
		LAW.valid(d["law"],int(d["turn"])),
		"same original law settlement clears heat and remains valid after payment")
	sim.set("data",old)
	print("CITY REIGN R179 REAL FINES SAVE SCHEMA: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
