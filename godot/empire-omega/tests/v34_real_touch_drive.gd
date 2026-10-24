extends SceneTree
## HORIZON R11: engine-level end-to-end two-finger input to genuine moving
## CharacterBody3D car. Unlike the earlier R6 contract this actually injects
## touchscreen events, advances physics, measures velocity, distance and yaw.
const TOUCH = preload("res://scripts/horizon_touch_controls.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func check(condition: bool, label: String) -> void:
    if condition:
        passed += 1
    else:
        failed += 1
        push_error("R11 REAL TOUCH DRIVE: "+label)

func _initialize() -> void:
    call_deferred("_run")

func touch_at(button: TouchScreenButton) -> Vector2:
    return button.position + Vector2.ONE * (48.0 * button.scale.x)

func send_touch(button: TouchScreenButton, finger: int, is_pressed: bool) -> void:
    var event := InputEventScreenTouch.new()
    event.index = finger
    event.position = touch_at(button)
    event.pressed = is_pressed
    Input.parse_input_event(event)

func frames(count: int) -> void:
    for i in range(count):
        await physics_frame

func _run() -> void:
    var floor := StaticBody3D.new()
    floor.name = "DrivingTestGround"
    floor.collision_layer = 1
    floor.position = Vector3(0.0,-1.0,0.0)
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(250,2,250)
    collider.shape = shape
    floor.add_child(collider)
    root.add_child(floor)
    var car: CharacterBody3D = CAR.new()
    root.add_child(car)
    car.position = Vector3(0.0,1.4,0.0)
    car.driving = true
    var pad: CanvasLayer = TOUCH.new()
    root.add_child(pad)
    pad.call("set_preview",true)
    pad.call("set_mode",true,false)
    var gas: TouchScreenButton = pad.get_node("Touch_move_forward") as TouchScreenButton
    var steer: TouchScreenButton = pad.get_node("Touch_move_left") as TouchScreenButton
    check(gas != null and steer != null,"real native touch surfaces exist")
    await frames(5)
    check(not Input.is_action_pressed("move_forward"),"gas starts released")
    var initial: Vector3 = car.global_position
    send_touch(gas,0,true)
    await frames(2)
    check(Input.is_action_pressed("move_forward"),"actual touchscreen press reaches InputMap gas")
    await frames(65)
    check(float(car.get("speed")) > 3.0,"gas actually accelerates physical vehicle")
    check(car.global_position.distance_to(initial)>2.5,"car covers physical distance, not just HUD animation")
    check(float(car.get("mileage"))>2.5,"authoritative odometer follows physical displacement")
    var yaw_before: float = car.rotation.y
    send_touch(steer,1,true)
    await frames(50)
    check(Input.is_action_pressed("move_forward") and Input.is_action_pressed("move_left"),"two independent fingers can accelerate and steer simultaneously")
    check(absf(car.rotation.y-yaw_before)>0.10,"second finger truly turns dynamic car")
    var position_before: Vector3 = car.global_position
    await frames(12)
    check(car.global_position.distance_to(position_before)>0.6,"multitouch driving continues across physics frames")
    send_touch(steer,1,false)
    send_touch(gas,0,false)
    await frames(3)
    check(not Input.is_action_pressed("move_forward") and not Input.is_action_pressed("move_left"),"real finger release stops held actions")
    send_touch(gas,2,true)
    await frames(2)
    check(Input.is_action_pressed("move_forward"),"second gas gesture works after release")
    pad.call("set_mode",true,true)
    await frames(2)
    check(not gas.visible and not steer.visible,"modal dialog hides both drive inputs")
    check(not Input.is_action_pressed("move_forward"),"hiding controls releases held acceleration immediately")
    send_touch(gas,2,false)
    await frames(2)
    pad.call("set_mode",true,false)
    check(gas.visible and steer.visible,"closing modal restores native touches")
    car.queue_free()
    pad.queue_free()
    floor.queue_free()
    print("HORIZON R11 REAL TOUCH DRIVE NATIVE: %d passed, %d failed" % [passed,failed])
    quit(0 if failed==0 else 1)
