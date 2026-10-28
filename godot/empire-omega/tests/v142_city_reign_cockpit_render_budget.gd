extends SceneTree
## R164: guard the 3-draw, no-reallocation cockpit and reduced-motion,
## with actual Godot instances (not a mocked static screenshot).
const CAR = preload("res://scripts/vehicle_controller.gd")
const POV = preload("res://scripts/city_reign_cockpit_camera.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
    if ok:
        passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R164 COCKPIT BUDGET FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var car: CharacterBody3D = CAR.new()
    root.add_child(car)
    car.set_physics_process(false)
    var original_collider: CollisionShape3D = car.get_child(0) as CollisionShape3D
    var chassis: Node3D = car.get("horizon_visual")
    var room: Node3D = chassis.get_node("CockpitInterior") as Node3D
    var first_meshes: Array[Mesh] = [
        (room.get_node("PhysicalDashboard") as MeshInstance3D).mesh,
        (room.get_node("SteeringWheel") as MeshInstance3D).mesh,
        (room.get_node("ActualSpeedNeedle") as MeshInstance3D).mesh
    ]
    var windscreen: MeshInstance3D = chassis.get_node("SlopedWindshield") as MeshInstance3D
    var greenhouse: MeshInstance3D = chassis.get_node("AerodynamicGreenhouse") as MeshInstance3D
    for switch in range(100):
        var inside: bool = switch%2==0
        chassis.call("set_cockpit_active",inside)
        chassis.call("set_cockpit_data",float(switch)*0.3,sin(float(switch)*0.04))
        check(room.visible==inside and windscreen.visible!=inside and greenhouse.visible!=inside,
            "100 real V-style transitions keep interior/road visibility correct")
    check(int(room.get("mesh_builds"))==3,
        "100 camera changes create exactly zero new 3D draw meshes")
    check((room.get_node("PhysicalDashboard") as MeshInstance3D).mesh==first_meshes[0] and
        (room.get_node("SteeringWheel") as MeshInstance3D).mesh==first_meshes[1] and
        (room.get_node("ActualSpeedNeedle") as MeshInstance3D).mesh==first_meshes[2],
        "GPU meshes reused instead of allocating on each camera transition")
    check(car.get_child(0)==original_collider and
        original_collider.shape is BoxShape3D,
        "original physics car collision is never touched")
    for yaw in [-PI,0.0,PI*0.5]:
        car.rotation.y = yaw
        for mobile in [false,true]:
            check(POV.valid_transform(car.global_transform,mobile),
                "actual moving 3D eye remains finite across car yaw and mobile aspect")
    check(not POV.enabled("street",true,false,false),
        "cockpit meshes cannot leak into existing R160 cameras")
    var status: Node = root.get_node_or_null("GameState")
    check(status!=null,"original mission/save authority unchanged")
    car.queue_free()
    await process_frame
    print("CITY REIGN R164 REAL 3D COCKPIT BUDGET: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
