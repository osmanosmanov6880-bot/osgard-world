extends SceneTree
## R181 real source A* closures remain authoritative after sidewalk expansion.
const PAVEMENT=preload("res://scripts/city_reign_sidewalk_routing.gd")
const MOBILITY=preload("res://scripts/city_mobility.gd")
const RIGHTS=preload("res://scripts/city_reign_pedestrian_right_of_way.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R181 REAL CLOSED ROAD SIDEWALK FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var sim: Node=root.get_node("GameState")
	var current: Dictionary=(sim.get("data") as Dictionary).duplicate(true)
	var start:=Vector3(-182,0.8,-182)
	var target:=Vector3(133,0.8,124)
	var road: Array[Vector3]=MOBILITY.find_route(start,target,current)
	check(road.size()>4,"original real 9x9 source A* road route exists for true commute")
	var pav: Array[Vector3]=PAVEMENT.to_sidewalk_route(road,12)
	check(pav.size()>road.size() and pav[0]==road[0] and
		pav[pav.size()-1]==road[road.size()-1],
		"actual original A* path expands on true sidewalks with unchanged start/destination")
	var original_grid_steps: int=0
	for i in range(road.size()-1):
		if PAVEMENT.edge_sidewalk_offset(road[i],road[i+1],12)!=Vector3.ZERO:
			original_grid_steps+=1
	check(original_grid_steps>=2 and pav.size()<=PAVEMENT.MAX_GENERATED_WAYPOINTS,
		"at least two truly existing physically walkable A* grid edges remain bounded")
	var observed: int=0
	for p in pav:
		if PAVEMENT.on_original_sidewalk(p):
			observed+=1
	check(observed>4,
		"multiple original city sidewalk strips actually govern pedestrian geometry")
	var incidents: Array[Dictionary]=MOBILITY.active_incidents(current)
	var closed: Dictionary={}
	for incident in incidents:
		var a: Array=incident["a"]
		var b: Array=incident["b"]
		closed[MOBILITY.edge_key(Vector2i(int(a[0]),int(a[1])),
			Vector2i(int(b[0]),int(b[1])))]=true
	for i in range(road.size()-1):
		var a: Vector3=road[i]
		var b: Vector3=road[i+1]
		if not PAVEMENT.is_original_road_point(a) or not PAVEMENT.is_original_road_point(b):
			continue
		var aa:=Vector2i(roundi((a.x-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING),
			roundi((a.z-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING))
		var bb:=Vector2i(roundi((b.x-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING),
			roundi((b.z-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING))
		check(not closed.has(MOBILITY.edge_key(aa,bb)),
			"source A* prohibited actual road closure from every generated walking leg")
	check(RIGHTS.permission(Vector3(-150,0.7,-169),Vector3(0,0,2.15),2.15,0.0).get("wait",false),
		"pedestrian signal now covers real x+6m sidewalk, not only car lane center")
	check(not RIGHTS.permission(Vector3(-150,0.7,-169),Vector3(0,0,2.15),2.15,12.0).get("wait",true),
		"real sidewalk user may physically cross when ORIGINAL source signal grants WALK")
	check(RIGHTS.permission(Vector3(-148,0.7,-169),Vector3(0,0,2.15),2.15,0.0).is_empty(),
		"distant parallel outside original sidewalk lip has no phantom road stop")
	var agent: String=FileAccess.get_file_as_string("res://scripts/pedestrian_agent.gd")
	check(agent.contains("R181_SIDEWALKS.to_sidewalk_route(source_roads,citizen_id)") and
		agent.contains("R180_CROSSWALK.permission("),
		"original living city couples authentic sidewalk path with actual WALK/WAIT movement")
	print("CITY REIGN R181 CLOSED-SOURCE PAVEMENT: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
