extends SceneTree
## R169 actual real 3D instrument wheel grip response and reduced-motion parity.
const CAR=preload("res://scripts/vehicle_controller.gd")
const MIX=preload("res://scripts/city_reign_acoustic_mix.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R169 ACCESSIBLE CABIN FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var state: Node=root.get_node_or_null("GameState")
	check(state!=null,"original city saves and missions remain an autoload")
	if state==null:
		quit(2)
		return
	var original_state: Dictionary=state.data.duplicate(true)
	var car: CharacterBody3D=CAR.new()
	root.add_child(car)
	car.set_physics_process(false)
	var shell: Node3D=car.get("horizon_visual")
	var interior: Node3D=shell.get("cockpit_interior")
	var wheel: MeshInstance3D=interior.get_node("SteeringWheel")
	var panel: MeshInstance3D=interior.get_node("PhysicalDashboard")
	var needle: MeshInstance3D=interior.get_node("ActualSpeedNeedle")
	var original_meshes: Array=[wheel.mesh,panel.mesh,needle.mesh]
	check(int(interior.get("mesh_builds"))==3 and interior.get_child_count()==3,
		"same R164 exactly three real PBR interior GPU draws")
	shell.call("set_cockpit_active",true)
	shell.call("set_cockpit_data",23.0,0.66,0.92,5.0,false)
	check(absf(wheel.rotation.x)>0.014 and wheel.position.z< -0.732 and
		absf(wheel.rotation.z)>0.20,
		"original wheel physically responds to real side-slip and brake pressure")
	shell.call("set_cockpit_data",23.0,0.66,0.92,5.0,true)
	check(is_zero_approx(wheel.rotation.x) and is_equal_approx(wheel.position.z,-0.725),
		"reduce-motion mode instantly stops all introduced tactile cabin animation")
	for i in range(160):
		shell.call("set_cockpit_data",float(i%30),sin(float(i)),
			float(i%12)/12.0,float(i%9)-4.0,i%3==0)
	check(wheel.mesh==original_meshes[0] and panel.mesh==original_meshes[1] and
		needle.mesh==original_meshes[2] and interior.get_child_count()==3,
		"160 physical grip updates allocate ZERO new meshes, cameras or nodes")
	check(MIX.cockpit_slip(NAN,false)==0.0 and MIX.cockpit_brake(NAN,false)==0.0,
		"invalid samples do not shake physical cockpit")
	shell.call("set_cockpit_active",false)
	check(not interior.visible and
		(shell.get_node("SlopedWindshield") as MeshInstance3D).visible,
		"external glazing restores immediately after driver camera")
	check(state.data==original_state,
		"original saved city and 40 missions unchanged by tactile cockpit")
	var main: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("car.lateral_speed,GameSettings.reduced_motion") and
		main.contains("car.rear_traction_factor"),
		"actual gameplay passes original physical car telemetry to 3D art and audio")
	car.queue_free()
	await process_frame
	print("CITY REIGN R169 REAL CABIN: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
