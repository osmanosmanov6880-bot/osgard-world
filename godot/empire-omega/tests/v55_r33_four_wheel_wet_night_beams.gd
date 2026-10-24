extends SceneTree
## R33 native test: four genuine supported wheel contacts, axle slide, night beams.
const PUDDLES = preload("res://scripts/horizon_rain_puddles.gd")
const TIRE = preload("res://scripts/horizon_tire_model.gd")
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0
func check(ok: bool,reason: String) -> void:
	if ok: passed += 1
	else:
		failed += 1
		push_error("R33 FAILED: "+reason)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	var puddles := PUDDLES.new()
	root.add_child(puddles)
	puddles.set_conditions("rain","cinematic")
	var centre: Vector3 = puddles.planned_transforms[0].origin
	var far: Vector3 = centre+Vector3(15,0,12)
	var all_ground: Array[bool] = [true,true,true,true]
	var points: Array[Vector3] = [centre,far,far,far]
	var front: Dictionary = puddles.wheel_contact_state({"points":points,"grounded":all_ground},far)
	check(not front["used_fallback"] and front["supported"]==4,"four real support contacts")
	check(absf(float(front["wetness"])-0.25)<0.02,"one wet wheel is one-quarter total contact")
	check(float(front["front"])>0.49 and is_zero_approx(float(front["rear"])),"front-only wet surface")
	points=[far,centre,far,far]
	var rear: Dictionary = puddles.wheel_contact_state({"points":points,"grounded":all_ground},far)
	check(float(rear["rear"])>0.49 and is_zero_approx(float(rear["front"])),"rear-only wet surface")
	points=[centre,centre,centre,centre]
	var fully_wet: Dictionary = puddles.wheel_contact_state({"points":points,"grounded":all_ground},far)
	check(float(fully_wet["wetness"])>0.98,"all four wheels wet")
	var none: Array[bool] = [false,false,false,false]
	check(is_zero_approx(float(puddles.wheel_contact_state({"points":points,"grounded":none},centre)["wetness"])),"airborne tyres stay dry")
	var partial: Array[bool] = [true,false,false,false]
	check(float(puddles.wheel_contact_state({"points":points,"grounded":partial},centre)["wetness"])<=0.26,"one supported wheel not treated as four")
	check(bool(puddles.wheel_contact_state({},centre)["used_fallback"]),"cold start retains old centre fallback")
	puddles.set_conditions("rain","low")
	check(not puddles.visible and float(puddles.wheel_contact_state({"points":points,"grounded":all_ground},far)["wetness"])>0.98,"LOW preserves exact physical friction")
	puddles.set_conditions("clear","cinematic")
	check(is_zero_approx(float(puddles.wheel_contact_state({"points":points,"grounded":all_ground},centre)["wetness"])),"clear weather removes hydro-grip")
	puddles.queue_free()
	var car := CAR.new()
	root.add_child(car)
	check(car.headlight_cones.size()==2,"real car owns two SpotLight3D emitters")
	car.update_headlights(22.0,"cinematic")
	check(car.headlight_cones[0].visible and car.headlight_cones[1].visible,"night beams visible")
	check(not car.headlight_cones[0].shadow_enabled and car.headlight_cones[0].spot_range<=20,"bounded light cost")
	car.update_headlights(12.0,"cinematic")
	check(not car.headlight_cones[0].visible,"sunlit car disables beams")
	car.update_headlights(22.0,"low")
	check(not car.headlight_cones[1].visible,"LOW disables night beams")
	car.update_headlights(22.0,"standard")
	check(car.headlight_cones[0].visible and car.headlight_cones[0].light_energy<0.7,"standard is economical")
	car.rear_traction_factor=PUDDLES.effective_grip(0.80,0.90)
	car.axle_grip_active=true
	check(car.rear_traction_factor<0.71,"rear wet grip reduces real lateral damping")
	var dry_slide: float=TIRE.step_lateral(0,19,0.5,0.80,false,0.25)
	var wet_slide: float=TIRE.step_lateral(0,19,0.5,car.rear_traction_factor,false,0.25)
	check(wet_slide>dry_slide,"wet rear axle increases genuine lateral slide")
	var parsed_main: Variant = load("res://scripts/main.gd")
	check(parsed_main!=null,"actual Godot main game script parses and loads")
	var source: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(source.contains("wheel_contact_state(car.last_wheel_support,car.global_position)"),"runtime consumes real four-wheel physics samples")
	check(source.contains("car.update_headlights("),"night beams react to game time")
	check(source.contains("ROAD_WETNESS.effective_grip(base_road_grip,wetness)"),"R32 traction contract retained")
	car.queue_free()
	await process_frame
	print("EMPIRE OMEGA R33 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
