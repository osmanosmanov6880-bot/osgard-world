extends Node
## Wave 6 reproducible native benchmark. No fabricated GPU results.
## Enable with: game.exe -- --w6-benchmark --w6-duration=30 --w6-profile=ultra --w6-resolution=1920x1080 --w6-output=report.json
## The CI workflow also executes this against Xvfb/llvmpipe, clearly tagged software.

var game: Node3D
var game_id: String = ""
var environment_node: WorldEnvironment
var enabled: bool = false
var warmup_seconds: float = 5.0
var duration_seconds: float = 30.0
var resolution: Vector2i = Vector2i(1920, 1080)
var quality: String = "ultra"
var result_file: String = ""
var total_elapsed: float = 0.0
var measured_seconds: float = 0.0
var frame_ms: Array[float] = []
var draw_calls: Array[int] = []
var max_video_memory_bytes: int = 0
var max_static_memory_bytes: int = 0
var last_camera_angle: float = 0.0

func configure(origin: Node3D, identifier: String, world: WorldEnvironment) -> void:
    game = origin
    game_id = identifier
    environment_node = world

func _opt_value(args: PackedStringArray, name: String, default_value: String) -> String:
    for arg in args:
        if arg.begins_with(name + "="):
            return arg.substr(name.length() + 1)
    return default_value

func _ready() -> void:
    var args: PackedStringArray = OS.get_cmdline_user_args()
    if not args.has("--w6-benchmark"):
        set_process(false)
        return
    enabled = true
    warmup_seconds = clampf(float(_opt_value(args, "--w6-warmup", "5")), 1.0, 60.0)
    duration_seconds = clampf(float(_opt_value(args, "--w6-duration", "30")), 4.0, 300.0)
    quality = _opt_value(args, "--w6-profile", "ultra")
    if quality != "ultra" and quality != "balanced":
        quality = "balanced"
    var requested_resolution: String = _opt_value(args, "--w6-resolution", "1920x1080")
    var components: PackedStringArray = requested_resolution.split("x")
    if components.size() == 2:
        resolution.x = clampi(int(components[0]), 640, 3840)
        resolution.y = clampi(int(components[1]), 360, 2160)
    result_file = _opt_value(args, "--w6-output", "")
    if result_file.is_empty():
        result_file = "user://osgard_%s_wave6_%s_%dx%d.json" % [game_id, quality, resolution.x, resolution.y]
    get_viewport().size = resolution
    if OS.get_name() != "Web":
        DisplayServer.window_set_size(resolution)
        DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
    Engine.max_fps = 0
    var fx_script = load("res://scripts/wave5_cinematic_fx.gd")
    if environment_node != null and fx_script != null:
        fx_script.apply(environment_node.environment, quality)
    game.set("wave5_profile", quality)
    var profiler: Node = game.get_node_or_null("Wave5PerformanceProfiler")
    if profiler != null:
        profiler.call("set_profile", quality)
    print("OSGARD_WAVE6_BENCHMARK_START: ", game_id, " quality=", quality, " size=", requested_resolution)

func _process(delta: float) -> void:
    if not enabled:
        return
    if delta <= 0.0:
        return
    total_elapsed += delta
    if total_elapsed < warmup_seconds:
        return
    measured_seconds += delta
    if delta < 1.0:
        frame_ms.append(delta * 1000.0)
        draw_calls.append(int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)))
    max_video_memory_bytes = maxi(max_video_memory_bytes, int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)))
    max_static_memory_bytes = maxi(max_static_memory_bytes, int(Performance.get_monitor(Performance.MEMORY_STATIC)))
    if measured_seconds >= duration_seconds:
        set_process(false)
        _finish()

func _percentile(sorted_values: Array[float], percentile: float) -> float:
    if sorted_values.is_empty():
        return 0.0
    return sorted_values[clampi(int(ceil((sorted_values.size() - 1) * percentile)), 0, sorted_values.size() - 1)]

func _finish() -> void:
    if frame_ms.size() < 5:
        push_error("Insufficient Wave 6 benchmark frames")
        get_tree().quit(1)
        return
    var sorted_frames := frame_ms.duplicate()
    sorted_frames.sort()
    var total: float = 0.0
    var call_total: float = 0.0
    for value in frame_ms:
        total += value
    for call in draw_calls:
        call_total += float(call)
    var mean_frame_ms: float = total / float(frame_ms.size())
    var adapter: String = RenderingServer.get_video_adapter_name()
    var lower: String = adapter.to_lower()
    var software: bool = lower.contains("llvmpipe") or lower.contains("softpipe") or lower.contains("swiftshader") or lower.contains("software rasterizer") or lower.contains("microsoft basic render")
    var native_renderer: String = RenderingServer.get_current_rendering_method()
    var physical_gpu_report: bool = not software and native_renderer == "forward_plus" and OS.get_name() == "Windows"
    var p95: float = _percentile(sorted_frames, 0.95)
    var p99: float = _percentile(sorted_frames, 0.99)
    var result: Dictionary = {
        "schema": "osgard.wave6.reproducible-hardware-benchmark.v1",
        "game": game_id,
        "quality": quality,
        "adapter": adapter,
        "driver": RenderingServer.get_current_rendering_driver_name(),
        "rendering_method": native_renderer,
        "os": OS.get_name(),
        "processor": OS.get_processor_name(),
        "logical_cores": OS.get_processor_count(),
        "res_x": resolution.x,
        "res_y": resolution.y,
        "vsync": "disabled_for_measurement",
        "warmup_seconds": warmup_seconds,
        "measurement_seconds": snappedf(measured_seconds, 0.001),
        "frames": frame_ms.size(),
        "mean_fps": snappedf(1000.0 / maxf(mean_frame_ms, 0.0001), 0.01),
        "fps_1pct_low_estimate": snappedf(1000.0 / maxf(p99, 0.0001), 0.01),
        "mean_frame_ms": snappedf(mean_frame_ms, 0.001),
        "p50_frame_ms": snappedf(_percentile(sorted_frames, 0.50), 0.001),
        "p95_frame_ms": snappedf(p95, 0.001),
        "p99_frame_ms": snappedf(p99, 0.001),
        "average_draw_calls": snappedf(call_total / maxf(float(draw_calls.size()), 1.0), 1.0),
        "max_video_memory_bytes": max_video_memory_bytes,
        "max_static_memory_bytes": max_static_memory_bytes,
        "physical_gpu_validation_candidate": physical_gpu_report,
        "passes_60fps_mean": mean_frame_ms <= 16.67,
        "passes_60fps_p95": p95 <= 16.67,
        "is_software_renderer": software,
        "interpretation": "Hardware validation requires a real accessible GPU and a completed sample. CI/Mesa llvmpipe samples are NOT proof of real gaming GPU performance."
    }
    var file_path: String = result_file
    if file_path.begins_with("user://"):
        file_path = ProjectSettings.globalize_path(file_path)
    if file_path.begins_with("res://"):
        file_path = ProjectSettings.globalize_path(file_path)
    var destination: String = file_path.get_base_dir()
    if not destination.is_empty():
        DirAccess.make_dir_recursive_absolute(destination)
    var f := FileAccess.open(file_path, FileAccess.WRITE)
    if f == null:
        push_error("Unable to save Wave6 benchmark JSON: " + file_path)
        get_tree().quit(1)
        return
    f.store_string(JSON.stringify(result, "  "))
    f.close()
    print("OSGARD_WAVE6_BENCHMARK_RESULT: ", JSON.stringify(result))
    print("OSGARD_WAVE6_BENCHMARK_FILE: ", file_path)
    get_tree().quit(0)