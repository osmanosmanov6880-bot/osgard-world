extends Control
class_name OSGARDMain
## W32 — an actual Godot Control interface + native 3D viewport, NOT an HTML wrapper.
## Launch Main.tscn in Godot 4.4.1. This project never connects to equipment.

const BG := Color("08131d")
const PANEL := Color("11232c")
const PANEL_SOFT := Color("142b33")
const COPPER := Color("d5a573")
const MINT := Color("6edbce")
const WHITE := Color("e7f2ef")
const MUTED := Color("9cafb4")
const CORAL := Color("ef9c8d")

var core := OSGARDCore.new()
var scene_3d: OSGARDRig
var sub_viewport: SubViewport
var visual_container: SubViewportContainer
var scroll: ScrollContainer
var body: VBoxContainer
var feedback: Label
var hint: Label
var status: Label
var telemetry: Label
var cal_title: Label
var cal_sensors: Label
var cal_help: Label
var signal_progress: ProgressBar
var progress_text: Label
var mission_title: Label
var debrief_caption: Label
var debrief_panel: VBoxContainer
var debrief_label: Label
var debrief_timeline: Label
var debrief_toggle: Button
var retry_button: Button
var erase_confirm: ConfirmationDialog
var debrief_expanded: bool = false
var heading: Label
var lead: Label
var footer: Label
var slider_a: HSlider
var slider_b: HSlider
var a_title: Label
var b_title: Label
var a_value: Label
var b_value: Label
var engine_btn: Button
var hatch_btn: Button
var scan_btn: Button
var lang_btn: Button
var quality_btn: Button
var motion_btn: Button
var sound_btn: Button
var captions_btn: Button
var metrics_btn: Button
var erase_btn: Button
var mission_btns: Array[Button] = []
var view_btns: Array[Button] = []
var _refresh_elapsed := 0.0
var _tone_remaining := 0.0
var _tone_phase := 0.0
var _tone_hz := 440.0
var _audio_player: AudioStreamPlayer

func _ready() -> void:
    name = "OSGARDFieldLab"
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _create_interface()
    _setup_sound()
    core.feedback_sent.connect(_on_feedback)
    resized.connect(_layout_stage_for_screen)
    call_deferred("_layout_stage_for_screen")
    _refresh()

func _panel_style(base: Color = PANEL, outline: Color = Color("365660"), radius: int = 10) -> StyleBoxFlat:
    var skin := StyleBoxFlat.new()
    skin.bg_color = base
    skin.border_color = outline
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(radius)
    skin.content_margin_left = 15.0
    skin.content_margin_right = 15.0
    skin.content_margin_top = 13.0
    skin.content_margin_bottom = 13.0
    return skin

func _panel(parent: Container) -> VBoxContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", _panel_style())
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(frame)
    var inner := VBoxContainer.new()
    inner.add_theme_constant_override("separation", 9)
    frame.add_child(inner)
    return inner

func _label(parent: Container, value: String = "", font_size: int = 14, color: Color = WHITE) -> Label:
    var node := Label.new()
    node.text = value
    node.add_theme_color_override("font_color", color)
    node.add_theme_font_size_override("font_size", font_size)
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(node)
    return node

func _button(parent: Container, value: String, callback: Callable, accent: bool = false, min_width: float = 142.0) -> Button:
    var node := Button.new()
    node.text = value
    node.focus_mode = Control.FOCUS_ALL
    node.custom_minimum_size = Vector2(min_width, 48)
    node.add_theme_font_size_override("font_size", 12)
    node.add_theme_color_override("font_color", WHITE)
    node.add_theme_color_override("font_hover_color", Color("f5e5cf"))
    node.add_theme_color_override("font_focus_color", Color("f5e5cf"))
    var skin := _panel_style(Color("264945") if accent else PANEL_SOFT, MINT if accent else Color("46606a"), 5)
    skin.content_margin_left = 10
    skin.content_margin_right = 10
    skin.content_margin_top = 8
    skin.content_margin_bottom = 8
    node.add_theme_stylebox_override("normal", skin)
    node.add_theme_stylebox_override("hover", _panel_style(Color("2c5358"), COPPER, 5))
    node.add_theme_stylebox_override("pressed", _panel_style(Color("355c5c"), COPPER, 5))
    node.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, MINT, 5))
    node.add_theme_stylebox_override("disabled", _panel_style(Color("182631"), Color("30444c"), 5))
    node.pressed.connect(callback)
    parent.add_child(node)
    return node

func _flow(parent: Container) -> HFlowContainer:
    var flow := HFlowContainer.new()
    flow.add_theme_constant_override("h_separation", 9)
    flow.add_theme_constant_override("v_separation", 9)
    flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(flow)
    return flow

func _create_interface() -> void:
    var backdrop := ColorRect.new()
    backdrop.name = "DarkLuxuryBackground"
    backdrop.color = BG
    backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
    backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(backdrop)

    scroll = ScrollContainer.new()
    scroll.name = "ScrollableAdaptiveOperatorConsole"
    scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
    scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
    scroll.follow_focus = true
    add_child(scroll)

    var pad := MarginContainer.new()
    pad.add_theme_constant_override("margin_left", 15)
    pad.add_theme_constant_override("margin_right", 15)
    pad.add_theme_constant_override("margin_top", 17)
    pad.add_theme_constant_override("margin_bottom", 22)
    pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(pad)
    body = VBoxContainer.new()
    body.add_theme_constant_override("separation", 13)
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pad.add_child(body)

    var top := _flow(body)
    _label(top, "✦  OSGARD / FIELD LAB", 23, COPPER).custom_minimum_size.x = 270
    lang_btn = _button(top, "RU / EN", _toggle_language, false, 92)
    quality_btn = _button(top, "HERO / ECO", _toggle_quality, false, 125)
    heading = _label(body, "КОНТРОЛЬ. ТОЧНОСТЬ. ОТВЕТСТВЕННОСТЬ.", 22, WHITE)
    lead = _label(body, "", 14, MUTED)

    var stage_section := _panel(body)
    _label(stage_section, "SERVICE MODULE  //  A7     ·     INTERACTIVE 3D SIMULATION", 12, MINT)
    visual_container = SubViewportContainer.new()
    visual_container.name = "TrueNative3DInspectionViewport"
    # W33 actual layout is resized to match viewport and quality below.
    visual_container.custom_minimum_size = Vector2(0, 340)
    visual_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    visual_container.stretch = true
    visual_container.stretch_shrink = 1
    stage_section.add_child(visual_container)
    sub_viewport = SubViewport.new()
    sub_viewport.name = "SourceGodot3DWorld"
    sub_viewport.size = Vector2i(960, 500)
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    visual_container.add_child(sub_viewport)
    scene_3d = OSGARDRig.new()
    scene_3d.name = "ActualSimulatedServiceRig"
    sub_viewport.add_child(scene_3d)
    var cameras := _flow(stage_section)
    for i in range(3):
        view_btns.append(_button(cameras, "CAMERA %02d" % (i + 1), _view_selected.bind(i), false, 162))

    var stats := _panel(body)
    _label(stats, "LIVE READINGS  /  SIMULATED SENSOR FEEDBACK", 12, COPPER)
    telemetry = _label(stats, "", 17, WHITE)
    status = _label(stats, "", 12, MUTED)
    progress_text = _label(stats, "", 12, MINT)
    var commands := _flow(stats)
    engine_btn = _button(commands, "STOP", _engine_clicked, true, 180)
    hatch_btn = _button(commands, "OPEN", _hatch_clicked, false, 180)
    scan_btn = _button(commands, "SCAN", _scan_clicked, true, 180)

    var calibration := _panel(body)
    calibration.name = "DualChannelCalibrationStation"
    cal_title = _label(calibration, "", 15, COPPER)
    a_title = _label(calibration, "A", 12, MUTED)
    slider_a = HSlider.new()
    slider_a.name = "VirtualCalibrationAxisA"
    slider_a.min_value = 0
    slider_a.max_value = 100
    slider_a.step = 1
    slider_a.custom_minimum_size = Vector2(0, 42)
    slider_a.focus_mode = Control.FOCUS_ALL
    slider_a.value_changed.connect(_on_slider_changed.bind("a"))
    calibration.add_child(slider_a)
    a_value = _label(calibration, "0", 13, MINT)
    b_title = _label(calibration, "B", 12, MUTED)
    slider_b = HSlider.new()
    slider_b.name = "VirtualCalibrationAxisB"
    slider_b.min_value = 0
    slider_b.max_value = 100
    slider_b.step = 1
    slider_b.custom_minimum_size = Vector2(0, 42)
    slider_b.focus_mode = Control.FOCUS_ALL
    slider_b.value_changed.connect(_on_slider_changed.bind("b"))
    calibration.add_child(slider_b)
    b_value = _label(calibration, "0", 13, MINT)
    cal_sensors = _label(calibration, "", 13, WHITE)
    cal_help = _label(calibration, "", 12, MUTED)
    signal_progress = ProgressBar.new()
    signal_progress.name = "TrueDiagnosisHoldFraction"
    signal_progress.max_value = 100
    signal_progress.custom_minimum_size = Vector2(0, 23)
    signal_progress.show_percentage = true
    calibration.add_child(signal_progress)

    var guidance := _panel(body)
    _label(guidance, "CAUSE → ACTION  /  ERROR EXPLAINABILITY", 12, COPPER)
    feedback = _label(guidance, "", 14, MINT)
    hint = _label(guidance, "", 13, WHITE)

    # W33: verified action-based assessment, not invented progress. The
    # bounded event history disappears on reload even if training is saved.
    debrief_panel = _panel(body)
    debrief_panel.get_parent().name = "ActionBasedOperatorAssessment"
    debrief_caption = _label(debrief_panel, "", 12, COPPER)
    debrief_label = _label(debrief_panel, "", 13, WHITE)
    var analysis_actions := _flow(debrief_panel)
    debrief_toggle = _button(analysis_actions, "WHY?", _toggle_debrief, false, 185)
    retry_button = _button(analysis_actions, "RETRY", _retry_case, true, 185)
    debrief_timeline = _label(debrief_panel, "", 12, MUTED)
    debrief_timeline.visible = false

    var mission_box := _panel(body)
    mission_title = _label(mission_box, "", 18, COPPER)
    var mission_flow := _flow(mission_box)
    for i in range(6):
        var btn := _button(mission_flow, "CASE %02d" % (i + 1), _case_selected.bind(i), false, 245)
        btn.custom_minimum_size = Vector2(245, 67)
        btn.name = "Mission%02d" % (i + 1)
        mission_btns.append(btn)

    var options := _panel(body)
    _label(options, "LOCAL ONLY  /  ACCESSIBILITY & PRIVACY", 12, COPPER)
    var option_flow := _flow(options)
    motion_btn = _button(option_flow, "REDUCED MOTION", _toggle_motion, false, 175)
    sound_btn = _button(option_flow, "SOUND", _toggle_sound, false, 150)
    captions_btn = _button(option_flow, "CAPTIONS", _toggle_captions, false, 160)
    metrics_btn = _button(option_flow, "METRICS", _toggle_metrics, false, 185)
    erase_btn = _button(option_flow, "ERASE", _erase_data, false, 195)
    footer = _label(body, "", 11, MUTED)

    # Explicit two-action confirmation avoids accidental loss of all records
    # on touchscreens. Merely opening the modal NEVER calls clear_data().
    erase_confirm = ConfirmationDialog.new()
    erase_confirm.name = "ConfirmLocalRecordDeletion"
    erase_confirm.min_size = Vector2i(300, 190)
    erase_confirm.get_label().autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    erase_confirm.confirmed.connect(_confirm_erase)
    add_child(erase_confirm)

func _layout_stage_for_screen() -> void:
    if visual_container == null or sub_viewport == null:
        return
    # Preserve the actual 3D viewport's aspect rather than stretching a
    # fixed 960x500 camera on 360px phones and landscape tablets.
    var available: float = maxf(240.0, size.x - 64.0)
    var desired_h: float = clampf(available * 0.56, 200.0, 420.0)
    visual_container.custom_minimum_size = Vector2(0.0, desired_h)
    var eco: bool = str(core.settings.get("quality", "hero")) == "eco"
    var render_width: int = (576 if eco else 720) if available < 520.0 else (800 if eco else 960)
    var render_height: int = clampi(roundi(float(render_width) * desired_h / available), 300, 960)
    sub_viewport.size = Vector2i(render_width, render_height)

func _setup_sound() -> void:
    var stream := AudioStreamGenerator.new()
    stream.mix_rate = 22050.0
    stream.buffer_length = 0.12
    _audio_player = AudioStreamPlayer.new()
    _audio_player.stream = stream
    _audio_player.volume_db = -18.0
    add_child(_audio_player)

func _sound_event(error: bool) -> void:
    if not bool(core.settings["sound"]):
        return
    _tone_hz = 190.0 if error else 640.0
    _tone_remaining = 0.16
    if not _audio_player.playing:
        _audio_player.play()

func _stream_sound() -> void:
    if _audio_player == null or not _audio_player.playing:
        return
    var playback := _audio_player.get_stream_playback() as AudioStreamGeneratorPlayback
    if playback == null:
        return
    var n := mini(playback.get_frames_available(), 480)
    for i in range(n):
        var volume := 0.0
        if _tone_remaining > 0.0:
            volume = sin(_tone_phase) * 0.10 * minf(1.0, _tone_remaining / 0.04)
            _tone_phase += TAU * _tone_hz / 22050.0
            _tone_remaining -= 1.0 / 22050.0
        playback.push_frame(Vector2(volume, volume))

func _process(delta: float) -> void:
    core.tick(delta)
    if scene_3d != null:
        var visual: Dictionary = core.snapshot()
        visual["quality"] = core.settings["quality"]
        if bool(core.settings["reduced_motion"]):
            visual["rotor_angle"] = 0.0
        scene_3d.apply_simulation(visual)
    _stream_sound()
    _refresh_elapsed += delta
    if _refresh_elapsed >= 0.12:
        _refresh_elapsed = 0.0
        _refresh()

func _unhandled_key_input(event: InputEvent) -> void:
    var key := event as InputEventKey
    if key == null or not key.pressed or key.echo or key.ctrl_pressed or key.alt_pressed or key.meta_pressed:
        return
    if key.keycode == KEY_1:
        _view_selected(0)
    elif key.keycode == KEY_2:
        _view_selected(1)
    elif key.keycode == KEY_3:
        _view_selected(2)
    elif key.keycode == KEY_S:
        _engine_clicked()
    elif key.keycode == KEY_H:
        _hatch_clicked()
    elif key.keycode == KEY_X:
        _scan_clicked()
    else:
        return
    get_viewport().set_input_as_handled()

func _case_selected(index: int) -> void:
    if core.begin_case(index):
        debrief_expanded = false
    _refresh()

func _retry_case() -> void:
    if core.retry_completed_case():
        debrief_expanded = false
    _refresh()

func _toggle_debrief() -> void:
    debrief_expanded = not debrief_expanded
    _refresh()

func _view_selected(index: int) -> void:
    core.set_view(index)
    _refresh()

func _engine_clicked() -> void:
    core.toggle_engine()
    _refresh()

func _hatch_clicked() -> void:
    core.toggle_hatch()
    _refresh()

func _scan_clicked() -> void:
    core.scan()
    _refresh()

func _on_slider_changed(value: float, axis: String) -> void:
    core.adjust_calibration(axis, int(roundf(value)))
    _refresh()

func _toggle_language() -> void:
    core.set_setting("locale", "en" if core.settings["locale"] == "ru" else "ru")
    _refresh()

func _toggle_quality() -> void:
    core.set_setting("quality", "eco" if core.settings["quality"] == "hero" else "hero")
    _layout_stage_for_screen()
    _refresh()

func _toggle_motion() -> void:
    core.set_setting("reduced_motion", not bool(core.settings["reduced_motion"]))
    _refresh()

func _toggle_sound() -> void:
    core.set_setting("sound", not bool(core.settings["sound"]))
    _refresh()

func _toggle_captions() -> void:
    core.set_setting("captions", not bool(core.settings["captions"]))
    _refresh()

func _toggle_metrics() -> void:
    core.set_setting("metrics_consent", not bool(core.settings["metrics_consent"]))
    _refresh()

func _erase_data() -> void:
    erase_confirm.title = _t("erase_confirm_title")
    erase_confirm.dialog_text = _t("erase_confirm_text")
    erase_confirm.popup_centered(Vector2i(300, 200))

func _confirm_erase() -> void:
    core.clear_data()
    debrief_expanded = false
    _refresh()

func _on_feedback(_code: String, error: bool) -> void:
    _sound_event(error)

func _t(key: String) -> String:
    return OSGARDText.text(str(core.settings["locale"]), key)

func _assign(node: Label, value: String) -> void:
    if node != null and node.text != value:
        node.text = value

func _refresh() -> void:
    if body == null:
        return
    var snap: Dictionary = core.snapshot()
    var locale := str(core.settings["locale"])
    _assign(heading, "OSGARD  /  FIELD LAB")
    _assign(lead, _t("lead"))
    _assign(footer, _t("sim") + "   ·   OFFLINE / GODOT 4.4.1 SOURCE PORT")
    lang_btn.text = "RU ●" if locale == "ru" else "EN ●"
    quality_btn.text = _t("quality") + ": " + str(core.settings["quality"]).to_upper()
    motion_btn.text = _t("motion") + (" ✓" if bool(core.settings["reduced_motion"]) else " –")
    sound_btn.text = _t("sound") + (" ✓" if bool(core.settings["sound"]) else " –")
    captions_btn.text = _t("captions") + (" ✓" if bool(core.settings["captions"]) else " –")
    metrics_btn.text = _t("privacy") + (" ✓" if bool(core.settings["metrics_consent"]) else " –")
    erase_btn.text = _t("erase")
    _assign(telemetry, "%s  %04d RPM     |     %s  %3d%%     |     %s  %d/150" % [
        _t("rpm"), roundi(float(snap["rpm"])), _t("hatch"), roundi(float(snap["hatch"]) * 100.0), _t("score"), int(snap["score"])])
    _assign(status, "%s: %02d / 06      •      %s: %d      •      %s: %.1f s" % [
        _t("select"), maxi(0, int(snap["mission"]) + 1), _t("progress"), int(snap["step"]), _t("elapsed"), float(snap["seconds"])])
    var step_names := [_t("step0"), _t("step1"), _t("step2"), _t("step3"), _t("step4")]
    _assign(progress_text, " → ".join(step_names) + "    |    %d/3 + %d/3" % [int(snap["cleared_count"]), int(snap["shift_cleared_count"])])
    engine_btn.text = _t("drive_stop") if bool(snap["drive_on"]) else _t("drive_start")
    hatch_btn.text = _t("hatch_close") if float(snap["hatch_target"]) == 1.0 else _t("hatch_open")
    scan_btn.text = _t("scan")
    for i in range(3):
        view_btns[i].text = _t("view%d" % i) + ("  ●" if int(snap["view"]) == i else "")
    var active_fault := int(snap["fault"])
    cal_title.text = "%s  ·  %s" % [_t("signal"), _t("select") if active_fault < 0 else _t("base%d" % active_fault)]
    slider_a.editable = bool(snap["inspection_allowed"])
    slider_b.editable = bool(snap["inspection_allowed"])
    if active_fault >= 0:
        a_title.text = _t("a%d" % active_fault)
        b_title.text = _t("b%d" % active_fault)
        slider_a.set_value_no_signal(float(snap["puzzle"]["a"]))
        slider_b.set_value_no_signal(float(snap["puzzle"]["b"]))
        a_value.text = "%d / 100" % int(snap["puzzle"]["a"])
        b_value.text = "%d / 100" % int(snap["puzzle"]["b"])
        var c: Dictionary = snap["calibration"]
        var reading: Dictionary = c.get("reading", {})
        if active_fault == 0:
            cal_sensors.text = "BEAM: %.2f mm    ·    FOCUS: %d%%" % [float(reading.get("alignment_mm", 0.0)), int(reading.get("focus_percent", 0))]
        elif active_fault == 1:
            cal_sensors.text = "TEMPERATURE: %.1f °C    ·    FLOW: %d%%" % [float(reading.get("outlet_c", 0.0)), int(reading.get("airflow_percent", 0))]
        else:
            cal_sensors.text = "LEFT: %.2f mm    ·    RIGHT: %.2f mm" % [float(reading.get("left_gap_mm", 0.0)), float(reading.get("right_gap_mm", 0.0))]
        signal_progress.value = int(c.get("hold_percent", 0))
        cal_help.text = "%s: %d%%  /  %.2f s" % [_t("stability"), int(c.get("hold_percent", 0)), float(c.get("required_seconds", 0.45))]
    else:
        slider_a.editable = false
        slider_b.editable = false
        a_title.text = "A / CHANNEL"
        b_title.text = "B / CHANNEL"
        signal_progress.value = 0
        a_value.text = "—"
        b_value.text = "—"
        cal_sensors.text = _t("intro")
        cal_help.text = ""
    var message := str(snap["feedback"])
    _assign(feedback, _t("error_" + message) if _t("error_" + message) != "error_" + message else message)
    feedback.add_theme_color_override("font_color", CORAL if bool(snap["last_error"]) else MINT)
    _assign(hint, OSGARDText.coach(locale, snap))
    _refresh_session_debrief(snap)
    _assign(mission_title, _t("select") + "   ·   %d/6" % [int(snap["cleared_count"]) + int(snap["shift_cleared_count"])])
    for i in range(6):
        var is_advanced := i >= 3
        var idx := i - 3 if is_advanced else i
        var board: Dictionary = snap["shifts"] if is_advanced else snap["records"]
        var unlocked: bool = not is_advanced or bool(snap["records"]["cleared"][idx])
        var best: int = int(board["best"][idx])
        var cleared: bool = bool(board["cleared"][idx])
        mission_btns[i].disabled = bool(snap["active"]) or not unlocked
        mission_btns[i].text = _t("adv%d" % idx) if is_advanced else _t("base%d" % idx)
        mission_btns[i].text += "\n" + (_t("locked") if not unlocked else _t("cleared") if cleared else "NEW")
        mission_btns[i].text += "   ·   %s  %03d/150" % [_t("best"), best]



func _refresh_session_debrief(snap: Dictionary) -> void:
    if debrief_label == null or debrief_timeline == null:
        return
    _assign(debrief_caption, _t("debrief"))
    var review: Dictionary = snap.get("session_review", {})
    var history: Array = snap.get("session_history", [])
    debrief_toggle.text = _t("debrief_less") if debrief_expanded else _t("debrief_more")
    debrief_timeline.visible = debrief_expanded
    retry_button.text = _t("retry")
    retry_button.disabled = not bool(snap.get("complete", false)) or bool(snap.get("active", false))
    if not review.is_empty():
        var grade: String = _t("grade_" + str(review.get("grade", "PRACTICE")))
        var indicators: PackedStringArray = PackedStringArray()
        for stage in review.get("protocol", []):
            var step_text: String = _t("protocol_" + str(stage.get("code", "")))
            var symbol: String = "OK" if bool(stage.get("completed", false)) else "--"
            indicators.append(symbol + " " + step_text)
        var reasons: PackedStringArray = PackedStringArray()
        for code in review.get("unique_error_codes", []):
            reasons.append(_t("error_" + str(code)))
        var mistake_line: String = " · ".join(reasons)
        var score_line: String = "%s: %s   ·   %s: %d   ·   %d/150\n%s\n%s" % [
            _t("completed_grade"), grade, _t("errors_count"), int(review.get("errors", 0)),
            int(review.get("score", 0)), _t("step_check"), "  •  ".join(indicators)]
        if not mistake_line.is_empty():
            score_line += "\n" + mistake_line
        _assign(debrief_label, score_line)
    elif bool(snap.get("active", false)):
        _assign(debrief_label, _t("debrief_running") + "  ·  " + _t("errors_count") + ": " + str(snap.get("errors", 0)))
    else:
        _assign(debrief_label, _t("debrief_empty"))
    var rows: PackedStringArray = PackedStringArray()
    for i in range(maxi(0, history.size() - 10), history.size()):
        var event: Dictionary = history[i]
        var code: String = str(event.get("event", ""))
        var label: String = _t("error_" + code)
        if label == "error_" + code:
            label = _t("protocol_" + code)
        if label == "protocol_" + code:
            label = code
        rows.append("%05.1f s   %s  %s" % [
            float(event.get("seconds", 0)), "!" if bool(event.get("error", false)) else "+", label])
    _assign(debrief_timeline, _t("timeline") + "\n" + ("\n".join(rows) if not rows.is_empty() else _t("no_history")))
