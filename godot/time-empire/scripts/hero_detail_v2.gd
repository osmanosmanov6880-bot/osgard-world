extends RefCounted
## CHRONOS CITY / HERO DETAIL v2. Fully modeled procedural landmark surfaces.
## Indexed lathe and twisted tower meshes; facade and roof details via GPU instancing.

const TITANIUM := Color(0.45, 0.55, 0.60)
const COBALT := Color(0.12, 0.22, 0.32)
const GLASS := Color(0.22, 0.45, 0.52)
const BRONZE := Color(0.62, 0.43, 0.29)
const IVORY := Color(0.77, 0.78, 0.69)
const AQUA := Color(0.19, 0.64, 0.75)
const EMERALD := Color(0.17, 0.43, 0.33)
const GOLD := Color(0.86, 0.59, 0.30)

static var materials: Dictionary = {}
static var detail_texture: ImageTexture

static func build(city: Node3D, reactor: Node3D, traffic: Array[Node3D]) -> void:
    _materials()
    var district := Node3D.new()
    district.name = "HeroCitySculpturesV2"
    city.add_child(district)
    _civic_transit(district)
    _rooftop_detail(district)
    var chronogear := Node3D.new()
    chronogear.name = "HeroChronoReactorV2"
    reactor.add_child(chronogear)
    _reactor_sculpt(chronogear)
    for i in range(traffic.size()):
        _vehicle_micro_detail(traffic[i],i)

static func _materials() -> void:
    if not materials.is_empty():
        return
    var img := Image.create(128,128,false,Image.FORMAT_RGBA8)
    for y in range(128):
        for x in range(128):
            var n:float=0.5+sin(float(y)*0.89)*0.031+sin(float(y)*2.4)*0.014
            img.set_pixel(x,y,Color(n,0.5+sin(float(x*19+y*7)*0.11)*0.014,0.993,1.0))
    detail_texture=ImageTexture.create_from_image(img)
    materials["titanium"]=_mat(TITANIUM,0.88,0.29,0.0,true)
    materials["cobalt"]=_mat(COBALT,0.72,0.33,0.0,true)
    materials["glass"]=_mat(GLASS,0.43,0.17,0.0,false)
    materials["bronze"]=_mat(BRONZE,0.83,0.27,0.0,true)
    materials["ivory"]=_mat(IVORY,0.38,0.36,0.0,false)
    materials["aqua"]=_mat(AQUA,0.08,0.20,1.0,false)
    materials["emerald"]=_mat(EMERALD,0.04,0.85,0.0,false)
    materials["gold"]=_mat(GOLD,0.17,0.22,0.7,false)

static func _mat(col:Color,metal:float,rough:float,glow:float,micro:bool)->StandardMaterial3D:
    var p:=StandardMaterial3D.new()
    p.albedo_color=col
    p.metallic=metal
    p.roughness=rough
    if glow>0.0:
        p.emission_enabled=true
        p.emission=col
        p.emission_energy_multiplier=glow
    if micro:
        p.normal_enabled=true
        p.normal_texture=detail_texture
        p.normal_scale=0.38
        p.uv1_triplanar=true
    return p

static func _instance(root:Node3D,name:String,mesh:Mesh,material:String,loc:Vector3=Vector3.ZERO)->MeshInstance3D:
    var item:=MeshInstance3D.new()
    item.name=name
    item.mesh=mesh
    item.material_override=materials[material]
    item.position=loc
    root.add_child(item)
    return item

static func _box(root:Node3D,name:String,position:Vector3,dim:Vector3,material:String)->MeshInstance3D:
    var mesh:=BoxMesh.new()
    mesh.size=dim
    return _instance(root,name,mesh,material,position)

static func _lathe_mesh(profile:PackedVector2Array,sides:int=72)->ArrayMesh:
    # Radial turning gives non-rectangular silhouettes and continuous normals.
    var verts:=PackedVector3Array()
    var norms:=PackedVector3Array()
    var tex:=PackedVector2Array()
    var faces:=PackedInt32Array()
    for j in range(profile.size()):
        var p:Vector2=profile[j]
        var pre:Vector2=profile[maxi(0,j-1)]
        var post:Vector2=profile[mini(profile.size()-1,j+1)]
        var tangent:Vector2=(post-pre).normalized()
        var out:Vector2=Vector2(tangent.y,-tangent.x)
        for i in range(sides+1):
            var t:float=TAU*float(i)/float(sides)
            var ca:float=cos(t)
            var sa:float=sin(t)
            verts.append(Vector3(ca*p.x,p.y,sa*p.x))
            norms.append(Vector3(ca*out.x,out.y,sa*out.x).normalized())
            tex.append(Vector2(float(i)/float(sides),float(j)/float(profile.size()-1)))
    for j in range(profile.size()-1):
        for i in range(sides):
            var k:int=j*(sides+1)+i
            var m:int=k+sides+1
            faces.append_array(PackedInt32Array([k,m,k+1,m,m+1,k+1]))
    var arrays:Array=[]
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX]=verts
    arrays[Mesh.ARRAY_NORMAL]=norms
    arrays[Mesh.ARRAY_TEX_UV]=tex
    arrays[Mesh.ARRAY_INDEX]=faces
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arrays)
    return mesh

static func _lathe(root:Node3D,name:String,profile:PackedVector2Array,material:String,loc:Vector3=Vector3.ZERO,sides:int=64)->MeshInstance3D:
    return _instance(root,name,_lathe_mesh(profile,sides),material,loc)

static func _twisted_mesh(height:float,base_radius:float,twist:float,rings:int=24,corners:int=8)->ArrayMesh:
    # Faceted glass-and-steel civic forms, not stacked cubes.
    var verts:=PackedVector3Array()
    var normals:=PackedVector3Array()
    var uv:=PackedVector2Array()
    var inds:=PackedInt32Array()
    for level in range(rings+1):
        var t:float=float(level)/float(rings)
        var aoff:float=twist*t
        var rad:float=base_radius*(1.0-0.23*t)+sin(t*TAU*3.0)*0.035
        for side in range(corners+1):
            var a:float=TAU*float(side)/float(corners)+aoff
            var x:float=cos(a)
            var z:float=sin(a)
            verts.append(Vector3(x*rad,height*t,z*rad))
            normals.append(Vector3(x,0.16,z).normalized())
            uv.append(Vector2(float(side)/float(corners),t*4.0))
    for level in range(rings):
        for side in range(corners):
            var i:int=level*(corners+1)+side
            var j:int=i+corners+1
            inds.append_array(PackedInt32Array([i,j,i+1,j,j+1,i+1]))
    var arr:Array=[]
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX]=verts
    arr[Mesh.ARRAY_NORMAL]=normals
    arr[Mesh.ARRAY_TEX_UV]=uv
    arr[Mesh.ARRAY_INDEX]=inds
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
    return mesh

static func _tubular_mesh(points:PackedVector3Array,radius:float,sides:int=10)->ArrayMesh:
    var v:=PackedVector3Array()
    var n:=PackedVector3Array()
    var uv:=PackedVector2Array()
    var idx:=PackedInt32Array()
    for i in range(points.size()):
        var delta:Vector3=(points[mini(i+1,points.size()-1)]-points[maxi(0,i-1)]).normalized()
        if delta.length_squared()<0.1:
            delta=Vector3.UP
        var axis:Vector3=Vector3.FORWARD if absf(delta.dot(Vector3.UP))>0.86 else Vector3.UP
        var side:Vector3=delta.cross(axis).normalized()
        var binormal:Vector3=delta.cross(side).normalized()
        for j in range(sides+1):
            var a:float=TAU*float(j)/float(sides)
            var nr:Vector3=side*cos(a)+binormal*sin(a)
            v.append(points[i]+nr*radius)
            n.append(nr)
            uv.append(Vector2(float(j)/float(sides),float(i)/16.0))
    for i in range(points.size()-1):
        for j in range(sides):
            var k:int=i*(sides+1)+j
            var h:int=k+sides+1
            idx.append_array(PackedInt32Array([k,h,k+1,h,h+1,k+1]))
    var arr:Array=[]
    arr.resize(Mesh.ARRAY_MAX)
    arr[Mesh.ARRAY_VERTEX]=v
    arr[Mesh.ARRAY_NORMAL]=n
    arr[Mesh.ARRAY_TEX_UV]=uv
    arr[Mesh.ARRAY_INDEX]=idx
    var mesh:=ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES,arr)
    return mesh

static func _batch(root:Node3D,name:String,mesh:Mesh,transforms:Array[Transform3D],kind:String)->void:
    if transforms.is_empty():
        return
    var multi:=MultiMesh.new()
    multi.transform_format=MultiMesh.TRANSFORM_3D
    multi.mesh=mesh
    multi.instance_count=transforms.size()
    for i in range(transforms.size()):
        multi.set_instance_transform(i,transforms[i])
    var node:=MultiMeshInstance3D.new()
    node.name=name
    node.multimesh=multi
    node.material_override=materials[kind]
    root.add_child(node)

static func _reactor_sculpt(root:Node3D)->void:
    # Distinctive chronosphere pedestal and rotated turbine strata.
    _lathe(root,"ParametricChronoCoolingCasing",PackedVector2Array([
        Vector2(1.20,0.55),Vector2(3.12,0.55),Vector2(3.35,0.75),
        Vector2(3.35,1.05),Vector2(2.82,1.20),Vector2(2.65,2.2),
        Vector2(2.45,2.35),Vector2(1.30,2.35)
    ]),"titanium",Vector3.ZERO,88)
    _lathe(root,"ReactorsPolishedMachinedCollar",PackedVector2Array([
        Vector2(0.97,4.30),Vector2(1.38,4.35),Vector2(1.57,4.54),
        Vector2(1.57,4.68),Vector2(1.44,4.82),Vector2(0.97,4.82)
    ]),"bronze",Vector3.ZERO,80)
    _lathe(root,"HighDensityChronoCrown",PackedVector2Array([
        Vector2(1.75,8.20),Vector2(2.7,8.20),Vector2(3.0,8.34),
        Vector2(3.0,8.51),Vector2(2.78,8.66),Vector2(1.83,8.66)
    ]),"titanium",Vector3.ZERO,88)
    # 3D helical conduits; the bright chronosphere remains an open focal point.
    for strand in range(3):
        var points:=PackedVector3Array()
        for i in range(185):
            var t:float=float(i)/184.0
            var a:float=t*TAU*5.5+TAU*float(strand)/3.0
            points.append(Vector3(2.16*cos(a),2.40+t*3.5,2.16*sin(a)))
        _instance(root,"ChronoEnergyHelix_%02d"%strand,_tubular_mesh(points,0.037,8),"bronze" if strand==0 else "aqua")
    # Servo-lock bolts are a single draw call per 96 pieces.
    var bolts:Array[Transform3D]=[]
    for i in range(96):
        var a:float=TAU*float(i)/96.0
        bolts.append(Transform3D(Basis().scaled(Vector3(0.078,0.10,0.078)),Vector3(cos(a)*2.91,8.68,sin(a)*2.91)))
    var boltmesh:=CylinderMesh.new()
    boltmesh.top_radius=0.64
    boltmesh.bottom_radius=0.64
    boltmesh.height=1.0
    boltmesh.radial_segments=8
    _batch(root,"ChronoCrownHexbolts96",boltmesh,bolts,"titanium")
    var plates:Array[Transform3D]=[]
    for i in range(20):
        var a:float=TAU*float(i)/20.0
        var tangent:Basis=Basis(Vector3.UP,-a).scaled(Vector3(0.30,1.28,0.09))
        plates.append(Transform3D(tangent,Vector3(cos(a)*3.85,3.28,sin(a)*3.85)))
    var box:=BoxMesh.new()
    box.size=Vector3.ONE
    _batch(root,"ReactorRadialThermalShields",box,plates,"cobalt")

static func _rooftop_detail(root:Node3D)->void:
    var landmarks:Node3D=root.get_parent().get_node_or_null("Chronos_UltraCityArchitecture")
    if landmarks==null:
        return
    for idx in range(12):
        var tower:Node3D=landmarks.get_node_or_null("SculptedLandmark_%02d"%idx)
        if tower==null:
            continue
        var art:=Node3D.new()
        art.name="TowerHeroFacades_%02d"%idx
        tower.add_child(art)
        var height:float=12.5+float(idx%4)*1.45
        var color:String="bronze" if idx%4==0 else "titanium" if idx%4==2 else "glass"
        var panels:Array[Transform3D]=[]
        for level in range(10):
            var yy:float=1.8+float(level)*(height-3.0)/10.0
            var radius:float=1.68 if idx%4==2 else 1.39
            for side in range(8):
                var a:float=TAU*float(side)/8.0
                var radial:float=radius+sin(float(level)*0.4)*0.075
                var basis:Basis=Basis(Vector3.UP,a).scaled(Vector3(0.08,0.34,0.052))
                panels.append(Transform3D(basis,Vector3(cos(a)*radial,yy,sin(a)*radial)))
        var mesh:=BoxMesh.new()
        mesh.size=Vector3.ONE
        _batch(art,"InstancedParametricFacadeFins",mesh,panels,color)
        # Per-landmark height varies: facades are attached, no floating roof disks.
    # Four free-form civic monuments in the existing outside promenade, low enough
    # to leave a clean sightline to the central chrono reactor.
    var monuments:Array[Vector3]=[
        Vector3(-13.0,0,-24.2),Vector3(13.0,0,-24.2),
        Vector3(-13.0,0,24.2),Vector3(13.0,0,24.2)
    ]
    for i in range(monuments.size()):
        var site:=Node3D.new()
        site.name="LoftedCivicMonument_%02d"%i
        site.position=monuments[i]
        site.rotation.y=float(i)*0.5
        root.add_child(site)
        _instance(site,"TwistingParametricPavilion",_twisted_mesh(6.8,1.4,1.05+float(i)*0.13,32,12),"glass",Vector3(0,0.4,0))
        _lathe(site,"CivicFoundationMilled",PackedVector2Array([
            Vector2(0.45,0.0),Vector2(1.65,0.0),Vector2(1.77,0.18),
            Vector2(1.77,0.36),Vector2(1.56,0.45),Vector2(0.45,0.45)
        ]),"ivory",Vector3.ZERO,64)
        _lathe(site,"FloatingObservationCanopy",PackedVector2Array([
            Vector2(0.01,7.04),Vector2(1.4,7.04),Vector2(1.53,7.14),
            Vector2(1.53,7.28),Vector2(1.38,7.40),Vector2(0.01,7.40)
        ]),"ivory",Vector3.ZERO,64)

static func _civic_transit(root:Node3D)->void:
    # A visible third dimension to transit, with milled guide couplings.
    var spline:=PackedVector3Array()
    for i in range(257):
        var a:float=TAU*float(i)/256.0
        spline.append(Vector3(22.2*cos(a),2.35,22.2*sin(a)))
    _instance(root,"ExpressRailRealTubularMesh",_tubular_mesh(spline,0.082,12),"titanium")
    var sleepers:Array[Transform3D]=[]
    var supports:Array[Transform3D]=[]
    for i in range(64):
        var a:float=TAU*float(i)/64.0
        sleepers.append(Transform3D(Basis(Vector3.UP,a).scaled(Vector3(0.29,0.12,0.67)),Vector3(22.2*cos(a),2.33,22.2*sin(a))))
        if i%4==0:
            supports.append(Transform3D(Basis().scaled(Vector3(0.12,1.80,0.12)),Vector3(22.2*cos(a),1.25,22.2*sin(a))))
    var base:=BoxMesh.new()
    base.size=Vector3.ONE
    _batch(root,"ExpressRailFasteners_64",base,sleepers,"bronze")
    _batch(root,"ElevatedExpressRailPylons_16",base,supports,"titanium")

static func _vehicle_micro_detail(car:Node3D,index:int)->void:
    var hero:=Node3D.new()
    hero.name="AutonomousVehicleHero_%02d"%index
    car.add_child(hero)
    _lathe(hero,"ThrustBearingShell",PackedVector2Array([
        Vector2(0.12,-0.11),Vector2(0.31,-0.09),Vector2(0.35,-0.04),
        Vector2(0.35,0.06),Vector2(0.24,0.12),Vector2(0.12,0.12)
    ]),"bronze",Vector3(-0.30,-0.07,0),24)
    _box(hero,"FrontAutonomyLidar",Vector3(0.34,0.17,0),Vector3(0.12,0.12,0.22),"glass")
    for side in [-1.0,1.0]:
        _box(hero,"WingtipCoilGuide",Vector3(0,0,0.37*side),Vector3(0.52,0.06,0.075),"titanium")