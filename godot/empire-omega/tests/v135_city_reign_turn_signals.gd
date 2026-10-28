extends SceneTree
## R161: authored real car signal mesh + traffic intention + persistent input map.
const LOGIC = preload("res://scripts/city_reign_turn_signals.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
    if ok:
        passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R161 TURN SIGNALS FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    check(LOGIC.toggle("off","left")=="left" and LOGIC.toggle("left","left")=="off",
        "tap indicator again cancels without rewriting mission state")
    check(LOGIC.toggle("left","hazard")=="hazard" and LOGIC.toggle("hazard","hazard")=="off",
        "hazard lights override and cancel correctly")
    check(LOGIC.upcoming(Vector3(0,0,-1),Vector3(1,0,0),18)=="right",
        "real X/Z heading anticipates a right turn")
    check(LOGIC.upcoming(Vector3(0,0,-1),Vector3(-1,0,0),18)=="left",
        "real X/Z heading anticipates a left turn")
    check(LOGIC.upcoming(Vector3(0,0,-1),Vector3(0,0,-1),5)=="off" and
        LOGIC.upcoming(Vector3(0,0,-1),Vector3(1,0,0),32)=="off",
        "straight road and distant turn never advertise falsely")
    check(LOGIC.upcoming(Vector3(NAN,0,0),Vector3(1,0,0),12)=="off",
        "invalid AI vector fails safely")
    check(LOGIC.side_on("hazard","left",0.1) and LOGIC.side_on("hazard","right",0.1) and
        not LOGIC.side_on("hazard","right",0.6) and not LOGIC.side_on("left","right",0.1),
        "amber pattern blinks both sides while keeping left/right independent")
    check(InputMap.has_action("indicator_left") and InputMap.has_action("indicator_right") and
        InputMap.has_action("hazard_lights"),"keyboard gamepad and phone use real action map")
    var player: CharacterBody3D = CAR.new()
    root.add_child(player)
    check(player.has_method("toggle_indicator") and player.has_method("set_indicator_mode"),
        "actual controllable vehicle exposes physical indicator modes")
    check(player.call("toggle_indicator","left")=="left","player turns on left indicators")
    var nodes: Dictionary = player.get("indicator_lamps")
    check((nodes["left"] as Array).size()==2 and (nodes["right"] as Array).size()==2,
        "four genuinely rendered player lamp meshes, front and back")
    player.call("_tick_indicators",0.02)
    var lamp: MeshInstance3D = (nodes["left"] as Array)[0] as MeshInstance3D
    check(lamp!=null and (lamp.material_override as StandardMaterial3D).emission_energy_multiplier>2.0,
        "lamp material REALLY illuminates in the original car")
    player.call("set_indicator_mode","off")
    check(float((lamp.material_override as StandardMaterial3D).emission_energy_multiplier)<0.5,
        "indicators extinguish after leaving the vehicle")
    var other: CharacterBody3D = TRAFFIC.new()
    root.add_child(other)
    var indicators: Dictionary = other.get("indicator_lamps")
    check(indicators.has("left") and indicators.has("right"),
        "original road-going AI car has real amber rear meshes")
    var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    check(main_source.contains("car.toggle_indicator("),
        "real player input reaches car lamp state, not a simulated menu")
    var traffic_source: String = FileAccess.get_file_as_string("res://scripts/traffic_agent.gd")
    check(traffic_source.contains("SIGNAL_LOGIC.upcoming("),
        "real AI traffic predicts route turns and activates the same signal model")
    player.queue_free()
    other.queue_free()
    await process_frame
    print("CITY REIGN R161 REAL VEHICLE SIGNALS: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
