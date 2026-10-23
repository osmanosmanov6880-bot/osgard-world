extends Node3D
## R6 skyline sculpture: six physically modelled tapered/twisted arcologies,
## with multi-storey facade bays, terrace rings and support arches.
## Procedural authored geometry; no flat billboards or duplicate box towers.

var landmark_count: int = 0
var facade_fins: int = 0
var steel: StandardMaterial3D
var windows: StandardMaterial3D
var inset: StandardMaterial3D
var copper: StandardMaterial3D
var light: StandardMaterial3D
# R18: tower silhouette remains visible; fine mullions, external steel
# buttresses and crown hardware use sector-level GPU bounds and distance LOD.
const FACADE_RANGE = [950.0, 650.0, 390.0]
var quality_mode: int = 0
var segment_origins: Array[Vector3] = []
var segment_hubs: Array[Node3D] = []
var detail_draws: Array[MultiMeshInstance3D] = []
var facade_batches: int = 0
var exterior_beam_instances: int = 0

func _ready() -> void:
    steel = _material(Color(0.24, 0.28, 0.34), 0.36)
    inset = _material(Color(0.024, 0.034, 0.048), 0.54)
    copper = _material(Color(0.49, 0.31, 0.17), 0.32)
    light = _material(Color(0.18, 0.52, 0.57), 0.37, 0.22)
    windows = _window_atlas()

func _material(color: Color, roughness: float, emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.74
    mat.roughness = roughness
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    return mat

func _window_atlas() -> StandardMaterial3D:
    var diffuse := Image.create(128, 256, false, Image.FORMAT_RGBA8)
    var glow := Image.create(128, 256, false, Image.FORMAT_RGBA8)
    for y in 256:
        for x in 128:
            var band: int = int(y / 8)
            var col: int = int(x / 8)
            var panel: bool = x % 8 >= 2 and x % 8 <= 6 and y % 8 >= 2 and y % 8 <= 6
            var on: bool = ((band * 17 + col * 41 + band * col * 3) % 13) < 4
            var base := Color(0.018, 0.039, 0.060)
            var shine := Color.BLACK
            if panel:
                base = Color(0.065, 0.15, 0.21)
                if on:
                    base = Color(0.50, 0.63, 0.58) if col % 3 == 0 else Color(0.38, 0.56, 0.68)
                    shine = base * 0.30
            elif x % 8 == 0:
                base = Color(0.060, 0.066, 0.075)
            diffuse.set_pixel(x, y, base)
            glow.set_pixel(x, y, shine)
    diffuse.generate_mipmaps()
    glow.generate_mipmaps()
    var mat := _material(Color.WHITE, 0.31)
    mat.albedo_texture = ImageTexture.create_from_image(diffuse)
    mat.emission_enabled = true
    mat.emission = Color.WHITE
    mat.emission_texture = ImageTexture.create_from_image(glow)
    mat.emission_energy_multiplier = 0.48
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    return mat

func _box(parent: Node3D, name: String, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
    var shape := BoxMesh.new()
    shape.size = size
    var mi := MeshInstance3D.new()
    mi.name = name
    mi.position = pos
    mi.mesh = shape
    mi.material_override = mat
    parent.add_child(mi)
    return mi

func _ring(parent: Node3D, name: String, pos: Vector3, radius: float, thickness: float, mat: Material) -> MeshInstance3D:
    var shape := TorusMesh.new()
    shape.inner_radius = radius - thickness
    shape.outer_radius = radius
    shape.rings = 48
    shape.ring_segments = 10
    var mi := MeshInstance3D.new()
    mi.name = name
    mi.mesh = shape
    mi.position = pos
    mi.material_override = mat
    parent.add_child(mi)
    return mi

func _emit(st: SurfaceTool, a: Vector3, uv_a: Vector2, b: Vector3, uv_b: Vector2, c: Vector3, uv_c: Vector2) -> void:
    st.set_uv(uv_a)
    st.add_vertex(a)
    st.set_uv(uv_b)
    st.add_vertex(b)
    st.set_uv(uv_c)
    st.add_vertex(c)

func _profile(height_fraction: float, radius: float, variant: int) -> float:
    var taper: float = 1.06 - height_fraction * (0.32 + float(variant % 3) * 0.035)
    var terrace: float = 0.82 if height_fraction > 0.54 and height_fraction < 0.59 else 1.0
    var shoulder: float = 1.13 if height_fraction > 0.19 and height_fraction < 0.29 else 1.0
    return radius * taper * terrace * shoulder

func _body_mesh(height: float, radius: float, sides: int, twist: float, variant: int) -> ArrayMesh:
    # 32 ring segments, UVs, normals, tangent basis: true 3D curved arcology massing.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var floors: int = 32
    for k in floors:
        var f0: float = float(k) / float(floors)
        var f1: float = float(k + 1) / float(floors)
        var y0: float = f0 * height
        var y1: float = f1 * height
        var r0: float = _profile(f0, radius, variant)
        var r1: float = _profile(f1, radius, variant)
        for j in sides:
            var a0: float = TAU * float(j) / float(sides)
            var a1: float = TAU * float(j + 1) / float(sides)
            var p00 := Vector3(cos(a0 + twist * f0) * r0, y0, sin(a0 + twist * f0) * r0)
            var p10 := Vector3(cos(a1 + twist * f0) * r0, y0, sin(a1 + twist * f0) * r0)
            var p01 := Vector3(cos(a0 + twist * f1) * r1, y1, sin(a0 + twist * f1) * r1)
            var p11 := Vector3(cos(a1 + twist * f1) * r1, y1, sin(a1 + twist * f1) * r1)
            var u0: float = float(j) / float(sides) * 4.0
            var u1: float = float(j + 1) / float(sides) * 4.0
            _emit(st, p00, Vector2(u0, f0 * 28), p01, Vector2(u0, f1 * 28), p11, Vector2(u1, f1 * 28))
            _emit(st, p00, Vector2(u0, f0 * 28), p11, Vector2(u1, f1 * 28), p10, Vector2(u1, f0 * 28))
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

func _beam_transform(start: Vector3, end: Vector3, width: float) -> Transform3D:
    var delta: Vector3 = end - start
    return Transform3D(Basis(Quaternion(Vector3.UP, delta.normalized())).scaled(Vector3(width, delta.length(), width)), (start + end) * 0.5)

func build(centers: Array, tints: Array) -> void:
    var exterior_ribs: Array[Transform3D] = []
    var landing_braces: Array[Transform3D] = []
    var crowns: Array[Transform3D] = []
    for sector in centers.size():
        var h: float = 192.0 + float(sector % 3) * 32.0
        var r: float = 19.0 + float(sector % 2) * 3.5
        var sides: int = 10 + (sector % 3) * 2
        var twist: float = (0.24 if sector % 2 == 0 else -0.40)
        var origin: Vector3 = centers[sector] + Vector3(100.0 + float(sector % 2) * 40.0, 0, -190.0)
        var hub := Node3D.new()
        hub.name = "R6_SculptedArcology_%02d" % sector
        hub.position = origin
        add_child(hub)
        segment_origins.append(origin)
        segment_hubs.append(hub)
        var mesh := MeshInstance3D.new()
        mesh.name = "TwistedSkyscraperMesh_32RingSections"
        mesh.mesh = _body_mesh(h, r, sides, twist, sector)
        mesh.material_override = windows
        hub.add_child(mesh)
        # Solid core collision for high-speed flight navigation; render-mesh independent.
        var hull_collider := StaticBody3D.new()
        hull_collider.name = "ArcologyCollision"
        hull_collider.position.y = h * 0.5
        hub.add_child(hull_collider)
        var solid := CollisionShape3D.new()
        var shape := CylinderShape3D.new()
        shape.radius = r * 1.17
        shape.height = h
        solid.shape = shape
        hull_collider.add_child(solid)
        _box(hub, "ThreeStoreyServicePod", Vector3(0, 10, 0), Vector3(r * 2.5, 19, r * 2.3), inset)
        for level in range(3):
            var y: float = h * (0.27 + float(level) * 0.25)
            var local_radius: float = _profile(y / h, r, sector)
            _ring(hub, "CrownStructuralBand", Vector3(0, y, 0), local_radius + 0.6, 0.25, steel)
            _ring(hub, "BronzeRailGasket", Vector3(0, y + 1.0, 0), local_radius + 0.28, 0.09, copper)
        _box(hub, "MainRoofPlant", Vector3(0, h + 3.0, 0), Vector3(13, 6, 11), inset)
        _ring(hub, "ObservationRim", Vector3(0, h + 2.0, 0), r * 0.75, 0.52, steel)
        for side in [-1.0, 1.0]:
            _box(hub, "CommunicationsRelay", Vector3(side * r * 0.37, h + 13.0, 0), Vector3(1.2, 18, 1.2), steel)
            _box(hub, "BronzeBeacon", Vector3(side * r * 0.37, h + 22.6, 0), Vector3(2.4, 0.75, 2.4), copper)
        for floor in range(18):
            var f: float = 0.06 + float(floor) / 20.0
            var radius: float = _profile(f, r, sector) + 0.58
            for side in range(sides):
                var angle: float = TAU * float(side) / float(sides) + twist * f
                var normal := Vector3(cos(angle), 0, sin(angle))
                exterior_ribs.append(_beam_transform(
                    origin + normal * radius + Vector3(0, f * h - 2.8, 0),
                    origin + normal * radius + Vector3(0, f * h + 2.8, 0), 0.23))
        for j in 8:
            var a: float = TAU * float(j) / 8.0
            var radial := Vector3(cos(a), 0, sin(a))
            landing_braces.append(_beam_transform(origin + radial * (r * 2.0) + Vector3(0, 0, 0),
                                   origin + radial * r + Vector3(0, 39, 0), 1.2))
            crowns.append(_beam_transform(origin + radial * (r * 0.75) + Vector3(0, h + 1.5, 0),
                          origin + radial * (r * 0.39) + Vector3(0, h + 13.0, 0), 0.35))
        landmark_count += 1
    _batch_beams("R6_ArcologyExteriorMullions", exterior_ribs, steel)
    _batch_beams("R6_ArcologyConcreteButtresses", landing_braces, inset)
    _batch_beams("R6_AntennaCrownSpars", crowns, copper)
    facade_fins = exterior_ribs.size()
    set_quality(0)

func _nearest_sector(where: Vector3) -> int:
    var best: int = 0
    var d2: float = INF
    for i in segment_origins.size():
        var distance: float = where.distance_squared_to(segment_origins[i])
        if distance < d2:
            d2 = distance
            best = i
    return best

func _batch_beams(label: String, parts: Array[Transform3D], material: Material) -> void:
    var buckets: Array = []
    for sector in segment_origins.size():
        buckets.append([])
    for beam in parts:
        var id: int = _nearest_sector(beam.origin)
        buckets[id].append(Transform3D(
            beam.basis, beam.origin - segment_origins[id]))
    for district in buckets.size():
        var items: Array = buckets[district]
        if items.is_empty():
            continue
        var mm := MultiMesh.new()
        mm.transform_format = MultiMesh.TRANSFORM_3D
        mm.mesh = BoxMesh.new()
        mm.instance_count = items.size()
        for i in items.size():
            mm.set_instance_transform(i, items[i])
        var render := MultiMeshInstance3D.new()
        render.name = "R18_D%02d_%s" % [district, label]
        render.multimesh = mm
        render.material_override = material
        render.extra_cull_margin = 14.0
        segment_hubs[district].add_child(render)
        detail_draws.append(render)
        facade_batches += 1
        exterior_beam_instances += items.size()

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    for detail in detail_draws:
        if is_instance_valid(detail):
            detail.visibility_range_end = FACADE_RANGE[quality_mode]
            detail.visibility_range_end_margin = 135.0
