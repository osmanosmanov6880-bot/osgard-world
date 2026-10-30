extends SceneTree
## R182: actual 3D-vehicle right of way for a PERSON inside source lane.
const GUARD=preload("res://scripts/city_reign_crosswalk_occupancy.gd")
const SOURCE=preload("res://scripts/city_reign_intersection_policy.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R182 REAL CROSSWALK OCCUPANCY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var center:=Vector3(-156,0,-156)
	var car:=Vector3(-156,0.8,-170)
	var heading:=Vector3.BACK
	var x:=GUARD.gate(car,heading,12.0)
	check(GUARD.source_geometry_consistent() and SOURCE.JUNCTIONS.size()==4,
		"same original 16 real junctions, true painted stop bars and source lane width")
	check(not x.is_empty() and x["point"]==center and
		absf(float(x["stop_distance"])-6.0)<0.01,
		"source car sees the actual 8m-before-centre stop bar at physical distance")
	check(GUARD.occupied(x,heading,Vector3(-155,0.8,-155),Vector3.ZERO,8.0),
		"real person stopped INSIDE vehicle lane is protected without fabricated velocity")
	check(not GUARD.occupied(x,heading,Vector3(-150,0.8,-155),Vector3.ZERO,8.0),
		"motionless citizen on real +6m sidewalk never causes a false car roadblock")
	check(not GUARD.occupied(x,heading,Vector3(-150,0.8,-155),
		Vector3(0,0,2.15),8.0),
		"original parallel sidewalk walker does not make vehicles brake")
	check(GUARD.occupied(GUARD.gate(Vector3(-156,0.8,-180),heading,12.0),
		heading,Vector3(-150,0.8,-155),Vector3(-2.15,0,0),8.0),
		"real cross-traffic walker physically headed FROM sidewalk INTO source lane is forecast")
	check(not GUARD.occupied(x,heading,Vector3(-150,0.8,-155),
		Vector3(2.15,0,0),8.0),
		"walker moving AWAY from vehicle lane does not trigger imaginary right of way")
	check(not GUARD.occupied(x,heading,Vector3(-156,0.8,-145),
		Vector3.ZERO,8.0),
		"citizen past source intersection crossing cannot immobilize remote cars")
	check(not GUARD.occupied(x,heading,Vector3(NAN,0,0),
		Vector3.ZERO,8.0) and
		not GUARD.occupied({},heading,center,Vector3.ZERO,8.0),
		"corrupt pedestrian position or absent source junction cannot invent occupancy")
	check(GUARD.stop_clearance(x)==10.0 and
		GUARD.reduced_speed(x,12.0,1.0,true)<12.0,
		"actual source stop gap reduces speed through EXISTING TrafficSafety")
	check(GUARD.reduced_speed(x,12.0,1.0,false)==12.0,
		"empty crossing does not steal normal source green cruise speed")
	var far:=GUARD.gate(Vector3(-156,0.8,-180),heading,12.0)
	check(GUARD.reduced_speed(far,18.0,0.4,true)<
		GUARD.reduced_speed(far,18.0,1.0,true),
		"real wet pavement extends the original safe braking distance")
	check(GUARD.gate(Vector3(-156,0.8,-148),heading,0.0).is_empty(),
		"an original car already INSIDE junction cannot freeze on distant pedestrian")
	check(GUARD.gate(Vector3(-156,0.8,-201),heading,12.0).is_empty(),
		"vehicle too far from source crossing does not evaluate all walkers")
	check(GUARD.gate(Vector3(NAN,0,0),heading,0).is_empty() and
		GUARD.gate(car,heading,NAN).is_empty(),
		"invalid source physics fails closed")
	check(GUARD.reduced_speed(x,NAN,0.8,true)==0.0 and
		GUARD.reduced_speed(x,12.0,NAN,true)==0.0,
		"invalid vehicle physics never awards faster unsafe driving")
	print("CITY REIGN R182 REAL PEDESTRIAN CROSSING SAFETY: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
