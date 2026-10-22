extends Node3D
const ImportedHangarR8Scene = preload("res://assets/models/industrial_hangar_r8.gltf")
## NEBULA R6: industrial megadocks with mesh-based hangar arches, PBR deck
## tiles, gantry cranes and architectural trusses. Six sector instances.
## Long-range repeated parts are batched into MultiMesh, not hundreds of lights.

var panels_instanced: int = 0
var structural_instances: int = 0
var hangar_count: int = 0
var crane_count: int = 0
var deck_material: StandardMaterial3D
var armor: StandardMaterial3D
var alloy: StandardMaterial3D
var glazing: StandardMaterial3D
var guide: StandardMaterial3D
var bronze: StandardMaterial3D

func _ready() -> void:
    deck_material = _make_deck_material()
    armor = _metal(Color(0.035, 0.052, 0.076), 0.52)
    alloy = _metal(Color(0.24, 0.28, 0.32), 0.39)
    glazing = _metal(Color(0.035, 0.13, 0.17), 0.18)
    guide = _metal(Color(0.17, 0.57, 0.63), 0.45, 0.40)
    bronze = _metal(Color(0.56, 0.37, 0.16), 0.37)

func _metal(color: Color, rough: float, emission: float = 0.0) -> StandardMaterial3D:
    var mat := StandardMaterial3D.new()
    mat.albedo_color = color
    mat.metallic = 0.78
    mat.roughness = rough
    if emission > 0.0:
        mat.emission_enabled = true
        mat.emission = color
        mat.emission_energy_multiplier = emission
    return mat

func _make_deck_material() -> StandardMaterial3D:
    # Pattern is physically represented on the actual 3D deck tiles.
    # Alternating grooves, seams, scuffs, worn edge markings and oxidized steel.
    var image := Image.create(256, 256, false, Image.FORMAT_RGBA8)
    var normal_image := Image.create(256, 256, false, Image.FORMAT_RGB8)
    for y in 256:
        for x in 256:
            var ix: int = x % 64
            var iy: int = y % 64
            var seam: bool = ix < 2 or iy < 2
            var groove: bool = ix % 16 == 0 or iy % 16 == 0
            var scratch: float = sin(float(x) * 0.78 + float(y) * 0.071)
            var wear: float = sin(float(x * 11 + y * 7) * 0.027) * 0.011
            var shade: float = 0.77 + scratch * 0.025 + wear
            var color := Color(0.20, 0.24, 0.26) * shade
            if seam:
                color = Color(0.023, 0.034, 0.045)
            elif groove:
                color = color.darkened(0.27)
            elif (int(x / 64) + int(y / 64)) % 3 == 0:
                color = color.lightened(0.035)
            image.set_pixel(x, y, color)
            normal_image.set_pixel(x, y, Color(0.5 + 0.014 * scratch, 0.5 + 0.018 * sin(float(y) * 0.57), 1.0))
    image.generate_mipmaps()
    normal_image.generate_mipmaps()
    var mat := _metal(Color.WHITE, 0.45)
    mat.albedo_texture = ImageTexture.create_from_image(image)
    mat.normal_enabled = true
    mat.normal_texture = ImageTexture.create_from_image(normal_image)
    mat.normal_scale = 0.25
    mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    mat.vertex_color_use_as_albedo = true
    return mat

func _transform(pos: Vector3, size: Vector3, rot_y: float = 0.0) -> Transform3D:
    return Transform3D(Basis(Vector3.UP, rot_y).scaled(size), pos)

func _beam_transform(from: Vector3, to: Vector3, width: float) -> Transform3D:
    var offset: Vector3 = to - from
    var shape: Basis = Basis(Quaternion(Vector3.UP, offset.normalized()))
    return Transform3D(shape.scaled(Vector3(width, offset.length(), width)), (from + to) * 0.5)

func _batch(label: String, parts: Array[Transform3D], material: Material, tint: bool = false) -> void:
    if parts.is_empty():
        return
    var inst := MultiMesh.new()
    inst.transform_format = MultiMesh.TRANSFORM_3D
    inst.use_colors = tint
    inst.mesh = BoxMesh.new()
    inst.instance_count = parts.size()
    for i in parts.size():
        inst.set_instance_transform(i, parts[i])
        if tint:
            var brightness: float = 0.78 + float(i % 7) * 0.032
            inst.set_instance_color(i, Color(brightness, brightness, brightness))
    var draw := MultiMeshInstance3D.new()
    draw.name = label
    draw.multimesh = inst
    draw.material_override = material
    draw.extra_cull_margin = 25.0
    add_child(draw)
    structural_instances += parts.size()

func _box(parent: Node3D, name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
    var mesh := BoxMesh.new()
    mesh.size = size
    var node := MeshInstance3D.new()
    node.name = name
    node.mesh = mesh
    node.position = pos
    node.material_override = mat
    parent.add_child(node)
    return node

func _collision_box(parent: Node3D, name: String, pos: Vector3, size: Vector3) -> void:
    var solid := StaticBody3D.new()
    solid.name = name
    solid.position = pos
    parent.add_child(solid)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = size
    shape.shape = box
    solid.add_child(shape)

func _emit(st: SurfaceTool, a: Vector3, uv_a: Vector2, b: Vector3, uv_b: Vector2, c: Vector3, uv_c: Vector2) -> void:
    st.set_uv(uv_a)
    st.add_vertex(a)
    st.set_uv(uv_b)
    st.add_vertex(b)
    st.set_uv(uv_c)
    st.add_vertex(c)

func _hangar_roof(width: float, depth: float, rise: float) -> ArrayMesh:
    # Continuous 28-segment arch, rather than rectangular cuboids.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var slices: int = 28
    for i in slices:
        var a0: float = PI * float(i) / float(slices)
        var a1: float = PI * float(i + 1) / float(slices)
        var x0: float = cos(a0) * width * 0.5
        var x1: float = cos(a1) * width * 0.5
        var y0: float = sin(a0) * rise
        var y1: float = sin(a1) * rise
        var p0 := Vector3(x0, y0, -depth * 0.5)
        var p1 := Vector3(x1, y1, -depth * 0.5)
        var p2 := Vector3(x1, y1, depth * 0.5)
        var p3 := Vector3(x0, y0, depth * 0.5)
        var u0: float = float(i) / float(slices)
        var u1: float = float(i + 1) / float(slices)
        _emit(st, p0, Vector2(u0, 0), p1, Vector2(u1, 0), p2, Vector2(u1, 1))
        _emit(st, p0, Vector2(u0, 0), p2, Vector2(u1, 1), p3, Vector2(u0, 1))
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

func _hangar(where: Vector3, direction: float, sector: int, side: int) -> void:
    var root := Node3D.new()
    root.name = "R6_EnclosedHangar_%02d_%d" % [sector, side]
    root.position = where
    root.rotation.y = direction
    add_child(root)
    var wall: float = 10.5
    _box(root, "BunkerFloor", Vector3(36.0, 1.25, 31.0), Vector3(0, 1.2, 0), armor)
    _box(root, "ReinforcedLeftWall", Vector3(1.5, wall * 1.95, 29.0), Vector3(-18.1, wall, 0), armor)
    _box(root, "ReinforcedRightWall", Vector3(1.5, wall * 1.95, 29.0), Vector3(18.1, wall, 0), armor)
    var roof_node := MeshInstance3D.new()
    roof_node.name = "SegmentedCurvedTitaniumRoof"
    roof_node.mesh = _hangar_roof(36.0, 31.0, 14.2)
    roof_node.material_override = alloy
    roof_node.position.y = wall * 1.93
    root.add_child(roof_node)
    # Replace the earlier coarse roof with a real independent 3D asset.
    var imported_r8 := ImportedHangarR8Scene.instantiate()
    imported_r8.name = "R8_IndustrialHangarAsset"
    root.add_child(imported_r8)
    roof_node.visible = false
    # Keep close-range details near the six ports without rendering distant
    # 13k-triangle hangars across the entire open-world skyline.
    for part in imported_r8.find_children("*", "MeshInstance3D", true, false):
        part.visibility_range_end = 430.0
        part.visibility_range_end_margin = 70.0
        # The metal now has microscopic brushed relief, not merely flat tints.
        if part.mesh == null:continue
        for surface in part.mesh.get_surface_count():
            var mat := part.mesh.surface_get_material(surface) as StandardMaterial3D
            if mat == null or mat.metallic < 0.40:continue
            var weathered := mat.duplicate() as StandardMaterial3D
            weathered.normal_enabled = true
            weathered.normal_texture = deck_material.normal_texture
            weathered.normal_scale = 0.21
            part.set_surface_override_material(surface, weathered)
    # Physical hangar walls and airlock doors stop high-speed ships, unlike R5 props.
    _collision_box(root, "HangarLeftWallCollision", Vector3(-18.1, wall, 0), Vector3(1.5, wall * 1.95, 29.0))
    _collision_box(root, "HangarRightWallCollision", Vector3(18.1, wall, 0), Vector3(1.5, wall * 1.95, 29.0))
    _collision_box(root, "HangarLeftDoorCollision", Vector3(-7.56, 9.3, -15.75), Vector3(14.6, 16.7, 0.68))
    _collision_box(root, "HangarRightDoorCollision", Vector3(7.56, 9.3, -15.75), Vector3(14.6, 16.7, 0.68))
    for side_x in [-1.0, 1.0]:
        _box(root, "HydraulicDoorSleeve", Vector3(2.2, 17.5, 3.4),
             Vector3(side_x * 15.7, 9.1, -16.0), bronze)
        _box(root, "RoofDrainageGutter", Vector3(0.95, 1.4, 33.1),
             Vector3(side_x * 17.8, wall * 1.93, 0), armor)
        for j in 7:
            var z: float = -12.0 + float(j) * 4.0
            _box(root, "WallShadowRib", Vector3(0.58, 18.6, 0.35),
                 Vector3(side_x * 18.9, 11.0, z), alloy)
            _box(root, "VentilationLouvers", Vector3(0.31, 0.19, 1.25),
                 Vector3(side_x * 18.95, 10.0, z), glazing)
    for j in 9:
        var z: float = -13.8 + float(j) * 3.46
        _box(root, "HangarRoofCrossBeam", Vector3(38.0, 0.24, 0.22),
             Vector3(0, wall * 1.92, z), armor)
    _box(root, "LeftHardenedDoor", Vector3(14.6, 16.7, 0.68),
         Vector3(-7.56, 9.3, -15.75), glazing)
    _box(root, "RightHardenedDoor", Vector3(14.6, 16.7, 0.68),
         Vector3(7.56, 9.3, -15.75), glazing)
    _box(root, "AirlockServiceSign", Vector3(17.0, 1.1, 0.5),
         Vector3(0, 19.0, -16.0), guide)
    for j in 4:
        _box(root, "BlastDoorPressureRail", Vector3(31.5, 0.38, 0.62),
             Vector3(0, 3.4 + float(j) * 4.1, -16.13), armor)
    hangar_count += 1

func _crane(where: Vector3, facing: float, sector: int, side: int) -> void:
    var root := Node3D.new()
    root.name = "R6_MegaServiceCrane_%02d_%d" % [sector, side]
    root.position = where
    root.rotation.y = facing
    add_child(root)
    _box(root, "TowerBase", Vector3(13, 5, 13), Vector3(0, 2.5, 0), armor)
    _collision_box(root, "CraneTowerBaseCollision", Vector3(0, 2.5, 0), Vector3(13, 5, 13))
    for x in [-4.2, 4.2]:
        _collision_box(root, "CraneSupportCollision", Vector3(x, 29, 0), Vector3(0.85, 50.0, 0.95))
        _box(root, "LatticeColumn", Vector3(0.85, 50.0, 0.95),
             Vector3(x, 29, 0), alloy)
        _box(root, "RailGuide", Vector3(0.36, 51, 0.30),
             Vector3(x, 29, -0.85), bronze)
        for j in 6:
            _box(root, "CraneCrossBrace", Vector3(9.1, 0.48, 0.48),
                 Vector3(0, 6.5 + float(j) * 7.6, 0), armor)
    _box(root, "CraneMainGirder", Vector3(3.2, 3.2, 69.0), Vector3(0, 55, -14), alloy)
    _box(root, "CraneCounterweight", Vector3(11.0, 4.6, 9.0), Vector3(0, 55, 25), armor)
    _box(root, "OperatorCabin", Vector3(7.2, 6.0, 8.2), Vector3(0, 51.2, -8), glazing)
    _box(root, "SuspendedLoad", Vector3(7.4, 5, 5.2), Vector3(0, 25, -34), armor)
    for x in [-2.4, 2.4]:
        _box(root, "CableArray", Vector3(0.10, 26.4, 0.10), Vector3(x, 40, -34), bronze)
    for j in 8:
        _box(root, "CraneServiceLamp", Vector3(0.34, 0.19, 0.63),
             Vector3(0, 57.1, -39.0 + float(j) * 7.7), guide)
    crane_count += 1

func build(centers: Array, colors: Array) -> void:
    var tiles: Array[Transform3D] = []
    var gantries: Array[Transform3D] = []
    var radial_girders: Array[Transform3D] = []
    var hazard: Array[Transform3D] = []
    var lamps: Array[Transform3D] = []
    var hydraulic: Array[Transform3D] = []
    var bollards: Array[Transform3D] = []
    var bulkheads: Array[Transform3D] = []
    for sector in centers.size():
        var origin: Vector3 = centers[sector]
        # Concentric matte brushed-metal plating laid over existing landing hub.
        for ring in range(1, 10):
            var radius: float = 3.0 + float(ring) * 3.8
            var segments: int = 10 + ring * 4
            for j in segments:
                var angle: float = TAU * float(j) / float(segments)
                var tile_pos := origin + Vector3(cos(angle) * radius, 3.98, sin(angle) * radius)
                tiles.append(_transform(tile_pos, Vector3(3.4, 0.14, 3.6), -angle))
        for j in 24:
            var a: float = TAU * float(j) / 24.0
            var direction := Vector3(cos(a), 0, sin(a))
            var tangent: float = -a
            var p: Vector3 = origin + direction * 45.0
            hazard.append(_transform(p + Vector3(0, 5.5, 0), Vector3(4.9, 0.14, 0.32), tangent))
            if j % 2 == 0:
                lamps.append(_transform(p + Vector3(0, 5.75, 0), Vector3(0.5, 0.26, 0.5)))
            if j % 3 == 0:
                bollards.append(_transform(p + Vector3(0, 7.3, 0), Vector3(0.8, 3.7, 1.0)))
            radial_girders.append(_beam_transform(origin + direction * 44.0 + Vector3(0, 1.8, 0),
                                 origin + direction * 48.0 + Vector3(0, -1.0, 0), 0.47))
        for j in 8:
            var a: float = TAU * float(j) / 8.0
            var r: Vector3 = Vector3(cos(a), 0, sin(a))
            var p: Vector3 = origin + r * 52.0 + Vector3(0, 4.4, 0)
            gantries.append(_transform(p, Vector3(5.0, 0.45, 3.2), -a))
            hydraulic.append(_beam_transform(p + Vector3(0, 6.5, 0),
                             origin + r * 60.0 + Vector3(0, 13.0, 0), 0.21))
            hydraulic.append(_beam_transform(p + Vector3(0, 6.5, 0),
                             origin + r * 47.0 + Vector3(0, 12.0, 0), 0.21))
        for j in 6:
            var z: float = -49.0 + float(j) * 18.0
            var x: float = 62.0 if j % 2 == 0 else -62.0
            bulkheads.append(_transform(origin + Vector3(x, 6.0, z), Vector3(5.6, 10.0, 13.5)))
        # Hangars sit behind the landing perimeter, giving the initial screenshot
        # actual industrial skyline and a strong accessible focal plane.
        _hangar(origin + Vector3(82, 0, -71), PI * 0.07, sector, 0)
        _hangar(origin + Vector3(-82, 0, -71), -PI * 0.07, sector, 1)
        _crane(origin + Vector3(106, 0, -14), -PI * 0.38, sector, 0)
        _crane(origin + Vector3(-106, 0, -14), PI * 0.38, sector, 1)
    _batch("R6_PBR_DeckPanels", tiles, deck_material, true)
    panels_instanced = tiles.size()
    _batch("R6_RadialSteelGantries", gantries, armor)
    _batch("R6_DockRakerSupports", radial_girders, alloy)
    _batch("R6_FadedHazardPaint", hazard, bronze)
    _batch("R6_ApproachSignalDots", lamps, guide)
    _batch("R6_BlastBarrierBollards", bollards, alloy)
    _batch("R6_BraceHydraulics", hydraulic, alloy)
    _batch("R6_CargoBulkheads", bulkheads, armor)
