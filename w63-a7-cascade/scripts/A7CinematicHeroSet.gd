extends Node3D
class_name A7CinematicHeroSet
## W68: original authored cinematic shapes over actual W67 two-room world.
## Ring-machinery, service pistons, industrial pipes, consoles, hatches,
## genuine procedural PBR materials and functional status lighting.
## Nothing is a 2D fake. This component cannot change gameplay state.

const BLUE := Color("68dce6")
const AMBER := Color("f2bd77")
const RED := Color("ee6b62")

var surface_lab: A7CinematicMaterialLab
var hero_details: Node3D
var essential: Node3D
var core_ring: Node3D
var relay_instrument: Node3D
var spot_core: SpotLight3D
var spot_relay: SpotLight3D
var core_emission: StandardMaterial3D
var relay_emission: StandardMaterial3D
var hazard_emission: StandardMaterial3D
var structure_count: int = 0
var true_torus_count: int = 0
var pipe_segments: int = 0
var visual_snapshots: int = 0
var damage: float = 0.0
var power: float = 0.85
var current_quality: String = "hero"

func _b(parent: Node3D, tag: String, size: Vector3, pos: Vector3,
        finish: Material) -> MeshInstance3D:
    var primitive := BoxMesh.new()
    primitive.size = size
    var obj := MeshInstance3D.new()
    obj.name = tag
    obj.mesh = primitive
    obj.material_override = finish
    obj.position = pos
    parent.add_child(obj)
    structure_count += 1
    return obj

func _c(parent: Node3D, tag: String, radius: float, height: float,
        pos: Vector3, finish: Material) -> MeshInstance3D:
    var primitive := CylinderMesh.new()
    primitive.top_radius = radius
    primitive.bottom_radius = radius
    primitive.height = height
    primitive.radial_segments = 20
    var obj := MeshInstance3D.new()
    obj.name = tag
    obj.mesh = primitive
    obj.material_override = finish
    obj.position = pos
    parent.add_child(obj)
    structure_count += 1
    return obj

func _t(parent: Node3D, tag: String, inner_radius: float, outer_radius: float,
        pos: Vector3, finish: Material) -> MeshInstance3D:
    var primitive := TorusMesh.new()
    primitive.inner_radius = inner_radius
    primitive.outer_radius = outer_radius
    primitive.ring_segments = 12
    primitive.rings = 40
    var obj := MeshInstance3D.new()
    obj.name = tag
    obj.mesh = primitive
    obj.material_override = finish
    obj.position = pos
    parent.add_child(obj)
    true_torus_count += 1
    structure_count += 1
    return obj

func _pipe(parent: Node3D, tag: String, a: Vector3, b: Vector3, r: float,
        finish: Material) -> void:
    var direction: Vector3 = b - a
    var pipe := _c(parent, tag, r, direction.length(), (a + b) * 0.5, finish)
    pipe.quaternion = Quaternion(Vector3.UP, direction.normalized())
    pipe_segments += 1

func _status_material(color: Color, energy: float) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = color
    material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    material.emission_enabled = true
    material.emission = color
    material.emission_energy_multiplier = energy
    return material

func _spot(tag: String, pos: Vector3, point: Vector3,
        tint: Color, lumens: float, range: float) -> SpotLight3D:
    var light := SpotLight3D.new()
    light.name = tag
    light.position = pos
    light.look_at(point, Vector3.UP)
    light.spot_range = range
    light.spot_angle = 42.0
    light.light_color = tint
    light.light_energy = lumens
    light.shadow_enabled = false
    add_child(light)
    return light

func build() -> void:
    name = "W68CinematicHeroStudioPracticalProps"
    surface_lab = A7CinematicMaterialLab.new()
    var iron: StandardMaterial3D = surface_lab.surface("dark_steel")
    var shell: StandardMaterial3D = surface_lab.surface("reactor_shell")
    var ceramic: StandardMaterial3D = surface_lab.surface("ceramic")
    var aged: StandardMaterial3D = surface_lab.surface("oxide")
    var rubber: StandardMaterial3D = surface_lab.surface("rubber")
    var hazard: StandardMaterial3D = surface_lab.surface("painted_hazard")
    var gratings: StandardMaterial3D = surface_lab.surface("floor_grate")
    core_emission = _status_material(BLUE, 1.75)
    relay_emission = _status_material(BLUE, 1.55)
    hazard_emission = _status_material(AMBER, 1.30)

    essential = Node3D.new()
    essential.name = "W68EssentialReadableIndustrialShapes"
    add_child(essential)
    hero_details = Node3D.new()
    hero_details.name = "W68HighFrequencyAuthoredHeroDetails"
    add_child(hero_details)
    core_ring = Node3D.new()
    core_ring.name = "ActualAnnularContainmentMechanism"
    add_child(core_ring)
    relay_instrument = Node3D.new()
    relay_instrument.name = "ActualRelayInstrumentation"
    relay_instrument.position = Vector3(8.0, 0.0, 19.0)
    add_child(relay_instrument)

    # Real smooth annular geometry replaces the ambiguous stack of loose
    # horizontal LED blocks in the earlier screenshot.
    for level in range(6):
        var y: float = 0.85 + float(level) * 0.64
        var wide: float = 1.40 if level % 2 == 0 else 1.33
        _t(core_ring, "PrecisionReactorClampingBand%02d" % level,
            wide, wide + 0.14, Vector3(0.0, y, -0.25),
            aged if level % 3 == 0 else shell)
        _t(core_ring, "ElectroluminescentInnerTrack%02d" % level,
            wide + 0.12, wide + 0.16,
            Vector3(0.0, y + 0.085, -0.25), core_emission)
    for idx in range(12):
        var angle: float = TAU * float(idx) / 12.0
        var x: float = sin(angle) * 1.73
        var z: float = cos(angle) * 1.73 - 0.25
        _c(essential, "VerticalContainmentPiston%02d" % idx,
            0.11, 3.46, Vector3(x, 2.45, z), aged)
        _c(essential, "HydraulicPistonSleeve%02d" % idx,
            0.16, 0.47, Vector3(x, 1.05, z), shell)
        _c(essential, "PistonHead%02d" % idx,
            0.19, 0.17, Vector3(x, 4.19, z), ceramic)
        if idx % 2 == 0:
            var fin := _b(hero_details, "RadialPressureValve%02d" % idx,
                Vector3(0.18, 0.26, 0.86),
                Vector3(sin(angle) * 1.93, 2.40, cos(angle) * 1.93 - 0.25),
                iron)
            fin.rotation.y = angle
            _c(hero_details, "ValveHub%02d" % idx, 0.17, 0.26,
                Vector3(sin(angle) * 1.97, 2.4, cos(angle) * 1.97 - 0.25), hazard)
    _c(essential, "ReactorCeramicContainmentCrown",
        1.67, 0.37, Vector3(0.0, 4.57, -0.25), ceramic)
    _t(essential, "MachinedContainmentCrownGasket",
        1.48, 1.70, Vector3(0, 4.81, -0.25), rubber)

    # Wear marks and tie-bars on a real service cradle at visual foreground.
    for side in [-1, 1]:
        var sx: float = float(side)
        _b(essential, "SubFrameLongitudinalBeam%d" % side,
            Vector3(0.34, 0.52, 5.60), Vector3(sx * 2.5, 0.45, 1.85), iron)
        _b(essential, "CradleCeramicSafetyEdge%d" % side,
            Vector3(0.10, 0.06, 5.55), Vector3(sx * 2.5, 0.76, 1.85), ceramic)
        for station in range(4):
            var zz: float = -0.35 + float(station) * 1.48
            _b(hero_details, "BeamLock%02d_%02d" % [side,station],
                Vector3(0.55, 0.14, 0.42),
                Vector3(sx * 2.5, 0.80, zz), aged)
    for x in range(6):
        var xx: float = -2.15 + float(x) * 0.86
        _b(essential, "IndustrialInspectionGrate%02d" % x,
            Vector3(0.11, 0.045, 4.75),
            Vector3(xx, -0.08, 2.65), gratings)

    # Actual elbowed pressure lines create volumetric plausibility.
    for side in [-1, 1]:
        var sx: float = float(side)
        for line in range(3):
            var z: float = -1.25 + float(line) * 0.83
            var start := Vector3(sx * 2.10, 3.62, z)
            var elbow := Vector3(sx * 3.32, 3.62, z)
            var down := Vector3(sx * 3.32, 1.04, z + 0.23)
            _pipe(essential, "HeatTransportManifold%d_%dA" % [side,line],
                start, elbow, 0.095, aged)
            _pipe(essential, "HeatTransportManifold%d_%dB" % [side,line],
                elbow, down, 0.095, aged)
            _c(essential, "ManifoldLocknut%d_%d" % [side,line],
                0.17, 0.16, down, shell)

    # Two field-engineer stations are proper consoles, not floating LEDs.
    for side in [-1, 1]:
        var xx: float = float(side) * 4.10
        _b(essential, "OperatorErgonomicBase%d" % side,
            Vector3(1.65, 0.20, 1.21), Vector3(xx, 0.38, 2.14), iron)
        _b(essential, "OperatorConsoleChassis%d" % side,
            Vector3(1.75, 1.35, 0.55), Vector3(xx, 1.28, 2.14), shell)
        _b(essential, "AngledPanel%d" % side,
            Vector3(1.52, 0.08, 0.47), Vector3(xx, 1.98, 1.93), rubber)
        for cell in range(7):
            var dx: float = -0.62 + float(cell) * 0.205
            _b(hero_details, "OperatorPhysicalSwitch%d_%02d" % [side,cell],
                Vector3(0.095, 0.045, 0.09),
                Vector3(xx + dx, 2.037, 1.94),
                hazard if cell % 3 == 0 else ceramic)
        _b(essential, "OperatorRealSignalLine%d" % side,
            Vector3(1.25, 0.012, 0.048),
            Vector3(xx, 2.048, 1.90), relay_emission)

    # Relay hall is an alternate location with its own coherent machinery,
    # powered stacks, cable service network and restrained emergency cues.
    for idx in range(3):
        var xx: float = -2.8 + float(idx) * 2.8
        _t(relay_instrument, "RelayCoilAnnulus%d" % idx,
            0.65, 0.80, Vector3(xx, 2.03, -2.55), aged)
        _t(relay_instrument, "RelayCoilSignal%d" % idx,
            0.80, 0.86, Vector3(xx, 2.08, -2.55), relay_emission)
        for bolt in range(6):
            var theta: float = TAU * float(bolt) / 6.0
            _c(hero_details, "RelayServiceBolt%d_%d" % [idx,bolt],
                0.075, 0.12,
                Vector3(8.0 + xx + sin(theta) * 1.0,
                    4.25, 19.0 - 2.55 + cos(theta) * 1.0), shell)
        _b(relay_instrument, "RelayMachineInspectionPlate%d" % idx,
            Vector3(1.1, 0.45, 0.17),
            Vector3(xx, 3.29, -1.85), ceramic)
        _b(relay_instrument, "RelayMachineLiveScreen%d" % idx,
            Vector3(0.79, 0.19, 0.025),
            Vector3(xx, 3.29, -1.75), relay_emission)
    for ix in range(7):
        var xx: float = -4.2 + float(ix) * 1.4
        _b(relay_instrument, "RelayBaseFootplate%02d" % ix,
            Vector3(1.20, 0.045, 0.33),
            Vector3(xx, 0.13, 1.18), gratings)
        _b(relay_instrument, "RelaySafetyPaint%02d" % ix,
            Vector3(0.20, 0.048, 0.31),
            Vector3(xx, 0.16, 1.18), hazard)

    # Local task-light pools for dimensionality, not uncontrolled bloom.
    spot_core = _spot("TaskLightOnPrimaryContainment",
        Vector3(3.4, 6.20, 3.5), Vector3(0, 2.20, -0.25),
        Color("ffcf97"), 2.9, 15.0)
    spot_relay = _spot("TaskLightOnRelayAndPowerPlant",
        Vector3(8.0, 7.10, 22.0), Vector3(8, 2.4, 16.5),
        Color("b2ecf4"), 2.40, 14.0)

func set_quality(quality: String) -> void:
    current_quality = "eco" if quality == "eco" else "hero"
    if hero_details != null:
        hero_details.visible = current_quality == "hero"
    if spot_core != null:
        spot_core.light_energy = 2.9 if current_quality == "hero" else 1.3
        spot_relay.light_energy = 2.40 if current_quality == "hero" else 1.1

func present(state: Dictionary) -> void:
    var stats: Dictionary = state.get("metrics", {})
    power = clampf(float(stats.get("energy", 85)) / 100.0, 0, 1)
    var integrity: float = clampf(float(stats.get("integrity", 100)) / 100.0, 0, 1)
    var heat: float = clampf(float(stats.get("heat", 62)) / 100.0, 0, 1)
    damage = clampf(1.0 - integrity + maxf(0, heat - 0.75), 0, 1)
    if str(state.get("status", "playing")) in ["failed", "unstable"]:
        damage = 1.0
    if core_emission != null:
        core_emission.emission = BLUE.lerp(RED, damage)
        core_emission.albedo_color = core_emission.emission
        core_emission.emission_energy_multiplier = 1.1 + damage * 1.0
    if relay_emission != null:
        relay_emission.emission = RED.lerp(BLUE, power)
        relay_emission.albedo_color = relay_emission.emission
        relay_emission.emission_energy_multiplier = 0.6 + power * 1.8
    if hazard_emission != null:
        hazard_emission.emission = AMBER.lerp(RED, damage)
    visual_snapshots += 1

func qa_readout() -> Dictionary:
    return {
        "schema": "LAST_FRONTIER_W68_ORIGINAL_PBR_HERO_GAME_V1",
        "meshes": structure_count,
        "smooth_machined_torus_parts": true_torus_count,
        "modeled_pressure_pipe_sections": pipe_segments,
        "task_spot_lights": int(spot_core != null) + int(spot_relay != null),
        "real_material_profiles": surface_lab.generated if surface_lab != null else 0,
        "procedural_pixels": surface_lab.pixels_written if surface_lab != null else 0,
        "material_texture_source": "ImageTexture",
        "quality": current_quality,
        "visual_snapshots": visual_snapshots,
        "gameplay_authority": false,
        "external_art_licensed_or_downloaded": false,
        "consumer_gpu_certified": false,
    }
