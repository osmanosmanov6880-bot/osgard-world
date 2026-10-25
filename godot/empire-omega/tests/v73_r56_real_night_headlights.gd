extends SceneTree
## R56 genuine SpotLight3D car headlights must illuminate night asphalt, not
## pass as emissive fake triangles or added HTML brightness overlay.
const CAR = preload("res://scripts/vehicle_controller.gd")
var passed := 0
var failed := 0

func verify(ok: bool,why: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("R56 REAL HEADLIGHT FAILED: "+why)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var original_car: CharacterBody3D = CAR.new()
	root.add_child(original_car)
	var beams: Array = original_car.get("headlight_cones")
	verify(beams.size()==2,"exactly two original real car SpotLight3D nodes exist")
	if beams.size()!=2:
		original_car.queue_free()
		quit(1)
		return
	for beam in beams:
		verify(beam is SpotLight3D,"real Godot punctual spotlights, not billboard overlays")
		verify(not beam.shadow_enabled,"no new expensive mobile shadow maps")
		verify(beam.spot_angle>=33.0 and beam.spot_angle<=36.0,
			"headlight spread remains a physically localized cone")
		verify(beam.spot_range>19.0 and beam.spot_range<=20.0,"premium cone illuminates real road within original R33 bounded light radius")
		verify(beam.rotation_degrees.x<0.0,"real optical beams face down into the roadway")
		verify(not beam.visible,"startup headlamps do not consume GPU at daylight")
	original_car.call("update_headlights",12.0,"cinematic")
	verify(not beams[0].visible and not beams[1].visible,"midday physically disables spotlights")
	original_car.call("update_headlights",22.0,"cinematic")
	verify(beams[0].visible and beams[1].visible,"both authentic car beams enable at 22:00")
	verify(float(beams[0].light_energy)>1.3 and float(beams[1].light_energy)>1.3,
		"nighttime cinematic road receives meaningful light energy")
	original_car.call("update_headlights",22.0,"standard")
	verify(beams[0].visible and beams[1].visible,"standard GPU tier keeps night road visible")
	verify(float(beams[0].light_energy)<0.7 and beams[0].spot_range<=20.0,
		"mobile standard preserves original R33 low-power bounded beam contract")
	original_car.call("update_headlights",22.0,"low")
	verify(not beams[0].visible and not beams[1].visible,"LOW GPU tier saves both punctual lights")
	original_car.call("update_headlights",6.0,"cinematic")
	verify(beams[0].visible and beams[1].visible,"dawn road still gets original beams")
	original_car.call("update_headlights",9.0,"cinematic")
	verify(not beams[0].visible and not beams[1].visible,"sunrise avoids artificial light")
	original_car.call("update_headlights",NAN,"cinematic")
	verify(not beams[0].visible and not beams[1].visible,"nonfinite clock cannot light city")
	verify(beams.size()==2,"changing quality/time never spawns additional GPU lights")
	var source: String=FileAccess.get_file_as_string("res://tests/r44_actual_night_capture.gd")
	verify(source.contains('active_car.call("update_headlights",hour,"cinematic")'),
		"independent OpenGL 22:00 city capture enables the ACTUAL car lamps")
	verify(source.contains("R56 REAL CAR HEADLIGHT PIXELS:"),
		"independent real framebuffer explicitly compares spotlit and unlit road")
	var game: Variant=load("res://scripts/main.gd")
	verify(game is Script and game.can_instantiate(),"real gameplay still compiles after optical upgrade")
	var gameplay_src: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	verify(gameplay_src.contains("car.update_headlights("),"gameplay day/night and GPU tier drive car spotlights")
	original_car.queue_free()
	await process_frame
	print("EMPIRE OMEGA R56 HEADLIGHTS: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
