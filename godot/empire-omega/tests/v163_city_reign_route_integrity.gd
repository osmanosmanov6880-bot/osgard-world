extends SceneTree
## R171 real road A* sanitizer, bounded off-route recomputation and no fake streets.
const ROAD=preload("res://scripts/city_reign_route_integrity.gd")
const GOAL=preload("res://scripts/city_reign_goal_fabric.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R171 ROUTE INTEGRITY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var actual: Array[Vector3]=[Vector3(-130,0,-130),Vector3(-78,0,-130),
		Vector3(-26,0,-130),Vector3(26,0,-130),Vector3(78,0,-130),Vector3(130,0,-130)]
	check(ROAD.usable(actual,actual[0],actual[-1]),"real genuine existing east-west city road is valid")
	check(ROAD.verified(actual,actual[0],actual[-1]).size()==actual.size(),
		"source graph polyline remains unchanged, never straightened through buildings")
	var broken: Array[Vector3]=actual.duplicate()
	broken[3]=Vector3(NAN,0,-130)
	check(not ROAD.usable(broken,actual[0],actual[-1]) and
		ROAD.verified(broken,actual[0],actual[-1]).is_empty(),
		"corrupt nonfinite A* cannot paint fraudulent route")
	var foreign: Array[Vector3]=[Vector3(-130,0,-130),Vector3(900,0,900)]
	check(not ROAD.usable(foreign,actual[0],actual[-1]),
		"fake straight-line map crossing entire city is rejected")
	var stale: Array[Vector3]=actual.duplicate()
	check(not ROAD.usable(stale,Vector3(290,0,290),actual[-1]),
		"stale previous player route cannot be reused from distant position")
	check(not ROAD.usable(actual,actual[0],Vector3(300,0,300)),
		"cached route to wrong mission destination cannot be trusted")
	var closed: Array[Vector3]=[actual[0]]
	check(ROAD.usable(closed,actual[0],actual[-1]),
		"original disconnected A* blocked-road sentinel is retained as no road")
	var many: Array[Vector3]=[]
	for i in range(150): many.append(Vector3(float(i),0,-130))
	check(not ROAD.usable(many,many[0],many[-1]),"150-node route resource abuse rejected")
	check(ROAD.should_recalculate(0.0,true,false,false) and
		ROAD.should_recalculate(0.0,false,true,false),
		"changing actual mission source or saved physical goal immediately recalculates A*")
	check(ROAD.should_recalculate(0.80,false,false,true) and
		not ROAD.should_recalculate(0.35,false,false,true),
		"off-route recovery is responsive but bounded to 0.75 seconds")
	check(not ROAD.should_recalculate(0.80,false,false,false) and
		ROAD.should_recalculate(1.27,false,false,false),
		"normal navigation continues legacy 1.25-second low-CPU route budget")
	check(not ROAD.should_recalculate(NAN,false,false,true),
		"invalid frame timer cannot force excessive route generation")
	check(GOAL.localized("nonsense","ru")=="","missing source cannot invent a map label")
	print("CITY REIGN R171 REAL ROUTE: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
