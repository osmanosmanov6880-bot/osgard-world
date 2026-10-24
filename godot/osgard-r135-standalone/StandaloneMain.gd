extends Node3D
## Independent R135 runtime. Does not depend on unavailable R131-R134 controllers.
var controller: Node3D
var camera: Camera3D
var orbit_yaw: float = 0.6
var orbit_pitch: float = 0.25
var distance: float = 18.0
var focus: Vector3 = Vector3(0, 1.9, 4.8)
var dragging: bool = false
var motion: bool = true
var quality: int = 0
var hud: Label
var touch_id: int = -1

func _ready() -> void:
    camera = $CinematicCamera
    var world := WorldEnvironment.new()
    var environment := Environment.new()
    environment.background_mode = Environment.BG_COLOR
    environment.background_color = Color(0.015, 0.025, 0.043)
    environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    environment.ambient_light_color = Color(0.40, 0.53, 0.66)
    environment.ambient_light_energy = 0.8
    world.environment = environment
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.4
    add_child(sun)
    controller = preload("res://R135ServiceDirector.gd").new()
    controller.name = "R135ServiceSpine"
    add_child(controller)
    controller.configure(camera, environment)
    # Low-memory mode first; user can opt into HERO on capable hardware.
    controller.set_quality(quality)
    var canvas := CanvasLayer.new()
    add_child(canvas)
    var panel := PanelContainer.new()
    panel.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
    panel.position = Vector2(18, 18)
    canvas.add_child(panel)
    var stack := VBoxContainer.new()
    panel.add_child(stack)
    hud = Label.new()
    stack.add_child(hud)
    var buttons := HBoxContainer.new()
    stack.add_child(buttons)
    _button(buttons, "ECO / HERO", _toggle_quality)
    _button(buttons, "PLAY / PAUSE", _toggle_motion)
    _button(buttons, "HATCH", _toggle_hatch)
    _button(buttons, "RESET VIEW", _reset_view)
    _update_view()
    _refresh_status()

func _button(parent: Control, caption: String, callback: Callable) -> void:
    var b := Button.new()
    b.text = caption
    b.pressed.connect(callback)
    parent.add_child(b)

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
    orbit_yaw = 0.6
    orbit_pitch = 0.25
    distance = 18.0
    _update_view()

func _refresh_status() -> void:
    var state: Dictionary = controller.summary()
    hud.text = "OSGARD R135 | SIMULATION ONLY | %s | %s\nDrag: orbit · Scroll: zoom · F: hatch · Space: pause · Q: quality" % ["HERO" if quality == 2 else "ECO", "RUNNING" if motion else "PAUSED"]
    if int(state["loading_failures"]) > 0:
        hud.text += "\nMODEL LOAD FAILED — check imported GLB files"

func _update_view() -> void:
    orbit_pitch = clampf(orbit_pitch, -1.20, 1.20)
    distance = clampf(distance, 5.5, 38.0)
    var direction := Vector3(sin(orbit_yaw) * cos(orbit_pitch), sin(orbit_pitch), cos(orbit_yaw) * cos(orbit_pitch))
    camera.position = focus + direction * distance
    camera.look_at(focus, Vector3.UP)

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
        touch_id = event.index if event.pressed else -1
    elif event is InputEventScreenDrag and event.index == touch_id:
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
    _update_view()
