extends SceneTree
## R185: actual 9x9 physical road right-hand lane geometry and corners.
const LANE=preload("res://scripts/city_reign_vehicle_lane_routing.gd")
const SOURCE=preload("res://scripts/city_mobility.gd")
var passed: int=0
var failed: int=0
func check(ok: bool,why: String) -> void:
	if ok:passed+=1
	else:
		failed+=1
		push_error("R185 ACTUAL RIGHT-HAND LANE GEOMETRY FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var a:=Vector3(-156,0.8,-156)
	var east:=Vector3(-104,0.8,-156)
	var farther_east:=Vector3(-52,0.8,-156)
	var south:=Vector3(-156,0.8,-104)
	var west:=Vector3(-208,0.8,-156)
	var north:=Vector3(-156,0.8,-208)
	check(LANE.source_integrity() and SOURCE.ROAD_SIZE==9 and SOURCE.ROAD_SPACING==52.0,
		"pure right-hand lane uses EXACT original 9x9 52m road fabric and 10m paved road width")
	check(LANE.source_edge_right(a,east)==Vector3(0,0,2) and
		LANE.source_edge_right(east,a)==Vector3(0,0,-2),
		"opposing east/west physically travel on DIFFERENT 2m lanes 4m apart")
	check(LANE.source_edge_right(a,south)==Vector3(-2,0,0) and
		LANE.source_edge_right(a,north)==Vector3(2,0,0),
		"opposite north/south physical lanes respect same genuine right-hand traffic")
	var straight: Array[Vector3]=[a,east,farther_east]
	var projected: Array[Vector3]=LANE.to_right_hand_lane(straight)
	check(projected==[a+Vector3(0,0,2),east+Vector3(0,0,2),
		farther_east+Vector3(0,0,2)],
		"real three-source-road A* nodes now follow one consistent +2m lane")
	var turn: Array[Vector3]=[a,east,Vector3(-104,0.8,-104)]
	var curved: Array[Vector3]=LANE.to_right_hand_lane(turn)
	check(curved.size()==3 and
		curved[1]==east+Vector3(-2,0,2) and
		LANE.on_original_asphalt(curved[1]),
		"real +X then +Z intersection meets at asphalt interior 2m x 2m, not a backwards hook")
	var left_turn: Array[Vector3]=[a,east,Vector3(-104,0.8,-208)]
	check(LANE.to_right_hand_lane(left_turn)==left_turn,
		"invalid 52m A* jump is never falsely projected onto a physical lane")
	var uturn: Array[Vector3]=[a,east,a]
	check(LANE.to_right_hand_lane(uturn)==uturn,
		"unsafe 180-degree turn preserves untouched original route instead of inventing a lane")
	var current:=Vector3(-154,0.8,-154)
	var first: Array[Vector3]=[current,a,east,Vector3(-102,0.8,-154)]
	var departure: Array[Vector3]=LANE.to_right_hand_lane(first)
	check(departure.size()==3 and departure[0]==current and
		departure[1].x>current.x and
		LANE.on_right_lane(departure[0],departure[1]-departure[0]),
		"real moving NPC leaving original +2m initial lane NEVER first drives 2m backwards")
	check(LANE.on_right_lane(a+Vector3(0,0,2),Vector3.RIGHT) and
		LANE.on_right_lane(a+Vector3(0,0,-2),Vector3.LEFT) and
		not LANE.on_right_lane(a,Vector3.RIGHT) and
		not LANE.on_right_lane(a+Vector3(0,0,-2),Vector3.RIGHT),
		"native lane error distinguishes real proper, central and opposing traffic lanes")
	check(LANE.on_original_asphalt(a+Vector3(-2,0,2)) and
		not LANE.on_original_asphalt(Vector3(500,0,500)),
		"all projected source corners stay on true original asphalt; no world-edge leap")
	check(LANE.source_edge_right(a,Vector3(-100,0.8,-156))==Vector3.ZERO and
		LANE.source_edge_right(a,Vector3(-104,3,-156))==Vector3.ZERO,
		"non-existent road lengths and unrealistic elevation cannot fabricate a route edge")
	check(LANE.to_right_hand_lane(straight)==projected,
		"same source A* path deterministically generates same lane, no random changes")
	var broken: Array[Vector3]=[a,Vector3(NAN,0,-104),east]
	var refused: Array[Vector3]=LANE.to_right_hand_lane(broken)
	check(refused.size()==broken.size() and not refused[1].is_finite(),
		"non-finite source road safely fails to original without teleporting vehicles")
	print("CITY REIGN R185 SOURCE RIGHT-HAND LANE RULES: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
