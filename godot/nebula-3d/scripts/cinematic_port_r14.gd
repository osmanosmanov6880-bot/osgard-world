extends Node3D
## R14: sculpted approach station designed for the FIRST playable flight frame.
## Six near-field facilities with genuine geometry, physical structures and
## deterministic animation. No unrealistic rings or billboard-only artwork.
## Godot Compatibility materials reuse existing shared R12 albedo/normal/ORM.

const MaterialFabricR12Script = preload("res://scripts/material_fabric_r12.gd")
const QUALITY_END = [640.0, 420.0, 240.0]
const PROXY_START = [560.0, 350.0, 195.0]

var site_count: int = 0
var sculpted_decks: int = 0
var detailed_truss_assemblies: int = 0
var hydraulic_gantries: int = 0
var physical_barriers: int = 0
var instanced_hardware: int = 0
var quality_mode: int = 0
var sculpted_vertices: int = 0
var elapsed: float = 0.0
var fine_draws: Array[GeometryInstance3D] = []
var proxy_draws: Array[GeometryInstance3D] = []
var hydraulic_pivots: Array[Node3D] = []
var scene_lights: Array[SpotLight3D] = []
var groups: Array[Node3D] = []
var player_ship: Node3D
var titanium: StandardMaterial3D
var ceramic: StandardMaterial3D
var graphite: StandardMaterial3D
var trim: StandardMaterial3D
var glass: StandardMaterial3D
var worklamp: StandardMaterial3D

func _ready() -> void:
    titanium = MaterialFabricR12Script.get_material(0)
    ceramic = MaterialFabricR12Script.get_material(1)
    graphite = MaterialFabricR12Script.get_material(2)
    trim = StandardMaterial3D.new()
    trim.albedo_color = Color(0.45, 0.29, 0.17)
    trim.roughness = 0.42
    trim.metallic = 0.88
    glass = StandardMaterial3D.new()
    glass.albedo_color = Color(0.06, 0.18, 0.23)
    glass.metallic = 0.18
    glass.roughness = 0.17
    worklamp = StandardMaterial3D.new()
    worklamp.albedo_color = Color(0.62, 0.43, 0.23)
    worklamp.roughness = 0.48
    worklamp.emission_enabled = true
    worklamp.emission = Color(0.46, 0.28, 0.09)
    worklamp.emission_energy_multiplier = 0.24

func _triangle(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
               uv_a: Vector2, uv_b: Vector2, uv_c: Vector2) -> void:
    st.set_uv(uv_a)
    st.add_vertex(a)
    st.set_uv(uv_b)
    st.add_vertex(b)
    st.set_uv(uv_c)
    st.add_vertex(c)

func _curved_flight_deck() -> ArrayMesh:
    # Looped 64-sector shoulder profiles create a truly beveled landing deck.
    # Each surface has explicit UVs and generated normals/tangents for PBR.
    var sections: Array[Vector2] = [
        Vector2(0.0, 3.08), Vector2(9.0, 3.08),
        Vector2(17.0, 3.05), Vector2(23.0, 2.96),
        Vector2(25.5, 2.76), Vector2(27.0, 2.28),
        Vector2(27.25, 1.62), Vector2(27.25, 0.86)
    ]
    var radials: int = 64
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    for i in range(sections.size() - 1):
        var r0: float = sections[i].x
        var y0: float = sections[i].y
        var r1: float = sections[i + 1].x
        var y1: float = sections[i + 1].y
        for j in radials:
            var a: float = TAU * float(j) / float(radials)
            var b: float = TAU * float(j + 1) / float(radials)
            var p0 := Vector3(cos(a) * r0, y0, sin(a) * r0)
            var p1 := Vector3(cos(b) * r0, y0, sin(b) * r0)
            var p2 := Vector3(cos(b) * r1, y1, sin(b) * r1)
            var p3 := Vector3(cos(a) * r1, y1, sin(a) * r1)
            var uv0 := Vector2(cos(a) * r0, sin(a) * r0) * 0.16 + Vector2(4, 4)
            var uv1 := Vector2(cos(b) * r0, sin(b) * r0) * 0.16 + Vector2(4, 4)
            var uv2 := Vector2(cos(b) * r1, sin(b) * r1) * 0.16 + Vector2(4, 4)
            var uv3 := Vector2(cos(a) * r1, sin(a) * r1) * 0.16 + Vector2(4, 4)
            _triangle(st, p0, p1, p2, uv0, uv1, uv2)
            _triangle(st, p0, p2, p3, uv0, uv2, uv3)
    st.generate_normals()
    st.generate_tangents()
    return st.commit()

func _block(root: Node3D, label: String, pos: Vector3,
            dimensions: Vector3, surface: Material, micro: bool = false) -> MeshInstance3D:
    var cube := BoxMesh.new()
    cube.size = dimensions
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = cube
    draw.position = pos
    draw.material_override = surface
    root.add_child(draw)
    if micro:
        fine_draws.append(draw)
    return draw

func _tube(root: Node3D, label: String, a: Vector3, b: Vector3,
           radius: float, material: Material, micro: bool = false) -> MeshInstance3D:
    var span: Vector3 = b - a
    var shape := CylinderMesh.new()
    shape.top_radius = radius
    shape.bottom_radius = radius
    shape.height = span.length()
    shape.radial_segments = 18
    var draw := MeshInstance3D.new()
    draw.name = label
    draw.mesh = shape
    draw.material_override = material
    draw.position = (a + b) * 0.5
    draw.basis = Basis(Quaternion(Vector3.UP, span.normalized()))
    root.add_child(draw)
    if micro:
        fine_draws.append(draw)
    return draw

func _collision(root: Node3D, label: String, location: Vector3,
                dimensions: Vector3) -> void:
    var solid := StaticBody3D.new()
    solid.name = label
    solid.position = location
    root.add_child(solid)
    var shape := CollisionShape3D.new()
    var box := BoxShape3D.new()
    box.size = dimensions
    shape.shape = box
    solid.add_child(shape)
    physical_barriers += 1

func _gpu_batch(root: Node3D, label: String, instances: Array[Transform3D],
                material: Material) -> void:
    if instances.is_empty():
        return
    var batch := MultiMesh.new()
    batch.transform_format = MultiMesh.TRANSFORM_3D
    batch.mesh = BoxMesh.new()
    batch.instance_count = instances.size()
    for i in instances.size():
        batch.set_instance_transform(i, instances[i])
    var node := MultiMeshInstance3D.new()
    node.name = label
    node.multimesh = batch
    node.material_override = material
    node.extra_cull_margin = 16.0
    root.add_child(node)
    fine_draws.append(node)
    instanced_hardware += instances.size()

func _transform(at: Vector3, size: Vector3) -> Transform3D:
    return Transform3D(Basis.IDENTITY.scaled(size), at)

func _make_gantry(root: Node3D, id: int, direction: float) -> void:
    var stage := Node3D.new()
    stage.name = "R14_HydraulicCargoRotator_%02d" % id
    stage.position = Vector3(direction * 41.0, 23.0, -21.0)
    root.add_child(stage)
    _block(stage, "MachinedRotorBearing", Vector3.ZERO,
        Vector3(5.1, 3.8, 5.1), titanium)
    _block(stage, "IndustrialCounterweight", Vector3(0, 2.0, 8.4),
        Vector3(6.4, 4.4, 11.5), graphite)
    _tube(stage, "PistonCore", Vector3(0, -2, -2),
        Vector3(-direction * 8.0, -10.0, -15.0), 0.30, trim, true)
    _tube(stage, "TitaniumLoadArm", Vector3(0, 0, 0),
        Vector3(-direction * 12.0, -11.0, -22.0), 0.75, titanium)
    _block(stage, "CargoClaw", Vector3(-direction * 12.0, -11.0, -22.0),
        Vector3(7.4, 2.1, 6.2), ceramic)
    for side in [-1.0, 1.0]:
        _block(stage, "PairedClampBlade",
            Vector3(-direction * 12.0 + side * 3.0, -12.7, -22.0),
            Vector3(1.1, 3.3, 6.0), graphite, true)
    hydraulic_pivots.append(stage)
    hydraulic_gantries += 1

func _make_facility(root: Node3D, id: int, deck_mesh: Mesh) -> void:
    var platform := MeshInstance3D.new()
    platform.name = "R14_SculptedFlightDeck"
    platform.mesh = deck_mesh
    platform.material_override = titanium
    platform.position = Vector3(0, 0, 52.0)
    root.add_child(platform)
    fine_draws.append(platform)
    sculpted_decks += 1
    var platform_collider := StaticBody3D.new()
    platform_collider.name = "R14_FlightDeckPhysics"
    platform_collider.position = Vector3(0, 1.6, 52.0)
    root.add_child(platform_collider)
    var physics_shape := CollisionShape3D.new()
    var rounded := CylinderShape3D.new()
    rounded.radius = 26.6
    rounded.height = 3.15
    physics_shape.shape = rounded
    platform_collider.add_child(physics_shape)
    physical_barriers += 1
    for direction in [-1.0, 1.0]:
        var x: float = direction * 43.0
        _block(root, "ReinforcedCompositeCitadel",
            Vector3(x, 16, -27), Vector3(18, 32, 29), graphite)
        _block(root, "BeveledCeramicCrown",
            Vector3(x, 33, -27), Vector3(21, 3.3, 32), ceramic)
        _block(root, "GlassObservationGallery",
            Vector3(x, 24, -11.9), Vector3(15.0, 5.5, 0.20), glass, true)
        _collision(root, "R14_TowerCollision", Vector3(x, 17.0, -27),
            Vector3(19.0, 34.0, 29.0))
        # Twelve extruded external load members, plus true cross-bracing.
        for k in 6:
            var z: float = -39.0 + float(k) * 5.0
            _tube(root, "ExposedTitaniumExteriorGirder",
                Vector3(x - direction * 8.8, 2.5, z),
                Vector3(x - direction * 8.8, 31.5, z),
                0.23, titanium, true)
            _tube(root, "FactoryWeatheredDiagonalBrace",
                Vector3(x - direction * 9.4, 4, z),
                Vector3(x - direction * 9.4, 29, z + 3.4),
                0.15, trim, true)
            detailed_truss_assemblies += 2
        for tier in 5:
            var y: float = 5.0 + float(tier) * 5.5
            _block(root, "RecessedArchitecturalSill",
                Vector3(x, y, -11.65),
                Vector3(16.7, 0.25, 0.85), ceramic, true)
            _block(root, "HorizontalCompositeSpine",
                Vector3(x, y + 1.1, -41.8),
                Vector3(17.0, 0.4, 0.67), titanium, true)
        _make_gantry(root, id * 2 + (0 if direction < 0.0 else 1), direction)
    # Overhead truss is much higher than the playable take-off route.
    _block(root, "R14_OverheadFlightControlBridge", Vector3(0, 66.0, -26),
        Vector3(69, 4.0, 9.0), graphite)
    _collision(root, "R14_OverheadBridgePhysics", Vector3(0, 66.0, -26),
        Vector3(69.0, 4.0, 9.0))
    for j in 16:
        var x: float = -32.0 + float(j) * 4.25
        _tube(root, "R14_OverheadDiagonalTruss",
            Vector3(x, 64.6, -30),
            Vector3(x + 3.7, 69.6, -21.4),
            0.20, titanium, true)
        detailed_truss_assemblies += 1
    var label3d := Label3D.new()
    label3d.name = "R14_PortEngravedSign"
    label3d.text = "OSGARD  /  AEGIS  XIV  ·  PORT %02d" % (id + 1)
    label3d.font_size = 72
    label3d.pixel_size = 0.013
    label3d.position = Vector3(0, 67.0, -20.6)
    label3d.modulate = Color(0.75, 0.70, 0.55)
    root.add_child(label3d)

func build(centres: Array) -> void:
    var flightdeck: ArrayMesh = _curved_flight_deck()
    sculpted_vertices = flightdeck.surface_get_array_len(0)
    for district in centres.size():
        var centre: Vector3 = centres[district]
        var group := Node3D.new()
        group.name = "R14_CinematicPort_%02d" % district
        group.position = centre
        add_child(group)
        groups.append(group)
        _make_facility(group, district, flightdeck)
        var bolts: Array[Transform3D] = []
        var ducting: Array[Transform3D] = []
        var lamps: Array[Transform3D] = []
        # Chunk per sector to reject all tiny parts of distant ports in one draw.
        for side in [-1.0, 1.0]:
            var x: float = side * 43.0
            for row in 19:
                var y: float = 3.1 + float(row) * 1.38
                for column in 12:
                    var xx: float = x - 8.0 + float(column) * 1.46
                    bolts.append(_transform(Vector3(xx, y, -11.55),
                        Vector3(0.18, 0.18, 0.20)))
                if row % 2 == 0:
                    ducting.append(_transform(Vector3(x, y, -42),
                        Vector3(15.8, 0.22, 0.42)))
            for k in 30:
                var t: float = TAU * float(k) / 30.0
                var pos := Vector3(cos(t) * 26.25, 3.04, 52 + sin(t) * 26.25)
                lamps.append(_transform(pos, Vector3(0.56, 0.12, 0.72)))
                if k % 3 == 0:
                    bolts.append(_transform(Vector3(cos(t) * 24.75,
                            3.09, 52 + sin(t) * 24.75), Vector3(0.19, 0.10, 0.19)))
        _gpu_batch(group, "R14_BatchedArmorFasteners", bolts, trim)
        _gpu_batch(group, "R14_BatchedMechanicalServiceDucts", ducting, graphite)
        _gpu_batch(group, "R14_DeckSafetyLuminaireArray", lamps, worklamp)
        # A simple far silhouette keeps skyline intact after micro-detail culls.
        for side in [-1.0, 1.0]:
            var far := _block(group, "R14_ProxyFarTower",
                Vector3(side * 43.0, 19, -27), Vector3(18, 38, 31), graphite)
            proxy_draws.append(far)
        var far_bridge := _block(group, "R14_ProxyFarSkybridge",
            Vector3(0, 66, -26), Vector3(68, 5.0, 9), graphite)
        proxy_draws.append(far_bridge)
        var fill := SpotLight3D.new()
        fill.name = "R14_PhysicalWorklight"
        fill.position = Vector3(0, 34, 52)
        fill.rotation_degrees.x = -90.0
        fill.light_color = Color(0.99, 0.81, 0.60)
        fill.light_energy = 0.34
        fill.spot_range = 44.0
        fill.spot_angle = 54.0
        fill.shadow_enabled = false
        group.add_child(fill)
        scene_lights.append(fill)
        site_count += 1
    set_quality(0)

func set_quality(mode: int) -> void:
    quality_mode = clampi(mode, 0, 2)
    for draw in fine_draws:
        if is_instance_valid(draw):
            draw.visibility_range_end = QUALITY_END[quality_mode]
            draw.visibility_range_end_margin = 60.0
    for far in proxy_draws:
        if is_instance_valid(far):
            far.visibility_range_begin = PROXY_START[quality_mode]
            far.visibility_range_begin_margin = 65.0
    _update_light_visibility()

func _update_light_visibility() -> void:
    for i in scene_lights.size():
        if is_instance_valid(scene_lights[i]):
            var nearby: bool = is_instance_valid(player_ship) and (
                player_ship.global_position.distance_squared_to(groups[i].global_position) < 150000.0)
            scene_lights[i].visible = quality_mode < 2 and nearby

func _process(delta: float) -> void:
    elapsed += delta
    if not is_instance_valid(player_ship):
        player_ship = get_parent().get_node_or_null("PlayerShip")
    if fmod(elapsed, 0.5) < delta:
        _update_light_visibility()
    # No per-fastener motion: animated parent pivots only and skip distant sectors.
    for i in hydraulic_pivots.size():
        var pivot: Node3D = hydraulic_pivots[i]
        if not is_instance_valid(pivot):
            continue
        var district: int = int(i / 2)
        var near: bool = is_instance_valid(player_ship) and (
            player_ship.global_position.distance_squared_to(groups[district].global_position) < 145000.0)
        if near:
            pivot.rotation.y = 0.19 * sin(elapsed * 0.25 + float(i) * 1.2)
            pivot.rotation.x = 0.075 * sin(elapsed * 0.17 + float(i) * 0.6)
