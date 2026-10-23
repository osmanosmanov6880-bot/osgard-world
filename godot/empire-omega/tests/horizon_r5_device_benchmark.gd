extends SceneTree
## R5 real-device GPU/CPU benchmark, not executed by headless CI.
## Launch: godot --rendering-method forward_plus --path godot/empire-omega --script res://tests/horizon_r5_device_benchmark.gd
const WORLD = preload("res://scripts/world_builder.gd")
const WARMUP = 5.0
const SAMPLE = 20.0
var city: Node3D
var eye: Camera3D
var accumulator := 0.0
var frames: Array[float] = []
var gpu_ms: Array[float] = []
var render_cpu_ms: Array[float] = []
var draws: Array[int] = []
var elapsed := 0.0
var prior_vsync: int = 0

func _initialize() -> void:
	call_deferred("_setup")

func _setup() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("R5 benchmark refused: needs visible native renderer + physical GPU")
		quit(2)
		return
	city = WORLD.new()
	root.add_child(city)
	eye = Camera3D.new()
	root.add_child(eye)
	eye.current = true
	eye.fov = 74
	eye.far = 700
	eye.global_position = Vector3(-119,7,-85)
	eye.look_at(Vector3(-125,4,-130))
	prior_vsync = DisplayServer.window_get_vsync_mode()
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),true)
	city.get_node("HorizonCinematicR5").call("set_profile","cinematic")

func _process(delta: float) -> bool:
	if city == null:
		return false
	elapsed += delta
	# Same camera path on every run; no AI/score/save modifications.
	var t: float = minf(elapsed / (WARMUP+SAMPLE),1.0)
	eye.global_position = Vector3(-119+sin(t*TAU)*18,7,-100+cos(t*TAU)*19)
	eye.look_at(Vector3(-125,5,-112))
	if elapsed >= WARMUP and elapsed < WARMUP+SAMPLE and delta > .0001 and delta < .75:
		frames.append(delta*1000.0)
		if frames.size()%8 == 0:
			var gpu_time: float = RenderingServer.viewport_get_measured_render_time_gpu(root.get_viewport_rid())
			var cpu_time: float = RenderingServer.viewport_get_measured_render_time_cpu(root.get_viewport_rid())
			if gpu_time>0.0: gpu_ms.append(gpu_time)
			if cpu_time>0.0: render_cpu_ms.append(cpu_time)
			draws.append(RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
	if elapsed >= WARMUP+SAMPLE:
		_finish()
	return false

func _average(numbers: Array) -> float:
	if numbers.is_empty(): return 0.0
	var total := 0.0
	for value in numbers: total += float(value)
	return total/float(numbers.size())

func _finish() -> void:
	if city == null: return
	city = null
	RenderingServer.viewport_set_measure_render_time(root.get_viewport_rid(),false)
	DisplayServer.window_set_vsync_mode(prior_vsync)
	var adapter: String = RenderingServer.get_video_adapter_name()
	var kind: String = adapter.to_lower()
	var software: bool = adapter.is_empty() or "llvmpipe" in kind or "swiftshader" in kind or "software" in kind or "lavapipe" in kind
	var ordered: Array[float] = frames.duplicate()
	ordered.sort()
	var low_count: int = maxi(1,ceili(float(ordered.size())*.01))
	var worst_one_percent: float = 0.0
	for index in range(low_count):
		worst_one_percent += ordered[ordered.size()-1-index]
	worst_one_percent /= float(low_count)
	var mean: float = _average(frames)
	var accepted: bool = not software and frames.size()>=200
	var report: Dictionary = {
		"release":"HORIZON_R5","engine":Engine.get_version_info(),
		"source":"ON_DEVICE_NATIVE_GODOT_SESSION","valid_physical_gpu":accepted,
		"gpu_adapter":adapter,"driver":RenderingServer.get_current_rendering_driver_name(),
		"renderer":RenderingServer.get_current_rendering_method(),
		"os":OS.get_name(),"cpu":OS.get_processor_name(),
		"resolution":str(root.get_visible_rect().size),
		"warmup_seconds":WARMUP,"capture_seconds":SAMPLE,
		"frame_count":frames.size(),"avg_fps":1000.0/mean if mean>0.0 else 0.0,
		"one_percent_low_fps":1000.0/worst_one_percent if worst_one_percent>0.0 else 0.0,
		"p95_frame_ms":ordered[clampi(roundi(.95*float(ordered.size()-1)),0,ordered.size()-1)] if not ordered.is_empty() else 0.0,
		"mean_gpu_ms":_average(gpu_ms),"mean_render_cpu_ms":_average(render_cpu_ms),
		"mean_draw_calls":_average(draws),"gpu_timing_available":not gpu_ms.is_empty(),
		"note":"Requires physical-GPU confirmation from operator; GitHub CI headless is not a hardware benchmark."
	}
	var path: String = "user://HORIZON_R5_DEVICE_BENCHMARK.json"
	var file: FileAccess = FileAccess.open(path,FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report,"  "))
		file.close()
	print("HORIZON_R5_DEVICE_BENCHMARK ",JSON.stringify(report))
	print("REPORT_PATH ",ProjectSettings.globalize_path(path))
	quit(0 if accepted and file != null else 1)
