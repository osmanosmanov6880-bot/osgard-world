extends Node3D
## Original R135 GLBs. Independent UI/camera responsive to real viewport aspect.
## No real telemetry. Both HERO and ECO originals remain available in Web.
var controller: Node3D
var camera: Camera3D
var studio: Node3D
var inspection_fill: OmniLight3D
var reduced_motion: bool = false
var last_layout_size: Vector2 = Vector2.ZERO
var orbit_yaw: float = 0.44
var orbit_pitch: float = 0.21
var distance: float = 12.8
var focus: Vector3 = Vector3(0.0, 1.85, 4.95)
var dragging: bool = false
var motion: bool = true
var quality: int = 0
var touch_id: int = -1
var touches: Dictionary = {}
var pinch_span: float = 0.0
var view_index: int = 0
var readout_clock: float = 0.0
var optical_tracking: bool = true
var camera_effective_distance: float = 0.0
const VIEW_NAMES = ["OVERVIEW", "SERVICE DECK", "OPTICAL HEAD", "SIDE INSPECTION"]
const R135Locale = preload("res://R135Locale.gd")
var ui_locale: String = "en"
var language_button: Button
var safety_notice: Label

var hud_panel: PanelContainer
var action_panel: PanelContainer
var heading: Label
var hud: Label
var helper: Label
var mission_label: Label
var grid: GridContainer
var action_buttons: Array[Button] = []

func _ready() -> void:
    camera = $CinematicCamera
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.014, 0.019, 0.025)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.68, 0.72, 0.77)
    environment.ambient_light_energy = 1.10
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -34, 0)
    sun.light_color = Color(1.0, 0.94, 0.87)
    sun.light_energy = 1.55
    add_child(sun)
    var rim := DirectionalLight3D.new()
    rim.rotation_degrees = Vector3(-32, 140, 0)
    rim.light_color = Color(0.62, 0.73, 0.81)
    rim.light_energy = 0.70
    add_child(rim)
    # W11 visual QA: metal-rich source GLBs were nearly black in ECO on
    # portrait SwiftShader. One camera-targeted, shadow-free fill makes
    # inspection legible without multiplying expensive shadow casters.
    inspection_fill = OmniLight3D.new()
    inspection_fill.name = "R135_ReadableInspectionFill_NoShadows"
    inspection_fill.light_color = Color(0.96, 0.95, 0.89)
    inspection_fill.light_energy = 3.8
    inspection_fill.omni_range = 12.5
    inspection_fill.omni_attenuation = 0.65
    inspection_fill.shadow_enabled = false
    add_child(inspection_fill)
    studio = preload("res://R135StudioEnvironment.gd").new()
    studio.name = "R135StudioEnvironment"
    add_child(studio)
    studio.call("configure")
    controller = preload("res://R135ServiceDirector.gd").new()
    controller.name = "R135ServiceSpine"
    add_child(controller)
    controller.configure(camera, environment)
    controller.set_quality(quality)
    studio.call("set_quality", quality)
    if OS.has_feature("web"):
        reduced_motion = bool(JavaScriptBridge.eval("Boolean(window.matchMedia && window.matchMedia('(prefers-reduced-motion: reduce)').matches)", true))
        ui_locale = "ru" if bool(JavaScriptBridge.eval("Boolean((navigator.language || '').toLowerCase().startsWith('ru'))", true)) else "en"
    controller.call("set_reduced_motion", reduced_motion)
    _build_hud()
    _set_locale(ui_locale)
    get_viewport().size_changed.connect(_update_layout)
    _update_layout()
    _update_view()
    _refresh_status()

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.038, 0.046, 0.056, 0.56)
    style.border_color = Color(0.38, 0.44, 0.47, 0.78)
    style.set_border_width_all(1)
    style.set_corner_radius_all(12)
    style.set_content_margin_all(16)
    return style

func _button_style(active: bool = false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.24, 0.14, 0.09, 0.95) if active else Color(0.09, 0.11, 0.13, 0.93)
    style.border_color = Color(0.78, 0.49, 0.32) if active else Color(0.34, 0.41, 0.44)
    style.set_border_width_all(1)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(10)
    return style

func _button(parent: GridContainer, text: String, action: Callable, prominent: bool) -> void:
    var b := Button.new()
    b.text = text
    # Avoid text forcing a >360px grid on narrow logical viewports.
    b.clip_text = true
    b.focus_mode = Control.FOCUS_ALL
    b.add_theme_color_override("font_color", Color(0.90, 0.96, 0.98))
    b.add_theme_color_override("font_hover_color", Color(1.0, 0.96, 0.86))
    b.add_theme_stylebox_override("normal", _button_style(prominent))
    b.add_theme_stylebox_override("hover", _button_style(true))
    b.add_theme_stylebox_override("pressed", _button_style(true))
    b.pressed.connect(action)
    parent.add_child(b)
    action_buttons.append(b)

func _build_hud() -> void:
    var overlay := CanvasLayer.new()
    overlay.name = "R135ResponsiveOperatorHUD"
    add_child(overlay)

    hud_panel = PanelContainer.new()
    hud_panel.name = "EngineeringStatus"
    hud_panel.add_theme_stylebox_override("panel", _panel_style())
    overlay.add_child(hud_panel)
    var text_stack := VBoxContainer.new()
    text_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    text_stack.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
    text_stack.add_theme_constant_override("separation", 6)
    hud_panel.add_child(text_stack)
    var header_bar := HBoxContainer.new()
    header_bar.add_theme_constant_override("separation", 8)
    text_stack.add_child(header_bar)
    heading = Label.new()
    heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    heading.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    heading.text = "OSGARD  /  SERVICE LAB"
    heading.add_theme_color_override("font_color", Color(0.93, 0.78, 0.62))
    header_bar.add_child(heading)
    language_button = Button.new()
    language_button.name = "SwitchLanguage"
    language_button.focus_mode = Control.FOCUS_ALL
    language_button.custom_minimum_size = Vector2(56, 40)
    language_button.add_theme_color_override("font_color", Color(0.95, 0.84, 0.69))
    language_button.add_theme_stylebox_override("normal", _button_style())
    language_button.add_theme_stylebox_override("hover", _button_style(true))
    language_button.pressed.connect(_toggle_locale)
    header_bar.add_child(language_button)
    hud = Label.new()
    hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud.add_theme_color_override("font_color", Color(0.86, 0.95, 0.97))
    text_stack.add_child(hud)
    mission_label = Label.new()
    mission_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    mission_label.name = "MissionStatus"
    mission_label.add_theme_color_override("font_color", Color(1.0, 0.71, 0.47))
    text_stack.add_child(mission_label)
    helper = Label.new()
    helper.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    helper.text = "M: TRAIN  C: DIAGNOSE  E: SCAN  V: CAMERA  ·  SIMULATION"
    helper.add_theme_color_override("font_color", Color(0.70, 0.76, 0.78))
    text_stack.add_child(helper)
    safety_notice = Label.new()
    safety_notice.name = "SimulationSafetyNotice"
    safety_notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    safety_notice.add_theme_color_override("font_color", Color(0.91, 0.75, 0.56))
    text_stack.add_child(safety_notice)

    action_panel = PanelContainer.new()
    action_panel.name = "OperatorControls"
    action_panel.add_theme_stylebox_override("panel", _panel_style())
    overlay.add_child(action_panel)
    grid = GridContainer.new()
    action_panel.add_child(grid)
    _button(grid, "START MISSION", _start_mission, true)
    _button(grid, "DIAGNOSTICS", _start_challenge, true)
    _button(grid, "NEXT VIEW", _next_view, false)
    _button(grid, "SCAN TARGET", _scan_component, false)
    _button(grid, "ECO / HERO", _toggle_quality, false)
    _button(grid, "PLAY / PAUSE", _toggle_motion, false)
    _button(grid, "OPEN HATCH", _toggle_hatch, false)
    _button(grid, "RESET VIEW", _reset_view, false)

func _viewport_is_portrait() -> bool:
    var size := get_viewport().get_visible_rect().size
    return size.y > size.x * 1.03

func _update_layout() -> void:
    if hud_panel == null:
        return
    var size := get_viewport().get_visible_rect().size
    var previous_layout_size: Vector2 = last_layout_size
    var first_layout: bool = previous_layout_size == Vector2.ZERO
    var did_resize: bool = not first_layout and size.distance_squared_to(previous_layout_size) > 1.0
    last_layout_size = size
    var portrait := _viewport_is_portrait()
    var margin := 24.0 if portrait else 18.0
    var compact := portrait and (size.y < 1150.0 or size.x < 500.0)
    var ui_scale := 0.73 if compact else 1.0
    var font_title := int(40 * ui_scale) if portrait else 25
    var font_state := int(27 * ui_scale) if portrait else 18
    var font_help := int(18 * ui_scale) if portrait else 12
    var font_mission := int(29 * ui_scale) if portrait else 17
    heading.add_theme_font_size_override("font_size", font_title)
    heading.text = "OSGARD / R135" if portrait else "OSGARD  /  SERVICE LAB"
    language_button.custom_minimum_size = Vector2(46, 35) if compact else Vector2(56, 40)
    safety_notice.add_theme_font_size_override("font_size", int(18 * ui_scale) if portrait else 13)
    hud.add_theme_font_size_override("font_size", font_state)
    helper.add_theme_font_size_override("font_size", font_help)
    mission_label.add_theme_font_size_override("font_size", font_mission)
    grid.columns = 2 if portrait else 4
    grid.add_theme_constant_override("h_separation", 12 if portrait else 9)
    grid.add_theme_constant_override("v_separation", 12 if portrait else 9)
    for b in action_buttons:
        b.add_theme_font_size_override("font_size", int(28 * ui_scale) if portrait else 17)
        b.custom_minimum_size = Vector2(0, (62 if compact else 82) if portrait else 43)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    var hud_width: float
    var control_width: float
    if portrait:
        hud_width = maxf(240.0, size.x - margin * 2.0)
        control_width = hud_width
    else:
        hud_width = minf(size.x * 0.48, 510.0)
        control_width = minf(size.x * 0.85, 990.0)
    # A CanvasLayer is not a full-rect Container. Its free-standing PanelContainer
    # keeps its previous computed size when the browser resizes unless explicitly
    # reset. Merely changing custom_minimum_size left W8's original 1033-pixel
    # panel visible inside a 360-pixel logical viewport.
    hud_panel.custom_minimum_size = Vector2(hud_width, 0.0)
    action_panel.custom_minimum_size = Vector2(control_width, 0.0)
    # First paint: preserve native PanelContainer sizing until Control layout settles.
    # Recalculate explicit width/height only on a real viewport transition.
    if first_layout or not did_resize:
        hud_panel.position = Vector2(margin, (32.0 if compact else 42.0) if portrait else margin)
        action_panel.position = Vector2(margin, maxf(0.0, size.y - (355.0 if compact else 455.0) if portrait else size.y - 150.0))
        _update_view()
        return
    hud_panel.reset_size()
    action_panel.reset_size()
    hud_panel.size = Vector2(hud_width, hud_panel.get_combined_minimum_size().y)
    action_panel.size = Vector2(control_width, action_panel.get_combined_minimum_size().y)
    hud_panel.position = Vector2(margin, (32.0 if compact else 42.0) if portrait else margin)
    action_panel.position = Vector2(
        margin,
        maxf(0.0, size.y - action_panel.size.y - margin)
    )
    _update_view()

func _set_locale(value: String) -> void:
    ui_locale = "ru" if value.to_lower() == "ru" else "en"
    if language_button == null:
        return
    language_button.text = "EN" if ui_locale == "ru" else "RU"
    language_button.tooltip_text = "Switch to English" if ui_locale == "ru" else "Переключить на русский"
    for i in range(action_buttons.size()):
        action_buttons[i].text = R135Locale.button_text(i, ui_locale)
    safety_notice.text = R135Locale.notice(ui_locale)
    if controller != null:
        var faults: Node3D = controller.get("visual_faults") as Node3D
        if faults != null:
            faults.call("set_locale", ui_locale)
    _refresh_status()

func _toggle_locale() -> void:
    _set_locale("en" if ui_locale == "ru" else "ru")

func _translated(message: String) -> String:
    return R135Locale.translate(message, ui_locale)

func _start_mission() -> void:
    # Keep the visible PLAY/PAUSE command synchronized with controller state.
    # Starting a new mission always starts its drive, even after a prior pause.
    motion = true
    controller.start_mission()
    _refresh_status()

func _start_challenge() -> void:
    motion = true
    controller.start_challenge()
    _apply_view(0)
    _refresh_status()

func _scan_component() -> void:
    controller.scan_diagnostic(view_index)
    _refresh_status()

func _next_view() -> void:
    _apply_view((view_index + 1) % VIEW_NAMES.size())

func _apply_view(index: int) -> void:
    view_index = index
    match view_index:
        0:
            focus = Vector3(0.0, 1.85, 4.95)
            distance = 12.8
            orbit_yaw = 0.44
            orbit_pitch = 0.21
        1:
            focus = Vector3(-4.55, 0.65, 5.92)
            distance = 5.7
            orbit_yaw = 0.83
            orbit_pitch = 0.39
        2:
            focus = Vector3(-2.5, 3.40, 5.25)
            distance = 6.3
            orbit_yaw = 0.57
            orbit_pitch = 0.16
        _:
            focus = Vector3(0.0, 1.65, 5.35)
            # Closer portrait viewpoint: the W12 AIRFLOW tag occupied only a
            # few real Chromium pixels at 12 world units.
            distance = 7.2 if _viewport_is_portrait() else 11.0
            orbit_yaw = 1.35
            orbit_pitch = 0.12
    _refresh_status()
    _update_view()

func _toggle_quality() -> void:
    quality = 0 if quality == 2 else 2
    controller.set_quality(quality)
    studio.call("set_quality", quality)
    inspection_fill.light_energy = 3.8 if quality == 0 else 4.2
    _refresh_status()

func _toggle_motion() -> void:
    controller.set_motion(not bool(controller.summary()["motion_enabled"]))
    # The advanced diagnostic interlock may reject an unsafe restart.
    motion = bool(controller.summary()["motion_enabled"])
    _refresh_status()

func _toggle_hatch() -> void:
    controller.toggle_access_lid()
    _refresh_status()

func _reset_view() -> void:
    _apply_view(0)

func _refresh_status() -> void:
    var state: Dictionary = controller.summary()
    var mode := "HERO" if quality == 2 else "ECO"
    var state_text := "RUNNING" if motion else "PAUSED"
    hud.text = "QUALITY  %s  |  DRIVE  %s  |  VIEW  %s" % [mode, state_text, VIEW_NAMES[view_index]]
    if bool(state["challenge_active"]) or bool(state["challenge_completed"]):
        mission_label.text = str(state["challenge_goal"]) + "\n" + str(state["challenge_feedback"])
        mission_label.text += "  |  %0.1f S" % float(state["challenge_elapsed"])
        helper.text = "SIM CLUE: %s  |  ERRORS %d  |  CASES %d/3" % [
            str(state["challenge_evidence"]), int(state["challenge_errors"]), int(state["cleared_case_count"])
        ]
        if bool(state["challenge_completed"]):
            mission_label.text += "\nLESSON: " + str(state["challenge_learning"])
            var active_case: int = int(state["challenge_fault_index"])
            var saved_scores: Array = state["case_best_scores"]
            var saved_attempts: Array = state["case_attempts"]
            helper.text = "SIM | CASE %d/3 | BEST %d/150 | RUNS %d" % [
                active_case + 1, int(saved_scores[active_case]), int(saved_attempts[active_case])
            ]
    else:
        mission_label.text = str(state["mission_goal"]) + "\n" + str(state["mission_feedback"])
        if bool(state["mission_active"]) or bool(state["mission_completed"]):
            mission_label.text += "  |  %0.1f S" % float(state["mission_elapsed"])
        helper.text = "M: TRAIN  C: DIAGNOSE  E: SCAN  V: CAMERA  |  SIM ONLY"
    if int(state["loading_failures"]) > 0:
        hud.text += "\nMODEL LOAD FAILED - CHECK GLB IMPORT"
    hud.text = _translated(hud.text)
    mission_label.text = _translated(mission_label.text)
    helper.text = _translated(helper.text)

func _update_view() -> void:
    if camera == null:
        return
    orbit_pitch = clampf(orbit_pitch, -1.2, 1.2)
    distance = clampf(distance, 4.5, 38.0)
    var size: Vector2 = get_viewport().get_visible_rect().size
    var portrait: bool = size.y > size.x * 1.03
    # W6: KEEP_WIDTH in portrait preserves horizontal composition while opening
    # the vertical field of view. W5's 2.75x portrait distance produced a tiny,
    # bottom-aligned inspection target with large unused empty sky.
    camera.keep_aspect = Camera3D.KEEP_WIDTH if portrait else Camera3D.KEEP_HEIGHT
    camera.fov = 57.0 if portrait else (53.0 if view_index == 2 else 55.0)
    var effective_distance: float = distance
    if portrait:
        match view_index:
            0:
                effective_distance = maxf(distance, 15.0)
            1:
                effective_distance = maxf(distance, 6.8)
            2:
                effective_distance = maxf(distance, 7.8)
            _:
                effective_distance = maxf(distance, 6.9)
    camera_effective_distance = effective_distance
    var target_focus: Vector3 = focus
    if view_index == 2 and optical_tracking and controller != null:
        # Aim at the actual animated optical head, not a guessed point or
        # 42%-interpolated carriage X. The head moves as the 16s cycle progresses.
        var optical_head: Node3D = controller.get("head") as Node3D
        if optical_head != null:
            # W6.2 screenshot QA: W6.1 head projected at 0.767 horizontal and
            # cut off its 3D label. Aim 1.15 units farther to the right and
            # 0.35 lower to recover label padding and usable machine area.
            var inspection_offset: Vector3 = Vector3(-1.0, -2.40, 0.12) if portrait else Vector3(-1.45, -0.18, 0.12)
            target_focus = optical_head.global_position + inspection_offset
    elif view_index == 1:
        target_focus = Vector3(-4.72, 0.38, 5.97)
    elif view_index == 3:
        target_focus = Vector3(1.54, 3.03, 4.78)
    var direction := Vector3(
        sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch),
        cos(orbit_yaw) * cos(orbit_pitch)
    )
    camera.position = target_focus + direction * effective_distance
    camera.look_at(target_focus, Vector3.UP)
    if inspection_fill != null:
        inspection_fill.global_position = target_focus + Vector3(0.0, 1.8, 3.8)

func _camera_target_readout() -> Dictionary:
    var size: Vector2 = get_viewport().get_visible_rect().size
    var frame: Dictionary = {
        "camera_keep_width": camera.keep_aspect == Camera3D.KEEP_WIDTH,
        "camera_fov": camera.fov,
        "camera_effective_distance": camera_effective_distance,
        "camera_target_visible": false,
        "camera_target_screen_x": -1.0,
        "camera_target_screen_y": -1.0,
        "machine_top_screen_y": -1.0
    }
    if view_index == 2 and controller != null:
        var rail_screen: Vector2 = camera.unproject_position(Vector3(0.0, 3.78, 5.37))
        frame["machine_top_screen_y"] = rail_screen.y / maxf(size.y, 1.0)
        var optical_head: Node3D = controller.get("head") as Node3D
        if optical_head != null and not camera.is_position_behind(optical_head.global_position):
            var point: Vector2 = camera.unproject_position(optical_head.global_position)
            frame["camera_target_screen_x"] = point.x / maxf(size.x, 1.0)
            frame["camera_target_screen_y"] = point.y / maxf(size.y, 1.0)
            frame["camera_target_visible"] = true
    return frame

func _process(delta: float) -> void:
    readout_clock += delta
    if readout_clock < 0.18:
        return
    readout_clock = 0.0
    # Browser viewport changes (especially Playwright Pixel DPR) can change the
    # engine's visible rect without emitting a reliable root size_changed signal.
    if get_viewport().get_visible_rect().size.distance_squared_to(last_layout_size) > 1.0:
        _update_layout()
    _refresh_status()
    if view_index == 2 and optical_tracking:
        _update_view()
    # Read-only browser QA telemetry: simulated state, no credentials,
    # remote control, network calls, or hardware integrations.
    if OS.has_feature("web"):
        var state: Dictionary = controller.summary()
        state["view"] = view_index
        state["scene_ready"] = true
        state["orbit_yaw"] = orbit_yaw
        state["orbit_pitch"] = orbit_pitch
        state["distance"] = distance
        state["camera_effective_distance"] = camera_effective_distance
        state["optical_tracking"] = optical_tracking
        state.merge(_camera_target_readout(), true)
        var area: Vector2 = get_viewport().get_visible_rect().size
        state["viewport_w"] = area.x
        state["viewport_h"] = area.y
        var stage_budget: Dictionary = studio.call("render_budget")
        state["studio_grid_draw_batches"] = int(stage_budget["grid_draw_batches"])
        state["studio_grid_instances"] = int(stage_budget["grid_instances"])
        state["studio_mesh_nodes"] = int(stage_budget["single_mesh_nodes"])
        state["studio_quality"] = int(stage_budget["stage_quality"])
        state["prefers_reduced_motion"] = reduced_motion
        state["ui_locale"] = ui_locale
        state["language_control_visible"] = language_button.visible
        var switch_center: Vector2 = language_button.get_global_rect().get_center()
        state["language_control_center"] = {"x": switch_center.x, "y": switch_center.y}
        state["studio_detail_draw_batches"] = int(stage_budget["detail_draw_batches"])
        state["studio_detail_instances"] = int(stage_budget["detail_instances"])
        state["render_fps_sample"] = Engine.get_frames_per_second()
        state["inspection_fill_energy"] = inspection_fill.light_energy
        state["inspection_fill_shadow_enabled"] = inspection_fill.shadow_enabled
        state["inspection_fill_range"] = inspection_fill.omni_range
        # W12: visibility is not just the Label3D.visible flag. Project the
        # actual world-space tag into the active camera and ensure the player
        # could see it inside the useful part of the viewport. Read-only QA.
        state["active_fault_caption_on_screen"] = false
        state["active_fault_caption_screen_x"] = -1.0
        state["active_fault_caption_screen_y"] = -1.0
        state["active_fault_caption_height_px_estimate"] = 0.0
        var fault_scene: Node3D = controller.get("visual_faults") as Node3D
        if fault_scene != null:
            var fault_labels: Array = fault_scene.get("marker_labels")
            var active_marker: int = int(state.get("fault_marker_active_index", -1))
            if active_marker >= 0 and active_marker < fault_labels.size():
                var active_label: Label3D = fault_labels[active_marker] as Label3D
                if active_label != null and active_label.visible and not camera.is_position_behind(active_label.global_position):
                    var label_pixel: Vector2 = camera.unproject_position(active_label.global_position)
                    var label_frame: Vector2 = get_viewport().get_visible_rect().size
                    var label_x: float = label_pixel.x / maxf(label_frame.x, 1.0)
                    var label_y: float = label_pixel.y / maxf(label_frame.y, 1.0)
                    state["active_fault_caption_screen_x"] = label_x
                    state["active_fault_caption_screen_y"] = label_y
                    var glyph_height_world: float = maxf(
                        float(active_label.font_size) * active_label.pixel_size, 0.001
                    )
                    var label_top_screen: Vector2 = camera.unproject_position(
                        active_label.global_position + Vector3(0.0, glyph_height_world, 0.0)
                    )
                    state["active_fault_caption_height_px_estimate"] = absf(label_top_screen.y - label_pixel.y)
                    state["active_fault_caption_on_screen"] = (
                        label_x >= 0.10 and label_x <= 0.90
                        and label_y >= 0.10 and label_y <= 0.85
                    )
        var status_rect: Rect2 = hud_panel.get_global_rect()
        var control_rect: Rect2 = action_panel.get_global_rect()
        state["hud_layout_mode"] = "portrait" if _viewport_is_portrait() else "landscape"
        state["hud_rect"] = {
            "x": status_rect.position.x, "y": status_rect.position.y,
            "w": status_rect.size.x, "h": status_rect.size.y
        }
        state["action_rect"] = {
            "x": control_rect.position.x, "y": control_rect.position.y,
            "w": control_rect.size.x, "h": control_rect.size.y
        }
        var button_centers: Array[Dictionary] = []
        for button in action_buttons:
            var box: Rect2 = button.get_global_rect()
            var center: Vector2 = box.get_center()
            button_centers.append({"x":center.x, "y":center.y})
        state["button_centers"] = button_centers
        JavaScriptBridge.eval("window.__OSGARD_R135_QA = " + JSON.stringify(state) + ";", true)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            dragging = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance *= 0.9
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance *= 1.1
    elif event is InputEventMouseMotion and dragging:
        orbit_yaw -= event.relative.x * 0.006
        orbit_pitch += event.relative.y * 0.006
    elif event is InputEventScreenTouch:
        if event.pressed:
            touches[event.index] = event.position
            touch_id = event.index
        else:
            touches.erase(event.index)
            if touch_id == event.index:
                touch_id = -1
        pinch_span = 0.0
    elif event is InputEventScreenDrag:
        if touches.has(event.index):
            touches[event.index] = event.position
        if touches.size() == 2:
            var positions: Array = touches.values()
            var p0: Vector2 = positions[0]
            var p1: Vector2 = positions[1]
            var current_span: float = p0.distance_to(p1)
            if pinch_span > 1.0:
                distance = clampf(distance * pinch_span / maxf(current_span, 1.0), 4.5, 38.0)
            pinch_span = current_span
        elif event.index == touch_id:
            orbit_yaw -= event.relative.x * 0.008
            orbit_pitch += event.relative.y * 0.008
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_F:
            _toggle_hatch()
        elif event.keycode == KEY_SPACE:
            _toggle_motion()
        elif event.keycode == KEY_Q:
            _toggle_quality()
        elif event.keycode == KEY_R:
            _reset_view()
        elif event.keycode == KEY_M:
            _start_mission()
        elif event.keycode == KEY_V:
            _next_view()
        elif event.keycode == KEY_C:
            _start_challenge()
        elif event.keycode == KEY_E:
            _scan_component()
        elif event.keycode == KEY_L:
            _toggle_locale()
    _update_view()
