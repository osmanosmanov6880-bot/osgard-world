extends Node3D
## R135 recovery bootstrap. Required assets are distributed separately in the reconstructed ZIP.
var controller: Node3D
var camera: Camera3D
var motion := true
var quality := 0
var yaw := 0.6
var pitch := 0.25
var distance := 18.0
var drag := false
var focus := Vector3(0, 1.9, 4.8)

func _ready() -> void:
    camera = $CinematicCamera
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.015, 0.025, 0.043)
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color(0.4, 0.53, 0.66)
    world.environment = env
    add_child(world)
    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-55, -30, 0)
    sun.light_energy = 1.4
    add_child(sun)
    controller = preload("res://R135ServiceDirector.gd").new()
    add_child(controller)
    controller.configure(camera, env)
    controller.set_quality(0)
    var layer := CanvasLayer.new()
    add_child(layer)
    var buttons := HBoxContainer.new()
    buttons.position = Vector2(16, 16)
    layer.add_child(buttons)
    _button(buttons, "ECO / HERO", _quality)
    _button(buttons, "PLAY / PAUSE", _motion)
    _button(buttons, "HATCH", _hatch)
    _camera_update()

func _button(parent: Control, label: String, fn: Callable) -> void:
    var b := Button.new()
    b.text = label
    b.pressed.connect(fn)
    parent.add_child(b)

func _quality() -> void:
    quality = 2 if quality == 0 else 0
    controller.set_quality(quality)

func _motion() -> void:
    motion = not motion
    controller.set_motion(motion)

func _hatch() -> void:
    controller.toggle_access_lid()

func _camera_update() -> void:
    pitch = clampf(pitch, -1.2, 1.2)
    distance = clampf(distance, 5.5, 38.0)
    camera.position = focus + Vector3(sin(yaw)*cos(pitch),sin(pitch),cos(yaw)*cos(pitch))*distance
    camera.look_at(focus, Vector3.UP)

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_LEFT:
            drag = event.pressed
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
            distance *= 0.9
        elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            distance *= 1.1
    elif event is InputEventMouseMotion and drag:
        yaw -= event.relative.x * 0.006
        pitch += event.relative.y * 0.006
    elif event is InputEventScreenDrag:
        yaw -= event.relative.x * 0.008
        pitch += event.relative.y * 0.008
    elif event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_Q: _quality()
        elif event.keycode == KEY_F: _hatch()
        elif event.keycode == KEY_SPACE: _motion()
    _camera_update()
