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
## R19: the last 1,800 world-spanning facade/roof instances are six independent
## local-bound sectors. Buildings retain their colors and physical positions.
const DETAIL_LIMIT = [1180.0, 820.0, 460.0]
const ROOF_LIMIT = [1550.0, 1100.0, 600.0]
var r19_quality: int = 0
var r19_centres: Array = []
var r19_facade_chunks: Array[MultiMeshInstance3D] = []
var r19_roof_chunks: Array[MultiMeshInstance3D] = []
var r19_facade_instance_count: int = 0
var r19_roof_instance_count: int = 0
var r20_facade_baked: bool = false

func _r20_exact_glazing() -> Dictionary:
    var textures: Dictionary = {}
    for channel in ["albedo", "emission"]:
        var resource: String = "res://assets/r20_baked/facade_" + channel + ".png"
        if not ResourceLoader.exists(resource):
            return {}
        var tex: Texture2D = ResourceLoader.load(resource) as Texture2D
        if tex == null or tex.get_width() != 256 or tex.get_height() != 512:
            return {}
        textures[channel] = tex
    return textures

func _facade_material(albedo_tex: Texture2D, emission_tex: Texture2D) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.albedo_texture = albedo_tex
    m.emission_enabled = true
    m.emission_texture = emission_tex
    m.emission = Color.WHITE
    m.emission_energy_multiplier = 0.24
    m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    m.albedo_color = Color(0.65, 0.73, 0.81)
    m.metallic = 0.61
    m.roughness = 0.43
    return m

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
    var exact_atlas: Dictionary = _r20_exact_glazing()
    if not exact_atlas.is_empty():
        r20_facade_baked = true
        return _facade_material(exact_atlas["albedo"], exact_atlas["emission"])
    # R5 256x512 day/night facade atlas: 16 columns x 32 floors of varied glazing.
    # Albedo and emission are separated so concrete and steel DO NOT glow.
    var albedo_image := Image.create(256, 512, false, Image.FORMAT_RGBA8)
    var emission_image := Image.create(256, 512, false, Image.FORMAT_RGBA8)
    for y in 512:
        var floor_id: int = int(y / 16)
        var ly: int = y % 16
        for x in 256:
            var column: int = int(x / 16)
            var lx: int = x % 16
            var hash_value: int = (floor_id * 73 + column * 131 + floor_id * column * 17) % 100
            var mullion: bool = lx <= 2 or lx >= 14
            var lintel: bool = ly <= 2 or ly >= 14
            var glass: bool = not mullion and not lintel
            var lit: bool = hash_value < 38 and floor_id % 7 != 0
            var warm: bool = hash_value % 4 == 0
            var pane := Color(0.044, 0.075, 0.104)
            var glow := Color.BLACK
            if mullion or lintel:
                pane = Color(0.021, 0.034, 0.052) if lx % 2 == 0 else Color(0.038, 0.055, 0.069)
            elif glass:
                if lit:
                    var source := Color(0.81, 0.62, 0.37) if warm else Color(0.37, 0.65, 0.78)
                    # Vertical shading and dark lintels keep each pane volumetric.
                    var exposure: float = 0.69 + float(ly) / 31.0
                    pane = source * exposure
                    glow = source * (0.48 if warm else 0.40)
                else:
                    var reflection: float = 0.73 + float((column * 11 + floor_id * 3) % 7) / 32.0
                    pane = Color(0.039, 0.099, 0.145) * reflection
                if lx == 4 or lx == 13:
                    pane = pane.darkened(0.29)
            albedo_image.set_pixel(x, y, pane)
            emission_image.set_pixel(x, y, glow)
    albedo_image.generate_mipmaps()
    emission_image.generate_mipmaps()
    return _facade_material(
        ImageTexture.create_from_image(albedo_image),
        ImageTexture.create_from_image(emission_image))

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
    r19_centres = sector_centers.duplicate()
    _build_facade_fins(tower_data, sector_colors)
    _build_roof_structures(tower_data, sector_colors)
    _build_skybridges(sector_centers, sector_colors)
    for i in sector_centers.size():
        _build_station(sector_centers[i], sector_colors[i], i)
    _build_distant_planet()
    set_quality(0)

func _sector_sizes(towers: Array[Dictionary]) -> Array[int]:
    var totals: Array[int] = []
    for sector in r19_centres.size():
        totals.append(0)
    for tower in towers:
        var district: int = int(tower["sector"])
        totals[district] += 1
    return totals

func _build_facade_fins(towers: Array[Dictionary], colors: Array) -> void:
    var parent := Node3D.new()
    parent.name = "PremiumFacadeFins"
    add_child(parent)
    var metal := _material(Color(0.43, 0.67, 0.84), 0.4)
    metal.vertex_color_use_as_albedo = true
    var sizes: Array[int] = _sector_sizes(towers)
    var mesh_shape := BoxMesh.new()
    var batches: Array[MultiMesh] = []
    var next_slot: Array[int] = []
    for sector in r19_centres.size():
        var mesh_batch := MultiMesh.new()
        mesh_batch.transform_format = MultiMesh.TRANSFORM_3D
        mesh_batch.use_colors = true
        mesh_batch.mesh = mesh_shape
        mesh_batch.instance_count = sizes[sector] * 4
        batches.append(mesh_batch)
        next_slot.append(0)
        var draw := MultiMeshInstance3D.new()
        draw.name = "R19_FacadeDistrict_%02d" % sector
        draw.position = r19_centres[sector]
        draw.multimesh = mesh_batch
        draw.material_override = metal
        parent.add_child(draw)
        r19_facade_chunks.append(draw)
    for t in towers:
        var district: int = int(t["sector"])
        var pos: Vector3 = t["pos"] - r19_centres[district]
        var w: float = t["w"]
        var h: float = t["h"]
        var depth: float = t["depth"]
        var col: Color = colors[district].darkened(0.30)
        var corners: Array[Vector3] = [
            Vector3(-w * 0.46, 0, -depth * 0.51),
            Vector3(w * 0.46, 0, -depth * 0.51),
            Vector3(-w * 0.46, 0, depth * 0.51),
            Vector3(w * 0.46, 0, depth * 0.51)
        ]
        for j in 4:
            var slot: int = next_slot[district]
            batches[district].set_instance_transform(slot,
                Transform3D(Basis.IDENTITY.scaled(Vector3(0.85, h, 0.85)), pos + corners[j]))
            batches[district].set_instance_color(slot, col)
            next_slot[district] += 1
            r19_facade_instance_count += 1
    window_instances = r19_facade_instance_count

func _build_roof_structures(towers: Array[Dictionary], colors: Array) -> void:
    var parent := Node3D.new()
    parent.name = "LuxuryRoofTerraces"
    add_child(parent)
    var material := _material(Color.WHITE, 0.18)
    material.vertex_color_use_as_albedo = true
    var cylinder := CylinderMesh.new()
    var sizes: Array[int] = _sector_sizes(towers)
    var batches: Array[MultiMesh] = []
    var next_slot: Array[int] = []
    for sector in r19_centres.size():
        var batch := MultiMesh.new()
        batch.transform_format = MultiMesh.TRANSFORM_3D
        batch.use_colors = true
        batch.mesh = cylinder
        batch.instance_count = sizes[sector]
        batches.append(batch)
        next_slot.append(0)
        var draw := MultiMeshInstance3D.new()
        draw.name = "R19_RoofDistrict_%02d" % sector
        draw.position = r19_centres[sector]
        draw.multimesh = batch
        draw.material_override = material
        parent.add_child(draw)
        r19_roof_chunks.append(draw)
    for t in towers:
        var district: int = int(t["sector"])
        var position: Vector3 = t["pos"] - r19_centres[district] + Vector3(
            0, float(t["h"]) * 0.5 + 2.6, 0)
        var radius: float = minf(float(t["w"]), float(t["depth"])) * 0.31
        var slot: int = next_slot[district]
        batches[district].set_instance_transform(slot,
            Transform3D(Basis.IDENTITY.scaled(Vector3(radius, 2.6, radius)), position))
        batches[district].set_instance_color(slot, colors[district].darkened(0.40))
        next_slot[district] += 1
        r19_roof_instance_count += 1

func set_quality(mode: int) -> void:
    r19_quality = clampi(mode, 0, 2)
    for facade in r19_facade_chunks:
        if is_instance_valid(facade):
            facade.visibility_range_end = DETAIL_LIMIT[r19_quality]
            facade.visibility_range_end_margin = 150.0
    for roof in r19_roof_chunks:
        if is_instance_valid(roof):
            roof.visibility_range_end = ROOF_LIMIT[r19_quality]
            roof.visibility_range_end_margin = 175.0

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
    var trim := _material(tint.darkened(0.32),0.42)
    # Matte hub, precise rings, service decks and visible landing architecture.
    _cylinder(station,47.0,7.0,Vector3(0,0,0),dark)
    _cylinder(station,35.0,0.45,Vector3(0,3.7,0),steel)
    _ring(station,49.0,0.32,4.0,trim)
    _ring(station,35.0,0.13,4.1,trim)
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
    # R7: eliminate the old floating cyan holographic ring.
    # Replace it with a physical gantry spanning the departure corridor.
    var framing := _material(Color(0.24, 0.31, 0.34), 0.0, 0.82, 0.42)
    var signage := _material(Color(0.69, 0.43, 0.19), 0.24, 0.76, 0.36)
    for side in [-1.0, 1.0]:
        _box(station, Vector3(side * 26.0, 25.0, -28.0),
             Vector3(3.8, 42.0, 5.5), dark)
        _box(station, Vector3(side * 26.0, 33.0, -31.0),
             Vector3(1.0, 24.0, 1.3), framing)
        _box(station, Vector3(side * 26.0, 4.3, -28.0),
             Vector3(8.2, 1.4, 8.5), steel)
        for tier in 6:
            _box(station, Vector3(side * 26.0, 12.0 + float(tier) * 5.4, -31.0),
                 Vector3(4.5, 0.40, 1.5), framing)
    _box(station, Vector3(0, 47.0, -28.0), Vector3(56.0, 3.0, 6.5), dark)
    _box(station, Vector3(0, 48.6, -28.0), Vector3(62.0, 0.65, 7.0), steel)
    _box(station, Vector3(0, 43.2, -31.5), Vector3(24.0, 0.6, 0.8), signage)
    for j in 7:
        var x: float = -21.0 + float(j) * 7.0
        _box(station, Vector3(x, 48.1, -32.3),
             Vector3(0.6, 3.2, 0.5), framing)
    # Real maintenance housings and readable low-energy approach lights.
    for side in [-1.0, 1.0]:
        for j in 4:
            var z: float = -8.0 + float(j) * 10.0
            _box(station, Vector3(side * 38.0, 5.5, z),
                 Vector3(2.2, 2.3, 4.7), steel)
            _box(station, Vector3(side * 38.0, 7.0, z),
                 Vector3(0.9, 0.15, 1.2), signage)
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
