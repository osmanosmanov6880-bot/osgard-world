extends Node3D
## OSGARD R136 procedural 3D source. All mechanics are simulated.
## No telemetry, actuation, credentials or server connections are used.

const DURATION: float = 20.0
var materials: Dictionary = {}
var detail_root: Node3D
var carriage: Node3D
var probe: Node3D
var service_door: Node3D
var jaw_left: Node3D
var jaw_right: Node3D
var fans: Array[Node3D] = []
var camera: Camera3D
var hud: Label
var post_layer: CanvasLayer
var scene_time: float = 0.0
var emergency_stopped: bool = false
var hero_enabled: bool = true
var orbit_yaw: float = -0.5
var orbit_pitch: float = 0.33
var orbit_distance: float = 11.8

func _ready() -> void:
    _setup_materials()
    _build_room()
    _build_service_cell()
    _build_motion_parts()
    _setup_lighting_and_camera()
    _setup_hud_and_post()
    _update_camera()
    set_detail(true)

func _material(color: Color, metal: float, rough: float, emissive: bool = false) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metal
    mat.roughness = rough
    if emissive:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = 1.5
    return mat

func _setup_materials() -> void:
    materials = {
        "floor": _material(Color(0.11, 0.15, 0.20), 0.40, 0.70),
        "steel": _material(Color(0.30, 0.37, 0.43), 0.84, 0.29),
        "black": _material(Color(0.055, 0.070, 0.085), 0.42, 0.37),
        "aluminium": _material(Color(0.68, 0.75, 0.81), 0.76, 0.22),
        "copper": _material(Color(0.70, 0.39, 0.20), 0.83, 0.27),
        "board": _material(Color(0.035, 0.24, 0.18), 0.10, 0.63),
        "chip": _material(Color(0.075, 0.095, 0.12), 0.17, 0.40),
        "optic": _material(Color(0.09, 0.54, 0.62), 0.13, 0.35),
        "cyan": _material(Color(0.15, 0.83, 0.89), 0.10, 0.28, true),
        "amber": _material(Color(0.98, 0.40, 0.14), 0.10, 0.34, true),
        "ceramic": _material(Color(0.82, 0.87, 0.87), 0.05, 0.55),
        "rubber": _material(Color(0.045, 0.055, 0.065), 0.0, 0.92),
    }

func _box(parent: Node3D, label: String, at: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    part.mesh = mesh
    part.position = at
    part.material_override = mat
    parent.add_child(part)
    return part

func _cylinder(parent: Node3D, label: String, at: Vector3, radius: float, height: float, mat: Material, segments: int = 16) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = label
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = segments
    part.mesh = mesh
    part.position = at
    part.material_override = mat
    parent.add_child(part)
    return part

func _build_room() -> void:
    _box(self, "ConcreteFoundation", Vector3(0, -0.18, 0), Vector3(14.5, 0.35, 11), materials["black"])
    _box(self, "RearWall", Vector3(0, 3.3, -5.35), Vector3(14.5, 6.6, 0.30), materials["floor"])
    for x in range(-7, 8):
        for z in range(-5, 6):
            _box(self, "ModularFloor_%d_%d" % [x, z], Vector3(float(x) * 0.92, 0.025, float(z) * 0.92),
                Vector3(0.895, 0.035, 0.895), materials["steel"] if (x + z) % 5 == 0 else materials["floor"])
    for i in range(10):
        var x: float = -6.2 + float(i) * 1.37
        _box(self, "CeilingLightRail_%02d" % i, Vector3(x, 5.9, -1.2), Vector3(0.09, 0.08, 7.0), materials["aluminium"])
        _box(self, "LightStrip_%02d" % i, Vector3(x, 5.85, -1.2), Vector3(0.065, 0.025, 6.7), materials["cyan"])
    for i in range(9):
        var x: float = -5.8 + float(i) * 1.45
        _box(self, "RearCableTray_%02d" % i, Vector3(x, 4.65, -4.96), Vector3(1.32, 0.15, 0.43), materials["steel"])
        _box(self, "CoolantHeader_%02d" % i, Vector3(x, 3.0, -4.98), Vector3(1.38, 0.12, 0.12), materials["copper"])
    for z in range(8):
        _box(self, "ServiceWalkwayMarker_%02d" % z, Vector3(5.25, 0.06, -3.55 + z * 1.02),
            Vector3(0.10, 0.010, 0.56), materials["amber"])

func _build_service_cell() -> void:
    var body := Node3D.new()
    body.name = "PrecisionServiceFrame"
    add_child(body)
    _box(body, "BasePlinth", Vector3(0, 0.43, 0), Vector3(6.65, 0.78, 3.85), materials["black"])
    for side in [-1, 1]:
        for z in [-1, 1]:
            _box(body, "StructuralPillar_%d_%d" % [side, z],
                Vector3(float(side) * 3.08, 2.15, float(z) * 1.63),
                Vector3(0.22, 3.55, 0.22), materials["aluminium"])
    _box(body, "UpperGantryBeam", Vector3(0, 3.89, 0), Vector3(6.43, 0.28, 0.42), materials["steel"])
    _box(body, "ServiceBackplane", Vector3(0, 2.17, -1.69), Vector3(5.83, 2.9, 0.18), materials["black"])
    for n in range(6):
        var x: float = -2.45 + float(n) * 0.98
        _box(body, "OpticalModule_%02d" % n, Vector3(x, 1.69, -1.50),
            Vector3(0.61, 0.39, 0.18), materials["board"])
        _box(body, "SignalBeacon_%02d" % n, Vector3(x, 1.95, -1.39),
            Vector3(0.31, 0.035, 0.025), materials["cyan"])
    detail_root = Node3D.new()
    detail_root.name = "HeroMicroDetails"
    body.add_child(detail_root)
    for slot in range(4):
        var z: float = -0.98 + float(slot) * 0.58
        _box(body, "TrayRailL_%02d" % slot, Vector3(-2.47, 1.09, z),
            Vector3(0.08, 0.13, 0.43), materials["aluminium"])
        _box(body, "TrayRailR_%02d" % slot, Vector3(2.47, 1.09, z),
            Vector3(0.08, 0.13, 0.43), materials["aluminium"])
        _box(body, "CircuitBoard_%02d" % slot, Vector3(0, 1.12, z),
            Vector3(4.6, 0.07, 0.43), materials["board"])
        for module in range(14):
            var x: float = -2.17 + float(module) * 0.33
            _box(detail_root, "SiliconController_%02d_%02d" % [slot, module],
                Vector3(x, 1.19, z), Vector3(0.18, 0.085, 0.20), materials["chip"])
            _box(detail_root, "HeatSink_%02d_%02d" % [slot, module],
                Vector3(x, 1.26, z), Vector3(0.16, 0.065, 0.14), materials["aluminium"])
    for row in range(16):
        var x: float = -2.80 + float(row) * 0.37
        for col in range(6):
            _box(detail_root, "ConnectorPin_%02d_%02d" % [row, col],
                Vector3(x, 2.40, -1.51 + float(col) * 0.07),
                Vector3(0.026, 0.13, 0.026), materials["copper"])
    for i in range(50):
        var x: float = -3.05 + float(i % 10) * 0.68
        var z: float = -1.57 + float(i / 10) * 0.70
        _cylinder(detail_root, "CaptiveFastener_%02d" % i,
            Vector3(x, 0.90, z), 0.033, 0.04, materials["steel"], 12)
    for n in range(12):
        var z: float = -1.45 + float(n) * 0.26
        _box(body, "HeatExchangerFin_%02d" % n, Vector3(3.13, 2.30, z),
            Vector3(0.11, 2.35, 0.045), materials["copper"])

func _build_motion_parts() -> void:
    carriage = Node3D.new()
    carriage.name = "ServiceCarriage"
    carriage.position = Vector3(-2.4, 3.60, 0)
    add_child(carriage)
    _box(carriage, "MotorizedTrolley", Vector3.ZERO, Vector3(0.67, 0.29, 0.58), materials["aluminium"])
    _box(carriage, "ServiceDiagnosticBeacon", Vector3(0, 0.16, 0),
        Vector3(0.29, 0.035, 0.31), materials["amber"])
    probe = Node3D.new()
    probe.name = "TelescopingInspectionHead"
    probe.position = Vector3(0, -0.28, 0)
    carriage.add_child(probe)
    _box(probe, "ActuatorShaft", Vector3(0, -0.26, 0),
        Vector3(0.13, 0.54, 0.13), materials["ceramic"])
    _box(probe, "OpticalCamera", Vector3(0, -0.54, 0),
        Vector3(0.33, 0.12, 0.25), materials["cyan"])
    jaw_left = Node3D.new()
    jaw_left.name = "GripperLeft"
    jaw_left.position = Vector3(-0.15, -0.65, 0)
    probe.add_child(jaw_left)
    _box(jaw_left, "LeftPrecisionJaw", Vector3.ZERO, Vector3(0.08, 0.20, 0.11), materials["steel"])
    jaw_right = Node3D.new()
    jaw_right.name = "GripperRight"
    jaw_right.position = Vector3(0.15, -0.65, 0)
    probe.add_child(jaw_right)
    _box(jaw_right, "RightPrecisionJaw", Vector3.ZERO, Vector3(0.08, 0.20, 0.11), materials["steel"])
    service_door = Node3D.new()
    service_door.name = "HingedSafetyDoor"
    service_door.position = Vector3(3.35, 1.95, 1.85)
    add_child(service_door)
    _box(service_door, "SafetyPanel", Vector3(-1.60, 0, 0),
        Vector3(3.2, 2.45, 0.075), materials["steel"])
    _box(service_door, "OpticalSafetyWindow", Vector3(-1.57, 0.20, 0.052),
        Vector3(2.43, 1.58, 0.029), materials["optic"])
    for i in range(4):
        var fan := Node3D.new()
        fan.name = "FanRotor_%02d" % i
        fan.position = Vector3(-2.75 + float(i) * 1.75, 2.85, -1.60)
        add_child(fan)
        for blade in range(8):
            var theta: float = TAU * float(blade) / 8.0
            var part: MeshInstance3D = _box(fan, "Blade_%02d" % blade,
                Vector3(cos(theta) * 0.21, sin(theta) * 0.21, 0),
                Vector3(0.25, 0.08, 0.045), materials["aluminium"])
            part.rotation.z = theta
        _cylinder(fan, "Hub", Vector3.ZERO, 0.095, 0.075, materials["black"], 16)
        fans.append(fan)

func _setup_lighting_and_camera() -> void:
    var world := WorldEnvironment.new()
    world.name = "FilmicEnvironment"
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color(0.025, 0.045, 0.075)
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)
    for i in range(4):
        var light := OmniLight3D.new()
        light.name = "InspectionLamp_%02d" % i
        light.position = Vector3(-4.5 + float(i) * 3.0, 4.7, 1.2)
        light.light_color = Color(0.70, 0.88, 1.0) if i % 3 != 0 else Color(1.0, 0.76, 0.52)
        light.light_energy = 0.82
        light.omni_range = 9.2
        add_child(light)
    camera = Camera3D.new()
    camera.name = "OrbitCamera"
    camera.fov = 53.0
    camera.near = 0.08
    camera.far = 90.0
    camera.current = true
    add_child(camera)

func _setup_hud_and_post() -> void:
    var overlay := CanvasLayer.new()
    overlay.name = "OperationalOverlay"
    add_child(overlay)
    hud = Label.new()
    hud.name = "StatusAndControls"
    hud.position = Vector2(20, 16)
    hud.size = Vector2(1100, 100)
    hud.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hud.add_theme_font_size_override("font_size", 15)
    overlay.add_child(hud)
    post_layer = CanvasLayer.new()
    post_layer.name = "FilmicVignette"
    post_layer.layer = 8
    add_child(post_layer)
    var film := ColorRect.new()
    film.name = "SinglePassVignette"
    film.mouse_filter = Control.MOUSE_FILTER_IGNORE
    film.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    film.color = Color.WHITE
    var mat := ShaderMaterial.new()
    mat.shader = load("res://shaders/filmic_vignette.gdshader")
    film.material = mat
    post_layer.add_child(film)

func _ease(start: float, finish: float, x: float) -> float:
    var u: float = clampf((x - start) / (finish - start), 0.0, 1.0)
    return u * u * (3.0 - 2.0 * u)

func _process(delta: float) -> void:
    if not emergency_stopped:
        scene_time = fmod(scene_time + delta, DURATION)
        var open_amount: float = _ease(0.5, 2.5, scene_time) * (1.0 - _ease(16.0, 18.5, scene_time))
        var travel: float = _ease(3.0, 6.0, scene_time) * (1.0 - _ease(12.5, 15.7, scene_time))
        var descent: float = _ease(6.3, 8.7, scene_time) * (1.0 - _ease(10.9, 13.0, scene_time))
        var grasp: float = _ease(8.8, 9.6, scene_time) * (1.0 - _ease(10.7, 11.4, scene_time))
        service_door.rotation.y = -1.1 * open_amount
        carriage.position.x = -2.4 + travel * 3.75
        probe.position.y = -0.28 - descent * 0.82
        jaw_left.position.x = -0.15 + grasp * 0.095
        jaw_right.position.x = 0.15 - grasp * 0.095
        for i in range(fans.size()):
            fans[i].rotation.z += delta * (3.0 + float(i) * 0.35)
    if hud != null:
        hud.text = "OSGARD R136  |  ПРЕЦИЗИОННАЯ ЯЧЕЙКА  |  ТОЛЬКО СИМУЛЯЦИЯ\n" + ("АВАРИЙНАЯ ОСТАНОВКА" if emergency_stopped else "ЦИКЛ %.1fс / 20с" % scene_time) + "  |  " + ("ДЕТАЛЬНО" if hero_enabled else "ЭКО") + "\nМышь/касание: обзор   Колесо/щипок: масштаб   H: детали   E: стоп   X: продолжить"

func _orbit_camera(delta: Vector2) -> void:
    orbit_yaw -= delta.x * 0.006
    orbit_pitch = clampf(orbit_pitch - delta.y * 0.006, -0.22, 1.10)
    _update_camera()

func _update_camera() -> void:
    if camera == null:
        return
    var target := Vector3(0, 1.8, 0)
    camera.position = target + Vector3(
        sin(orbit_yaw) * cos(orbit_pitch),
        sin(orbit_pitch),
        cos(orbit_yaw) * cos(orbit_pitch)) * orbit_distance
    camera.look_at(target, Vector3.UP)

func set_detail(hero: bool) -> void:
    hero_enabled = hero
    if detail_root != null:
        detail_root.visible = hero

func set_emergency_stop(engaged: bool) -> void:
    emergency_stopped = engaged

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
        _orbit_camera(event.relative)
    elif event is InputEventScreenDrag:
        _orbit_camera(event.relative)
    elif event is InputEventMagnifyGesture:
        orbit_distance = clampf(orbit_distance / maxf(event.factor, 0.1), 4.0, 25.0)
        _update_camera()
    if event is InputEventMouseButton and event.pressed:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP:
            orbit_distance = maxf(4.0, orbit_distance - 0.85)
            _update_camera()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
            orbit_distance = minf(25.0, orbit_distance + 0.85)
            _update_camera()
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_H:
            set_detail(not hero_enabled)
        elif event.keycode == KEY_E:
            set_emergency_stop(true)
        elif event.keycode == KEY_X:
            set_emergency_stop(false)
