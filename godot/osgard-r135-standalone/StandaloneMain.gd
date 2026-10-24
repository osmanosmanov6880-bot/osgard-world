extends Node3D
## Original R135 GLBs. Independent UI/camera responsive to real viewport aspect.
## No real telemetry. Both HERO and ECO originals remain available in Web.
var controller: Node3D
var camera: Camera3D
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
const VIEW_NAMES = ["OVERVIEW", "SERVICE DECK", "OPTICAL HEAD", "SIDE INSPECTION"]

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
    environment.background_color = Color(0.006, 0.012, 0.022)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.42, 0.58, 0.72)
    environment.ambient_light_energy = 0.85
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-48, -34, 0)
    sun.light_energy = 1.45
    add_child(sun)
    var rim := DirectionalLight3D.new()
    rim.rotation_degrees = Vector3(-32, 140, 0)
    rim.light_color = Color(0.28, 0.69, 0.96)
    rim.light_energy = 0.55
    add_child(rim)
    _build_floor()
    controller = preload("res://R135ServiceDirector.gd").new()
    controller.name = "R135ServiceSpine"
    add_child(controller)
    controller.configure(camera, environment)
    controller.set_quality(quality)
    _build_hud()
    get_viewport().size_changed.connect(_update_layout)
    _update_layout()
    _update_view()
    _refresh_status()

func _floor_material(color: Color, emission: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.58
    mat.roughness = 0.43
    if emission:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.3
    return mat

func _floor_box(name: String, pos: Vector3, size: Vector3, mat: Material) -> void:
    var node := MeshInstance3D.new()
    node.name = name
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = pos
    node.material_override = mat
    add_child(node)

func _build_floor() -> void:
    # A bounded service platform gives depth cues without additional GLBs.
    var surface := _floor_material(Color(0.023, 0.040, 0.061))
    var inlay := _floor_material(Color(0.035, 0.14, 0.18), true)
    _floor_box("LowReflectionIndustrialStage", Vector3(0, -0.20, 4.90), Vector3(22, 0.29, 14), surface)
    for x in range(-10, 11, 2):
        _floor_box("StageGridX_%02d" % (x + 10), Vector3(float(x), -0.044, 4.9), Vector3(0.018, 0.009, 13), inlay)
    for z in range(-1, 13, 2):
        _floor_box("StageGridZ_%02d" % (z + 1), Vector3(0, -0.044, float(z)), Vector3(20.5, 0.009, 0.018), inlay)
    var orange := _floor_material(Color(0.62, 0.23, 0.10), true)
    _floor_box("ServiceBoundaryFront", Vector3(0, -0.029, 11.6), Vector3(21, 0.013, 0.055), orange)
    _floor_box("ServiceBoundaryRear", Vector3(0, -0.029, -1.75), Vector3(21, 0.013, 0.055), orange)

func _panel_style() -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.019, 0.038, 0.058, 0.93)
    style.border_color = Color(0.28, 0.58, 0.68, 0.75)
    style.set_border_width_all(2)
    style.set_corner_radius_all(13)
    style.set_content_margin_all(16)
    return style

func _button_style(active: bool = false) -> StyleBoxFlat:
    var style := StyleBoxFlat.new()
    style.bg_color = Color(0.20, 0.080, 0.046, 0.96) if active else Color(0.045, 0.089, 0.13, 0.95)
    style.border_color = Color(1.0, 0.59, 0.32) if active else Color(0.31, 0.70, 0.77)
    style.set_border_width_all(2)
    style.set_corner_radius_all(8)
    style.set_content_margin_all(10)
    return style

func _button(parent: GridContainer, text: String, action: Callable, prominent: bool) -> void:
    var b := Button.new()
    b.text = text
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
    text_stack.add_theme_constant_override("separation", 6)
    hud_panel.add_child(text_stack)
    heading = Label.new()
    heading.text = "OSGARD   /   R135"
    heading.add_theme_color_override("font_color", Color(1.0, 0.68, 0.43))
    text_stack.add_child(heading)
    hud = Label.new()
    hud.add_theme_color_override("font_color", Color(0.86, 0.95, 0.97))
    text_stack.add_child(hud)
    mission_label = Label.new()
    mission_label.name = "MissionStatus"
    mission_label.add_theme_color_override("font_color", Color(1.0, 0.71, 0.47))
    text_stack.add_child(mission_label)
    helper = Label.new()
    helper.text = "DRAG / PINCH TO INSPECT  ·  M: MISSION  ·  V: VIEW  ·  SIM ONLY"
    helper.add_theme_color_override("font_color", Color(0.53, 0.79, 0.84))
    text_stack.add_child(helper)

    action_panel = PanelContainer.new()
    action_panel.name = "OperatorControls"
    action_panel.add_theme_stylebox_override("panel", _panel_style())
    overlay.add_child(action_panel)
    grid = GridContainer.new()
    action_panel.add_child(grid)
    _button(grid, "START MISSION", _start_mission, true)
    _button(grid, "NEXT VIEW", _next_view, false)
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
    var portrait := _viewport_is_portrait()
    var margin := 24.0 if portrait else 18.0
    var font_title := 43 if portrait else 25
    var font_state := 29 if portrait else 18
    var font_help := 19 if portrait else 12
    var font_mission := 31 if portrait else 17
    heading.add_theme_font_size_override("font_size", font_title)
    hud.add_theme_font_size_override("font_size", font_state)
    helper.add_theme_font_size_override("font_size", font_help)
    mission_label.add_theme_font_size_override("font_size", font_mission)
    grid.columns = 2 if portrait else 3
    grid.add_theme_constant_override("h_separation", 12 if portrait else 9)
    grid.add_theme_constant_override("v_separation", 12 if portrait else 9)
    for b in action_buttons:
        b.add_theme_font_size_override("font_size", 37 if portrait else 17)
        b.custom_minimum_size = Vector2(0, 84 if portrait else 42)
        b.size_flags_horizontal = Control.SIZE_EXPAND_FILL

    if portrait:
        hud_panel.position = Vector2(margin, 42)
        hud_panel.custom_minimum_size = Vector2(size.x - margin * 2, 0)
        action_panel.custom_minimum_size = Vector2(size.x - margin * 2, 0)
        action_panel.position = Vector2(margin, maxf(0, size.y - 384))
    else:
        hud_panel.position = Vector2(margin, margin)
        hud_panel.custom_minimum_size = Vector2(minf(size.x * 0.48, 510), 0)
        action_panel.custom_minimum_size = Vector2(minf(size.x * 0.70, 780), 0)
        action_panel.position = Vector2(margin, maxf(0, size.y - 145))
    _update_view()

func _start_mission() -> void:
    controller.start_mission()
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
            distance = 12.0
            orbit_yaw = 1.35
            orbit_pitch = 0.12
    _refresh_status()
    _update_view()

func _toggle_quality() -> void:
    quality = 0 if quality == 2 else 2
    controller.set_quality(quality)
    _refresh_status()

func _toggle_motion() -> void:
    motion = not motion
    controller.set_motion(motion)
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
    var feedback: String = str(state["mission_feedback"])
    mission_label.text = str(state["mission_goal"]) + "\n" + feedback
    if bool(state["mission_active"]):
        mission_label.text += "  |  %0.1f S" % float(state["mission_elapsed"])
    elif bool(state["mission_completed"]):
        mission_label.text += "  |  %0.1f S" % float(state["mission_elapsed"])
    if int(state["loading_failures"]) > 0:
        hud.text += "\nMODEL LOAD FAILED - CHECK GLB IMPORT"

func _update_view() -> void:
    if camera == null:
        return
    orbit_pitch = clampf(orbit_pitch, -1.2, 1.2)
    distance = clampf(distance, 5.5, 38.0)
    var size := get_viewport().get_visible_rect().size
    var ratio: float = size.x / maxf(size.y, 1.0)
    # Godot FOV is vertical. Widen the orbit distance on portrait screens
    # instead of cutting the original full-width service-spine geometry.
    var width_goal: float = 1.27 if view_index == 0 else 0.90
    var aspect_compensation: float = maxf(1.0, width_goal / maxf(ratio, 0.42))
    var effective_distance: float = distance * aspect_compensation
    var direction := Vector3(
        sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch),
        cos(orbit_yaw) * cos(orbit_pitch)
    )
    camera.position = focus + direction * effective_distance
    camera.look_at(focus, Vector3.UP)

func _process(delta: float) -> void:
    readout_clock += delta
    if readout_clock < 0.18:
        return
    readout_clock = 0.0
    _refresh_status()
    # Read-only browser QA telemetry: simulated state, no credentials,
    # remote control, network calls, or hardware integrations.
    if OS.has_feature("web"):
        var state: Dictionary = controller.summary()
        state["view"] = view_index
        state["scene_ready"] = true
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
    _update_view()
