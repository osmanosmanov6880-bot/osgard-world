extends Node3D
class_name A7CinematicStage
## W64 ORIGINAL procedural 3D staging for the A7 CASCADE game.
## All colors, movement and signals are visualizations of FICTIONAL game values.
## No physical-machine connection; no external imagery and no runtime downloads.

const DARK := Color("0a1019")
const FLOOR := Color("151e28")
const GRAPHITE := Color("29323c")
const STEEL := Color("596777")
const COPPER := Color("c6a77d")
const COOL := Color("55c5d2")
const GOOD := Color("79d2c0")
const HOT := Color("ee725b")
const ALERT := Color("ee4f53")
const AMBER := Color("efb970")

var rotor: Node3D
var sensor_array: Node3D
var containment_door: MeshInstance3D
var energy_gauge: MeshInstance3D
var seal_gauge: MeshInstance3D
var signal_gauge: MeshInstance3D
var warning_beacons: Array[MeshInstance3D] = []
var coolant_tubes: Array[MeshInstance3D] = []
var heat_material: StandardMaterial3D
var warning_material: StandardMaterial3D
var coolant_material: StandardMaterial3D
var seal_material: StandardMaterial3D
var signal_material: StandardMaterial3D
var energy_material: StandardMaterial3D
var key_light: OmniLight3D
var warning_light: OmniLight3D
var fill_light: OmniLight3D
var hero_details: Node3D
var camera: Camera3D
var camera_index: int = 0
var mode: String = "hero"
var reduced_motion: bool = false
var heat: float = 0.62
var pressure: float = 0.48
var energy: float = 0.85
var severity: float = 0.0
var pulse: float = 0.0
var phase: float = 0.0
var current_status: String = "playing"
var recent_action: String = ""
var mesh_count: int = 0
var light_count: int = 0
var snapshot_count: int = 0

func _ready() -> void:
    name = "A7TrueNativeProceduralCinema"
    _construct_facility()
    set_camera(0)
    set_quality(mode)
    set_process(true)

func _material(tone: Color, metal: float = 0.15, glow: float = 0.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tone
    m.metallic = metal
    m.roughness = 0.39 if metal > 0.5 else 0.73
    if glow > 0.0:
        m.emission_enabled = true
        m.emission = tone
        m.emission_energy_multiplier = glow
    return m

func _box(parent: Node3D, id: String, dimension: Vector3, at: Vector3, finish: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dimension
    var obj := MeshInstance3D.new()
    obj.name = id
    obj.mesh = mesh
    obj.material_override = finish
    obj.position = at
    parent.add_child(obj)
    mesh_count += 1
    return obj

func _cylinder(parent: Node3D, id: String, r: float, h: float, at: Vector3, finish: Material) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = r
    mesh.bottom_radius = r
    mesh.height = h
    mesh.radial_segments = 20
    var obj := MeshInstance3D.new()
    obj.name = id
    obj.mesh = mesh
    obj.material_override = finish
    obj.position = at
    parent.add_child(obj)
    mesh_count += 1
    return obj

func _sphere(parent: Node3D, id: String, r: float, at: Vector3, finish: Material) -> MeshInstance3D:
    var mesh := SphereMesh.new()
    mesh.radius = r
    mesh.height = r * 2.0
    mesh.radial_segments = 16
    mesh.rings = 8
    var obj := MeshInstance3D.new()
    obj.name = id
    obj.mesh = mesh
    obj.material_override = finish
    obj.position = at
    parent.add_child(obj)
    mesh_count += 1
    return obj

func _light(id: String, at: Vector3, tint: Color, power: float, radius: float) -> OmniLight3D:
    var lamp := OmniLight3D.new()
    lamp.name = id
    lamp.position = at
    lamp.light_color = tint
    lamp.light_energy = power
    lamp.omni_range = radius
    lamp.shadow_enabled = false
    add_child(lamp)
    light_count += 1
    return lamp

func _construct_facility() -> void:
    var environment := WorldEnvironment.new()
    environment.name = "A7ActualSceneEnvironment"
    var settings := Environment.new()
    settings.background_mode = Environment.BG_COLOR
    settings.background_color = DARK
    settings.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    settings.ambient_light_color = Color("344455")
    settings.ambient_light_energy = 0.42
    environment.environment = settings
    add_child(environment)

    var asphalt := _material(FLOOR, 0.52)
    var structure := _material(GRAPHITE, 0.68)
    var metal := _material(STEEL, 0.76)
    var precious := _material(COPPER, 0.75)
    var shadow := _material(Color("101822"), 0.47)
    heat_material = _material(COOL, 0.45, 1.4)
    warning_material = _material(AMBER, 0.2, 1.0)
    coolant_material = _material(COOL, 0.28, 1.7)
    seal_material = _material(GOOD, 0.35, 1.5)
    signal_material = _material(GOOD, 0.18, 1.4)
    energy_material = _material(AMBER, 0.18, 1.6)

    _box(self, "EngineRoomFloor", Vector3(14.0, 0.26, 10.0), Vector3(0, -0.25, 0), asphalt)
    _box(self, "FarWall", Vector3(14.0, 6.5, 0.24), Vector3(0, 3.0, -4.8), shadow)
    _box(self, "LeftBulkhead", Vector3(0.25, 6.5, 10), Vector3(-7.0, 3, 0), structure)
    _box(self, "RightBulkhead", Vector3(0.25, 6.5, 10), Vector3(7.0, 3, 0), structure)
    _box(self, "UpperServiceBeam", Vector3(13.6, 0.34, 0.5), Vector3(0, 5.6, -4.5), precious)

    for i in range(9):
        var x: float = -6.0 + float(i) * 1.5
        _box(self, "FloorDirectionLine%02d" % i, Vector3(0.04, 0.015, 6.8),
            Vector3(x, -0.106, 0.4), precious if i % 3 == 0 else structure)
    for i in range(4):
        var x: float = -5.8 + float(i) * 3.9
        _box(self, "BulkheadRib%02d" % i, Vector3(0.35, 6.0, 0.38), Vector3(x, 2.9, -4.42), metal)
        _box(self, "CeilingSplice%02d" % i, Vector3(0.17, 0.11, 7.8),
            Vector3(x, 5.8, -0.65), precious)

    _cylinder(self, "ReactorPlinth", 2.2, 0.68, Vector3(0, 0.24, -0.25), metal)
    _cylinder(self, "ReactorLowerRing", 1.74, 0.19, Vector3(0, 0.68, -0.25), precious)
    _cylinder(self, "ReactorPressureHousing", 1.38, 3.15, Vector3(0, 2.25, -0.25), structure)
    _cylinder(self, "CoreGlassInnerTube", 0.88, 2.7, Vector3(0, 2.31, -0.25), heat_material)
    _cylinder(self, "ReactorUpperRing", 1.73, 0.24, Vector3(0, 3.94, -0.25), precious)
    _cylinder(self, "ReactorCrown", 1.27, 0.45, Vector3(0, 4.22, -0.25), metal)
    _sphere(self, "A7EnergyLighthouse", 0.40, Vector3(0, 4.60, -0.25), energy_material)

    rotor = Node3D.new()
    rotor.name = "VisibleEnergyRotor"
    rotor.position = Vector3(0, 2.22, -0.25)
    add_child(rotor)
    _cylinder(rotor, "RotorCore", 0.48, 1.72, Vector3.ZERO, precious)
    for i in range(8):
        var a: float = TAU * float(i) / 8.0
        var fin := _box(rotor, "RotorBlade%02d" % i, Vector3(0.16, 1.72, 0.75),
            Vector3(sin(a) * 0.42, 0.0, cos(a) * 0.42), metal)
        fin.rotation.y = a

    hero_details = Node3D.new()
    hero_details.name = "HighDetailHeroGeometry"
    add_child(hero_details)
    for ring in range(3):
        var height: float = 1.25 + float(ring) * 1.08
        for side in range(12):
            var a: float = TAU * float(side) / 12.0
            var rail := _box(hero_details, "ContainmentRail%d_%02d" % [ring, side],
                Vector3(0.22, 0.07, 0.37),
                Vector3(sin(a) * 1.78, height, cos(a) * 1.78 - 0.25), precious)
            rail.rotation.y = a

    var service_console := Node3D.new()
    service_console.name = "ResponsiveServiceHardware"
    add_child(service_console)
    _box(service_console, "LeftPumpCabinet", Vector3(1.75, 2.00, 1.30),
        Vector3(-4.22, 1.14, -0.85), metal)
    _box(service_console, "LeftPumpFace", Vector3(1.50, 1.55, 0.06),
        Vector3(-4.22, 1.20, -0.13), structure)
    for i in range(4):
        var tube := _cylinder(service_console, "CoolantConduit%d" % i, 0.09, 1.70,
            Vector3(-5.12 + 0.55 * float(i), 1.24, 0.17), coolant_material)
        tube.rotation.z = deg_to_rad(90.0)
        coolant_tubes.append(tube)

    _box(service_console, "PressureDesk", Vector3(1.90, 1.95, 1.25),
        Vector3(4.28, 1.10, -1.0), metal)
    _box(service_console, "PressureConsoleFace", Vector3(1.60, 1.50, 0.07),
        Vector3(4.28, 1.18, -0.30), structure)
    energy_gauge = _box(service_console, "PhysicalPowerGauge",
        Vector3(0.31, 1.05, 0.12), Vector3(3.85, 1.27, -0.20), energy_material)
    signal_gauge = _box(service_console, "PhysicalSignalGauge",
        Vector3(0.31, 1.05, 0.12), Vector3(4.30, 1.27, -0.20), signal_material)
    seal_gauge = _box(service_console, "PhysicalSealGauge",
        Vector3(0.31, 1.05, 0.12), Vector3(4.75, 1.27, -0.20), seal_material)

    containment_door = _box(self, "RearContainmentDoor",
        Vector3(2.45, 3.50, 0.18), Vector3(0, 1.66, -4.32), structure)
    _box(self, "DoorBorderLeft", Vector3(0.12, 3.8, 0.20),
        Vector3(-1.38, 1.74, -4.19), precious)
    _box(self, "DoorBorderRight", Vector3(0.12, 3.8, 0.20),
        Vector3(1.38, 1.74, -4.19), precious)

    sensor_array = Node3D.new()
    sensor_array.name = "MovingDiagnosticScanner"
    sensor_array.position = Vector3(0, 3.36, -0.25)
    add_child(sensor_array)
    for i in range(3):
        var a: float = TAU * float(i) / 3.0
        var optic := _box(sensor_array, "ScanOptic%d" % i, Vector3(0.24, 0.13, 0.40),
            Vector3(sin(a) * 1.15, 0, cos(a) * 1.15), signal_material)
        optic.rotation.y = a

    for i in range(4):
        var x: float = -5.7 + float(i % 2) * 11.4
        var z: float = -2.80 + float(i / 2) * 4.9
        var beacon := _sphere(self, "TrueAlertBeacon%d" % i, 0.22,
            Vector3(x, 4.72, z), warning_material)
        warning_beacons.append(beacon)

    key_light = _light("A7CopperKeyLight", Vector3(0, 5, 4.4), Color("f9dfaf"), 1.35, 11.5)
    fill_light = _light("A7TealFillLight", Vector3(-5.8, 3.5, -1.0), COOL, 0.88, 8.5)
    warning_light = _light("A7SafetyVisualLight", Vector3(5.1, 4.0, 1.1), AMBER, 0.35, 8.0)

    camera = Camera3D.new()
    camera.name = "RealGodotHeroCamera"
    camera.fov = 55
    camera.near = 0.1
    camera.far = 70.0
    add_child(camera)

func set_camera(index: int) -> void:
    camera_index = clampi(index, 0, 2)
    if camera == null:
        return
    var spots := [Vector3(8.0, 5.6, 11.5),
        Vector3(0, 5.0, 13.0),
        Vector3(-8.1, 4.1, 9.3)]
    camera.position = spots[camera_index]
    camera.look_at(Vector3(0.0, 2.0, -0.6), Vector3.UP)
    camera.current = true

func set_quality(new_mode: String) -> void:
    mode = "eco" if new_mode == "eco" else "hero"
    if hero_details == null:
        return
    hero_details.visible = mode == "hero"
    if key_light != null:
        key_light.light_energy = 1.35 if mode == "hero" else 0.90
        fill_light.visible = mode == "hero"

func set_reduced_motion(enabled: bool) -> void:
    reduced_motion = enabled

func trigger_action(action: String) -> void:
    if not ["PUMP", "VENT", "SEAL", "SCAN", "POWER"].has(action):
        return
    recent_action = action
    pulse = 1.0

func apply_snapshot(state: Dictionary) -> void:
    if heat_material == null:
        return
    var stats: Dictionary = state.get("metrics", {})
    heat = clampf(float(stats.get("heat", 62)) / 100.0, 0.0, 1.0)
    pressure = clampf(float(stats.get("pressure", 48)) / 100.0, 0.0, 1.0)
    energy = clampf(float(stats.get("energy", 85)) / 100.0, 0.0, 1.0)
    var seal: float = clampf(float(stats.get("seal", 68)) / 100.0, 0.0, 1.0)
    var signal_strength: float = clampf(float(stats.get("signal", 44)) / 100.0, 0.0, 1.0)
    var integrity: float = clampf(float(stats.get("integrity", 100)) / 100.0, 0.0, 1.0)
    current_status = str(state.get("status", "playing"))
    severity = clampf(maxf(heat - 0.70, pressure - 0.70) * 3.0 + (1.0 - integrity) * 0.7, 0.0, 1.0)
    if current_status == "failed" or current_status == "unstable":
        severity = 1.0
    elif current_status == "won":
        severity = 0.0

    heat_material.albedo_color = COOL.lerp(HOT, heat)
    heat_material.emission = COOL.lerp(HOT, heat)
    coolant_material.emission = COOL.lerp(GOOD, 1.0 - heat)
    seal_material.emission = ALERT.lerp(GOOD, seal)
    signal_material.emission = ALERT.lerp(GOOD, signal_strength)
    energy_material.emission = HOT.lerp(AMBER, energy)
    warning_material.emission = AMBER.lerp(ALERT, severity)
    warning_material.albedo_color = AMBER.lerp(ALERT, severity)
    warning_light.light_color = AMBER.lerp(ALERT, severity)
    warning_light.light_energy = 0.25 + severity * 2.1

    # Visual gauge heights and bulkhead positioning correspond to actual
    # deterministic game metrics, not hardcoded decorative loop states.
    if energy_gauge != null:
        energy_gauge.scale.y = maxf(0.06, energy)
        signal_gauge.scale.y = maxf(0.06, signal_strength)
        seal_gauge.scale.y = maxf(0.06, seal)
        containment_door.position.x = (1.0 - seal) * 1.40
    snapshot_count += 1

func _process(delta: float) -> void:
    if rotor == null or reduced_motion:
        return
    phase += minf(delta, 0.10)
    var power: float = 0.25 + energy * 1.6
    rotor.rotation.y += delta * power
    sensor_array.rotation.y -= delta * (0.12 + (1.0 - pressure) * 0.45)
    pulse = maxf(0.0, pulse - delta * 1.45)
    var flare: float = 1.0 + pulse * 1.4
    var alarm: float = 1.0 + severity * (0.35 + 0.32 * sin(phase * 7.0))
    heat_material.emission_energy_multiplier = 1.4 * flare
    warning_material.emission_energy_multiplier = 1.0 * alarm
    warning_light.light_energy = (0.25 + severity * 2.1) * (1.0 + pulse * 0.5)

func qa_readout() -> Dictionary:
    return {
        "schema": "A7_CINEMATIC_REAL_GODOT_STAGE_V1",
        "actual_native_3d": rotor != null and camera != null and
            heat_material != null and warning_light != null,
        "real_meshes": mesh_count, "real_lights": light_count,
        "camera": camera_index, "quality": mode,
        "reduced_motion": reduced_motion, "snapshots": snapshot_count,
        "heat": heat, "pressure": pressure, "energy": energy,
        "severity": severity, "status": current_status,
        "action_feedback": recent_action,
        "physical_equipment_connected": false,
        "consumer_gpu_certified": false,
    }
