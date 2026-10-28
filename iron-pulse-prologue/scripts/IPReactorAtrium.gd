extends Node3D
class_name IPReactorAtrium
## IRON PULSE / V8 — original vertical reactor megastructure.
## A cinematic side atrium replaces the unbroken corridor wall, while a real
## physical guardrail keeps the existing 3D mission path and terminals safe.
## No borrowed meshes, 3rd-party textures or remote dependencies.

const CORE_CENTER := Vector3(12.3, 7.0, -20.5)
const OPENING_Z_MIN := -31.0
const OPENING_Z_MAX := -9.0
const METAL_DARK := Color(0.13, 0.18, 0.22)
const STEEL_WARM := Color(0.40, 0.45, 0.47)
const CERAMIC := Color(0.22, 0.29, 0.33)
const CAUTION := Color(0.96, 0.47, 0.19)
const PLASMA := Color(0.22, 0.75, 0.83)

var structure: Node3D
var hero_details: Node3D
var shield_housing: Node3D
var _painted: StandardMaterial3D
var _steel: StandardMaterial3D
var _deck: StandardMaterial3D
var _dark: StandardMaterial3D
var _plasma: StandardMaterial3D
var _warning: StandardMaterial3D
var _lights: Array[OmniLight3D] = []
var _mechanical_rotors: Array[Node3D] = []
var _plasma_bands: Array[StandardMaterial3D] = []
var _mesh_count: int = 0
var _physical_rails: int = 0
var _signs: int = 0
var _repeated_instances: int = 0
var _pbr_maps: int = 0
var _quality: String = "hero"
var _hazard: float = 0.0
var _last_emissive: float = 1.0

func _ready() -> void:
    name = "A7_CinematicReactorAtrium"
    structure = Node3D.new()
    structure.name = "PermanentShell"
    add_child(structure)
    hero_details = Node3D.new()
    hero_details.name = "HERO_OptionalDetail"
    add_child(hero_details)
    _make_original_materials()
    _build_open_vault()
    _build_guardrail()
    _build_monumental_core_housing()
    _build_catwalk_network()
    _build_machined_detail()
    _build_diegetic_signs()
    _build_lighting()
    set_quality("hero")

func _procedural_pbr_maps() -> Dictionary:
    # One deterministic original paint/wear atlas: albedo grain, uneven
    # roughness, and tiny embossed scratch normals. No sourced art.
    var albedo := Image.create(96, 96, false, Image.FORMAT_RGBA8)
    var rough := Image.create(96, 96, false, Image.FORMAT_RGBA8)
    var normal := Image.create(96, 96, false, Image.FORMAT_RGBA8)
    for y in range(96):
        for x in range(96):
            var cross: int = (x*71 + y*127 + x*y*3 + (x*y)%11) % 251
            var grain: float = float(cross) / 250.0
            var scratch: float = 0.16 if (x+3*y)%37 == 0 or (x+11*y)%89 == 0 else 0.0
            var value: float = clampf(0.74 + grain*0.19-scratch,0.35,1.0)
            albedo.set_pixel(x,y,Color(value,value*0.98,value*0.94,1.0))
            var roughness: float = clampf(0.48+grain*0.33+scratch,0.20,1.0)
            rough.set_pixel(x,y,Color(roughness,roughness,roughness,1.0))
            var slope_x: float = sin(float(x)*0.47+float(y)*0.11)*0.10
            var slope_y: float = cos(float(y)*0.38+float(x)*0.05)*0.08
            var normal_vec := Vector3(slope_x,slope_y,1.0).normalized()
            normal.set_pixel(x,y,Color(normal_vec.x*0.5+0.5,normal_vec.y*0.5+0.5,normal_vec.z,1.0))
    _pbr_maps = 3
    return {
        "albedo":ImageTexture.create_from_image(albedo),
        "roughness":ImageTexture.create_from_image(rough),
        "normal":ImageTexture.create_from_image(normal)
    }

func _material(tint: Color, metal: float, roughness: float, maps: Dictionary = {}) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = metal
    m.roughness = roughness
    if not maps.is_empty():
        m.albedo_texture = maps["albedo"]
        m.roughness_texture = maps["roughness"]
        m.normal_enabled = true
        m.normal_texture = maps["normal"]
        m.normal_scale = 0.34
        m.uv1_scale = Vector3(2.0,2.0,1.0)
    return m

func _glow(color: Color, intensity: float = 1.05) -> StandardMaterial3D:
    var m := _material(color,0.06,0.32)
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = intensity
    return m

func _make_original_materials() -> void:
    var maps: Dictionary = _procedural_pbr_maps()
    _painted = _material(METAL_DARK,0.55,0.63,maps)
    _steel = _material(STEEL_WARM,0.82,0.46,maps)
    _deck = _material(CERAMIC,0.56,0.70,maps)
    _dark = _material(Color(0.053,0.075,0.089),0.38,0.78)
    _plasma = _glow(PLASMA,1.15)
    _warning = _glow(CAUTION,1.05)
    _plasma_bands.append(_plasma)
    _plasma_bands.append(_warning)

func _box(parent: Node3D, label: String, point: Vector3, size: Vector3, material: Material, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := BoxMesh.new()
    mesh.size = size
    node.mesh = mesh
    node.position = point
    node.rotation_degrees = rotation
    node.material_override = material
    parent.add_child(node)
    _mesh_count += 1
    return node

func _column(parent: Node3D, label: String, point: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 20
    node.mesh = mesh
    node.position = point
    node.material_override = material
    parent.add_child(node)
    _mesh_count += 1
    return node

func _torus(parent: Node3D, label: String, point: Vector3, radius: float, material: Material, tilt: Vector3 = Vector3(0,0,90)) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = label
    var mesh := TorusMesh.new()
    mesh.inner_radius = radius-0.14
    mesh.outer_radius = radius
    mesh.rings = 40
    mesh.ring_segments = 12
    node.mesh = mesh
    node.position = point
    node.rotation_degrees = tilt
    node.material_override = material
    parent.add_child(node)
    _mesh_count += 1
    return node

func _build_open_vault() -> void:
    # The player can see through x=+7 into a 12m-high adjoining containment
    # chamber. These static meshes do not replace the main corridor floor.
    _box(structure,"VaultFloor",Vector3(12.35,-0.48,-20.0),Vector3(12.2,0.90,26.0),_deck)
    _box(structure,"VaultCeiling",Vector3(12.35,15.15,-20.0),Vector3(12.2,0.85,26.0),_steel)
    _box(structure,"VaultFarWall",Vector3(18.5,7.2,-20.0),Vector3(0.68,15.0,26.0),_painted)
    _box(structure,"VaultNearBulkhead",Vector3(12.35,7.0,-7.2),Vector3(12.2,14.5,0.62),_painted)
    _box(structure,"VaultRearBulkhead",Vector3(12.35,7.0,-32.8),Vector3(12.2,14.5,0.62),_painted)
    for index in range(6):
        var z: float = -9.4 - float(index)*4.2
        _box(structure,"VaultHighRoofTruss_%d" % index,Vector3(12.3,14.55,z),Vector3(11.6,0.42,0.68),_steel)
        _box(structure,"VaultFarColumn_%d" % index,Vector3(18.04,7.0,z),Vector3(0.48,13.5,0.68),_steel)
        _box(structure,"VaultFarCeilingLight_%d" % index,Vector3(12.3,14.18,z),Vector3(8.7,0.09,0.15),_plasma)
    for level in [4.1,8.8,12.7]:
        _box(structure,"FarViewingDeck_%d" % int(level*10),Vector3(17.1,level,-20.5),Vector3(2.5,0.26,23.5),_deck)
        _box(structure,"DeckHandrail_%d" % int(level*10),Vector3(15.75,level+0.95,-20.5),Vector3(0.16,0.22,23.0),_steel)

func _build_guardrail() -> void:
    # Actual physics barrier at the opening. The player stays on the verified
    # mission route; viewing gaps between open-work bars preserve sightlines.
    var physics := StaticBody3D.new()
    physics.name = "AtriumSafetyBarrier"
    physics.position = Vector3(6.35,0.93,-20.1)
    structure.add_child(physics)
    var shape := CollisionShape3D.new()
    var bounds := BoxShape3D.new()
    bounds.size = Vector3(0.26,1.78,22.1)
    shape.shape = bounds
    physics.add_child(shape)
    _physical_rails += 1
    for index in range(12):
        var z: float = -9.65 - float(index)*1.85
        _box(structure,"OpenWorkGuardPost_%02d" % index,Vector3(6.40,0.90,z),Vector3(0.19,1.80,0.20),_steel)
    for h in [0.52,1.33]:
        _box(structure,"GuardrailLevel_%d" % int(h*100),Vector3(6.40,h,-20.1),Vector3(0.20,0.13,22.0),_steel)
    _box(structure,"GuardrailToeplate",Vector3(6.40,0.20,-20.1),Vector3(0.23,0.32,22.0),_painted)
    _box(structure,"GuardrailCautionStripe",Vector3(6.29,0.10,-20.1),Vector3(0.04,0.08,22.0),_warning)

func _build_monumental_core_housing() -> void:
    shield_housing = Node3D.new()
    shield_housing.name = "TwelveMeterContainmentAssembly"
    shield_housing.position = CORE_CENTER
    structure.add_child(shield_housing)
    _column(shield_housing,"CoreFoundation",Vector3(0,-6.1,0),3.9,1.2,_steel)
    _column(shield_housing,"UpperReactorCap",Vector3(0,6.1,0),3.4,1.0,_painted)
    for index in range(10):
        var angle: float = TAU*float(index)/10.0
        var radius: float = 4.15
        var brace := Node3D.new()
        brace.name = "ReactorHeatShield_%02d" % index
        brace.position = Vector3(cos(angle)*radius,0,sin(angle)*radius)
        brace.rotation.y = -angle
        shield_housing.add_child(brace)
        _box(brace,"ArmouredVerticalCassette",Vector3.ZERO,Vector3(0.64,10.5,0.62),_painted)
        for y in [-4.4,-1.6,1.6,4.4]:
            _box(brace,"ServiceCoolantDuct_%d" % int(y*10),Vector3(0.40,y,0.0),Vector3(0.13,0.55,0.52),_steel)
    for row in [-3.9,0.0,3.9]:
        _torus(shield_housing,"MachinedCircumferentialRing_%d" % int(row*10),Vector3(0,row,0),4.7,_steel,Vector3.ZERO)
        _torus(shield_housing,"PlasmaContainmentTrim_%d" % int(row*10),Vector3(0,row+0.18,0),4.95,_plasma,Vector3.ZERO)
    for rotor_index in range(3):
        var rotor := Node3D.new()
        rotor.name = "MechanicalRotor_%d" % rotor_index
        rotor.rotation_degrees = Vector3(0,0,15.0+float(rotor_index)*52.0)
        shield_housing.add_child(rotor)
        _torus(rotor,"RotorGimbal",Vector3.ZERO,5.05+float(rotor_index)*0.3,_steel,Vector3(0,0,90))
        _torus(rotor,"RotorSafetyIllumination",Vector3.ZERO,5.25+float(rotor_index)*0.3,_warning,Vector3(0,0,90))
        _mechanical_rotors.append(rotor)
    # Strong visual reading: industrial armour, pale ceramic trim and contained
    # energy core — not a wall of neon strips.
    for side in [-1.0,1.0]:
        _column(hero_details,"TallCoolantPressureVessel_%d" % int(side),Vector3(17.15,5.9,-20.5+side*8.2),0.73,10.8,_steel)
        for index in range(3):
            _torus(hero_details,"CoolantTankClamp_%d_%d" % [int(side),index],Vector3(17.15,2.5+float(index)*3.1,-20.5+side*8.2),0.92,_deck,Vector3.ZERO)

func _build_catwalk_network() -> void:
    for z in [-11.5,-29.0]:
        _box(hero_details,"SuspendedCrosswalk",Vector3(12.4,8.45,z),Vector3(11.1,0.27,1.20),_deck)
        for side in [-1.0,1.0]:
            _box(hero_details,"CrosswalkGuard",Vector3(12.4,9.05,z+side*0.53),Vector3(10.8,0.08,0.09),_steel)
            for index in range(7):
                x = 7.7+float(index)*1.54
                _box(hero_details,"CrosswalkStanchion",Vector3(x,8.94,z+side*0.53),Vector3(0.085,0.93,0.095),_steel)
    for index in range(9):
        var z: float = -10.0-float(index)*2.5
        _box(hero_details,"A7ConduitShelf_%d" % index,Vector3(18.04,2.0,z),Vector3(0.28,0.20,2.1),_painted)

func _build_machined_detail() -> void:
    var bolts: Array[Transform3D] = []
    var mesh := BoxMesh.new()
    mesh.size = Vector3(0.11,0.06,0.12)
    for index in range(72):
        var angle: float = TAU*float(index)/72.0
        for row in [-4.1,0.0,4.1]:
            var point := CORE_CENTER + Vector3(cos(angle)*4.78,row,sin(angle)*4.78)
            bolts.append(Transform3D(Basis(),point))
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = bolts.size()
    for i in range(bolts.size()):
        multi.set_instance_transform(i,bolts[i])
    var fasteners := MultiMeshInstance3D.new()
    fasteners.name = "ReactorArmourFasteners_OneDrawGroup"
    fasteners.multimesh = multi
    fasteners.material_override = _steel
    hero_details.add_child(fasteners)
    _repeated_instances = bolts.size()

func _sign(label: String, text_value: String, pos: Vector3, tint: Color, font_size: int = 50) -> void:
    var node := Label3D.new()
    node.name = label
    node.text = text_value
    node.position = pos
    node.font_size = font_size
    node.pixel_size = 0.0021
    node.modulate = tint
    structure.add_child(node)
    _signs += 1

func _build_diegetic_signs() -> void:
    # English sign labels for original in-world fictional machinery; HUD has
    # RU/EN objective text that is independent of these decorative plates.
    _box(structure,"ObservationHeaderPanel",Vector3(6.61,5.05,-20.3),Vector3(0.08,0.72,6.8),_dark)
    _sign("WarningMain","A7  /  CONTAINMENT",Vector3(6.52,5.08,-19.85),PLASMA,51)
    _sign("HighVoltage","HIGH ENERGY CORE",Vector3(6.50,4.60,-19.85),CAUTION,35)
    _box(structure,"VaultSerialPlate",Vector3(18.03,10.6,-20.0),Vector3(0.12,0.84,8.0),_painted)
    _sign("CoreSerial","A7  //  IRON PULSE",Vector3(17.92,10.55,-19.3),Color(0.78,0.87,0.88),57)

func _build_lighting() -> void:
    for spot in [Vector3(9.0,12.5,-12.0),Vector3(15.0,12.5,-20.5),Vector3(9.0,12.5,-29.0)]:
        var lamp := OmniLight3D.new()
        lamp.name = "AtriumNeutralAreaFill"
        lamp.position = spot
        lamp.light_color = Color(0.68,0.77,0.83)
        lamp.light_energy = 1.25
        lamp.omni_range = 18.5
        lamp.shadow_enabled = false
        structure.add_child(lamp)
        _lights.append(lamp)
    for side in [-1.0,1.0]:
        var warning_lamp := OmniLight3D.new()
        warning_lamp.name = "ContainmentAlarmLamp"
        warning_lamp.position = CORE_CENTER+Vector3(2.8,1.8,side*5.3)
        warning_lamp.light_color = CAUTION
        warning_lamp.light_energy = 0.36
        warning_lamp.omni_range = 11.0
        warning_lamp.shadow_enabled = false
        hero_details.add_child(warning_lamp)
        _lights.append(warning_lamp)

func set_quality(value: String) -> void:
    _quality = "eco" if value == "eco" else "hero"
    hero_details.visible = _quality == "hero"
    for index in range(_lights.size()):
        _lights[index].visible = _quality == "hero" or index == 1

func update_alarm(scenario: String, heat: float, oxygen: float, elapsed: float, reduced_motion: bool) -> void:
    # Risk changes physical warm/cold illumination and reactor glow. Reduced
    # motion disables the oscillation while keeping safety states visible.
    _hazard = maxf(clampf((heat-58.0)/42.0,0.0,1.0),clampf((60.0-oxygen)/60.0,0.0,1.0))
    var alarm_tint: Color = CAUTION if scenario == "thermal" else PLASMA if scenario == "breach" else Color(0.82,0.47,0.28)
    var pulse: float = 1.0 if reduced_motion else 0.88 + 0.12*sin(elapsed*1.6)
    _last_emissive = 0.78 + _hazard*0.72*pulse
    _warning.emission = alarm_tint
    _warning.emission_energy_multiplier = _last_emissive
    _plasma.emission_energy_multiplier = 0.78 + _hazard*0.29
    for index in range(_lights.size()):
        if index >= 3:
            _lights[index].light_color = alarm_tint
            _lights[index].light_energy = 0.30 + _hazard*0.65*pulse
    if not reduced_motion:
        for i in range(_mechanical_rotors.size()):
            _mechanical_rotors[i].rotation.x = elapsed*(0.055+float(i)*0.012)*(1.0+_hazard*0.65)*(1.0 if i%2 == 0 else -1.0)

func readout() -> Dictionary:
    return {
        "cinematic_vault":true,
        "open_wall_span_m":OPENING_Z_MAX-OPENING_Z_MIN,
        "vault_height_m":15.0,
        "core_center":[CORE_CENTER.x,CORE_CENTER.y,CORE_CENTER.z],
        "pbr_texture_maps":_pbr_maps,
        "monumental_geometry":_mesh_count,
        "physical_guardrail_colliders":_physical_rails,
        "diegetic_signs":_signs,
        "moving_rotors":_mechanical_rotors.size(),
        "instanced_fasteners":_repeated_instances,
        "real_lights":_lights.size(),
        "quality":_quality,
        "hero_visible":hero_details.visible,
        "alarm_risk":_hazard,
        "last_emissive":_last_emissive
    }
