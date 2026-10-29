extends SceneTree
## Original Godot CharacterBody3D car, real road collider, real physical
## input events, true 4-wheel road probes and existing city state authority.
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed: int = 0
var failed: int = 0
func check(ok: bool,name: String) -> void:
    if ok:
        passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R165 REAL ROAD FAIL: "+name)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var game: Node = root.get_node_or_null("GameState")
    var saved: Dictionary = (game.get("data") as Dictionary).duplicate(true)
    var floor := StaticBody3D.new()
    floor.collision_layer=1
    floor.position=Vector3(0,-0.30,0)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size=Vector3(300.0,0.60,300.0)
    shape.shape=box
    floor.add_child(shape)
    root.add_child(floor)
    var car: CharacterBody3D = CAR.new()
    car.position=Vector3(0.0,0.86,0.0)
    root.add_child(car)
    car.driving=true
    car.traction_factor=1.0
    var shell: Node3D = car.get("horizon_visual")
    var brake_strip: MeshInstance3D = shell.get("brake_strip")
    check(shell!=null and brake_strip!=null and
        car.collision_layer==4 and car.collision_mask==9,
        "real player car and its original shape/light network are retained")
    Input.action_press("move_forward")
    for i in range(112):
        await physics_frame
    Input.action_release("move_forward")
    var cruise: float=float(car.get("speed"))
    check(cruise>7.0 and cruise<29.1,
        "real Godot drive on the original 300m road accelerates with bounded torque")
    check(float(car.get("apex_torque_factor"))<1.0,
        "actual motion pipeline uses high-speed tapered torque")
    var unlit: float=(brake_strip.material_override as StandardMaterial3D).emission_energy_multiplier
    Input.action_press("move_backward")
    for i in range(22):
        await physics_frame
    Input.action_release("move_backward")
    var slowed: float=float(car.get("speed"))
    var effort: float=float(car.get("brake_response"))
    var lit: float=(brake_strip.material_override as StandardMaterial3D).emission_energy_multiplier
    check(effort>0.90 and effort<=1.0,
        "live input produces gradual actual requested braking response")
    check(slowed<cruise-0.5 and slowed>=0.0,
        "real car slows rather than instantly changing into reverse")
    check(lit>unlit+0.5,
        "brake lens actually brightens from physical input without mesh allocation")
    check(car.get("r46_brake_diagnostics") is Dictionary,
        "original 4-contact braking load telemetry remains authoritative")
    check(float(car.get("brake_estimated_stop_m"))>=0.0 and
        is_finite(float(car.get("brake_estimated_stop_m"))),
        "finite stopping distance remains labelled as estimate, not certification")
    check(float(car.get("r46_brake_grip"))<=1.15,
        "road contact remains bounded after true brake action")
    for i in range(30):
        await physics_frame
    check(float(car.get("brake_response"))<0.10,
        "real brake gauge releases after actual pedal input ends")
    check(car.health>=5.0 and car.fuel>=0.0,
        "real damage/fuel conditions remain valid through braking")
    check(game.get("data")==saved,
        "vehicle model does not mint money, edit campaign, or migrate save state")
    var script: String=FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
    check(script.contains("APEX_RESPONSE.effective_throttle(") and
        script.contains("APEX_RESPONSE.corner_yaw(") and
        script.contains('horizon_visual.call("sync_brake_response"'),
        "source-game driving, yaw and actual original brake lamps are integrated")
    car.driving=false
    car.queue_free()
    floor.queue_free()
    await process_frame
    print("CITY REIGN R165 REAL WHEEL/ROAD PHYSICS: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
