extends SceneTree
## R188 authoritative original 12 52m AStar roadwork edges and driver risk
const OPER=preload("res://scripts/city_reign_roadwork_operations.gd")
const MOBILITY=preload("res://scripts/city_mobility.gd")
const ROUTER=preload("res://scripts/street_router.gd")
const HUD=preload("res://scripts/city_reign_driver_awareness.gd")
var pass_count: int=0
var fail_count: int=0
func verify(ok: bool,why: String) -> void:
	if ok:pass_count+=1
	else:
		fail_count+=1
		push_error("R188 SOURCE OPERATIONS FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	verify(OPER.catalog_integrity() and MOBILITY.ROAD_SIZE==9 and
		MOBILITY.ROAD_SPACING==52.0,"12 real source adjacent edges from 9x9 original map")
	var catalog: Array=MOBILITY.catalog().get("incidents",[])
	var keys: Dictionary={}
	for item in catalog:
		var data: Dictionary=OPER.source_segment(item)
		verify(not data.is_empty() and not keys.has(data.get("edge","")) and
			(data["center"] as Vector3).is_finite() and
			is_equal_approx((data["axis"] as Vector3).length(),1.0),
			"one actual 52m legal source A* edge, not invented road")
		keys[data["edge"]]=true
	verify(keys.size()==12,"all 12 incident edges unique")
	var altered: Dictionary=(catalog[0] as Dictionary).duplicate(true)
	altered["a"]=[0,0]
	altered["b"]=[1,0]
	verify(OPER.source_segment(altered).is_empty() and
		OPER.source_segment({"id":"forged","a":[0,0],"b":[1,0]}).is_empty(),
		"forged ID/endpoint cannot create new closure, repair, or reward")
	var gs: Node=root.get_node("GameState")
	var state: Dictionary=gs.new_game()
	var incidents: Array[Dictionary]=MOBILITY.active_incidents(state)
	var selected: Dictionary=OPER.source_segment(incidents[0])
	verify(incidents.size()>=1 and incidents.size()<=2 and
		OPER.active_sites(state).size()==incidents.size(),
		"real state clock/seed controls source closed road count")
	var axis: Vector3=selected["axis"]
	var center: Vector3=selected["center"]
	var right:=Vector3(-axis.z,0,axis.x)
	var angle: float=atan2(-axis.x,-axis.z)
	var approach: Vector3=center-axis*30.0+right*2.0
	var risk: Dictionary=OPER.driver_warning(approach,angle,8.0,incidents)
	verify(risk.get("kind","")=="road_closed" and
		risk.get("incident_id","")==selected["id"] and
		is_equal_approx(float(risk.get("distance_m",0)),30.0),
		"source exact real roadside site gives warning thirty metres before impact")
	verify(OPER.driver_warning(approach,angle,0,incidents).is_empty() and
		OPER.driver_warning(approach,angle+PI*0.5,8,incidents).is_empty() and
		OPER.driver_warning(center-axis*47.0,angle,8,incidents).is_empty(),
		"stationary, cross-road and remote drivers have no fabricated alerts")
	verify(OPER.driver_warning(center-axis*25.0+right*7.0,angle,8,incidents).is_empty() and
		OPER.driver_warning(Vector3(NAN,0,0),angle,8,incidents).is_empty(),
		"out-of-lane and corrupt coordinates generate no false game alerts")
	verify(HUD.localized(risk,"ru").contains("ПЕРЕКРЫТА") and
		HUD.localized(risk,"en").contains("ROAD CLOSED") and
		HUD.localized(risk,"zh").contains("道路封闭"),
		"genuine compact driving HUD supports RU EN ZH, no new overlay")
	var cleared: Dictionary=state.duplicate(true)
	cleared["roads_cleared"].append(str(selected["id"]))
	var after: Array[Dictionary]=MOBILITY.active_incidents(cleared)
	verify(OPER.driver_warning(approach,angle,8,after).get("incident_id","")!=selected["id"],
		"repaired real physical barrier disappears from original road warnings")
	var a: Array=incidents[0]["a"]
	var b: Array=incidents[0]["b"]
	var pa: Vector3=MOBILITY._pos(Vector2i(int(a[0]),int(a[1])))
	var pb: Vector3=MOBILITY._pos(Vector2i(int(b[0]),int(b[1])))
	verify(MOBILITY.length(ROUTER.find_route(pa,pb,state))>
			MOBILITY.length(ROUTER.find_route(pa,pb,cleared))+40.0 and
		is_equal_approx(MOBILITY.length(ROUTER.find_route(pa,pb,cleared)),52.0),
		"ACTUAL city AStar detours original closure and restores 52m direct route")
	print("CITY REIGN R188 ORIGINAL SOURCE ROADWORK: %d PASS %d FAIL" %
		[pass_count,fail_count])
	quit(0 if fail_count==0 else 1)
