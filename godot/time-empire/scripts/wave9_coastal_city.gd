extends Node3D
## WAVE 9 — CHRONOS world-building: landscaped waterfront and civic transport.
## Genuine mesh and GPU instance geometry; economy, saves and navigation unchanged.

var game: Node3D
var web: bool = false
var seconds: float = 0.0
var quay_pylons: int = 0
var landscape_instances: int = 0
var trains: Array[Node3D] = []
var crane_hook: Node3D
var materials: Dictionary = {}

func configure(origin: Node3D) -> void:
    game = origin

func _ready() -> void:
    web = OS.has_feature("web") or RenderingServer.get_current_rendering_method() != "forward_plus"
    materials = {
        "stone": _pbr("sea_wall_concrete",Color(0.69,0.72,0.69),0.05,0.82),
        "alloy": _pbr("architectural_titanium",Color(0.67,0.77,0.82),0.82,0.32),
        "bronze": _pbr("patinated_bronze",Color(0.72,0.58,0.39),0.72,0.36),
        "glass": _solid(Color(0.17,0.40,0.51),0.43,0.19),
        "foliage": _solid(Color(0.21,0.36,0.30),0.03,0.88),
        "beacon": _emission(Color(1.0,0.72,0.37),0.95)
    }
    _build_waterfront()
    _build_urban_gardens()
    _build_civic_observatory()
    _build_service_transit()
    _tune_atmosphere()
    print("OSGARD_WAVE9_CHRONOS:",JSON.stringify({"waterfront_supports":quay_pylons,"landscaped_instances":landscape_instances,"moving_trams":trains.size(),"web_lod":web}))

func _pbr(folder: String, tint: Color, metal: float, rough: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = metal
    mat.roughness = rough
    mat.uv1_scale = Vector3(2.4,2.4,1.0)
    var base: String = "res://assets/wave8/%s/" % folder
    var a := load(base+"albedo.png") as Texture2D
    var n := load(base+"normal.png") as Texture2D
    var r := load(base+"roughness.png") as Texture2D
    var m := load(base+"metallic.png") as Texture2D
    if a != null:
        mat.albedo_texture = a
    if n != null:
        mat.normal_enabled = true
        mat.normal_texture = n
        mat.normal_scale = 0.28
    if r != null:
        mat.roughness_texture = r
        mat.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    if m != null:
        mat.metallic_texture = m
        mat.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
    return mat

func _solid(tint: Color, metal: float, rough: float) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = tint
    mat.metallic = metal
    mat.roughness = rough
    return mat

func _emission(tint: Color, energy: float) -> StandardMaterial3D:
    var mat := _solid(tint,0.12,0.28)
    mat.emission_enabled = true
    mat.emission = tint
    mat.emission_energy_multiplier = energy
    return mat

func _box(parent: Node3D, label: String, size: Vector3, position: Vector3, mat: Material) -> MeshInstance3D:
    var box := BoxMesh.new()
    box.size = size
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = box
    part.position = position
    part.material_override = mat
    parent.add_child(part)
    return part

func _cylinder(parent: Node3D, label: String, r: float, h: float, position: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := CylinderMesh.new()
    mesh.top_radius = r
    mesh.bottom_radius = r
    mesh.height = h
    mesh.radial_segments = 12 if web else 32
    var part := MeshInstance3D.new()
    part.name = label
    part.mesh = mesh
    part.position = position
    part.material_override = mat
    parent.add_child(part)
    return part

func _build_waterfront() -> void:
    var waterfront := Node3D.new()
    waterfront.name="Wave9TerracedWaterfront"
    add_child(waterfront)
    # Arc of physically supported shoreline terraces; deliberate breaks preserve
    # the access bridge and initial strategy-camera sightline to the Chrono core.
    var platform_mesh := BoxMesh.new()
    platform_mesh.size = Vector3(3.5,0.60,4.1)
    var modules := MultiMesh.new()
    modules.transform_format = MultiMesh.TRANSFORM_3D
    modules.mesh = platform_mesh
    var count: int = 52 if web else 104
    modules.instance_count = count
    for k in range(count):
        var angle: float = -0.15 + PI*1.24*float(k)/float(count-1)
        var radius: float = 35.2
        var center := Vector3(cos(angle)*radius,-5.7,sin(angle)*radius)
        var basis := Basis(Vector3.UP,-angle)
        modules.set_instance_transform(k,Transform3D(basis,center))
    var inst := MultiMeshInstance3D.new()
    inst.name = "GPUBatchedWaterfrontDeck"
    inst.multimesh = modules
    inst.material_override = materials["stone"]
    waterfront.add_child(inst)
    # Supporting quay piles reach below waterline, not floating platforms.
    var pilemesh := CylinderMesh.new()
    pilemesh.top_radius = 0.33
    pilemesh.bottom_radius = 0.41
    pilemesh.height = 7.8
    pilemesh.radial_segments = 8 if web else 16
    var piles := MultiMesh.new()
    piles.transform_format = MultiMesh.TRANSFORM_3D
    piles.mesh = pilemesh
    piles.instance_count = 24 if web else 48
    quay_pylons = piles.instance_count
    for i in range(piles.instance_count):
        var a: float = -0.15 + PI*1.24*float(i)/float(piles.instance_count-1)
        var r: float = 35.0
        piles.set_instance_transform(i,Transform3D(Basis(),Vector3(cos(a)*r,-9.6,sin(a)*r)))
    var pile_group := MultiMeshInstance3D.new()
    pile_group.name = "GPUDeepWaterFoundations"
    pile_group.multimesh = piles
    pile_group.material_override = materials["alloy"]
    waterfront.add_child(pile_group)
    # A double pedestrian rail is a cohesive read from the strategy camera.
    for i in range(18):
        var a: float = 0.03 + PI*1.06*float(i)/17.0
        var p := Vector3(cos(a)*39.0,-4.86,sin(a)*39.0)
        var strut := _box(waterfront,"QuaySafetyPylon",Vector3(0.16,1.22,0.16),p,materials["alloy"])
        strut.rotation.y = a
        if i%3 == 0:
            _box(waterfront,"MaritimeWarningLamp",Vector3(0.22,0.12,0.22),p+Vector3(0,0.67,0),materials["beacon"])

func _build_urban_gardens() -> void:
    var gardens := Node3D.new()
    gardens.name = "Wave9BiodiverseParkBelt"
    add_child(gardens)
    # Seven terraced parks around the seawall, no interference with build plots.
    var planted: Array[Transform3D] = []
    var trunks: Array[Transform3D] = []
    for sector in range(7):
        var angle: float = 0.30+float(sector)*TAU/7.0
        var r: float = 32.8 + float(sector%2)*1.4
        var x: float = cos(angle)*r
        var z: float = sin(angle)*r
        var garden := Node3D.new()
        garden.name = "RaisedGarden_%02d" % sector
        garden.position = Vector3(x,-5.4,z)
        gardens.add_child(garden)
        _cylinder(garden,"ConcretePlanterDish",2.0,0.44,Vector3.ZERO,materials["stone"])
        _cylinder(garden,"SoilBed",1.79,0.12,Vector3(0,0.24,0),materials["foliage"])
        for sprig in range(11 if web else 24):
            var local_angle: float = float(sprig)*TAU/float(11 if web else 24)
            var radial: float = 0.38 + float((sprig*3)%7)*0.19
            var px: float = x+cos(local_angle)*radial
            var pz: float = z+sin(local_angle)*radial
            var size: float = 0.56+float((sprig*5)%9)*0.048
            planted.append(Transform3D(Basis().scaled(Vector3(size,size*1.15,size)),Vector3(px,-4.66+size*0.5,pz)))
            trunks.append(Transform3D(Basis().scaled(Vector3(0.07,0.48,0.07)),Vector3(px,-4.51,pz)))
    var leafmesh := SphereMesh.new()
    leafmesh.radius=0.58
    leafmesh.height=1.10
    leafmesh.radial_segments=7 if web else 11
    leafmesh.rings=4 if web else 7
    _gpu_instances(gardens,"GPUCanopyFoliage",leafmesh,planted,materials["foliage"])
    var trunkmesh := CylinderMesh.new()
    trunkmesh.top_radius=1.0
    trunkmesh.bottom_radius=1.0
    trunkmesh.height=1.0
    trunkmesh.radial_segments=6
    _gpu_instances(gardens,"GPUTrunks",trunkmesh,trunks,materials["bronze"])
    landscape_instances=planted.size()

func _gpu_instances(parent: Node3D, label: String, mesh: Mesh, instances: Array[Transform3D], material: Material) -> void:
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = mesh
    batch.instance_count = instances.size()
    for i in range(instances.size()):
        batch.set_instance_transform(i,instances[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = batch
    node.material_override = material
    parent.add_child(node)

func _build_civic_observatory() -> void:
    var observatory := Node3D.new()
    observatory.name="Wave9CivicObservatory"
    observatory.position=Vector3(29.0,-5.3,15.0)
    add_child(observatory)
    _cylinder(observatory,"GraniteFoundation",3.5,0.72,Vector3.ZERO,materials["stone"])
    _cylinder(observatory,"CentralSteelColumn",0.85,5.2,Vector3(0,3.1,0),materials["alloy"])
    _cylinder(observatory,"PanoramicCrown",3.0,0.48,Vector3(0,6.0,0),materials["bronze"])
    var dome := SphereMesh.new()
    dome.radius=2.7
    dome.height=2.9
    dome.radial_segments=16 if web else 44
    dome.rings=8 if web else 22
    var glass := MeshInstance3D.new()
    glass.name="PanoramicObservationGlazing"
    glass.mesh=dome
    glass.position=Vector3(0,7.45,0)
    glass.material_override=materials["glass"]
    observatory.add_child(glass)
    for i in range(8):
        var a: float=TAU*float(i)/8.0
        var bx:float=cos(a)*2.6
        var bz:float=sin(a)*2.6
        _box(observatory,"CeramicSupportSpar",Vector3(0.18,4.4,0.18),Vector3(bx,3.3,bz),materials["alloy"])
    _box(observatory,"HarborNavigationCrown",Vector3(1.9,0.16,0.16),Vector3(0,9.05,0),materials["beacon"])

func _build_service_transit() -> void:
    var transit := Node3D.new()
    transit.name="Wave9WatersideServiceRail"
    add_child(transit)
    # Shore connection is physically grounded in the quay, not a floating effect.
    _box(transit,"RailBeam",Vector3(25,0.22,0.72),Vector3(18.2,-4.68,21.1),materials["alloy"])
    for i in range(9):
        _cylinder(transit,"RailSupportPylon",0.24,4.6,Vector3(7.0+float(i)*2.8,-7.2,21.1),materials["stone"])
    for i in range(2):
        var vehicle := Node3D.new()
        vehicle.name="ShoreShuttle_%02d"%i
        transit.add_child(vehicle)
        _box(vehicle,"StampedMetalBody",Vector3(2.4,0.75,1.12),Vector3(0,0.35,0),materials["alloy"])
        _box(vehicle,"GlazedPanorama",Vector3(1.7,0.38,0.94),Vector3(0,0.78,0),materials["glass"])
        _box(vehicle,"NavigationBeacon",Vector3(0.11,0.16,0.20),Vector3(-1.12,0.47,0),materials["beacon"])
        trains.append(vehicle)

func _tune_atmosphere() -> void:
    var world := game.get_node_or_null("ChronosAtmosphere") as WorldEnvironment
    if world == null or world.environment == null:
        return
    var env := world.environment
    env.adjustment_enabled=true
    env.adjustment_contrast=1.033
    env.adjustment_saturation=0.98
    env.fog_density=0.00145 if web else 0.00165
    env.glow_intensity=0.15 if web else 0.19

func _process(delta: float) -> void:
    seconds+=minf(delta,0.10)
    for i in range(trains.size()):
        var train:=trains[i]
        var slide: float=fposmod(seconds*(2.1+float(i)*0.23)+float(i)*12.0,21.4)
        train.position=Vector3(7.5+slide,-4.56,21.1)
        train.rotation.y=PI if i%2==0 else 0.0
