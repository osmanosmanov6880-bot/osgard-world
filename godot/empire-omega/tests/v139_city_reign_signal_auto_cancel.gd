extends SceneTree
const CANCEL = preload("res://scripts/city_reign_signal_cancel.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func check(ok: bool,why: String) -> void:
    if ok: passed+=1
    else:
        failed+=1
        push_error("R163 PHYSICAL TURN CANCEL FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    check(CANCEL.progress("left",0,0.9,0.0,5.5,9)>0.8,
        "actual leftward Godot vehicle yaw builds physical progress")
    check(CANCEL.progress("right",0,-0.9,0.0,5.5,9)>0.8,
        "real right-turn heading rotates negative in this game controller")
    check(CANCEL.progress("left",0,-0.9,0.0,5.5,9)==0,
        "an unintended opposite maneuver cannot cancel an indicator")
    check(CANCEL.progress("left",3.0,-3.0,0.0,6,9)>0.2,
        "rotation wrap at the 180-degree boundary is handled")
    check(not CANCEL.completed("hazard",2.0,40,0,20),
        "emergency hazards NEVER cancel on actual road turns")
    check(not CANCEL.completed("left",1.0,25,0.6,10),
        "indicator stays on until steering wheel recenters")
    check(not CANCEL.completed("right",1.0,3,0,10),
        "turn with no physical road movement never clears signal")
    var player: CharacterBody3D = CAR.new()
    root.add_child(player)
    player.set_physics_process(false)
    player.speed=9.0
    player.rotation.y=0.0
    player.call("set_indicator_mode","right")
    player.rotation.y=-0.54
    player.call("_update_indicator_turn",3.0,0.6)
    check(player.get("indicator_mode")=="right",
        "real auto-cancel waits for motion and steering centering")
    player.rotation.y=-1.02
    player.call("_update_indicator_turn",4.0,0.0)
    check(player.get("indicator_mode")=="off",
        "real CAR indicator turns off automatically after a completed maneuver")
    player.call("set_indicator_mode","hazard")
    player.rotation.y=1.0
    player.call("_update_indicator_turn",12.0,0.0)
    check(player.get("indicator_mode")=="hazard",
        "hazards persist through vehicle rotation, never auto-cancel")
    player.call("set_indicator_mode","off")
    var source: String = FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
    check(source.contains("_update_indicator_turn(covered,applied_steering)"),
        "actual driving physics calls auto-cancel on REAL covered distance")
    player.queue_free()
    await process_frame
    print("CITY REIGN R163 REAL AUTO CANCEL: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
