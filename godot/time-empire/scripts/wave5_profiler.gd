extends CanvasLayer
## Wave 5 performance telemetry for REAL device testing (F9 display, F10 JSON).
## Stores GPU model, renderer, CPU, process times and frame-time percentiles.
## Reports are actual measurements from the currently running device.
var game_id: String = ""
var active_profile: String = "web"
var samples: Array[float] = []
var elapsed_seconds: float = 0.0
var _ui_elapsed: float = 0.0
var _label: Label
var _panel: PanelContainer

func configure(identifier: String, quality: String) -> void:
    game_id = identifier
    active_profile = quality

func _ready() -> void:
    _panel = PanelContainer.new()
    _panel.name = "PerformanceOverlay"
    _panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
    _panel.position = Vector2(-335, 92)
    _panel.custom_minimum_size = Vector2(300, 0)
    _panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.015, 0.025, 0.040, 0.91)
    style.border_color = Color(0.22, 0.52, 0.60, 0.70)
    style.set_border_width_all(1)
    style.set_content_margin_all(12)
    _panel.add_theme_stylebox_override("panel", style)
    _label = Label.new()
    _label.add_theme_font_size_override("font_size", 17)
    _label.add_theme_color_override("font_color", Color(0.88, 0.95, 0.97))
    _label.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _panel.add_child(_label)
    add_child(_panel)
    _panel.visible = false

func _process(delta: float) -> void:
    if delta > 0.00001 and delta < 1.0:
        samples.append(delta * 1000.0)
        if samples.size() > 9000:
            samples.pop_front()
    elapsed_seconds += delta
    _ui_elapsed += delta
    if _panel.visible and _ui_elapsed >= 0.35:
        _ui_elapsed = 0.0
        var fps: float = Engine.get_frames_per_second()
        var calls: int = int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME))
        _label.text = "ОСГАРД · ДИАГНОСТИКА\nFPS: %.0f  |  %.1f мс\nВызовы GPU: %d\nРежим: %s\nF9 — скрыть · F10 — отчёт" % [fps, _percentile(samples, 0.95), calls, active_profile.to_upper()]

func toggle_overlay() -> void:
    _panel.visible = not _panel.visible
    _ui_elapsed = 999.0

func set_profile(profile: String) -> void:
    active_profile = profile
    _ui_elapsed = 999.0

func _percentile(values: Array[float], position: float) -> float:
    if values.is_empty():
        return 0.0
    var ordered: Array[float] = values.duplicate()
    ordered.sort()
    var index: int = clampi(int(ceil(float(ordered.size() - 1) * position)), 0, ordered.size() - 1)
    return ordered[index]

func report() -> Dictionary:
    var total: float = 0.0
    for t in samples:
        total += t
    var mean: float = total / maxf(float(samples.size()), 1.0)
    var p99: float = _percentile(samples, 0.99)
    return {
        "schema": "osgard.wave5.hardware-benchmark.v1",
        "game": game_id,
        "quality_profile": active_profile,
        "os": OS.get_name(),
        "processor": OS.get_processor_name(),
        "logical_processors": OS.get_processor_count(),
        "adapter": RenderingServer.get_video_adapter_name(),
        "driver": RenderingServer.get_current_rendering_driver_name(),
        "renderer": RenderingServer.get_current_rendering_method(),
        "has_native_rendering_device": RenderingServer.get_rendering_device() != null,
        "window": "%dx%d" % [get_viewport().size.x, get_viewport().size.y],
        "duration_seconds": snappedf(elapsed_seconds, 0.001),
        "samples": samples.size(),
        "mean_fps": 1000.0 / maxf(mean, 0.001),
        "mean_frame_ms": mean,
        "p50_frame_ms": _percentile(samples, 0.50),
        "p95_frame_ms": _percentile(samples, 0.95),
        "p99_frame_ms": p99,
        "fps_1pct_low_estimate": 1000.0 / maxf(p99, 0.001),
        "draw_calls_last_frame": int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)),
        "video_memory_bytes": int(Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)),
        "static_memory_bytes": int(Performance.get_monitor(Performance.MEMORY_STATIC)),
        "reported_at_epoch_s": int(Time.get_unix_time_from_system()),
        "limitations": "Frame times include game logic, OS scheduling and presentation; not an isolated GPU timer. Browser and CI software renderer are not equivalent to a gaming GPU."
    }

func export_report() -> String:
    var path: String = "user://osgard_%s_%s.json" % [game_id, str(int(Time.get_unix_time_from_system()))]
    var handle := FileAccess.open(path, FileAccess.WRITE)
    if handle == null:
        push_error("Unable to write hardware performance report: " + path)
        return ""
    handle.store_string(JSON.stringify(report(), "  "))
    handle.close()
    print("OSGARD_HARDWARE_REPORT: ", ProjectSettings.globalize_path(path))
    return ProjectSettings.globalize_path(path)