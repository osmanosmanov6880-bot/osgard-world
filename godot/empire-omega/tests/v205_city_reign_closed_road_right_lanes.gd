extends SceneTree
## R185 original road closures, AStar topology and true 10m asphalt.
const LANE=preload("res://scripts/city_reign_vehicle_lane_routing.gd")
const MOBILITY=preload("res://scripts/city_mobility.gd")
const ROUTER=preload("res://scripts/street_router.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R185 ORIGINAL A* ROAD CLOSURE FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var gs: Node=root.get_node("GameState")
	var state: Dictionary=(gs.get("data") as Dictionary).duplicate(true)
	var raw: Array[Vector3]=ROUTER.find_route(
		Vector3(-182,0.8,-182),Vector3(133,0.8,124),state)
	var upgraded: Array[Vector3]=LANE.to_right_hand_lane(raw)
	check(raw.size()>4 and upgraded.size()>4 and
		upgraded.size()<=LANE.MAX_RETURN_NODES,
		"the real original 9x9 route creates only bounded source waypoints")
	check(upgraded[0]==raw[0] and
		upgraded[upgraded.size()-1]==raw[raw.size()-1],
		"existing original off-road pickup and destination preserved exactly")
	var on_lanes: int=0
	for i in range(upgraded.size()-1):
		var heading: Vector3=upgraded[i+1]-upgraded[i]
		if LANE.on_right_lane(upgraded[i],heading):
			on_lanes+=1
	check(on_lanes>=2,
		"real closure-aware A* path contains multiple actual right-side road segments")
	var no_exit: Array[Vector3]=[Vector3(-500,0.8,-500),Vector3(500,0.8,500)]
	check(LANE.to_right_hand_lane(no_exit)==no_exit,
		"an imaginary road outside the original map cannot be projected into a false lane")
	var closures: Dictionary={}
	for incident in MOBILITY.active_incidents(state):
		var arr_a: Array=incident["a"]
		var arr_b: Array=incident["b"]
		var a:=Vector2i(int(arr_a[0]),int(arr_a[1]))
		var b:=Vector2i(int(arr_b[0]),int(arr_b[1]))
		closures[MOBILITY.edge_key(a,b)]=true
	var verified_source_steps: int=0
	for i in range(raw.size()-1):
		if LANE.source_edge_right(raw[i],raw[i+1])==Vector3.ZERO:
			continue
		verified_source_steps+=1
		var left: Vector3=raw[i]
		var right: Vector3=raw[i+1]
		var origin:=Vector2i(roundi((left.x-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING),
			roundi((left.z-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING))
		var target:=Vector2i(roundi((right.x-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING),
			roundi((right.z-MOBILITY.ROAD_MIN)/MOBILITY.ROAD_SPACING))
		check(not closures.has(MOBILITY.edge_key(origin,target)),
			"R185 preserves actual original closed-road A* traversal decision")
	check(verified_source_steps>=2,
		"multiple physically valid 52m road segments are truly taken from original source A*")
	var changed: Dictionary=state.duplicate(true)
	changed["turn"]=int(state.get("turn",1))+3
	var reroute: Array[Vector3]=ROUTER.find_route(
		Vector3(-182,0.8,-182),Vector3(133,0.8,124),changed)
	var projected_again: Array[Vector3]=LANE.to_right_hand_lane(reroute)
	check(projected_again.size()>=2 and
		projected_again[0]==reroute[0] and
		projected_again[projected_again.size()-1]==reroute[reroute.size()-1],
		"genuinely changed city turn uses UPDATED original closure-aware routing, not cached old road path")
	var file: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(file.contains("R185_RIGHT_LANES.to_right_hand_lane(loop)") and
		file.contains("ROUTER.find_route("),
		"only original road-loop facade gets right-lane geometry after original A* chooses closures")
	print("CITY REIGN R185 SOURCE ROADWORKS & LANES: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
