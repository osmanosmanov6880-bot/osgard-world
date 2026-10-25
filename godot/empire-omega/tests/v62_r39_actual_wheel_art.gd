extends SceneTree
## R39 genuine sculpted car wheel detail, not an external high-res image.
const DETAIL = preload("res://scripts/horizon_r39_wheel_detail.gd")
const ART = preload("res://scripts/horizon_vehicle_art.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("EMPIRE OMEGA R39 ACTUAL CAR FAILED: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var art: Node3D = ART.new()
	root.add_child(art)
	var rigs: Array = art.get("wheel_rigs")
	var details: Array = art.get("wheel_detail_nodes")
	check(rigs.size()==4 and details.size()==4,"actual car has four independent animated wheels and four new geometry packs")
	for index in range(details.size()):
		var pack: Node3D=details[index]
		check(pack.get_parent().name=="RollingWheel","physical visuals spin with authentic rolling wheel")
		check(pack.get_node_or_null("MachinedBrakeRotor") is MeshInstance3D,"rotor is a real cylinder mesh")
		check(pack.get_node_or_null("MachinedWheelBoltBatch") is MultiMeshInstance3D,"metal studs share a five-instance batch")
		check(pack.get_node_or_null("RealTyreShoulderTreadBatch") is MultiMeshInstance3D,"rubber tyre detail shares a 24-instance batch")
		check(pack.call("instance_budget")==29,"each actual wheel has exactly 29 GPU-instanced details")
		var studs: MultiMeshInstance3D=pack.get_node("MachinedWheelBoltBatch")
		var grooves: MultiMeshInstance3D=pack.get_node("RealTyreShoulderTreadBatch")
		check(studs.multimesh.instance_count==5 and grooves.multimesh.instance_count==24,"real physically placed geometry has expected budgets")
		check(studs.cast_shadow==GeometryInstance3D.SHADOW_CASTING_SETTING_OFF,"added detail does not increase shadow-pass cost")
	art.call("set_detail_quality","low")
	for pack in details:
		check(not pack.visible,"mobile low suppresses all 3D tyre detail")
	art.call("set_detail_quality","standard")
	for pack in details:
		check(pack.visible and not (pack.get_node("RealTyreShoulderTreadBatch") as MultiMeshInstance3D).visible,"standard retains rotor but disables expensive tread")
	art.call("set_detail_quality","cinematic")
	for pack in details:
		check((pack.get_node("RealTyreShoulderTreadBatch") as MultiMeshInstance3D).visible,"cinematic enables detailed tyre shoulder")
	art.roll_wheels(0.8,0.3)
	check(rigs[0].get_node("RollingWheel").rotation.x!=0.0,"R39 rotates naturally with real existing wheel spin")
	art.queue_free()
	var car: CharacterBody3D=CAR.new()
	root.add_child(car)
	check(car.get("horizon_visual")!=null,"actual original driving car owns R39 3D art")
	var collision_count := 0
	for part in car.get_children():
		if part is CollisionShape3D: collision_count+=1
	check(collision_count==1,"original vehicle collision shape count unchanged")
	car.update_headlights(23.0,"cinematic")
	check(car.get("headlight_cones").size()==2 and car.get("headlight_cones")[0].visible,"actual night lighting retained")
	var art2: Node3D=car.get("horizon_visual")
	check(art2.get("wheel_detail_nodes").size()==4,"live game car has four 3D enhanced wheels")
	car.update_headlights(23.0,"low")
	for pack in art2.get("wheel_detail_nodes"):
		check(not pack.visible,"actual real car adaptive LOW disables extra detailing")
	check(not car.get("headlight_cones")[0].visible,"night lamps also follow original LOW render budget")
	var main: Variant = load("res://scripts/main.gd")
	check(main!=null and main is Script and main.can_instantiate(),"actual playable main still parses")
	var source: String = FileAccess.get_file_as_string("res://scripts/vehicle_controller.gd")
	check(source.contains('HORIZON_BODY = preload("res://scripts/horizon_vehicle_art.gd")'),"original working car not replaced with unrelated 3D image")
	check(source.contains('horizon_visual.call("set_detail_quality",quality)'),"live adaptive graphics controls real car geometry")
	car.queue_free()
	await process_frame
	print("EMPIRE OMEGA R39 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
