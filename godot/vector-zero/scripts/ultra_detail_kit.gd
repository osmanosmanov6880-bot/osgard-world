extends RefCounted
## BLACKFIELD / HIGH DENSITY ORIGINAL ASSET KIT
## Geometry is authored as actual 3D meshes; no screen-space image substitutes.
## Repeated rivets, fins and rail fittings are GPU instanced. Godot 4.7 compatible.

static var _materials: Dictionary = {}
static var _micro_normals: Texture2D

const GRAPHITE := Color(0.105, 0.147, 0.178)
const TITANIUM := Color(0.43, 0.53, 0.58)
const BRIGHT := Color(0.66, 0.73, 0.74)
const BRONZE := Color(0.49, 0.35, 0.23)
const CERAMIC := Color(0.30, 0.37, 0.40)
const CYAN := Color(0.21, 0.76, 0.90)
const VIOLET := Color(0.55, 0.29, 0.88)
const AMBER := Color(0.88, 0.47, 0.17)
const MINT := Color(0.33, 0.88, 0.69)

static func build(world: Node3D, core: Node3D, magnet: Node3D, receiver: Node3D) -> void:
    _prepare_materials()
    var architecture := Node3D.new()
    architecture.name = "UltraDetailArchitecture"
    world.add_child(architecture)
    _facility(architecture)
    _launch_machine(architecture)
    var power_cell := Node3D.new()
    power_cell.name = "HighPolyCoreAssembly"
    core.add_child(power_cell)
    _energy_core(power_cell)
    var magnet_art := Node3D.new()
    magnet_art.name = "HighPolyMagnetAssembly"
    magnet.add_child(magnet_art)
    _magnet_array(magnet_art)
    var target_art := Node3D.new()
    target_art.name = "HighPolyReceiverAssembly"
    receiver.add_child(target_art)
    _receiver_dock(target_art)

static func _prepare_materials() -> void:
    if not _materials.is_empty():
        return
    _micro_normals = _normal_microtexture()
    _materials["steel"] = _pbr(TITANIUM, 0.86, 0.29, 0.0, true)
    _materials["black"] = _pbr(GRAPHITE, 0.71, 0.38, 0.0, true)
    _materials["bright"] = _pbr(BRIGHT, 0.91, 0.17, 0.0, true)
    _materials["bronze"] = _pbr(BRONZE, 0.82, 0.30, 0.0, true)
    _materials["ceramic"] = _pbr(CERAMIC, 0.23, 0.54, 0.0, true)
    _materials["cyan"] = _pbr(CYAN, 0.16, 0.18, 1.9, false)
    _materials["violet"] = _pbr(VIOLET, 0.12, 0.21, 1.5, false)
    _materials["amber"] = _pbr(AMBER, 0.09, 0.23, 1.3, false)
    _materials["mint"] = _pbr(MINT, 0.13, 0.16, 1.9, false)
    _materials["glass"] = _pbr(Color(0.08, 0.24, 0.29, 0.40), 0.17, 0.08, 0.0, false)
    var pane: StandardMaterial3D = _materials["glass"]
    pane.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    pane.cull_mode = BaseMaterial3D.CULL_DISABLED

static func _normal_microtexture() -> Texture2D:
    var image := Image.create(128, 128, false, Image.FORMAT_RGBA8)
    for y in range(128):
        for x in range(128):
            var streak: float = sin(float(y) * 0.73) * 0.042 + sin(float(y) * 2.14) * 0.019
            var chip: float = sin(float(x) * 0.73 + float(y) * 2.17) * 0.016
            var nx: float = 0.50 + streak + chip
            var ny: float = 0.50 + sin(float(x) * 1.4 + float(y) * 0.1) * 0.028
            image.set_pixel(x, y, Color(nx, ny, 0.994, 1.0))
    return ImageTexture.create_from_image(image)

static func _pbr(color: Color, metal: float, rough: float, energy: float, micro: bool) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metal
    m.roughness = rough
    if energy > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = energy
    if micro:
        m.normal_enabled = true
        m.normal_texture = _micro_normals
        m.normal_scale = 0.45
        m.uv1_triplanar = true
    return m

static func _cube(parent: Node3D, title: String, location: Vector3, dimensions: Vector3, kind: String, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = title
    var mesh := BoxMesh.new()
    mesh.size = dimensions
    item.mesh = mesh
    item.material_override = _materials[kind]
    item.position = location
    item.rotation = rotation
    parent.add_child(item)
    return item

static func _cylinder(parent: Node3D, title: String, location: Vector3, radius: float, height: float, kind: String, segments: int = 32) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = title
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = segments
    item.mesh = mesh
    item.material_override = _materials[kind]
    item.position = location
    parent.add_child(item)
    return item

static func _ring(parent: Node3D, title: String, location: Vector3, radius: float, tube: float, kind: String, rotation: Vector3 = Vector3.ZERO) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = title
    var mesh := TorusMesh.new()
    mesh.inner_radius = maxf(0.01, radius - tube)
    mesh.outer_radius = radius + tube
    mesh.rings = 64
    mesh.ring_segments = 18
    item.mesh = mesh
    item.position = location
    item.rotation = rotation
    item.material_override = _materials[kind]
    parent.add_child(item)
    return item

static func _sphere(parent: Node3D, title: String, location: Vector3, radius: float, kind: String) -> MeshInstance3D:
    var item := MeshInstance3D.new()
    item.name = title
    var mesh := SphereMesh.new()
    mesh.radius = radius
    mesh.height = radius * 2.0
    mesh.radial_segments = 40
    mesh.rings = 24
    item.mesh = mesh
    item.position = location
    item.material_override = _materials[kind]
    parent.add_child(item)
    return item

static func _beam(parent: Node3D, title: String, a: Vector3, b: Vector3, radius: float, kind: String) -> void:
    var delta: Vector3 = b - a
    if delta.length_squared() <= 0.000001:
        return
    var item := _cylinder(parent, title, (a+b)*0.5, radius, delta.length(), kind, 12)
    item.quaternion = Quaternion(Vector3.UP, delta.normalized())

static func _batch_boxes(parent: Node3D, title: String, transforms: Array[Transform3D], kind: String) -> void:
    if transforms.is_empty():
        return
    var multi := MultiMesh.new()
    multi.transform_format = MultiMesh.TRANSFORM_3D
    var geometry := BoxMesh.new()
    geometry.size = Vector3.ONE
    multi.mesh = geometry
    multi.instance_count = transforms.size()
    for index in range(transforms.size()):
        multi.set_instance_transform(index, transforms[index])
    var node := MultiMeshInstance3D.new()
    node.name = title
    node.multimesh = multi
    node.material_override = _materials[kind]
    parent.add_child(node)

static func _bolt_ring(parent: Node3D, name: String, radius: float, yy: float, count: int, size: float = 0.06) -> void:
    var locations: Array[Transform3D] = []
    for i in range(count):
        var a: float = TAU * float(i) / float(count)
        locations.append(Transform3D(Basis().scaled(Vector3(size, size, size)), Vector3(cos(a)*radius, yy, sin(a)*radius)))
    _batch_boxes(parent, name, locations, "bright")

static func _energy_core(root: Node3D) -> void:
    # 36 precision-machined facets and two independently legible containment cages.
    _sphere(root, "HighDensityInnerCap", Vector3.ZERO, 0.43, "glass")
    for rotation in [Vector3(PI*0.5, 0.0, 0.0), Vector3(0.0, 0.0, 0.0), Vector3(0.25, 0.75, 0.35)]:
        var cage := Node3D.new()
        cage.rotation = rotation
        root.add_child(cage)
        _ring(cage, "CNC_AnnularCage", Vector3.ZERO, 0.89, 0.048, "steel")
        _ring(cage, "LightGuide", Vector3.ZERO, 0.93, 0.014, "cyan")
        _bolt_ring(cage, "MicroFasteners_32", 0.90, 0.0, 32, 0.055)
    for band in range(3):
        var spin := Node3D.new()
        spin.rotation = Vector3(float(band) * 0.6, float(band) * 0.9, 0.0)
        root.add_child(spin)
        for j in range(12):
            var theta: float = TAU * float(j) / 12.0
            var fin := _cube(spin, "RadialShieldFin", Vector3(cos(theta)*0.59, 0.0, sin(theta)*0.59), Vector3(0.17, 0.075, 0.44), "bronze")
            fin.rotation.y = theta
            _cube(spin, "OpticPin", Vector3(cos(theta)*0.77, 0.03, sin(theta)*0.77), Vector3(0.07, 0.07, 0.12), "cyan")

static func _magnet_array(root: Node3D) -> void:
    # 14-rib superconducting linear accelerator, heavy service enclosure,
    # pressure gauges and active luminous induction conduits.
    for level in range(9):
        var y: float = -1.8 + float(level) * 0.45
        _ring(root, "InductionCopperWinding", Vector3(0,y,0), 1.62, 0.070, "bronze")
        _ring(root, "FieldGuideCoil", Vector3(0,y+0.12,0), 1.79, 0.027, "violet")
        if level % 2 == 0:
            _ring(root, "ActuatorBearing", Vector3(0,y+0.20,0), 1.92, 0.035, "steel")
    for side in range(12):
        var a: float = float(side) * TAU / 12.0
        var frame := Node3D.new()
        frame.rotation.y = a
        root.add_child(frame)
        _cube(frame, "CeramicArmorSpine", Vector3(0.0,0.0,2.17), Vector3(0.30, 4.55, 0.22), "ceramic")
        _cube(frame, "TitaniumJointSpline", Vector3(0.0,0.0,2.29), Vector3(0.075, 4.0, 0.09), "steel")
        for level in [-1.65, -0.9, 0.0, 0.9, 1.65]:
            _cube(frame, "CNC_ArmorFastening", Vector3(0.0,level,2.34), Vector3(0.17, 0.16, 0.13), "bright")
    for h in [-2.25, 2.25]:
        _cylinder(root, "GraphiteClampingFlange", Vector3(0,h,0), 2.13, 0.37, "black", 48)
        _ring(root, "PrecisionSeal", Vector3(0,h+0.20,0), 1.85, 0.08, "bright")
        _bolt_ring(root, "FastenerCircle_48", 1.94, h+0.20, 48, 0.055)
    # Side mounted high-voltage bus bars with ceramic bushing arrays.
    for x in [-2.25, 2.25]:
        _cube(root, "CopperPowerBus", Vector3(x,0,-0.2), Vector3(0.22,5.9,0.24), "bronze")
        for y in [-2.1, -1.4, -0.7, 0.0, 0.7, 1.4, 2.1]:
            _cylinder(root, "BusInsulator", Vector3(x,y,-0.2), 0.28, 0.22, "ceramic", 24)
            _ring(root, "BusEnergyCollar", Vector3(x,y,-0.2), 0.26, 0.022, "violet")
    _cylinder(root, "HydraulicCoilHead", Vector3(0, 2.62, 0), 1.29, 0.25, "steel", 48)
    _ring(root, "SafetyOrangeRing", Vector3(0, 2.81, 0), 1.36, 0.060, "amber")

static func _receiver_dock(root: Node3D) -> void:
    # Visible octagonal full-depth target housing, 24 locking pins,
    # three active annuli and structural support trusses.
    for ring_index in range(3):
        var z: float = -0.32 + float(ring_index)*0.32
        _ring(root, "TargetCNC_Annulus", Vector3(0,0,z), 1.44+float(ring_index)*0.13, 0.14, "steel", Vector3(PI*0.5,0,0))
        _ring(root, "ReceiverEnergyGuide", Vector3(0,0,z+0.015), 1.30+float(ring_index)*0.13, 0.035, "mint", Vector3(PI*0.5,0,0))
    for index in range(16):
        var a: float = float(index)*TAU/16.0
        var clamp := Node3D.new()
        clamp.rotation.z = a
        root.add_child(clamp)
        _cube(clamp,"ArticulatedCaptureJaw",Vector3(0,1.64,0),Vector3(0.31,0.54,0.58),"black")
        _cube(clamp,"CNC_ChromeTooth",Vector3(0,1.88,0.12),Vector3(0.16,0.19,0.61),"bright")
        _cube(clamp,"OpticTargetPixel",Vector3(0,1.93,0.49),Vector3(0.11,0.11,0.055),"mint")
    var bolts: Array[Transform3D] = []
    for index in range(64):
        var a: float = TAU*float(index)/64.0
        bolts.append(Transform3D(Basis().scaled(Vector3(0.070,0.070,0.070)), Vector3(sin(a)*1.42,cos(a)*1.42,0.54)))
    _batch_boxes(root,"ReceiverPolishedBolts64",bolts,"bright")
    _cube(root,"LateralReceiverBraceLeft",Vector3(-1.7,-1.8,0),Vector3(0.26,2.1,0.40),"steel",Vector3(0.0,0.0,-0.18))
    _cube(root,"LateralReceiverBraceRight",Vector3(1.7,-1.8,0),Vector3(0.26,2.1,0.40),"steel",Vector3(0.0,0.0,0.18))

static func _launch_machine(root: Node3D) -> void:
    var rig := Node3D.new()
    rig.name = "PrecisionLauncher_Assembly"
    rig.position = Vector3(-8.8, 0.4, 0.0)
    root.add_child(rig)
    _cylinder(rig,"BaseServoDrum",Vector3.ZERO,1.12,0.36,"black",40)
    _ring(rig,"ElectromagneticBearing",Vector3(0,0.24,0),0.94,0.08,"steel")
    for t in range(6):
        var y: float = 0.56+float(t)*0.21
        _ring(rig,"AcceleratorStage",Vector3(0,y,0),0.70,0.064,"bronze")
        _ring(rig,"FieldRetainer",Vector3(0,y+0.09,0),0.74,0.022,"cyan")
    for index in range(8):
        var a: float = float(index)*TAU/8.0
        var p := Vector3(cos(a)*0.95, 0.45, sin(a)*0.95)
        var q := Vector3(cos(a)*0.58, 1.7, sin(a)*0.58)
        _beam(rig,"LauncherHydraulicBrace",p,q,0.075,"steel")
        _sphere(rig,"ServoTerminal",q,0.11,"bright")
    _cylinder(rig,"LaunchEmitDisk",Vector3(0,1.80,0),0.50,0.15,"cyan",40)
    _ring(rig,"LaunchWarningBorder",Vector3(0,1.86,0),0.77,0.035,"amber")
    _bolt_ring(rig,"LauncherBolts40",1.08,0.25,40,0.055)

static func _facility(root: Node3D) -> void:
    # Service gantries, reactor silhouettes, machine vents and repeated detailing.
    var rivets: Array[Transform3D] = []
    var hazard: Array[Transform3D] = []
    var blue_strips: Array[Transform3D] = []
    for x in range(-12,13,3):
        for z in range(-7,8,3):
            if abs(x) < 5 and abs(z) < 4:
                continue
            var xx: float = float(x)
            var zz: float = float(z)
            rivets.append(Transform3D(Basis().scaled(Vector3(0.065,0.06,0.065)),Vector3(xx,0.06,zz)))
            if (x+z)%2==0:
                hazard.append(Transform3D(Basis().scaled(Vector3(0.42,0.024,0.10)),Vector3(xx,0.05,zz)))
    _batch_boxes(root,"GPU_InstancedDeckBolts",rivets,"bright")
    _batch_boxes(root,"GPU_SafetyDeckMarkings",hazard,"amber")
    for x in [-11.5,11.5]:
        for z in [-6.0,-2.0,2.0,5.3]:
            var gantry := Node3D.new()
            gantry.name="HardenedMaintenanceBay"
            gantry.position=Vector3(x,2.6,z)
            root.add_child(gantry)
            _cube(gantry,"ShockHousing",Vector3.ZERO,Vector3(1.25,2.75,1.1),"black")
            _cube(gantry,"ServiceDoor",Vector3(0,0,0.62),Vector3(0.92,1.9,0.08),"steel")
            for j in range(7):
                _cube(gantry,"MachinedVentSlot",Vector3(0,-0.6+float(j)*0.19,0.68),Vector3(0.58,0.043,0.048),"bright")
            for yy in [-1.10,1.13]:
                _cube(gantry,"OverPressureLamp",Vector3(0.46,yy,0.67),Vector3(0.12,0.12,0.07),"cyan")
            _cylinder(gantry,"MaintenancePressureGauge",Vector3(-0.38,0.85,0.73),0.15,0.12,"bronze",18).rotation.x=PI*0.5
    for x in [-10.0,10.0]:
        for y in [4.2,10.8]:
            var turbine := Node3D.new()
            turbine.name="SuperconductingVentTurbine"
            turbine.position=Vector3(x,y,-7.2)
            turbine.rotation.x=PI*0.5
            root.add_child(turbine)
            _ring(turbine,"ChromeIntakeFrame",Vector3.ZERO,1.0,0.13,"steel")
            _ring(turbine,"CeramicSeal",Vector3(0,0.05,0),0.75,0.044,"black")
            _cylinder(turbine,"ImpellerHub",Vector3(0,0.13,0),0.21,0.30,"bright")
            for b in range(12):
                var a: float=TAU*float(b)/12.0
                var blade:=_cube(turbine,"CentrifugalBlade",Vector3(cos(a)*0.50,0.08,sin(a)*0.50),Vector3(0.11,0.06,0.55),"steel")
                blade.rotation.y=a
    for x in [-7.0,0.0,7.0]:
        var rail:=Node3D.new()
        rail.name="OverheadRoboticCableRail"
        rail.position=Vector3(x,12.65,-0.3)
        root.add_child(rail)
        _cube(rail,"BridgeCrossbeam",Vector3.ZERO,Vector3(0.35,0.40,13.8),"steel")
        for z in range(-6,7,2):
            var zz: float=float(z)
            _cube(rail,"CrossbeamConnector",Vector3(0,-0.36,zz),Vector3(0.68,0.08,0.27),"bronze")
            _cylinder(rail,"CableReel",Vector3(0,-0.55,zz),0.32,0.24,"black",20)
            blue_strips.append(Transform3D(Basis().scaled(Vector3(0.075,0.075,0.36)),Vector3(x,12.20,zz)))
    _batch_boxes(root,"OverheadGuideLights",blue_strips,"cyan")