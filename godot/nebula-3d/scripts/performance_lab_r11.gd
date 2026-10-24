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
## R36: on-device mobile performance controls; no remote analytics SDK.
var r36_touch_source
var r36_mobile: bool = false
var r36_safe_area: Vector4 = Vector4.ZERO
var r36_view_size: Vector2 = Vector2(1280, 720)
var r36_launcher: Button
var r36_start_button: Button
var r36_export_button: Button
var r36_close_button: Button
var r36_command_row: HBoxContainer
var r36_panel_style: StyleBoxFlat
var r36_touch_start_count: int = 0
var r36_touch_start_sum_ms: float = 0.0
var r36_touch_start_invalid: int = 0

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
    r36_panel_style = style
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
    r36_command_row = HBoxContainer.new()
    r36_command_row.name = "R36_MobilePerformanceActions"
    r36_command_row.add_theme_constant_override("separation", 4)
    column.add_child(r36_command_row)
    r36_start_button = Button.new()
    r36_start_button.text = "20 С"
    r36_start_button.name = "R36_StartReal20SecondBenchmark"
    r36_start_button.custom_minimum_size = Vector2(46, 28)
    r36_start_button.pressed.connect(start_benchmark)
    r36_command_row.add_child(r36_start_button)
    r36_export_button = Button.new()
    r36_export_button.text = "JSON"
    r36_export_button.name = "R36_SaveLocalReport"
    r36_export_button.custom_minimum_size = Vector2(52, 28)
    r36_export_button.pressed.connect(download_report)
    r36_command_row.add_child(r36_export_button)
    r36_close_button = Button.new()
    r36_close_button.text = "×"
    r36_close_button.name = "R36_ClosePerformancePanel"
    r36_close_button.custom_minimum_size = Vector2(30, 28)
    r36_close_button.pressed.connect(_r36_close_mobile_panel)
    r36_command_row.add_child(r36_close_button)
    r36_launcher = Button.new()
    r36_launcher.name = "R36_MobileFPSLauncher"
    r36_launcher.text = "FPS"
    r36_launcher.custom_minimum_size = Vector2(70, 30)
    r36_launcher.pressed.connect(_r36_show_mobile_panel)
    add_child(r36_launcher)
    get_viewport().size_changed.connect(_r36_relayout)
    overlay.visible = false
    r36_launcher.visible = false
    r36_command_row.visible = false
    _draw_overlay()

func configure_mobile(active: bool, touch_source: Node,
        safe_area: Vector4, viewport_pixels: Vector2) -> void:
    r36_mobile = active
    r36_touch_source = touch_source
    r36_safe_area = safe_area
    r36_view_size = viewport_pixels
    _r36_relayout()


func _r36_relayout() -> void:
    if not is_instance_valid(overlay) or not is_instance_valid(r36_launcher):
        return
    r36_command_row.visible = r36_mobile
    r36_launcher.visible = r36_mobile and not (show_live or benchmarking)
    if not r36_mobile:
        overlay.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
        overlay.offset_left = -390.0
        overlay.offset_right = -18.0
        overlay.offset_top = -255.0
        overlay.offset_bottom = -16.0
        return
    var size: Vector2 = r36_view_size
    if size.x < 200.0 or size.y < 200.0:
        size = get_viewport().get_visible_rect().size
    var landscape: bool = size.x > size.y and size.y < 530.0
    var left: float = r36_safe_area.x
    var top: float = r36_safe_area.y
    var right: float = r36_safe_area.z
    var usable_w: float = maxf(180.0, size.x - left - right)
    overlay.set_anchors_preset(Control.PRESET_TOP_LEFT)
    overlay.offset_left = left + 8.0
    overlay.offset_top = top + 8.0
    overlay.offset_right = overlay.offset_left + minf(
        164.0 if landscape else 300.0, usable_w - 16.0)
    overlay.offset_bottom = overlay.offset_top + (
        108.0 if landscape else 130.0)
    if is_instance_valid(r36_panel_style):
        r36_panel_style.content_margin_left = 8
        r36_panel_style.content_margin_right = 8
        r36_panel_style.content_margin_top = 6
        r36_panel_style.content_margin_bottom = 6
    stats_label.add_theme_font_size_override("font_size", 10)
    report_label.add_theme_font_size_override("font_size", 10)
    stats_label.clip_text = true
    report_label.clip_text = true
    r36_launcher.set_anchors_preset(Control.PRESET_TOP_LEFT)
    if landscape:
        r36_launcher.offset_left = size.x - right - 78.0
        r36_launcher.offset_top = top + 8.0
    else:
        r36_launcher.offset_left = left + 8.0
        r36_launcher.offset_top = top + 136.0
    r36_launcher.offset_right = r36_launcher.offset_left + 70.0
    r36_launcher.offset_bottom = r36_launcher.offset_top + 30.0


func _r36_show_mobile_panel() -> void:
    show_live = true
    _sync_visibility()


func _r36_close_mobile_panel() -> void:
    if benchmarking:
        return
    show_live = false
    _sync_visibility()


func download_report() -> void:
    if last_report.is_empty():
        report_label.text = "НЕТ ЗАМЕРА · НАЖМИ 20 С"
        show_live = true
        _sync_visibility()
        return
    var content: String = JSON.stringify(last_report)
    var filename: String = "nebula-r36-real-device-performance.json"
    if OS.has_feature("web"):
        # Explicit local download; no network, identity or background upload.
        var encoded: String = Marshalls.raw_to_base64(content.to_utf8_buffer())
        var js: String = "(function(){const a=document.createElement('a');" + (
            "a.download='" + filename + "';" +
            "a.href='data:application/json;base64," + encoded + "';" +
            "document.body.appendChild(a);a.click();a.remove();" +
            "return true;})()")
        JavaScriptBridge.eval(js)
        report_label.text = "JSON · ЗАПРОС ЗАГРУЗКИ"
    else:
        var file := FileAccess.open("user://" + filename, FileAccess.WRITE)
        if file != null:
            file.store_string(content)
            file.close()
            report_label.text = "JSON · СОХРАНЁН В user://"
        else:
            report_label.text = "НЕ УДАЛОСЬ СОХРАНИТЬ JSON"
    show_live = true
    _sync_visibility()


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
    _r36_relayout()

func _percentile(sorted_values: Array[float], p: float) -> float:
    if sorted_values.is_empty():
        return 0.0
    var index: int = clampi(int(ceil(float(sorted_values.size()) * p)) - 1,
                           0, sorted_values.size() - 1)
    return sorted_values[index]

func start_benchmark() -> void:
    if benchmarking:
        return
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
    r36_touch_start_count = 0
    r36_touch_start_sum_ms = 0.0
    r36_touch_start_invalid = 0
    if is_instance_valid(r36_touch_source):
        r36_touch_start_count = r36_touch_source.r36_input_poll_samples
        r36_touch_start_sum_ms = r36_touch_source.r36_input_poll_latency_total_ms
        r36_touch_start_invalid = r36_touch_source.r36_input_poll_invalid
    if is_instance_valid(r36_start_button):
        r36_start_button.disabled = true
    if is_instance_valid(r36_export_button):
        r36_export_button.disabled = true
    show_live = true
    _sync_visibility()
    report_label.text = "ПРОГРЕВ 2 СЕК · ЗАТЕМ ЗАМЕР 20 СЕК\nОставь игру активной, лети через порт и город."

func _complete() -> void:
    benchmarking = false
    samples_ms.sort()
    var valid_count: int = samples_ms.size()
    if valid_count < 120:
        report_label.text = "НЕДОСТАТОЧНО КАДРОВ · ПОВТОРИ 20 С" if (
            r36_mobile) else (
            "НЕДОСТАТОЧНО КАДРОВ ДЛЯ ЗАМЕРА\nПовтори F7 в активной вкладке.")
        if is_instance_valid(r36_start_button):
            r36_start_button.disabled = false
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
    var touch_count: int = 0
    var touch_invalid: int = 0
    var touch_mean_ms: Variant = null
    var touch_peak_ms: Variant = null
    if is_instance_valid(r36_touch_source):
        touch_count = maxi(0, r36_touch_source.r36_input_poll_samples -
            r36_touch_start_count)
        touch_invalid = maxi(0, r36_touch_source.r36_input_poll_invalid -
            r36_touch_start_invalid)
        if touch_count > 0:
            touch_mean_ms = snappedf(maxf(0.0, (
                r36_touch_source.r36_input_poll_latency_total_ms -
                r36_touch_start_sum_ms)) / float(touch_count), 0.1)
            touch_peak_ms = snappedf(
                r36_touch_source.r36_input_poll_latency_peak_ms, 0.1)
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
        "measurement": "Real in-game frame intervals; not a GPU-only timing measurement",
        "r36_touch_poll_samples": touch_count,
        "r36_touch_poll_invalid": touch_invalid,
        "r36_browser_dom_to_engine_avg_ms": touch_mean_ms,
        "r36_browser_dom_to_engine_peak_since_launch_ms": touch_peak_ms,
        "r36_touch_delay_scope": "Browser DOM touch dispatch to Godot poll; not input-to-photon, and only measured for actual touch events",
        "r36_data_policy": "Collected locally in active session; JSON downloaded only after a user click; no remote upload"
    }
    var formatted: String = JSON.stringify(last_report)
    print("NEBULA_R12_BENCHMARK_JSON:" + formatted)
    print("NEBULA_R11_BENCHMARK_JSON:" + formatted) # Older browser tools compatibility.
    var file := FileAccess.open("user://nebula_r12_hardware_benchmark.json", FileAccess.WRITE)
    if file != null:
        file.store_string(formatted)
        file.close()
    if r36_mobile:
        report_label.text = "AVG %.0f FPS · P95 %.0f МС" % [
            mean_fps, p95_ms]
    else:
        report_label.text = "R12 · " + gate + " · F9 КОПИРОВАТЬ\n" + (
            "СРЕДНИЙ %.1f FPS · 1%% LOW %.1f FPS\n95%% КАДР %.1f МС · 99%% %.1f МС" %
            [mean_fps, one_pct_low, p95_ms, p99_ms])
    if is_instance_valid(r36_start_button):
        r36_start_button.disabled = false
    if is_instance_valid(r36_export_button):
        r36_export_button.disabled = false
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
    if r36_mobile:
        var age_ms: float = -1.0
        if is_instance_valid(r36_touch_source):
            age_ms = r36_touch_source.r36_input_poll_latency_ms
        stats_label.text = (
            "REAL FPS %.0f · %s\n" +
            "CPU %.1f МС · %d DRAW\n" +
            "ВВОД %.0f МС (DOM)") % [
                fps, quality_text, frame_ms, draw_calls, age_ms]
        if benchmarking and warmup_remaining <= 0.0:
            report_label.text = "ЗАМЕР %.0f / 20 С · %d КАДРОВ" % [
                sample_elapsed, samples_ms.size()]
        elif not benchmarking and last_report.is_empty():
            report_label.text = "ТЕСТ 20 С · ЛОКАЛЬНО"
    else:
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
