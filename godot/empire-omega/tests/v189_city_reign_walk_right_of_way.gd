extends SceneTree
## R180 genuine 16-source-signal phase. No scripted fake trips.
const RULE=preload("res://scripts/city_reign_pedestrian_right_of_way.gd")
const LIGHTS=preload("res://scripts/city_reign_intersection_policy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,reason: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R180 PEDESTRIAN RIGHT-OF-WAY FAIL: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var at:=Vector3(-156,0.7,-169)
	var moving:=Vector3(0,0,2.15)
	var red: Dictionary=RULE.permission(at,moving,2.15,0.0)
	check(RULE.consistent_with_original_grid() and LIGHTS.JUNCTIONS.size()==4,
		"pedestrian authority and original 16 traffic junctions share ONE source grid")
	check(red.get("wait",false) and red.get("source_phase","")=="red" and
		absf(float(red.get("distance_to_center",0))-13.0)<0.01,
		"real person must WAIT at 13m approach before 8m stop line on original Z red")
	var green: Dictionary=RULE.permission(at,moving,2.15,12.0)
	check(not green.get("wait",true) and green.get("state","")=="walk" and
		green.get("source_phase","")=="green",
		"same real junction gives WALK when actual Z turns green")
	var late: Dictionary=RULE.permission(at,moving,2.15,18.5)
	check(late.get("wait",false) and late.get("source_phase","")=="green",
		"yellow WALK is forbidden in last seconds of green if crossing cannot finish")
	check(RULE.required_green_seconds(13.0,2.15)>6.0 and
		RULE.required_green_seconds(13.0,1.0)>
		RULE.required_green_seconds(13.0,2.15),
		"physical green time reserves actual sidewalk-to-opposite-side walking time")
	check(RULE.permission(Vector3(-156,0,-163.5),moving,2.15,0.0).is_empty(),
		"once inside real 8m crossing, no red freeze mid-road")
	check(RULE.permission(Vector3(-148,0,-169),moving,2.15,0.0).is_empty(),
		"nearby side lane not falsely blocked by an unrelated signal")
	check(RULE.permission(Vector3(-156,0,-190),moving,2.15,0.0).is_empty(),
		"distant resident never stops because of far-away intersection")
	check(RULE.permission(Vector3(-156,0,-169),Vector3(0,0,-2),2.15,0.0).is_empty(),
		"walker moving AWAY from actual junction has no phantom WAIT")
	var xat:=Vector3(-169,0,-156)
	check(not RULE.permission(xat,Vector3(2.15,0,0),2.15,0).get("wait",true) and
		RULE.permission(xat,Vector3(2.15,0,0),2.15,12).get("wait",false),
		"physically opposite X crossing uses its proper opposite signal phases")
	check(RULE.permission(at,moving,2.15,NAN).get("wait",false) and
		RULE.permission(Vector3(NAN,0,0),moving,2.15,0.0).get("wait",false),
		"invalid clock and invalid road position conservatively deny WALK")
	check(RULE.permission(at,Vector3.ZERO,2.15,0.0).is_empty(),
		"stationary walker does not fabricate an imminent crossing")
	check(RULE.face_state(0.0,"x")=="walk" and
		RULE.face_state(0.0,"z")=="wait" and
		RULE.face_state(10.0,"x")=="wait" and
		RULE.face_state(12.0,"z")=="walk",
		"four original source physical WALK/WAIT visual states follow actual clock")
	check(RULE.face_state(18.6,"z")=="wait" and
		RULE.face_state(12.0,"bad")=="wait",
		"late green and invalid direction never claim safe walk")
	print("CITY REIGN R180 REAL WALK WINDOWS: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
