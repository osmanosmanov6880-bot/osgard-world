extends SceneTree
## HORIZON R19: native Godot audio wiring, virtual transmission and time-stable envelopes.
const ENGINE_AUDIO = preload("res://scripts/horizon_engine_audio.gd")
const SOUNDSCAPE = preload("res://scripts/city_soundscape.gd")
var passed := 0
var failed := 0

func check(ok: bool, description: String) -> void:
	if ok:
		passed += 1
	else:
		failed += 1
		push_error("HORIZON R19 FAILURE: "+description)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	check(ENGINE_AUDIO.next_gear(1,0.0)==1,"parked vehicle retains first audio gear")
	check(ENGINE_AUDIO.next_gear(1,7.8)==2,"accelerating reaches virtual second gear")
	check(ENGINE_AUDIO.next_gear(2,7.0)==2,"gearbox hysteresis prevents oscillation")
	check(ENGINE_AUDIO.next_gear(2,5.0)==1,"deceleration eventually downshifts")
	check(ENGINE_AUDIO.next_gear(3,-3.0)==0,"reverse uses separate sound gear")
	check(ENGINE_AUDIO.next_gear(0,2.0)==1,"reverse exit restores forward gear")
	check(ENGINE_AUDIO.next_gear(3,NAN)==3,"invalid speed keeps known gear")
	var first: float = ENGINE_AUDIO.pitch(4.0,0.0,1)
	var powered: float = ENGINE_AUDIO.pitch(4.0,1.0,1)
	check(powered>first and powered<=ENGINE_AUDIO.MAX_PITCH,"engine revs audibly under throttle")
	check(ENGINE_AUDIO.pitch(6.0,1.0,1)>ENGINE_AUDIO.pitch(7.9,1.0,2),"upshift creates sensible pitch drop")
	check(ENGINE_AUDIO.pitch(-6.0,0.0,0)>0.75,"reverse cue has audible pitch")
	check(ENGINE_AUDIO.pitch(NAN,1.0,2)>0.70,"invalid velocity cannot create impossible pitch")
	var idle_db: float = ENGINE_AUDIO.volume(true,0.0,0.0,false)
	var boost_db: float = ENGINE_AUDIO.volume(true,20.0,1.0,false)
	check(boost_db>idle_db,"engine load and speed drive loudness")
	check(ENGINE_AUDIO.volume(true,20.0,1.0,true)<boost_db,"handbrake avoids hard throttle swell")
	check(ENGINE_AUDIO.volume(false,20.0,1.0,false)==ENGINE_AUDIO.ENGINE_FADE_DB,"motor fades off when leaving vehicle")
	var once: float = ENGINE_AUDIO.smooth(0.0,1.0,1.0/30.0,7.0)
	var twice: float = ENGINE_AUDIO.smooth(0.0,1.0,1.0/60.0,7.0)
	twice = ENGINE_AUDIO.smooth(twice,1.0,1.0/60.0,7.0)
	check(absf(once-twice)<0.0001,"audio smoothing independent of 30 or 60 FPS")
	check(ENGINE_AUDIO.smooth(0.2,0.9,0.0)==0.2,"paused scene leaves audio unchanged")
	check(ENGINE_AUDIO.smooth(0.2,0.9,NAN)==0.2,"invalid frame delta leaves audio unchanged")
	var sounds: Node = SOUNDSCAPE.new()
	root.add_child(sounds)
	await process_frame
	var engine: AudioStreamPlayer3D = sounds.get("engine")
	var rain: AudioStreamPlayer = sounds.get("rain")
	var pursuit: AudioStreamPlayer = sounds.get("pursuit")
	check(engine!=null and engine.stream!=null,"real original engine stream imported")
	check(rain!=null and rain.stream!=null,"existing weather sound retained")
	check(pursuit!=null and pursuit.stream!=null,"existing patrol alert retained")
	var car := Node3D.new()
	root.add_child(car)
	sounds.call("attach_vehicle",car)
	check(engine.get_parent()==car,"engine sound remains physically anchored to car")
	for i in range(25):
		sounds.call("update_cues",true,13.5,"rain",0,0.9,false,1.0/60.0)
	check(int(sounds.get("virtual_gear"))>=2,"live engine selects virtual gear from actual speed")
	check(engine.pitch_scale>0.80 and engine.pitch_scale<=ENGINE_AUDIO.MAX_PITCH,"live 3D engine receives bounded rpm tone")
	check(engine.volume_db > -35.0 and engine.volume_db <= -19.0,"real sound player reflects engine load")
	check(rain.volume_db > -65.0,"rain loop fades up under real weather")
	var target_db: float = engine.volume_db
	for i in range(50):
		sounds.call("update_cues",false,0.0,"clear",1,0.0,false,1.0/60.0)
	check(engine.volume_db < target_db,"exiting vehicle attenuates engine")
	check(rain.volume_db < -35.0,"rain fades when weather clears")
	check(pursuit.volume_db > -65.0,"wanted status raises patrol cue")
	var main: String = FileAccess.get_file_as_string("res://scripts/main.gd")
	check(main.contains("soundscape.update_cues(driving,car.speed,current_weather_kind"),"real game calls native sound engine")
	check(main.contains("car.handbrake_on if driving else false,delta"),"real frame delta and handbrake passed to sound")
	sounds.queue_free()
	car.queue_free()
	print("HORIZON R19 NATIVE: %d passed, %d failed" % [passed,failed])
	quit(0 if failed==0 else 1)
