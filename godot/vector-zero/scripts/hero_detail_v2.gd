extends RefCounted
## OSGARD / BLACKFIELD: original hero-asset geometry, second density pass.
## Real indexed ArrayMesh surfaces, helical copper, CNC turned parts and GPU batches.
## Designed to remain legible in Godot's GL Compatibility Web renderer.

const GUNMETAL := Color(0.17, 0.22, 0.27)
const CERAMIC := Color(0.54, 0.59, 0.61)
const BRUSHED := Color(0.42, 0.50, 0.54)
const COPPER := Color(0.54, 0.29, 0.15)
const CYAN := Color(0.13, 0.65, 0.82)
const VIOLET := Color(0.55, 0.31, 0.81)
const AMBER := Color(0.80, 0.40, 0.13)
const GRAPHITE := Color(0.075, 0.11, 0.15)

static var mats: Dictionary = {}
static var scratch_map: ImageTexture

static func build(world: Node3D, core: Node3D, magnet: Node3D, receiver: Node3D) -> void:
    _materials()
    var facility := Node3D.new()
    facility.name = "HeroFacilityV2"
    world.add_child(facility)
    _pipeworks(facility)
    _precision_injector(facility)
    var armature := Node3D.new()
    armature.name = "HeroPlasmaCoreV2"
    core.add_child(armature)
    _plasma_armature(armature)
    var induction := Node3D.new()
    induction.name = "HeroMagnetV2"
    magnet.add_child(induction)
    _superconducting_magnet(induction)
    var iris := Node3D.new()
    iris.name = "HeroCaptureIrisV2"
    receiver.add_child(iris)
    _servo_iris(iris)

static func _materials() -> void:
    if not mats.is_empty():
        return
    var img := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    for y in range(128):
        for x in range(128):
            var ripple: float = sin(float(y) * 1.11) * 0.014 + sin(float(y) * 0.13) * 0.037
            var chip: float = sin(float(x * 17 + y * 37) * 0.51) * 0.011
            img.set_pixel(x, y, Color(0.5 + ripple, 0.5 + chip, 0.994, 1.0))
    scratch_map = ImageTexture.create_from_image(img)
    mats["gunmetal"] = _mat(GUNMETAL, 0.82, 0.29, 0.0, true)
    mats["ceramic"] = _mat(CERAMIC, 0.10, 0.55, 0.0, false)
    mats["steel"] = _mat(BRUSHED, 0.89, 0.24, 0.0, true)
    mats["copper"] = _mat(COPPER, 0.90, 0.28, 0.0, true)
    mats["cyan"] = _mat(CYAN, 0.10, 0.18, 1.25, false)
    mats["violet"] = _mat(VIOLET, 0.13, 0.19, 0.95, false)
    mats["amber"] = _mat(AMBER, 0.12, 0.26, 0.80, false)
    mats["black"] = _mat(GRAPHITE, 0.68, 0.38, 0.0, true)

static func _mat(color: Color, metallic: float, roughness: float, glow: float, scratches: bool) -> StandardMaterial3D:
    var result := StandardMaterial3D.new()
    result.albedo_color = color
    result.metallic = metallic
    result.roughness = roughness
    if glow > 0.0:
        result.emission_enabled = true
        result.emission = color
        result.emission_energy_multiplier = glow
    if scratches:
        result.normal_enabled = true
        result.normal_texture = scratch_map
        result.normal_scale = 0.35
        result.uv1_triplanar = true
    return result

static func _mesh_node(parent: Node3D, title: String, mesh: Mesh, kind: String, pos: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var inst := MeshInstance3D.new()
    inst.name = title
    inst.mesh = mesh
    inst.material_override = mats[kind]
    inst.position = pos
    parent.add_child(inst)
    return inst

static func _turn_mesh(profile: PackedVector2Array, sides: int = 64) -> ArrayMesh:
    # Real indexed lathe: the profile determines the silhouette instead of box stacking.
    var vertices := PackedVector3Array()
    var uv := PackedVector2Array()
    var normals := PackedVector3Array()
    var indices := PackedInt32Array()
    for j in range(profile.size()):
        var here: Vector2 = profile[j]
        var before: Vector2 = profile[maxi(j - 1, 0)]
        var after: Vector2 = profile[mini(j + 1, profile.size() - 1)]
        var tangent: Vector2 = (after - before).normalized()
        var n2: Vector2 = Vector2(tangent.y, -tangent.x)
        for i in range(sides + 1):
            var a: float = TAU * float(i) / float(sides)
            var ca: float = cos(a)
            var sa: float = sin(a)
            vertices.append(Vector3(ca * here.x, here.y, sa * here.x))
            normals.append(Vector3(ca * n2.x, n2.y, sa * n2.x).normalized())
            uv.append(Vector2(float(i) / float(sides), float(j) / float(profile.size() - 1)))
    for j in range(profile.size() - 1):
        for i in range(sides):
            var index: int = j * (sides + 1) + i
            var right: int = index + sides + 1
            indices.append_array(PackedInt32Array([index, right, index + 1, right, right + 1, index + 1]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uv
    arrays[Mesh.ARRAY_INDEX] = indices
    var result := ArrayMesh.new()
    result.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return result

static func _tube_mesh(points: PackedVector3Array, radius: float, sides: int = 10) -> ArrayMesh:
    # CNC coolant tubes and continuous magnetic windings. Smooth, not short cylinders.
    var vertices := PackedVector3Array()
    var normals := PackedVector3Array()
    var uvs := PackedVector2Array()
    var indices := PackedInt32Array()
    for i in range(points.size()):
        var pa: Vector3 = points[maxi(0, i - 1)]
        var pb: Vector3 = points[mini(points.size() - 1, i + 1)]
        var tangent: Vector3 = (pb - pa).normalized()
        if tangent.length_squared() < 0.1:
            tangent = Vector3.UP
        var axis: Vector3 = Vector3.FORWARD if absf(tangent.dot(Vector3.UP)) > 0.87 else Vector3.UP
        var normal: Vector3 = tangent.cross(axis).normalized()
        var binormal: Vector3 = tangent.cross(normal).normalized()
        for j in range(sides + 1):
            var a: float = TAU * float(j) / float(sides)
            var radial: Vector3 = (normal * cos(a) + binormal * sin(a))
            vertices.append(points[i] + radial * radius)
            normals.append(radial)
            uvs.append(Vector2(float(j) / float(sides), float(i) / 20.0))
    for i in range(points.size() - 1):
        for j in range(sides):
            var id: int = i * (sides + 1) + j
            var other: int = id + sides + 1
            indices.append_array(PackedInt32Array([id, id + 1, other, id + 1, other + 1, other]))
    var arrays: Array = []
    arrays.resize(Mesh.ARRAY_MAX)
    arrays[Mesh.ARRAY_VERTEX] = vertices
    arrays[Mesh.ARRAY_NORMAL] = normals
    arrays[Mesh.ARRAY_TEX_UV] = uvs
    arrays[Mesh.ARRAY_INDEX] = indices
    var mesh := ArrayMesh.new()
    mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
    return mesh

static func _turn(parent: Node3D, name: String, profile: PackedVector2Array, kind: String, pos: Vector3 = Vector3.ZERO, sides: int = 64) -> MeshInstance3D:
    return _mesh_node(parent, name, _turn_mesh(profile, sides), kind, pos)

static func _box(parent: Node3D, name: String, p: Vector3, size: Vector3, kind: String) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    return _mesh_node(parent, name, mesh, kind, p)

static func _bolt_instances(parent: Node3D, name: String, radius: float, y: float, amount: int, kind: String, size: float = 0.052) -> void:
    var mesh := CylinderMesh.new()
    mesh.top_radius = 0.76
    mesh.bottom_radius = 0.76
    mesh.height = 1.0
    mesh.radial_segments = 8
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    multi.mesh = mesh
    multi.instance_count = amount
    for i in range(amount):
        var a: float = TAU * float(i) / float(amount)
        var loc := Vector3(cos(a) * radius, y, sin(a) * radius)
        multi.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(size, size * 1.9, size)), loc))
    var node := MultiMeshInstance3D.new()
    node.name = name
    node.multimesh = multi
    node.material_override = mats[kind]
    parent.add_child(node)

static func _helical_winding(root: Node3D, name: String, radius: float, y1: float, y2: float, loops: float, offset: float, size: float, kind: String) -> void:
    var pts := PackedVector3Array()
    for i in range(321):
        var t: float = float(i) / 320.0
        var theta: float = loops * TAU * t + offset
        pts.append(Vector3(radius * cos(theta), lerpf(y1, y2, t), radius * sin(theta)))
    _mesh_node(root, name, _tube_mesh(pts, size, 8), kind)

static func _plasma_armature(root: Node3D) -> void:
    # The physical projectile remains a clear round target. Heavy plating sits behind
    # its cyan/white emission instead of hiding its recognizable silhouette.
    # Two machined caps leave the luminous plasma visible through the equator.
    _turn(root, "MachinedCoreContainmentShell", PackedVector2Array([
        Vector2(0.12,-0.57),Vector2(0.36,-0.54),Vector2(0.52,-0.47),
        Vector2(0.56,-0.35),Vector2(0.51,-0.29),Vector2(0.41,-0.27)
    ]), "gunmetal", Vector3.ZERO, 72)
    _turn(root, "MachinedCoreUpperShell", PackedVector2Array([
        Vector2(0.42,0.28),Vector2(0.51,0.31),Vector2(0.56,0.37),
        Vector2(0.52,0.47),Vector2(0.36,0.54),Vector2(0.12,0.57)
    ]), "gunmetal", Vector3.ZERO, 72)
    for h in [-0.44, -0.18, 0.20, 0.44]:
        var ring := _turn(root, "OpticalFusionRidge", PackedVector2Array([
            Vector2(0.51, h-0.034), Vector2(0.61,h-0.015),
            Vector2(0.61,h+0.015), Vector2(0.51,h+0.034)
        ]), "steel", Vector3.ZERO, 60)
    _turn(root, "FrontEmitterLens", PackedVector2Array([
        Vector2(0.08,-0.58),Vector2(0.30,-0.56),Vector2(0.36,-0.49),
        Vector2(0.20,-0.39),Vector2(0.08,-0.38)
    ]), "cyan")
    for layer in range(2):
        var t := Node3D.new()
        t.rotation = Vector3(float(layer)*0.72, 0.0, float(layer)*0.61)
        t.name = "GyroMachinedFrame_%d" % layer
        root.add_child(t)
        _turn(t, "AnnularMachinedBearing", PackedVector2Array([
            Vector2(0.66,-0.052),Vector2(0.78,-0.039),Vector2(0.80,-0.017),
            Vector2(0.80,0.017),Vector2(0.78,0.039),Vector2(0.66,0.052)
        ]), "steel", Vector3.ZERO, 72)
        _bolt_instances(t, "CNC_18_TorxFasteners", 0.72, 0.050, 18, "steel", 0.027)

static func _superconducting_magnet(root: Node3D) -> void:
    # Three *continuous* copper superconductors, each a genuine triangulated tube.
    _helical_winding(root, "HelicalSuperconductor_A", 1.87, -2.0, 2.0, 13.5, 0.0, 0.057, "copper")
    _helical_winding(root, "HelicalSuperconductor_B", 1.94, -2.0, 2.0, 13.5, TAU/3.0, 0.046, "steel")
    _helical_winding(root, "FluxTracerHelix", 2.01, -2.0, 2.0, 13.5, 2.0*TAU/3.0, 0.018, "violet")
    _turn(root, "LowerCNCPressureFlange", PackedVector2Array([
        Vector2(1.78,-2.55),Vector2(2.29,-2.55),Vector2(2.42,-2.43),
        Vector2(2.42,-2.26),Vector2(2.27,-2.19),Vector2(1.85,-2.19)
    ]), "gunmetal", Vector3.ZERO, 80)
    _turn(root, "UpperCNCPressureFlange", PackedVector2Array([
        Vector2(1.85,2.20),Vector2(2.30,2.20),Vector2(2.42,2.30),
        Vector2(2.42,2.49),Vector2(2.27,2.60),Vector2(1.78,2.60)
    ]), "steel", Vector3.ZERO, 80)
    for h in [-2.43, 2.43]:
        _bolt_instances(root,"PrecisionFlangeM24_56",2.28,h,56,"steel",0.08)
    for x in [-2.70,2.70]:
        var pipe := PackedVector3Array()
        for i in range(33):
            var t: float = float(i)/32.0
            pipe.append(Vector3(x + signf(x)*0.30*sin(t*PI), -2.25+4.5*t, 0.45*sin(t*PI)))
        _mesh_node(root,"CryogenicCoolantManifold",_tube_mesh(pipe,0.11,12),"copper")
        for k in range(5):
            var h: float = -1.8+float(k)*0.9
            _turn(root,"CeramicFluidFeedthrough",PackedVector2Array([
                Vector2(0.18,h-0.18),Vector2(0.34,h-0.11),
                Vector2(0.34,h+0.11),Vector2(0.18,h+0.18)
            ]),"ceramic",Vector3(x,0,0),24)
    # Arc flash detectors and angled cover panels, intentionally away from shot path.
    for side in range(12):
        var a: float = float(side)*TAU/12.0
        var support := Node3D.new()
        support.rotation.y = a
        support.name = "RadialCNCBrace_%02d" % side
        root.add_child(support)
        _box(support,"ElectroceramicInsulator",Vector3(0,0,2.32),Vector3(0.22,3.15,0.26),"ceramic")
        _box(support,"ConductorReveal",Vector3(0,0,2.49),Vector3(0.08,2.80,0.08),"copper")
        _box(support,"ArcFlashSensor",Vector3(0,1.85,2.50),Vector3(0.17,0.17,0.13),"amber")

static func _servo_iris(root: Node3D) -> void:
    # A working-looking aperture: a clear central hole, twelve overlapping
    # tangential CNC jaws and concentric machined retainers.
    _turn(root,"ReceiverOuterServohousing",PackedVector2Array([
        Vector2(1.14,-0.20),Vector2(1.66,-0.20),Vector2(1.80,-0.13),
        Vector2(1.80,0.13),Vector2(1.68,0.20),Vector2(1.14,0.20)
    ]),"steel",Vector3.ZERO,88).rotation.x=PI*0.5
    var jaws: Array[Transform3D] = []
    for i in range(12):
        var a: float = float(i)*TAU/12.0
        var basis := Basis(Vector3(0,0,1),a)
        basis = basis.scaled(Vector3(0.18,0.58,0.10))
        jaws.append(Transform3D(basis,Vector3(sin(a)*0.98,cos(a)*0.98,0.34)))
    var jaws_mesh := BoxMesh.new()
    jaws_mesh.size=Vector3.ONE
    var mm := MultiMesh.new()
    mm.transform_format=MultiMesh.TRANSFORM_3D
    mm.mesh=jaws_mesh
    mm.instance_count=jaws.size()
    for i in range(jaws.size()):
        mm.set_instance_transform(i,jaws[i])
    var jaws_inst:=MultiMeshInstance3D.new()
    jaws_inst.name="Iris_ServoJaws_12"
    jaws_inst.multimesh=mm
    jaws_inst.material_override=mats["gunmetal"]
    root.add_child(jaws_inst)
    _bolt_instances(root,"Iris_ServoHeads_64",1.58,0.26,64,"steel",0.045)
    var scanner:=PackedVector3Array()
    for i in range(129):
        var a:float=TAU*float(i)/128.0
        scanner.append(Vector3(sin(a)*1.04,cos(a)*1.04,0.38))
    _mesh_node(root,"IrisOpticalScannerRing",_tube_mesh(scanner,0.028,8),"cyan")

static func _precision_injector(root: Node3D) -> void:
    var device := Node3D.new()
    device.name="PrecisionInjectorV2"
    device.position=Vector3(-8.8,0.1,0)
    root.add_child(device)
    _turn(device,"FiveAxisMachinedInjector",PackedVector2Array([
        Vector2(0.18,0.0),Vector2(1.15,0.0),Vector2(1.27,0.13),
        Vector2(1.25,0.31),Vector2(0.96,0.42),Vector2(0.91,1.14),
        Vector2(0.71,1.35),Vector2(0.58,1.65),Vector2(0.60,1.88),
        Vector2(0.53,1.96),Vector2(0.15,1.96)
    ]),"steel",Vector3.ZERO,80)
    for y in [0.36,0.72,1.08,1.51]:
        _turn(device,"AcceleratorCNCTrim",PackedVector2Array([
            Vector2(0.82,y-0.05),Vector2(1.04,y-0.02),
            Vector2(1.04,y+0.02),Vector2(0.82,y+0.05)
        ]),"copper")
    _bolt_instances(device,"InjectorM16Bolts48",1.13,0.29,48,"steel",0.067)

static func _pipeworks(root: Node3D) -> void:
    # Silicon-sealed coolant piping behind gameplay; does not intersect the shot.
    var batches: Array[Transform3D] = []
    for x in [-12.3,12.3]:
        for z in [-6.7,-4.0,0.2,4.0]:
            var path:=PackedVector3Array()
            for i in range(25):
                var t:float=float(i)/24.0
                path.append(Vector3(x+sin(t*PI)*0.20,2.0+5.0*t,z))
            _mesh_node(root,"CoolantUprightSpline",_tube_mesh(path,0.094,10),"copper")
            for j in range(14):
                batches.append(Transform3D(Basis().scaled(Vector3(0.12,0.08,0.15)),Vector3(x,2.0+float(j)*0.38,z)))
    if not batches.is_empty():
        var bmesh:=BoxMesh.new()
        bmesh.size=Vector3.ONE
        var multi:=MultiMesh.new()
        multi.transform_format=MultiMesh.TRANSFORM_3D
        multi.mesh=bmesh
        multi.instance_count=batches.size()
        for i in range(batches.size()):
            multi.set_instance_transform(i,batches[i])
        var inst:=MultiMeshInstance3D.new()
        inst.name="InstancedCoolantPipeSeals_112"
        inst.multimesh=multi
        inst.material_override=mats["gunmetal"]
        root.add_child(inst)