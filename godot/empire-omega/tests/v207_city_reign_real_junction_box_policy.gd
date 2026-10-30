extends SceneTree
## R186 PURE source policy: actual box, blocked right-hand exit, cross vehicle.
const BOX=preload("res://scripts/city_reign_junction_box_clearance.gd")
const SOURCE=preload("res://scripts/city_reign_intersection_policy.gd")
const SAFETY=preload("res://scripts/traffic_safety.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R186 PHYSICAL ORIGINAL JUNCTION BOX FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var heading:=Vector3.BACK
	var start:=Vector3(-156,0.8,-170)
	var gate: Dictionary=SOURCE.approach(start,heading,12.0)
	check(BOX.source_integrity() and
		BOX.source_gate_valid(gate,heading) and
		absf(float(gate["stop_distance"])-6.0)<0.001,
		"genuine R178 junction stop bar at original 16 physical crossings controls R186")
	check(BOX.classify(gate,heading,8.0,Vector3(-158,0.8,-142),
		Vector3.ZERO,0.0)=="blocked_exit",
		"genuine stationary 4.1m car in RIGHT-HAND downstream +2m exit stops entering NPC")
	check(BOX.classify(gate,heading,8.0,Vector3(-154,0.8,-142),
		Vector3.ZERO,0.0)=="",
		"opposing left-hand lane parked car does NOT block lawful separated exit")
	check(BOX.classify(gate,heading,8.0,Vector3(-158,0.8,-142),
		Vector3(0,0,3.0),3.0)=="",
		"genuinely MOVING exit traffic is not confused with static gridlock")
	check(BOX.classify(gate,heading,8.0,Vector3(-155,0.8,-155),
		Vector3(-4,0,0),4.0)=="occupied_box",
		"perpendicular native vehicle already INSIDE real intersection gets safe clearance")
	check(BOX.classify(gate,heading,8.0,Vector3(-158,0.8,-154),
		Vector3(0,0,6.0),6.0)=="",
		"parallel car moving in its own true 2m lane is still handled by original FOLLOW")
	check(BOX.classify(gate,heading,8.0,Vector3(-166,0.8,-156),
		Vector3(8,0,0),8.0)=="incoming_cross_traffic",
		"short actual source velocity projection anticipates cross car entering box before arrival")
	check(BOX.classify(gate,heading,8.0,Vector3(-180,0.8,-156),
		Vector3(4,0,0),4.0)=="",
		"remote cross vehicle beyond measured arrival never creates phantom obstruction")
	check(BOX.classify(gate,heading,8.0,Vector3(-158,0.8,-180),
		Vector3.ZERO,0.0)=="",
		"vehicle physically behind source STOP line cannot block the real intersection")
	check(BOX.classify(gate,heading,8.0,Vector3(-132,0.8,-154),
		Vector3.ZERO,0.0)=="",
		"vehicles on unrelated parallel streets don't trigger 16-junction clearance")
	check(BOX.classify(gate,heading,8.0,Vector3(NAN,0,0),
		Vector3.ZERO,0.0)=="" and
		BOX.classify({},heading,8.0,Vector3(-155,0,-155),
		Vector3.ZERO,0.0)=="" and
		not BOX.source_gate_valid({},heading),
		"invalid source state and corrupt coordinates can never fabricate NPC yields")
	check(BOX.safe_stop_cap(gate,heading,12.0,1.0)<12.0 and
		BOX.safe_stop_cap(gate,heading,12.0,1.0)>=0.0,
		"real original wet TrafficSafety safe-speed physically slows BEFORE source stop bar")
	var far: Dictionary=SOURCE.approach(Vector3(-156,0.8,-180),heading,12.0)
	check(BOX.safe_stop_cap(far,heading,18.0,0.4)<
		BOX.safe_stop_cap(far,heading,18.0,1.0),
		"real wet original braking grants lower permissible speed on longer approach")
	check(SOURCE.approach(Vector3(-156,0.8,-148),heading,12.0).is_empty(),
		"real NPC ALREADY inside intersection remains free to clear, no frozen mid-box car")
	check(not BOX.source_gate_valid(SOURCE.approach(
		Vector3(-156,0.8,-205),heading,12.0),heading),
		"no expensive far-away all-12-car scan before true junction sight distance")
	print("CITY REIGN R186 REAL JUNCTION BOX PURE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
