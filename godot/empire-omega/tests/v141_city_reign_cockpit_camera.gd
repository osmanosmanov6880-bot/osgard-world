extends SceneTree
## R164: prove the actual player car renders a real 3D cockpit with
## one camera, steering animation and four persistent RU/EN/ZH lenses.
const CAMERA_MODES = preload("res://scripts/city_reign_camera_modes.gd")
const INTERIOR_CAMERA = preload("res://scripts/city_reign_cockpit_camera.gd")
const PLAYER_CAR = preload("res://scripts/vehicle_controller.gd")
var passed: int = 0
var failed: int = 0

func check(ok: bool,why: String) -> void:
    if ok:
        passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R164 REAL COCKPIT FAIL: "+why)

func _initialize() -> void:
    call_deferred("_run")

func _run() -> void:
    var settings: Node = root.get_node_or_null("GameSettings")
    var game: Node = root.get_node_or_null("GameState")
    check(settings!=null and game!=null,"existing preferences and financial GameState autoload")
    if settings==null or game==null:
        quit(2)
        return
    var original_state: Dictionary = (game.get("data") as Dictionary).duplicate(true)
    var old_camera: String = str(settings.get("camera_mode"))
    check(CAMERA_MODES.bounded() and CAMERA_MODES.MODES.size()==4,
        "three existing game cameras plus true cockpit share the same source")
    check(CAMERA_MODES.next_mode("panorama")=="cockpit" and
        CAMERA_MODES.next_mode("cockpit")=="street",
        "original V keyboard/gamepad/touch cycle includes cockpit without losing modes")
    for lang in ["ru","en","zh"]:
        check(not CAMERA_MODES.localized_mode("cockpit",lang).is_empty(),
            "cockpit is localized for all three existing languages: "+lang)
    settings.call("set_camera_mode","cockpit")
    check(str(settings.get("camera_mode"))=="cockpit",
        "the exact native settings system saves the fourth mode")
    check(InputMap.has_action("camera_cycle"),
        "original keyboard and physical gamepad V action remains available")
    var car: CharacterBody3D = PLAYER_CAR.new()
    root.add_child(car)
    car.set_physics_process(false)
    car.rotation.y = 0.7
    car.global_position = Vector3(12.0,1.2,-14.0)
    var chassis: Node3D = car.get("horizon_visual")
    check(chassis!=null,"original Horizon 3D car owns its own cockpit visuals")
    if chassis==null:
        quit(2)
        return
    var room: Node3D = chassis.get_node_or_null("CockpitInterior") as Node3D
    check(room!=null,"3D interior genuinely exists within player vehicle")
    if room==null:
        quit(2)
        return
    check(not room.visible and int(room.get("mesh_builds"))==3,
        "outside view has zero cockpit renders; interior builds only 3 meshes once")
    var dash: MeshInstance3D = room.get_node("PhysicalDashboard") as MeshInstance3D
    var wheel: MeshInstance3D = room.get_node("SteeringWheel") as MeshInstance3D
    var needle: MeshInstance3D = room.get_node("ActualSpeedNeedle") as MeshInstance3D
    check(dash.mesh!=null and wheel.mesh!=null and needle.mesh!=null,
        "dashboard, steering wheel and analog speed needle have physical triangle meshes")
    check(dash.mesh.get_surface_count()==1 and wheel.mesh.get_surface_count()==1 and
        needle.mesh.get_surface_count()==1,"three original mesh surfaces, no emissive lights")
    var original_shell: MeshInstance3D = chassis.get_node("AerodynamicGreenhouse") as MeshInstance3D
    var original_glass: MeshInstance3D = chassis.get_node("SlopedWindshield") as MeshInstance3D
    var original_shape: Mesh = original_shell.mesh
    check(original_shell.visible and original_glass.visible,
        "all original exterior glass and sports car paint are intact")
    var transform: Transform3D = car.global_transform
    for phone in [false,true]:
        var eye: Vector3 = INTERIOR_CAMERA.eye(transform,phone)
        var looking: Vector3 = INTERIOR_CAMERA.target(transform,phone)
        check(INTERIOR_CAMERA.valid_transform(transform,phone) and
            eye.distance_to(looking)>15.0 and eye.distance_to(looking)<30.0,
            "real driver eye is a stable bounded Godot 3D viewpoint")
        var relative: Vector3 = transform.affine_inverse()*eye
        check(relative.x<0.0 and relative.y>0.35 and relative.y<0.75,
            "eye sits in original left-hand physical driver's seat")
        check(INTERIOR_CAMERA.fov(phone)>=69.0 and INTERIOR_CAMERA.fov(phone)<=74.0,
            "desktop/mobile avoid the earlier wide-angle fish-eye")
    check(INTERIOR_CAMERA.enabled("cockpit",true,false,false) and
        not INTERIOR_CAMERA.enabled("cockpit",false,false,false) and
        not INTERIOR_CAMERA.enabled("cockpit",true,true,false) and
        not INTERIOR_CAMERA.enabled("cockpit",true,false,true),
        "dashboard only while actually driving with no cabinet or interior overlay")
    chassis.call("set_cockpit_active",true)
    check(room.visible and not original_shell.visible and not original_glass.visible,
        "3D cockpit reveals road by temporarily occluding opaque greenhouse")
    chassis.call("set_cockpit_data",18.0,0.8)
    check(absf(float(wheel.rotation.z))>0.2 and absf(float(needle.rotation.z))>0.15,
        "3D wheel and instrument respond to REAL car motion data")
    chassis.call("set_cockpit_active",false)
    check(not room.visible and original_shell.visible and original_glass.visible,
        "exiting car or selecting previous camera restores the whole actual shell")
    check(original_shell.mesh==original_shape,
        "original garage vehicle geometry has never been replaced or overwritten")
    check(game.get("data")==original_state,
        "camera/interior updates do not mutate economy, missions, mileage or save")
    var main_source: String = FileAccess.get_file_as_string("res://scripts/main.gd")
    check(main_source.contains("COCKPIT_VIEW.eye(car.global_transform") and
        main_source.contains("set_cockpit_active"),
        "true rendered scene Camera3D consumes actual car Transform3D and mesh visibility")
    settings.call("set_camera_mode",old_camera)
    car.queue_free()
    await process_frame
    print("CITY REIGN R164 PHYSICAL 3D COCKPIT: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
