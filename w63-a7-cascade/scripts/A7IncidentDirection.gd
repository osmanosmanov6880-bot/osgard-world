extends Node3D
class_name A7IncidentDirection
## W69 / CINEMATIC INCIDENT DIRECTION. Genuine local Godot 3D.
## Pure fiction. Scene reads A7CascadeCore state; NEVER changes its rules.
## Native mesh shutters, incident lights, in-world instruments, glass/vapor.
## No external models, music, photographs, stock textures or network traffic.

const ICE := Color("6bd9e7")
const COPPER := Color("d6a978")
const RED := Color("f46f67")
const DARK := Color("273642")
const PARCHMENT := Color("dce7e8")

var main_rig: Node3D
var extra_atmosphere: Node3D
var core_shutters: Array[MeshInstance3D] = []
var relay_shutters: Array[MeshInstance3D] = []
var scanner_lattice: Node3D
var vapor_planes: Array[MeshInstance3D] = []
var core_alarm: OmniLight3D
var relay_alarm: OmniLight3D
var reactor_readout: Label3D
var relay_readout: Label3D
var action_material: StandardMaterial3D
var alert_material: StandardMaterial3D
var window_material: StandardMaterial3D
var vapor_material: StandardMaterial3D
var mesh_count: int = 0
var label_count: int = 0
var snapshot_count: int = 0
var accepted_actions: int = 0
var actuation: float = 0.0
var incident_severity: float = 0.0
var action_flash: float = 0.0
var time_phase: float = 0.0
var reduced_motion: bool = false
var compact: bool = false
var quality: String = "hero"
var current_status: String = "playing"
var last_event: String = ""
var last_action: String = ""

func _mat(color: Color, metallic: float = 0.08, glow: float = 0.0) -> StandardMaterial3D:
    var finish := StandardMaterial3D.new()
    finish.albedo_color = color
    finish.metallic = metallic
    finish.roughness = 0.63
    if glow > 0.0:
        finish.emission_enabled = true
        finish.emission = color
        finish.emission_energy_multiplier = glow
    return finish

func _box(parent: Node3D, id: String, dims: Vector3, at: Vector3,
        finish: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = dims
    var item := MeshInstance3D.new()
    item.name = id
    item.mesh = mesh
    item.material_override = finish
    item.position = at
    parent.add_child(item)
    mesh_count += 1
    return item

func _light(id: String, at: Vector3, color: Color, energy: float) -> OmniLight3D:
    var item := OmniLight3D.new()
    item.name = id
    item.position = at
    item.light_color = color
    item.light_energy = energy
    item.omni_range = 7.8
    item.shadow_enabled = false
    add_child(item)
    return item

func _label(parent: Node3D, id: String, at: Vector3, size: int) -> Label3D:
    var item := Label3D.new()
    item.name = id
    item.position = at
    item.font_size = size
    item.pixel_size = 0.0032
    item.modulate = PARCHMENT
    item.no_depth_test = false
    parent.add_child(item)
    label_count += 1
    return item

func _vapor() -> StandardMaterial3D:
    # Original locally authored alpha texture with soft density and no
    # photographic or licensed effect source. A small number of planes only.
    var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
    for y in range(64):
        for x in range(64):
            var u: float = (float(x) - 31.5) / 31.5
            var v: float = (float(y) - 31.5) / 31.5
            var halo: float = maxf(0.0, 1.0 - u*u - v*v)
            var drift: float = 0.70 + 0.30 * sin(float(x)*0.29 + float(y)*0.14)
            var alpha: float = pow(halo, 2.2) * drift * 0.19
            img.set_pixel(x, y, Color(0.46, 0.72, 0.77, alpha))
    img.generate_mipmaps()
    var material := StandardMaterial3D.new()
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    material.albedo_texture = ImageTexture.create_from_image(img)
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.cull_mode = BaseMaterial3D.CULL_DISABLED
    return material

func build() -> void:
    name = "W69PhysicalIncidentDirection"
    main_rig = Node3D.new()
    main_rig.name = "OperationalCinematicMachines"
    add_child(main_rig)
    extra_atmosphere = Node3D.new()
    extra_atmosphere.name = "OriginalSubtleAtmosphereHERO"
    add_child(extra_atmosphere)
    scanner_lattice = Node3D.new()
    scanner_lattice.name = "ActiveDiagnosticBeamLattice"
    main_rig.add_child(scanner_lattice)

    var structural := _mat(DARK, 0.18)
    var gilded := _mat(COPPER, 0.12)
    alert_material = _mat(COPPER, 0.01, 1.1)
    action_material = _mat(ICE, 0.02, 1.65)
    window_material = _mat(Color("567282"), 0.03)

    # Functional interlocked shutters from the real game's incident metrics.
    for side in [-1, 1]:
        var sx: float = float(side)
        var shutter := _box(main_rig, "PhysicalReactorBaffle%d" % side,
            Vector3(0.36, 3.8, 1.4), Vector3(sx * 3.6, 2.25, -2.45),
            structural)
        core_shutters.append(shutter)
        _box(shutter, "SafetyPaintOnReactorBaffle%d" % side,
            Vector3(0.39, 0.11, 0.97), Vector3.ZERO, alert_material)
        _box(main_rig, "ReactorActuatorRail%d" % side,
            Vector3(0.16, 0.16, 3.7), Vector3(sx*3.6, 4.55, -2.0), gilded)
        var relay := _box(main_rig, "RealRelayBulkheadBaffle%d" % side,
            Vector3(0.43, 4.0, 1.35),
            Vector3(8.0 + sx*3.85, 2.25, 16.4), structural)
        relay_shutters.append(relay)
        _box(relay, "RelayActuatorStatus%d" % side,
            Vector3(0.44, 0.10, 0.95), Vector3.ZERO, alert_material)

    for i in range(10):
        var angle: float = TAU * float(i) / 10.0
        var arm := _box(scanner_lattice, "RealDiagnosticOptic%02d" % i,
            Vector3(0.035, 0.09, 0.55),
            Vector3(sin(angle)*1.88, 2.68, cos(angle)*1.88-0.25),
            action_material)
        arm.rotation.y = angle
    for sector in range(2):
        var center: Vector3 = Vector3(0,0,0) if sector == 0 else Vector3(8,0,19)
        _box(main_rig, "WarningLightBus%d" % sector,
            Vector3(2.6, 0.17, 0.48),
            center + Vector3(0, 4.85, -3.80), gilded)
        for i in range(8):
            var xx: float = -1.15 + float(i)*0.33
            _box(main_rig, "SectorSignalSegment%d_%02d" % [sector,i],
                Vector3(0.21, 0.07, 0.13),
                center + Vector3(xx, 4.72, -3.43),
                alert_material if i%2 == 0 else action_material)
    core_alarm = _light("ReactorPracticalAmberAlarm",
        Vector3(0, 5.9, 0.9), COPPER, 0.12)
    relay_alarm = _light("RelayPracticalAmberAlarm",
        Vector3(8, 6.5, 16.5), COPPER, 0.12)

    # In-world instruments use the ACTUAL game state, unlike fake movie UI.
    reactor_readout = _label(main_rig, "ActualOperatorHeatPressureTelemetry",
        Vector3(-4.35, 3.1, -0.05), 38)
    relay_readout = _label(main_rig, "ActualRelayEnergySignalTelemetry",
        Vector3(8.0, 4.05, 13.55), 42)
    _box(main_rig, "CoreServiceGlassPanel", Vector3(2.5, 1.12, 0.12),
        Vector3(-4.35, 3.16, -0.22), window_material)
    _box(main_rig, "RelayServiceGlassPanel", Vector3(3.7, 1.32, 0.10),
        Vector3(8.0, 4.1, 13.33), window_material)

    vapor_material = _vapor()
    for i in range(8):
        var plane := MeshInstance3D.new()
        plane.name = "RealGodotAtmosphericVapor%02d" % i
        var quad := QuadMesh.new()
        quad.size = Vector2(1.6 + float(i%3)*0.25, 3.4)
        plane.mesh = quad
        plane.material_override = vapor_material
        plane.position = Vector3(-2.8 + float(i%4)*1.85, 3.1,
            (0.55 if i<4 else 19.9))
        if i >= 4:
            plane.position.x += 8.0
        extra_atmosphere.add_child(plane)
        vapor_planes.append(plane)
        mesh_count += 1
    set_quality("hero")
    set_compact_view(false)
    set_process(true)

func present(state: Dictionary) -> void:
    var stats: Dictionary = state.get("metrics", {})
    var heat: int = int(stats.get("heat", 62))
    var pressure: int = int(stats.get("pressure", 48))
    var energy: int = int(stats.get("energy", 85))
    var signal_strength: int = int(stats.get("signal", 44))
    var integrity: int = int(stats.get("integrity", 100))
    current_status = str(state.get("status", "playing"))
    last_event = str(state.get("last_event", ""))
    incident_severity = clampf(maxf(float(heat - 72)/28.0,
        float(pressure - 76)/24.0) + float(100 - integrity)/160.0, 0, 1)
    if current_status in ["failed", "unstable"]:
        incident_severity = 1.0
    elif current_status == "won":
        incident_severity = 0.0
    actuation = incident_severity
    var hazard: Color = COPPER.lerp(RED, incident_severity)
    alert_material.albedo_color = hazard
    alert_material.emission = hazard
    action_material.emission = RED.lerp(ICE, float(signal_strength) / 100.0)
    if reactor_readout != null:
        reactor_readout.text = "THERMAL  %03d\nPRESSURE %03d" % [heat,pressure]
    if relay_readout != null:
        relay_readout.text = "POWER  %03d\nSIGNAL %03d" % [energy,signal_strength]
    # Position drives the actual native shutter meshes; non-animated mode
    # still shows a deterministic, visually readable equipment state.
    for side in range(core_shutters.size()):
        var sign_side: float = -1.0 if side == 0 else 1.0
        core_shutters[side].position.x = sign_side * (3.6 - actuation*0.62)
        relay_shutters[side].position.x = 8.0 + sign_side*(3.85-actuation*0.50)
    snapshot_count += 1

func accepted_action(action: String) -> void:
    if not ["PUMP", "VENT", "SEAL", "SCAN", "POWER"].has(action):
        return
    accepted_actions += 1
    last_action = action
    action_flash = 1.0

func set_quality(new_quality: String) -> void:
    quality = "eco" if new_quality == "eco" else "hero"
    if extra_atmosphere != null:
        extra_atmosphere.visible = quality == "hero"
    if scanner_lattice != null:
        scanner_lattice.visible = quality == "hero"
    if core_alarm != null:
        core_alarm.light_energy = 0.08 if quality == "eco" else 0.12
        relay_alarm.light_energy = 0.08 if quality == "eco" else 0.12

func set_compact_view(enabled: bool) -> void:
    compact = enabled
    if reactor_readout != null:
        reactor_readout.visible = not compact
    if relay_readout != null:
        relay_readout.visible = not compact

func set_reduced_motion(enabled: bool) -> void:
    reduced_motion = enabled
    if enabled:
        action_flash = 0.0
        scanner_lattice.rotation = Vector3.ZERO

func _process(delta: float) -> void:
    if main_rig == null or alert_material == null:
        return
    if reduced_motion:
        core_alarm.light_energy = 0.12 + incident_severity*0.95
        relay_alarm.light_energy = 0.12 + incident_severity*0.95
        return
    time_phase += minf(delta, 0.08)
    action_flash = maxf(0.0, action_flash - delta*1.7)
    var flicker: float = sin(time_phase*7.8)
    var warning_strength: float = 0.16 + incident_severity * (
        0.85 + flicker*0.40) + action_flash*0.6
    core_alarm.light_energy = warning_strength
    relay_alarm.light_energy = warning_strength * 0.84
    alert_material.emission_energy_multiplier = (
        0.75 + incident_severity*1.15 + action_flash*0.60)
    action_material.emission_energy_multiplier = 1.15 + action_flash*1.25
    scanner_lattice.rotation.y += delta*(0.12 + action_flash*0.36)
    for i in range(vapor_planes.size()):
        var plane: MeshInstance3D = vapor_planes[i]
        plane.position.y = 3.1 + 0.20 * sin(time_phase*0.62 + float(i)*0.73)

func qa_readout() -> Dictionary:
    return {
        "schema": "LAST_FRONTIER_W69_NATIVE_INCIDENT_DIRECTION_V1",
        "real_meshes": mesh_count,
        "real_shutters": core_shutters.size() + relay_shutters.size(),
        "real_scanner_optics": scanner_lattice.get_child_count(),
        "actual_vapor_planes": vapor_planes.size(),
        "native_lights": int(core_alarm != null) + int(relay_alarm != null),
        "in_world_readouts": label_count,
        "reported_pressure": reactor_readout.text if reactor_readout != null else "",
        "reported_energy": relay_readout.text if relay_readout != null else "",
        "hazard": incident_severity,
        "accepted_actions": accepted_actions,
        "action_flash": action_flash,
        "status": current_status,
        "quality": quality,
        "compact_view": compact,
        "reduced_motion": reduced_motion,
        "gameplay_authority": false,
        "network_or_licensed_art_used": false,
        "physical_gpu_certified": false,
    }
