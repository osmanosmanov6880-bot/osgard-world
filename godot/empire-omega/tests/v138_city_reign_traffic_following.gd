extends SceneTree
const FOLLOW = preload("res://scripts/city_reign_traffic_following.gd")
const CAR = preload("res://scripts/traffic_agent.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
    if ok: passed+=1
    else:
        failed+=1
        push_error("R163 ACTUAL TRAFFIC FOLLOWING FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var fwd := Vector3(0,0,-1)
    var origin := Vector3.ZERO
    var stationary := FOLLOW.speed_cap(origin,fwd,12,Vector3(0,0,-16),
        Vector3.ZERO,12,1.0)
    check(stationary<12 and stationary>=0,"same lane stationary vehicle calms traffic")
    check(FOLLOW.speed_cap(origin,fwd,12,Vector3(4,0,-16),Vector3.ZERO,12,1.0)==12,
        "adjacent lane does not create phantom car following")
    check(FOLLOW.speed_cap(origin,fwd,12,Vector3(0,0,16),Vector3.ZERO,12,1.0)==12,
        "vehicles behind are ignored")
    check(FOLLOW.speed_cap(origin,fwd,12,Vector3(0,0,-65),Vector3.ZERO,12,1.0)==12,
        "distant traffic is outside exact bounded traffic query")
    check(FOLLOW.speed_cap(origin,fwd,12,Vector3(0,0,-16),Vector3(0,0,10),12,1.0)==12,
        "oncoming cars are handled by original physics ray, not following")
    check(FOLLOW.speed_cap(origin,fwd,12,Vector3(0,0,-16),Vector3(0,0,-10),12,1.0)>stationary,
        "moving leader creates smoother actual convoy flow")
    var dry := FOLLOW.speed_cap(origin,fwd,12,Vector3(0,0,-27),Vector3.ZERO,12,1.0)
    var wet := FOLLOW.speed_cap(origin,fwd,12,Vector3(0,0,-27),Vector3.ZERO,12,0.45)
    check(wet<=dry,"rain never increases safe following speed")
    check(FOLLOW.speed_cap(origin,fwd,12,Vector3(NAN,0,-16),Vector3.ZERO,12,1)==12,
        "invalid leader coordinate cannot produce corrupted motion")
    var lead: CharacterBody3D = CAR.new()
    root.add_child(lead)
    lead.set_physics_process(false)
    lead.global_position=Vector3(0,0,-17)
    lead.velocity=Vector3.ZERO
    var follower: CharacterBody3D = CAR.new()
    root.add_child(follower)
    follower.set_physics_process(false)
    follower.global_position=Vector3.ZERO
    follower.set("neighbors",[follower,lead])
    var agents: Array = follower.get("neighbors")
    var result := FOLLOW.scan(follower,agents,fwd,12,12,1.0)
    check(result<12 and result>=0,
        "actual Godot traffic Agent checks a real spawned neighboring vehicle")
    check(follower.get("neighbors").size()==2,
        "following reads node identities without mutating road scene")
    lead.global_position=Vector3(5,0,-17)
    check(absf(FOLLOW.scan(follower,agents,fwd,12,12,1.0)-12)<0.01,
        "real car outside lane restores original cruise")
    var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    var ai_source: String = FileAccess.get_file_as_string("res://scripts/traffic_agent.gd")
    check(main_source.contains("traffic.neighbors = ambient_cars") and
        ai_source.contains("FOLLOW.scan("),
        "original playable 12-car traffic scene consumes actual collision-safe follower cap")
    lead.queue_free()
    follower.queue_free()
    await process_frame
    print("CITY REIGN R163 PHYSICAL TRAFFIC FOLLOWING: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
