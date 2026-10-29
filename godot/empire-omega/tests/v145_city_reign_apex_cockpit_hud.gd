extends SceneTree
## R165 premium feedback: existing three original interior draw meshes
## and the existing single original brake-strip material, no new draws.
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed: int = 0
var failed: int = 0
func check(ok: bool,reason: String) -> void:
    if ok:
        passed+=1
    else:
        failed+=1
        push_error("CITY REIGN R165 PREMIUM BRAKE FEEDBACK FAIL: "+reason)
func _initialize() -> void:
    call_deferred("_run")
func _run() -> void:
    var car: CharacterBody3D=CAR.new()
    root.add_child(car)
    car.set_physics_process(false)
    var chassis: Node3D=car.get("horizon_visual")
    var cockpit: Node3D=chassis.get("cockpit_interior")
    var needle: MeshInstance3D=cockpit.get_node("ActualSpeedNeedle")
    var dash: MeshInstance3D=cockpit.get_node("PhysicalDashboard")
    var original_needle_mesh: Mesh=needle.mesh
    var original_dash_mesh: Mesh=dash.mesh
    var dash_vertices: int=dash.mesh.surface_get_array_len(0)
    check(dash_vertices>220,
        "R165 original hand-authored physical speed dial has fine gauge tick marks")
    check(int(cockpit.get("mesh_builds"))==3 and
        cockpit.get_child_count()==3,"still exactly 3 cockpit GPU draw surfaces")
    chassis.call("set_cockpit_active",true)
    chassis.call("set_cockpit_data",18.0,0.5,0.0)
    var old_tint: Color=(needle.material_override as StandardMaterial3D).albedo_color
    chassis.call("set_cockpit_data",18.0,0.5,0.95)
    var hot_tint: Color=(needle.material_override as StandardMaterial3D).albedo_color
    check(float(cockpit.get("last_brake_response"))>0.90,
        "actual brake command arrives inside native rendered driver instruments")
    check(hot_tint!=old_tint and hot_tint.r>=old_tint.r and
        hot_tint.g<old_tint.g,"speed needle visibly warms during actual braking")
    var stoplamp: MeshInstance3D=chassis.get("brake_strip")
    var lamp_mesh: Mesh=stoplamp.mesh
    chassis.call("sync_brake_response",0.95,true,1.0/60.0)
    var bright: float=(stoplamp.material_override as StandardMaterial3D).emission_energy_multiplier
    for i in range(12):
        chassis.call("sync_brake_response",0.0,false,1.0/60.0)
    check((stoplamp.material_override as StandardMaterial3D).emission_energy_multiplier<bright,
        "source-modelled brake light smoothly fades on driver release")
    for i in range(90):
        chassis.call("set_cockpit_data",float(i)*0.2,sin(float(i)),float(i%7)/6.0)
    check(needle.mesh==original_needle_mesh and dash.mesh==original_dash_mesh and
        stoplamp.mesh==lamp_mesh and int(cockpit.get("mesh_builds"))==3,
        "90 physical steering/braking updates generate ZERO GPU meshes")
    chassis.call("set_cockpit_active",false)
    check(not cockpit.visible and
        (chassis.get_node("SlopedWindshield") as MeshInstance3D).visible,
        "original exterior canopy restored after actual cockpit camera leaves")
    var ui_source: String=FileAccess.get_file_as_string("res://scripts/hud.gd")
    var main_source: String=FileAccess.get_file_as_string("res://scripts/main.gd")
    check(ui_source.contains("ОТКЛИК ТОРМОЗА") and
        ui_source.contains("BRAKE RESPONSE") and ui_source.contains("制动响应"),
        "real pedal feedback is localized to RU EN ZH")
    check(main_source.contains("car.indicator_mode,car.brake_response"),
        "player-visible driving HUD consumes real sampled car pressure")
    check(not ui_source.contains("ABS SENSOR TRUE"),
        "arcade input envelope is never misrepresented as real wheel-slip ABS")
    car.queue_free()
    await process_frame
    print("CITY REIGN R165 PREMIUM COCKPIT FEEDBACK: %d PASS %d FAIL" % [passed,failed])
    quit(0 if failed==0 else 1)
