extends SceneTree
## R162: actual car and pedestrian Node3Ds, real velocity data, no spoof.
const SENSE = preload("res://scripts/city_reign_driver_awareness.gd")
const TRAFFIC = preload("res://scripts/traffic_agent.gd")
const WALKER = preload("res://scripts/pedestrian_agent.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
    if ok: passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R162 DRIVER AWARENESS FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    check(SENSE.inspect(Vector3(0,0,-12),Vector3(0,0,-1),13,
        Vector3.ZERO,"vehicle").get("urgency","")=="urgent",
        "parked vehicle at actual stopping distance is urgent")
    check(SENSE.inspect(Vector3(5,0,-12),Vector3(0,0,-1),13,
        Vector3.ZERO,"vehicle").is_empty(),
        "adjacent lane does not trigger false collision")
    check(SENSE.inspect(Vector3(0,0,-12),Vector3(0,0,-1),13,
        Vector3(0,0,-18),"vehicle").is_empty(),
        "vehicle pulling away faster gives no warning")
    check(SENSE.inspect(Vector3(0,0,8),Vector3(0,0,-1),13,
        Vector3.ZERO,"pedestrian").is_empty(),
        "walker behind the player is ignored")
    check(SENSE.inspect(Vector3(NAN,0,0),Vector3(0,0,-1),12,
        Vector3.ZERO,"vehicle").is_empty(),
        "malformed sensor vectors fail closed")
    var car: CharacterBody3D = TRAFFIC.new()
    root.add_child(car)
    car.set_physics_process(false)
    car.global_position=Vector3(0,0,-18)
    car.velocity=Vector3.ZERO
    var pedestrian: Node3D = WALKER.new()
    pedestrian.set("citizen_id",9)
    root.add_child(pedestrian)
    pedestrian.set_process(false)
    pedestrian.global_position=Vector3(0,0,-10)
    pedestrian.set("planned_velocity",Vector3.ZERO)
    var traffic: Array = [car]
    var people: Array = [pedestrian]
    var dangerous: Dictionary = SENSE.scan(Vector3.ZERO,0.0,12.0,traffic,people)
    check(str(dangerous.get("kind",""))=="pedestrian",
        "real visible crossing citizen outranks a more distant parked car")
    check(SENSE.localized(dangerous,"ru").contains("ПЕШЕХОД") and
        SENSE.localized(dangerous,"en").contains("PEDESTRIAN") and
        SENSE.localized(dangerous,"zh").contains("行人"),
        "three language driver warnings carry actual object class")
    pedestrian.visible=false
    car.global_position=Vector3(0,0,-12)
    var driving_risk: Dictionary = SENSE.scan(Vector3.ZERO,0.0,12,traffic,people)
    check(driving_risk.get("kind","")=="vehicle",
        "real visible road car still triggers warning")
    car.global_position=Vector3(4.5,0,-12)
    check(SENSE.scan(Vector3.ZERO,0.0,12,traffic,people).is_empty(),
        "outside player lane gives no phantom warning")
    car.global_position=Vector3(0,0,-12)
    check(SENSE.scan(Vector3.ZERO,0.0,2,traffic,people).is_empty(),
        "advisor stays silent when player almost stopped")
    var main_src: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    var hud_src: String = FileAccess.get_file_as_string("res://scripts/hud.gd")
    check(main_src.contains("DRIVER_SENSE.scan(") and hud_src.contains("DRIVER_SENSE.localized("),
        "native sensor connects to ACTUAL gameplay/HUD, not imaginary overlay")
    car.queue_free()
    pedestrian.queue_free()
    await process_frame
    print("CITY REIGN R162 NATIVE TRAFFIC AWARENESS: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
