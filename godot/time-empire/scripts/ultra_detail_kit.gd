extends RefCounted
## CHRONOS CITY / ORIGINAL MODULAR 3D ASSETS
## Native meshes, PBR normals and GPU-instanced facade detail. Godot 4.7.

static var _materials: Dictionary = {}
static var _micro_normals: Texture2D

const METAL := Color(0.47, 0.56, 0.61)
const DARK := Color(0.12, 0.19, 0.24)
const IVORY := Color(0.72, 0.76, 0.72)
const CHAMPAGNE := Color(0.66, 0.49, 0.31)
const GLASS := Color(0.13, 0.36, 0.47)
const AQUA := Color(0.24, 0.79, 0.88)
const GOLD := Color(0.99, 0.66, 0.34)
const GREEN := Color(0.23, 0.51, 0.37)

static func decorate_city(city: Node3D, chrono_core: Node3D, traffic: Array[Node3D]) -> void:
    _prepare()
    var architecture := Node3D.new()
    architecture.name = "Chronos_UltraCityArchitecture"
    city.add_child(architecture)
    _central_promenade(architecture)
    _sculpted_landmarks(architecture)
    _transit_system(architecture)
    var reactor_details := Node3D.new()
    reactor_details.name = "Chronos_HighPolyReactor"
    chrono_core.add_child(reactor_details)
    _reactor(reactor_details)
    for i in range(traffic.size()):
        _shuttle_art(traffic[i], i)

static func decorate_district(district: Node3D, index: int) -> void:
    _prepare()
    var art := Node3D.new()
    art.name = "HighDensityDistrict_%02d" % index
    district.add_child(art)
    _cylinder(art,"ReactorAntimatterContainment",Vector3(0,2.5,0),1.35,2.2,"steel",36)
    for deck in range(5):
        var h: float = 1.2+float(deck)*0.65
        _ring(art,"ServiceBearing",Vector3(0,h,0),1.65,0.05,"gold")
        _ring(art,"SafetyTrim",Vector3(0,h+0.16,0),1.48,0.028,"aqua")
    for arm in range(8):
        var a: float = TAU*float(arm)/8.0
        var module := Node3D.new()
        module.rotation.y = a
        art.add_child(module)
        _cube(module,"CivicEnergyFin",Vector3(0,2.3,1.95),Vector3(0.33,3.35,0.23),"ivory")
        _cube(module,"DistrictServiceLight",Vector3(0,4.05,1.95),Vector3(0.12,0.23,0.12),"aqua")
        _cube(module,"DistrictPanelSeam",Vector3(0,1.3,2.07),Vector3(0.24,0.035,0.06),"dark")
    _bolt_ring(art,"FlangeFasteners32",2.20,0.65,32,0.075)

static func _prepare() -> void:
    if not _materials.is_empty():
        return
    var img := Image.create(128,128,false,Image.FORMAT_RGBA8)
    for y in range(128):
        for x in range(128):
            var a: float = sin(float(x)*0.13+float(y)*0.75)*0.025
            var b: float = sin(float(y)*1.4)*0.045
            img.set_pixel(x,y,Color(0.5+a,0.5+b,0.991,1))
    _micro_normals = ImageTexture.create_from_image(img)
    _materials["steel"] = _pbr(METAL,0.82,0.27,0,true)
    _materials["dark"] = _pbr(DARK,0.62,0.39,0,true)
    _materials["ivory"] = _pbr(IVORY,0.43,0.26,0,true)
    _materials["bronze"] = _pbr(CHAMPAGNE,0.77,0.23,0,true)
    _materials["glass"] = _pbr(GLASS,0.31,0.13,0,false)
    _materials["aqua"] = _pbr(AQUA,0.10,0.19,1.15,false)
    _materials["gold"] = _pbr(GOLD,0.22,0.18,0.85,false)
    _materials["green"] = _pbr(GREEN,0.03,0.82,0,false)

static func _pbr(color: Color,metal: float,rough: float,emission: float,normal: bool) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color=color
    m.metallic=metal
    m.roughness=rough
    if emission>0.0:
        m.emission_enabled=true
        m.emission=color
        m.emission_energy_multiplier=emission
    if normal:
        m.normal_enabled=true
        m.normal_texture=_micro_normals
        m.normal_scale=0.43
        m.uv1_triplanar=true
    return m

static func _cube(parent: Node3D,name: String,pos: Vector3,size: Vector3,material: String,rotation: Vector3=Vector3.ZERO) -> MeshInstance3D:
    var item:=MeshInstance3D.new()
    item.name=name
    var geo:=BoxMesh.new()
    geo.size=size
    item.mesh=geo
    item.material_override=_materials[material]
    item.position=pos
    item.rotation=rotation
    parent.add_child(item)
    return item

static func _cylinder(parent: Node3D,name: String,pos: Vector3,radius: float,height: float,material: String,segments: int=32) -> MeshInstance3D:
    var item:=MeshInstance3D.new()
    item.name=name
    var geo:=CylinderMesh.new()
    geo.top_radius=radius
    geo.bottom_radius=radius
    geo.height=height
    geo.radial_segments=segments
    item.mesh=geo
    item.material_override=_materials[material]
    item.position=pos
    parent.add_child(item)
    return item

static func _ring(parent: Node3D,name: String,pos: Vector3,radius: float,tube: float,material: String,rotation: Vector3=Vector3.ZERO) -> MeshInstance3D:
    var item:=MeshInstance3D.new()
    item.name=name
    var geo:=TorusMesh.new()
    geo.inner_radius=maxf(0.01,radius-tube)
    geo.outer_radius=radius+tube
    geo.rings=64
    geo.ring_segments=16
    item.mesh=geo
    item.material_override=_materials[material]
    item.position=pos
    item.rotation=rotation
    parent.add_child(item)
    return item

static func _sphere(parent: Node3D,name: String,pos: Vector3,radius: float,material: String) -> MeshInstance3D:
    var item:=MeshInstance3D.new()
    item.name=name
    var geo:=SphereMesh.new()
    geo.radius=radius
    geo.height=radius*2
    geo.radial_segments=36
    geo.rings=20
    item.mesh=geo
    item.material_override=_materials[material]
    item.position=pos
    parent.add_child(item)
    return item

static func _beam(parent: Node3D,name: String,a: Vector3,b: Vector3,radius: float,kind: String) -> void:
    var delta: Vector3=b-a
    if delta.length_squared()<0.0001:
        return
    var pipe:=_cylinder(parent,name,(a+b)*0.5,radius,delta.length(),kind,16)
    pipe.quaternion=Quaternion(Vector3.UP,delta.normalized())

static func _batch(parent: Node3D,name: String,transforms: Array[Transform3D],material: String) -> void:
    if transforms.is_empty():
        return
    var multi:=MultiMesh.new()
    multi.transform_format=MultiMesh.TRANSFORM_3D
    var mesh:=BoxMesh.new()
    mesh.size=Vector3.ONE
    multi.mesh=mesh
    multi.instance_count=transforms.size()
    for i in range(transforms.size()):
        multi.set_instance_transform(i,transforms[i])
    var item:=MultiMeshInstance3D.new()
    item.name=name
    item.multimesh=multi
    item.material_override=_materials[material]
    parent.add_child(item)

static func _bolt_ring(parent:Node3D,title:String,radius:float,y:float,count:int,size:float) -> void:
    var transforms: Array[Transform3D]=[]
    for i in range(count):
        var a: float=TAU*float(i)/float(count)
        transforms.append(Transform3D(Basis().scaled(Vector3(size,size,size)),Vector3(cos(a)*radius,y,sin(a)*radius)))
    _batch(parent,title,transforms,"bronze")

static func _central_promenade(root:Node3D)->void:
    # Bronze-veined paving and lit concentric pedestrian access.
    for i in range(24):
        var a:float=TAU*float(i)/24.0
        var radius:float=5.7
        _cube(root,"SkygardenBench",Vector3(cos(a)*radius,0.46,sin(a)*radius),Vector3(0.46,0.18,1.15),"ivory",Vector3(0,a,0))
        _sphere(root,"PromenadeLamp",Vector3(cos(a)*(radius+0.36),1.00,sin(a)*(radius+0.36)),0.085,"gold")
    _ring(root,"CentralSunburstBand",Vector3(0,0.50,0),6.4,0.055,"bronze")
    _ring(root,"CentralAquaEdge",Vector3(0,0.54,0),6.56,0.025,"aqua")
    for i in range(12):
        var a:float=TAU*float(i)/12.0
        var p:=Vector3(cos(a)*6.9,0.4,sin(a)*6.9)
        var q:=Vector3(cos(a)*6.9,2.4,sin(a)*6.9)
        _beam(root,"LightPylon",p,q,0.08,"steel")
        _sphere(root,"LightPylonHead",q,0.13,"aqua")

static func _reactor(root:Node3D)->void:
    # Multi-deck, layered crown of the city's time-energy reactor.
    for level in range(8):
        var y:float=2.20+float(level)*0.50
        _ring(root,"RotaryInductionBelt",Vector3(0,y,0),1.25+float(level%3)*0.075,0.045,"bronze")
        if level%2==0:
            _ring(root,"AxialEnergyGuide",Vector3(0,y+0.18,0),1.38,0.018,"aqua")
    for side in range(16):
        var a:float=TAU*float(side)/16.0
        var spire:=Node3D.new()
        spire.rotation.y=a
        root.add_child(spire)
        _cube(spire,"ReactorShieldArmor",Vector3(0,3.65,3.90),Vector3(0.31,5.70,0.21),"dark")
        _cube(spire,"TitaniumReactorRidge",Vector3(0,3.7,4.05),Vector3(0.073,5.25,0.10),"steel")
        for h in [1.3,2.55,3.85,5.10]:
            _cube(spire,"SafetyEnergyFilament",Vector3(0,h,4.10),Vector3(0.24,0.055,0.05),"gold")
        _sphere(spire,"TopControlNode",Vector3(0,6.50,3.90),0.19,"aqua")
    for level in [0.0,1.25,2.70,4.10]:
        _ring(root,"OuterPrecisionFlange",Vector3(0,0.9+level,0),4.26,0.085,"steel")
        _bolt_ring(root,"MachinedFastenerRing",4.32,0.9+level,48,0.075)
    for index in range(12):
        var a:float=TAU*float(index)/12.0
        var x:float=cos(a)*3.1
        var z:float=sin(a)*3.1
        _cube(root,"HydraulicGeneratorPod",Vector3(x,0.83,z),Vector3(0.55,1.25,0.77),"bronze",Vector3(0,-a,0))
        _cylinder(root,"ReactorCoolingVent",Vector3(x,1.56,z),0.24,0.16,"dark",20)
        _ring(root,"ArcHazardBeacon",Vector3(x,1.65,z),0.22,0.055,"gold")
    _sphere(root,"HighFluxInnerEmitter",Vector3(0,6.50,0),1.16,"aqua")
    _ring(root,"SovereignChronoCrown",Vector3(0,9.15,0),2.80,0.18,"bronze")
    for i in range(12):
        var a:float=TAU*float(i)/12.0
        _beam(root,"TimeArcSculpture",Vector3(cos(a)*2.8,9.15,sin(a)*2.8),Vector3(cos(a)*1.7,10.25,sin(a)*1.7),0.075,"steel")

static func _sculpted_landmarks(root:Node3D)->void:
    var positions: Array[Vector3]=[
        Vector3(-21.1,0,-8.3),Vector3(20.6,0,-8.5),Vector3(9.7,0,-21.8),
        Vector3(-9.7,0,-21.1),Vector3(-21.3,0,8.7),Vector3(21.0,0,8.5),
        Vector3(9.5,0,21.4),Vector3(-9.6,0,21.2),Vector3(2.6,0,16.6),
        Vector3(-2.8,0,-16.6),Vector3(16.7,0,2.5),Vector3(-16.5,0,-2.2)
    ]
    for idx in range(positions.size()):
        var landmark:=Node3D.new()
        landmark.name="SculptedLandmark_%02d"%idx
        landmark.position=positions[idx]
        landmark.rotation.y=float(idx)*0.53
        root.add_child(landmark)
        match idx%4:
            0: _tiered_skyscraper(landmark,idx)
            1: _twin_tower(landmark,idx)
            2: _civic_observatory(landmark,idx)
            _: _garden_spire(landmark,idx)

static func _tiered_skyscraper(root:Node3D,seed:int)->void:
    var h:float=11.2+float(seed%4)*2.1
    _cube(root,"BrutalistDeepFoundation",Vector3(0,0.72,0),Vector3(3.2,1.5,3.1),"dark")
    for level in range(4):
        var yy:float=1.5+float(level)*h/4.0
        var floor_height:float=h/4.0
        var width:float=2.6-float(level)*0.35
        _cube(root,"LayeredTitaniumVolume",Vector3(0,yy+floor_height*0.5,0),Vector3(width,floor_height,width),"steel")
        _cube(root,"BronzeReveal",Vector3(0,yy+floor_height,0),Vector3(width+0.2,0.18,width+0.2),"bronze")
        for y in range(5):
            var wy:float=yy+0.4+float(y)*floor_height/6.0
            for side in [-1.0,1.0]:
                _cube(root,"FacadeStreak",Vector3(float(side)*(width*0.48),wy,width*0.51),Vector3(0.22,0.09,0.035),"aqua")
    _cylinder(root,"RoofBeacon",Vector3(0,h+2.1,0),0.24,2.9,"steel")
    _sphere(root,"RoofBeaconEmitter",Vector3(0,h+3.6,0),0.28,"gold")

static func _twin_tower(root:Node3D,seed:int)->void:
    var height:float=12.0+float(seed%3)*2.6
    for x in [-1.35,1.35]:
        _cube(root,"DuplexPylon",Vector3(x,height*0.5,0),Vector3(1.85,height,2.1),"dark")
        _cube(root,"VerticalGlassChasm",Vector3(x,height*0.5,1.09),Vector3(1.25,height*0.83,0.12),"glass")
        _cube(root,"UpperRoofCap",Vector3(x,height+0.06,0),Vector3(2.05,0.30,2.36),"bronze")
        for floor in range(2,int(height),2):
            _cube(root,"HorizontalFloorBand",Vector3(x,float(floor),1.18),Vector3(1.63,0.085,0.1),"aqua")
    _cube(root,"SkybridgeCivicDeck",Vector3(0,height*0.65,0),Vector3(4.2,0.35,1.4),"ivory")
    _cube(root,"SkybridgeGlass",Vector3(0,height*0.92,0.28),Vector3(3.7,0.95,0.15),"glass")
    _ring(root,"RooftopAntennaHalo",Vector3(0,height+0.7,0),1.55,0.055,"gold")

static func _civic_observatory(root:Node3D,seed:int)->void:
    _cylinder(root,"ObservatoryCircularBase",Vector3(0,1.1,0),2.25,2.2,"bronze",32)
    _cylinder(root,"ObservatoryTower",Vector3(0,5.5,0),1.45,7.2,"steel",32)
    for floor in range(5):
        var h:float=2.4+float(floor)*1.5
        _ring(root,"ObservationBalcony",Vector3(0,h,0),1.74,0.15,"ivory")
        _ring(root,"ObservationLumen",Vector3(0,h+0.21,0),1.82,0.027,"aqua")
        for w in range(8):
            var a:float=TAU*float(w)/8.0
            var n:=Node3D.new()
            n.rotation.y=a
            root.add_child(n)
            _cube(n,"OctagonalGlassPanel",Vector3(0,h+0.58,1.37),Vector3(0.64,0.79,0.07),"glass")
    _cylinder(root,"ObservatoryCrown",Vector3(0,9.3,0),2.04,0.62,"dark",32)
    _sphere(root,"AstralObservationSensor",Vector3(0,10.1,0),0.85,"aqua")
    _ring(root,"AstralGuidingRing",Vector3(0,10.2,0),1.40,0.08,"bronze",Vector3(PI/3,0,0))

static func _garden_spire(root:Node3D,seed:int)->void:
    var main_height:float=11.4+float(seed%4)*1.3
    _cylinder(root,"ResidentialCivicFoundation",Vector3(0,0.9,0),2.2,1.8,"dark",24)
    _cylinder(root,"SculpturalCenterSpine",Vector3(0,main_height*0.5+0.9,0),1.15,main_height,"glass",24)
    for terrace in range(6):
        var y:float=2.0+float(terrace)*main_height/6.0
        var radius:float=1.92-float(terrace)*0.12
        _cylinder(root,"GardensCantilever",Vector3(0,y,0),radius,0.25,"ivory",24)
        _ring(root,"TerraceGuardrail",Vector3(0,y+0.19,0),radius-0.1,0.045,"bronze")
        for plant in range(10):
            var a:float=TAU*float(plant)/10.0+float(terrace)*0.18
            _sphere(root,"HangingGardenCanopy",Vector3(cos(a)*(radius-0.3),y+0.38,sin(a)*(radius-0.3)),0.20,"green")
    _sphere(root,"UrbanSpireFinial",Vector3(0,main_height+2.1,0),0.65,"gold")

static func _transit_system(root:Node3D)->void:
    for side in range(20):
        var a:float=TAU*float(side)/20.0
        var x:float=cos(a)*20.5
        var z:float=sin(a)*20.5
        _cylinder(root,"RailwaySupportFoundation",Vector3(x,0.20,z),0.21,0.28,"dark",14)
        _cylinder(root,"RailwayGuideColumn",Vector3(x,0.63,z),0.075,0.84,"steel",14)
        _sphere(root,"LightedTrafficMarker",Vector3(x,1.20,z),0.095,"aqua")
    _ring(root,"PublicTransportBronzeGuide",Vector3(0,0.48,0),20.43,0.07,"bronze")
    _ring(root,"PublicTransportSafetyLighting",Vector3(0,0.54,0),20.71,0.028,"aqua")

static func _shuttle_art(vehicle:Node3D,index:int)->void:
    var art:=Node3D.new()
    art.name="DetailedAutonomousShuttle"
    vehicle.add_child(art)
    _cube(art,"CompositeLowerHull",Vector3(0,0.03,0),Vector3(1.06,0.21,0.58),"ivory")
    _cube(art,"ArmoredCanopy",Vector3(-0.07,0.19,0),Vector3(0.56,0.22,0.49),"glass")
    for side in [-1.0,1.0]:
        _cube(art,"StabilizerWinglet",Vector3(-0.23,0.02,0.40*side),Vector3(0.34,0.035,0.34),"bronze")
        _cube(art,"NavIlluminator",Vector3(0.52,0.04,0.21*side),Vector3(0.10,0.08,0.07),"aqua")
    for wheel in [-0.33,0.33]:
        for z in [-0.31,0.31]:
            _sphere(art,"MaglevThruster",Vector3(wheel,-0.09,z),0.12,"dark")
    _cube(art,"ReactorRunningLight",Vector3(-0.51,0.03,0),Vector3(0.045,0.06,0.29),"gold")