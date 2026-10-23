extends CanvasLayer
## R11 real-device benchmark. Run IN the player's browser on their actual GPU.
## F6 = show/hide live monitor, F7 = 20-second controlled sample,
## F9 = copy last real result. CI smoke does not invent hardware FPS.

const BENCH_SECONDS: float = 20.0
const WARMUP_SECONDS: float = 2.0
const MAX_SAMPLES: int = 4000

var overlay: PanelContainer
var stats_label: Label
var report_label: Label
var show_live: bool = false
var quality_mode: int = 0
var elapsed: float = 0.0
var sample_elapsed: float = 0.0
var warmup_remaining: float = 0.0
var benchmarking: bool = false
var samples_ms: Array[float] = []
var frames_drawn: int = 0
var invalid_frames: int = 0
var sum_ms: float = 0.0
var last_report: Dictionary = {}
var last_timestamp_us: int = 0
var last_ui_update: float = 0.0
var source_name: String = ""
var device_name: String = ""
var draw_calls_peak: int = 0
var triangle_peak: int = 0
var quality_at_start: int = 0
var profile_switched_during_test: bool = false
var screenshot_count: int = 0

func _ready() -> void:
    layer = 7
    device_name = RenderingServer.get_video_adapter_name()
    source_name = OS.get_name()
    overlay = PanelContainer.new()
    overlay.name = "R11_HardwarePerformancePanel"
    overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
    overlay.offset_left = -390.0
    overlay.offset_right = -18.0
    overlay.offset_top = -255.0
    overlay.offset_bottom = -16.0
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.025, 0.035, 0.051, 0.93)
    style.border_color = Color(0.67, 0.56, 0.39, 0.68)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.content_margin_left = 14
    style.content_margin_right = 14
    style.content_margin_top = 12
    style.content_margin_bottom = 10
    overlay.add_theme_stylebox_override("panel", style)
    add_child(overlay)
    var column := VBoxContainer.new()
    column.add_theme_constant_override("separation", 7)
    overlay.add_child(column)
    stats_label = Label.new()
    stats_label.add_theme_font_size_override("font_size", 16)
    stats_label.add_theme_color_override("font_color", Color(0.89, 0.92, 0.95))
    column.add_child(stats_label)
    report_label = Label.new()
    report_label.add_theme_font_size_override("font_size", 14)
    report_label.add_theme_color_override("font_color", Color(0.88, 0.73, 0.49))
    report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    column.add_child(report_label)
    overlay.visible = false
    _draw_overlay()

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    if benchmarking and quality_mode != quality_at_start:
        profile_switched_during_test = true

func toggle_panel() -> void:
    show_live = not show_live
    _sync_visibility()

func _sync_visibility() -> void:
    if is_instance_valid(overlay):
        overlay.visible = show_live or benchmarking

func _percentile(sorted_values: Array[float], p: float) -> float:
    if sorted_values.is_empty():
        return 0.0
    var index: int = clampi(int(ceil(float(sorted_values.size()) * p)) - 1,
                           0, sorted_values.size() - 1)
    return sorted_values[index]

func start_benchmark() -> void:
    # Never reuse samples from CI/headless or a previous run.
    benchmarking = true
    quality_at_start = quality_mode
    profile_switched_during_test = false
    warmup_remaining = WARMUP_SECONDS
    sample_elapsed = 0.0
    frames_drawn = 0
    invalid_frames = 0
    sum_ms = 0.0
    draw_calls_peak = 0
    triangle_peak = 0
    samples_ms.clear()
    last_report.clear()
    last_timestamp_us = 0
    show_live = true
    _sync_visibility()
    report_label.text = "ПРОГРЕВ 2 СЕК · ЗАТЕМ ЗАМЕР 20 СЕК\nОставь игру активной, лети через порт и город."

func _complete() -> void:
    benchmarking = false
    samples_ms.sort()
    var valid_count: int = samples_ms.size()
    if valid_count < 120:
        report_label.text = "НЕДОСТАТОЧНО КАДРОВ ДЛЯ ЗАМЕРА\nПовтори F7 в активной вкладке."
        _sync_visibility()
        return
    var mean_ms: float = sum_ms / float(valid_count)
    var mean_fps: float = 1000.0 / maxf(0.001, mean_ms)
    var slow_count: int = maxi(1, int(ceil(float(valid_count) * 0.01)))
    var slowest_sum: float = 0.0
    for i in range(valid_count - slow_count, valid_count):
        slowest_sum += samples_ms[i]
    var one_pct_low: float = 1000.0 / maxf(0.001, slowest_sum / float(slow_count))
    var p95_ms: float = _percentile(samples_ms, 0.95)
    var p99_ms: float = _percentile(samples_ms, 0.99)
    var vps: Vector2 = get_viewport().get_visible_rect().size
    var target_fps: float = [60.0, 40.0, 30.0][quality_at_start]
    var max_p95_ms: float = [20.0, 30.0, 35.0][quality_at_start]
    var stable_sample: bool = (invalid_frames <= 2 and not profile_switched_during_test)
    var gate: String = "UNRELIABLE" if not stable_sample else (
        "MEETS_TARGET" if mean_fps >= target_fps and p95_ms <= max_p95_ms else "BELOW_TARGET")
    last_report = {
        "schema": "NEBULA_R12_HARDWARE_BENCHMARK",
        "date_unix": Time.get_unix_time_from_system(),
        "engine": Engine.get_version_info().get("string", "unknown"),
        "runtime": source_name,
        "adapter_reported": device_name,
        "adapter_note": "Browsers may mask/spoof GPU identity",
        "quality": quality_at_start,
        "quality_changed": profile_switched_during_test,
        "quality_gate": gate,
        "target_average_fps": target_fps,
        "target_p95_frame_ms": max_p95_ms,
        "resolution_width": int(vps.x),
        "resolution_height": int(vps.y),
        "sample_seconds": sample_elapsed,
        "valid_frames": valid_count,
        "excluded_long_frames": invalid_frames,
        "avg_fps": snappedf(mean_fps, 0.1),
        "one_percent_low_fps": snappedf(one_pct_low, 0.1),
        "one_percent_low_method": "Inverse average frame interval of slowest one percent, not p99",
        "avg_frame_ms": snappedf(mean_ms, 0.01),
        "p95_frame_ms": snappedf(p95_ms, 0.01),
        "p99_frame_ms": snappedf(p99_ms, 0.01),
        "max_draw_calls": draw_calls_peak,
        "max_primitives": triangle_peak,
        "measurement": "Real in-game frame intervals; not a GPU-only timing measurement"
    }
    var formatted: String = JSON.stringify(last_report)
    print("NEBULA_R12_BENCHMARK_JSON:" + formatted)
    print("NEBULA_R11_BENCHMARK_JSON:" + formatted) # Older browser tools compatibility.
    var file := FileAccess.open("user://nebula_r12_hardware_benchmark.json", FileAccess.WRITE)
    if file != null:
        file.store_string(formatted)
        file.close()
    report_label.text = "R12 · " + gate + " · F9 КОПИРОВАТЬ\n" + (
        "СРЕДНИЙ %.1f FPS · 1%% LOW %.1f FPS\n95%% КАДР %.1f МС · 99%% %.1f МС" %
        [mean_fps, one_pct_low, p95_ms, p99_ms])
    _sync_visibility()

func capture_frame() -> void:
    # Explicit physical-device capture; this is not a CI screenshot.
    # GPU readback is triggered only on F10 and may be slow on integrated GPUs.
    await RenderingServer.frame_post_draw
    var frame: Image = get_viewport().get_texture().get_image()
    if frame == null or frame.is_empty():
        report_label.text = "КАДР НЕ ПОЛУЧЕН · ПРОВЕРЬ WEBGL"
        show_live = true
        _sync_visibility()
        return
    var png: PackedByteArray = frame.save_png_to_buffer()
    if png.size() < 4096:
        report_label.text = "КАДР ПУСТОЙ · СНИМОК НЕ ПОДТВЕРЖДЁН"
        show_live = true
        _sync_visibility()
        return
    screenshot_count += 1
    var file_name: String = "nebula-r12-frame-%03d.png" % screenshot_count
    var stored := FileAccess.open("user://" + file_name, FileAccess.WRITE)
    if stored != null:
        stored.store_buffer(png)
        stored.close()
    if OS.has_feature("web"):
        # Download the actual Godot viewport PNG using a user-triggered local
        # Blob/data URL. No telemetry or remote upload is performed.
        var encoded: String = Marshalls.raw_to_base64(png)
        var js: String = "(function(){var a=document.createElement('a');" + (
            "a.download='" + file_name + "';a.href='data:image/png;base64," +
            encoded + "';document.body.appendChild(a);a.click();a.remove();" +
            "return 'requested';})()")
        var requested: Variant = JavaScriptBridge.eval(js, true)
        report_label.text = "СКРИНШОТ F10 · ЗАПРОС ЗАГРУЗКИ (" + str(requested) + ")"
    else:
        report_label.text = "СНИМОК СОХРАНЁН · user://" + file_name
    show_live = true
    _sync_visibility()

func copy_report() -> void:
    if last_report.is_empty():
        report_label.text = "Сначала запусти тест клавишей F7."
        show_live = true
        _sync_visibility()
        return
    DisplayServer.clipboard_set(JSON.stringify(last_report))
    report_label.text = "ОТЧЁТ ОТПРАВЛЕН В БУФЕР ОБМЕНА\n" + (
        "FPS %.1f · 1%% LOW %.1f" % [
            float(last_report["avg_fps"]), float(last_report["one_percent_low_fps"])])
    show_live = true
    _sync_visibility()

func _draw_overlay() -> void:
    if not is_instance_valid(stats_label):
        return
    var fps: float = float(Performance.get_monitor(Performance.TIME_FPS))
    var frame_ms: float = float(Performance.get_monitor(Performance.TIME_PROCESS)) * 1000.0
    var draw_calls: int = RenderingServer.get_rendering_info(
        RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
    var primitives: int = RenderingServer.get_rendering_info(
        RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
    var resolution: Vector2 = get_viewport().get_visible_rect().size
    var quality_text: String = ["MAX", "HIGH", "ECO"][quality_mode]
    stats_label.text = (
        "NEBULA R12 · REAL DEVICE MONITOR\n" +
        "FPS %.0f    CPU FRAME %.1f МС\n" +
        "DRAW CALLS %d    ПРИМИТИВЫ %d\n" +
        "RENDER %dx%d    КАЧЕСТВО %s\n" +
        "F6 МЕТРИКИ · F7 ЗАМЕР · F9 КОПИЯ") % [
            fps, frame_ms, draw_calls, primitives,
            int(resolution.x), int(resolution.y), quality_text]
    if benchmarking and warmup_remaining <= 0.0:
        report_label.text = "ТЕСТ: %.0f / %.0f СЕК · %d КАДРОВ" % [
            sample_elapsed, BENCH_SECONDS, samples_ms.size()]

func _process(delta: float) -> void:
    elapsed += delta
    if elapsed - last_ui_update >= 0.6:
        last_ui_update = elapsed
        if overlay.visible:
            _draw_overlay()
    if not benchmarking:
        last_timestamp_us = 0
        return
    if warmup_remaining > 0.0:
        warmup_remaining -= delta
        last_timestamp_us = Time.get_ticks_usec()
        return
    var now_us: int = Time.get_ticks_usec()
    if last_timestamp_us > 0:
        var ms: float = float(now_us - last_timestamp_us) / 1000.0
        # Browser tab suspension/pause produces non-gameplay giant intervals.
        if ms >= 2.0 and ms <= 350.0 and samples_ms.size() < MAX_SAMPLES:
            samples_ms.append(ms)
            sum_ms += ms
            frames_drawn += 1
        elif ms > 350.0:
            invalid_frames += 1
    last_timestamp_us = now_us
    draw_calls_peak = maxi(draw_calls_peak,
        RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
    triangle_peak = maxi(triangle_peak,
        RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
    sample_elapsed += delta
    if sample_elapsed >= BENCH_SECONDS or samples_ms.size() >= MAX_SAMPLES:
        _complete()
