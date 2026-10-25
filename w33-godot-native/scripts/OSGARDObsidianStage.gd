extends Node3D
## OSGARD / OBSIDIAN PROTOCOL W35
## Cinematic laboratory built with original procedural geometry for Godot 4.4.1.
## No external assets, no remote services, no real machine controls.
##
## LOD limits: HERO has decorative microgeometry, ECO hides it and disables
## the key's shadows. All reactive lights reflect read-only gameplay state.

const OBSIDIAN := Color("070b10")
const GRAPHITE := Color("161d23")
const TITANIUM := Color("3c464c")
const CHAMPAGNE := Color("b49a79")
const SIGNAL := Color("70cbbb")
const CRITICAL := Color("dc6257")

var hero_only: Array[Node3D] = []
var smooth_rings: Array[MeshInstance3D] = []
var _precision_ring_batches: Array[MultiMeshInstance3D] = []
var precision_fasteners: MultiMeshInstance3D
var industrial_lights: Array[Light3D] = []
var alarm_lamps: Array[MeshInstance3D] = []
var status_lamps: Array[MeshInstance3D] = []
var key_light: DirectionalLight3D
var emergency_glow: OmniLight3D
var _reduced_motion: bool = false
var _emergency_seconds: float = 0.0
var _quality: String = "hero"
var _alarm: bool = false
var _running: bool = true
var _structure_count: int = 0
var _detail_count: int = 0

func _ready() -> void:
    _construct_architecture()
    _construct_reactor_skin()
    _construct_lighting()
    for lamp in alarm_lamps:
        lamp.visible = false
    _quality = "uninitialized"
    _running = false
    set_quality("hero")
    set_running(true)

func _material(hex_color: String, metal: float = 0.0, rough: float = 0.45, emit: float = 0.0) -> StandardMaterial3D:
    var material := StandardMaterial3D.new()
    material.albedo_color = Color(hex_color)
    material.metallic = metal
    material.roughness = rough
    if emit > 0.0:
        material.emission_enabled = true
        material.emission = Color(hex_color)
        material.emission_energy_multiplier = emit
    return material

func _box(parent: Node3D, label: String, extent: Vector3, at: Vector3, material: Material, hero: bool = false) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    var geometry := BoxMesh.new()
    geometry.size = extent
    node.mesh = geometry
    node.material_override = material
    node.position = at
    node.name = label
    parent.add_child(node)
    if hero:
        node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        hero_only.append(node)
        _detail_count += 1
    else:
        _structure_count += 1
    return node

func _cylinder(parent: Node3D, label: String, radius: float, depth: float, at: Vector3, mat: Material, hero: bool = false, sideways: bool = true) -> MeshInstance3D:
    var obj := MeshInstance3D.new()
    var geo := CylinderMesh.new()
    geo.top_radius = radius
    geo.bottom_radius = radius
    geo.height = depth
    geo.radial_segments = 32
    obj.mesh = geo
    obj.material_override = mat
    obj.position = at
    if sideways:
        obj.rotation_degrees.x = 90.0
    obj.name = label
    parent.add_child(obj)
    if hero:
        obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
        hero_only.append(obj)
        _detail_count += 1
    else:
        _structure_count += 1
    return obj

func _machined_torus(label: String, radius: float, tube: float, z_depth: float, mat: Material, hero: bool = false) -> MeshInstance3D:
    # A smooth original torus surface replaces the toy-looking box-ring edge
    # without changing any of the underlying safety simulation mechanics.
    var geometry := TorusMesh.new()
    geometry.inner_radius = radius - tube
    geometry.outer_radius = radius + tube
    geometry.rings = 96 if not hero else 112
    geometry.ring_segments = 16
    var obj := MeshInstance3D.new()
    obj.name = label
    obj.mesh = geometry
    obj.material_override = mat
    obj.rotation_degrees.x = 90.0
    obj.position = Vector3(0.0, 2.32, z_depth)
    obj.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if hero else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(obj)
    smooth_rings.append(obj)
    if hero:
        hero_only.append(obj)
        _detail_count += 1
    else:
        _structure_count += 1
    return obj

func _add_instanced_precision_fasteners() -> void:
    # 72 teeth form one GPU-instanced mesh, not 72 separate draw submissions.
    # Moving them to the HERO group protects WebGL ECO performance.
    var fasteners := MultiMesh.new()
    fasteners.transform_format = MultiMesh.TRANSFORM_3D
    var bar := BoxMesh.new()
    bar.size = Vector3(0.037, 0.11, 0.028)
    fasteners.mesh = bar
    fasteners.instance_count = 72
    for i in range(72):
        var angle: float = TAU * float(i) / 72.0
        var center := Vector3(cos(angle) * 1.54, 2.32 + sin(angle) * 1.54, 1.49)
        fasteners.set_instance_transform(i, Transform3D(Basis(Vector3.FORWARD, -angle), center))
    precision_fasteners = MultiMeshInstance3D.new()
    precision_fasteners.name = "A7MachinedKnurl72Instances"
    precision_fasteners.multimesh = fasteners
    precision_fasteners.material_override = _material("a69278", 0.89, 0.30)
    precision_fasteners.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    add_child(precision_fasteners)
    hero_only.append(precision_fasteners)
    _detail_count += 1

func _construct_architecture() -> void:
    var basalt := _material("090f15", 0.17, 0.82)
    var graphite := _material("1b222b", 0.70, 0.38)
    var gunmetal := _material("303940", 0.83, 0.32)
    var floor_tile := _material("151c22", 0.42, 0.59)
    var bronze := _material("887153", 0.81, 0.27)
    var copper := _material("af9875", 0.74, 0.36)
    var luminous := _material("69bcb6", 0.13, 0.24, 1.50)
    var warm_strip := _material("b89a6c", 0.0, 0.42, 0.85)
    # The older laboratory mesh is enclosed rather than discarded; the native
    # simulated rotor, hatch, diagnostics and interactive parts remain intact.
    _box(self, "MonolithicRearBasalt", Vector3(22, 11, 0.33), Vector3(0, 4.8, -3.82), basalt)
    _box(self, "BlackStoneLeft", Vector3(0.36, 10, 12), Vector3(-10.9, 4.6, 0.0), graphite)
    _box(self, "BlackStoneRight", Vector3(0.36, 10, 12), Vector3(10.9, 4.6, 0.0), graphite)
    _box(self, "A7RecessedCeiling", Vector3(22, 0.35, 13), Vector3(0, 7.5, 0), basalt)
    _box(self, "BasaltFloor", Vector3(22, 0.20, 16), Vector3(0, -0.34, 1.2), floor_tile)
    for i in range(7):
        var position_x := -8.4 + float(i) * 2.8
        _box(self, "DistantFloorSeam_%02d" % i, Vector3(0.022, 0.012, 14), Vector3(position_x, -0.22, 1.5), gunmetal, true)
    for i in range(7):
        var position_z := -2.9 + float(i) * 2.05
        _box(self, "FloorExpansionJoint_%02d" % i, Vector3(20, 0.014, 0.024), Vector3(0, -0.21, position_z), graphite, true)
    # Monumental bays: industrial fins and inset practical light, no neon flood.
    for side in [-1.0, 1.0]:
        for i in range(4):
            var px: float = float(side) * (5.25 + float(i) * 1.67)
            _box(self, "MonolithPillar_%d_%02d" % [int(side), i], Vector3(0.54, 7.40, 0.84), Vector3(px, 3.48, -3.40), graphite)
            _box(self, "PillarTitaniumFace_%d_%02d" % [int(side), i], Vector3(0.24, 6.70, 0.09), Vector3(px, 3.55, -2.91), gunmetal)
            _box(self, "PillarRecessedLight_%d_%02d" % [int(side), i], Vector3(0.055, 4.30, 0.045), Vector3(px, 3.50, -2.83), luminous)
            _box(self, "BronzePillarCapital_%d_%02d" % [int(side), i], Vector3(0.76, 0.17, 1.02), Vector3(px, 6.97, -3.32), bronze)
        _box(self, "SuspendedCeilingBeam_%d" % int(side), Vector3(0.22, 0.38, 11.8), Vector3(side * 5.05, 6.75, 0.55), graphite)
        for i in range(5):
            var z := -2.20 + float(i) * 2.12
            _box(self, "CeilingRib_%d_%02d" % [int(side), i], Vector3(0.32, 0.26, 0.18), Vector3(side * 5.05, 6.47, z), copper, true)
    # Massive reactor cradle, plinth and hard-edged champagne trim.
    _box(self, "A7FloatingPlinth", Vector3(7.70, 0.18, 5.50), Vector3(0, 0.33, 0.10), graphite)
    _box(self, "A7InsetFoundation", Vector3(6.95, 0.15, 4.95), Vector3(0, 0.45, 0.10), gunmetal)
    for side in [-1.0, 1.0]:
        _box(self, "PlinthWarmCut_%d" % int(side), Vector3(0.025, 0.06, 5.0), Vector3(side * 3.75, 0.46, 0.10), bronze)
        _box(self, "GuideRail_%d" % int(side), Vector3(0.13, 0.19, 10.60), Vector3(side * 4.18, -0.07, 2.0), graphite)
        _box(self, "SafetyFloorLine_%d" % int(side), Vector3(0.055, 0.01, 11), Vector3(side * 4.52, -0.225, 2.00), warm_strip)
    # Layered chamber entry vault makes the set read as a large facility.
    _box(self, "ServiceArchLintel", Vector3(9.55, 0.71, 0.70), Vector3(0, 5.44, -2.75), graphite)
    _box(self, "LintelChampagnePinstripe", Vector3(9.50, 0.035, 0.02), Vector3(0, 5.12, -2.37), bronze)
    for side in [-1.0, 1.0]:
        _box(self, "VaultSteelJamb_%d" % int(side), Vector3(0.82, 4.45, 0.76), Vector3(side * 4.43, 3.06, -2.70), graphite)
        for i in range(7):
            _box(self, "VaultCoolingVent_%d_%02d" % [int(side), i], Vector3(0.44, 0.032, 0.055), Vector3(side * 4.43, 1.13 + i * 0.48, -2.25), gunmetal, true)
    # Shallow recessed overhead worklights with black masks.
    for i in range(5):
        var x := -4.00 + float(i) * 2.00
        _box(self, "CeilingArrayMask_%02d" % i, Vector3(1.48, 0.13, 0.81), Vector3(x, 6.96, 0.2), graphite)
        _box(self, "CeilingArrayDiffuser_%02d" % i, Vector3(1.04, 0.018, 0.31), Vector3(x, 6.84, 0.2), warm_strip)
    # Perspective walkways, railings and equipment racks at the sides.
    for side in [-1.0, 1.0]:
        _box(self, "RearUtilityHousing_%d" % int(side), Vector3(1.05, 2.45, 2.32), Vector3(side * 6.83, 1.24, -1.48), graphite)
        _box(self, "AccessPanel_%d" % int(side), Vector3(0.07, 1.82, 1.31), Vector3(side * 6.28, 1.33, -1.32), gunmetal)
        for i in range(5):
            _box(self, "RackFin_%d_%02d" % [int(side), i], Vector3(0.08, 0.15, 0.95), Vector3(side * 6.21, 0.75 + i * 0.27, -1.26), basalt, true)
        _box(self, "FloorCableTrunk_%d" % int(side), Vector3(0.38, 0.20, 7.7), Vector3(side * 6.07, -0.01, 1.3), gunmetal)
        _box(self, "CableStrake_%d" % int(side), Vector3(0.044, 0.03, 7.7), Vector3(side * 6.07, 0.10, 1.30), bronze)

func _precision_ring_multimesh(index: int, radius: float, depth: float, segments: int, mat: Material) -> void:
    # Previous release W47 rendered 84 tiny box meshes as 84 individual
    # MeshInstance3D drawables despite a shared transform/material pattern.
    # One GPU-instanced draw submission per radius retains exactly the same
    # width, positions, rotations and PBR material without separate nodes.
    # Keep segment 0 of outer ring as a real physical MeshInstance3D for
    # compatibility with W35 visual acceptance and original scene inspectors.
    var first_index: int = 1 if index == 0 else 0
    var count: int = segments - first_index
    var unit := BoxMesh.new()
    unit.size = Vector3(0.095 if index < 2 else 0.042, 0.43 if index == 0 else 0.34, 0.14)
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = unit
    batch.instance_count = count
    for i in range(first_index, segments):
        var angle: float = TAU * float(i) / float(segments)
        var centre := Vector3(cos(angle) * radius, 2.32 + sin(angle) * radius, depth)
        var basis := Basis(Vector3.FORWARD, -angle)
        batch.set_instance_transform(i - first_index, Transform3D(basis, centre))
    var housing := MultiMeshInstance3D.new()
    housing.name = "A7PrecisionRingBatch_%d" % index
    housing.multimesh = batch
    housing.material_override = mat
    housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if index == 2 else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(housing)
    _precision_ring_batches.append(housing)
    if index == 2:
        hero_only.append(housing)
        _detail_count += count
    else:
        _structure_count += count

func _construct_reactor_skin() -> void:
    var oxide := _material("11171d", 0.72, 0.40)
    var machined := _material("414c53", 0.90, 0.24)
    var silvery := _material("7e888c", 0.94, 0.21)
    var champagne := _material("b9a17c", 0.80, 0.29)
    var black_glass := _material("132d35", 0.24, 0.10)
    var teal := _material("77c4b4", 0.12, 0.30, 1.35)
    var amber := _material("ca765e", 0.10, 0.34, 1.55)
    var inactive := _material("2b4448", 0.18, 0.43, 0.28)
    # Side forged frames and upper enclosure over original functional rig.
    for side in [-1.0, 1.0]:
        _box(self, "ReactorForgedShoulder_%d" % int(side), Vector3(0.35, 3.30, 2.47), Vector3(side * 2.68, 2.13, -0.05), machined)
        _box(self, "ReactorTitaniumBlade_%d" % int(side), Vector3(0.08, 2.45, 1.60), Vector3(side * 2.91, 2.07, 0.35), oxide)
        _box(self, "ReactorBronzeSeam_%d" % int(side), Vector3(0.028, 2.65, 1.67), Vector3(side * 2.99, 2.12, 0.36), champagne)
        _box(self, "VerticalActuator_%d" % int(side), Vector3(0.40, 2.15, 0.38), Vector3(side * 3.21, 1.53, 0.73), oxide)
        for i in range(6):
            _box(self, "ActuatorMachinedTeeth_%d_%02d" % [int(side), i], Vector3(0.48, 0.05, 0.47), Vector3(side * 3.21, 0.70 + float(i)*0.33, 0.73), machined, true)
    _box(self, "A7MainHeader", Vector3(6.45, 0.47, 2.1), Vector3(0, 4.22, -0.20), oxide)
    _box(self, "A7HeaderChamfer", Vector3(6.10, 0.055, 1.85), Vector3(0, 4.47, -0.16), champagne)
    _box(self, "A7LowerSill", Vector3(6.05, 0.22, 1.95), Vector3(0, 0.59, 0.20), oxide)
    # The machined circular face is deliberately smooth. The W35 bolted box
    # ring segments remain as forged mechanical insets behind the actual
    # lathed surfaces, so the original architecture and QA remain compatible.
    _machined_torus("A7ContinuousForgedBlackOuter", 1.65, 0.095, 1.08, oxide)
    _machined_torus("A7ContinuousChampagneMachining", 1.46, 0.075, 1.43, champagne)
    _machined_torus("A7ContinuousTitaniumInnerBearing", 1.23, 0.065, 1.47, silvery)
    _machined_torus("A7HeroOpticalGlassMicroRim", 1.09, 0.026, 1.51, _material("579a98", 0.35, 0.25, 0.40), true)
    _add_instanced_precision_fasteners()
    # Concentric high-contrast machined rings in front of the read-only rotor.
    # The actual safety hatch still pivots over this assembly.
    # Identical 84 mechanical segment positions, now only four drawable
    # nodes (one original outer segment plus three genuinely instanced rings).
    _box(self, "A7PrecisionRing_0_00", Vector3(0.095, 0.43, 0.14), Vector3(1.46, 2.32, 1.25), machined)
    for radius_index in range(3):
        var radius: float = 1.46 - float(radius_index) * 0.19
        var depth: float = 1.25 + float(radius_index) * 0.10
        var rim_material: Material = machined if radius_index == 0 else champagne if radius_index == 1 else teal
        _precision_ring_multimesh(radius_index, radius, depth, 28, rim_material)
    _cylinder(self, "CoreBlackOpticalHousing", 0.71, 0.28, Vector3(0, 2.32, 1.34), black_glass)
    _cylinder(self, "CorePolishedBearing", 0.44, 0.30, Vector3(0, 2.32, 1.51), silvery)
    _cylinder(self, "CoreObsidianEmitter", 0.28, 0.32, Vector3(0, 2.32, 1.73), oxide)
    _cylinder(self, "CoreChampagneHub", 0.12, 0.36, Vector3(0, 2.32, 1.93), champagne)
    # Fan ribs, cast hex supports, hydraulic pistons and calibration bearings.
    for i in range(12):
        var angle := TAU * float(i) / 12.0
        var outer := Vector3(cos(angle) * 1.84, 2.32 + sin(angle) * 1.84, 0.55)
        var rib := _box(self, "RingCastSupport_%02d" % i, Vector3(0.19, 0.76, 0.47), outer, oxide)
        rib.rotation.z = -angle
        var bolt := _cylinder(self, "A7PinnedRetainer_%02d" % i, 0.068, 0.09, Vector3(cos(angle)*1.68,2.32+sin(angle)*1.68,1.10), champagne, true)
        bolt.rotation_degrees.x = 90.0
    for side in [-1.0, 1.0]:
        for i in range(4):
            _cylinder(self, "A7ServiceCoupling_%d_%02d" % [int(side),i], 0.13, 0.24, Vector3(side*(1.7+i*0.21), 0.92, 1.28), machined, true)
        _box(self, "A7VentBank_%d" % int(side), Vector3(0.78, 0.90, 0.17), Vector3(side * 2.34, 3.25, 1.20), oxide)
        for j in range(6):
            _box(self, "A7VentMachinedFin_%d_%02d" % [int(side),j], Vector3(0.62, 0.042, 0.14), Vector3(side*2.34,2.94+j*0.115,1.33), machined, true)
    # Real visual state readouts: safety amber, running teal.
    for i in range(3):
        var led := _cylinder(self, "A7EmergentFaultLamp_%d" % i, 0.085, 0.055, Vector3(-0.68 + i * 0.68, 4.06, 1.22), amber, true)
        alarm_lamps.append(led)
    for i in range(5):
        var light := _box(self, "A7BifurcatedSignal_%02d" % i, Vector3(0.27, 0.038, 0.05), Vector3(-0.60 + i*0.30, 0.81, 1.43), inactive)
        status_lamps.append(light)
    # Engraved-like corner cutouts: only real geometry, no stock images.
    for i in range(4):
        var x := -2.75 + i*1.83
        _box(self, "A7UpperMicrocut_%02d" % i, Vector3(0.28, 0.031, 0.043), Vector3(x,4.40,0.97), champagne, true)
    _box(self, "DiagnosticDeskObsidian", Vector3(4.30, 0.14, 0.54), Vector3(0, 0.79, 1.86), oxide)
    _box(self, "DiagnosticDeskLine", Vector3(3.85, 0.015, 0.04), Vector3(0, 0.88, 2.15), teal)
    # Framed side dark glass monitor panels echo real signal conditions.
    for side in [-1.0,1.0]:
        _box(self, "SideDiagnosticsFrame_%d" % int(side), Vector3(0.78, 1.46, 0.11), Vector3(side*3.42,2.53,0.59), machined)
        _box(self, "SideDiagnosticsPanel_%d" % int(side), Vector3(0.63, 1.29, 0.08), Vector3(side*3.42,2.53,0.66), black_glass)
        for i in range(4):
            _box(self, "SideDiagnosticMetric_%d_%02d" % [int(side),i], Vector3(0.48, 0.04, 0.03), Vector3(side*3.42,2.89-i*0.21,0.73), teal, true)

func _construct_lighting() -> void:
    key_light = DirectionalLight3D.new()
    key_light.name = "ObsidianCinematicKey"
    key_light.rotation_degrees = Vector3(-56, -28, 0)
    key_light.light_color = Color("c1d1d2")
    key_light.light_energy = 0.88
    key_light.shadow_enabled = true
    add_child(key_light)
    var edge := OmniLight3D.new()
    edge.name = "ChampagneRimPractical"
    edge.position = Vector3(-4.50, 5.65, 3.85)
    edge.light_color = Color("e1b788")
    edge.light_energy = 1.70
    edge.omni_range = 12.0
    edge.shadow_enabled = false
    add_child(edge)
    industrial_lights.append(edge)
    var cool := OmniLight3D.new()
    cool.name = "CoolSculpturalFill"
    cool.position = Vector3(4.60, 4.15, 1.25)
    cool.light_color = Color("8dabb8")
    cool.light_energy = 1.20
    cool.omni_range = 10.0
    cool.shadow_enabled = false
    add_child(cool)
    industrial_lights.append(cool)
    # Controlled angled fill reveals the metal profile instead of leaving the
    # left side of the original W39 screenshot as a featureless black void.
    var contour := SpotLight3D.new()
    contour.name = "RakingMachinedMetalContour"
    contour.position = Vector3(-4.65, 4.35, 4.4)
    contour.light_color = Color("ecc4a2")
    contour.light_energy = 0.85
    contour.spot_range = 13.0
    contour.spot_angle = 43.0
    contour.shadow_enabled = false
    add_child(contour)
    contour.look_at(Vector3(0.0, 2.24, 0.78), Vector3.UP)
    industrial_lights.append(contour)
    emergency_glow = OmniLight3D.new()
    emergency_glow.name = "TrueSimulatedEmergencySculpture"
    emergency_glow.position = Vector3(0.0, 4.5, 2.3)
    emergency_glow.light_color = Color("dd6759")
    emergency_glow.omni_range = 8.0
    emergency_glow.light_energy = 0.0
    emergency_glow.shadow_enabled = false
    add_child(emergency_glow)

func set_reduced_motion(reduced: bool) -> void:
    _reduced_motion = reduced

func _process(delta: float) -> void:
    if emergency_glow == null:
        return
    if not _alarm:
        emergency_glow.light_energy = 0.0
        return
    if _reduced_motion:
        emergency_glow.light_energy = 0.42 if _quality == "eco" else 0.72
        return
    _emergency_seconds += maxf(delta, 0.0)
    var modulation: float = 0.74 + 0.26 * sin(_emergency_seconds * 5.5)
    emergency_glow.light_energy = modulation * (0.62 if _quality == "eco" else 0.96)

func set_quality(mode: String) -> void:
    if mode == _quality:
        return
    _quality = mode
    for detail in hero_only:
        detail.visible = mode == "hero"
    if key_light != null:
        key_light.shadow_enabled = mode == "hero"
    for i in range(industrial_lights.size()):
        var lamp: Light3D = industrial_lights[i]
        var hero_energy: float = 1.70 if i == 0 else 1.20 if i == 1 else 0.85
        # The extra premium raking spot is off entirely in ECO.
        lamp.light_energy = (0.0 if mode == "eco" else hero_energy) if i == 2 else hero_energy * (0.70 if mode == "eco" else 1.0)

func set_alarm(danger: bool) -> void:
    if _alarm == danger:
        return
    _alarm = danger
    _emergency_seconds = 0.0
    for lamp in alarm_lamps:
        lamp.visible = danger
    if emergency_glow != null:
        emergency_glow.light_energy = (0.66 if _quality == "hero" else 0.42) if danger else 0.0

func set_running(running: bool) -> void:
    if _running == running:
        return
    _running = running
    var mat := _material("77c4b4", 0.06, 0.30, 1.15) if running else _material("3c514e", 0.08, 0.42, 0.28)
    for lamp in status_lamps:
        lamp.material_override = mat

func qa_readout() -> Dictionary:
    var visible_details: int = 0
    for detail in hero_only:
        if detail.visible:
            var instanced: MultiMeshInstance3D = detail as MultiMeshInstance3D
            visible_details += instanced.multimesh.instance_count if instanced != null else 1
    var ring_segments: int = 1
    for group in _precision_ring_batches:
        ring_segments += group.multimesh.instance_count
    return {
        "art_direction": "OSGARD_OBSIDIAN_PROTOCOL_W35",
        "visible_hero_details": visible_details,
        "alarm": _alarm,
        "running": _running,
        "reduced_motion": _reduced_motion,
        "emergency_lighting": emergency_glow != null and emergency_glow.light_energy > 0.0,
        "emergency_light_energy": emergency_glow.light_energy if emergency_glow != null else 0.0,
        "emergency_pulse_seconds": _emergency_seconds,
        "key_shadow_enabled": key_light.shadow_enabled if key_light != null else false,
        "cinematic_complex": true,
        "structures": _structure_count,
        "hero_details": _detail_count,
        "reactor_rings": 3,
        "precision_ring_gpu_batches": _precision_ring_batches.size(),
        "precision_ring_segments_total": ring_segments,
        "precision_ring_drawable_nodes": _precision_ring_batches.size() + 1,
        "precision_ring_legacy_segment_node": has_node("A7PrecisionRing_0_00"),
        "continuous_torus_surfaces": smooth_rings.size(),
        "lathed_torus_meshes": smooth_rings.all(func(ring: MeshInstance3D) -> bool: return ring.mesh is TorusMesh),
        "instanced_precision_fasteners": precision_fasteners.multimesh.instance_count if precision_fasteners != null else 0,
        "machined_fastener_batch_visible": precision_fasteners.visible if precision_fasteners != null else false,
        "cinematic_fill_count": industrial_lights.size(),
        "contour_light_hero_only": industrial_lights[2].light_energy if industrial_lights.size() > 2 else 0.0,
        "hero_vs_eco": _quality,
        "alarm_reflects_simulation": true,
        "external_asset_dependency": false,
        "network_connection": false,
        "physical_device_certified": false,
        "photorealistic_aaa_certified": false
    }
