extends SceneTree
## R178: same real 24s signal cycle, wet physical stop rule and driver cue.
const RULE=preload("res://scripts/city_reign_intersection_policy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("R178 REAL SIGNAL RULE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var xaxis:=Vector3.RIGHT
	var zaxis:=Vector3.BACK
	check(RULE.source_grid_valid() and RULE.JUNCTIONS.size()==4,
		"same original 4 by 4 physical 16-junction traffic grid")
	check(RULE.state_at(0.0,xaxis)=="green" and RULE.state_at(0.0,zaxis)=="red",
		"true source cycle phase 0 permits only X direction")
	check(RULE.state_at(10.6,xaxis)=="amber" and RULE.state_at(11.9,zaxis)=="red",
		"last real 1.5 seconds are amber X and red Z")
	check(RULE.state_at(12.0,zaxis)=="green" and RULE.state_at(12.0,xaxis)=="red",
		"12s phase change grants Z but not X")
	check(RULE.state_at(22.6,zaxis)=="amber" and RULE.state_at(24.0,xaxis)=="green",
		"amber and 24s rollover follow original signal controller exactly")
	check(RULE.state_at(NAN,xaxis)=="unknown" and
		RULE.state_at(3.0,Vector3.ZERO)=="unknown",
		"invalid or directionless input never yields fabricated green")
	var at:=Vector3(-156.0,0.8,-169.0)
	var stop: Dictionary=RULE.approach(at,zaxis,0.0)
	check(not stop.is_empty() and stop["point"].distance_to(Vector3(-156,0,-156))<0.1
		and absf(float(stop["stop_distance"])-5.0)<0.01,
		"source signal stop bar is 8 metres before original physical junction")
	check(RULE.approach(Vector3(-149,0,-169),zaxis,0.0).is_empty(),
		"neighboring lane eight metres away never receives phantom signal stop")
	var at_bar:=Vector3(-156,0,-163.5)
	check(not RULE.approach(at_bar,zaxis,0.0).is_empty() and
		RULE.speed_cap(at_bar,zaxis,2.0,12.0,1.0,0.0)==0.0,
		"actual red stop holds through minor physics overshoot at the existing road line")
	check(RULE.approach(Vector3(-156,0,-162),zaxis,0.0).is_empty(),
		"once the car enters actual junction it cannot freeze on red mid-crossing")
	var red_cap: float=RULE.speed_cap(at,zaxis,8.0,12.0,1.0,0.0)
	var green_cap: float=RULE.speed_cap(at,zaxis,8.0,12.0,1.0,12.0)
	check(red_cap<7.0 and green_cap==12.0,
		"real original red physically reduces NPC speed; green restores source cruise")
	check(RULE.speed_cap(at,zaxis,8.0,12.0,1.0,11.0)==red_cap,
		"red opposing phase never inherits X amber permission")
	var near_amber:=Vector3(-170,0,-156)
	var amber_cap: float=RULE.speed_cap(near_amber,xaxis,5.0,12.0,1.0,10.7)
	var committed_cap: float=RULE.speed_cap(near_amber,xaxis,15.0,12.0,1.0,10.7)
	check(amber_cap<12.0 and committed_cap==12.0,
		"true amber stops when safe but preserves physically unavoidable dilemma-zone passage")
	var wet_at:=Vector3(-156,0,-179)
	check(RULE.speed_cap(wet_at,zaxis,9,12,0.4,0.0)<
		RULE.speed_cap(wet_at,zaxis,9,12,1.0,0.0),
		"existing wet traction lowers safe real road signal approach speed")
	check(RULE.speed_cap(Vector3(NAN,0,0),zaxis,9,12,1,0)==0.0 and
		RULE.speed_cap(at,zaxis,NAN,12,1,0)==0.0,
		"invalid physical collision math fails closed at 0 m/s")
	var hazard: Dictionary=RULE.driver_warning(at,PI,8.0,0.0)
	check(hazard["kind"]=="signal" and hazard["phase"]=="red" and
		hazard["urgency"]=="urgent",
		"human driving advisor uses exactly same actual signal clock and approaching lane")
	check(RULE.driver_warning(at,PI,8.0,12.0).is_empty() and
		RULE.driver_warning(Vector3(500,0,0),PI,8.0,0.0).is_empty(),
		"green and unknown far road do not manufacture dangerous driver warnings")
	check(RULE.driver_warning(at,PI,1.0,0.0).is_empty(),
		"player nearly parked receives no repeated alert spam")
	print("CITY REIGN R178 REAL PHASE AND WET BRAKING: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
