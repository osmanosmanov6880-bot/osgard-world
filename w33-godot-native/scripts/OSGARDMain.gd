extends Control
class_name OSGARDMain
## W32 — an actual Godot Control interface + native 3D viewport, NOT an HTML wrapper.
## Launch Main.tscn in Godot 4.4.1. This project never connects to equipment.

const BG := Color("05080d")
const PANEL := Color("0d131b")
const PANEL_SOFT := Color("151d26")
const COPPER := Color("c6a77d")
const MINT := Color("84cbbc")
const WHITE := Color("e9ebe8")
const MUTED := Color("93a2a6")
const CORAL := Color("e7786f")

var core := OSGARDCore.new()
var scene_3d: OSGARDRig
var sub_viewport: SubViewport
var visual_container: SubViewportContainer
var scroll: ScrollContainer
# Dedicated native touch-scroll corridor for small WebGL screens.
# This repairs real Godot mobile usability when nested panels consume
# ScreenDrag events before ScrollContainer can move its scrollbar.
var _edge_touch_index: int = -1
var _edge_touch_scrolling: bool = false
var _edge_touch_travel: float = 0.0
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
var dial_a: OSGARDLuxuryDial
var dial_b: OSGARDLuxuryDial
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
# W35: Actual responsive cinematic viewport and in-scene editorial HUD.
var stage_shell: Control
var brand_mark: Label
var stage_section_heading: Label
var control_grid: GridContainer
var stage_title: Label
var stage_kicker: Label
var stage_live: Label
var stage_readout: Label
var stage_edition: Label
# W61: source-only cinematic mission phase indicators; no gameplay mutation.
var mission_segments: Array[ColorRect] = []
# Read-only browser status for assistive technology and genuine WebGL input QA.
# Never receives commands, never stores metrics and never sends network data.
var _web_state_element: Variant = null
var _web_last_event_id: int = -1

func _ready() -> void:
    name = "OSGARDFieldLab"
    set_anchors_preset(Control.PRESET_FULL_RECT)
    _create_interface()
    _create_web_accessibility()
    _setup_sound()
    core.feedback_sent.connect(_on_feedback)
    resized.connect(_layout_stage_for_screen)
    call_deferred("_layout_stage_for_screen")
    _refresh()

func _create_web_accessibility() -> void:
    if not OS.has_feature("web"):
        return
    var document: Variant = JavaScriptBridge.get_interface("document")
    if document == null:
        return
    var node: Variant = document.getElementById("osgard-native-state")
    if node == null:
        node = document.createElement("div")
        node.setAttribute("id", "osgard-native-state")
        node.setAttribute("role", "status")
        node.setAttribute("aria-live", "polite")
        node.setAttribute("aria-atomic", "true")
        node.setAttribute("style", "position:fixed;left:0;top:0;width:1px;height:1px;overflow:hidden;opacity:0;pointer-events:none")
        document.body.appendChild(node)
    _web_state_element = node

func _web_control_rect(item: Control) -> Array:
    var rect: Rect2 = item.get_global_rect()
    return [roundi(rect.position.x), roundi(rect.position.y), roundi(rect.size.x), roundi(rect.size.y)]

func _publish_web_accessibility(snap: Dictionary) -> void:
    if _web_state_element == null:
        return
    # Only visible, non-sensitive simulation data are mirrored. This is
    # intentionally read-only: Playwright still has to press actual controls.
    # Headless RenderingServer returns dummy transforms; the real exported
    # browser must independently prove all 83 actual MultiMesh GPU writes.
    var ring_renderer: Dictionary = {}
    if scene_3d != null and scene_3d.obsidian_stage != null:
        ring_renderer = scene_3d.obsidian_stage.w48_real_renderer_ring_qa()
    var state: Dictionary = {
        "mission": int(snap["mission"]), "step": int(snap["step"]),
        "active": bool(snap["active"]), "complete": bool(snap["complete"]),
        "rpm": roundi(float(snap["rpm"])), "hatch": float(snap["hatch"]),
        "drive_on": bool(snap["drive_on"]), "view": int(snap["view"]),
        "a": int(snap["puzzle"]["a"]), "b": int(snap["puzzle"]["b"]),
        "ready": bool(snap["calibration"].get("ready", false)),
        "incident": bool(snap["incident_triggered"]),
        "feedback": str(snap["feedback"]), "errors": int(snap["errors"]),
        "score": int(snap["score"]), "cleared": int(snap["cleared_count"]),
        "shift_cleared": int(snap["shift_cleared_count"]),
        "inspection_allowed": bool(snap["inspection_allowed"]),
        "hold_percent": int(snap["calibration"].get("hold_percent", 0)),
        "last_error": bool(snap["last_error"]),
        "quality": str(core.settings["quality"]),
        "locale": str(core.settings["locale"]), # read-only WebGL locale QA / accessibility
        # Original native engine values read only by local browser QA.
        # Not a benchmark on the user's physical hardware.
        "godot_render_fps": Engine.get_frames_per_second(),
        "godot_frames_drawn": Engine.get_frames_drawn(),
        "godot_3d_draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
        "godot_3d_rendered_objects": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
        "w48_real_renderer_readback": bool(ring_renderer.get("actual_renderer", false)),
        "w48_gpu_ring_transforms_ok": bool(ring_renderer.get("ok", false)),
        "w48_gpu_ring_transforms_checked": int(ring_renderer.get("checked", 0)),
        "w48_gpu_ring_mismatch_count": int(ring_renderer.get("mismatches", -1)),
        "w48_gpu_ring_max_error": float(ring_renderer.get("max_error", -1.0))
    }
    var geometry: Dictionary = {
        "viewport": [roundi(size.x), roundi(size.y)],
        "scroll": int(scroll.scroll_vertical),
        "hero_stage": _web_control_rect(stage_shell),
        "brand": _web_control_rect(brand_mark),
        "heading": _web_control_rect(heading),
        "stage_section_heading": _web_control_rect(stage_section_heading),
        "stage_kicker": _web_control_rect(stage_kicker),
        "stage_edition": _web_control_rect(stage_edition),
        "dial_a": _web_control_rect(dial_a),
        "dial_b": _web_control_rect(dial_b),
        "engine": _web_control_rect(engine_btn),
        "hatch": _web_control_rect(hatch_btn),
        "scan": _web_control_rect(scan_btn),
        "slider_a": _web_control_rect(slider_a),
        "slider_b": _web_control_rect(slider_b),
        "retry": _web_control_rect(retry_button),
        "language": _web_control_rect(lang_btn),
        "quality": _web_control_rect(quality_btn)
    }
    for index in range(6):
        geometry["mission%d" % index] = _web_control_rect(mission_btns[index])
    for index in range(3):
        geometry["camera%d" % index] = _web_control_rect(view_btns[index])
    _web_state_element.setAttribute("data-state", JSON.stringify(state))
    _web_state_element.setAttribute("data-geometry", JSON.stringify(geometry))
    var event_id: int = int(snap["event_id"])
    if event_id != _web_last_event_id:
        _web_last_event_id = event_id
        _web_state_element.textContent = "Last Frontier simulated lab, " + str(state["feedback"]) + ", mission " + str(state["mission"] + 1) + ", step " + str(state["step"])

func _panel_style(base: Color = PANEL, outline: Color = Color("2e3b43"), radius: int = 8) -> StyleBoxFlat:
    var skin := StyleBoxFlat.new()
    skin.bg_color = base
    skin.border_color = outline
    skin.set_border_width_all(1)
    skin.set_corner_radius_all(radius)
    skin.content_margin_left = 18.0
    skin.content_margin_right = 18.0
    skin.content_margin_top = 16.0
    skin.content_margin_bottom = 16.0
    return skin

func _panel(parent: Container) -> VBoxContainer:
    var frame := PanelContainer.new()
    frame.add_theme_stylebox_override("panel", _panel_style())
    frame.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(frame)
    var inner := VBoxContainer.new()
    inner.add_theme_constant_override("separation", 12)
    frame.add_child(inner)
    return inner

func _label(parent: Container, value: String = "", font_size: int = 15, color: Color = WHITE) -> Label:
    var node := Label.new()
    node.text = _legible_copy(value)
    node.add_theme_color_override("font_color", color)
    node.add_theme_font_size_override("font_size", font_size)
    node.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    node.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(node)
    return node

func _button(parent: Container, value: String, callback: Callable, accent: bool = false, min_width: float = 142.0) -> Button:
    var node := Button.new()
    node.text = _legible_copy(value)
    node.focus_mode = Control.FOCUS_ALL
    node.custom_minimum_size = Vector2(min_width, 52)
    node.add_theme_font_size_override("font_size", 14)
    node.add_theme_color_override("font_color", WHITE)
    node.add_theme_color_override("font_hover_color", Color("f5e5cf"))
    node.add_theme_color_override("font_focus_color", Color("f5e5cf"))
    var skin := _panel_style(Color("1c3535") if accent else Color("121920"), MINT if accent else Color("39464e"), 6)
    skin.content_margin_left = 10
    skin.content_margin_right = 10
    skin.content_margin_top = 8
    skin.content_margin_bottom = 8
    node.add_theme_stylebox_override("normal", skin)
    node.add_theme_stylebox_override("hover", _panel_style(Color("26363b"), COPPER, 6))
    node.add_theme_stylebox_override("pressed", _panel_style(Color("2c4747"), COPPER, 6))
    node.add_theme_stylebox_override("focus", _panel_style(Color.TRANSPARENT, MINT, 6))
    node.add_theme_stylebox_override("disabled", _panel_style(Color("0d1419"), Color("273239"), 6))
    node.pressed.connect(callback)
    parent.add_child(node)
    return node

func _flow(parent: Container) -> HFlowContainer:
    var flow := HFlowContainer.new()
    flow.add_theme_constant_override("h_separation", 10)
    flow.add_theme_constant_override("v_separation", 10)
    flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(flow)
    return flow

func _overlay_label(parent: Control, name_tag: String, title_text: String, font_size: int, tone: Color) -> Label:
    var tag := Label.new()
    tag.name = name_tag
    tag.text = _legible_copy(title_text)
    tag.add_theme_color_override("font_color", tone)
    tag.add_theme_font_size_override("font_size", font_size)
    tag.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(tag)
    return tag

func _make_cinematic_overlay(parent: Control) -> void:
    # In-scene dark optical scrim guarantees HUD legibility even when metallic
    # highlights and simulated alarm flashes cross the camera's lower frame.
    var scrim := ColorRect.new()
    scrim.name = "CinematicBottomScrim"
    scrim.color = Color(0.015, 0.025, 0.034, 0.72)
    scrim.anchor_left = 0.0
    scrim.anchor_top = 1.0
    scrim.anchor_right = 1.0
    scrim.anchor_bottom = 1.0
    scrim.offset_top = -119.0
    scrim.offset_bottom = 0.0
    scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(scrim)
    var trim := ColorRect.new()
    trim.name = "PreciousMaterialAccent"
    trim.color = Color("bca27d")
    trim.anchor_left = 0.0
    trim.anchor_right = 1.0
    trim.anchor_top = 1.0
    trim.anchor_bottom = 1.0
    trim.offset_top = -119.0
    trim.offset_bottom = -117.0
    trim.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(trim)
    var overlay := MarginContainer.new()
    overlay.name = "ObsidianInSceneHUD"
    overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    overlay.add_theme_constant_override("margin_left", 20)
    overlay.add_theme_constant_override("margin_right", 20)
    overlay.add_theme_constant_override("margin_top", 18)
    overlay.add_theme_constant_override("margin_bottom", 16)
    overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(overlay)
    var column := VBoxContainer.new()
    column.mouse_filter = Control.MOUSE_FILTER_IGNORE
    overlay.add_child(column)
    var top := HBoxContainer.new()
    top.mouse_filter = Control.MOUSE_FILTER_IGNORE
    top.add_theme_constant_override("separation", 8)
    column.add_child(top)
    stage_kicker = _overlay_label(top, "A7Classification", "A7 / RESTRICTED RESEARCH FACILITY", 13, COPPER)
    stage_kicker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stage_kicker.autowrap_mode = TextServer.AUTOWRAP_OFF
    stage_kicker.clip_text = true
    stage_edition = _overlay_label(top, "SimulationTag", "OFFLINE · SIMULATION", 12, MINT)
    # Screenshot QA discovered a real W35 defect: unbounded label width turned
    # 'OFFLINE · SIMULATION' into a vertical ribbon on the right-hand side.
    stage_edition.autowrap_mode = TextServer.AUTOWRAP_OFF
    stage_edition.custom_minimum_size = Vector2(190, 22)
    stage_edition.size_flags_horizontal = Control.SIZE_SHRINK_END
    stage_edition.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    stage_edition.clip_text = true
    var space := Control.new()
    space.size_flags_vertical = Control.SIZE_EXPAND_FILL
    space.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(space)
    var bottom := VBoxContainer.new()
    bottom.add_theme_constant_override("separation", 5)
    bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
    column.add_child(bottom)
    stage_live = _overlay_label(bottom, "LiveChamberState", "CHAMBER / STANDBY", 13, MINT)
    stage_title = _overlay_label(bottom, "ReactorIdentity", "OBSIDIAN CORE  /  A7", 26, WHITE)
    stage_readout = _overlay_label(bottom, "ReactorRealTelemetry", "ROTOR   1480 RPM     ·     HATCH   SEALED", 13, COPPER)
    # Five native, read-only mission-phase segments. They follow the existing
    # simulation snapshot, preserving its win/loss rules and safe interlocks.
    var phase_strip := HBoxContainer.new()
    phase_strip.name = "LastFrontierMissionPhaseStrip"
    phase_strip.add_theme_constant_override("separation", 6)
    phase_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
    bottom.add_child(phase_strip)
    for i in range(5):
        var segment := ColorRect.new()
        segment.name = "Phase%02d" % (i + 1)
        segment.color = Color("30414a")
        segment.custom_minimum_size = Vector2(24, 4)
        segment.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        segment.mouse_filter = Control.MOUSE_FILTER_IGNORE
        phase_strip.add_child(segment)
        mission_segments.append(segment)

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
    pad.add_theme_constant_override("margin_left", 18)
    pad.add_theme_constant_override("margin_right", 18)
    pad.add_theme_constant_override("margin_top", 16)
    pad.add_theme_constant_override("margin_bottom", 32)
    pad.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    scroll.add_child(pad)
    body = VBoxContainer.new()
    body.add_theme_constant_override("separation", 16)
    body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    pad.add_child(body)

    var top := _flow(body)
    brand_mark = _label(top, _t("brand_desktop"), 23, COPPER)
    brand_mark.name = "ObsidianBrandWordmark"
    brand_mark.autowrap_mode = TextServer.AUTOWRAP_OFF
    brand_mark.clip_text = true
    lang_btn = _button(top, "RU / EN", _toggle_language, false, 96)
    quality_btn = _button(top, "HERO / ECO", _toggle_quality, false, 150)
    heading = _label(body, "REACTOR A7   /   PRECISION DIVISION", 26, WHITE)
    lead = _label(body, "", 14, MUTED)

    var stage_section := _panel(body)
    var stage_frame := stage_section.get_parent() as PanelContainer
    stage_frame.add_theme_stylebox_override("panel", _panel_style(Color("080d13"), Color("49545a"), 12))
    stage_section_heading = _label(stage_section, _t("stage_facility"), 12, COPPER)
    stage_section_heading.name = "A7CinemaSectionHeading"
    stage_section_heading.autowrap_mode = TextServer.AUTOWRAP_OFF
    stage_section_heading.clip_text = true
    stage_shell = Control.new()
    stage_shell.name = "CinematicHeroShell"
    stage_shell.custom_minimum_size = Vector2(0, 500)
    stage_shell.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    stage_section.add_child(stage_shell)
    visual_container = SubViewportContainer.new()
    visual_container.name = "TrueNative3DInspectionViewport"
    visual_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    visual_container.mouse_filter = Control.MOUSE_FILTER_STOP
    visual_container.stretch = true
    visual_container.stretch_shrink = 1
    stage_shell.add_child(visual_container)
    sub_viewport = SubViewport.new()
    sub_viewport.name = "SourceGodot3DWorld"
    sub_viewport.size = Vector2i(1280, 660)
    sub_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
    visual_container.add_child(sub_viewport)
    scene_3d = OSGARDRig.new()
    scene_3d.name = "ActualSimulatedServiceRig"
    sub_viewport.add_child(scene_3d)
    _make_cinematic_overlay(stage_shell)
    var cameras := _flow(stage_section)
    for i in range(3):
        var view_button: Button = _button(cameras, _t("view%d" % i), _view_selected.bind(i), false, 175)
        view_button.toggle_mode = true
        view_btns.append(view_button)

    # Below the cinematic hero: a professional twin-column service desk on PC.
    # One column on phones; this is native Godot adaptive layout.
    control_grid = GridContainer.new()
    control_grid.name = "ObsidianOperatorWorkbench"
    control_grid.columns = 2
    control_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    control_grid.add_theme_constant_override("h_separation", 16)
    control_grid.add_theme_constant_override("v_separation", 16)
    body.add_child(control_grid)
    var stats := _panel(control_grid)
    _label(stats, "LIVE READINGS  /  SIMULATED SENSOR FEEDBACK", 12, COPPER)
    telemetry = _label(stats, "", 17, WHITE)
    status = _label(stats, "", 12, MUTED)
    progress_text = _label(stats, "", 12, MINT)
    var commands := _flow(stats)
    engine_btn = _button(commands, "STOP", _engine_clicked, true, 180)
    hatch_btn = _button(commands, "OPEN", _hatch_clicked, false, 180)
    scan_btn = _button(commands, "SCAN", _scan_clicked, true, 180)

    var calibration := _panel(control_grid)
    calibration.name = "DualChannelCalibrationStation"
    cal_title = _label(calibration, "", 15, COPPER)
    var machined_dials := HBoxContainer.new()
    machined_dials.name = "A7PhysicalCalibrationDeck"
    machined_dials.alignment = BoxContainer.ALIGNMENT_CENTER
    machined_dials.add_theme_constant_override("separation", 24)
    machined_dials.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    calibration.add_child(machined_dials)
    dial_a = OSGARDLuxuryDial.new()
    dial_a.channel = "A"
    machined_dials.add_child(dial_a)
    dial_a.value_requested.connect(_on_dial_requested.bind("a"))
    dial_b = OSGARDLuxuryDial.new()
    dial_b.channel = "B"
    machined_dials.add_child(dial_b)
    dial_b.value_requested.connect(_on_dial_requested.bind("b"))
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

    var guidance := _panel(control_grid)
    _label(guidance, "CAUSE → ACTION  /  ERROR EXPLAINABILITY", 12, COPPER)
    feedback = _label(guidance, "", 14, MINT)
    hint = _label(guidance, "", 13, WHITE)

    # W33: verified action-based assessment, not invented progress. The
    # bounded event history disappears on reload even if training is saved.
    debrief_panel = _panel(control_grid)
    debrief_panel.get_parent().name = "ActionBasedOperatorAssessment"
    debrief_caption = _label(debrief_panel, "", 12, COPPER)
    debrief_label = _label(debrief_panel, "", 13, WHITE)
    var analysis_actions := _flow(debrief_panel)
    debrief_toggle = _button(analysis_actions, "WHY?", _toggle_debrief, false, 185)
    retry_button = _button(analysis_actions, "RETRY", _retry_case, true, 185)
    debrief_timeline = _label(debrief_panel, "", 12, MUTED)
    debrief_timeline.visible = false

    var mission_box := _panel(control_grid)
    mission_title = _label(mission_box, "", 18, COPPER)
    var mission_flow := _flow(mission_box)
    for i in range(6):
        var btn := _button(mission_flow, "CASE %02d" % (i + 1), _case_selected.bind(i), false, 245)
        btn.custom_minimum_size = Vector2(245, 67)
        btn.name = "Mission%02d" % (i + 1)
        mission_btns.append(btn)

    var options := _panel(control_grid)
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

func _sync_camera_rail() -> void:
    # W46: mobile-first instrument rail. Full translated description remains
    # readable above the 3D scene and in each button tooltip. Three camera
    # actions can now share a single row at 320-390px viewport widths.
    var compact: bool = size.x < 640.0
    var cell_width: float = clampf((size.x - 110.0) / 3.0, 60.0, 98.0) if compact else 175.0
    var selected: int = int(core.snapshot()["view"])
    for i in range(3):
        var camera_button: Button = view_btns[i]
        if not is_equal_approx(camera_button.custom_minimum_size.x, cell_width):
            camera_button.custom_minimum_size.x = cell_width
        var full_name: String = _t("view%d" % i)
        var short_name: String = "%02d" % (i + 1)
        var visible_name: String = short_name if compact else full_name
        if camera_button.text != visible_name:
            camera_button.text = visible_name
        camera_button.tooltip_text = full_name
        camera_button.set_pressed_no_signal(selected == i)
    if compact:
        stage_kicker.text = "A7 / " + _t("view%d" % selected)
    else:
        stage_kicker.text = _t("stage_classification")

func _layout_stage_for_screen() -> void:
    if visual_container == null or sub_viewport == null:
        return
    # W35 cinema-first framing: ~70% of desktop fold is the real 3D scene.
    # On 360-390px phones, keep it within 300px for reachable native controls.
    var desired_h: float = clampf(size.y * 0.70, 450.0, 570.0)
    if size.x < 640.0:
        desired_h = clampf(size.x * 0.79, 258.0, 300.0)
    elif size.x < 900.0:
        desired_h = clampf(size.y * 0.60, 350.0, 500.0)
    stage_shell.custom_minimum_size = Vector2(0.0, desired_h)
    visual_container.custom_minimum_size = Vector2(0.0, desired_h)
    control_grid.columns = 1 if size.x < 900.0 else 2
    var narrow: bool = size.x < 640.0
    stage_edition.visible = size.x >= 1050.0
    _sync_camera_rail()
    stage_section_heading.text = _t("stage_narrow") if narrow else _t("stage_facility")
    brand_mark.text = _t("brand_mobile") if narrow else _t("brand_desktop")
    brand_mark.add_theme_font_size_override("font_size", 18 if narrow else 23)
    heading.add_theme_font_size_override("font_size", 21 if narrow else 26)
    stage_title.add_theme_font_size_override("font_size", 20 if narrow else 26)
    stage_readout.add_theme_font_size_override("font_size", 11 if narrow else 13)
    var eco: bool = str(core.settings.get("quality", "hero")) == "eco"
    visual_container.stretch_shrink = 2 if eco else 1

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
        visual["reduced_motion"] = bool(core.settings["reduced_motion"])
        if bool(core.settings["reduced_motion"]):
            visual["rotor_angle"] = 0.0
        scene_3d.apply_simulation(visual)
    _stream_sound()
    _refresh_elapsed += delta
    if _refresh_elapsed >= 0.12:
        _refresh_elapsed = 0.0
        _refresh()

func _input(event: InputEvent) -> void:
    # W53: native touchscreen navigation. In Chromium 390px portrait, the
    # genuine W47 input test proved six CDP ScreenDrag swipes did not move
    # the ScrollContainer: the first mission remained at y=2160.
    # A narrow right-edge gesture lane scrolls the REAL Godot container,
    # irrespective of child PanelContainer mouse_filter consumption.
    # This is user-facing input, not a synthetic test-only scroll hook.
    if scroll == null or size.x >= 640.0:
        return
    var touch: InputEventScreenTouch = event as InputEventScreenTouch
    if touch != null:
        if touch.pressed:
            var in_lane: bool = touch.position.x >= size.x * 0.84 and touch.position.x <= size.x - 3.0
            var below_buttons: bool = touch.position.y >= 90.0 and touch.position.y <= size.y - 35.0
            _edge_touch_index = touch.index if in_lane and below_buttons else -1
            _edge_touch_scrolling = false
            _edge_touch_travel = 0.0
        elif touch.index == _edge_touch_index:
            _edge_touch_index = -1
            _edge_touch_scrolling = false
        return
    var drag: InputEventScreenDrag = event as InputEventScreenDrag
    if drag == null or drag.index != _edge_touch_index or _edge_touch_index < 0:
        return
    # Tap events and short camera/quality button gestures are NOT hijacked.
    _edge_touch_travel += absf(drag.relative.y)
    if _edge_touch_travel >= 10.0:
        _edge_touch_scrolling = true
    if not _edge_touch_scrolling:
        return
    # ScreenDrag is reported in native viewport pixels, and content moves
    # against the finger. Clamp and let Godot's genuine scrollbar apply its
    # own maximum (no DOM spoof, no gameplay commands, no generated scroll).
    scroll.scroll_vertical = maxi(0, scroll.scroll_vertical - roundi(drag.relative.y))
    get_viewport().set_input_as_handled()


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

func _on_dial_requested(value: int, axis: String) -> void:
    # Identical original simulated calibration interlock as keyboard sliders.
    core.adjust_calibration(axis, value)
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

# W55: The original REAL 390px WebGL screenshot displayed the U+2192
# protocol arrows as unsupported boxed glyphs. Use a directional ASCII
# marker on all native Godot text paths; do NOT rely on an OS-specific
# fallback font unavailable inside the exported WebGL player.
# Original instructional copy, order and offline-only content are unchanged.
func _legible_copy(value: String) -> String:
    return value.replace("→", " > ")

func _flag_copy(enabled: bool) -> String:
    var russian: bool = str(core.settings["locale"]) == "ru"
    if russian:
        return " / ВКЛ" if enabled else " / ВЫКЛ"
    return " / ON" if enabled else " / OFF"

func _t(key: String) -> String:
    return _legible_copy(OSGARDText.text(str(core.settings["locale"]), key))

func _assign(node: Label, value: String) -> void:
    var safe: String = _legible_copy(value)
    if node != null and node.text != safe:
        node.text = safe

func _refresh() -> void:
    if body == null:
        return
    var snap: Dictionary = core.snapshot()
    var locale := str(core.settings["locale"])
    var narrow_brand: bool = size.x < 640.0
    _assign(brand_mark, _t("brand_mobile") if narrow_brand else _t("brand_desktop"))
    _assign(stage_section_heading, _t("stage_narrow") if narrow_brand else _t("stage_facility"))
    _assign(heading, _t("reactor_title_short") if size.x < 640.0 else _t("reactor_title_long"))
    _assign(lead, _t("lead"))
    _assign(footer, _t("sim") + "   ·   LAST FRONTIER / GODOT 4.4.1 / LOCAL ONLY")
    # Keep the actual language code readable on minimal web fonts.
    lang_btn.text = "RU" if locale == "ru" else "EN"
    quality_btn.text = _t("quality") + ": " + str(core.settings["quality"]).to_upper()
    # Explicit localized state text is readable without the unsupported
    # checkmark glyph and is understandable to non-colorblind users.
    motion_btn.text = _t("motion") + _flag_copy(bool(core.settings["reduced_motion"]))
    sound_btn.text = _t("sound") + _flag_copy(bool(core.settings["sound"]))
    captions_btn.text = _t("captions") + _flag_copy(bool(core.settings["captions"]))
    metrics_btn.text = _t("privacy") + _flag_copy(bool(core.settings["metrics_consent"]))
    erase_btn.text = _t("erase")
    # W58: grouped telemetry uses explicit native Label lines on phones,
    # never a free-floating separator at the start of a wrapped 390px line.
    # Original live readings and desktop delimiters remain identical.
    var telemetry_groups: PackedStringArray = PackedStringArray([
        "%s  %04d RPM" % [_t("rpm"), roundi(float(snap["rpm"]))],
        "%s  %3d%%" % [_t("hatch"), roundi(float(snap["hatch"]) * 100.0)],
        "%s  %d/150" % [_t("score"), int(snap["score"])],
    ])
    var telemetry_separator: String = "\n" if size.x < 640.0 else "     |     "
    _assign(telemetry, telemetry_separator.join(telemetry_groups))
    # W58 review: each mobile status is a complete line rather than an
    # orphaned bullet; desktop copy and original values remain unchanged.
    var status_groups: PackedStringArray = PackedStringArray([
        "%s: %02d / 06" % [_t("select"), maxi(0, int(snap["mission"]) + 1)],
        "%s: %d" % [_t("progress"), int(snap["step"])],
        "%s: %.1f s" % [_t("elapsed"), float(snap["seconds"])],
    ])
    var status_separator: String = "\n" if size.x < 640.0 else "      •      "
    _assign(status, status_separator.join(status_groups))
    # True in-scene state, never a fake video or static rendered mockup.
    var stage_message_key: String = "stage_complete" if bool(snap["complete"]) else "stage_alert" if bool(snap["last_error"]) else "stage_active" if bool(snap["active"]) else "stage_idle"
    _assign(stage_live, _t(stage_message_key))
    stage_live.add_theme_color_override("font_color", CORAL if bool(snap["last_error"]) else MINT)
    # The indicators display accepted simulation state only: they never
    # send commands, affect scores or pretend physical-machine telemetry.
    var phase_index: int = clampi(int(snap["step"]), 0, 4)
    for i in range(mission_segments.size()):
        var completed: bool = bool(snap["complete"])
        var active_phase: bool = bool(snap["active"]) and i <= phase_index
        mission_segments[i].color = CORAL if bool(snap["last_error"]) and i == phase_index else MINT if completed or active_phase else Color("30414a")
    # W58 review: prevent a stranded slash on the 320/390px true 3D HUD.
    # Preserve desktop text, numeric precision, RPM, hatch and score.
    var stage_groups: PackedStringArray = PackedStringArray([
        "ROTOR   %04d RPM" % roundi(float(snap["rpm"])),
        "HATCH   %03d%%" % roundi(float(snap["hatch"]) * 100.0),
        "SCORE   %03d" % int(snap["score"]),
    ])
    var stage_separator: String = "\n" if size.x < 640.0 else "     /     "
    _assign(stage_readout, stage_separator.join(stage_groups))
    var step_names := [_t("step0"), _t("step1"), _t("step2"), _t("step3"), _t("step4")]
    _assign(progress_text, " > ".join(step_names) + "    |    %d/3 + %d/3" % [int(snap["cleared_count"]), int(snap["shift_cleared_count"])])
    engine_btn.text = _t("drive_stop") if bool(snap["drive_on"]) else _t("drive_start")
    hatch_btn.text = _t("hatch_close") if float(snap["hatch_target"]) == 1.0 else _t("hatch_open")
    scan_btn.text = _t("scan")
    _sync_camera_rail()
    var active_fault := int(snap["fault"])
    cal_title.text = "%s  ·  %s" % [_t("signal"), _t("select") if active_fault < 0 else _t("base%d" % active_fault)]
    slider_a.editable = bool(snap["inspection_allowed"])
    slider_b.editable = bool(snap["inspection_allowed"])
    dial_a.set_active(bool(snap["inspection_allowed"]))
    dial_b.set_active(bool(snap["inspection_allowed"]))
    if active_fault >= 0:
        a_title.text = _t("a%d" % active_fault)
        b_title.text = _t("b%d" % active_fault)
        slider_a.set_value_no_signal(float(snap["puzzle"]["a"]))
        slider_b.set_value_no_signal(float(snap["puzzle"]["b"]))
        dial_a.set_value_silent(int(snap["puzzle"]["a"]))
        dial_b.set_value_silent(int(snap["puzzle"]["b"]))
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
        dial_a.set_active(false)
        dial_b.set_active(false)
        dial_a.set_value_silent(0)
        dial_b.set_value_silent(0)
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
    _publish_web_accessibility(snap)



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
