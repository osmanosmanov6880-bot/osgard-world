extends Node3D
## BLACKFIELD Wave 8 / materials, readable physical silhouettes and controlled animation.
## The scene preserves all gameplay state, puzzle collision and magnetic simulation.

var game: Node3D
var web: bool = false
var frame_clock: float = 0.0
var patrol: Array[Node3D] = []
var signal_materials: Array[StandardMaterial3D] = []
var total_mesh_vertices: int = 0
var pooled_bolts: int = 0
var matte_steel: StandardMaterial3D
var copper: StandardMaterial3D
var graphite: StandardMaterial3D
var light_cyan: StandardMaterial3D
var light_amber: StandardMaterial3D

func configure(root_game: Node3D) -> void:
    game = root_game

func _ready() -> void:
    web = OS.has_feature("web") or RenderingServer.get_current_rendering_method() != "forward_plus"
    matte_steel = _pbr("machined_nickel", Color(0.71, 0.77, 0.79), 0.89, 0.37)
    copper = _pbr("oxide_copper", Color(0.74, 0.48, 0.32), 0.87, 0.28)
    graphite = _pbr("powder_graphite", Color(0.26, 0.32, 0.36), 0.64, 0.46)
    light_cyan = _signal(Color(0.29, 0.78, 1.0), 1.6)
    light_amber = _signal(Color(1.0, 0.55, 0.18), 1.0)
    _mount_cnc_station()
    _build_safety_infrastructure()
    _build_optical_scanners()
    _tune_presentation()
    print("OSGARD_WAVE8_VECTOR:", JSON.stringify({"unique_cnc_vertices":total_mesh_vertices,"gpu_bolts":pooled_bolts,"web_lod":web}))

func _pbr(folder: String, base: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var pbr := StandardMaterial3D.new()
    pbr.albedo_color = base
    pbr.metallic = metallic
    pbr.roughness = roughness
    pbr.diffuse_mode = BaseMaterial3D.DIFFUSE_BURLEY
    var prefix: String = "res://assets/wave8/%s/" % folder
    var albedo := load(prefix + "albedo.png") as Texture2D
    var normal := load(prefix + "normal.png") as Texture2D
    var rough := load(prefix + "roughness.png") as Texture2D
    var metal := load(prefix + "metallic.png") as Texture2D
    if albedo != null:
        pbr.albedo_texture = albedo
    if normal != null:
        pbr.normal_enabled = true
        pbr.normal_texture = normal
        pbr.normal_scale = 0.38
    if rough != null:
        pbr.roughness_texture = rough
        pbr.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    if metal != null:
        pbr.metallic_texture = metal
        pbr.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    pbr.uv1_scale = Vector3(2.0, 2.0, 1.0)
    return pbr

func _signal(color: Color, energy: float) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.roughness = 0.25
    m.emission_enabled = true
    m.emission = color
    m.emission_energy_multiplier = energy
    signal_materials.append(m)
    return m

func _box(parent: Node3D, name_tag: String, size: Vector3, pos: Vector3, material: Material) -> MeshInstance3D:
    var node := MeshInstance3D.new()
    node.name = name_tag
    var cube := BoxMesh.new()
    cube.size = size
    node.mesh = cube
    node.position = pos
    node.material_override = material
    parent.add_child(node)
    return node

func _cylinder(parent: Node3D, name_tag: String, radius: float, height: float, pos: Vector3, material: Material) -> MeshInstance3D:
    var part := MeshInstance3D.new()
    part.name = name_tag
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 12 if web else 28
    part.mesh = mesh
    part.position = pos
    part.material_override = material
    parent.add_child(part)
    return part

func _lathe(name_tag: String, profile: PackedVector2Array, segments: int, material: Material) -> MeshInstance3D:
    # Indexed manufacturing cross-section with outward-facing normals and UVs.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for p in range(profile.size()-1):
        for a in range(segments):
            var a0: float = TAU*float(a)/float(segments)
            var a1: float = TAU*float(a+1)/float(segments)
            var r0: float = profile[p].x
            var r1: float = profile[p+1].x
            var y0: float = profile[p].y
            var y1: float = profile[p+1].y
            var v00 := Vector3(cos(a0)*r0,y0,sin(a0)*r0)
            var v01 := Vector3(cos(a1)*r0,y0,sin(a1)*r0)
            var v10 := Vector3(cos(a0)*r1,y1,sin(a0)*r1)
            var v11 := Vector3(cos(a1)*r1,y1,sin(a1)*r1)
            for v in [v00,v01,v10,v10,v01,v11]:
                st.set_uv(Vector2(atan2(v.z,v.x)/TAU, v.y*0.5))
                st.add_vertex(v)
    st.generate_normals()
    st.index()
    var node := MeshInstance3D.new()
    node.name = name_tag
    node.mesh = st.commit()
    node.material_override = material
    if node.mesh != null:
        total_mesh_vertices += node.mesh.surface_get_array_len(0)
    return node

func _mount_cnc_station() -> void:
    var stage := Node3D.new()
    stage.name = "Wave8MachinedContaminment"
    add_child(stage)
    # Two visible, unique large-scale pressure vessels behind the main physics arena.
    for side in [-1,1]:
        var stem := Node3D.new()
        stem.name = "CoolingManifold_%s" % ("Left" if side<0 else "Right")
        stem.position = Vector3(float(side)*10.5, 0, -3.9)
        stage.add_child(stem)
        _box(stem,"CompartmentPodium",Vector3(2.15,0.52,2.3),Vector3(0,0.31,0),graphite)
        var profile := PackedVector2Array([
            Vector2(0.76,0.65), Vector2(0.86,0.72),Vector2(0.87,0.93),
            Vector2(0.73,1.02),Vector2(0.75,2.20),Vector2(1.00,2.36),
            Vector2(1.00,2.60),Vector2(0.77,2.76),Vector2(0.72,4.12),
            Vector2(0.96,4.20),Vector2(0.96,4.43),Vector2(0.77,4.54),
            Vector2(0.70,5.02),Vector2(0.40,5.19)])
        stem.add_child(_lathe("CNC_PressureShell",profile,18 if web else 54,matte_steel))
        for y in [1.0,2.5,4.25]:
            _cylinder(stem,"ForgedFlange",1.06,0.14,Vector3(0,y,0),copper)
        _box(stem,"ThermalPanel",Vector3(1.19,0.68,0.07),Vector3(0,3.18,0.79),graphite)
        _box(stem,"StatusEmblem",Vector3(0.83,0.11,0.09),Vector3(0,3.27,0.85),light_cyan)
        for offset in [-0.48,0.48]:
            _cylinder(stem,"HighPressureTube",0.11,4.04,Vector3(offset,3.28,1.01),copper)
        var rotor := Node3D.new()
        rotor.name = "PressureActuatorRotor"
        rotor.position=Vector3(0,5.2,0)
        stem.add_child(rotor)
        _cylinder(rotor,"AlloyActuatorRotor",0.65,0.3,Vector3.ZERO,graphite)
        for arm in range(8):
            var arm_part := _box(rotor,"MachinedRadialFin",Vector3(0.11,0.15,1.05),Vector3(0,0,0.41),matte_steel)
            arm_part.rotation.y = float(arm)*TAU/8
        patrol.append(rotor)
    # Clamp bolts use one shared indexed geometry + MultiMesh, not many draw calls.
    var screw := CylinderMesh.new()
    screw.top_radius = 0.075
    screw.bottom_radius = 0.075
    screw.height = 0.15
    screw.radial_segments = 8
    var screws := MultiMesh.new()
    screws.transform_format = MultiMesh.TRANSFORM_3D
    screws.mesh = screw
    screws.instance_count = 144 if web else 288
    pooled_bolts=screws.instance_count
    for n in range(screws.instance_count):
        var angle: float = float(n%24)*TAU/24
        var row: float = float(n/24)
        var xside: float = -10.5 if n < screws.instance_count/2 else 10.5
        var height: float = 1.0+fmod(row,12.0)*0.33
        var pos := Vector3(xside+cos(angle)*1.01,height,-3.9+sin(angle)*1.01)
        screws.set_instance_transform(n, Transform3D(Basis(),pos))
    var inst := MultiMeshInstance3D.new()
    inst.name="CNCInstancedFasteners"
    inst.multimesh=screws
    inst.material_override=matte_steel
    stage.add_child(inst)

func _build_safety_infrastructure() -> void:
    var catwalk := Node3D.new()
    catwalk.name = "Wave8StructuralCatwalk"
    add_child(catwalk)
    # The camera sees a working facility: support frames, cable trunk and hazard lamps.
    for side in [-1.0,1.0]:
        var x: float=side*12.20
        _box(catwalk,"CNCStructuralRail",Vector3(0.19,7.8,0.4),Vector3(x,4.4,2.45),matte_steel)
        _box(catwalk,"CeramicPowerDuct",Vector3(0.42,0.32,11.2),Vector3(x,9.16,-1.6),graphite)
        for z in [-6.0,-3.0,0.0,3.0]:
            _box(catwalk,"CastSteelTransverseBrace",Vector3(1.05,0.10,0.17),Vector3(x-side*0.50,7.8,z),matte_steel)
            _box(catwalk,"WarmSafetyBeacon",Vector3(0.32,0.12,0.14),Vector3(x-side*0.33,7.92,z),light_amber)

func _build_optical_scanners() -> void:
    var opt := Node3D.new()
    opt.name = "Wave8SafetyTelemetry"
    add_child(opt)
    for side in [-1.0,1.0]:
        var arm := Node3D.new()
        arm.name="ScanningBridge_%s" % ("Left" if side < 0.0 else "Right")
        arm.position=Vector3(side*8.15,7.85,-1.1)
        opt.add_child(arm)
        _box(arm,"StainlessAxis",Vector3(0.6,0.24,1.8),Vector3.ZERO,matte_steel)
        _box(arm,"PhotometricSensor",Vector3(0.36,0.16,0.4),Vector3(0,-0.18,0.75),light_cyan)
        patrol.append(arm)
    var accent:=SpotLight3D.new()
    accent.name="SafetyInspectionKey"
    accent.position=Vector3(1.0,11.3,5.9)
    accent.light_color=Color(1.0,0.74,0.54)
    accent.light_energy=1.05
    accent.spot_range=14.0
    accent.spot_angle=52.0
    accent.shadow_enabled=not web
    opt.add_child(accent)
    accent.look_at(Vector3(0,3.0,-2.0))

func _tune_presentation() -> void:
    var world := game.get_node_or_null("CinematicEnvironment") as WorldEnvironment
    if world == null or world.environment == null:
        return
    var env := world.environment
    env.adjustment_enabled=true
    env.adjustment_contrast=1.045
    env.adjustment_saturation=0.99
    env.glow_intensity=0.19 if web else 0.23
    env.fog_density=0.0022 if web else 0.0028
    # SSR/SSIL/SSAO remain controlled by the quality profile and Forward+ capability.

func _process(delta: float) -> void:
    frame_clock+=minf(delta,0.12)
    for i in range(patrol.size()):
        var rotor: Node3D=patrol[i]
        if i<2:
            rotor.rotation.y=frame_clock*0.48*(1.0 if i%2==0 else -1.0)
        else:
            rotor.rotation.z=sin(frame_clock*0.63+float(i))*0.15
    var phase: float=0.55+0.45*sin(frame_clock*2.1)
    light_amber.emission_energy_multiplier=0.65+0.6*phase
