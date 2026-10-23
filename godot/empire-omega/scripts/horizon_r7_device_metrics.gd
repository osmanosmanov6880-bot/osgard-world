extends Node
## R7 reproducible IN-GAME GPU diagnostics. Real GameState autoload and city renderer.
## Does not modify disk settings/saves. Software/Xvfb results are never marked GPU-verified.
const SCENARIOS = [
	{"name":"STANDARD_DRY","quality":"standard","weather":"clear"},
	{"name":"CINEMATIC_DRY","quality":"cinematic","weather":"clear"},
	{"name":"CINEMATIC_RAIN","quality":"cinematic","weather":"rain"},
	{"name":"CINEMATIC_DRY_REPEAT","quality":"cinematic","weather":"clear"}
]
var game
var started: bool = false
var phase: int = 0
var stage: float = 0.0
var sample: Array[float] = []
var gpu_timings: Array[float] = []
var cpu_timings: Array[float] = []
var draw_calls: Array[float] = []
var results: Array[Dictionary] = []
var old_max_fps: int = 0
var old_vsync: int = 0
var warmup: float = 3.0
var measure: float = 12.0
var saving: bool = false

func initialize(root_node) -> void:
	game = root_node
	if OS.get_cmdline_user_args().has("--r7-benchmark-quick"):
		warmup = .40
		measure = 2.0
	call_deferred("_begin")

func _begin() -> void:
	if game == null or DisplayServer.get_name() == "headless":
		push_error("R7 on-device benchmark requires the real playable game and a visible renderer")
		get_tree().quit(2)
		return
	game.set_process(false)
	game.set_physics_process(false)
	game.car.set_physics_process(false)
	game.hud.visible = false
	game.player.visible = false
	game.world.update_chunks(Vector3(-130,0,-130),"cinematic")
	for traffic in game.ambient_cars:
		traffic.visible = false
	for citizen in game.pedestrians:
		citizen.visible = false
	game.car.global_position = Vector3(-132.0,.98,-103.0)
	game.car.rotation.y = -.18
	game.camera.current = true
	game.camera.fov = 60.0
	game.camera.global_position = Vector3(-107.0,4.8,-104.0)
	game.camera.look_at(Vector3(-132.0,3.0,-119.0),Vector3.UP)
	old_max_fps = Engine.max_fps
	Engine.max_fps = 0
	old_vsync = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),true)
	_set_scenario(0)
	started = true

func _set_scenario(index: int) -> void:
	if index >= SCENARIOS.size():
		_finalize()
		return
	phase = index
	stage = 0.0
	sample.clear()
	gpu_timings.clear()
	cpu_timings.clear()
	draw_calls.clear()
	var profile: String = str(SCENARIOS[index]["quality"])
	var climate: String = str(SCENARIOS[index]["weather"])
	# Deliberately avoid GameSettings.set_graphics() (that function writes to user://).
	GameSettings.graphics = profile
	game._apply_preferences()
	game.world.update_weather(climate)
	for name in ["HorizonCinematicR5","HorizonPhotorealR6","HorizonArchitectureR7"]:
		var visual: Node = game.world.get_node_or_null(name)
		if visual != null:
			visual.call("set_weather",climate)
	# Engine fixed camera path: identical origin for each profile.
	game.camera.global_position = Vector3(-107.0,4.8,-104.0)
	game.camera.look_at(Vector3(-132.0,3.0,-119.0),Vector3.UP)
	print("R7 DEVICE BENCH PROFILE ",SCENARIOS[index]["name"]," warmup_s=",warmup," capture_s=",measure)

func _process(delta: float) -> void:
	if not started or saving:
		return
	stage += delta
	# Repeat the exact micro-orbit on every scene, excluding warmup.
	var t: float = clampf((stage-warmup)/maxf(measure,.01),0.0,1.0)
	game.camera.global_position = Vector3(-107.0+sin(t*TAU)*2.8,4.8+sin(t*PI)*.25,-104.0+cos(t*TAU)*2.8)
	game.camera.look_at(Vector3(-132.0,3.0,-119.0),Vector3.UP)
	if stage >= warmup and stage <= warmup+measure and delta > 0.0001 and delta < .8:
		sample.append(delta*1000.0)
		if sample.size()%8==0:
			var viewport_rid: RID = get_viewport().get_viewport_rid()
			var gpu: float = RenderingServer.viewport_get_measured_render_time_gpu(viewport_rid)
			var cpu: float = RenderingServer.viewport_get_measured_render_time_cpu(viewport_rid)
			if gpu>0.0:gpu_timings.append(gpu)
			if cpu>0.0:cpu_timings.append(cpu)
			draw_calls.append(float(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)))
	if stage >= warmup+measure:
		_capture_scene()

func _mean(data: Array) -> float:
	if data.is_empty():return 0.0
	var acc: float = 0.0
	for n in data:acc+=float(n)
	return acc/float(data.size())

func _capture_scene() -> void:
	var ordered: Array[float] = sample.duplicate()
	ordered.sort()
	var worst_count: int = maxi(1,ceili(float(ordered.size())*.01))
	var tail: float = 0.0
	for n in range(mini(worst_count,ordered.size())):
		tail += ordered[ordered.size()-1-n]
	var frame_mean: float = _mean(sample)
	var result := {
		"profile":str(SCENARIOS[phase]["name"]),
		"frames":sample.size(),
		"mean_fps":1000.0/frame_mean if frame_mean>0.0 else 0.0,
		"one_percent_low_fps":1000.0/(tail/float(worst_count)) if tail>0.0 else 0.0,
		"p95_ms":ordered[clampi(roundi(.95*float(ordered.size()-1)),0,ordered.size()-1)] if not ordered.is_empty() else 0.0,
		"p99_ms":ordered[clampi(roundi(.99*float(ordered.size()-1)),0,ordered.size()-1)] if not ordered.is_empty() else 0.0,
		"mean_gpu_ms":_mean(gpu_timings),
		"mean_render_cpu_ms":_mean(cpu_timings),
		"mean_draw_calls":_mean(draw_calls),
		"has_gpu_timer":not gpu_timings.is_empty()
	}
	results.append(result)
	print("R7 DEVICE BENCH RESULT ",JSON.stringify(result))
	_set_scenario(phase+1)

func _finalize() -> void:
	if saving:return
	saving = true
	started = false
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(),false)
	DisplayServer.window_set_vsync_mode(old_vsync)
	Engine.max_fps = old_max_fps
	var adapter: String = RenderingServer.get_video_adapter_name()
	var gpu_label: String = adapter.to_lower()
	var software: bool = adapter.is_empty() or "llvmpipe" in gpu_label or "lavapipe" in gpu_label or "swiftshader" in gpu_label or "software" in gpu_label or "softpipe" in gpu_label
	var complete: bool = results.size() == SCENARIOS.size()
	for item in results:
		if int(item["frames"])<5:
			complete = false
	var on_hardware: bool = not software and complete and DisplayServer.get_name()!="headless"
	var report := {
		"release":"R7","origin":"ACTUAL_GODOT_PLAYABLE_CITY","capture_completed":complete,
		"gpu_adapter":adapter,"software_renderer_detected":software,"physical_gpu_candidate":on_hardware,
		"renderer":RenderingServer.get_current_rendering_method(),
		"driver":RenderingServer.get_current_rendering_driver_name(),
		"cpu":OS.get_processor_name(),"os":OS.get_name(),
		"resolution":str(get_viewport().get_visible_rect().size),
		"warmup_seconds":warmup,"measurement_seconds_per_scenario":measure,
		"scenarios":results,
		"note":"Physical GPU candidate means non-software adapter reported by Godot, NOT independent hardware attestation. Mesa CI FPS must not be advertised."
	}
	var workspace: String = OS.get_environment("GITHUB_WORKSPACE")
	var filepath: String = "user://OSGARD_R7_GPU_MEASUREMENTS.json" if workspace=="" else workspace+"/screenshots/OSGARD_R7_GPU_MEASUREMENTS.json"
	if workspace!="":
		DirAccess.make_dir_recursive_absolute(filepath.get_base_dir())
	var file: FileAccess=FileAccess.open(filepath,FileAccess.WRITE)
	if file!=null:
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	print("R7 LIVE PERFORMANCE REPORT ",JSON.stringify(report))
	print("R7 DEVICE REPORT PATH ",ProjectSettings.globalize_path(filepath) if workspace=="" else filepath)
	get_tree().quit(0 if complete and file != null else 1)
