extends Node3D
## CHRONOS WAVE 8: connected landfall, physical mobility, PBR civic infrastructure.
## All economy/building/save systems in chrono_city.gd are preserved unmodified.

var game: Node3D
var web: bool = false
var t: float = 0.0
var trains: Array[Node3D] = []
var bridge_lights: Array[MeshInstance3D] = []
var supports: int = 0
var rail_units: int = 0
var material_map: Dictionary = {}

func configure(origin: Node3D) -> void:
    game=origin

func _ready() -> void:
    web=OS.has_feature("web") or RenderingServer.get_current_rendering_method() != "forward_plus"
    material_map={
        "titanium":_pbr("architectural_titanium",Color(0.76,0.85,0.89),0.8,0.31),
        "concrete":_pbr("sea_wall_concrete",Color(0.72,0.76,0.72),0.07,0.83),
        "bronze":_pbr("patinated_bronze",Color(0.76,0.70,0.57),0.77,0.42),
        "glazing":_solid(Color(0.16,0.45,0.58),0.38,0.19,0.28),
        "signal":_solid(Color(0.88,0.73,0.48),0.1,0.27,0.95)
    }
    _build_continental_link()
    _build_mobility_transit()
    _build_civic_infrastructure()
    _finish_color_pipeline()
    print("OSGARD_WAVE8_EMPIRE:",JSON.stringify({"bridge_supports":supports,"instanced_rail_parts":rail_units,"animated_cars":trains.size(),"web_lod":web}))

func _pbr(subfolder: String, tint: Color, metallic: float, roughness: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color=tint
    mat.metallic=metallic
    mat.roughness=roughness
    var prefix: String="res://assets/wave8/%s/"%subfolder
    var albedo:=load(prefix+"albedo.png") as Texture2D
    var normal:=load(prefix+"normal.png") as Texture2D
    var rough:=load(prefix+"roughness.png") as Texture2D
    var metal:=load(prefix+"metallic.png") as Texture2D
    if albedo!=null:
        mat.albedo_texture=albedo
    if normal!=null:
        mat.normal_enabled=true
        mat.normal_texture=normal
        mat.normal_scale=0.33
    if rough!=null:
        mat.roughness_texture=rough
        mat.roughness_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
    if metal!=null:
        mat.metallic_texture=metal
        mat.metallic_texture_channel=BaseMaterial3D.TEXTURE_CHANNEL_RED
    mat.uv1_scale=Vector3(2.2,2.2,1.0)
    return mat

func _solid(tint: Color, metal: float, rough: float, emissive: float=0.0) -> StandardMaterial3D:
    var mat:=StandardMaterial3D.new()
    mat.albedo_color=tint
    mat.metallic=metal
    mat.roughness=rough
    if emissive>0.0:
        mat.emission_enabled=true
        mat.emission=tint
        mat.emission_energy_multiplier=emissive
    return mat

func _box(parent: Node3D, id: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var part:=MeshInstance3D.new()
    part.name=id
    var box:=BoxMesh.new()
    box.size=size
    part.mesh=box
    part.position=pos
    part.material_override=mat
    parent.add_child(part)
    return part

func _column(parent: Node3D,id:String,radius:float,height:float,pos:Vector3,mat:Material)->MeshInstance3D:
    var c:=MeshInstance3D.new()
    c.name=id
    var mesh:=CylinderMesh.new()
    mesh.top_radius=radius
    mesh.bottom_radius=radius
    mesh.height=height
    mesh.radial_segments=12 if web else 28
    c.mesh=mesh
    c.position=pos
    c.material_override=mat
    parent.add_child(c)
    return c

func _build_continental_link() -> void:
    # Landfall is behind the city along -Z. Wave 7 land is approx. z=-82.
    # Road height is above sea level; each support is physically anchored.
    var bridge:=Node3D.new()
    bridge.name="Wave8PhysicalLandfall"
    add_child(bridge)
    var concrete:Material=material_map["concrete"]
    var steel:Material=material_map["titanium"]
    var bronze:Material=material_map["bronze"]
    _box(bridge,"CityGatePortal",Vector3(9.2,1.15,1.8),Vector3(-7,0.0,-30.0),concrete)
    _box(bridge,"ContinentalCausewayDeck",Vector3(8.1,0.65,60.0),Vector3(-7,0.22,-59.5),concrete)
    _box(bridge,"TramTrackMedian",Vector3(2.2,0.25,60.0),Vector3(-7,0.65,-59.5),bronze)
    for x in [-9.55,-4.45]:
        _box(bridge,"GuardBarrier",Vector3(0.25,0.86,60.0),Vector3(x,1.1,-59.5),steel)
        _box(bridge,"CableHousing",Vector3(0.09,0.08,60.0),Vector3(x,1.50,-59.5),material_map["signal"])
    for z in [-32.5,-41.0,-49.5,-58.0,-66.5,-75.0,-83.5]:
        # 7 bridge piers, direct structural connection to sea bed.
        _box(bridge,"FoundationPileHead",Vector3(7.2,0.80,1.30),Vector3(-7,-0.8,z),steel)
        for x in [-9.45,-4.55]:
            _column(bridge,"PileDrivenToSeabed",0.41,8.0,Vector3(x,-4.85,z),concrete)
            supports+=1
    # Access portals at both ends make the direction of travel unmistakable.
    for z in [-29.0,-89.0]:
        _box(bridge,"TransitCheckpointHeader",Vector3(8.4,0.39,0.55),Vector3(-7,4.65,z),steel)
        for x in [-10.7,-3.3]:
            _box(bridge,"CheckpointPost",Vector3(0.32,4.45,0.42),Vector3(x,2.32,z),bronze)
        _box(bridge,"CheckpointStatus",Vector3(3.2,0.13,0.15),Vector3(-7,4.48,z+0.39),material_map["glazing"])

func _build_mobility_transit() -> void:
    var system:=Node3D.new()
    system.name="Wave8ActiveMonorail"
    add_child(system)
    # GPU instancing for track fasteners and sleepers; gameplay scene stays responsive.
    var fastener_mesh:=BoxMesh.new()
    fastener_mesh.size=Vector3(2.22,0.09,0.30)
    var multi:=MultiMesh.new()
    multi.transform_format=MultiMesh.TRANSFORM_3D
    multi.mesh=fastener_mesh
    multi.instance_count=90 if web else 180
    rail_units=multi.instance_count
    for i in range(rail_units):
        var z=-30.0-60.0*float(i)/float(maxi(rail_units-1,1))
        multi.set_instance_transform(i,Transform3D(Basis(),Vector3(-7,0.84,z)))
    var sleepers:=MultiMeshInstance3D.new()
    sleepers.name="GPUTrackSleepers"
    sleepers.multimesh=multi
    sleepers.material_override=material_map["titanium"]
    system.add_child(sleepers)
    for k in range(3):
        var car:=Node3D.new()
        car.name="AutonomousTram_%02d"%k
        system.add_child(car)
        _box(car,"AeroAlloyBody",Vector3(1.56,0.85,3.7),Vector3(0,1.2,0),material_map["titanium"])
        _box(car,"PanoramicGlass",Vector3(1.4,0.48,2.35),Vector3(0,1.68,0),material_map["glazing"])
        _box(car,"ArticulatedUnderframe",Vector3(1.08,0.19,3.1),Vector3(0,0.68,0),material_map["bronze"])
        _box(car,"NavigationLight",Vector3(0.83,0.12,0.11),Vector3(0,1.31,-1.9),material_map["signal"])
        trains.append(car)

func _build_civic_infrastructure() -> void:
    var terminal:=Node3D.new()
    terminal.name="Wave8HarborTerminal"
    terminal.position=Vector3(30.0,-4.5,-23.0)
    add_child(terminal)
    var concrete:Material=material_map["concrete"]
    var steel:Material=material_map["titanium"]
    var bronze:Material=material_map["bronze"]
    _box(terminal,"CargoDeck",Vector3(12.0,0.68,19.0),Vector3.ZERO,concrete)
    for x in [-5.35,5.35]:
        _box(terminal,"ExtrudedDockRail",Vector3(0.18,0.60,19.0),Vector3(x,0.62,0),steel)
    for z in [-7.0,-2.0,3.0,8.0]:
        for x in [-4.5,4.5]:
            _column(terminal,"HydraulicBollard",0.24,0.62,Vector3(x,0.64,z),bronze)
    _box(terminal,"OperationsHangar",Vector3(5.8,2.60,7.9),Vector3(-2.7,1.65,-3.7),steel)
    _box(terminal,"GlassControlRoom",Vector3(3.7,1.25,3.8),Vector3(-2.7,3.32,-3.7),material_map["glazing"])
    _box(terminal,"CraneTower",Vector3(0.62,11.2,0.72),Vector3(4.1,5.9,3.0),bronze)
    _box(terminal,"ContainerCraneSpan",Vector3(10.2,0.45,0.55),Vector3(1.35,11.15,3.0),steel)
    _box(terminal,"CargoWinch",Vector3(0.65,2.0,0.65),Vector3(-1.25,9.9,3.0),material_map["signal"])

func _finish_color_pipeline() -> void:
    var world:=game.get_node_or_null("ChronosAtmosphere") as WorldEnvironment
    if world==null or world.environment==null:
        return
    var env:=world.environment
    env.adjustment_enabled=true
    env.adjustment_saturation=0.97
    env.adjustment_contrast=1.038
    env.fog_density=0.00145 if web else 0.0018
    env.glow_intensity=0.16 if web else 0.20
    # PC shadows and SSR/SSIL remain controlled by the Forward+ quality preset.

func _process(delta:float) -> void:
    t+=minf(delta,0.13)
    for i in range(trains.size()):
        var tram:Node3D=trains[i]
        var phase:float=fposmod(t*(2.8+float(i)*0.30)+float(i)*19.0,60.0)
        tram.position=Vector3(-7,0.0,-30.0-phase)
        tram.rotation.y=PI if i%2==0 else 0.0
