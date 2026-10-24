extends SceneTree
## R10 native acceptance against REAL A* city routes + deterministic synthetic
## road detours. No race economy or checkpoints are writable through this API.
const GUIDE = preload("res://scripts/horizon_road_guidance.gd")
const MOBILITY = preload("res://scripts/city_mobility.gd")
const RACES = preload("res://scripts/driving_trials.gd")
const R9 = preload("res://scripts/horizon_race_navigator.gd")
var passed := 0
var failed := 0

func check(ok: bool, message: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R10 ROAD QA: "+message)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var base := {"distance":104.0,"seconds":42,"direction":"STRAIGHT",
		"details":"STRAIGHT · 104 m · 42 s","title":"ACADEMY 1/4"}
	var car := Vector3.ZERO
	var gate := Vector3(0.0,0.0,-104.0)
	var detour: Array[Vector3] = [car,Vector3(52,0,0),Vector3(52,0,-52),Vector3(0,0,-52),gate]
	var original: Dictionary = base.duplicate(true)
	var guide: Dictionary = GUIDE.decorate(base,car,0.0,gate,detour,"ru")
	check(str(guide.get("direction",""))=="НАПРАВО","turn follows a REAL road detour, not direct gate bearing")
	check(str(guide.get("road_status",""))=="routed","A* road route is acknowledged")
	check(absf(float(guide.get("road_distance",0.0))-208.0)<0.1,"full remaining road distance rather than 104 m straight line")
	check(str(guide.get("details","")).contains("208 м"),"HUD shows road travel length")
	check(str(guide.get("details","")).contains("42 с"),"timer is preserved verbatim")
	check(base==original,"pure guidance never modifies trial, score or objective")
	var en: Dictionary = GUIDE.decorate(base,car,0.0,gate,detour,"en")
	check(en.get("direction","")=="RIGHT","English road turn")
	var zh: Dictionary = GUIDE.decorate(base,car,0.0,gate,detour,"zh")
	check(zh.get("direction","")=="右转","Chinese road turn")
	var unknown: Dictionary = GUIDE.decorate(base,car,0.0,gate,detour,"zz")
	check(unknown.get("direction","")=="НАПРАВО","safe locale fallback")
	var heading_back: Dictionary = GUIDE.decorate(base,car,PI,gate,detour,"en")
	check(heading_back.get("direction","")=="LEFT","vehicle yaw changes the relative navigation")
	var empty: Array[Vector3] = []
	check(GUIDE.decorate(base,car,0.0,gate,empty)==base,"not-yet-calculated road route preserves R9 direct guidance")
	var broken: Array[Vector3] = [car]
	var blocked: Dictionary = GUIDE.decorate(base,car,0.0,gate,broken,"en")
	check(blocked.get("direction","")=="ROAD BLOCKED","disconnected A* graph never invents a straight route")
	check(blocked.get("road_status","")=="blocked","closure is an explicit state")
	check(str(blocked.get("details","")).contains("42"),"road closure does not freeze race clock")
	var near := base.duplicate(true)
	near["distance"] = 4.0
	check(GUIDE.decorate(near,car,0.0,gate,broken,"en")==near,"inside real gate overrides road-closure hint")
	var stale: Array[Vector3] = [Vector3(120,0,0),Vector3(120,0,-104),gate]
	check(GUIDE.decorate(base,car,0.0,gate,stale,"en")==base,"stale route for previous vehicle position rejected")
	var wrong_goal: Array[Vector3] = [car,Vector3(52,0,0),Vector3(52,0,-52)]
	check(GUIDE.decorate(base,car,0.0,gate,wrong_goal,"en")==base,"route to a different old mission rejected")
	var offroad: Array[Vector3] = [Vector3(25,0,0),Vector3(52,0,0),Vector3(52,0,-52),gate]
	check(GUIDE.decorate(base,Vector3(-100,0,0),0.0,gate,offroad,"en")==base,"can't claim GPS guidance when car off route")
	var nanpath: Array[Vector3] = [car,Vector3(NAN,0,0),gate]
	check(GUIDE.decorate(base,car,0.0,gate,nanpath,"ru")==base,"nonfinite broken road geometry safely ignored")
	check(GUIDE.decorate(base,car,NAN,gate,detour,"ru")==base,"invalid heading does not generate instructions")
	check(GUIDE.decorate({},car,0.0,gate,detour,"ru").is_empty(),"no fake race from inactive save")
	var routes: Array = RACES.catalog()
	check(routes.size()>=4,"genuine driving academy routes are loaded")
	for route in routes:
		var gate0: Vector3 = RACES.checkpoint(route,0)
		var start := gate0 + Vector3(30,0,60)
		var state := {"step":0,"elapsed":12.0}
		var a: Dictionary = R9.view(route,state,start,0.0,"ru")
		var road: Array[Vector3] = MOBILITY.find_route(start,gate0,{"turn":1,"seed":781413,"road_quality":75,"roads_cleared":[]})
		check(road.size()>=2,"A* finds navigable road grid to real academy "+str(route["id"]))
		if road.size()>=2:
			var linked: Dictionary = GUIDE.decorate(a,start,0.0,gate0,road,"ru")
			check(not linked.is_empty() and linked.get("checkpoint",0)==1,"road hint preserves authoritative gate count "+str(route["id"]))
			check(linked.get("seconds",0)==int(route["limit_seconds"])-12,"real race clock never changes "+str(route["id"]))
			check(not state.has("wallet") and int(state["step"])==0,"navigation cannot issue fictional rewards "+str(route["id"]))
	var hud: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(hud.contains("ROAD_GUIDE.decorate(guide,vehicle_at,vehicle_yaw,goal_at,map.route,GameState.locale)"),"live 3D HUD consumes the cached A* route")
	check(main.contains("hud.map.route = ROUTER.find_route(protagonist,goal,GameState.data)"),"live route uses real road closures from GameState")
	print("HORIZON R10 ROAD NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
