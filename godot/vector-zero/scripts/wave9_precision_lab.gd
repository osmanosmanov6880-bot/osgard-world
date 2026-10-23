extends Node3D
## WAVE 9 — BLACKFIELD precision installation.
## All art is physically modeled, LOD-aware and never touches magnetic simulation.
## Individual animated assemblies remain separate; repeated fasteners are GPU-instanced.

var game: Node3D
var web: bool = false
var seconds: float = 0.0
var actuator_pivots: Array[Node3D] = []
var warning_material: StandardMaterial3D
var phase_lamp: OmniLight3D
var cable_vertices: int = 0
var bolt_count: int = 0
var material_count: int = 0

func configure(origin: Node3D) -> void:
    game = origin

func _ready() -> void:
    web = OS.has_feature("web") or RenderingServer.get_current_rendering_method() != "forward_plus"
    var brushed := _pbr("machined_nickel", Color(0.70, 0.75, 0.77), 0.85, 0.38)
    var oxidized := _pbr("oxide_copper", Color(0.78, 0.50, 0.31), 0.83, 0.30)
    var ceramic := _pbr("powder_graphite", Color(0.22, 0.28, 0.32), 0.62, 0.52)
    warning_material = _emission(Color(1.0, 0.59, 0.20), 0.72)
    material_count = 4
    _hero_electromagnet(brushed, oxidized, ceramic)
    _cable_and_pump_systems(brushed, oxidized, ceramic)
    _kinetic_warning_system(ceramic)
    _tune_environment()
    print("OSGARD_WAVE9_VECTOR:", JSON.stringify({"lod_web":web,"precision_cable_vertices":cable_vertices,"gpu_fasteners":bolt_count,"pbr_materials":material_count}))

func _pbr(folder: String, tint: Color, metal: float, rough: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.metallic = metal
    m.roughness = rough
    m.uv1_scale = Vector3(2.0, 2.0, 1.0)
    var base := "res://assets/wave8/%s/" % folder
    var a := load(base + "albedo.png") as Texture2D
    var n := load(base + "normal.png") as Texture2D
    var r := load(base + "roughness.png") as Texture2D
    var mt := load(base + "metallic.png") as Texture2D
    if a != null:
        m.albedo_texture = a
    if n != null:
        m.normal_enabled = true
        m.normal_texture = n
        m.normal_scale = 0.27
    if r != null:
        m.roughness_texture = r
        m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    if mt != null:
        m.metallic_texture = mt
        m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    return m

func _emission(tint: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = tint
    m.roughness = 0.28
    m.emission_enabled = true
    m.emission = tint
    m.emission_energy_multiplier = energy
    return m

func _box(parent: Node3D, label: String, size: Vector3, position: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var item := MeshInstance3D.new()
    item.name = label
    item.mesh = mesh
    item.position = position
    item.material_override = mat
    parent.add_child(item)
    return item

func _ring(parent: Node3D, label: String, inside: float, outside: float, position: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := TorusMesh.new()
    mesh.inner_radius = inside
    mesh.outer_radius = outside
    mesh.rings = 32 if web else 80
    mesh.ring_segments = 10 if web else 20
    var item := MeshInstance3D.new()
    item.name = label
    item.mesh = mesh
    item.position = position
    item.material_override = mat
    item.rotation.x = PI * 0.5
    parent.add_child(item)
    return item

func _tube(points: PackedVector3Array, radius: float, segments: int, material: Material, parent: Node3D, label: String) -> MeshInstance3D:
    var builder := SurfaceTool.new()
    builder.begin(Mesh.PRIMITIVE_TRIANGLES)
    for k in range(points.size() - 1):
        var p0: Vector3 = points[k]
        var p1: Vector3 = points[k+1]
        var forward: Vector3 = (p1 - p0).normalized()
        var reference := Vector3.FORWARD if absf(forward.dot(Vector3.FORWARD)) < 0.92 else Vector3.RIGHT
        var normal: Vector3 = forward.cross(reference).normalized()
        var binormal: Vector3 = forward.cross(normal).normalized()
        for side in range(segments):
            var a: float = TAU * float(side) / float(segments)
            var b: float = TAU * float(side+1) / float(segments)
            var ca: Vector3 = normal * cos(a) * radius + binormal * sin(a) * radius
            var cb: Vector3 = normal * cos(b) * radius + binormal * sin(b) * radius
            var vertices := [p0+ca,p0+cb,p1+ca,p1+ca,p0+cb,p1+cb]
            for v in vertices:
                builder.set_uv(Vector2(float(side) / float(segments), float(k) / 8.0))
                builder.add_vertex(v)
    builder.generate_normals()
    builder.index()
    var instance := MeshInstance3D.new()
    instance.name = label
    instance.mesh = builder.commit()
    instance.material_override = material
    parent.add_child(instance)
    if instance.mesh != null:
        cable_vertices += instance.mesh.surface_get_array_len(0)
    return instance

func _hero_electromagnet(steel: Material, copper: Material, graphite: Material) -> void:
    var magnet := game.get_node_or_null("MagnetAssembly") as Node3D
    if magnet == null:
        return
    var assembly := Node3D.new()
    assembly.name = "Wave9PrecisionMagneticCircuit"
    magnet.add_child(assembly)
    _ring(assembly,"ForgedContainmentCrown",3.35,3.68,Vector3(0,0,0.14),steel)
    _ring(assembly,"CopperInductionReturn",3.08,3.18,Vector3(0,0,-0.06),copper)
    _ring(assembly,"GraphiteSafetyLiner",3.20,3.30,Vector3(0,0,0.20),graphite)
    # Helical copper channels are actual indexed tube surfaces (not particle trails).
    var samples: int = 140 if web else 320
    var points := PackedVector3Array()
    for i in range(samples+1):
        var t: float = float(i) / float(samples)
        var angle: float = t * TAU * 8.0
        points.append(Vector3(cos(angle)*2.80, -2.08+4.16*t, sin(angle)*2.80))
    _tube(points,0.065,7 if web else 12,copper,assembly,"HelicalCopperBusbar")
    # Low-draw-call individually readable steel clamps.
    var bolt := BoxMesh.new()
    bolt.size = Vector3(0.22,0.27,0.35)
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = bolt
    mm.instance_count = 48 if web else 96
    bolt_count += mm.instance_count
    for j in range(mm.instance_count):
        var a: float = TAU*float(j%24)/24.0
        var z: float = -0.18 if int(j/24) % 2 == 0 else 0.39
        var basis := Basis(Vector3(0,0,1),a)
        mm.set_instance_transform(j,Transform3D(basis,Vector3(cos(a)*3.51,sin(a)*3.51,z)))
    var inst := MultiMeshInstance3D.new()
    inst.name = "GPUForgedCrownClamps"
    inst.multimesh = mm
    inst.material_override = graphite
    assembly.add_child(inst)
    # Service actuators remain animated as separate mechanical assemblies.
    for side in [-1.0,1.0]:
        var pivot := Node3D.new()
        pivot.name = "ServoJaw_Left" if side < 0 else "ServoJaw_Right"
        pivot.position = Vector3(side*3.72,-0.25,0.24)
        assembly.add_child(pivot)
        _box(pivot,"JawPivot",Vector3(0.51,1.38,0.42),Vector3.ZERO,steel)
        _box(pivot,"JawCopperContact",Vector3(0.18,0.82,0.28),Vector3(-side*0.33,0,0.03),copper)
        _box(pivot,"CeramicInsulator",Vector3(0.31,0.14,0.40),Vector3(0,0.61,0),graphite)
        actuator_pivots.append(pivot)

func _cable_and_pump_systems(steel: Material, copper: Material, graphite: Material) -> void:
    var infrastructure := Node3D.new()
    infrastructure.name = "Wave9HeavyEngineeringDeck"
    add_child(infrastructure)
    # Physical silhouettes at the side walls, behind the core flight path.
    for side in [-1.0,1.0]:
        var s: float = side
        var tower := Node3D.new()
        tower.name = "HydraulicStand_Left" if s < 0 else "HydraulicStand_Right"
        tower.position = Vector3(s*11.7,0,-1.3)
        infrastructure.add_child(tower)
        _box(tower,"CastAlloyPlinth",Vector3(1.75,0.44,2.20),Vector3(0,0.30,0),graphite)
        _box(tower,"UpperServiceBracket",Vector3(1.6,0.38,1.7),Vector3(0,5.92,0),steel)
        for x in [-0.56,0.56]:
            var chamber := CylinderMesh.new()
            chamber.top_radius = 0.25
            chamber.bottom_radius = 0.33
            chamber.height = 4.5
            chamber.radial_segments = 12 if web else 32
            var vessel := MeshInstance3D.new()
            vessel.name="ElectrohydraulicReservoir"
            vessel.mesh = chamber
            vessel.position = Vector3(x,3.21,0)
            vessel.material_override = steel
            tower.add_child(vessel)
        var path := PackedVector3Array()
        for j in range(29 if web else 79):
            var t: float = float(j)/float(28 if web else 78)
            path.append(Vector3(s*11.7 + (1.7*t),4.8 + 1.35*sin(PI*t),-1.0-6.5*t))
        _tube(path,0.105,7 if web else 12,copper,infrastructure,"FlexibleIndustrialHose")
        for h in [1.2,2.9,4.6]:
            _box(tower,"StampedShroud",Vector3(1.88,0.08,0.45),Vector3(0,h,0.75),graphite)
    # High voltage warning strips: bright accents on otherwise neutral PBR surfaces.
    for side in [-1.0,1.0]:
        _box(infrastructure,"SafetyStrip",Vector3(0.10,0.13,9.6),Vector3(side*12.05,6.3,0.0),warning_material)

func _kinetic_warning_system(graphite: Material) -> void:
    var rig := Node3D.new()
    rig.name="Wave9InspectionLighting"
    add_child(rig)
    var housing := _box(rig,"WarningEmitterHousing",Vector3(0.82,0.34,0.70),Vector3(0,10.4,2.2),graphite)
    housing.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    phase_lamp = OmniLight3D.new()
    phase_lamp.name="PolarityReactiveAmberFill"
    phase_lamp.position = Vector3(0,9.7,2.2)
    phase_lamp.light_color = Color(1.0,0.54,0.23)
    phase_lamp.omni_range = 9.0
    phase_lamp.light_energy = 0.35 if web else 0.58
    phase_lamp.shadow_enabled = false
    rig.add_child(phase_lamp)

func _tune_environment() -> void:
    var world := game.get_node_or_null("CinematicEnvironment") as WorldEnvironment
    if world == null or world.environment == null:
        return
    var env := world.environment
    # Avoid harsh overexposure; advanced screen-space effects are Forward+ only.
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.040
    env.adjustment_saturation = 0.96
    env.glow_intensity = 0.145 if web else 0.21
    env.fog_density = 0.0018 if web else 0.0023

func _process(delta: float) -> void:
    seconds += minf(delta,0.10)
    var polarity: int = 1
    if game != null:
        polarity = int(game.get("polarity"))
    for i in range(actuator_pivots.size()):
        var pivot := actuator_pivots[i]
        var direction: float = -1.0 if i == 0 else 1.0
        pivot.rotation.z = direction * (0.045 + 0.09*sin(seconds*1.8)) * float(polarity)
    var pulse: float = 0.72 + 0.28*sin(seconds*2.2)
    if warning_material != null:
        warning_material.emission_energy_multiplier = pulse * (0.95 if polarity > 0 else 1.30)
    if phase_lamp != null:
        phase_lamp.light_energy = pulse * (0.28 if web else 0.50)
