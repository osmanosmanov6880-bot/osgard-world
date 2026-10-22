extends Node3D
## Procedural premium geometry for the web-safe GL Compatibility renderer.
## Instancing rather than thousands of individual light nodes keeps draw calls bounded.

const DARK_METAL := Color(0.036, 0.085, 0.14)
const TITANIUM := Color(0.17, 0.28, 0.40)
var towers_built: int = 0
var window_instances: int = 0
var corridor_count: int = 0
var dock_count: int = 0
var animated_holos: Array[Node3D] = []

func _material(color: Color, emission: float = 0.0, metallic: float = 0.76, roughness: float = 0.38) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = color
    m.metallic = metallic
    m.roughness = roughness
    if emission > 0.0:
        m.emission_enabled = true
        m.emission = color
        m.emission_energy_multiplier = emission
    return m

func make_facade_material() -> StandardMaterial3D:
    # Windows are real textured surfaces. A repeated procedural atlas gives each
    # tower dozens of lit floors without generating one draw call per window.
    var image := Image.create(128, 256, false, Image.FORMAT_RGBA8)
    for y in range(256):
        for x in range(128):
            var ix: int = int(x / 17)
            var iy: int = int(y / 13)
            var inside: bool = x % 17 >= 4 and x % 17 <= 13 and y % 13 >= 3 and y % 13 <= 9
            var lit: bool = (ix * 11 + iy * 7 + int(iy * ix / 3)) % 13 < 8
            var color := Color(0.115, 0.19, 0.265)
            if x % 17 <= 1 or y % 13 <= 1:
                color = Color(0.027, 0.055, 0.08)
            elif inside:
                color = Color(0.60, 0.78, 0.84) if lit else Color(0.08, 0.14, 0.19)
            image.set_pixel(x, y, color)
    var texture := ImageTexture.create_from_image(image)
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.albedo_texture = texture
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    m.metallic = 0.66
    m.roughness = 0.42
    m.emission_enabled = true
    m.emission_texture = texture
    m.emission = Color(0.23, 0.42, 0.67)
    m.emission_energy_multiplier = 0.32
    return m

func _box(parent: Node3D, position: Vector3, size: Vector3, material: Material, angle: float = 0.0) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var shape := BoxMesh.new()
    shape.size = size
    mi.mesh = shape
    mi.position = position
    mi.rotation.y = angle
    mi.material_override = material
    parent.add_child(mi)
    return mi

func _ring(parent: Node3D, radius: float, thickness: float, height: float, material: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var ring := TorusMesh.new()
    ring.inner_radius = radius - thickness
    ring.outer_radius = radius
    ring.rings = 64
    ring.ring_segments = 8
    mi.mesh = ring
    mi.material_override = material
    mi.position.y = height
    parent.add_child(mi)
    return mi

func _cylinder(parent: Node3D, radius: float, height: float, position: Vector3, material: Material) -> MeshInstance3D:
    var mi := MeshInstance3D.new()
    var mesh := CylinderMesh.new()
    mesh.top_radius = radius
    mesh.bottom_radius = radius
    mesh.height = height
    mesh.radial_segments = 48
    mi.mesh = mesh
    mi.position = position
    mi.material_override = material
    parent.add_child(mi)
    return mi

func build(tower_data: Array[Dictionary], sector_centers: Array, sector_colors: Array) -> void:
    towers_built = tower_data.size()
    _build_facade_fins(tower_data, sector_colors)
    _build_roof_structures(tower_data, sector_colors)
    _build_skybridges(sector_centers, sector_colors)
    for i in sector_centers.size():
        _build_station(sector_centers[i], sector_colors[i], i)
    _build_distant_planet()

func _build_facade_fins(towers: Array[Dictionary], colors: Array) -> void:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.use_colors = true
    mm.mesh = BoxMesh.new()
    mm.instance_count = towers.size() * 4
    var node := MultiMeshInstance3D.new()
    node.name = "PremiumFacadeFins"
    node.multimesh = mm
    var metal := _material(Color(0.43,0.67,0.84),0.4)
    metal.vertex_color_use_as_albedo = true
    node.material_override = metal
    add_child(node)
    for i in towers.size():
        var t: Dictionary = towers[i]
        var pos: Vector3 = t["pos"]
        var w: float = t["w"]
        var h: float = t["h"]
        var depth: float = t["depth"]
        var col: Color = colors[int(t["sector"])].darkened(0.30)
        var corners: Array[Vector3] = [
            Vector3(-w * 0.46, 0, -depth * 0.51),
            Vector3(w * 0.46, 0, -depth * 0.51),
            Vector3(-w * 0.46, 0, depth * 0.51),
            Vector3(w * 0.46, 0, depth * 0.51)
        ]
        for j in range(4):
            var bar_pos: Vector3 = pos + corners[j]
            mm.set_instance_transform(i*4+j, Transform3D(Basis.IDENTITY.scaled(Vector3(0.85,h,0.85)),bar_pos))
            mm.set_instance_color(i*4+j,col)
    window_instances = towers.size() * 4

func _build_roof_structures(towers: Array[Dictionary], colors: Array) -> void:
    var roofs := MultiMesh.new()
    roofs.transform_format = MultiMesh.TRANSFORM_3D
    roofs.use_colors = true
    roofs.mesh = CylinderMesh.new()
    roofs.instance_count = towers.size()
    var node := MultiMeshInstance3D.new()
    node.name = "LuxuryRoofTerraces"
    node.multimesh = roofs
    var material := _material(Color.WHITE,0.18)
    material.vertex_color_use_as_albedo = true
    node.material_override = material
    add_child(node)
    for i in towers.size():
        var t: Dictionary=towers[i]
        var position: Vector3=t["pos"] + Vector3(0,float(t["h"])*0.5+2.6,0)
        var radius: float=minf(float(t["w"]),float(t["depth"]))*0.31
        roofs.set_instance_transform(i,Transform3D(Basis.IDENTITY.scaled(Vector3(radius,2.6,radius)),position))
        roofs.set_instance_color(i,colors[int(t["sector"])].darkened(0.40))

func _build_skybridges(centers: Array, colors: Array) -> void:
    var alloy := _material(Color(0.08,0.14,0.22))
    var guide := _material(Color(0.12,0.42,0.60),0.9)
    for i in range(centers.size()-1):
        var first: Vector3 = centers[i] + Vector3(0,12.0,0)
        var second: Vector3 = centers[i+1] + Vector3(0,12.0,0)
        var midpoint: Vector3 = (first+second)*0.5
        var vec: Vector3 = second-first
        # Paths are thin and dark; their luminous rails stay subtle in HDR.
        var spine := _box(self,midpoint,Vector3(11.0,1.6,vec.length()),alloy)
        spine.rotation.y = atan2(-vec.x,-vec.z)
        for side in [-1.0,1.0]:
            var rail := _box(spine,Vector3(side*5.6,1.2,0),Vector3(0.30,0.30,vec.length()),guide)
            rail.rotation.y = 0.0
        corridor_count += 1

func _build_station(center: Vector3, tint: Color, index: int) -> void:
    var station := Node3D.new()
    station.name = "CinematicStation_%02d" % index
    station.position = center
    add_child(station)
    var dark := _material(Color(0.065,0.11,0.19),0.0)
    var steel := _material(Color(0.16,0.25,0.35))
    var trim := _material(tint.darkened(0.12),1.15)
    # Matte hub, precise rings, service decks and visible landing architecture.
    _cylinder(station,47.0,7.0,Vector3(0,0,0),dark)
    _cylinder(station,35.0,0.45,Vector3(0,3.7,0),steel)
    _ring(station,49.0,0.8,4.0,trim)
    _ring(station,35.0,0.28,4.1,trim)
    for i in 8:
        var angle: float=TAU*float(i)/8.0
        var ux: float=cos(angle)
        var uz: float=sin(angle)
        _box(station,Vector3(ux*43.0,5.0,uz*43.0),Vector3(5.0,2.2,7.0),steel,angle)
    for i in 4:
        var angle: float=TAU*float(i)/4.0+PI*0.25
        var pos := Vector3(cos(angle)*64.0,0,sin(angle)*64.0)
        _box(station,pos+Vector3(0,29,0),Vector3(8,58,8),dark)
        _box(station,pos+Vector3(0,59,0),Vector3(10,4.0,10),trim)
        _box(station,pos+Vector3(0,40,0),Vector3(11,2,11),steel)
    var ring := _ring(station,17.0,1.0,18.0,trim)
    ring.rotation.x=PI*0.32
    animated_holos.append(ring)
    var label := Label3D.new()
    label.text = "OSGARD // %02d" % (index+1)
    label.font_size = 44
    label.pixel_size = 0.08
    label.modulate = Color(0.68,0.85,0.98)
    label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
    label.position = Vector3(0,74,0)
    station.add_child(label)
    dock_count+=1

func _build_distant_planet() -> void:
    var planet := MeshInstance3D.new()
    planet.name = "NebulaDistantPlanet"
    var sphere := SphereMesh.new()
    sphere.radius = 210.0
    sphere.height = 420.0
    sphere.radial_segments=32
    sphere.rings=16
    planet.mesh = sphere
    planet.material_override = _material(Color(0.24,0.36,0.50),0.04,0.1,0.96)
    planet.position = Vector3(-940,410,-1450)
    add_child(planet)
    var halo := _ring(self,285.0,1.1,0.0,_material(Color(0.33,0.57,0.76),0.24))
    halo.position=planet.position
    halo.rotation = Vector3(PI*0.20,0.0,PI*0.43)

func _process(delta: float) -> void:
    for ring in animated_holos:
        if is_instance_valid(ring):ring.rotation.y += delta*0.16
