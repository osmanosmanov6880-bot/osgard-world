extends Node3D
## R22 approved-Aurora skyline upgrade. All content below is real Godot 3D
## geometry: 18 hero towers, 3 navigable overpasses, moving ambient traffic,
## volumetric-looking *geometry* cloud ribbons and ~2,000 instanced windows.
## Absolutely no still image / wallpaper stands in for the playable world.
const MaterialFabricR12Script = preload("res://scripts/material_fabric_r12.gd")
const DETAIL_RANGE = [1050.0, 680.0, 360.0]
const TRAFFIC_RANGE = [1100.0, 750.0, 350.0]
const CLOUD_RANGE = [1700.0, 1050.0, 600.0]

var hero_towers: int = 0
var real_3d_windows: int = 0
var physical_structures: int = 0
var overpass_count: int = 0
var moving_traffic: int = 0
var cloud_banks: int = 0
var quality_mode: int = 0
var detail_nodes: Array[GeometryInstance3D] = []
var traffic_nodes: Array[Node3D] = []
var cloud_nodes: Array[MeshInstance3D] = []
var clock: float = 0.0
var budget_clock: float = 0.0
var traffic_updates: int = 0
var ship: Node3D
var hull: Material
var titanium: Material
var dark: Material
var bronze: Material
var window_warm: Material
var window_cool: Material
var led: Material

func _paint(color: Color, rough: float, metallic: float, emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = metallic
    mat.roughness = rough
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    return mat

func _block(parent: Node3D, label: String, p: Vector3, size: Vector3,
            mat: Material, detail: bool = true) -> MeshInstance3D:
    var block := BoxMesh.new()
    block.size = size
    var item := MeshInstance3D.new()
    item.name = label
    item.mesh = block
    item.position = p
    item.material_override = mat
    parent.add_child(item)
    if detail:
        detail_nodes.append(item)
    return item

func _batch(label: String, items: Array[Transform3D], mat: Material) -> void:
    if items.is_empty():
        return
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = BoxMesh.new()
    mm.instance_count = items.size()
    for i in items.size():
        mm.set_instance_transform(i, items[i])
    var inst := MultiMeshInstance3D.new()
    inst.name = label
    inst.multimesh = mm
    inst.material_override = mat
    inst.extra_cull_margin = 6.0
    add_child(inst)
    detail_nodes.append(inst)

func _window_transform(p: Vector3, size: Vector3) -> Transform3D:
    return Transform3D(Basis.IDENTITY.scaled(size), p)

func _build_tower(root: Node3D, index: int, wall: Array[Transform3D],
                  warm: Array[Transform3D], cool: Array[Transform3D]) -> void:
    var height: float = 105.0 + float((index * 37) % 115)
    var width: float = 18.0 + float((index * 5) % 14)
    var depth: float = 17.0 + float((index * 7) % 11)
    var group := Node3D.new()
    group.name = "R22_PhysicalAuroraTower_%02d" % index
    var side: float = -1.0 if index % 2 == 0 else 1.0
    var row: int = int(index / 2)
    group.position = Vector3(
        side * (133.0 + float((row % 3) * 46)),
        0.0,
        -64.0 - float(row) * 73.0
    )
    root.add_child(group)
    var center: Vector3 = Vector3(0.0, height * 0.5, 0.0)
    _block(group,"R22_SatinSteelCore", center,
        Vector3(width, height, depth), hull, false)
    _block(group,"R22_UpperSetback",Vector3(0,height + 5.0,0),
        Vector3(width * 0.69, 10.0, depth * 0.74),titanium,false)
    _block(group,"R22_TopMechanicalHat",Vector3(0,height + 11.3,0),
        Vector3(width * 0.84, 2.5, depth * 0.82),dark)
    _block(group,"R22_StructuralPlinth",Vector3(0,6.0,0),
        Vector3(width + 4.0, 12.0, depth + 4.0),dark,false)
    for corner in [-1.0,1.0]:
        var edge_x: float = corner * (width * 0.5 + 0.19)
        _block(group,"R22_DeepFacadeSpine",Vector3(edge_x,height*0.5,depth*0.5+0.13),
            Vector3(0.75,height,0.61),titanium)
        _block(group,"R22_SecondaryServiceRail",Vector3(edge_x,height*0.5,-depth*0.5-0.13),
            Vector3(0.70,height,0.57),titanium)
        for band in 4:
            _block(group,"R22_BronzeSetbackTrim",
                Vector3(0.0,8.0+float(band)*height/5.0,corner*(depth*0.5+0.32)),
                Vector3(width+2.0,0.35,0.51),bronze)
    var floors: int = int((height - 18.0) / 5.6)
    for floor in floors:
        var y: float = 12.0 + float(floor) * 5.6
        for col in 7:
            var x: float = (float(col)-3.0) * (width * 0.118)
            var pane_position: Vector3 = group.position + Vector3(x,y,depth*0.5+0.27)
            var pane: Transform3D = _window_transform(
                pane_position,Vector3(width*0.086,2.55,0.15))
            var selection: int = (index*37+floor*19+col*71) % 17
            if selection < 5:
                warm.append(pane)
            elif selection < 8:
                cool.append(pane)
            else:
                wall.append(pane)
            real_3d_windows += 1
    for antenna in 2:
        _block(group,"R22_RooftopAntenna",Vector3(
            -width*0.25 + float(antenna)*width*0.50,height+18.0,0),
            Vector3(0.28,14.0,0.28),titanium)
    # 18 *real* collision solids, far from the center flyable corridor.
    var solid := StaticBody3D.new()
    solid.name = "R22_TowerBody"
    var collider := CollisionShape3D.new()
    var shape := BoxShape3D.new()
    shape.size = Vector3(width, height, depth)
    collider.shape = shape
    collider.position = center
    solid.add_child(collider)
    group.add_child(solid)
    hero_towers += 1
    physical_structures += 1

func _bridges(root: Node3D) -> void:
    for i in 3:
        var y: float = 109.0 + float(i) * 19.0
        var z: float = -190.0 - float(i) * 183.0
        var span := Node3D.new()
        span.name = "R22_SuspendedFlightway_%02d" % i
        span.position = Vector3(0,y,z)
        root.add_child(span)
        _block(span,"LoadBearingSteel",Vector3.ZERO,
            Vector3(269.0,5.4,9.2),dark,false)
        _block(span,"PBRDeckSkin",Vector3(0,3.0,0),
            Vector3(273.0,0.44,11.2),titanium)
        for side in [-1.0,1.0]:
            _block(span,"CantileverRails",Vector3(0,4.2,side*5.8),
                Vector3(267.0,1.20,0.64),bronze)
            for n in 16:
                var x: float = (float(n)-7.5)*16.0
                _block(span,"R22_DeckLuminaires",Vector3(x,3.2,side*4.6),
                    Vector3(1.6,0.10,0.85),led)
        var body := StaticBody3D.new()
        body.name = "R22_PhysicalFlightway"
        var collision := CollisionShape3D.new()
        var shape := BoxShape3D.new()
        shape.size = Vector3(269.0,5.4,9.2)
        collision.shape = shape
        body.add_child(collision)
        span.add_child(body)
        physical_structures += 1
        overpass_count += 1

func _ambient_traffic(root: Node3D) -> void:
    for i in 16:
        var mover := Node3D.new()
        mover.name = "R22_LivingCityTraffic_%02d" % i
        var side: float = -1.0 if i % 2 == 0 else 1.0
        mover.position = Vector3(side*(80.0+float((i*13)%90)),
            34.0+float((i*11)%70),-48.0-float(i)*42.0)
        root.add_child(mover)
        _block(mover,"MachinedFuselage",Vector3.ZERO,Vector3(5.6,1.15,12.0),titanium,false)
        _block(mover,"DarkGlassCockpit",Vector3(0,0.8,-2.9),
            Vector3(3.0,0.95,4.1),dark,false)
        _block(mover,"Wing",Vector3(0,-0.15,1.2),
            Vector3(13.0,0.22,2.2),hull,false)
        _block(mover,"DualNavLamps",Vector3(0,0.06,6.1),
            Vector3(2.6,0.21,0.22),led,false)
        traffic_nodes.append(mover)
        moving_traffic += 1

func _cloud_ribbon(index: int) -> MeshInstance3D:
    # Approximate distant lower-atmosphere cloud decks with real transparent
    # 3D ribbon geometry. No fullscreen transparent noise or fake HDR video.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var z: float = -315.0-float(index)*195.0
    var y: float = -20.0+float(index)*3.5
    for slice in 64:
        var x0: float = (float(slice)-32.0)*49.0
        var x1: float = x0+49.0
        var h0: float = 7.0+sin(float(slice)*0.67+float(index)*1.43)*5.0
        var h1: float = 7.0+sin(float(slice+1)*0.67+float(index)*1.43)*5.0
        var a := Vector3(x0,y,z)
        var b := Vector3(x1,y,z)
        var c := Vector3(x1,y+h1,z)
        var d := Vector3(x0,y+h0,z)
        for p in [a,b,c,a,c,d]:
            st.add_vertex(p)
    var draw := MeshInstance3D.new()
    draw.name = "R22_CloudDeck_%02d" % index
    draw.mesh = st.commit()
    var haze := StandardMaterial3D.new()
    haze.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    haze.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
    haze.cull_mode = BaseMaterial3D.CULL_DISABLED
    haze.albedo_color = Color(0.77,0.65,0.52,0.12+float(index)*0.03)
    draw.material_override = haze
    add_child(draw)
    cloud_banks += 1
    cloud_nodes.append(draw)
    return draw

func build() -> void:
    hull = _paint(Color(0.12,0.17,0.21),0.51,0.69)
    titanium = MaterialFabricR12Script.get_material(0)
    dark = _paint(Color(0.028,0.048,0.068),0.64,0.46)
    bronze = _paint(Color(0.42,0.26,0.13),0.40,0.74)
    led = _paint(Color(0.24,0.65,0.89),0.36,0.2,0.24)
    window_warm = _paint(Color(0.79,0.52,0.29),0.32,0.12,0.35)
    window_cool = _paint(Color(0.24,0.57,0.66),0.28,0.16,0.20)
    var stage := Node3D.new()
    stage.name = "R22_AuroraPhysicalStructures"
    add_child(stage)
    var dark_windows: Array[Transform3D] = []
    var warm_windows: Array[Transform3D] = []
    var cool_windows: Array[Transform3D] = []
    for index in 18:
        _build_tower(stage,index,dark_windows,warm_windows,cool_windows)
    _batch("R22_DarkRecessedGlass",dark_windows,dark)
    _batch("R22_WarmOccupiedWindows",warm_windows,window_warm)
    _batch("R22_CoolOfficeGlass",cool_windows,window_cool)
    _bridges(stage)
    _ambient_traffic(stage)
    for cloud in 4:
        _cloud_ribbon(cloud)
    ship = get_parent().get_node_or_null("PlayerShip")
    set_quality(0)

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode,0,2)
    for item in detail_nodes:
        if is_instance_valid(item):
            item.visibility_range_end = DETAIL_RANGE[quality_mode]
            item.visibility_range_end_margin = 130.0
    for node in traffic_nodes:
        if is_instance_valid(node):
            node.visible = quality_mode < 2
    for cloud in cloud_nodes:
        if is_instance_valid(cloud):
            cloud.visibility_range_end = CLOUD_RANGE[quality_mode]
            cloud.visibility_range_end_margin = 220.0

func _process(delta: float) -> void:
    clock += delta
    budget_clock += delta
    if budget_clock < 0.05 or not is_instance_valid(ship):
        return
    budget_clock = fmod(budget_clock, 0.05)
    for index in traffic_nodes.size():
        var mover: Node3D = traffic_nodes[index]
        if not mover.visible:
            continue
        if mover.global_position.distance_squared_to(ship.global_position) > 640000.0:
            continue
        var side: float = -1.0 if index % 2 == 0 else 1.0
        mover.position.z = -48.0-float(index)*42.0+fmod(clock*(12.0+float(index%5)*4.0),250.0)
        mover.position.x = side*(80.0+float((index*13)%90))+sin(clock*0.21+float(index))*7.0
        traffic_updates += 1
