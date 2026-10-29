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
var director_camera: Camera3D
var director_shots: Array[Camera3D] = []
var director_shot_index: int = 0
var core_plasma_material: ShaderMaterial
var _plasma_phase: float = 0.0
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
    _create_plasma_material()
    _build_open_vault()
    _build_guardrail()
    _build_monumental_core_housing()
    _build_catwalk_network()
    _build_machined_detail()
    _build_diegetic_signs()
    _build_lighting()
    _build_director_camera()
    set_quality("hero")

func _create_plasma_material() -> void:
    # The existing playable reactor sphere receives a real runtime shader,
    # not a prerendered sprite/video or an external borrowed VFX asset.
    # All inputs are bounded and driven by live reactor temperature and oxygen.
    var shader := Shader.new()
    shader.code = """
shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float crisis : hint_range(0.0, 1.0) = 0.0;
uniform float thermal_bias : hint_range(0.0, 1.0) = 0.15;
uniform float motion_clock = 0.0;
void fragment() {
    vec2 uv = UV * vec2(4.0, 5.5);
    float t = motion_clock;
    float turbulence = sin(uv.x * 6.0 + t * 2.4 + sin(uv.y * 2.2 - t) * 1.7);
    float strata = sin(uv.y * 13.0 - t * 3.5 + sin(uv.x * 2.8 + t) * 3.0);
    float vein = smoothstep(0.42, 0.94, turbulence * 0.5 + 0.5);
    float sweep = smoothstep(0.33, 0.96, strata * 0.5 + 0.5);
    float facing = clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0);
    float fresnel = pow(1.0 - facing, 2.1);
    vec3 cold = vec3(0.06, 0.76, 0.98);
    vec3 hot = vec3(1.0, 0.35, 0.09);
    vec3 tone = mix(cold, hot, thermal_bias);
    float electric = pow(clamp(vein * 0.78 + sweep * 0.38, 0.0, 1.0), 4.0);
    vec3 white_hot = mix(vec3(0.73, 0.96, 1.0), vec3(1.0, 0.83, 0.55), thermal_bias);
    vec3 ion = mix(tone, white_hot, electric * 0.70);
    float light = 0.58 + vein * 0.75 + sweep * 0.62 + fresnel * 0.70;
    // GL Compatibility/WebGL can under-expose procedural EMISSION.
    // Bright local albedo filaments ensure the actual energy core is
    // visible even without HDR tonemapping or a fake bloom overlay.
    ALBEDO = mix(ion * 0.55, white_hot, electric * 0.78);
    EMISSION = ion * light * (2.12 + crisis * 1.30);
}
"""
    core_plasma_material = ShaderMaterial.new()
    core_plasma_material.shader = shader
    core_plasma_material.set_shader_parameter("crisis",0.0)
    core_plasma_material.set_shader_parameter("thermal_bias",0.15)
    core_plasma_material.set_shader_parameter("motion_clock",0.0)

func _build_director_camera() -> void:
    # Real diegetic security camera mounted inside the actual reactor
    # observation gallery. The user's physical player remains in place.
    director_camera = Camera3D.new()
    director_camera.name = "A7_ServiceObservationCamera"
    director_camera.position = Vector3(2.45,4.20,-20.25)
    director_camera.fov = 75.0
    director_camera.near = 0.08
    director_camera.far = 150.0
    add_child(director_camera)
    director_camera.look_at(CORE_CENTER+Vector3(0.0,-0.15,0.0),Vector3.UP)
    director_camera.current = false
    director_shots.append(director_camera)
    # V12: three truly independent Godot cameras in the same real 3D world.
    # No pre-rendered plates, animation files or gameplay teleports.
    var side_view := Camera3D.new()
    side_view.name = "A7_TurbineSideCamera"
    side_view.position = Vector3(16.55,9.35,-12.1)
    side_view.fov = 70.0
    side_view.near = 0.08
    add_child(side_view)
    side_view.look_at(CORE_CENTER,Vector3.UP)
    side_view.current = false
    director_shots.append(side_view)
    var high_view := Camera3D.new()
    high_view.name = "A7_UpperCatwalkCamera"
    high_view.position = Vector3(7.30,11.50,-27.5)
    high_view.fov = 74.0
    high_view.near = 0.08
    add_child(high_view)
    high_view.look_at(CORE_CENTER,Vector3.UP)
    high_view.current = false
    director_shots.append(high_view)

func reset_director_shots() -> void:
    director_shot_index = 0
    if director_camera != null:
        director_camera.make_current()

func cycle_director_shot() -> String:
    if director_shots.is_empty():
        return ""
    director_shot_index = (director_shot_index+1)%director_shots.size()
    director_shots[director_shot_index].make_current()
    return director_shots[director_shot_index].name

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
    # Thin luminous conductors avoid giant cyan foreground bars; load-bearing
    # steel containment rings retain their original industrial profile.
    var strip: float = 0.055 if material == _plasma or material == _warning else 0.14
    mesh.inner_radius = radius-strip
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

func _tapered_armor_panel(panel_index: int) -> void:
    # Bespoke curved, UV-mapped armour: this is an authored mesh, not a box
    # scaled to imitate a cinematic 12m reactor module.
    var plate := SurfaceTool.new()
    plate.begin(Mesh.PRIMITIVE_TRIANGLES)
    var slice_count: int = 8
    var center_angle: float = TAU*float(panel_index)/12.0
    var half_arc: float = 0.205
    var lower: float = -4.5 + 0.14*float(panel_index%3)
    var upper: float = 4.4 - 0.16*float(panel_index%2)
    var rad: float = 4.57
    for slice in range(slice_count):
        var a0: float = center_angle-half_arc+2.0*half_arc*float(slice)/float(slice_count)
        var a1: float = center_angle-half_arc+2.0*half_arc*float(slice+1)/float(slice_count)
        var front0 := Vector3(cos(a0)*rad,lower,sin(a0)*rad)
        var front1 := Vector3(cos(a0)*rad,upper,sin(a0)*rad)
        var front2 := Vector3(cos(a1)*rad,lower,sin(a1)*rad)
        var front3 := Vector3(cos(a1)*rad,upper,sin(a1)*rad)
        var u0: float = float(slice)/float(slice_count)
        var u1: float = float(slice+1)/float(slice_count)
        for vertex in [
            [front0,Vector2(u0,0.0)],
            [front1,Vector2(u0,3.0)],
            [front2,Vector2(u1,0.0)],
            [front2,Vector2(u1,0.0)],
            [front1,Vector2(u0,3.0)],
            [front3,Vector2(u1,3.0)]
        ]:
            plate.set_uv(vertex[1])
            plate.add_vertex(vertex[0])
    plate.generate_normals()
    var mesh: ArrayMesh = plate.commit()
    var shell := MeshInstance3D.new()
    shell.name = "CustomUV_ArmourCassette_%02d" % panel_index
    shell.mesh = mesh
    shell.material_override = _painted
    shield_housing.add_child(shell)
    _mesh_count += 1

func _build_monumental_core_housing() -> void:
    shield_housing = Node3D.new()
    shield_housing.name = "TwelveMeterContainmentAssembly"
    shield_housing.position = CORE_CENTER
    structure.add_child(shield_housing)
    _column(shield_housing,"CoreFoundation",Vector3(0,-6.1,0),3.9,1.2,_steel)
    _column(shield_housing,"UpperReactorCap",Vector3(0,6.1,0),3.4,1.0,_painted)
    # Open a camera-facing service throat of roughly 100 degrees. The
    # old front armour obstructed the LIVE plasma sphere completely. Side
    # and rear armoured cassettes preserve weight and containment machinery.
    for panel_index in range(12):
        if panel_index % 3 != 1 and panel_index not in [5,6,7]:
            _tapered_armor_panel(panel_index)
    for index in range(10):
        if index in [4,5,6]:
            continue
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
        # The old 15/67/119-degree Z roll made two giant rings edge-on to
        # the A7 observation camera, creating the stubborn vertical cyan bar.
        # Small interleaved Y/Z tilts preserve mechanical scale and depth.
        rotor.rotation_degrees = Vector3(0.0,float(rotor_index)*12.0,-16.0+float(rotor_index)*16.0)
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
                var x: float = 7.7+float(index)*1.54
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
    node.rotation_degrees.y = -90.0
    node.font_size = font_size
    node.pixel_size = 0.0021
    node.modulate = tint
    structure.add_child(node)
    _signs += 1

func _build_diegetic_signs() -> void:
    # English sign labels for original in-world fictional machinery; HUD has
    # RU/EN objective text that is independent of these decorative plates.
    # Previously this sign slab physically intercepted the camera-to-core
    # ray. Raise it above the observation sightline instead.
    # Shift the sign board to the far retaining wall. Front-portal signage
    # was covering the plasma sphere in actual Chromium art screenshots.
    _box(structure,"ObservationHeaderPanel",Vector3(17.93,13.1,-20.3),Vector3(0.14,0.72,6.8),_dark)
    _sign("WarningMain","A7  /  CONTAINMENT",Vector3(17.82,13.14,-19.85),PLASMA,51)
    _sign("HighVoltage","HIGH ENERGY CORE",Vector3(17.80,12.65,-19.85),CAUTION,35)
    _box(structure,"VaultSerialPlate",Vector3(18.03,10.6,-20.0),Vector3(0.12,0.84,8.0),_painted)
    _sign("CoreSerial","A7  //  IRON PULSE",Vector3(17.92,10.55,-19.3),Color(0.78,0.87,0.88),57)

func _build_lighting() -> void:
    for spot in [Vector3(9.0,12.5,-12.0),Vector3(7.35,8.2,-20.5),Vector3(9.0,12.5,-29.0)]:
        var lamp := OmniLight3D.new()
        lamp.name = "AtriumNeutralAreaFill"
        lamp.position = spot
        lamp.light_color = Color(0.66,0.79,0.86)
        # The ECO-safe middle lamp actually illuminates the front reactor
        # armour, rather than sitting hidden behind its silhouette.
        lamp.light_energy = 2.05 if absf(spot.z+20.5)<0.1 else 1.20
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
    # An authored plasma material responds to the SAME GAME simulation
    # rather than animating a fixed decorative effect.
    if core_plasma_material != null:
        var thermal_bias: float = 1.0 if scenario == "thermal" else 0.12 if scenario == "blackout" else 0.0
        core_plasma_material.set_shader_parameter("crisis",_hazard)
        core_plasma_material.set_shader_parameter("thermal_bias",thermal_bias)
        if not reduced_motion:
            _plasma_phase = elapsed*0.65
        core_plasma_material.set_shader_parameter("motion_clock",_plasma_phase)
    for index in range(_lights.size()):
        if index >= 3:
            _lights[index].light_color = alarm_tint
            _lights[index].light_energy = 0.30 + _hazard*0.65*pulse
    if not reduced_motion:
        for i in range(_mechanical_rotors.size()):
            _mechanical_rotors[i].rotation.x = elapsed*(0.055+float(i)*0.012)*(1.0+_hazard*0.65)*(1.0 if i%2 == 0 else -1.0)

func readout() -> Dictionary:
    var rotor_alignment: float = 1.0
    if director_camera != null:
        for rotor in _mechanical_rotors:
            var rim: MeshInstance3D = rotor.get_node("RotorSafetyIllumination") as MeshInstance3D
            var normal: Vector3 = (rim.global_transform.basis*Vector3.UP).normalized()
            var eye: Vector3 = (director_camera.global_position-rim.global_position).normalized()
            rotor_alignment = minf(rotor_alignment,absf(normal.dot(eye)))
    return {
        "rotor_camera_alignment_min":rotor_alignment,
        "cinematic_vault":true,
        "security_director_camera":director_camera != null,
        "director_shot_count":director_shots.size(),
        "director_shot_index":director_shot_index,
        "security_camera_position":[director_camera.global_position.x,director_camera.global_position.y,director_camera.global_position.z] if director_camera != null else [],
        "plasma_shader_live":core_plasma_material != null,
        "open_core_inspection":shield_housing != null and shield_housing.get_node_or_null("ReactorHeatShield_05") == null and shield_housing.get_node_or_null("CustomUV_ArmourCassette_06") == null,
        "plasma_phase":_plasma_phase,
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
