extends SceneTree
## R169 actual source-generated PCM, native Godot streams and bounded player nodes.
const MIX=preload("res://scripts/city_reign_acoustic_mix.gd")
const AUDIO=preload("res://scripts/city_soundscape.gd")
var passed:=0
var failed:=0
func check(ok: bool,why: String) -> void:
	if ok: passed+=1
	else:
		failed+=1
		push_error("CITY REIGN R169 SOURCE PCM FAIL: "+why)
func _initialize() -> void:
	call_deferred("_run")
func _run() -> void:
	check(MIX.MAX_ADDED_VOICES==2 and MIX.TIERS.size()==3,
		"two extra audio loops only: low, standard, cinematic original tier safety")
	for sample_name in ["engine_load.wav","tyre_roll.wav"]:
		var source: AudioStreamWAV=load("res://assets/audio/"+sample_name) as AudioStreamWAV
		check(source!=null,"real Godot WAV import available: "+sample_name)
		if source!=null:
			# Godot 4 may IMPORT authored PCM into a smaller codec representation.
			# Exact original WAV bytes/rate are checked independently by Python.
			# Native Godot must load a real ~2 sec nonempty playable audio stream.
			print("R169 IMPORT ",sample_name," rate=",source.mix_rate,
				" buffer=",source.data.size()," length=",source.get_length())
			check(source.get_length()>1.9 and source.get_length()<2.1 and
				source.data.size()>1000,
				"actual engine-imported authored audio plays for two seconds")
	var sounds: Node=AUDIO.new()
	root.add_child(sounds)
	var engine: AudioStreamPlayer3D=sounds.get("engine") as AudioStreamPlayer3D
	var load_layer: AudioStreamPlayer3D=sounds.get("engine_load") as AudioStreamPlayer3D
	var tyres: AudioStreamPlayer3D=sounds.get("tyre_roll") as AudioStreamPlayer3D
	check(engine!=null and load_layer!=null and tyres!=null,
		"exact source Godot vehicle engine, load, tyre 3D nodes instantiated")
	check(load_layer.stream!=null and tyres.stream!=null,
		"new real waveform material exists as genuine native AudioStreamWAV")
	check(sounds.get_child_count()==7,
		"original five channels plus exactly two new real 3D player nodes")
	var car:=Node3D.new()
	root.add_child(car)
	sounds.call("attach_vehicle",car)
	check(engine.get_parent()==car and load_layer.get_parent()==car and
		tyres.get_parent()==car,
		"all THREE genuine audio voices follow one original actual vehicle node")
	check(load_layer.max_distance<=110.0 and tyres.max_distance<=82.0,
		"all new 3D sounds have bounded attenuation ranges")
	sounds.queue_free()
	car.queue_free()
	await process_frame
	print("CITY REIGN R169 SOURCE PCM: %d PASS %d FAIL" % [passed,failed])
	quit(0 if failed==0 else 1)
