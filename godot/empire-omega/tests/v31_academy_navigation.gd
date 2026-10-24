extends SceneTree
## Native R9: checkpoint directions reflect real world coordinates and actual
## academy data. UI must never alter awards, positions or the race state.
const NAV = preload("res://scripts/horizon_race_navigator.gd")
const ROUTES = preload("res://scripts/driving_trials.gd")
var passed := 0
var failed := 0
func check(ok: bool, message: String) -> void:
    if ok: passed += 1
    else:
        failed += 1
        push_error("HORIZON R9 ACADEMY: "+message)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var routes: Array = ROUTES.catalog()
    check(routes.size() >= 4,"real academy catalog loaded")
    for route in routes:
        var coords: Vector3 = ROUTES.checkpoint(route,0)
        var active := {"step":0,"elapsed":10.0}
        var state_before: Dictionary = active.duplicate(true)
        var response: Dictionary = NAV.view(route,active,coords+Vector3(0,0,32),0.0,"ru",true)
        check(not response.is_empty(), "valid state creates directional guidance "+str(route["id"]))
        check(str(response.get("direction",""))=="ПРЯМО","towards -Z is forward "+str(route["id"]))
        check(response.get("checkpoint",0)==1,"first waypoint index "+str(route["id"]))
        check(response.get("total",0)==route["checkpoints"].size(),"actual waypoint count "+str(route["id"]))
        check(response.get("seconds",-1)==int(route["limit_seconds"])-10,"actual time countdown "+str(route["id"]))
        check((response.get("distance",0.0) as float)>31.0,"actual measured goal distance "+str(route["id"]))
        check(str(response.get("title","")).contains("1/%d" % route["checkpoints"].size()),"compact title shows progress "+str(route["id"]))
        check(str(response.get("details","")).length()<38,"mobile detail remains concise "+str(route["id"]))
        check(active==state_before,"view does not mutate monetary or authoritative race state "+str(route["id"]))
    var route: Dictionary = routes[0]
    var goal: Vector3 = ROUTES.checkpoint(route,0)
    var state := {"step":0,"elapsed":0.0}
    check(NAV.view(route,state,goal+Vector3(-40,0,0),0.0,"ru").get("direction","")=="НАПРАВО","right of car")
    check(NAV.view(route,state,goal+Vector3(40,0,0),0.0,"ru").get("direction","")=="НАЛЕВО","left of car")
    check(NAV.view(route,state,goal+Vector3(0,0,-40),0.0,"ru").get("direction","")=="РАЗВОРОТ","behind the vehicle")
    check(NAV.view(route,state,goal,0.0,"ru").get("direction","")=="ТОЧКА","inside checkpoint gate")
    check(NAV.view(route,state,goal+Vector3(0,0,35),0.0,"en").get("direction","")=="STRAIGHT","English directions")
    check(NAV.view(route,state,goal+Vector3(0,0,35),0.0,"zh").get("direction","")=="直行","Chinese directions")
    var advanced := {"step":1,"elapsed":5.1}
    var next: Dictionary = NAV.view(route,advanced,goal,0.0,"en",false)
    check(next.get("checkpoint",0)==2,"progress updates with actual state")
    check(next.get("seconds",0)==int(route["limit_seconds"])-6,"countdown rounds up elapsed seconds")
    check(NAV.view(route,{"step":999},goal,0.0).is_empty(),"out-of-range waypoint rejected")
    check(NAV.view({},state,goal,0.0).is_empty(),"missing route rejected")
    check(NAV.view(route,{},goal,0.0).is_empty(),"missing active session rejected")
    var hud: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
    var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    check(hud.contains("RACE_NAVIGATOR.view(route,session,vehicle_at,vehicle_yaw,GameState.locale,compact_hud)"),"live HUD receives actual academy state")
    check(hud.contains("mission_distance_label.text = str(guide[\"details\"])"),"live HUD shows direction and clock")
    check(main.contains("car.steering_assist_correction,car.rotation.y)"),"live main passes actual car heading")
    print("HORIZON R9 ACADEMY NATIVE: %d passed, %d failed" % [passed,failed])
    quit(0 if failed==0 else 1)
