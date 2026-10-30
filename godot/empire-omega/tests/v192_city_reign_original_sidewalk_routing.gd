extends SceneTree
## R181 actual Godot pavement topology: original existing 36 sidewalk lips.
const PAVEMENT=preload("res://scripts/city_reign_sidewalk_routing.gd")
const MOBILITY=preload("res://scripts/city_mobility.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R181 ORIGINAL SIDEWALK GEOMETRY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(PAVEMENT.source_geometry_consistent() and
		MOBILITY.ROAD_MIN==-208.0 and MOBILITY.ROAD_SPACING==52.0,
		"pure pedestrian path references exact current world original 9x9 road grid")
	var first:=Vector3(-156,0.8,-156)
	var turn:=Vector3(-104,0.8,-156)
	var finish:=Vector3(-104,0.8,-104)
	var route: Array[Vector3]=[first,turn,finish]
	var foot: Array[Vector3]=PAVEMENT.to_sidewalk_route(route,0)
	check(foot[0]==first and foot[foot.size()-1]==finish and
		foot.size()>route.size(),
		"player's actual A* endpoints preserved while the human footpath gains sidewalk bends")
	var east:=Vector3(-130,0.8,-150)
	check(foot.has(east)==false and foot.has(Vector3(-156,0.8,-150)) and
		foot.has(Vector3(-104,0.8,-150)) and
		foot.has(Vector3(-98,0.8,-104)),
		"both physical +6m sidewalk lips are actually visited, no fake screen position")
	check(foot.has(Vector3(-98,0.8,-150)) and
		PAVEMENT.on_original_sidewalk(Vector3(-98,0.8,-150)),
		"90 degree pedestrian turn follows existing sidewalk corner, not road center shortcut")
	var other: Array[Vector3]=PAVEMENT.to_sidewalk_route(route,1)
	check(other.has(Vector3(-156,0.8,-162)) and
		other.has(Vector3(-110,0.8,-104)) and
		not other.has(Vector3(-98,0.8,-150)),
		"two deterministic pedestrian sidewalk sides spread the original 34 visible residents")
	check(PAVEMENT.edge_sidewalk_offset(first,turn,0)==Vector3(0,0,6) and
		PAVEMENT.edge_sidewalk_offset(turn,finish,0)==Vector3(6,0,0),
		"real pedestrian footpaths follow both X and Z grid roads at physical lip positions")
	check(PAVEMENT.edge_sidewalk_offset(first,Vector3(-100,0,-156),0)==Vector3.ZERO,
		"unrecognized imaginary 56m road never creates a fake walkable sidewalk")
	check(PAVEMENT.to_sidewalk_route(route,0)==foot,
		"same saved city and citizen deterministically produce same sidewalk route")
	var malformed: Array[Vector3]=[first,Vector3(NAN,0,0),finish]
	check(PAVEMENT.to_sidewalk_route(malformed,0)==malformed,
		"invalid coordinate fails to original route instead of inventing navigation")
	check(not PAVEMENT.on_original_sidewalk(Vector3(300,0,300)) and
		PAVEMENT.on_original_sidewalk(Vector3(52+6,0,52)),
		"pavement validator accepts actual original walk lip but rejects outside city")
	check(foot.size()<=PAVEMENT.MAX_GENERATED_WAYPOINTS,
		"native mobile path size is explicitly bounded")
	print("CITY REIGN R181 ORIGINAL PHYSICAL SIDEWALK PATH: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
