extends SceneTree
## R169 original engine throttle, weather and rear tyre lateral motion.
const MIX=preload("res://scripts/city_reign_acoustic_mix.gd")
const AUDIO=preload("res://scripts/city_soundscape.gd")
const CAR=preload("res://scripts/vehicle_controller.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R169 DYNAMIC AUDIO FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(MIX.load_volume(true,20.0,1.0,3,"cinematic",false)>
		MIX.load_volume(true,20.0,0.0,3,"cinematic",false),
		"real player W throttle raises powertrain sample")
	check(MIX.road_volume(true,20.0,5.0,0.66,"storm","cinematic",false)>
		MIX.road_volume(true,20.0,0.0,1.0,"clear","cinematic",false),
		"real rear contact, lateral slip and wet weather change actual road audio")
	check(MIX.load_volume(true,20.0,1.0,3,"low",false)==MIX.MUTE_DB and
		MIX.road_volume(true,20.0,5.0,0.66,"rain","low",false)==MIX.MUTE_DB,
		"LOW mutes optional voices independent of original gameplay physics")
	check(MIX.road_volume(false,20.0,5.0,0.66,"storm","standard",false)==MIX.MUTE_DB,
		"walking never produces synthetic tyre sounds")
	check(MIX.road_volume(true,NAN,NAN,NAN,"storm","standard",false)==MIX.MUTE_DB and
		MIX.rolling_pitch(NAN,true)>0.6,
		"nonfinite physics telemetry safely fails closed")
	check(MIX.load_volume(true,25.0,1.0,3,"cinematic",true)<
		MIX.load_volume(true,25.0,1.0,3,"cinematic",false),
		"physical cockpit cabin damps exterior powertrain audio")
	var car: CharacterBody3D=CAR.new()
	root.add_child(car)
	car.set_physics_process(false)
	var sounds: Node=AUDIO.new()
	root.add_child(sounds)
	sounds.call("attach_vehicle",car)
	var engine_layer: AudioStreamPlayer3D=sounds.get("engine_load")
	var tyre_layer: AudioStreamPlayer3D=sounds.get("tyre_roll")
	for i in range(120):
		sounds.call("update_cues",true,24.0,"rain",0,0.95,false,1.0/60.0,
			4.0,0.72,"cinematic",false)
	check(engine_layer.stream!=null and engine_layer.volume_db> -42.0,
		"original native engine harmonics audible under true 3D car acceleration")
	check(tyre_layer.stream!=null and tyre_layer.volume_db> -40.0,
		"original tyre-grain layer mixed from rear wheel and rain")
	var initial_road: float=tyre_layer.volume_db
	for i in range(100):
		sounds.call("update_cues",true,24.0,"clear",0,0.30,false,1.0/60.0,
			0.0,1.0,"cinematic",true)
	check(tyre_layer.volume_db<initial_road-4.0,
		"road dryness and enclosed cockpit reduce real spatial tyre audio")
	for i in range(130):
		sounds.call("update_cues",false,0.0,"clear",0,0.0,false,1.0/60.0,
			0.0,1.0,"low",false)
	check(engine_layer.volume_db< -62.0 and tyre_layer.volume_db< -62.0,
		"car exit and LOW fade additional 3D audio to bounded silence")
	check(car.get_node_or_null("HorizonCoupe")!=null,
		"player CharacterBody3D with original authoritative game collisions remains")
	var main_source: String=FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main_source.contains("car.lateral_speed if driving else 0.0,car.rear_traction_factor"),
		"original actual game passes physical tyre slip and rear traction, not UI values")
	sounds.queue_free()
	car.queue_free()
	await process_frame
	print("CITY REIGN R169 REAL DYNAMIC AUDIO: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
